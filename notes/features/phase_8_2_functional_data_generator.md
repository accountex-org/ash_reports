# Phase 8.2: Functional DataGenerator System Implementation Plan

**Feature**: Transform DataGenerator from placeholder to fully functional data generation system  
**Priority**: Critical - Required for functional demo with realistic data  
**Estimated Time**: 2-3 days  
**Branch**: `feature/phase-8.2-functional-data-generator`

## Overview

Phase 8.2 transforms the AshReportsDemo.DataGenerator from a placeholder system that attempts to call undefined functions into a fully functional data generation system that:
- Uses actual Ash domain operations for all CRUD activities
- Maintains proper referential integrity across all demo resources
- Supports configurable data volumes (small/medium/large)
- Provides robust error handling and transaction management
- Generates realistic business data using Faker with proper relationships

## Current State Analysis

### Issues with Current DataGenerator:
- ❌ Calls to undefined methods in foundation data generation
- ❌ No transaction management for data consistency
- ❌ Missing error handling for data generation failures
- ❌ No proper cleanup/reset functionality
- ❌ Volume configuration not fully implemented
- ❌ Relationship integrity not guaranteed

### What Works:
- ✅ Basic structure with GenServer pattern
- ✅ Faker integration for realistic data
- ✅ Domain parameter usage in CRUD calls (fixed in 8.1)
- ✅ ETS data layer integration

## Implementation Tasks

### Task 8.2.1: Working Data Generation with Ash Operations

**Goal**: Make all data generation functions work with actual Ash domain operations

#### Subtasks:
- [ ] 8.2.1.1 Fix foundation data generation to handle existing records gracefully
- [ ] 8.2.1.2 Implement proper error handling for all CRUD operations
- [ ] 8.2.1.3 Add transaction management for data consistency
- [ ] 8.2.1.4 Create data validation during generation

#### Implementation Details:
```elixir
# Enhanced lib/ash_reports_demo/data_generator.ex
defmodule AshReportsDemo.DataGenerator do
  use GenServer
  require Logger

  # Public API with enhanced error handling
  def generate_sample_data(volume \\ :medium) do
    GenServer.call(__MODULE__, {:generate_sample_data, volume}, :timer.minutes(5))
  end

  def reset_data do
    GenServer.call(__MODULE__, :reset_data)
  end

  # Enhanced foundation data generation
  defp do_generate_foundation_data(volume_config) do
    with :ok <- ensure_clean_state(),
         {:ok, customer_types} <- create_customer_types(),
         {:ok, product_categories} <- create_product_categories() do
      Logger.info("Generated foundation data: #{length(customer_types)} customer types, #{length(product_categories)} categories")
      {:ok, %{customer_types: customer_types, categories: product_categories}}
    else
      {:error, reason} -> {:error, "Foundation data generation failed: #{reason}"}
    end
  end

  defp create_customer_types do
    customer_types = [
      %{name: "Bronze", description: "Basic customer tier", credit_limit_multiplier: Decimal.new("1.0"), 
        discount_percentage: Decimal.new("0"), active: true},
      %{name: "Silver", description: "Standard customer tier", credit_limit_multiplier: Decimal.new("1.5"), 
        discount_percentage: Decimal.new("5"), active: true},
      %{name: "Gold", description: "Premium customer tier", credit_limit_multiplier: Decimal.new("2.0"), 
        discount_percentage: Decimal.new("10"), active: true},
      %{name: "Platinum", description: "Elite customer tier", credit_limit_multiplier: Decimal.new("3.0"), 
        discount_percentage: Decimal.new("15"), active: true}
    ]

    results = for type_attrs <- customer_types do
      case AshReportsDemo.CustomerType.create(type_attrs, domain: AshReportsDemo.Domain) do
        {:ok, customer_type} -> customer_type
        {:error, error} -> 
          Logger.warn("Failed to create customer type #{type_attrs.name}: #{inspect(error)}")
          nil
      end
    end

    valid_types = Enum.reject(results, &is_nil/1)
    
    if length(valid_types) > 0 do
      {:ok, valid_types}
    else
      {:error, "Failed to create any customer types"}
    end
  end
end
```

