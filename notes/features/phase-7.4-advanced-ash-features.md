# Phase 7.4: Advanced Ash Features

**Duration: 1-2 weeks**  
**Goal: Enhance AshReportsDemo with sophisticated Ash Framework features for business intelligence and advanced business logic**

## Overview

Phase 7.4 elevates the AshReportsDemo project by implementing advanced Ash Framework features that showcase the full sophistication of the framework. Building on the solid foundation of Phases 7.1-7.3 with complete resources and realistic data generation, this phase adds complex cross-resource calculations, sophisticated business intelligence queries, policy-based authorization, and advanced validation patterns.

The implementation demonstrates enterprise-grade features including customer lifetime value calculations based on actual invoice data, multi-dimensional business analytics, role-based access control, and complex business rule validation that spans multiple resources.

## Technical Analysis

### Advanced Ash Framework Patterns
- **Cross-Resource Calculations**: Complex calculations spanning multiple resources with sophisticated business logic
- **Advanced Aggregates**: Multi-level aggregates with filtering, grouping, and conditional logic
- **Custom Queries**: Business intelligence queries with complex filtering, sorting, and analytics
- **Policy Framework**: Authorization policies for realistic multi-user business scenarios
- **Advanced Validations**: Custom validation logic with cross-resource constraint checking
- **Resource Hooks**: Lifecycle management and automated business process triggers

### Current Foundation Assessment
- **Complete Domain Model**: 8 interconnected resources with basic calculations and aggregates
- **ETS Data Layer**: Zero-configuration demonstration environment with full Ash features
- **Data Generation**: Comprehensive Faker-based realistic business data across all resources
- **Basic Business Logic**: Foundation calculations, relationships, and validation rules

## Problem Definition

### Business Intelligence Requirements
The AshReportsDemo needs to showcase advanced business intelligence capabilities:

1. **Customer Analytics**: Sophisticated customer segmentation, lifetime value analysis, and payment behavior predictions
2. **Product Performance**: Advanced inventory analytics, profitability analysis, and sales trend calculations  
3. **Financial Intelligence**: Cash flow analysis, revenue forecasting, and payment risk assessment
4. **Cross-Resource Analytics**: Business metrics that span multiple resources with complex aggregation logic
5. **Authorization Scenarios**: Multi-user access control with role-based permissions for sensitive business data

### Technical Challenges
- **Performance Optimization**: Complex calculations must remain performant with large datasets
- **Calculation Dependencies**: Managing dependencies between calculations across multiple resources
- **Authorization Complexity**: Implementing realistic business authorization scenarios without over-engineering
- **Validation Logic**: Advanced business rules that maintain data integrity across resource boundaries
- **Testing Complexity**: Comprehensive testing of advanced features with realistic business scenarios

## Solution Architecture

### Advanced Calculations Framework

#### Customer Intelligence Module
```elixir
# Enhanced Customer resource with advanced calculations
defmodule AshReportsDemo.Customer do
  # ... existing configuration ...

  calculations do
    # Advanced lifetime value with trend analysis
    calculate :lifetime_value_trend, :map do
      description "Lifetime value trend analysis over time periods"
      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          trend_data = calculate_lifetime_value_trend(customer.id)
          {customer.id, trend_data}
        end)
        |> Map.new()
      end
    end

    # Customer segment classification
    calculate :customer_segment, :string do
      description "Customer segment based on value, frequency, and recency"
      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          segment = classify_customer_segment(customer)
          {customer.id, segment}
        end)
        |> Map.new()
      end
    end

    # Payment risk score with ML-style analysis
    calculate :payment_risk_score, :decimal do
      description "Advanced payment risk assessment (0.0-1.0)"
      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          risk_score = calculate_payment_risk(customer.id)
          {customer.id, risk_score}
        end)
        |> Map.new()
      end
    end

    # Customer health score
    calculate :customer_health_score, :integer do
      description "Overall customer relationship health (0-100)"
      calculation fn records, _context ->
        records
        |> Enum.map(fn customer ->
          health_score = calculate_customer_health(customer)
          {customer.id, health_score}
        end)
        |> Map.new()
      end
    end
  end

  # Advanced custom queries
  actions do
    # Customer segmentation query
    read :by_segment do
      description "Get customers by business segment"
      argument :segment, :string, allow_nil?: false
      filter expr(customer_segment == ^arg(:segment))
      sort [lifetime_value: :desc, created_at: :desc]
    end

    # At-risk customers query
    read :at_risk_customers do
      description "Customers at risk of churning or payment issues"
      argument :risk_threshold, :decimal, default: Decimal.new("0.7")
      filter expr(payment_risk_score >= ^arg(:risk_threshold))
      sort [payment_risk_score: :desc, lifetime_value: :desc]
    end

    # Customer cohort analysis query
    read :cohort_analysis do
      description "Customer cohort analysis by signup date"
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false
      filter expr(date(created_at) >= ^arg(:start_date) and date(created_at) <= ^arg(:end_date))
      load [:lifetime_value_trend, :customer_segment, :payment_risk_score]
    end
  end
end
```

