# Phase 7: Comprehensive Example Demo Implementation

**Duration: 2-3 weeks**  
**Goal: Create a complete working example demonstrating all ash_reports features with realistic business data**

## Overview

Phase 7 creates a comprehensive example demo of the ash_reports library that showcases all implemented features through a realistic business scenario. This example will serve as both documentation and validation of the library's capabilities, providing developers with a complete reference implementation.

The example will implement a business invoicing system with customers, products, and invoices, using an ETS data layer for simplicity while demonstrating all ash_reports features including hierarchical bands, variables, calculations, grouping, and multiple output formats.

## Phase 7.1: Project Structure and Dependencies ✅

### Implementation Tasks:
- [ ] 7.1.1 Create example directory structure
- [ ] 7.1.2 Add Faker dependency for realistic data generation
- [ ] 7.1.3 Set up example project configuration
- [ ] 7.1.4 Create base module structure

### Code Structure:
```
example/
├── lib/
│   ├── example/
│   │   ├── application.ex
│   │   ├── domain.ex
│   │   ├── resources/
│   │   │   ├── customer.ex
│   │   │   ├── customer_address.ex
│   │   │   ├── customer_type.ex
│   │   │   ├── product.ex
│   │   │   ├── product_category.ex
│   │   │   ├── inventory.ex
│   │   │   ├── invoice.ex
│   │   │   └── invoice_line_item.ex
│   │   ├── data_generator.ex
│   │   └── reports/
│   │       ├── customer_summary.ex
│   │       ├── product_inventory.ex
│   │       ├── invoice_details.ex
│   │       └── financial_summary.ex
│   └── example.ex
├── test/
│   ├── example/
│   │   ├── resources/
│   │   ├── reports/
│   │   └── integration/
│   └── test_helper.exs
├── config/
│   ├── config.exs
│   ├── dev.exs
│   └── test.exs
└── mix.exs
```

### Testing:
```elixir
# test/example/project_structure_test.exs
defmodule Example.ProjectStructureTest do
  use ExUnit.Case

  test "example module loads successfully" do
    assert Code.ensure_loaded?(Example)
    assert Code.ensure_loaded?(Example.Domain)
    assert Code.ensure_loaded?(Example.DataGenerator)
  end

  test "all example resources load successfully" do
    resources = [
      Example.Customer,
      Example.CustomerAddress,
      Example.CustomerType,
      Example.Product,
      Example.ProductCategory,
      Example.Inventory,
      Example.Invoice,
      Example.InvoiceLineItem
    ]

    for resource <- resources do
      assert Code.ensure_loaded?(resource), "Failed to load #{resource}"
    end
  end
end
```

## Phase 7.2: Domain Model and Resources ✅

### Implementation Tasks:
- [ ] 7.2.1 Create Customer resource with relationships
- [ ] 7.2.2 Create CustomerAddress resource
- [ ] 7.2.3 Create CustomerType resource
- [ ] 7.2.4 Create Product resource with inventory
- [ ] 7.2.5 Create ProductCategory resource
- [ ] 7.2.6 Create Inventory resource
- [ ] 7.2.7 Create Invoice and InvoiceLineItem resources
- [ ] 7.2.8 Configure ETS data layer for all resources

### Domain Model:
```
Customer (1) ──── (*) CustomerAddress
    │                     │
    │ (*)                 │ (1)
    │                     │
CustomerType (1) ──── (*) │
                          │
Invoice (1) ──────── (*) InvoiceLineItem (*) ──── (1) Product
    │                                                   │
    │ (*)                                              │ (1)
    │                                                   │
    └─────────────── Customer (1)               ProductCategory (1)
                                                        │
                                                        │ (1)
                                                        │
                                                 Inventory (*)
```

### Resource Specifications:

#### Customer Resource:
```elixir
# Key attributes: name, email, phone, status, credit_limit
# Relationships: has_many addresses, belongs_to customer_type, has_many invoices
# Calculations: full_name, address_count, total_outstanding
# Aggregates: total_invoice_amount, average_order_value, last_invoice_date
```

#### Product Resource:
```elixir
# Key attributes: name, sku, price, cost, active, weight
# Relationships: belongs_to category, has_many invoice_line_items, has_one inventory
# Calculations: margin, margin_percentage, profit_per_unit
# Aggregates: total_sold, current_stock, reorder_point
```

