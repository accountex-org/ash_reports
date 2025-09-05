defmodule AshReportsDemo.CustomerType do
  @moduledoc """
  Customer type resource for AshReports Demo.

  Represents customer type classifications such as Premium, Standard, Basic
  with associated benefits and pricing tiers.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_customer_types
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Customer type name"
      constraints max_length: 100
    end

    attribute :description, :string do
      description "Description of customer type benefits"
      constraints max_length: 500
    end

    attribute :discount_percentage, :decimal do
      description "Default discount percentage for this customer type"
      default Decimal.new("0.00")
      constraints [max: Decimal.new("50.00"), min: Decimal.new("0.00")]
    end

    attribute :priority_level, :integer do
      description "Priority level for customer service (1-5)"
      default 3
      constraints min: 1, max: 5
    end

    attribute :active, :boolean do
      description "Whether this customer type is currently active"
      default true
      allow_nil? false
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the customer type was created"
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
      accept [:name, :description, :discount_percentage, :priority_level, :active]
    end

    read :active do
      description "Get active customer types only"
      filter expr(active == true)
    end

    read :by_priority do
      description "Get customer types by priority level"
      argument :priority, :integer, allow_nil?: false
      filter expr(priority_level == ^arg(:priority))
    end
  end

  relationships do
    has_many :customers, AshReportsDemo.Customer do
      description "Customers with this type"
      destination_attribute :customer_type_id
    end
  end

  calculations do
    calculate :display_name, :string, expr(name <> " (" <> description <> ")") do
      description "Customer type name with description for display"
    end

    calculate :effective_discount, :decimal do
      description "Effective discount including any special promotions"

      calculation fn records, _context ->
        records
        |> Enum.map(fn customer_type ->
          # For demo: add small random promotion bonus
          base_discount = customer_type.discount_percentage
          promotion_bonus = Decimal.new("#{:rand.uniform(5)}")
          effective = Decimal.add(base_discount, promotion_bonus)

          {customer_type.id, effective}
        end)
        |> Map.new()
      end
    end
  end

  aggregates do
    count :customer_count, :customers do
      description "Number of customers with this type"
    end

    count :active_customer_count, :customers do
      description "Number of active customers with this type"
      filter expr(status == :active)
    end
  end

  validations do
    validate present(:name), message: "name is required"
    validate attribute_does_not_equal(:name, ""), message: "name cannot be blank"

    validate compare(:discount_percentage, greater_than_or_equal_to: 0),
      message: "discount percentage must be non-negative"

    validate compare(:discount_percentage, less_than_or_equal_to: 50),
      message: "discount percentage cannot exceed 50%"
  end

  identities do
    identity :unique_name, [:name] do
      message "customer type name must be unique"
      pre_check_with AshReportsDemo.Domain
    end
  end

  resource do
    description "Customer type classifications for business segmentation"
  end
end