#### Product Intelligence Module
```elixir
# Enhanced Product resource with advanced analytics
defmodule AshReportsDemo.Product do
  # ... existing configuration ...

  calculations do
    # Advanced inventory analytics
    calculate :inventory_velocity, :decimal do
      description "Product inventory velocity (units per day)"
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          velocity = calculate_inventory_velocity(product.id)
          {product.id, velocity}
        end)
        |> Map.new()
      end
    end

    # Profitability trend analysis
    calculate :profitability_trend, :map do
      description "Profitability trend over time periods"
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          trend = calculate_profitability_trend(product.id)
          {product.id, trend}
        end)
        |> Map.new()
      end
    end

    # Demand forecasting score
    calculate :demand_forecast, :map do
      description "Demand forecast based on historical patterns"
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          forecast = calculate_demand_forecast(product.id)
          {product.id, forecast}
        end)
        |> Map.new()
      end
    end

    # Product lifecycle stage
    calculate :lifecycle_stage, :string do
      description "Product lifecycle stage based on sales patterns"
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          stage = determine_lifecycle_stage(product.id)
          {product.id, stage}
        end)
        |> Map.new()
      end
    end
  end

  # Advanced product queries
  actions do
    # Underperforming products analysis
    read :underperforming do
      description "Products with declining performance metrics"
      filter expr(profitability_trend.current_month < profitability_trend.previous_month)
      sort [margin_percentage: :asc, inventory_velocity: :asc]
    end

    # High-opportunity products
    read :high_opportunity do
      description "Products with high growth potential"
      filter expr(demand_forecast.trend == "increasing" and lifecycle_stage == "growth")
      sort [demand_forecast.confidence: :desc]
    end

    # Inventory optimization candidates
    read :inventory_optimization do
      description "Products needing inventory optimization"
      load [:inventory, :inventory_velocity, :demand_forecast]
      filter expr(
        (inventory.current_stock > inventory.max_stock * 0.8 and inventory_velocity < 0.5) or
        (inventory.current_stock < inventory.reorder_point and demand_forecast.trend == "increasing")
      )
    end
  end
end
```

### Business Intelligence Query Engine

#### Financial Analytics Module
```elixir
# Advanced Invoice analytics
defmodule AshReportsDemo.Invoice do
  # ... existing configuration ...

  calculations do
    # Cash flow impact analysis
    calculate :cash_flow_impact, :decimal do
      description "Impact on cash flow considering payment terms"
      calculation fn records, _context ->
        records
        |> Enum.map(fn invoice ->
          impact = calculate_cash_flow_impact(invoice)
          {invoice.id, impact}
        end)
        |> Map.new()
      end
    end

    # Revenue recognition timeline
    calculate :revenue_recognition, :map do
      description "Revenue recognition schedule for this invoice"
      calculation fn records, _context ->
        records
        |> Enum.map(fn invoice ->
          schedule = calculate_revenue_recognition(invoice)
          {invoice.id, schedule}
        end)
        |> Map.new()
      end
    end

    # Collection probability
    calculate :collection_probability, :decimal do
      description "Probability of successful collection (0.0-1.0)"
      calculation fn records, _context ->
        records
        |> Enum.map(fn invoice ->
          probability = calculate_collection_probability(invoice)
          {invoice.id, probability}
        end)
        |> Map.new()
      end
    end
  end

  # Business intelligence queries
  actions do
    # Aging analysis query
    read :aging_analysis do
      description "Invoice aging analysis with risk assessment"
      load [:customer, :collection_probability, :cash_flow_impact]
      sort [days_overdue: :desc, total: :desc]
    end

    # Cash flow forecast query
    read :cash_flow_forecast do
      description "Projected cash flow from outstanding invoices"
      argument :forecast_days, :integer, default: 90
      filter expr(status in [:pending, :overdue] and due_date <= fragment("NOW() + INTERVAL '? days'", ^arg(:forecast_days)))
      load [:collection_probability, :revenue_recognition]
    end

    # Revenue analysis query
    read :revenue_analysis do
      description "Revenue analysis by time periods and segments"
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false
      argument :group_by, :atom, default: :month
      filter expr(date >= ^arg(:start_date) and date <= ^arg(:end_date))
      load [:customer, :line_items]
    end
  end
end
```

### Authorization Policy Framework

#### Multi-User Authorization System
```elixir
# User resource for authorization scenarios
defmodule AshReportsDemo.User do
  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_users
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :role, :atom, constraints: [one_of: [:admin, :manager, :sales, :finance, :readonly]]
    attribute :department, :string
    attribute :active, :boolean, default: true
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  identities do
    identity :unique_email, [:email]
  end
end

# Authorization policies for Customer resource
defmodule AshReportsDemo.Customer do
  # ... existing configuration ...

  policies do
    # Admin users have full access
    policy action_type(:*) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Managers can read and update customers
    policy action_type([:read, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Sales team can read customers and create new ones
    policy action_type([:read, :create]) do
      authorize_if actor_attribute_equals(:role, :sales)
    end

    # Finance team can read customers and view financial data
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :finance)
    end

    # Readonly users can only view basic customer information
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :readonly)
      # Restrict sensitive calculations for readonly users
      forbid_if accessing_calculation(:payment_risk_score)
      forbid_if accessing_calculation(:lifetime_value)
    end

    # Department-based data access restrictions
    policy action_type(:read) do
      # Users can only access customers assigned to their department
      filter_if actor_attribute_equals(:department, "regional"), expr(addresses.state in ^get_user_region_states(actor))
    end
  end

  # Field-level authorization
  field_policies do
    # Sensitive financial data restricted by role
    field_policy [:lifetime_value, :payment_risk_score, :credit_limit] do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :finance)
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Personal information protection
    field_policy [:email, :phone, :notes] do
      forbid_if actor_attribute_equals(:role, :readonly)
    end
  end
end
```