#### Invoice Resource:
```elixir
# Key attributes: invoice_number, date, due_date, status, subtotal, tax, total
# Relationships: belongs_to customer, has_many line_items
# Calculations: days_overdue, payment_status, line_item_count
# Aggregates: total_amount, tax_amount, outstanding_balance
```

### Testing:
```elixir
# test/example/resources/customer_test.exs
defmodule Example.CustomerTest do
  use ExUnit.Case
  alias Example.{Customer, CustomerType, CustomerAddress}

  setup do
    # Setup test data with ETS
    Example.DataGenerator.reset_data()
    :ok
  end

  describe "customer creation and relationships" do
    test "creates customer with required attributes" do
      customer_type = create_customer_type("Premium")
      
      assert {:ok, customer} = Customer.create(%{
        name: "John Doe",
        email: "john@example.com",
        customer_type_id: customer_type.id
      })
      
      assert customer.name == "John Doe"
      assert customer.email == "john@example.com"
    end

    test "loads customer with addresses" do
      customer = create_customer_with_addresses()
      
      loaded = Customer.get!(customer.id, load: [:addresses])
      assert length(loaded.addresses) == 2
    end

    test "calculates customer aggregates" do
      customer = create_customer_with_invoices()
      
      loaded = Customer.get!(customer.id, load: [:total_invoice_amount])
      assert loaded.total_invoice_amount == Decimal.new("1500.00")
    end
  end
end
```

## Phase 7.3: Data Generation System ✅

### Implementation Tasks:
- [ ] 7.3.1 Create GenServer-based data generator
- [ ] 7.3.2 Implement Faker integration for realistic data
- [ ] 7.3.3 Create seed data functions for all resources
- [ ] 7.3.4 Implement relationship integrity management
- [ ] 7.3.5 Add data volume controls and configuration

### Data Generator Design:
```elixir
defmodule Example.DataGenerator do
  @moduledoc """
  GenServer that generates realistic test data using Faker library.
  
  Provides seeding functions for all example resources with proper
  relationship integrity and configurable data volumes.
  """
  
  use GenServer
  
  # Public API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def generate_sample_data(volume \\ :medium) do
    GenServer.call(__MODULE__, {:generate_data, volume})
  end
  
  def reset_data do
    GenServer.call(__MODULE__, :reset)
  end
  
  # Data generation specifications
  @data_volumes %{
    small: %{customers: 10, products: 50, invoices: 25},
    medium: %{customers: 100, products: 200, invoices: 500},
    large: %{customers: 1000, products: 2000, invoices: 10000}
  }
end
```

### Data Generation Features:
- **Realistic Names**: Using Faker for person and company names
- **Geographic Data**: Addresses with real cities, states, zip codes
- **Business Data**: SKUs, product names, pricing with realistic margins
- **Financial Data**: Invoice amounts, payment terms, tax calculations
- **Temporal Data**: Realistic date ranges, due dates, payment schedules
- **Relationship Integrity**: Proper foreign key relationships maintained

### Testing:
```elixir
# test/example/data_generator_test.exs
defmodule Example.DataGeneratorTest do
  use ExUnit.Case
  alias Example.DataGenerator

  setup do
    {:ok, _pid} = start_supervised(DataGenerator)
    :ok
  end

  test "generates small dataset successfully" do
    assert :ok = DataGenerator.generate_sample_data(:small)
    
    customers = Example.Customer.list!()
    products = Example.Product.list!()
    invoices = Example.Invoice.list!()
    
    assert length(customers) == 10
    assert length(products) == 50
    assert length(invoices) == 25
  end

  test "maintains relationship integrity" do
    DataGenerator.generate_sample_data(:small)
    
    invoice = Example.Invoice.list!(load: [:customer, :line_items]) |> hd()
    
    assert invoice.customer != nil
    assert length(invoice.line_items) > 0
    
    # Verify all line items reference valid products
    for line_item <- invoice.line_items do
      assert line_item.product_id != nil
      assert Example.Product.get!(line_item.product_id)
    end
  end

  test "generates realistic data patterns" do
    DataGenerator.generate_sample_data(:medium)
    
    customers = Example.Customer.list!()
    
    # Test realistic email patterns
    email_domains = customers |> Enum.map(&(&1.email)) |> Enum.map(fn email ->
      email |> String.split("@") |> List.last()
    end) |> Enum.uniq()
    
    assert length(email_domains) > 5  # Multiple realistic domains
    assert "example.com" in email_domains
    assert "gmail.com" in email_domains
  end
end
```

