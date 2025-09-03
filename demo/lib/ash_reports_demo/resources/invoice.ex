defmodule AshReportsDemo.Invoice do
  @moduledoc """
  Invoice resource for AshReports Demo.

  Represents customer invoices with line items, payment tracking,
  and financial calculations for the business system.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_invoices
  end

  attributes do
    uuid_primary_key :id

    attribute :invoice_number, :string do
      allow_nil? false
      description "Unique invoice number"
      constraints max_length: 50
    end

    attribute :date, :date do
      allow_nil? false
      description "Invoice date"
      default &Date.utc_today/0
    end

    attribute :due_date, :date do
      description "Payment due date"
    end

    attribute :status, :atom do
      description "Invoice status"
      constraints one_of: [:draft, :sent, :paid, :overdue, :cancelled]
      default :draft
      allow_nil? false
    end

    attribute :subtotal, :decimal do
      allow_nil? false
      description "Invoice subtotal before tax"
      default Decimal.new("0.00")
      constraints decimal: [min: Decimal.new("0.00")]
    end

    attribute :tax_rate, :decimal do
      description "Tax rate applied"
      default Decimal.new("8.25")
      constraints decimal: [min: Decimal.new("0.00"), max: Decimal.new("50.00")]
    end

    attribute :tax_amount, :decimal do
      allow_nil? false
      description "Tax amount"
      default Decimal.new("0.00")
      constraints decimal: [min: Decimal.new("0.00")]
    end

    attribute :total, :decimal do
      allow_nil? false
      description "Total invoice amount"
      default Decimal.new("0.00")
      constraints decimal: [min: Decimal.new("0.00")]
    end

    attribute :payment_terms, :string do
      description "Payment terms"
      default "Net 30"
      constraints max_length: 50
    end

    attribute :notes, :string do
      description "Invoice notes"
      constraints max_length: 1000
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the invoice was created"
      default &DateTime.utc_now/0
      allow_nil? false
    end

    attribute :updated_at, :utc_datetime_usec do
      description "When the invoice was last updated"
      default &DateTime.utc_now/0
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :by_status do
      description "Get invoices by status"
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    read :overdue do
      description "Get overdue invoices"
      filter expr(status == :sent and due_date < ^Date.utc_today())
    end

    read :recent do
      description "Get recent invoices"
      argument :days, :integer, default: 30
      # Note: Complex date filtering - simplified for demo
      filter expr(date >= ^Date.add(Date.utc_today(), -30))
    end

    update :mark_paid do
      description "Mark invoice as paid"
      change set_attribute(:status, :paid)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :mark_overdue do
      description "Mark invoice as overdue"
      change set_attribute(:status, :overdue)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :calculate_totals do
      description "Recalculate invoice totals from line items"

      change fn changeset, context ->
        # This would calculate totals from line items
        # For demo purposes, we'll use the existing values
        changeset
        |> Ash.Changeset.change_attribute(:updated_at, DateTime.utc_now())
      end
    end
  end

  relationships do
    belongs_to :customer, AshReportsDemo.Customer do
      description "Customer this invoice belongs to"
      allow_nil? false
    end

    has_many :line_items, AshReportsDemo.InvoiceLineItem do
      description "Invoice line items"
      destination_attribute :invoice_id
    end
  end

  calculations do
    calculate :days_overdue, :integer do
      description "Number of days overdue (negative if not due yet)"

      calculation fn records, _context ->
        today = Date.utc_today()

        records
        |> Enum.map(fn invoice ->
          days_overdue =
            if invoice.due_date do
              Date.diff(today, invoice.due_date)
            else
              0
            end

          {invoice.id, days_overdue}
        end)
        |> Map.new()
      end
    end

    calculate :payment_status, :string do
      description "Payment status description"

      calculation fn records, _context ->
        today = Date.utc_today()

        records
        |> Enum.map(fn invoice ->
          status =
            case invoice.status do
              :paid ->
                "Paid"

              :cancelled ->
                "Cancelled"

              :draft ->
                "Draft"

              :sent ->
                if invoice.due_date && Date.compare(today, invoice.due_date) == :gt do
                  "Overdue"
                else
                  "Outstanding"
                end

              :overdue ->
                "Overdue"
            end

          {invoice.id, status}
        end)
        |> Map.new()
      end
    end

    calculate :age_in_days, :integer do
      description "Age of invoice in days"

      calculation fn records, _context ->
        today = Date.utc_today()

        records
        |> Enum.map(fn invoice ->
          age = Date.diff(today, invoice.date)
          {invoice.id, age}
        end)
        |> Map.new()
      end
    end

    calculate :formatted_total, :string do
      description "Formatted total for display"

      calculation fn records, _context ->
        records
        |> Enum.map(fn invoice ->
          formatted = "$#{Decimal.to_string(invoice.total)}"
          {invoice.id, formatted}
        end)
        |> Map.new()
      end
    end
  end

  aggregates do
    count :line_item_count, :line_items do
      description "Number of line items on this invoice"
    end

    sum :line_items_subtotal, :line_items, :line_total do
      description "Subtotal from line items"
    end

    avg :average_line_item_amount, :line_items, :line_total do
      description "Average line item amount"
    end
  end

  validations do
    validate present([:invoice_number, :date, :customer_id]),
      message: "invoice number, date, and customer are required"

    validate attribute_does_not_equal(:invoice_number, ""),
      message: "invoice number cannot be blank"

    validate compare(:subtotal, greater_than_or_equal_to: 0),
      message: "subtotal must be non-negative"

    validate compare(:tax_amount, greater_than_or_equal_to: 0),
      message: "tax amount must be non-negative"

    validate compare(:total, greater_than_or_equal_to: 0),
      message: "total must be non-negative"

    # Due date must be after invoice date
    validate fn changeset, _context ->
      invoice_date = Ash.Changeset.get_attribute(changeset, :date)
      due_date = Ash.Changeset.get_attribute(changeset, :due_date)

      if invoice_date && due_date && Date.compare(due_date, invoice_date) == :lt do
        {:error, field: :due_date, message: "due date must be on or after invoice date"}
      else
        :ok
      end
    end
  end

  identities do
    identity :unique_invoice_number, [:invoice_number] do
      message "invoice number must be unique"
    end
  end

  changes do
    change fn changeset, _context ->
      # Auto-update the updated_at timestamp
      if changeset.action_type in [:update] do
        Ash.Changeset.change_attribute(changeset, :updated_at, DateTime.utc_now())
      else
        changeset
      end
    end

    # Auto-calculate due date if not provided
    change fn changeset, _context ->
      if changeset.action_type == :create &&
           !Ash.Changeset.get_attribute(changeset, :due_date) do
        invoice_date = Ash.Changeset.get_attribute(changeset, :date) || Date.utc_today()
        # Default 30 days
        due_date = Date.add(invoice_date, 30)

        Ash.Changeset.change_attribute(changeset, :due_date, due_date)
      else
        changeset
      end
    end

    # Phase 7.4: Advanced lifecycle management
    change fn changeset, _context ->
      # Auto-update status based on due date for sent invoices
      if changeset.action_type == :update do
        current_status = Ash.Changeset.get_attribute(changeset, :status)
        due_date = Ash.Changeset.get_attribute(changeset, :due_date)
        
        if current_status == :sent && due_date && Date.compare(Date.utc_today(), due_date) == :gt do
          Ash.Changeset.change_attribute(changeset, :status, :overdue)
        else
          changeset
        end
      else
        changeset
      end
    end
  end

  resource do
    description "Invoice management with payment tracking and financial calculations"
  end
end