### Advanced Validation Framework

#### Cross-Resource Business Rules
```elixir
# Advanced validation system
defmodule AshReportsDemo.Customer do
  # ... existing configuration ...

  validations do
    # Existing basic validations ...

    # Advanced business rule validations
    validate {AshReportsDemo.Validations, :credit_limit_vs_customer_type} do
      description "Credit limit must align with customer type policies"
      where [changing(:credit_limit), changing(:customer_type_id)]
    end

    validate {AshReportsDemo.Validations, :customer_risk_assessment} do
      description "Customer risk level must be acceptable for activation"
      where [changing(:status)]
    end

    validate {AshReportsDemo.Validations, :geographic_compliance} do
      description "Customer location must comply with business operating regions"
      where [present(:addresses)]
    end
  end
end

# Custom validation module
defmodule AshReportsDemo.Validations do
  @moduledoc """
  Advanced custom validations for business logic enforcement.
  """

  def credit_limit_vs_customer_type(changeset, _opts) do
    credit_limit = Ash.Changeset.get_attribute(changeset, :credit_limit)
    customer_type_id = Ash.Changeset.get_attribute(changeset, :customer_type_id)

    if credit_limit && customer_type_id do
      customer_type = AshReportsDemo.CustomerType.get!(customer_type_id)
      max_allowed = Decimal.mult(customer_type.credit_limit_multiplier, Decimal.new("10000"))

      if Decimal.compare(credit_limit, max_allowed) == :gt do
        {:error, field: :credit_limit, message: "exceeds maximum allowed for customer type"}
      else
        :ok
      end
    else
      :ok
    end
  end

  def customer_risk_assessment(changeset, _opts) do
    status = Ash.Changeset.get_attribute(changeset, :status)

    if status == :active do
      # Calculate risk score and validate it's acceptable
      customer_id = changeset.data.id
      risk_score = calculate_customer_risk_score(customer_id)

      if Decimal.compare(risk_score, Decimal.new("0.8")) == :gt do
        {:error, field: :status, message: "customer risk too high for activation"}
      else
        :ok
      end
    else
      :ok
    end
  end

  def geographic_compliance(changeset, _opts) do
    # Validate customer addresses are in approved business regions
    addresses = Ash.Changeset.get_relationship(changeset, :addresses)

    if addresses do
      restricted_states = ["XX", "YY"]  # Example restricted regions

      invalid_addresses = 
        Enum.filter(addresses, fn addr -> 
          addr.state in restricted_states 
        end)

      if length(invalid_addresses) > 0 do
        {:error, field: :addresses, message: "contains addresses in restricted regions"}
      else
        :ok
      end
    else
      :ok
    end
  end

  # Helper functions for validation calculations
  defp calculate_customer_risk_score(customer_id) do
    # Complex risk calculation logic
    # Returns Decimal between 0.0 and 1.0
    Decimal.new("0.3")  # Placeholder
  end
end
```

### Resource Lifecycle Management

#### Automated Business Process Hooks
```elixir
# Enhanced Invoice resource with lifecycle hooks
defmodule AshReportsDemo.Invoice do
  # ... existing configuration ...

  changes do
    # Automated invoice processing
    change after_action(fn changeset, result, _context ->
      case changeset.action.name do
        :create ->
          # Trigger automated processes for new invoices
          trigger_invoice_created_workflow(result)
          
        :update when changeset.attributes.status == :paid ->
          # Process payment-related business logic
          trigger_payment_processing_workflow(result)
          
        :update when changeset.attributes.status == :overdue ->
          # Initiate collection processes
          trigger_collection_workflow(result)
          
        _ ->
          :ok
      end
      
      {:ok, result}
    end)

    # Automated inventory updates
    change after_action(fn changeset, result, _context ->
      if changeset.action.name == :create do
        # Update inventory based on invoice line items
        update_inventory_from_invoice(result)
      end
      
      {:ok, result}
    end)

    # Customer analytics updates
    change after_action(fn changeset, result, _context ->
      # Refresh customer analytics when invoices change
      refresh_customer_analytics(result.customer_id)
      {:ok, result}
    end)
  end

  # Automated workflow trigger functions
  defp trigger_invoice_created_workflow(invoice) do
    # Send notifications, update dashboards, etc.
    AshReportsDemo.Workflows.InvoiceCreated.execute(invoice)
  end

  defp trigger_payment_processing_workflow(invoice) do
    # Update financial records, send confirmations, etc.
    AshReportsDemo.Workflows.PaymentProcessed.execute(invoice)
  end

  defp trigger_collection_workflow(invoice) do
    # Initiate collection processes, update risk scores, etc.
    AshReportsDemo.Workflows.CollectionInitiated.execute(invoice)
  end

  defp update_inventory_from_invoice(invoice) do
    # Update inventory levels based on invoice line items
    AshReportsDemo.InventoryManager.process_invoice(invoice)
  end

  defp refresh_customer_analytics(customer_id) do
    # Refresh cached customer analytics
    AshReportsDemo.Analytics.refresh_customer_data(customer_id)
  end
end
```