## Phase 7.4: Advanced Ash Features Implementation ✅

### Implementation Tasks:
- [ ] 7.4.1 Add comprehensive calculations to all resources
- [ ] 7.4.2 Implement aggregates for reporting needs
- [ ] 7.4.3 Create custom Ash queries for complex scenarios
- [ ] 7.4.4 Add policy-based authorization examples
- [ ] 7.4.5 Implement resource-level validations and constraints

### Advanced Features:

#### Calculations:
```elixir
# Customer calculations
calculate :lifetime_value, :decimal, expr(
  coalesce(sum(invoices, field: :total), 0)
)

calculate :payment_score, :integer, expr(
  case do
    avg(invoices, field: :days_overdue) <= 0 -> 100
    avg(invoices, field: :days_overdue) <= 30 -> 80
    avg(invoices, field: :days_overdue) <= 60 -> 60
    true -> 40
  end
)

# Product calculations
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
```

#### Complex Queries:
```elixir
# High-value customers query
read :high_value_customers do
  argument :minimum_value, :decimal, default: Decimal.new("10000")
  filter expr(lifetime_value >= ^arg(:minimum_value))
  sort lifetime_value: :desc
end

# Overdue invoices with customer info
read :overdue_with_customer_details do
  argument :days_overdue, :integer, default: 30
  filter expr(days_overdue > ^arg(:days_overdue))
  load [:customer, :line_items]
  sort days_overdue: :desc
end

# Low stock products requiring reorder
read :reorder_needed do
  filter expr(current_stock <= reorder_point and active == true)
  load [:category, :supplier_info]
  sort [:category, :name]
end
```

### Testing:
```elixir
# test/example/advanced_features_test.exs
defmodule Example.AdvancedFeaturesTest do
  use ExUnit.Case
  alias Example.{Customer, Product, Invoice}

  setup do
    Example.DataGenerator.generate_sample_data(:medium)
    :ok
  end

  describe "calculations" do
    test "customer lifetime value calculation" do
      customer = create_customer_with_invoices(invoice_total: Decimal.new("5000"))
      loaded = Customer.get!(customer.id, load: [:lifetime_value])
      
      assert Decimal.eq?(loaded.lifetime_value, Decimal.new("5000"))
    end

    test "product profitability grade calculation" do
      high_margin_product = create_product(price: 100, cost: 30)  # 70% margin
      low_margin_product = create_product(price: 100, cost: 90)   # 10% margin
      
      high_loaded = Product.get!(high_margin_product.id, load: [:profitability_grade])
      low_loaded = Product.get!(low_margin_product.id, load: [:profitability_grade])
      
      assert high_loaded.profitability_grade == "A"
      assert low_loaded.profitability_grade == "D"
    end
  end

  describe "complex queries" do
    test "high value customers query" do
      _low_value = create_customer_with_invoices(invoice_total: Decimal.new("5000"))
      high_value = create_customer_with_invoices(invoice_total: Decimal.new("15000"))
      
      results = Customer.high_value_customers!(minimum_value: Decimal.new("10000"))
      
      assert length(results) == 1
      assert hd(results).id == high_value.id
    end

    test "overdue invoices query" do
      _current = create_invoice(days_old: 10)
      overdue = create_invoice(days_old: 45)
      
      results = Invoice.overdue_with_customer_details!(days_overdue: 30)
      
      assert length(results) == 1
      assert hd(results).id == overdue.id
      assert hd(results).customer != nil
    end
  end
end
```

## Phase 7.5: Comprehensive Report Definitions ✅

### Implementation Tasks:
- [ ] 7.5.1 Create Customer Summary Report (all band types)
- [ ] 7.5.2 Create Product Inventory Report (grouping, variables)
- [ ] 7.5.3 Create Invoice Details Report (master-detail)
- [ ] 7.5.4 Create Financial Summary Report (calculations, aggregates)
- [ ] 7.5.5 Implement all output formats for each report
- [ ] 7.5.6 Add interactive features and filters

### Report Specifications:

