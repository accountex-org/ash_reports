# Phase 7.2: Domain Model and Resources

**Duration: 3-4 days**  
**Goal: Implement comprehensive business domain model with 8 interconnected Ash resources using ETS data layer**

## Overview

Phase 7.2 focuses on creating the complete business domain model for the AshReportsDemo project. This phase builds upon the Phase 7.1 foundation to implement 8 interconnected Ash resources that represent a realistic invoicing system with customers, products, and financial transactions.

The implementation will use the ETS data layer for zero-configuration demonstration while showcasing advanced Ash Framework features including calculations, aggregates, relationships, and comprehensive validations.

## Technical Analysis

### Ash Framework Integration
- **Resource Patterns**: All resources follow Ash Framework declarative patterns
- **ETS Data Layer**: Configured for all resources to enable zero-dependency demonstration  
- **Relationship Management**: Foreign key relationships properly managed through Ash
- **Domain Configuration**: Resources registered in the AshReportsDemo.Domain module
- **Advanced Features**: Calculations, aggregates, custom queries, and validations

### ETS Data Layer Benefits
- **Zero Configuration**: No database setup required for demonstration
- **In-Memory Performance**: Fast operations for demo scenarios
- **Resource Compatibility**: Full Ash resource feature support
- **Testing Simplicity**: Clean state management for test scenarios

## Problem Definition

### Business Domain Requirements
The AshReportsDemo requires a realistic business invoicing system that demonstrates:

1. **Customer Management**: Customer profiles with addresses and types
2. **Product Catalog**: Products with categories and inventory tracking
3. **Financial Transactions**: Invoices with line items and payment tracking
4. **Business Intelligence**: Calculations for lifetime value, profitability analysis
5. **Data Relationships**: Complex inter-resource relationships for reporting

### Technical Challenges
- **Resource Interdependencies**: 8 resources with multiple relationship types
- **Calculation Complexity**: Advanced Ash calculations for business metrics
- **ETS Configuration**: Proper ETS data layer setup for all resources
- **Validation Logic**: Comprehensive business rule validation
- **Testing Scope**: Resource-level and relationship validation testing

## Solution Architecture

### Domain Model Structure
```
AshReportsDemo.Customer (1) ──── (*) AshReportsDemo.CustomerAddress
    │                                              │
    │ (*)                                          │ (1)
    │                                              │
AshReportsDemo.CustomerType (1) ──── (*) ──────── │
                                                   │
AshReportsDemo.Invoice (1) ──────── (*) AshReportsDemo.InvoiceLineItem (*) ──── (1) AshReportsDemo.Product
    │                                                                                        │
    │ (*)                                                                                   │ (1)
    │                                                                                        │
    └─────────────── AshReportsDemo.Customer (1)                                    AshReportsDemo.ProductCategory (1)
                                                                                              │
                                                                                              │ (1)
                                                                                              │
                                                                                      AshReportsDemo.Inventory (*)
```

### Resource Specifications

#### 1. Customer Resource
```elixir
# lib/ash_reports_demo/resources/customer.ex
defmodule AshReportsDemo.Customer do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :customers
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :email, :string, allow_nil?: false
    attribute :phone, :string
    attribute :status, :atom, default: :active, constraints: [one_of: [:active, :inactive, :suspended]]
    attribute :credit_limit, :decimal, default: Decimal.new("5000.00")
    attribute :created_at, :utc_datetime_usec, default: &DateTime.utc_now/0
    attribute :updated_at, :utc_datetime_usec, default: &DateTime.utc_now/0
  end

  relationships do
    belongs_to :customer_type, AshReportsDemo.CustomerType
    has_many :addresses, AshReportsDemo.CustomerAddress
    has_many :invoices, AshReportsDemo.Invoice
  end

  calculations do
    calculate :full_name, :string, expr(name)
    calculate :address_count, :integer, expr(count(addresses))
    calculate :lifetime_value, :decimal, expr(coalesce(sum(invoices, field: :total), 0))
    calculate :payment_score, :integer, expr(
      case do
        avg(invoices, field: :days_overdue) <= 0 -> 100
        avg(invoices, field: :days_overdue) <= 30 -> 80
        avg(invoices, field: :days_overdue) <= 60 -> 60
        true -> 40
      end
    )
  end

  aggregates do
    sum :total_invoice_amount, :invoices, :total
    count :invoice_count, :invoices
    max :last_invoice_date, :invoices, :date
  end

  validations do
    validate present([:name, :email])
    validate match(:email, ~r/\A[^@\s]+@[^@\s]+\z/)
    validate numericality(:credit_limit, greater_than: 0)
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :active do
      filter expr(status == :active)
    end

    read :high_value do
      argument :minimum_value, :decimal, default: Decimal.new("10000")
      filter expr(lifetime_value >= ^arg(:minimum_value))
      sort lifetime_value: :desc
    end
  end
end
```

