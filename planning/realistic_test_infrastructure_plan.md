# Realistic Test Infrastructure Implementation Plan

## Executive Summary

This document outlines the implementation of a comprehensive realistic testing infrastructure for the AshReports project. The goal is to transition from simple mock data testing to a robust, production-like testing strategy using real Ash resources, the DataGenerator for realistic test data, and the ETSDataLayer for in-memory storage.

## Problem Statement

### Current State

The AshReports project currently uses a simplified testing approach:

1. **Mock Data Strategy**
   - Uses plain Elixir maps and structs in `RendererTestHelpers` module
   - Functions like `build_mock_data()`, `build_mock_report()`, `build_render_context()`
   - Direct struct construction in tests with hardcoded values
   - No real Ash resources involved in most tests
   - Limited relationship testing
   - No realistic data patterns

2. **Limitations of Current Approach**
   - **Lack of Realism**: Test data doesn't reflect real-world scenarios with complex relationships
   - **Limited Coverage**: Cannot properly test Ash-specific features (calculations, aggregates, validations)
   - **Brittle Tests**: Changes to resource definitions don't surface in mock-based tests
   - **Integration Gaps**: Difficult to test cross-resource relationships and business logic
   - **Maintenance Burden**: Mock data must be manually updated when resources change
   - **Testing Confidence**: Lower confidence that tests reflect production behavior