## Implementation Plan

### Week 1: Advanced Calculations and Analytics (Days 1-3)

#### Day 1: Customer Intelligence Enhancement
**Focus: Advanced customer calculations and segmentation**

**Tasks:**
1. **Enhanced Customer Calculations**
   - Implement `lifetime_value_trend` calculation with time-based analysis
   - Add `customer_segment` classification logic (VIP, Standard, At-Risk, etc.)
   - Create `payment_risk_score` with advanced risk assessment
   - Implement `customer_health_score` combining multiple metrics

2. **Customer Business Intelligence Queries**
   - Create `by_segment` action for customer segmentation
   - Add `at_risk_customers` query with risk-based filtering  
   - Implement `cohort_analysis` for customer lifecycle analysis

3. **Testing Framework**
   - Unit tests for advanced customer calculations
   - Integration tests for business intelligence queries
   - Performance tests with large customer datasets

**Deliverables:**
- Enhanced `/lib/ash_reports_demo/resources/customer.ex`
- Customer intelligence helper module `/lib/ash_reports_demo/intelligence/customer_analytics.ex`
- Comprehensive test suite `/test/ash_reports_demo/intelligence/customer_analytics_test.exs`

#### Day 2: Product Intelligence and Inventory Analytics  
**Focus: Advanced product performance and inventory optimization**

**Tasks:**
1. **Product Intelligence Calculations**
   - Implement `inventory_velocity` calculation
   - Add `profitability_trend` with time-based analysis
   - Create `demand_forecast` using historical patterns
   - Implement `lifecycle_stage` determination logic

2. **Product Business Intelligence Queries**  
   - Create `underperforming` products analysis query
   - Add `high_opportunity` products identification
   - Implement `inventory_optimization` recommendations

3. **Inventory Intelligence Integration**
   - Enhanced inventory calculations in Inventory resource
   - Cross-resource analytics between Product and Inventory
   - Automated reorder point optimization

**Deliverables:**
- Enhanced `/lib/ash_reports_demo/resources/product.ex`
- Enhanced `/lib/ash_reports_demo/resources/inventory.ex`
- Product analytics module `/lib/ash_reports_demo/intelligence/product_analytics.ex`
- Test coverage `/test/ash_reports_demo/intelligence/product_analytics_test.exs`

#### Day 3: Financial Intelligence and Business Analytics
**Focus: Advanced financial calculations and cash flow analysis**

**Tasks:**
1. **Invoice Financial Intelligence**
   - Implement `cash_flow_impact` calculation
   - Add `revenue_recognition` timeline analysis
   - Create `collection_probability` assessment

2. **Financial Business Intelligence Queries**
   - Create `aging_analysis` with risk assessment
   - Add `cash_flow_forecast` projections
   - Implement `revenue_analysis` by segments and time periods

3. **Cross-Resource Financial Analytics**
   - Customer profitability analysis
   - Product contribution analysis
   - Financial trend analysis across all resources

**Deliverables:**
- Enhanced `/lib/ash_reports_demo/resources/invoice.ex`
- Financial analytics module `/lib/ash_reports_demo/intelligence/financial_analytics.ex`
- Business intelligence test suite `/test/ash_reports_demo/intelligence/financial_analytics_test.exs`

### Week 2: Authorization and Advanced Validation (Days 4-7)

#### Day 4: Multi-User Authorization Framework
**Focus: Implementing realistic business authorization scenarios**

**Tasks:**
1. **User Resource and Role Management**
   - Create User resource with role-based attributes
   - Implement role hierarchy and permissions
   - Add department-based access controls

2. **Customer Authorization Policies**
   - Role-based action permissions (admin, manager, sales, finance, readonly)
   - Field-level authorization for sensitive data
   - Department-based regional access controls

3. **Resource-Level Policy Implementation**
   - Apply policies to Product, Invoice, and other sensitive resources
   - Implement query-level authorization filters
   - Add calculation-level access controls

**Deliverables:**
- New `/lib/ash_reports_demo/resources/user.ex`
- Authorization policies added to all resources
- Policy testing framework `/test/ash_reports_demo/authorization/`

#### Day 5: Advanced Validation Framework
**Focus: Complex business rule validation across resources**

**Tasks:**
1. **Cross-Resource Validation Module**
   - Create custom validation module for complex business rules
   - Implement credit limit vs customer type validation
   - Add customer risk assessment validation
   - Create geographic compliance validation

2. **Advanced Business Rule Enforcement**  
   - Invoice total validation against customer credit limits
   - Product category restrictions based on customer type
   - Inventory level validation for order processing

3. **Validation Integration Testing**
   - Comprehensive validation test scenarios
   - Business rule violation testing
   - Performance testing for complex validations

**Deliverables:**
- Custom validation module `/lib/ash_reports_demo/validations.ex`
- Enhanced validation rules across all resources
- Validation test suite `/test/ash_reports_demo/validations/`