#### 2. CustomerAddress Resource
```elixir
# lib/ash_reports_demo/resources/customer_address.ex
defmodule AshReportsDemo.CustomerAddress do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :customer_addresses
  end

  attributes do
    uuid_primary_key :id
    attribute :street_address, :string, allow_nil?: false
    attribute :city, :string, allow_nil?: false
    attribute :state, :string, allow_nil?: false
    attribute :postal_code, :string, allow_nil?: false
    attribute :country, :string, default: "US"
    attribute :address_type, :atom, default: :billing, constraints: [one_of: [:billing, :shipping, :both]]
    attribute :is_primary, :boolean, default: false
  end

  relationships do
    belongs_to :customer, AshReportsDemo.Customer
  end

  calculations do
    calculate :full_address, :string, expr(
      street_address <> ", " <> city <> ", " <> state <> " " <> postal_code
    )
  end

  validations do
    validate present([:street_address, :city, :state, :postal_code])
    validate match(:postal_code, ~r/^\d{5}(-\d{4})?$/)
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 3. CustomerType Resource  
```elixir
# lib/ash_reports_demo/resources/customer_type.ex
defmodule AshReportsDemo.CustomerType do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :customer_types
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :discount_percentage, :decimal, default: Decimal.new("0.00")
    attribute :credit_limit_multiplier, :decimal, default: Decimal.new("1.00")
  end

  relationships do
    has_many :customers, AshReportsDemo.Customer
  end

  aggregates do
    count :customer_count, :customers
    sum :total_customer_value, :customers, :lifetime_value
  end

  validations do
    validate present([:name])
    validate numericality(:discount_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 4. Product Resource
```elixir
# lib/ash_reports_demo/resources/product.ex
defmodule AshReportsDemo.Product do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :products
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :sku, :string, allow_nil?: false
    attribute :description, :string
    attribute :price, :decimal, allow_nil?: false
    attribute :cost, :decimal, allow_nil?: false
    attribute :weight, :decimal
    attribute :active, :boolean, default: true
    attribute :created_at, :utc_datetime_usec, default: &DateTime.utc_now/0
  end

  relationships do
    belongs_to :category, AshReportsDemo.ProductCategory
    has_many :invoice_line_items, AshReportsDemo.InvoiceLineItem
    has_one :inventory, AshReportsDemo.Inventory
  end

  calculations do
    calculate :margin, :decimal, expr(price - cost)
    calculate :margin_percentage, :decimal, expr(
      case do
        price > 0 -> ((price - cost) / price) * 100
        true -> 0
      end
    )
    calculate :profit_per_unit, :decimal, expr(price - cost)
    calculate :inventory_turnover, :decimal, expr(
      total_sold / max(current_stock, 1)
    )
    calculate :profitability_grade, :string, expr(
      case do
        margin_percentage >= 50 -> "A"
        margin_percentage >= 30 -> "B"
        margin_percentage >= 15 -> "C"
        true -> "D"
      end
    )
  end

  aggregates do
    sum :total_sold, :invoice_line_items, :quantity
    sum :total_revenue, :invoice_line_items, :total_price
  end

  validations do
    validate present([:name, :sku, :price, :cost])
    validate numericality(:price, greater_than: 0)
    validate numericality(:cost, greater_than_or_equal_to: 0)
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :active do
      filter expr(active == true)
    end

    read :low_stock do
      load :inventory
      filter expr(inventory.current_stock <= inventory.reorder_point)
    end

    read :profitable do
      argument :minimum_margin, :decimal, default: Decimal.new("30.00")
      filter expr(margin_percentage >= ^arg(:minimum_margin))
    end
  end
end
```

#### 5. ProductCategory Resource
```elixir
# lib/ash_reports_demo/resources/product_category.ex
defmodule AshReportsDemo.ProductCategory do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :product_categories
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :active, :boolean, default: true
  end

  relationships do
    has_many :products, AshReportsDemo.Product
  end

  aggregates do
    count :product_count, :products
    sum :total_category_revenue, :products, :total_revenue
    avg :average_product_price, :products, :price
  end

  validations do
    validate present([:name])
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 6. Inventory Resource
```elixir
# lib/ash_reports_demo/resources/inventory.ex
defmodule AshReportsDemo.Inventory do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :inventory
  end

  attributes do
    uuid_primary_key :id
    attribute :current_stock, :integer, default: 0
    attribute :reorder_point, :integer, default: 10
    attribute :max_stock, :integer, default: 1000
    attribute :last_restock_date, :date
    attribute :last_updated, :utc_datetime_usec, default: &DateTime.utc_now/0
  end

  relationships do
    belongs_to :product, AshReportsDemo.Product
  end

  calculations do
    calculate :stock_status, :string, expr(
      case do
        current_stock <= 0 -> "Out of Stock"
        current_stock <= reorder_point -> "Low Stock"
        current_stock >= max_stock -> "Overstock"
        true -> "In Stock"
      end
    )
    calculate :reorder_quantity, :integer, expr(max_stock - current_stock)
    calculate :days_since_restock, :integer, expr(
      fragment("DATE_PART('day', NOW() - ?)", last_restock_date)
    )
  end

  validations do
    validate numericality(:current_stock, greater_than_or_equal_to: 0)
    validate numericality(:reorder_point, greater_than: 0)
    validate numericality(:max_stock, greater_than: 0)
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :low_stock do
      filter expr(current_stock <= reorder_point)
    end

    read :out_of_stock do
      filter expr(current_stock <= 0)
    end
  end
end
```

#### 7. Invoice Resource
```elixir
# lib/ash_reports_demo/resources/invoice.ex
defmodule AshReportsDemo.Invoice do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :invoices
  end

  attributes do
    uuid_primary_key :id
    attribute :invoice_number, :string, allow_nil?: false
    attribute :date, :date, allow_nil?: false
    attribute :due_date, :date, allow_nil?: false
    attribute :status, :atom, default: :pending, constraints: [one_of: [:pending, :paid, :overdue, :cancelled]]
    attribute :subtotal, :decimal, allow_nil?: false
    attribute :tax_rate, :decimal, default: Decimal.new("0.08")
    attribute :tax_amount, :decimal
    attribute :total, :decimal, allow_nil?: false
    attribute :payment_date, :date
    attribute :notes, :string
  end

  relationships do
    belongs_to :customer, AshReportsDemo.Customer
    has_many :line_items, AshReportsDemo.InvoiceLineItem
  end

  calculations do
    calculate :days_overdue, :integer, expr(
      case do
        status == :overdue -> fragment("DATE_PART('day', NOW() - ?)", due_date)
        true -> 0
      end
    )
    calculate :payment_status, :string, expr(
      case do
        status == :paid -> "Paid"
        days_overdue > 0 -> "Overdue"
        fragment("DATE_PART('day', ? - NOW())", due_date) <= 7 -> "Due Soon"
        true -> "Current"
      end
    )
    calculate :line_item_count, :integer, expr(count(line_items))
    calculate :calculated_tax, :decimal, expr(subtotal * tax_rate)
  end

  aggregates do
    sum :total_line_amount, :line_items, :total_price
    count :item_count, :line_items
  end

  validations do
    validate present([:invoice_number, :date, :due_date, :subtotal, :total])
    validate numericality(:subtotal, greater_than: 0)
    validate numericality(:total, greater_than: 0)
    validate numericality(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :overdue do
      filter expr(status == :overdue)
      sort days_overdue: :desc
    end

    read :recent do
      argument :days, :integer, default: 30
      filter expr(date >= fragment("NOW() - INTERVAL '? days'", ^arg(:days)))
      sort date: :desc
    end

    read :by_date_range do
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false
      filter expr(date >= ^arg(:start_date) and date <= ^arg(:end_date))
    end
  end
end
```

#### 8. InvoiceLineItem Resource
```elixir
# lib/ash_reports_demo/resources/invoice_line_item.ex
defmodule AshReportsDemo.InvoiceLineItem do
  use Ash.Resource, domain: AshReportsDemo.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    table :invoice_line_items
  end

  attributes do
    uuid_primary_key :id
    attribute :quantity, :integer, allow_nil?: false
    attribute :unit_price, :decimal, allow_nil?: false
    attribute :total_price, :decimal, allow_nil?: false
    attribute :description, :string
    attribute :discount_percentage, :decimal, default: Decimal.new("0.00")
  end

  relationships do
    belongs_to :invoice, AshReportsDemo.Invoice
    belongs_to :product, AshReportsDemo.Product
  end

  calculations do
    calculate :line_total, :decimal, expr(quantity * unit_price)
    calculate :discount_amount, :decimal, expr(
      (quantity * unit_price) * (discount_percentage / 100)
    )
    calculate :net_total, :decimal, expr(
      (quantity * unit_price) - discount_amount
    )
  end

  validations do
    validate present([:quantity, :unit_price, :total_price])
    validate numericality(:quantity, greater_than: 0)
    validate numericality(:unit_price, greater_than: 0)
    validate numericality(:discount_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### ETS Data Layer Configuration

```elixir
# lib/ash_reports_demo/domain.ex
defmodule AshReportsDemo.Domain do
  use Ash.Domain

  resources do
    resource AshReportsDemo.Customer
    resource AshReportsDemo.CustomerAddress
    resource AshReportsDemo.CustomerType
    resource AshReportsDemo.Product
    resource AshReportsDemo.ProductCategory
    resource AshReportsDemo.Inventory
    resource AshReportsDemo.Invoice
    resource AshReportsDemo.InvoiceLineItem
  end
end
```

## Implementation Plan

### Week 1: Core Resources (Days 1-2)

#### Day 1: Foundation Resources
**Tasks:**
1. **Customer Resource Implementation**
   - Create basic resource structure with ETS configuration
   - Implement attributes, relationships, and basic actions
   - Add lifetime_value and payment_score calculations
   - Create comprehensive validations

2. **CustomerType Resource Implementation**  
   - Define customer type attributes and relationships
   - Add customer count and value aggregates
   - Implement discount and credit limit logic

3. **CustomerAddress Resource Implementation**
   - Create address resource with validation
   - Implement full_address calculation
   - Add relationship to Customer

**Deliverables:**
- `/lib/ash_reports_demo/resources/customer.ex`
- `/lib/ash_reports_demo/resources/customer_type.ex`  
- `/lib/ash_reports_demo/resources/customer_address.ex`
- Basic unit tests for each resource

#### Day 2: Product Catalog Resources
**Tasks:**
1. **Product Resource Implementation**
   - Create product resource with pricing attributes
   - Add margin and profitability calculations
   - Implement product-specific actions (active, profitable)

2. **ProductCategory Resource Implementation**
   - Define category structure and relationships
   - Add category-level aggregates

3. **Inventory Resource Implementation**
   - Create inventory tracking resource
   - Add stock status calculations
   - Implement reorder logic

**Deliverables:**
- `/lib/ash_reports_demo/resources/product.ex`
- `/lib/ash_reports_demo/resources/product_category.ex`
- `/lib/ash_reports_demo/resources/inventory.ex`
- Unit tests with relationship validation

### Week 2: Financial Resources (Days 3-4)

#### Day 3: Invoice System
**Tasks:**
1. **Invoice Resource Implementation**
   - Create invoice resource with financial attributes
   - Add overdue and payment status calculations
   - Implement date-based queries

2. **InvoiceLineItem Resource Implementation**
   - Create line item resource with pricing logic
   - Add discount and total calculations
   - Establish relationships with Invoice and Product

**Deliverables:**
- `/lib/ash_reports_demo/resources/invoice.ex`
- `/lib/ash_reports_demo/resources/invoice_line_item.ex`
- Financial calculation tests

#### Day 4: Integration and Testing
**Tasks:**
1. **Domain Configuration**
   - Register all resources in AshReportsDemo.Domain
   - Verify ETS table configuration
   - Test resource loading and compilation

2. **Relationship Testing**
   - Test all inter-resource relationships
   - Validate foreign key constraints
   - Test calculation dependencies

3. **Comprehensive Test Suite**
   - Resource-level unit tests
   - Relationship integration tests  
   - Calculation and aggregate tests
   - Performance validation tests

**Deliverables:**
- Updated `/lib/ash_reports_demo/domain.ex`
- Complete test suite in `/test/ash_reports_demo/resources/`
- Integration tests for resource relationships

## Testing Strategy

### Unit Testing Approach
```elixir
# test/ash_reports_demo/resources/customer_test.exs
defmodule AshReportsDemo.CustomerTest do
  use ExUnit.Case
  alias AshReportsDemo.{Customer, CustomerType, CustomerAddress}

  setup do
    # Reset ETS tables for clean test state
    :ets.delete_all_objects(:customers)
    :ets.delete_all_objects(:customer_types) 
    :ets.delete_all_objects(:customer_addresses)
    :ok
  end

  describe "customer creation and validation" do
    test "creates customer with valid attributes" do
      customer_type = create_customer_type("Premium")
      
      assert {:ok, customer} = Customer.create(%{
        name: "John Doe",
        email: "john@example.com", 
        phone: "555-1234",
        customer_type_id: customer_type.id
      })
      
      assert customer.name == "John Doe"
      assert customer.email == "john@example.com"
      assert customer.status == :active
    end

    test "validates required fields" do
      assert {:error, errors} = Customer.create(%{})
      assert has_error(errors, :name, "is required")
      assert has_error(errors, :email, "is required")
    end

    test "validates email format" do
      assert {:error, errors} = Customer.create(%{
        name: "Test User",
        email: "invalid-email"
      })
      assert has_error(errors, :email, "must be valid email format")
    end
  end

  describe "customer calculations" do
    test "calculates lifetime value from invoices" do
      customer = create_customer_with_invoices([
        %{total: Decimal.new("1000.00")},
        %{total: Decimal.new("1500.00")}
      ])
      
      loaded = Customer.get!(customer.id, load: [:lifetime_value])
      assert Decimal.eq?(loaded.lifetime_value, Decimal.new("2500.00"))
    end

    test "calculates payment score based on overdue invoices" do
      customer = create_customer_with_overdue_invoices(avg_days: 45)
      
      loaded = Customer.get!(customer.id, load: [:payment_score])
      assert loaded.payment_score == 40  # 45 days overdue = 40 score
    end
  end

  describe "customer relationships" do
    test "loads customer addresses" do
      customer = create_customer_with_addresses(2)
      
      loaded = Customer.get!(customer.id, load: [:addresses])
      assert length(loaded.addresses) == 2
      assert Enum.all?(loaded.addresses, &(&1.customer_id == customer.id))
    end

    test "loads customer invoices with line items" do
      customer = create_customer_with_invoices(3)
      
      loaded = Customer.get!(customer.id, load: [invoices: [:line_items]])
      assert length(loaded.invoices) == 3
      assert Enum.all?(loaded.invoices, &(length(&1.line_items) > 0))
    end
  end

  # Helper functions for test data creation
  defp create_customer_type(name) do
    CustomerType.create!(%{name: name, description: "Test type"})
  end

  defp create_customer_with_addresses(count) do
    customer = create_basic_customer()
    
    for i <- 1..count do
      CustomerAddress.create!(%{
        customer_id: customer.id,
        street_address: "#{i}00 Test St",
        city: "Test City",
        state: "TS", 
        postal_code: "12345"
      })
    end
    
    customer
  end

  defp has_error(errors, field, message) do
    Enum.any?(errors, fn error ->
      error.field == field && String.contains?(error.message, message)
    end)
  end
end
```

### Integration Testing Strategy
```elixir
# test/ash_reports_demo/integration/resource_relationships_test.exs
defmodule AshReportsDemo.Integration.ResourceRelationshipsTest do
  use ExUnit.Case
  
  alias AshReportsDemo.{
    Customer, CustomerType, CustomerAddress,
    Product, ProductCategory, Inventory,
    Invoice, InvoiceLineItem
  }

  setup do
    # Clean all ETS tables
    tables = [:customers, :customer_types, :customer_addresses,
              :products, :product_categories, :inventory,
              :invoices, :invoice_line_items]
    
    for table <- tables, do: :ets.delete_all_objects(table)
    :ok
  end

  test "complete business workflow integration" do
    # 1. Create customer type and customer
    customer_type = CustomerType.create!(%{
      name: "Premium",
      discount_percentage: Decimal.new("10.00")
    })
    
    customer = Customer.create!(%{
      name: "Acme Corp",
      email: "orders@acme.com",
      customer_type_id: customer_type.id
    })
    
    # 2. Create customer address
    address = CustomerAddress.create!(%{
      customer_id: customer.id,
      street_address: "123 Business St",
      city: "Commerce City", 
      state: "CO",
      postal_code: "80022"
    })
    
    # 3. Create product category and products
    category = ProductCategory.create!(%{
      name: "Office Supplies"
    })
    
    product1 = Product.create!(%{
      name: "Premium Paper",
      sku: "PAPER-001",
      price: Decimal.new("29.99"),
      cost: Decimal.new("15.00"),
      category_id: category.id
    })
    
    # 4. Create inventory
    inventory = Inventory.create!(%{
      product_id: product1.id,
      current_stock: 100,
      reorder_point: 20
    })
    
    # 5. Create invoice with line items
    invoice = Invoice.create!(%{
      customer_id: customer.id,
      invoice_number: "INV-001",
      date: Date.utc_today(),
      due_date: Date.add(Date.utc_today(), 30),
      subtotal: Decimal.new("59.98"),
      tax_amount: Decimal.new("4.80"),
      total: Decimal.new("64.78")
    })
    
    line_item = InvoiceLineItem.create!(%{
      invoice_id: invoice.id,
      product_id: product1.id,
      quantity: 2,
      unit_price: Decimal.new("29.99"),
      total_price: Decimal.new("59.98")
    })
    
    # 6. Verify all relationships work correctly
    loaded_customer = Customer.get!(customer.id, load: [
      :customer_type, :addresses, invoices: [:line_items]
    ])
    
    assert loaded_customer.customer_type.name == "Premium"
    assert length(loaded_customer.addresses) == 1
    assert hd(loaded_customer.addresses).city == "Commerce City"
    assert length(loaded_customer.invoices) == 1
    
    loaded_invoice = hd(loaded_customer.invoices)
    assert length(loaded_invoice.line_items) == 1
    assert hd(loaded_invoice.line_items).quantity == 2
    
    # 7. Test calculations work across relationships
    loaded_with_calcs = Customer.get!(customer.id, load: [:lifetime_value, :payment_score])
    assert Decimal.eq?(loaded_with_calcs.lifetime_value, Decimal.new("64.78"))
    assert loaded_with_calcs.payment_score == 100  # No overdue invoices
  end

  test "product profitability calculations" do
    category = ProductCategory.create!(%{name: "Test Category"})
    
    high_margin = Product.create!(%{
      name: "High Margin Product",
      sku: "HM-001", 
      price: Decimal.new("100.00"),
      cost: Decimal.new("30.00"),
      category_id: category.id
    })
    
    low_margin = Product.create!(%{
      name: "Low Margin Product",
      sku: "LM-001",
      price: Decimal.new("100.00"), 
      cost: Decimal.new("85.00"),
      category_id: category.id
    })
    
    # Test calculations
    high_loaded = Product.get!(high_margin.id, load: [:margin_percentage, :profitability_grade])
    low_loaded = Product.get!(low_margin.id, load: [:margin_percentage, :profitability_grade])
    
    assert Decimal.eq?(high_loaded.margin_percentage, Decimal.new("70.00"))
    assert high_loaded.profitability_grade == "A"
    
    assert Decimal.eq?(low_loaded.margin_percentage, Decimal.new("15.00"))
    assert low_loaded.profitability_grade == "C"
  end
end
```

### Performance Testing
```elixir
# test/ash_reports_demo/performance/resource_performance_test.exs
defmodule AshReportsDemo.Performance.ResourcePerformanceTest do
  use ExUnit.Case

  @tag :performance
  test "resource creation performance with relationships" do
    # Measure time to create 1000 customers with addresses and invoices
    {time_microseconds, _} = :timer.tc(fn ->
      for i <- 1..1000 do
        customer_type = create_customer_type("Type #{i}")
        customer = create_customer("Customer #{i}", customer_type.id)
        create_address(customer.id)
        create_invoice_with_items(customer.id, 3)  # 3 line items per invoice
      end
    end)
    
    time_seconds = time_microseconds / 1_000_000
    
    # Should create 1000 complete customer records in under 5 seconds
    assert time_seconds < 5.0, "Performance too slow: #{time_seconds}s"
    
    # Verify data was created correctly
    customer_count = Customer.list!() |> length()
    assert customer_count == 1000
  end

  @tag :performance  
  test "calculation performance with large datasets" do
    # Create test data
    setup_performance_data(500)  # 500 customers with invoices
    
    # Test lifetime value calculation performance
    {time, customers} = :timer.tc(fn ->
      Customer.list!(load: [:lifetime_value, :payment_score])
    end)
    
    # Should load 500 customers with calculations in under 2 seconds
    assert time < 2_000_000, "Calculation performance too slow: #{time}μs"
    assert length(customers) == 500
    
    # Verify calculations are working
    assert Enum.all?(customers, &(&1.lifetime_value != nil))
    assert Enum.all?(customers, &(&1.payment_score != nil))
  end

  defp setup_performance_data(customer_count) do
    for i <- 1..customer_count do
      customer_type = create_customer_type("Type #{rem(i, 5)}")  # 5 different types
      customer = create_customer("Customer #{i}", customer_type.id)
      
      # Create 2-5 invoices per customer
      invoice_count = :rand.uniform(4) + 1
      for _j <- 1..invoice_count do
        create_invoice_with_items(customer.id, :rand.uniform(3) + 1)
      end
    end
  end
end
```

## Quality Assurance

### Code Quality Standards
- **Zero Compilation Warnings**: All code must compile without warnings
- **Credo Compliance**: All code must pass Credo checks with zero issues
- **Documentation**: All public functions must have @doc annotations
- **Type Specifications**: All public functions should have @spec declarations
- **Test Coverage**: Minimum 95% test coverage for all resources

### Validation Checklist
- [ ] All 8 resources compile successfully
- [ ] ETS tables are properly configured
- [ ] All relationships load correctly
- [ ] Calculations produce expected results
- [ ] Aggregates work across relationships
- [ ] Custom actions return appropriate results
- [ ] Validations prevent invalid data
- [ ] Test suite passes completely
- [ ] Performance benchmarks meet requirements
- [ ] Credo passes with zero issues

### Error Handling
- Comprehensive validation error messages
- Graceful handling of relationship constraint violations
- Proper error propagation in calculations
- Clear error messages for business rule violations

## Success Criteria

### Functional Requirements
- [ ] All 8 resources implemented with complete functionality
- [ ] ETS data layer configured and operational for all resources
- [ ] Complex inter-resource relationships working correctly
- [ ] Advanced Ash features (calculations, aggregates) operational
- [ ] Comprehensive validations preventing invalid states
- [ ] Custom actions providing business-specific queries
- [ ] All resources registered in domain and loadable

### Performance Requirements
- [ ] Resource creation: <10ms per resource on average
- [ ] Relationship loading: <50ms for complex relationship graphs
- [ ] Calculation execution: <100ms for complex calculations
- [ ] Memory usage: Stable during large data operations
- [ ] ETS table performance: Sub-millisecond lookups

### Quality Requirements
- [ ] Zero compilation warnings across all resource files
- [ ] All Credo checks pass without issues  
- [ ] Test coverage ≥95% for all resource modules
- [ ] Comprehensive integration tests covering workflows
- [ ] Performance tests validating speed requirements
- [ ] Clear, comprehensive documentation for all resources

## Risk Mitigation

### Technical Risks
1. **ETS Configuration Issues**: Mitigated by comprehensive testing and validation
2. **Relationship Complexity**: Managed through incremental development and testing
3. **Calculation Performance**: Addressed by performance benchmarks and optimization
4. **Memory Usage**: Controlled through ETS table management and cleanup

### Implementation Risks  
1. **Resource Interdependencies**: Managed through careful ordering of implementation
2. **Test Data Setup**: Addressed by helper functions and clean test environments
3. **Validation Complexity**: Mitigated by comprehensive test coverage

## Conclusion

Phase 7.2 establishes the complete business domain foundation for AshReportsDemo, providing 8 interconnected resources that demonstrate the full power of the Ash Framework. The implementation showcases advanced features including calculations, aggregates, relationships, and validations while maintaining the simplicity of an ETS-based demonstration environment.

This phase enables the subsequent phases to build comprehensive reports and data generation systems on top of a robust, well-tested domain model that represents realistic business scenarios and relationships.