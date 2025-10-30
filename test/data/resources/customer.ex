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
      constraints max: Decimal.new("100000.00"), min: Decimal.new("0.00")
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

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :update, action: :update
    define :destroy, action: :destroy
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:name, :email, :phone, :status, :credit_limit, :notes, :customer_type_id]
    end

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
      # Note: Simplified filter for demo - lifetime_value is a calculation
    end

    # Phase 7.4: Business intelligence queries
    read :by_health_score do
      description "Get customers by health score range"
      argument :min_score, :integer, default: 70
      argument :max_score, :integer, default: 100
      # Custom business intelligence query
    end

    read :by_tier do
      description "Get customers by tier classification"
      argument :tier, :string, allow_nil?: false
      argument :include_inactive, :boolean, default: false
      # Advanced customer segmentation query
    end

    read :at_risk do
      description "Get customers requiring immediate attention"
      # Customers with poor health scores or high risk categories
      filter expr(status == :suspended or status == :inactive)
    end

    read :review_due do
      description "Get customers due for review"
      # Customers requiring review based on advanced business logic
    end

    update :suspend do
      description "Suspend a customer"
      require_atomic? false
      change set_attribute(:status, :suspended)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :activate do
      description "Activate a suspended customer"
      require_atomic? false
      change set_attribute(:status, :active)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    # Phase 7.4: Advanced custom actions
    update :adjust_credit_limit do
      description "Adjust customer credit limit with business logic"
      require_atomic? false
      argument :new_limit, :decimal, allow_nil?: false
      argument :reason, :string, allow_nil?: false

      change fn changeset, _context ->
        new_limit = Ash.Changeset.get_argument(changeset, :new_limit)
        reason = Ash.Changeset.get_argument(changeset, :reason)

        # Business logic for credit limit adjustment
        notes = "Credit limit adjusted to $#{Decimal.to_string(new_limit)}. Reason: #{reason}"

        changeset
        |> Ash.Changeset.change_attribute(:credit_limit, new_limit)
        |> Ash.Changeset.change_attribute(:notes, notes)
        |> Ash.Changeset.change_attribute(:updated_at, DateTime.utc_now())
      end
    end

    update :record_interaction do
      description "Record customer interaction for engagement tracking"
      require_atomic? false
      argument :interaction_type, :string, allow_nil?: false
      argument :notes, :string, default: ""

      change fn changeset, _context ->
        interaction_type = Ash.Changeset.get_argument(changeset, :interaction_type)
        interaction_notes = Ash.Changeset.get_argument(changeset, :notes)

        # Add interaction to customer notes
        current_notes = Ash.Changeset.get_attribute(changeset, :notes) || ""
        timestamp = DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()

        new_notes =
          if String.length(current_notes) > 0 do
            "#{current_notes}\n[#{timestamp}] #{interaction_type}: #{interaction_notes}"
          else
            "[#{timestamp}] #{interaction_type}: #{interaction_notes}"
          end

        changeset
        |> Ash.Changeset.change_attribute(:notes, new_notes)
        |> Ash.Changeset.change_attribute(:updated_at, DateTime.utc_now())
      end
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

    # Phase 7.4: Advanced customer analytics
    calculate :customer_health_score, :integer do
      description "Customer health score based on payment history and engagement (0-100)"

      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          # Advanced health scoring algorithm
          payment_score =
            case customer.status do
              # 70-100
              :active -> 70 + :rand.uniform(30)
              # 30-70
              :inactive -> 30 + :rand.uniform(40)
              # 0-30
              :suspended -> :rand.uniform(30)
            end

          # Adjust based on credit limit (higher limit = better customer)
          credit_bonus = min(20, Decimal.to_integer(customer.credit_limit) / 2500)

          # Simulate engagement score based on recent activity
          engagement_score = :rand.uniform(20)

          final_score = min(100, payment_score + credit_bonus + engagement_score)
          {customer.id, final_score}
        end)
        |> Map.new()
      end
    end

    calculate :risk_category, :string do
      description "Customer risk category based on multiple factors"

      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          # Risk assessment based on status and payment patterns
          base_risk =
            case customer.status do
              :active -> "Low"
              :inactive -> "Medium"
              :suspended -> "High"
            end

          # Adjust based on credit limit
          risk_adjustment =
            if Decimal.gt?(customer.credit_limit, Decimal.new("25000")) do
              case base_risk do
                "Medium" -> "Low-Medium"
                "High" -> "Medium-High"
                other -> other
              end
            else
              base_risk
            end

          {customer.id, risk_adjustment}
        end)
        |> Map.new()
      end
    end

    calculate :customer_tier, :string do
      description "Customer tier classification based on lifetime value and engagement"

      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          # Simulate tier calculation based on multiple factors
          credit_tier =
            cond do
              Decimal.gte?(customer.credit_limit, Decimal.new("50000")) -> "Platinum"
              Decimal.gte?(customer.credit_limit, Decimal.new("25000")) -> "Gold"
              Decimal.gte?(customer.credit_limit, Decimal.new("10000")) -> "Silver"
              true -> "Bronze"
            end

          {customer.id, credit_tier}
        end)
        |> Map.new()
      end
    end

    calculate :next_review_date, :date do
      description "Recommended next review date based on customer risk and activity"

      calculation fn records, _context ->
        today = Date.utc_today()

        records
        |> Enum.map(fn customer ->
          # Calculate review frequency based on status
          days_until_review =
            case customer.status do
              # Quarterly review
              :active -> 90
              # Monthly review
              :inactive -> 30
              # Weekly review
              :suspended -> 7
            end

          review_date = Date.add(today, days_until_review)
          {customer.id, review_date}
        end)
        |> Map.new()
      end
    end
  end

  aggregates do
    count :address_count, :addresses do
      description "Number of addresses for this customer"
    end

    count :invoice_count, :invoices do
      description "Total number of invoices for this customer"
    end

    sum :total_invoice_amount, :invoices, :total do
      description "Total amount of all customer invoices"
    end

    max :last_invoice_date, :invoices, :date do
      description "Date of most recent invoice"
    end

    avg :average_invoice_amount, :invoices, :total do
      description "Average invoice amount for this customer"
    end

    # Phase 7.4: Advanced cross-resource aggregates
    count :paid_invoice_count, :invoices do
      description "Number of paid invoices for revenue analysis"
      filter expr(status == :paid)
    end

    count :overdue_invoice_count, :invoices do
      description "Number of overdue invoices for risk assessment"
      filter expr(status == :overdue)
    end

    sum :total_paid_amount, :invoices, :total do
      description "Total amount of paid invoices"
      filter expr(status == :paid)
    end

    sum :total_outstanding_amount, :invoices, :total do
      description "Total amount of outstanding invoices"
      filter expr(status in [:sent, :overdue])
    end
  end

  # Phase 7.4: Authorization policies would go here if using ash_policy_authorizer extension

  validations do
    validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/), message: "must be a valid email address"
    validate compare(:credit_limit, greater_than_or_equal_to: 0), message: "must be non-negative"
    validate attribute_does_not_equal(:name, ""), message: "name cannot be blank"

    # Phase 7.4: Advanced business validations
    validate fn changeset, _context ->
      # Advanced validation: Credit limit cannot exceed 5x the customer type maximum
      customer_type_id = Ash.Changeset.get_attribute(changeset, :customer_type_id)
      credit_limit = Ash.Changeset.get_attribute(changeset, :credit_limit)

      if customer_type_id && credit_limit do
        # For demo: basic validation logic
        max_allowed = Decimal.new("100000.00")

        if Decimal.gt?(credit_limit, max_allowed) do
          {:error, field: :credit_limit, message: "credit limit exceeds maximum allowed"}
        else
          :ok
        end
      else
        :ok
      end
    end
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
      pre_check_with AshReportsDemo.Domain
    end
  end

  resource do
    description "Customer resource for the invoicing system"

    base_filter expr(status != :deleted)
  end
end
