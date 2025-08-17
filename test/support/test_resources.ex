defmodule AshReports.Test.Customer do
  @moduledoc """
  Test Customer resource for AshReports testing.
  
  Provides a realistic Ash.Resource with relationships for comprehensive
  testing of report functionality.
  """
  
  use Ash.Resource,
    domain: nil,
    data_layer: AshReports.MockDataLayer
  
  attributes do
    uuid_primary_key :id
    
    attribute :name, :string do
      allow_nil? false
      description "Customer full name"
    end
    
    attribute :email, :string do
      description "Customer email address"
    end
    
    attribute :region, :string do
      description "Customer's geographic region"
      default "North"
    end
    
    attribute :status, :atom do
      description "Customer status"
      constraints one_of: [:active, :inactive, :pending]
      default :active
    end
    
    attribute :created_at, :utc_datetime_usec do
      description "When the customer was created"
      default &DateTime.utc_now/0
    end
    
    attribute :credit_limit, :decimal do
      description "Customer's credit limit"
      default Decimal.new("1000.00")
    end
  end
  
  relationships do
    has_many :orders, AshReports.Test.Order do
      destination_attribute :customer_id
    end
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :active do
      filter expr(status == :active)
    end
    
    read :by_region do
      argument :region, :string, allow_nil?: false
      filter expr(region == ^arg(:region))
    end
  end
  
  calculations do
    calculate :full_display_name, :string, expr(name <> " (" <> email <> ")") do
      description "Full name with email for display"
    end
  end
  
  # Aggregates temporarily disabled for testing
  # aggregates do
  #   count :total_orders, :orders
  #   sum :lifetime_value, :orders, :total_amount
  #   max :last_order_date, :orders, :order_date
  # end
end

defmodule AshReports.Test.Order do
  @moduledoc """
  Test Order resource for AshReports testing.
  
  Represents customer orders with relationships to customers and products.
  """
  
  use Ash.Resource,
    domain: nil,
    data_layer: AshReports.MockDataLayer
  
  attributes do
    uuid_primary_key :id
    
    attribute :order_number, :string do
      allow_nil? false
      description "Unique order number"
    end
    
    attribute :order_date, :date do
      allow_nil? false
      description "Date the order was placed"
      default &Date.utc_today/0
    end
    
    attribute :status, :atom do
      description "Order status"
      constraints one_of: [:pending, :processing, :shipped, :delivered, :cancelled]
      default :pending
    end
    
    attribute :total_amount, :decimal do
      description "Total order amount"
      allow_nil? false
    end
    
    attribute :shipping_cost, :decimal do
      description "Shipping cost for the order"
      default Decimal.new("0.00")
    end
    
    attribute :tax_amount, :decimal do
      description "Tax amount for the order"
      default Decimal.new("0.00")
    end
    
    attribute :notes, :string do
      description "Order notes"
    end
  end
  
  relationships do
    belongs_to :customer, AshReports.Test.Customer do
      allow_nil? false
      attribute_writable? true
    end
    
    has_many :order_items, AshReports.Test.OrderItem do
      destination_attribute :order_id
    end
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end
    
    read :by_date_range do
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false
      filter expr(order_date >= ^arg(:start_date) and order_date <= ^arg(:end_date))
    end
    
    read :recent do
      filter expr(order_date >= ago(30, :day))
    end
  end
  
  calculations do
    calculate :subtotal, :decimal, expr(total_amount - shipping_cost - tax_amount) do
      description "Order subtotal before shipping and tax"
    end
    
    calculate :days_since_order, :integer, expr(
      date_diff(^Date.utc_today(), order_date, :day)
    ) do
      description "Days since order was placed"
    end
  end
  
  # Aggregates temporarily disabled for testing
  # aggregates do
  #   count :total_items, :order_items
  #   sum :total_quantity, :order_items, :quantity
  # end
end

defmodule AshReports.Test.Product do
  @moduledoc """
  Test Product resource for AshReports testing.
  
  Represents products that can be included in orders.
  """
  
  use Ash.Resource,
    domain: nil,
    data_layer: AshReports.MockDataLayer
  
  attributes do
    uuid_primary_key :id
    
    attribute :name, :string do
      allow_nil? false
      description "Product name"
    end
    
    attribute :sku, :string do
      allow_nil? false
      description "Stock keeping unit"
    end
    
    attribute :description, :string do
      description "Product description"
    end
    
    attribute :category, :string do
      description "Product category"
      default "General"
    end
    
    attribute :price, :decimal do
      allow_nil? false
      description "Product price"
    end
    
    attribute :cost, :decimal do
      description "Product cost"
    end
    
    attribute :weight, :decimal do
      description "Product weight in pounds"
    end
    
    attribute :active, :boolean do
      description "Whether the product is active"
      default true
    end
    
    attribute :created_at, :utc_datetime_usec do
      description "When the product was created"
      default &DateTime.utc_now/0
    end
  end
  
  relationships do
    has_many :order_items, AshReports.Test.OrderItem do
      destination_attribute :product_id
    end
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :active do
      filter expr(active == true)
    end
    
    read :by_category do
      argument :category, :string, allow_nil?: false
      filter expr(category == ^arg(:category))
    end
    
    read :price_range do
      argument :min_price, :decimal, allow_nil?: false
      argument :max_price, :decimal, allow_nil?: false
      filter expr(price >= ^arg(:min_price) and price <= ^arg(:max_price))
    end
  end
  
  calculations do
    calculate :margin, :decimal, expr(price - cost) do
      description "Product margin"
    end
    
    calculate :margin_percentage, :decimal, expr(
      (price - cost) / price * 100
    ) do
      description "Margin as percentage"
    end
  end
  
  # Aggregates temporarily disabled for testing
  # aggregates do
  #   count :total_orders, :order_items
  #   sum :total_quantity_sold, :order_items, :quantity
  # end
end

defmodule AshReports.Test.OrderItem do
  @moduledoc """
  Test OrderItem resource for AshReports testing.
  
  Represents line items within orders, linking orders to products.
  """
  
  use Ash.Resource,
    domain: nil,
    data_layer: AshReports.MockDataLayer
  
  attributes do
    uuid_primary_key :id
    
    attribute :quantity, :integer do
      allow_nil? false
      description "Quantity ordered"
      constraints min: 1
    end
    
    attribute :unit_price, :decimal do
      allow_nil? false
      description "Price per unit at time of order"
    end
    
    attribute :line_total, :decimal do
      description "Total for this line item"
    end
    
    attribute :discount_amount, :decimal do
      description "Discount applied to this line"
      default Decimal.new("0.00")
    end
  end
  
  relationships do
    belongs_to :order, AshReports.Test.Order do
      allow_nil? false
      attribute_writable? true
    end
    
    belongs_to :product, AshReports.Test.Product do
      allow_nil? false
      attribute_writable? true
    end
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
  end
  
  calculations do
    calculate :discounted_total, :decimal, expr(line_total - discount_amount) do
      description "Line total after discount"
    end
    
    calculate :effective_unit_price, :decimal, expr(
      (line_total - discount_amount) / quantity
    ) do
      description "Effective price per unit after discounts"
    end
  end
end