#### Customer Summary Report:
```elixir
report :customer_summary do
  title "Customer Summary Report"
  description "Comprehensive customer analysis with addresses and payment history"
  driving_resource Example.Customer
  
  parameters do
    parameter :customer_type, :string
    parameter :region, :string  
    parameter :min_lifetime_value, :decimal
    parameter :include_inactive, :boolean, default: false
  end

  variables do
    variable :customer_count, :count,
      expression: expr(1),
      reset_on: :report
      
    variable :total_lifetime_value, :sum,
      expression: expr(lifetime_value),
      reset_on: :report
      
    variable :region_count, :count,
      expression: expr(1),
      reset_on: :group,
      reset_group: 1
      
    variable :region_lifetime_value, :sum,
      expression: expr(lifetime_value),
      reset_on: :group,
      reset_group: 1
  end

  groups do
    group :region, expr(addresses.state), level: 1
    group :customer_type, expr(customer_type.name), level: 2
  end

  bands do
    band :title do
      type :title
      elements do
        label :report_title do
          text "Customer Summary Report"
          position x: 0, y: 0, width: 100, height: 30
          style font_size: 18, font_weight: :bold, text_align: :center
        end
        
        expression :report_date do
          source expr("Generated on: " <> ^DateTime.utc_now() |> DateTime.to_string())
          position x: 0, y: 35, width: 100, height: 15
          style font_size: 12, text_align: :center
        end
      end
    end

    band :page_header do
      type :page_header
      elements do
        label :name_header do
          text "Customer Name"
          position x: 0, y: 0, width: 25, height: 20
          style font_weight: :bold
        end
        
        label :email_header do
          text "Email"
          position x: 25, y: 0, width: 25, height: 20
          style font_weight: :bold
        end
        
        label :lifetime_value_header do
          text "Lifetime Value"
          position x: 50, y: 0, width: 25, height: 20
          style font_weight: :bold, text_align: :right
        end
        
        label :payment_score_header do
          text "Payment Score"
          position x: 75, y: 0, width: 25, height: 20
          style font_weight: :bold, text_align: :right
        end
      end
    end

    band :group_header do
      type :group_header
      group_level 1
      on_entry expr(reset_variable(:region_count))
      on_entry expr(reset_variable(:region_lifetime_value))
      
      elements do
        label :region_label do
          text "Region:"
          position x: 0, y: 0, width: 15, height: 20
          style font_weight: :bold
        end
        
        field :region_name do
          source expr(addresses.state)
          position x: 15, y: 0, width: 30, height: 20
          style font_weight: :bold
        end
      end
    end

    band :group_header do
      type :group_header  
      group_level 2
      
      elements do
        label :type_label do
          text "Customer Type:"
          position x: 10, y: 0, width: 20, height: 20
          style font_weight: :bold
        end
        
        field :customer_type_name do
          source expr(customer_type.name)
          position x: 30, y: 0, width: 25, height: 20
          style font_weight: :bold
        end
      end
    end

    band :detail do
      type :detail
      
      elements do
        field :customer_name do
          source :name
          position x: 0, y: 0, width: 25, height: 15
        end
        
        field :customer_email do
          source :email
          position x: 25, y: 0, width: 25, height: 15
        end
        
        field :lifetime_value do
          source :lifetime_value
          position x: 50, y: 0, width: 25, height: 15
          format currency: :USD
          style text_align: :right
        end
        
        field :payment_score do
          source :payment_score
          position x: 75, y: 0, width: 25, height: 15
          style text_align: :right
        end
      end
    end

    band :group_footer do
      type :group_footer
      group_level 2
      
      elements do
        label :type_total_label do
          text "Type Total:"
          position x: 25, y: 0, width: 25, height: 15
          style font_weight: :bold
        end
        
        # Customer type totals would be calculated here
      end
    end

    band :group_footer do
      type :group_footer
      group_level 1
      
      elements do
        label :region_total_label do
          text "Region Total:"
          position x: 10, y: 0, width: 25, height: 15
          style font_weight: :bold
        end
        
        variable :region_count_display do
          source :region_count
          position x: 35, y: 0, width: 15, height: 15
          style font_weight: :bold, text_align: :right
        end
        
        variable :region_value_display do
          source :region_lifetime_value
          position x: 50, y: 0, width: 25, height: 15
          format currency: :USD
          style font_weight: :bold, text_align: :right
        end
      end
    end

    band :summary do
      type :summary
      
      elements do
        label :grand_total_label do
          text "Grand Total:"
          position x: 0, y: 0, width: 35, height: 20
          style font_size: 14, font_weight: :bold
        end
        
        variable :total_customers do
          source :customer_count
          position x: 35, y: 0, width: 15, height: 20
          style font_size: 14, font_weight: :bold, text_align: :right
        end
        
        variable :grand_total_value do
          source :total_lifetime_value
          position x: 50, y: 0, width: 25, height: 20
          format currency: :USD
          style font_size: 14, font_weight: :bold, text_align: :right
        end
      end
    end
  end
end
```

