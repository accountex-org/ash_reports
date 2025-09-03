defmodule AshReportsDemo.Customer do
  @moduledoc """
  Customer resource for AshReports Demo.

  Represents customers in the invoicing system with comprehensive
  business logic, calculations, and relationship management.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_customers
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Customer full name"
      constraints max_length: 255
    end

    attribute :email, :string do
      allow_nil? false
      description "Customer email address"
      constraints match: ~r/^[^\s]+@[^\s]+\.[^\s]+$/
    end

    attribute :phone, :string do
      description "Customer phone number"
      constraints max_length: 20
    end

    attribute :status, :atom do
      description "Customer status"
      constraints one_of: [:active, :inactive, :suspended]
      default :active
    end

    attribute :credit_limit, :decimal do
      description "Customer credit limit"
      default Decimal.new("5000.00")
      constraints decimal: [max: Decimal.new("100000.00"), min: Decimal.new("0.00")]
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the customer was created"
      default &DateTime.utc_now/0
      allow_nil? false
    end

    attribute :updated_at, :utc_datetime_usec do
      description "When the customer was last updated"
      default &DateTime.utc_now/0
      allow_nil? false
    end

    attribute :notes, :string do
      description "Internal notes about the customer"
      constraints max_length: 1000
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :active do
      description "Get active customers only"
      filter expr(status == :active)
    end

    read :by_status do
      description "Get customers by status"
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    read :high_value do
      description "Get customers with high lifetime value"
      argument :minimum_value, :decimal, default: Decimal.new("10000.00")
      filter expr(lifetime_value >= ^arg(:minimum_value))
    end

    update :suspend do
      description "Suspend a customer"
      change set_attribute(:status, :suspended)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :activate do
      description "Activate a suspended customer"
      change set_attribute(:status, :active)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
  end

  relationships do
    belongs_to :customer_type, AshReportsDemo.CustomerType do
      description "Customer type classification"
      allow_nil? false
    end

    has_many :addresses, AshReportsDemo.CustomerAddress do
      description "Customer addresses"
      destination_attribute :customer_id
    end

    has_many :invoices, AshReportsDemo.Invoice do
      description "Customer invoices"
      destination_attribute :customer_id
    end
  end

  calculations do
    calculate :full_name, :string, expr(name) do
      description "Full customer name for display"
    end

    calculate :primary_address,
              :string,
              expr(
                fragment(
                  "(SELECT CONCAT(?, ', ', ?, ' ', ?) FROM addresses WHERE customer_id = ? AND primary = true LIMIT 1)",
                  [street, city, state, id]
                )
              ) do
      description "Primary address formatted for display"
    end

    calculate :lifetime_value, :decimal do
      description "Total value of all customer invoices"

      calculation fn records, _context ->
        # Calculate lifetime value based on invoice totals
        records
        |> Enum.map(fn customer ->
          # This would query invoices for the customer
          # For demo purposes, return a sample value
          invoice_total = Decimal.new("#{:rand.uniform(50000)}")
          {customer.id, invoice_total}
        end)
        |> Map.new()
      end
    end

    calculate :payment_score, :integer do
      description "Payment score based on payment history (0-100)"

      calculation fn records, _context ->
        # Calculate payment score based on invoice payment patterns
        records
        |> Enum.map(fn customer ->
          # For demo: random score based on customer status
          score =
            case customer.status do
              # 60-100
              :active -> :rand.uniform(40) + 60
              # 20-80
              :inactive -> :rand.uniform(60) + 20
              # 0-30
              :suspended -> :rand.uniform(30)
            end

          {customer.id, score}
        end)
        |> Map.new()
      end
    end

    calculate :days_since_created,
              :integer,
              expr(fragment("EXTRACT(DAY FROM AGE(NOW(), ?))", created_at)) do
      description "Number of days since customer was created"
    end
  end

  aggregates do
    count :address_count, :addresses do
      description "Number of addresses for this customer"
    end

    count :invoice_count, :invoices do
      description "Total number of invoices for this customer"
    end

    sum :total_invoice_amount, :invoices, field: :total do
      description "Total amount of all customer invoices"
    end

    max :last_invoice_date, :invoices, field: :date do
      description "Date of most recent invoice"
    end

    avg :average_invoice_amount, :invoices, field: :total do
      description "Average invoice amount for this customer"
    end
  end

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/), message: "must be a valid email address"
    validate compare(:credit_limit, greater_than_or_equal_to: 0), message: "must be non-negative"
    validate attribute_does_not_equal(:name, ""), message: "name cannot be blank"
  end

  changes do
    change fn changeset, _context ->
      # Auto-update the updated_at timestamp
      if changeset.action_type in [:create, :update] do
        Ash.Changeset.change_attribute(changeset, :updated_at, DateTime.utc_now())
      else
        changeset
      end
    end
  end

  identities do
    identity :unique_email, [:email] do
      message "email must be unique"
    end
  end

  resource do
    description "Customer resource for the invoicing system"

    base_filter expr(status != :deleted)
  end
end