#### Day 6: Resource Lifecycle Management
**Focus: Automated business process triggers and workflow integration**

**Tasks:**
1. **Invoice Lifecycle Hooks**
   - Automated inventory updates on invoice creation
   - Payment processing triggers
   - Collection workflow automation
   - Customer analytics refresh triggers

2. **Customer Lifecycle Management**
   - Automated customer segmentation updates
   - Risk score recalculation triggers
   - Notification and alert systems

3. **Product Lifecycle Automation**
   - Inventory reorder automation
   - Product performance monitoring
   - Lifecycle stage transition triggers

**Deliverables:**
- Workflow modules in `/lib/ash_reports_demo/workflows/`
- Enhanced resources with lifecycle hooks
- Lifecycle management tests `/test/ash_reports_demo/workflows/`

#### Day 7: Integration Testing and Performance Optimization
**Focus: Comprehensive testing and performance validation**

**Tasks:**
1. **Advanced Features Integration Testing**
   - End-to-end business scenario testing
   - Multi-user authorization scenario testing
   - Complex validation business rule testing
   - Workflow automation testing

2. **Performance Optimization and Testing**
   - Performance testing for advanced calculations
   - Query optimization for business intelligence features
   - Memory usage validation for complex scenarios
   - Concurrent user scenario testing

3. **Documentation and Quality Assurance**
   - Comprehensive documentation for advanced features
   - Code review and Credo compliance validation
   - Test coverage analysis and improvement
   - Performance benchmarking and documentation

**Deliverables:**
- Comprehensive integration test suite
- Performance benchmark results
- Feature documentation in `/docs/advanced_features.md`
- Quality assurance validation report

## Testing Strategy

### Advanced Feature Testing Framework

#### Business Intelligence Testing
```elixir
# test/ash_reports_demo/intelligence/business_intelligence_test.exs
defmodule AshReportsDemo.Intelligence.BusinessIntelligenceTest do
  use ExUnit.Case
  alias AshReportsDemo.{Customer, Product, Invoice}

  setup do
    # Setup comprehensive test data
    AshReportsDemo.DataGenerator.generate_sample_data(:large)
    :ok
  end

  describe "customer intelligence" do
    test "calculates customer lifetime value trends accurately" do
      customer = create_customer_with_invoice_history()
      
      loaded = Customer.get!(customer.id, load: [:lifetime_value_trend])
      trend = loaded.lifetime_value_trend
      
      assert trend.current_quarter > 0
      assert trend.trend_direction in ["increasing", "stable", "decreasing"]
      assert is_number(trend.growth_rate)
    end

    test "correctly segments customers based on business rules" do
      # Create customers with different value profiles
      vip_customer = create_high_value_customer()
      standard_customer = create_standard_customer()
      at_risk_customer = create_at_risk_customer()
      
      # Load segments
      vip = Customer.get!(vip_customer.id, load: [:customer_segment])
      standard = Customer.get!(standard_customer.id, load: [:customer_segment])
      at_risk = Customer.get!(at_risk_customer.id, load: [:customer_segment])
      
      assert vip.customer_segment == "VIP"
      assert standard.customer_segment == "Standard" 
      assert at_risk.customer_segment == "At-Risk"
    end

    test "payment risk score correlates with payment history" do
      good_payer = create_customer_with_payment_history(:excellent)
      bad_payer = create_customer_with_payment_history(:poor)
      
      good_loaded = Customer.get!(good_payer.id, load: [:payment_risk_score])
      bad_loaded = Customer.get!(bad_payer.id, load: [:payment_risk_score])
      
      assert Decimal.compare(good_loaded.payment_risk_score, Decimal.new("0.3")) == :lt
      assert Decimal.compare(bad_loaded.payment_risk_score, Decimal.new("0.7")) == :gt
    end
  end

  describe "product intelligence" do
    test "inventory velocity calculation reflects actual sales patterns" do
      fast_moving = create_product_with_sales_history(:high_velocity)
      slow_moving = create_product_with_sales_history(:low_velocity)
      
      fast_loaded = Product.get!(fast_moving.id, load: [:inventory_velocity])
      slow_loaded = Product.get!(slow_moving.id, load: [:inventory_velocity])
      
      assert Decimal.compare(fast_loaded.inventory_velocity, slow_loaded.inventory_velocity) == :gt
      assert Decimal.compare(fast_loaded.inventory_velocity, Decimal.new("1.0")) == :gt
    end

    test "demand forecast accuracy with historical data" do
      product = create_product_with_seasonal_patterns()
      
      loaded = Product.get!(product.id, load: [:demand_forecast])
      forecast = loaded.demand_forecast
      
      assert forecast.next_month_projection > 0
      assert forecast.confidence >= 0.0 and forecast.confidence <= 1.0
      assert forecast.trend in ["increasing", "stable", "decreasing", "seasonal"]
    end
  end

  describe "financial intelligence" do
    test "cash flow impact calculation includes payment terms" do
      short_term_invoice = create_invoice(payment_terms: 15)
      long_term_invoice = create_invoice(payment_terms: 60)
      
      short_loaded = Invoice.get!(short_term_invoice.id, load: [:cash_flow_impact])
      long_loaded = Invoice.get!(long_term_invoice.id, load: [:cash_flow_impact])
      
      # Short-term invoices should have higher immediate cash flow impact
      assert Decimal.compare(short_loaded.cash_flow_impact, long_loaded.cash_flow_impact) == :gt
    end

    test "collection probability assessment accuracy" do
      good_customer_invoice = create_invoice_for_good_customer()
      risky_customer_invoice = create_invoice_for_risky_customer()
      
      good_loaded = Invoice.get!(good_customer_invoice.id, load: [:collection_probability])
      risky_loaded = Invoice.get!(risky_customer_invoice.id, load: [:collection_probability])
      
      assert Decimal.compare(good_loaded.collection_probability, Decimal.new("0.8")) == :gt
      assert Decimal.compare(risky_loaded.collection_probability, Decimal.new("0.5")) == :lt
    end
  end
end
```