#### Financial Summary Report:
```elixir
report :financial_summary do
  title "Financial Performance Summary"
  description "Revenue, profitability, and payment analysis"
  driving_resource Example.Invoice
  
  parameters do
    parameter :start_date, :date, required: true
    parameter :end_date, :date, required: true
    parameter :include_pending, :boolean, default: false
  end

  scope fn params ->
    Example.Invoice
    |> Ash.Query.filter(date >= ^params.start_date and date <= ^params.end_date)
    |> Ash.Query.filter(if ^params.include_pending, do: true, else: status != :pending)
    |> Ash.Query.load([:customer, :line_items])
    |> Ash.Query.sort([:date, :invoice_number])
  end

  # Complex variables and calculations for financial metrics
  variables do
    variable :total_revenue, :sum, expression: expr(total), reset_on: :report
    variable :total_tax, :sum, expression: expr(tax_amount), reset_on: :report
    variable :invoice_count, :count, expression: expr(1), reset_on: :report
    variable :average_invoice, :average, expression: expr(total), reset_on: :report
    
    # Monthly grouping variables  
    variable :monthly_revenue, :sum, expression: expr(total), reset_on: :group, reset_group: 1
    variable :monthly_count, :count, expression: expr(1), reset_on: :group, reset_group: 1
  end

  groups do
    group :month, expr(fragment("date_trunc('month', ?)", date)), level: 1
    group :status, expr(status), level: 2
  end

  # Comprehensive band structure showcasing all features
  bands do
    band :title do
      type :title
      elements do
        label :main_title do
          text "Financial Performance Summary"
          position x: 0, y: 0, width: 100, height: 25
          style font_size: 20, font_weight: :bold, text_align: :center
        end
        
        expression :period_display do
          source expr("Period: " <> ^params.start_date <> " to " <> ^params.end_date)
          position x: 0, y: 30, width: 100, height: 15
          style font_size: 12, text_align: :center
        end
      end
    end

    # ... additional bands for complete financial reporting
  end
end
```