#### Unit Tests:
```elixir
# test/ash_reports_demo/functional_data_generator_test.exs
defmodule AshReportsDemo.FunctionalDataGeneratorTest do
  use ExUnit.Case

  test "creates foundation data without errors" do
    AshReportsDemo.DataGenerator.reset_data()
    
    assert :ok = AshReportsDemo.DataGenerator.generate_foundation_data()
    
    {:ok, types} = AshReportsDemo.CustomerType.read(domain: AshReportsDemo.Domain)
    assert length(types) == 4
    assert Enum.find(types, &(&1.name == "Bronze"))
  end
end
```

### Task 8.2.2: Relationship Integrity Management

**Goal**: Ensure all generated data maintains proper foreign key relationships

#### Subtasks:
- [ ] 8.2.2.1 Implement referential integrity validation
- [ ] 8.2.2.2 Add cascade handling for data cleanup
- [ ] 8.2.2.3 Create relationship validation functions
- [ ] 8.2.2.4 Handle orphaned record cleanup

#### Implementation Details:
```elixir
# Enhanced relationship management
defp generate_customer_data_with_integrity(volume_config) do
  with {:ok, customer_types} <- get_available_customer_types(),
       {:ok, customers} <- create_customers_batch(customer_types, volume_config.customers),
       {:ok, addresses} <- create_addresses_for_customers(customers) do
    {:ok, %{customers: customers, addresses: addresses}}
  end
end

defp get_available_customer_types do
  case AshReportsDemo.CustomerType.read(domain: AshReportsDemo.Domain) do
    {:ok, []} -> {:error, "No customer types available - run foundation data first"}
    {:ok, types} -> {:ok, types}
    {:error, error} -> {:error, "Failed to load customer types: #{inspect(error)}"}
  end
end

defp validate_relationships do
  # Validate all customers have valid customer_type_id
  # Validate all addresses have valid customer_id
  # Validate all invoices have valid customer_id
  # Validate all line_items have valid invoice_id and product_id
end
```

### Task 8.2.3: Configurable Data Volumes

**Goal**: Implement proper volume configuration with realistic scaling

#### Subtasks:
- [ ] 8.2.3.1 Define volume configurations with realistic ratios
- [ ] 8.2.3.2 Implement proportional relationship scaling
- [ ] 8.2.3.3 Add performance monitoring for large volumes
- [ ] 8.2.3.4 Create memory-efficient generation for large datasets

#### Implementation Details:
```elixir
# Enhanced volume configuration
@data_volumes %{
  small: %{
    customer_types: 4,    # Fixed foundation data
    product_categories: 5, # Fixed foundation data
    customers: 25,
    products: 100,
    invoices: 75,
    addresses_per_customer: 1..2,
    line_items_per_invoice: 1..5
  },
  medium: %{
    customer_types: 4,
    product_categories: 5,
    customers: 100,
    products: 500,
    invoices: 300,
    addresses_per_customer: 1..3,
    line_items_per_invoice: 2..8
  },
  large: %{
    customer_types: 4,
    product_categories: 5,
    customers: 1000,
    products: 2000,
    invoices: 5000,
    addresses_per_customer: 1..4,
    line_items_per_invoice: 1..12
  }
}
```

### Task 8.2.4: GenServer-based Data Management

**Goal**: Enhance GenServer implementation for proper state management and monitoring

#### Subtasks:
- [ ] 8.2.4.1 Add comprehensive GenServer state management
- [ ] 8.2.4.2 Implement progress tracking and reporting
- [ ] 8.2.4.3 Add cancellation and cleanup capabilities
- [ ] 8.2.4.4 Create monitoring and metrics collection