3. **Recent Infrastructure Added**
   - **test/data/domain.ex**: Complete Ash domain with Customer, Invoice, Product resources
   - **test/data/data_generator.ex**: Sophisticated data generation (1,136 lines) using Faker library
   - **test/data/ets_data_layer.ex**: In-memory ETS storage for testing
   - **test/data/resources/**: 8 fully-defined Ash resources with relationships, calculations, aggregates

### Why Change Is Needed

1. **Test Quality**: Need tests that accurately represent production scenarios
2. **Feature Coverage**: Must test advanced Ash features (calculations, aggregates, validations, policies)
3. **Relationship Testing**: Need to verify complex multi-resource queries and relationships
4. **Data Integrity**: Must test referential integrity and business rules
5. **Confidence**: Higher confidence that tests reflect actual system behavior
6. **Maintainability**: Automatic synchronization with resource definitions

## Solution Overview

### High-Level Approach

Create a new test helper module (`AshReports.RealisticTestHelpers`) that provides:

1. **Easy Setup**: Simple functions to initialize realistic test data
2. **ETS Lifecycle**: Automatic setup/teardown of ETS tables for test isolation
3. **Data Scenarios**: Pre-configured scenarios (small, medium, large datasets)
4. **Resource Access**: Convenient helpers to query and create Ash resources
5. **Integration**: Seamless integration with existing `RendererTestHelpers`
6. **Performance**: Fast in-memory operations suitable for test suites

### Key Design Decisions

1. **Complementary, Not Replacement**: Keep existing `RendererTestHelpers` for simple unit tests
2. **ETS Isolation**: Each test gets clean ETS state via ExUnit setup blocks
3. **Lazy Loading**: Generate data on-demand to avoid slow test startup
4. **Scenario-Based**: Predefined scenarios for common testing needs
5. **GenServer Management**: Ensure DataGenerator and ETSDataLayer are properly supervised
6. **Module Organization**: Clear separation between setup, data generation, and query helpers

### Architecture

```
test/support/
├── realistic_test_helpers.ex          # Main helper module (NEW)
├── renderer_test_helpers.ex           # Existing mock helpers (KEEP)
└── ...

test/data/
├── domain.ex                           # Ash domain (EXISTS)
├── data_generator.ex                   # Data generation (EXISTS)
├── ets_data_layer.ex                   # ETS storage (EXISTS)
└── resources/                          # Ash resources (EXISTS)
    ├── customer.ex
    ├── invoice.ex
    ├── product.ex
    └── ...
```

## Technical Details

### Dependencies

**Required (Missing):**
- `faker` (~> 0.18) - For realistic test data generation (currently used but not in deps)

**Already Available:**
- `ash` (~> 3.0) - Core Ash framework
- `mox` (~> 1.1) - Mocking support
- `stream_data` (~> 1.0) - Property-based testing
- `ex_unit` - Test framework

### File Locations

**New Files:**
- `/home/pcharbon/code/ash_reports/test/support/realistic_test_helpers.ex`

**Modified Files:**
- `/home/pcharbon/code/ash_reports/mix.exs` - Add Faker dependency
- `/home/pcharbon/code/ash_reports/test/test_helper.exs` - Integrate new helpers

**Existing Files Used:**
- `/home/pcharbon/code/ash_reports/test/data/domain.ex`
- `/home/pcharbon/code/ash_reports/test/data/data_generator.ex`
- `/home/pcharbon/code/ash_reports/test/data/ets_data_layer.ex`
- `/home/pcharbon/code/ash_reports/test/data/resources/*.ex` (8 resource files)
- `/home/pcharbon/code/ash_reports/test/support/renderer_test_helpers.ex` (for integration)

### Integration with Existing Code

1. **With RendererTestHelpers**
   - `RealisticTestHelpers` can convert Ash resources to the format expected by `RendererTestHelpers`
   - Provide adapter functions like `to_render_context/2`
   - Allow mixing realistic data with mock report definitions

2. **With ExUnit**
   - Provide setup functions that can be used in `setup` blocks
   - Automatic cleanup via `on_exit` callbacks
   - Support for `async: true` tests with proper ETS table isolation

3. **With DataGenerator**
   - Wrap DataGenerator GenServer calls with convenient helper functions
   - Provide synchronous wrappers for test-friendly API
   - Cache generated data within test module scope when appropriate

4. **With ETSDataLayer**
   - Automatic table initialization and cleanup
   - Per-test table isolation using unique table names
   - Statistics and debugging helpers

## Agent Consultations Performed

### Research Summary

Based on the codebase analysis, I identified the following key patterns and best practices:

**Ash Testing Patterns:**
1. Ash resources in test environment use ETS data layer via `data_layer: Ash.DataLayer.Ets`
2. Resources define `ets do table :table_name end` for table configuration
3. Ash domain must be properly initialized before resource queries
4. Code interface functions (`define :create, :read, :update, :destroy`) provide convenient API
5. Tests should use `Ash.read/2`, `Ash.create/2` with `domain: Domain` option

**ETS Data Layer Best Practices:**
1. ETS tables should be `:public, :named_table` for test access
2. GenServer manages table lifecycle (create in `init`, cleanup in `terminate`)
3. Use `:read_concurrency, :write_concurrency` for better performance
4. Clear all tables between test scenarios for isolation
5. Monitor memory and table size for performance testing

**ExUnit Integration Patterns:**
1. Use `setup` and `setup_all` for resource initialization
2. `on_exit` callbacks for cleanup ensure proper teardown
3. `async: true` requires careful ETS table naming to avoid conflicts
4. Helper modules in `test/support/` automatically compiled via `elixirc_paths(:test)`
5. `test_helper.exs` loads support files and configures ExUnit

**Current Testing Infrastructure:**
- RendererTestHelpers: Mock-based, uses plain maps/structs
- TestHelpers: General testing utilities
- MockDataLayer: Simplified data layer for basic tests
- TestResources: Simple Ash resources for testing
- Domain configured with AshReportsDemo for demo/test resources

**DataGenerator Capabilities:**
- Configurable volumes: `:small`, `:medium`, `:large`
- Referential integrity validation
- Realistic data using Faker library
- Transaction-like generation with rollback on failure
- GenServer-based with timeout management
- Generates: CustomerType, ProductCategory, Customer, CustomerAddress, Product, Inventory, Invoice, InvoiceLineItem

## Success Criteria

### Functional Requirements

1. **Easy Initialization**
   - Single function call to set up realistic test data
   - Multiple data scenarios available (empty, small, medium, large)
   - Works seamlessly in ExUnit setup blocks
   - Support for both `setup` and `setup_all` contexts

2. **Data Generation**
   - Generate realistic Customer, Invoice, Product data
   - Maintain referential integrity across all resources
   - Support for custom data volumes
   - Deterministic generation for reproducible tests

3. **Query Helpers**
   - Convenient functions to query resources (e.g., `get_customers/1`, `find_invoice/1`)
   - Support for Ash query filters and parameters
   - Aggregate and calculation helpers
   - Relationship loading utilities

4. **ETS Management**
   - Automatic table creation and cleanup
   - Per-test isolation (support for `async: true`)
   - Memory and performance monitoring
   - Clear error messages when setup fails

5. **Integration**
   - Works with existing RendererTestHelpers
   - Compatible with mock-based tests
   - Doesn't break any existing tests
   - Can be adopted gradually

### Non-Functional Requirements

1. **Performance**
   - Small scenario setup < 100ms
   - Medium scenario setup < 1 second
   - Large scenario setup < 5 seconds
   - Cleanup < 50ms

2. **Maintainability**
   - Clear, documented API
   - Consistent naming conventions
   - Good error messages
   - Examples in module documentation

3. **Reliability**
   - No flaky tests due to race conditions
   - Proper cleanup even on test failures
   - Clear separation of concerns
   - Comprehensive test coverage

### Test Coverage Goals

1. **Unit Tests for RealisticTestHelpers**
   - ETS lifecycle management
   - Data generation scenarios
   - Query helper functions
   - Error handling

2. **Integration Tests**
   - Used in actual renderer tests
   - Works with RendererTestHelpers
   - Cross-resource queries
   - Complex relationships

3. **Example Usage**
   - Document in test file or README
   - Show common patterns
   - Demonstrate best practices

## Implementation Plan

### Phase 1: Foundation (Essential Infrastructure)

**Goal:** Set up basic infrastructure without breaking existing tests

#### Step 1.1: Add Faker Dependency
- **File:** `/home/pcharbon/code/ash_reports/mix.exs`
- **Changes:**
  - Add `{:faker, "~> 0.18", only: [:test, :dev]}` to deps
  - Run `mix deps.get`
- **Validation:** `mix compile` succeeds, `Faker.Commerce.product_name()` works in iex

#### Step 1.2: Create RealisticTestHelpers Module Skeleton
- **File:** `/home/pcharbon/code/ash_reports/test/support/realistic_test_helpers.ex`
- **Implement:**
  ```elixir
  defmodule AshReports.RealisticTestHelpers do
    @moduledoc """
    Test helpers for realistic testing with Ash resources and ETS data layer.

    Provides utilities for:
    - Setting up realistic test data using DataGenerator
    - Managing ETS lifecycle for test isolation
    - Querying Ash resources conveniently
    - Converting between Ash resources and mock formats
    """

    # Module structure with function stubs
  end
  ```
- **Basic Structure:**
  - Public API section (setup, teardown)
  - Data generation section
  - Query helpers section
  - Conversion utilities section
  - Private implementation section

#### Step 1.3: Update test_helper.exs
- **File:** `/home/pcharbon/code/ash_reports/test/test_helper.exs`
- **Changes:**
  - Add `Code.require_file("support/realistic_test_helpers.ex", __DIR__)`
  - Add `Code.require_file("data/domain.ex", __DIR__)`
  - Add `Code.require_file("data/data_generator.ex", __DIR__)`
  - Add `Code.require_file("data/ets_data_layer.ex", __DIR__)`
  - Ensure proper ordering (data layer before domain before generator)
- **Note:** test/data/*.ex files must be loadable in test environment

#### Step 1.4: Verify Foundation
- **Test:** Create simple test file using new helpers
- **Check:** `mix test` passes for new test
- **Check:** Existing tests still pass
- **Check:** ETS tables are created and cleaned up properly

### Phase 2: Core Functionality (Data Generation & ETS)

**Goal:** Implement core data generation and ETS management

#### Step 2.1: Implement ETS Lifecycle Management
- **Functions:**
  - `setup_ets/1` - Initialize ETS tables for test
  - `cleanup_ets/1` - Clean up ETS tables after test
  - `with_clean_ets/2` - Convenience wrapper for setup/cleanup
- **Implementation Details:**
  - Start ETSDataLayer GenServer if not running
  - Generate unique table names for async test support (e.g., `:"demo_customers_#{:erlang.unique_integer()}"`)
  - Store table names in test context
  - Ensure cleanup on test exit via `on_exit` callback
- **Error Handling:**
  - Clear errors if GenServer already started
  - Graceful handling if tables already exist
  - Proper cleanup even on test failure

#### Step 2.2: Implement Data Generation Helpers
- **Functions:**
  - `generate_data/1` - Generate data with specified scenario (`:empty`, `:small`, `:medium`, `:large`)
  - `generate_foundation_data/0` - Only customer types and product categories
  - `generate_customers/1` - Generate customers with options
  - `generate_products/1` - Generate products with options
  - `generate_invoices/1` - Generate invoices with options
- **Implementation Details:**
  - Start DataGenerator GenServer if not running
  - Wrap GenServer calls with proper timeouts
  - Cache results in test context to avoid regeneration
  - Support custom volumes via options
- **Scenarios:**
  - `:empty` - Only foundation data (types, categories)
  - `:small` - 25 customers, 100 products, 75 invoices (quick tests)
  - `:medium` - 100 customers, 500 products, 300 invoices (integration tests)
  - `:large` - 1000 customers, 2000 products, 5000 invoices (performance tests)

#### Step 2.3: Implement Data Validation Helpers
- **Functions:**
  - `validate_data_integrity/0` - Check referential integrity
  - `get_data_stats/0` - Get counts of all resources
  - `verify_relationships/2` - Verify specific relationships exist
- **Purpose:**
  - Debugging aid when tests fail
  - Verify data generation worked correctly
  - Ensure test data meets expectations

### Phase 3: Query Helpers (Convenient Resource Access)

**Goal:** Make it easy to query and work with generated data

#### Step 3.1: Implement Basic Query Helpers
- **Functions:**
  - `list_customers/1` - Get all customers with optional filters
  - `list_products/1` - Get all products with optional filters
  - `list_invoices/1` - Get all invoices with optional filters
  - `get_customer/1` - Get customer by ID
  - `get_product/1` - Get product by ID
  - `get_invoice/1` - Get invoice by ID
- **Implementation:**
  - Wrap `Ash.read/2` with domain specification
  - Handle errors gracefully
  - Support filter options (e.g., `status: :active`)
  - Return `{:ok, records}` or `{:error, reason}` tuples

#### Step 3.2: Implement Relationship Loaders
- **Functions:**
  - `load_customer_addresses/1` - Load addresses for customer(s)
  - `load_customer_invoices/1` - Load invoices for customer(s)
  - `load_invoice_line_items/1` - Load line items for invoice(s)
  - `load_product_inventory/1` - Load inventory for product(s)
- **Implementation:**
  - Use Ash relationship loading
  - Support both single resource and lists
  - Handle missing relationships gracefully

#### Step 3.3: Implement Filter Helpers
- **Functions:**
  - `find_customers_by_status/1` - Filter customers by status
  - `find_products_by_category/1` - Filter products by category
  - `find_invoices_by_status/1` - Filter invoices by status
  - `find_overdue_invoices/0` - Get overdue invoices
  - `find_active_customers/0` - Get active customers
- **Implementation:**
  - Use Ash query filters
  - Leverage resource actions where defined
  - Return empty list instead of error for no matches

#### Step 3.4: Implement Aggregate Helpers
- **Functions:**
  - `customer_invoice_total/1` - Get total invoice amount for customer
  - `customer_invoice_count/1` - Get invoice count for customer
  - `product_inventory_count/1` - Get inventory count for product
  - `invoice_line_item_count/1` - Get line item count for invoice
- **Implementation:**
  - Use Ash aggregates defined on resources
  - Cache results when appropriate
  - Handle nil values gracefully

### Phase 4: Integration with Existing Infrastructure

**Goal:** Seamlessly integrate with RendererTestHelpers and existing tests

#### Step 4.1: Implement Conversion Utilities
- **Functions:**
  - `to_render_context/2` - Convert Ash resources to RenderContext
  - `to_mock_report/1` - Convert realistic data to mock report format
  - `ash_resource_to_map/1` - Convert Ash struct to plain map
  - `resources_to_records/1` - Convert list of resources to records list
- **Purpose:**
  - Bridge between realistic and mock testing
  - Allow gradual adoption
  - Support mixed testing strategies

#### Step 4.2: Implement Setup Macros/Functions
- **Functions:**
  - `setup_realistic_test/1` - Complete setup for realistic test
  - `setup_with_data/2` - Setup with specific data scenario
- **Implementation:**
  ```elixir
  defmacro setup_realistic_test(scenario \\ :small) do
    quote do
      setup do
        {:ok, context} = AshReports.RealisticTestHelpers.setup_with_data(unquote(scenario))
        on_exit(fn -> AshReports.RealisticTestHelpers.cleanup_ets(context) end)
        {:ok, context}
      end
    end
  end
  ```
- **Usage:**
  ```elixir
  use AshReports.RealisticTestHelpers

  setup_realistic_test(:small)

  test "invoice report with realistic data", %{customers: customers} do
    # Test code
  end
  ```

#### Step 4.3: Create Integration Examples
- **File:** `/home/pcharbon/code/ash_reports/test/ash_reports/realistic_integration_test.exs`
- **Demonstrate:**
  - Using realistic data in renderer tests
  - Mixing realistic and mock data
  - Performance testing with large datasets
  - Relationship queries across resources
  - Using calculations and aggregates in reports

#### Step 4.4: Document Integration Patterns
- **Update:** Module documentation in `realistic_test_helpers.ex`
- **Include:**
  - Quick start examples
  - Common patterns
  - Integration with RendererTestHelpers
  - Performance considerations
  - Troubleshooting guide

### Phase 5: Testing & Validation

**Goal:** Ensure the new infrastructure works correctly and is well-tested

#### Step 5.1: Write Unit Tests for RealisticTestHelpers
- **File:** `/home/pcharbon/code/ash_reports/test/support/realistic_test_helpers_test.exs`
- **Test Coverage:**
  - ETS lifecycle (setup, cleanup, isolation)
  - Data generation for each scenario
  - Query helpers return correct data
  - Relationship loading works
  - Filter helpers work correctly
  - Aggregate helpers work correctly
  - Conversion utilities produce correct format
  - Error handling for edge cases
- **Test Count:** Aim for 50+ tests covering all public functions

#### Step 5.2: Create Example Usage Tests
- **File:** `/home/pcharbon/code/ash_reports/test/examples/realistic_test_examples_test.exs`
- **Purpose:**
  - Demonstrate real-world usage
  - Serve as documentation
  - Validate common patterns
- **Examples:**
  - Simple renderer test with realistic data
  - Multi-resource query test
  - Performance test with large dataset
  - Relationship traversal test
  - Aggregate calculation test

#### Step 5.3: Update Existing Test to Use Realistic Data
- **Choose:** 1-2 existing renderer tests
- **Convert:** Use RealisticTestHelpers instead of mocks
- **Purpose:**
  - Validate integration with existing code
  - Demonstrate migration path
  - Find integration issues
- **Tests to Convert:**
  - `test/ash_reports/heex_renderer_test.exs` (some tests)
  - One test from `test/ash_reports/group_processor_test.exs`

#### Step 5.4: Performance Testing
- **Tests:**
  - Measure setup time for each scenario
  - Measure memory usage for large datasets
  - Measure query performance
  - Ensure cleanup completes quickly
- **Benchmarks:**
  - Small: < 100ms setup
  - Medium: < 1s setup
  - Large: < 5s setup
  - Cleanup: < 50ms
- **Document:** Performance characteristics in README

### Phase 6: Documentation & Polish

**Goal:** Create excellent documentation and developer experience

#### Step 6.1: Complete Module Documentation
- **RealisticTestHelpers Module:**
  - Comprehensive @moduledoc with examples
  - @doc for every public function
  - @spec for function signatures
  - Examples in docstrings
  - Link to related functions

#### Step 6.2: Create Usage Guide
- **File:** `/home/pcharbon/code/ash_reports/test/support/REALISTIC_TESTING_GUIDE.md`
- **Contents:**
  - Introduction and motivation
  - Quick start guide
  - Common patterns and recipes
  - Integration with existing tests
  - Performance considerations
  - Troubleshooting
  - FAQ

#### Step 6.3: Update Project Documentation
- **Files to Update:**
  - README.md - Add section on testing
  - planning/testing.md - Update with new approach
- **Include:**
  - Overview of dual testing strategy (mock + realistic)
  - When to use which approach
  - Migration guide for existing tests

#### Step 6.4: Code Review Checklist
- Code style consistent with project
- All functions have specs
- All functions have docs
- Error messages are clear and helpful
- No TODO comments left
- All tests pass
- Performance benchmarks met
- Documentation is complete and accurate

## Implementation Sequence

### Week 1: Foundation & Core
- Days 1-2: Phase 1 (Foundation)
- Days 3-5: Phase 2 (Core Functionality)

### Week 2: Query Helpers & Integration
- Days 1-2: Phase 3 (Query Helpers)
- Days 3-5: Phase 4 (Integration)

### Week 3: Testing & Documentation
- Days 1-3: Phase 5 (Testing & Validation)
- Days 4-5: Phase 6 (Documentation & Polish)

## Notes and Considerations

### Edge Cases

1. **ETS Table Name Collisions**
   - Use unique identifiers for async tests
   - Consider test module name + unique integer
   - Document naming strategy

2. **GenServer Already Started**
   - Handle gracefully with proper error messages
   - Consider using named supervisors per test
   - Document restart strategies

3. **Circular Dependencies**
   - Carefully manage module loading order
   - Avoid circular requires in test_helper.exs
   - Use lazy loading where possible

4. **Data Generation Timeout**
   - Large datasets may take time to generate
   - Provide progress feedback for long operations
   - Support incremental data generation

5. **Memory Pressure**
   - Large datasets consume memory
   - Document memory requirements
   - Provide cleanup utilities
   - Consider streaming for very large tests

### Performance Considerations

1. **Lazy Data Generation**
   - Only generate data when first needed
   - Cache generated data in test context
   - Avoid regenerating for each test

2. **ETS Performance**
   - Use appropriate concurrency options
   - Monitor table size
   - Benchmark operations
   - Document performance characteristics

3. **Test Parallelization**
   - Ensure proper isolation for async tests
   - Use unique table names per test
   - Avoid shared state

4. **Cleanup Efficiency**
   - Batch delete operations where possible
   - Clear tables rather than deleting
   - Measure cleanup time

### Cleanup and Resource Management

1. **ETS Tables**
   - Always cleanup in on_exit callback
   - Handle cleanup errors gracefully
   - Verify cleanup completed
   - Log cleanup failures

2. **GenServer Processes**
   - Stop processes after use (or leave running for speed)
   - Handle supervisor restarts
   - Document process lifecycle

3. **Memory Leaks**
   - Monitor memory growth over test suite
   - Ensure all resources released
   - Test cleanup thoroughly

4. **Test Isolation**
   - Each test gets clean state
   - No data leaks between tests
   - Verify isolation with assertions

### Migration Strategy

1. **Gradual Adoption**
   - Keep existing mock-based tests working
   - Add realistic tests alongside mocks
   - Gradually convert high-value tests
   - Document migration patterns

2. **Dual Support**
   - Both approaches remain valid
   - Choose based on test needs
   - Provide clear guidance on when to use each

3. **Backward Compatibility**
   - Don't break existing tests
   - Maintain RendererTestHelpers API
   - Integration should be opt-in

### Testing Strategy for the Helpers Themselves

1. **Unit Tests**
   - Test each function in isolation
   - Mock external dependencies (DataGenerator, etc.)
   - Cover error cases thoroughly
   - Use stream_data for property testing

2. **Integration Tests**
   - Test interaction with real DataGenerator
   - Verify ETS operations work correctly
   - Test with actual Ash resources
   - Verify cleanup works

3. **Example Tests**
   - Realistic usage examples
   - Document best practices
   - Serve as regression tests

### Potential Issues and Mitigations

1. **Issue:** Faker dependency not available in production
   - **Mitigation:** Only in test/dev deps, clear boundary

2. **Issue:** Tests become slower due to data generation
   - **Mitigation:** Lazy loading, caching, use small scenario by default

3. **Issue:** Difficult to debug test failures
   - **Mitigation:** Provide debugging helpers, clear error messages, data stats

4. **Issue:** ETS tables not cleaned up properly
   - **Mitigation:** Robust cleanup with on_exit, monitoring, verification

5. **Issue:** Complex setup discourages adoption
   - **Mitigation:** Simple defaults, convenience macros, excellent docs

6. **Issue:** Memory consumption with large datasets
   - **Mitigation:** Document requirements, provide smaller scenarios, cleanup thoroughly

### Dependencies Analysis

**New Dependencies Required:**
- `faker` ~> 0.18 (test/dev only) - Currently used but not declared in mix.exs

**Existing Dependencies Used:**
- `ash` ~> 3.0 - Core framework
- `ex_unit` - Test framework
- `mox` ~> 1.1 (optional) - For mocking if needed
- `stream_data` ~> 1.0 (optional) - For property tests

**No Production Dependencies Added:** All new deps are test/dev only

### Future Enhancements (Out of Scope)

1. **Database-backed Testing**
   - Switch from ETS to Postgres for some tests
   - Test migration with real database
   - Performance comparison

2. **Shared Test Data**
   - Generate data once, use across multiple tests
   - Requires read-only test strategy
   - Significant performance improvement

3. **Snapshot Testing**
   - Capture expected output, compare on future runs
   - Good for regression testing
   - Complementary to realistic data

4. **Factory Pattern**
   - ExMachina-style factory functions
   - More flexible than DataGenerator
   - Good for unit tests

5. **Test Data Fixtures**
   - JSON/CSV fixtures loaded into ETS
   - Version controlled test data
   - Good for specific scenarios

## Success Metrics

### Quantitative Metrics

1. **Test Coverage**: New helpers have >90% test coverage
2. **Performance**: Setup times meet requirements (small < 100ms, medium < 1s, large < 5s)
3. **Adoption**: At least 5 existing tests converted to use realistic data
4. **Memory**: Memory usage stays within 50MB for small, 200MB for medium scenarios
5. **Cleanup**: All ETS tables cleaned up after tests (0 leaked tables)

### Qualitative Metrics

1. **Developer Experience**: Easy to understand and use
2. **Documentation**: Comprehensive and clear
3. **Reliability**: No flaky tests
4. **Maintainability**: Easy to extend and modify
5. **Integration**: Works seamlessly with existing infrastructure

## Approval and Sign-off

This plan will be reviewed by Pascal before implementation begins.

**Key Questions for Review:**
1. Is the phased approach appropriate?
2. Are there any missing considerations?
3. Should we prioritize differently?
4. Are there any concerns about the approach?

---

**Document Version:** 1.0
**Created:** 2025-10-30
**Author:** Claude (Code Assistant)
**Status:** Draft - Pending Review