#### Authorization Testing Framework
```elixir
# test/ash_reports_demo/authorization/multi_user_authorization_test.exs
defmodule AshReportsDemo.Authorization.MultiUserAuthorizationTest do
  use ExUnit.Case
  alias AshReportsDemo.{Customer, User}

  setup do
    # Create users with different roles
    admin = create_user(:admin)
    manager = create_user(:manager) 
    sales = create_user(:sales)
    finance = create_user(:finance)
    readonly = create_user(:readonly)
    
    # Create test data
    customer = create_customer()
    
    %{
      admin: admin,
      manager: manager,
      sales: sales, 
      finance: finance,
      readonly: readonly,
      customer: customer
    }
  end

  describe "role-based access control" do
    test "admin users have full access to all customer data", %{admin: admin, customer: customer} do
      # Admin can read all data including sensitive calculations
      assert {:ok, loaded} = Customer.get(customer.id, 
        actor: admin,
        load: [:lifetime_value, :payment_risk_score]
      )
      
      assert loaded.lifetime_value != nil
      assert loaded.payment_risk_score != nil
    end

    test "sales users can read customers but not sensitive financial data", %{sales: sales, customer: customer} do
      # Sales can read basic customer data
      assert {:ok, loaded} = Customer.get(customer.id, actor: sales)
      assert loaded.name != nil
      
      # But cannot access sensitive financial calculations
      assert {:error, _} = Customer.get(customer.id,
        actor: sales, 
        load: [:payment_risk_score]
      )
    end

    test "readonly users have limited access to customer data", %{readonly: readonly, customer: customer} do
      # Readonly can access basic information
      assert {:ok, loaded} = Customer.get(customer.id, actor: readonly)
      assert loaded.name != nil
      
      # But cannot access sensitive fields
      assert loaded.email == nil  # Field policy restriction
      assert loaded.lifetime_value == nil
    end

    test "finance users can access financial data but not modify customers", %{finance: finance, customer: customer} do
      # Finance can read financial calculations
      assert {:ok, loaded} = Customer.get(customer.id,
        actor: finance,
        load: [:lifetime_value, :payment_risk_score]
      )
      
      assert loaded.lifetime_value != nil
      assert loaded.payment_risk_score != nil
      
      # But cannot update customer records
      assert {:error, _} = Customer.update(customer, %{name: "New Name"}, actor: finance)
    end
  end

  describe "department-based access control" do
    test "regional users can only access customers in their region" do
      west_user = create_user(:sales, department: "west_region")
      east_user = create_user(:sales, department: "east_region")
      
      west_customer = create_customer_in_region("CA")  # West region
      east_customer = create_customer_in_region("NY")  # East region
      
      # West user can access west customer
      assert {:ok, _} = Customer.get(west_customer.id, actor: west_user)
      
      # But cannot access east customer
      assert {:error, _} = Customer.get(east_customer.id, actor: west_user)
      
      # East user can access east customer  
      assert {:ok, _} = Customer.get(east_customer.id, actor: east_user)
      
      # But cannot access west customer
      assert {:error, _} = Customer.get(west_customer.id, actor: east_user)
    end
  end

  describe "query-level authorization" do
    test "high-value customer queries respect user permissions" do
      admin = create_user(:admin)
      sales = create_user(:sales)
      
      # Admin can run high-value customer analysis
      assert {:ok, customers} = Customer.high_value(actor: admin, minimum_value: Decimal.new("50000"))
      assert is_list(customers)
      
      # Sales user might have restricted access to high-value analysis
      case Customer.high_value(actor: sales, minimum_value: Decimal.new("50000")) do
        {:ok, customers} -> 
          # If allowed, should return filtered results
          assert is_list(customers)
        {:error, _} ->
          # Or might be completely forbidden
          assert true
      end
    end
  end
end
```

