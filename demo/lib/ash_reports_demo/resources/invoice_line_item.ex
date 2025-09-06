defmodule AshReportsDemo.InvoiceLineItem do
  @moduledoc """
  Invoice line item resource for AshReports Demo.

  Represents individual items on customer invoices with
  pricing, quantity, and calculation support.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_invoice_line_items
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      description "Quantity ordered"
      constraints min: Decimal.new("0.01")
    end

    attribute :unit_price, :decimal do
      allow_nil? false
      description "Price per unit"
      constraints min: Decimal.new("0.01")
    end

    attribute :line_total, :decimal do
      allow_nil? false
      description "Total for this line item"
      default Decimal.new("0.00")
      constraints min: Decimal.new("0.00")
    end

    attribute :discount_percentage, :decimal do
      description "Discount percentage applied to this line"
      default Decimal.new("0.00")
      constraints [min: Decimal.new("0.00"), max: Decimal.new("100.00")]
    end

    attribute :discount_amount, :decimal do
      description "Dollar amount of discount applied"
      default Decimal.new("0.00")
      constraints min: Decimal.new("0.00")
    end

    attribute :description, :string do
      description "Line item description or notes"
      constraints max_length: 255
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the line item was created"
      default &DateTime.utc_now/0
      allow_nil? false
    end
  end

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :update, action: :update
    define :destroy, action: :destroy
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [:quantity, :unit_price, :line_total, :discount_percentage, :discount_amount, :description, :invoice_id, :product_id]
    end

    read :by_invoice do
      description "Get line items by invoice"
      argument :invoice_id, :uuid, allow_nil?: false
      filter expr(invoice_id == ^arg(:invoice_id))
    end

    read :by_product do
      description "Get line items by product"
      argument :product_id, :uuid, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))
    end

    update :apply_discount do
      description "Apply discount to line item"
      require_atomic? false
      argument :discount_type, :atom, constraints: [one_of: [:percentage, :amount]]
      argument :discount_value, :decimal, allow_nil?: false

      change fn changeset, context ->
        discount_type = Ash.Changeset.get_argument(changeset, :discount_type)
        discount_value = Ash.Changeset.get_argument(changeset, :discount_value)
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)

        {discount_percentage, discount_amount} =
          case discount_type do
            :percentage ->
              percentage = discount_value
              subtotal = Decimal.mult(quantity, unit_price)
              amount = subtotal |> Decimal.mult(percentage) |> Decimal.div(100)
              {percentage, amount}

            :amount ->
              amount = discount_value
              subtotal = Decimal.mult(quantity, unit_price)

              percentage =
                if Decimal.gt?(subtotal, 0) do
                  amount |> Decimal.div(subtotal) |> Decimal.mult(100)
                else
                  Decimal.new("0.00")
                end

              {percentage, amount}
          end

        # Calculate new line total
        subtotal = Decimal.mult(quantity, unit_price)
        new_total = Decimal.sub(subtotal, discount_amount)

        changeset
        |> Ash.Changeset.change_attribute(:discount_percentage, discount_percentage)
        |> Ash.Changeset.change_attribute(:discount_amount, discount_amount)
        |> Ash.Changeset.change_attribute(:line_total, new_total)
      end
    end
  end

  relationships do
    belongs_to :invoice, AshReportsDemo.Invoice do
      description "Invoice this line item belongs to"
      allow_nil? false
    end

    belongs_to :product, AshReportsDemo.Product do
      description "Product being invoiced"
      allow_nil? false
    end
  end

  calculations do
    calculate :subtotal_before_discount, :decimal, expr(quantity * unit_price) do
      description "Subtotal before any discounts"
    end

    calculate :effective_unit_price, :decimal do
      description "Effective unit price after discounts"

      calculation fn records, _context ->
        records
        |> Enum.map(fn line_item ->
          if Decimal.gt?(line_item.quantity, 0) do
            effective_price = Decimal.div(line_item.line_total, line_item.quantity)
            {line_item.id, effective_price}
          else
            {line_item.id, Decimal.new("0.00")}
          end
        end)
        |> Map.new()
      end
    end

    calculate :profit_margin, :decimal do
      description "Profit margin for this line item"

      calculation fn records, _context ->
        records
        |> Enum.map(fn line_item ->
          # This would ideally access product cost
          # For demo: simulate margin calculation
          # Assume 65% cost ratio
          cost_ratio = Decimal.new("0.65")
          revenue = line_item.line_total
          estimated_cost = Decimal.mult(revenue, cost_ratio)
          margin = Decimal.sub(revenue, estimated_cost)

          {line_item.id, margin}
        end)
        |> Map.new()
      end
    end

    calculate :discount_savings, :decimal, expr(quantity * unit_price - line_total) do
      description "Amount saved due to discounts"
    end
  end

  validations do
    validate present([:quantity, :unit_price, :invoice_id, :product_id]),
      message: "quantity, unit price, invoice, and product are required"

    validate compare(:quantity, greater_than: 0), message: "quantity must be positive"
    validate compare(:unit_price, greater_than: 0), message: "unit price must be positive"

    validate compare(:line_total, greater_than_or_equal_to: 0),
      message: "line total must be non-negative"

    validate compare(:discount_percentage, greater_than_or_equal_to: 0),
      message: "discount percentage must be non-negative"

    validate compare(:discount_percentage, less_than_or_equal_to: 100),
      message: "discount percentage cannot exceed 100%"
  end

  changes do
    # Auto-calculate line total when quantity or unit_price changes
    change fn changeset, _context ->
      if Ash.Changeset.changing_attribute?(changeset, :quantity) ||
           Ash.Changeset.changing_attribute?(changeset, :unit_price) ||
           Ash.Changeset.changing_attribute?(changeset, :discount_amount) do
        quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)

        discount_amount =
          Ash.Changeset.get_attribute(changeset, :discount_amount) || Decimal.new("0.00")

        if quantity && unit_price do
          subtotal = Decimal.mult(quantity, unit_price)
          line_total = Decimal.sub(subtotal, discount_amount)

          Ash.Changeset.change_attribute(changeset, :line_total, line_total)
        else
          changeset
        end
      else
        changeset
      end
    end
  end

  resource do
    description "Invoice line items with pricing and discount calculations"
  end
end