#### Implementation Details:
```elixir
# Enhanced GenServer implementation
defmodule AshReportsDemo.DataGenerator do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :status,           # :idle, :generating, :error
      :current_operation,
      :progress,
      :volume_config,
      :generated_data,
      :errors,
      :start_time,
      :metrics
    ]
  end

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def generate_sample_data(volume \\ :medium) do
    GenServer.call(__MODULE__, {:generate_sample_data, volume}, :timer.minutes(10))
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def cancel_generation do
    GenServer.call(__MODULE__, :cancel_generation)
  end

  # Server callbacks with comprehensive state management
  @impl true
  def init(_opts) do
    {:ok, %State{
      status: :idle,
      current_operation: nil,
      progress: %{},
      generated_data: %{},
      errors: [],
      metrics: %{}
    }}
  end

  @impl true
  def handle_call({:generate_sample_data, volume}, _from, state) do
    case state.status do
      :generating ->
        {:reply, {:error, "Generation already in progress"}, state}
      
      _ ->
        new_state = %{state | 
          status: :generating, 
          volume_config: @data_volumes[volume],
          start_time: DateTime.utc_now(),
          errors: []
        }
        
        result = do_generate_all_data(new_state)
        
        final_state = %{state | 
          status: if(match?({:ok, _}, result), do: :idle, else: :error),
          current_operation: nil
        }
        
        {:reply, result, final_state}
    end
  end
end
```

## Testing Strategy

### Unit Tests (Each Component):
1. **Foundation Data Tests**: Customer types and product categories creation
2. **Customer Data Tests**: Customer and address generation with relationships
3. **Product Data Tests**: Product and inventory generation with categories
4. **Invoice Data Tests**: Invoice and line item generation with totals
5. **Volume Configuration Tests**: Different volume settings work correctly
6. **Error Handling Tests**: Graceful failure scenarios
7. **GenServer State Tests**: State management and progress tracking

### Integration Tests (Complete System):
1. **End-to-End Generation**: Complete dataset creation with all relationships
2. **Relationship Integrity**: All foreign keys are valid
3. **Data Quality**: Generated data is realistic and usable
4. **Performance Tests**: Large volume generation within time limits
5. **Cleanup Tests**: Reset functionality works correctly
6. **Concurrent Generation**: Multiple generation attempts handled correctly

## Success Criteria

### Functional Requirements:
- [ ] `AshReportsDemo.DataGenerator.generate_sample_data(:small)` creates 25 customers with relationships
- [ ] `AshReportsDemo.DataGenerator.generate_sample_data(:medium)` creates 100 customers with relationships  
- [ ] `AshReportsDemo.DataGenerator.generate_sample_data(:large)` creates 1000 customers with relationships
- [ ] All generated data maintains referential integrity
- [ ] Generated data is realistic using Faker library
- [ ] Reset functionality clears all data completely
- [ ] Error handling prevents partial/corrupted data states

### Performance Requirements:
- [ ] Small dataset generation: <2 seconds
- [ ] Medium dataset generation: <10 seconds  
- [ ] Large dataset generation: <60 seconds
- [ ] Memory usage remains stable during generation
- [ ] Progress reporting for long-running operations

### Quality Requirements:
- [ ] Zero Credo issues
- [ ] Zero compilation warnings
- [ ] >95% test coverage for DataGenerator module
- [ ] Comprehensive error handling
- [ ] Proper logging and monitoring

## Implementation Order

1. **Foundation Data Enhancement**: Robust customer type and category creation
2. **Customer Generation**: Customers with proper addresses and relationships
3. **Product Generation**: Products with inventory and category relationships
4. **Invoice Generation**: Invoices with line items and calculated totals
5. **Volume Configuration**: Proper scaling and configuration management
6. **GenServer Enhancement**: State management and progress tracking
7. **Error Handling**: Comprehensive error scenarios and recovery
8. **Testing**: Complete test coverage for all functionality
9. **Code Quality**: Credo compliance and warning elimination

This will establish a production-ready data generation system that creates realistic business data for comprehensive AshReports demonstration.