#### Advanced Validation Testing
```elixir
# test/ash_reports_demo/validations/advanced_validation_test.exs
defmodule AshReportsDemo.Validations.AdvancedValidationTest do
  use ExUnit.Case
  alias AshReportsDemo.{Customer, CustomerType, Invoice}

  describe "cross-resource business rule validation" do
    test "credit limit validation against customer type" do
      # Create customer type with specific multiplier
      customer_type = CustomerType.create!(%{
        name: "Standard",
        credit_limit_multiplier: Decimal.new("2.0")  # Max 20k credit limit
      })
      
      # Valid credit limit should succeed
      assert {:ok, _customer} = Customer.create(%{
        name: "Test Customer",
        email: "test@example.com", 
        credit_limit: Decimal.new("15000.00"),
        customer_type_id: customer_type.id
      })
      
      # Excessive credit limit should fail
      assert {:error, errors} = Customer.create(%{
        name: "Test Customer 2",
        email: "test2@example.com",
        credit_limit: Decimal.new("25000.00"),  # Exceeds 20k limit
        customer_type_id: customer_type.id
      })
      
      assert has_validation_error(errors, :credit_limit, "exceeds maximum allowed")
    end

    test "customer risk assessment validation on activation" do
      # Create customer with poor payment history (would set high risk score)
      customer = create_customer_with_poor_history()
      
      # Attempt to activate high-risk customer should fail
      assert {:error, errors} = Customer.update(customer, %{status: :active})
      assert has_validation_error(errors, :status, "risk too high for activation")
      
      # Low-risk customer should activate successfully
      good_customer = create_customer_with_good_history()
      assert {:ok, _updated} = Customer.update(good_customer, %{status: :active})
    end

    test "geographic compliance validation" do
      # Create customer in restricted region
      restricted_address = %{
        street_address: "123 Test St",
        city: "Restricted City", 
        state: "XX",  # Restricted state
        postal_code: "12345"
      }
      
      assert {:error, errors} = Customer.create(%{
        name: "Restricted Customer",
        email: "restricted@example.com",
        addresses: [restricted_address]
      })
      
      assert has_validation_error(errors, :addresses, "restricted regions")
      
      # Customer in allowed region should succeed
      allowed_address = %{
        street_address: "456 Main St",
        city: "Allowed City",
        state: "CA",  # Allowed state
        postal_code: "90210"
      }
      
      assert {:ok, _customer} = Customer.create(%{
        name: "Allowed Customer",
        email: "allowed@example.com", 
        addresses: [allowed_address]
      })
    end
  end

  describe "complex invoice validation" do
    test "invoice total validation against customer credit limit" do
      customer = create_customer(credit_limit: Decimal.new("1000.00"))
      
      # Invoice within limit should succeed
      assert {:ok, _invoice} = Invoice.create(%{
        customer_id: customer.id,
        invoice_number: "INV-001",
        date: Date.utc_today(),
        due_date: Date.add(Date.utc_today(), 30),
        subtotal: Decimal.new("800.00"),
        total: Decimal.new("800.00")
      })
      
      # Invoice exceeding limit should fail
      assert {:error, errors} = Invoice.create(%{
        customer_id: customer.id,
        invoice_number: "INV-002", 
        date: Date.utc_today(),
        due_date: Date.add(Date.utc_today(), 30),
        subtotal: Decimal.new("1500.00"),
        total: Decimal.new("1500.00")
      })
      
      assert has_validation_error(errors, :total, "exceeds customer credit limit")
    end
  end

  defp has_validation_error(errors, field, message) do
    Enum.any?(errors, fn error ->
      error.field == field && String.contains?(error.message, message)
    end)
  end
end
```

### Performance Testing Framework

#### Advanced Feature Performance Testing
```elixir
# test/ash_reports_demo/performance/advanced_features_performance_test.exs
defmodule AshReportsDemo.Performance.AdvancedFeaturesPerformanceTest do
  use ExUnit.Case

  @tag :performance
  describe "advanced calculation performance" do
    test "customer intelligence calculations with large datasets" do
      # Create large dataset
      AshReportsDemo.DataGenerator.generate_sample_data(:large)
      
      # Test lifetime value trend calculation performance
      {time, customers} = :timer.tc(fn ->
        Customer.list!(load: [:lifetime_value_trend, :customer_segment, :payment_risk_score])
      end)
      
      # Should complete within reasonable time for large dataset
      assert time < 10_000_000, "Advanced calculations too slow: #{time}μs"
      assert length(customers) > 0
      
      # Verify all calculations were computed
      assert Enum.all?(customers, &(&1.lifetime_value_trend != nil))
      assert Enum.all?(customers, &(&1.customer_segment != nil))
    end

    test "business intelligence query performance" do
      AshReportsDemo.DataGenerator.generate_sample_data(:large)
      
      # Test complex business intelligence queries
      queries = [
        fn -> Customer.at_risk_customers!(risk_threshold: Decimal.new("0.5")) end,
        fn -> Customer.cohort_analysis!(start_date: ~D[2024-01-01], end_date: ~D[2024-12-31]) end,
        fn -> Product.underperforming!() end,
        fn -> Invoice.aging_analysis!() end
      ]
      
      for {query, index} <- Enum.with_index(queries) do
        {time, results} = :timer.tc(query)
        
        assert time < 5_000_000, "Query #{index} too slow: #{time}μs"
        assert is_list(results)
      end
    end
  end

  @tag :performance
  describe "authorization performance" do
    test "policy evaluation performance with large datasets" do
      AshReportsDemo.DataGenerator.generate_sample_data(:large)
      users = create_users_with_different_roles()
      
      for user <- users do
        {time, _results} = :timer.tc(fn ->
          Customer.list!(actor: user, load: [:lifetime_value])
        end)
        
        # Policy evaluation should not significantly impact query time
        assert time < 3_000_000, "Authorization too slow for #{user.role}: #{time}μs"
      end
    end
  end

  @tag :performance
  describe "validation performance" do
    test "complex validation performance" do
      # Test performance of advanced validation rules
      customer_type = create_customer_type()
      
      # Create many customers to test validation performance
      {time, _results} = :timer.tc(fn ->
        for i <- 1..100 do
          Customer.create!(%{
            name: "Customer #{i}",
            email: "customer#{i}@example.com",
            credit_limit: Decimal.new("#{5000 + i * 100}"),
            customer_type_id: customer_type.id
          })
        end
      end)
      
      # Should maintain reasonable performance even with complex validations
      assert time < 5_000_000, "Validation performance too slow: #{time}μs"
    end
  end

  defp create_users_with_different_roles do
    [:admin, :manager, :sales, :finance, :readonly]
    |> Enum.map(fn role ->
      User.create!(%{
        email: "#{role}@example.com",
        role: role,
        active: true
      })
    end)
  end
end
```