### Testing:
```elixir
# test/example/reports/comprehensive_reports_test.exs
defmodule Example.Reports.ComprehensiveReportsTest do
  use ExUnit.Case
  alias Example.Domain

  setup do
    Example.DataGenerator.generate_sample_data(:medium)
    :ok
  end

  describe "customer summary report" do
    test "generates report in all formats" do
      formats = [:html, :pdf, :heex, :json]
      
      for format <- formats do
        assert {:ok, result} = AshReports.Runner.run_report(
          Domain,
          :customer_summary,
          %{},
          format: format
        )
        
        assert result.content != nil
        assert result.metadata.format == format
        assert result.metadata.record_count > 0
      end
    end

    test "applies parameters correctly" do
      assert {:ok, filtered_result} = AshReports.Runner.run_report(
        Domain,
        :customer_summary,
        %{customer_type: "Premium"},
        format: :json
      )
      
      assert {:ok, unfiltered_result} = AshReports.Runner.run_report(
        Domain,
        :customer_summary,
        %{},
        format: :json
      )
      
      filtered_data = Jason.decode!(filtered_result.content)
      unfiltered_data = Jason.decode!(unfiltered_result.content)
      
      assert length(filtered_data["data"]) < length(unfiltered_data["data"])
    end

    test "calculates variables correctly" do
      assert {:ok, result} = AshReports.Runner.run_report(
        Domain,
        :customer_summary,
        %{},
        format: :json
      )
      
      data = Jason.decode!(result.content)
      
      assert data["variables"]["customer_count"] > 0
      assert data["variables"]["total_lifetime_value"] != "0.00"
      assert data["groups"] |> length() > 0
    end

    test "processes all band types correctly" do
      assert {:ok, result} = AshReports.Runner.run_report(
        Domain,
        :customer_summary,
        %{},
        format: :html
      )
      
      html = result.content
      
      # Verify all band types are present
      assert html =~ "Customer Summary Report"  # title band
      assert html =~ "Customer Name"           # page header
      assert html =~ "Region:"                 # group header
      assert html =~ "@"                       # detail band (email addresses)
      assert html =~ "Region Total:"           # group footer
      assert html =~ "Grand Total:"            # summary band
    end
  end

  describe "financial summary report" do
    test "handles date range parameters" do
      start_date = Date.add(Date.utc_today(), -90)
      end_date = Date.utc_today()
      
      assert {:ok, result} = AshReports.Runner.run_report(
        Domain,
        :financial_summary,
        %{start_date: start_date, end_date: end_date},
        format: :json
      )
      
      data = Jason.decode!(result.content)
      assert data["metadata"]["parameters"]["start_date"] == Date.to_string(start_date)
      assert data["metadata"]["parameters"]["end_date"] == Date.to_string(end_date)
    end

    test "calculates financial metrics correctly" do
      # Create known test data
      invoice1 = create_invoice(total: Decimal.new("1000.00"), tax: Decimal.new("80.00"))
      invoice2 = create_invoice(total: Decimal.new("1500.00"), tax: Decimal.new("120.00"))
      
      assert {:ok, result} = AshReports.Runner.run_report(
        Domain,
        :financial_summary,
        %{
          start_date: Date.add(Date.utc_today(), -1),
          end_date: Date.utc_today()
        },
        format: :json
      )
      
      data = Jason.decode!(result.content)
      
      assert data["variables"]["total_revenue"] == "2500.00"
      assert data["variables"]["total_tax"] == "200.00"
      assert data["variables"]["invoice_count"] == 2
    end
  end
end
```

## Phase 7.6: Integration and Documentation ✅

### Implementation Tasks:
- [ ] 7.6.1 Create comprehensive integration tests
- [ ] 7.6.2 Add performance benchmarks with realistic data
- [ ] 7.6.3 Create detailed documentation and usage examples
- [ ] 7.6.4 Add interactive demo scripts
- [ ] 7.6.5 Create deployment and setup instructions

### Integration Testing:
```elixir
# test/integration/complete_workflow_test.exs
defmodule Example.Integration.CompleteWorkflowTest do
  use ExUnit.Case
  
  @tag :integration
  test "complete business scenario workflow" do
    # 1. Generate realistic business data
    Example.DataGenerator.generate_sample_data(:large)
    
    # 2. Run all reports in all formats
    reports = [:customer_summary, :product_inventory, :invoice_details, :financial_summary]
    formats = [:html, :pdf, :heex, :json]
    
    results = for report <- reports, format <- formats do
      case run_report_with_timing(report, format) do
        {:ok, result, timing} -> 
          {report, format, :success, timing, byte_size(result.content)}
        {:error, reason} -> 
          {report, format, :error, reason, 0}
      end
    end
    
    # 3. Verify all reports generated successfully
    errors = Enum.filter(results, fn {_, _, status, _, _} -> status == :error end)
    assert errors == [], "Some reports failed: #{inspect(errors)}"
    
    # 4. Performance assertions
    avg_timing = results 
      |> Enum.map(fn {_, _, _, timing, _} -> timing end) 
      |> Enum.sum() 
      |> div(length(results))
    
    assert avg_timing < 5000, "Average report generation time too slow: #{avg_timing}ms"
    
    # 5. Content size assertions
    total_size = results |> Enum.map(fn {_, _, _, _, size} -> size end) |> Enum.sum()
    assert total_size > 100_000, "Total generated content suspiciously small"
  end

  @tag :integration
  test "concurrent report generation" do
    Example.DataGenerator.generate_sample_data(:medium)
    
    # Generate 20 concurrent reports
    tasks = for i <- 1..20 do
      Task.async(fn ->
        AshReports.Runner.run_report(
          Example.Domain,
          :customer_summary,
          %{region: Enum.random(["North", "South", "East", "West"])},
          format: Enum.random([:html, :pdf, :json])
        )
      end)
    end
    
    results = Task.await_many(tasks, 30_000)
    
    # All should succeed
    successes = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    assert successes == 20, "Only #{successes}/20 concurrent reports succeeded"
  end
end
```

### Performance Benchmarks:
```elixir
# test/benchmarks/report_performance_test.exs
defmodule Example.Benchmarks.ReportPerformanceTest do
  use ExUnit.Case
  import Benchee

  @tag :benchmark
  test "report generation performance benchmarks" do
    # Setup different data sizes
    data_sizes = [:small, :medium, :large]
    
    for size <- data_sizes do
      Example.DataGenerator.reset_data()
      Example.DataGenerator.generate_sample_data(size)
      
      Benchee.run(
        %{
          "customer_summary_html" => fn ->
            AshReports.Runner.run_report(
              Example.Domain,
              :customer_summary,
              %{},
              format: :html
            )
          end,
          "customer_summary_pdf" => fn ->
            AshReports.Runner.run_report(
              Example.Domain,
              :customer_summary,
              %{},
              format: :pdf
            )
          end,
          "financial_summary_json" => fn ->
            AshReports.Runner.run_report(
              Example.Domain,
              :financial_summary,
              %{
                start_date: Date.add(Date.utc_today(), -90),
                end_date: Date.utc_today()
              },
              format: :json
            )
          end
        },
        time: 10,
        memory_time: 2,
        formatters: [
          Benchee.Formatters.HTML,
          Benchee.Formatters.Console
        ],
        html: [file: "benchmarks/results_#{size}.html"]
      )
    end
  end
end
```

### Documentation Structure:
```markdown
# Example Documentation Structure

example/
├── README.md                    # Quick start and overview
├── docs/
│   ├── setup.md                 # Installation and configuration
│   ├── domain_model.md          # Business model explanation  
│   ├── reports/
│   │   ├── customer_summary.md  # Detailed report documentation
│   │   ├── financial_summary.md
│   │   ├── product_inventory.md
│   │   └── invoice_details.md
│   ├── data_generation.md       # How to use the data generator
│   ├── performance.md           # Performance characteristics
│   └── deployment.md            # Production deployment guide
└── examples/
    ├── basic_usage.exs          # Simple usage examples
    ├── advanced_features.exs    # Complex report scenarios
    └── custom_reports.exs       # Creating custom reports
```

## Phase 7 Integration Tests ✅

```elixir
# test/integration/phase7_integration_test.exs
defmodule AshReports.Phase7IntegrationTest do
  use ExUnit.Case

  @moduledoc """
  Complete integration test for Phase 7 Example Demo.
  
  Validates the entire example implementation including:
  - Domain model and resources
  - Data generation system  
  - Report definitions and rendering
  - All output formats
  - Performance characteristics
  """

  setup_all do
    # Ensure example application is started
    {:ok, _} = Application.ensure_all_started(:example)
    
    # Generate comprehensive test data
    Example.DataGenerator.generate_sample_data(:medium)
    
    :ok
  end

  test "complete example domain functionality" do
    # 1. Verify all resources are properly configured
    domain_resources = Example.Domain.Info.resources()
    expected_resources = [
      Example.Customer,
      Example.CustomerAddress,
      Example.CustomerType,
      Example.Product,
      Example.ProductCategory,
      Example.Inventory,
      Example.Invoice,
      Example.InvoiceLineItem
    ]
    
    for resource <- expected_resources do
      assert resource in domain_resources, "#{resource} not found in domain"
    end
    
    # 2. Verify all reports are properly registered
    domain_reports = AshReports.Info.reports(Example.Domain)
    expected_reports = [:customer_summary, :product_inventory, :invoice_details, :financial_summary]
    
    for report_name <- expected_reports do
      assert Enum.find(domain_reports, &(&1.name == report_name)), 
        "Report #{report_name} not found"
    end
    
    # 3. Test data relationships and integrity
    customer = Example.Customer.list!(load: [:addresses, :invoices]) |> hd()
    assert length(customer.addresses) > 0
    assert length(customer.invoices) > 0
    
    invoice = hd(customer.invoices)
    loaded_invoice = Example.Invoice.get!(invoice.id, load: [:line_items])
    assert length(loaded_invoice.line_items) > 0
    
    # 4. Test all reports in all formats
    test_report_generation()
    
    # 5. Verify performance characteristics
    test_performance_requirements()
  end

  defp test_report_generation do
    reports = [:customer_summary, :financial_summary]
    formats = [:html, :pdf, :heex, :json]
    
    for report <- reports, format <- formats do
      params = case report do
        :financial_summary -> %{
          start_date: Date.add(Date.utc_today(), -30),
          end_date: Date.utc_today()
        }
        _ -> %{}
      end
      
      assert {:ok, result} = AshReports.Runner.run_report(
        Example.Domain,
        report,
        params,
        format: format
      )
      
      assert result.content != nil
      assert result.metadata.format == format
      
      # Format-specific validations
      case format do
        :html -> assert result.content =~ ~r/<html/i
        :pdf -> assert String.starts_with?(result.content, "%PDF")
        :json -> assert match?({:ok, _}, Jason.decode(result.content))
        :heex -> assert is_struct(result.content, Phoenix.LiveView.Rendered)
      end
    end
  end

  defp test_performance_requirements do
    # Small report should be fast
    {time, {:ok, _}} = :timer.tc(fn ->
      AshReports.Runner.run_report(
        Example.Domain,
        :customer_summary,
        %{customer_type: "Premium"},  # Filtered for smaller result set
        format: :html
      )
    end)
    
    # Should complete within 2 seconds for medium dataset
    assert time < 2_000_000, "Report generation too slow: #{time}μs"
  end
end
```