## Quality Assurance

### Code Quality Standards
- **Zero Compilation Warnings**: All advanced features must compile without warnings
- **Credo Compliance**: All code must pass Credo checks with advanced rule compliance
- **Documentation Standards**: All public functions, calculations, and policies must have comprehensive @doc annotations
- **Type Specifications**: All public functions should have detailed @spec declarations
- **Test Coverage**: Minimum 95% test coverage for all advanced features
- **Performance Benchmarks**: All advanced features must meet defined performance criteria

### Advanced Feature Validation Checklist
- [ ] All advanced customer calculations work correctly with realistic data
- [ ] Product intelligence features provide accurate business insights
- [ ] Financial analytics calculations are mathematically correct
- [ ] Authorization policies properly restrict access based on user roles
- [ ] Field-level authorization protects sensitive data appropriately
- [ ] Advanced validation rules enforce complex business logic
- [ ] Cross-resource validations maintain data integrity
- [ ] Resource lifecycle hooks trigger appropriate business processes
- [ ] Performance requirements met for all advanced features
- [ ] Memory usage remains stable during complex operations
- [ ] Concurrent user scenarios work correctly with authorization
- [ ] All advanced features are fully tested and documented

## Success Criteria

### Functional Requirements
- [ ] **Customer Intelligence**: Advanced customer segmentation, lifetime value analysis, and risk scoring operational
- [ ] **Product Intelligence**: Inventory analytics, profitability trends, and demand forecasting working
- [ ] **Financial Intelligence**: Cash flow analysis, collection probability, and revenue recognition implemented
- [ ] **Authorization Framework**: Multi-user role-based access control with field-level permissions operational
- [ ] **Advanced Validation**: Complex business rule validation across resources enforced
- [ ] **Lifecycle Management**: Automated business process triggers and workflow integration functional

### Performance Requirements
- [ ] **Calculation Performance**: Advanced calculations complete within 5 seconds for large datasets
- [ ] **Query Performance**: Business intelligence queries execute within 3 seconds
- [ ] **Authorization Performance**: Policy evaluation adds <500ms to query time
- [ ] **Validation Performance**: Complex validations complete within 100ms per record
- [ ] **Memory Efficiency**: Stable memory usage during concurrent advanced feature usage
- [ ] **Scalability**: All features remain performant with 10,000+ records

### Quality Requirements
- [ ] **Code Quality**: Zero compilation warnings, full Credo compliance
- [ ] **Test Coverage**: ≥95% coverage for all advanced features
- [ ] **Documentation**: Comprehensive documentation for all business intelligence features
- [ ] **Integration Testing**: End-to-end testing of complex business scenarios
- [ ] **Performance Testing**: Benchmarking of all advanced features under load
- [ ] **Security Testing**: Authorization and validation security scenario testing

## Risk Mitigation

### Technical Risks
1. **Calculation Complexity**: Managed through modular design and comprehensive testing
2. **Performance Impact**: Mitigated by performance benchmarking and optimization
3. **Authorization Complexity**: Controlled through clear policy design and testing
4. **Validation Dependencies**: Managed through careful dependency analysis and testing

### Implementation Risks
1. **Feature Scope Creep**: Controlled by focusing on core business intelligence features
2. **Performance Degradation**: Addressed through continuous performance monitoring
3. **Test Complexity**: Managed through helper functions and test data factories
4. **Integration Challenges**: Mitigated through incremental integration and testing

## Conclusion

Phase 7.4 transforms the AshReportsDemo from a basic domain model demonstration into a sophisticated showcase of advanced Ash Framework capabilities. The implementation demonstrates enterprise-grade features including complex business intelligence analytics, multi-user authorization scenarios, advanced validation patterns, and automated business process workflows.

This phase positions AshReportsDemo as a comprehensive reference implementation that demonstrates how the Ash Framework can power sophisticated business applications with advanced analytics, security, and business logic enforcement. The advanced features provide realistic business scenarios that developers can learn from and adapt to their own applications.

The completion of Phase 7.4 enables Phase 7.5 to build comprehensive reports that leverage these advanced business intelligence features, providing rich analytics and insights through the AshReports framework.