## Success Criteria ✅

### Functional Requirements:
- [ ] Complete example domain with 8 interconnected resources
- [ ] ETS data layer configuration for all resources  
- [ ] Faker-based realistic data generation system
- [ ] 4 comprehensive reports showcasing all ash_reports features
- [ ] All band types implemented (title, headers, detail, footers, summary)
- [ ] Variables, grouping, and calculations working correctly
- [ ] All 4 output formats (HTML, HEEX, PDF, JSON) functional
- [ ] Advanced Ash features (calculations, aggregates, queries)
- [ ] Comprehensive test coverage (>95%)

### Performance Requirements:
- [ ] Small dataset reports: <500ms generation time
- [ ] Medium dataset reports: <2s generation time  
- [ ] Large dataset reports: <10s generation time
- [ ] Memory usage remains stable during large reports
- [ ] Concurrent report generation support (20+ simultaneous)

### Quality Requirements:
- [ ] Zero compilation warnings
- [ ] All Credo checks pass
- [ ] Comprehensive documentation
- [ ] Integration tests cover end-to-end workflows
- [ ] Performance benchmarks included
- [ ] Clear setup and deployment instructions

## Deployment and Usage ✅

### Quick Start:
```bash
# Clone and setup
git clone <repository>
cd ash_reports/example
mix deps.get

# Generate sample data
iex -S mix
Example.DataGenerator.generate_sample_data(:medium)

# Run sample reports  
AshReports.Runner.run_report(Example.Domain, :customer_summary, %{}, format: :html)
AshReports.Runner.run_report(Example.Domain, :financial_summary, %{
  start_date: ~D[2024-01-01], 
  end_date: ~D[2024-12-31]
}, format: :pdf)
```

### Interactive Demo:
```elixir
# Start interactive session
Example.InteractiveDemo.start()

# Available commands:
Example.InteractiveDemo.run(:all_reports)
Example.InteractiveDemo.run(:customer_analysis)  
Example.InteractiveDemo.run(:financial_dashboard)
Example.InteractiveDemo.benchmark(:performance_test)
```

### Production Deployment:
```elixir
# config/prod.exs
config :example, Example.DataGenerator,
  auto_generate: false,  # Disable in production
  data_volume: :large

# Deployment checklist:
# 1. Configure ETS table persistence
# 2. Set up report caching  
# 3. Configure PDF generation service
# 4. Set up monitoring and logging
# 5. Configure backup and recovery
```

## Conclusion ✅

Phase 7 provides a comprehensive, production-ready example of ash_reports capabilities. The implementation demonstrates all library features through a realistic business scenario, serves as executable documentation, and provides performance benchmarks.

The example can be used for:
- **Developer onboarding**: Complete reference implementation
- **Feature validation**: Proof that all ash_reports features work together  
- **Performance testing**: Baseline for optimization efforts
- **Production template**: Starting point for real implementations
- **Training material**: Interactive learning environment

This phase completes the ash_reports library with a polished, professional demonstration that showcases the full power and flexibility of the reporting system.