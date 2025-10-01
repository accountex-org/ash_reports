# Stage 2.4.4: Integration and Testing - Feature Planning Document

**Status**: Planning
**Created**: 2025-10-01
**Section**: Stage 2.4.4 - DSL-Driven Grouped Aggregation Integration Testing
**Dependencies**: Sections 2.4.1, 2.4.2, 2.4.3 (Complete)

---

## Problem Statement

Sections 2.4.1 (Expression Parsing), 2.4.2 (Variable-to-Aggregation Mapping), and 2.4.3 (Cumulative Grouping) have implemented the core DSL parsing and configuration building logic in `AshReports.Typst.DataLoader`. Now we need comprehensive integration tests to verify the complete flow from DSL definitions through to ProducerConsumer configuration generation works correctly in real-world scenarios.

### Why Integration Tests Are Needed Now

1. **Unit Tests Are Incomplete**: Current tests in `test/ash_reports/typst/data_loader_test.exs` only test the DSL parsing logic in isolation using the `__test_build_grouped_aggregations__/1` helper function. They don't verify the integration with the streaming pipeline.

2. **Missing Real-World Validation**: We need to verify that:
   - The generated configs are accepted by `ProducerConsumer.start_link/1`
   - The DSL parsing works with actual `AshReports.Report` structs from `test_helpers.ex`
   - Variables are correctly filtered by `reset_on` and `reset_group`
   - Edge cases (empty groups, mismatched levels) are handled gracefully

3. **ProducerConsumer Contract Verification**: The generated configs must match the expected format documented in `ProducerConsumer` (lines 140-146):
   ```elixir
   grouped_aggregations: [
     %{
       group_by: :field | [:field1, :field2],  # Single field as atom, multiple as list
       aggregations: [:sum, :count, :avg, :min, :max],
       level: 1,  # Group level from DSL
       sort: :asc | :desc  # Sort order from group definition
     }
   ]
   ```

4. **Gap Analysis**: Current test coverage shows:
   - ✅ Unit tests for cumulative grouping logic (lines 47-247 in `data_loader_test.exs`)
   - ✅ Tests for expression parsing (separate `expression_parser_test.exs`)
   - ❌ **Missing**: Integration tests using `build_complex_report/1` from test helpers
   - ❌ **Missing**: End-to-end tests with actual streaming pipeline startup
   - ❌ **Missing**: Variable filtering validation (reset_on, reset_group)
   - ❌ **Missing**: Edge case handling (empty groups, no variables, mismatched levels)

---

## Solution Overview

Create comprehensive integration tests in a new test module that:

1. **Uses Real Test Data**: Leverage `build_complex_report/1` from `test/support/test_helpers.ex` which includes:
   - Single-level grouping by region (lines 158-164)
   - Variables with different scopes (lines 150-156)
   - Parameters and filters (lines 138-148)

2. **Tests Complete Flow**: Verify the entire pipeline from DSL → DataLoader → ProducerConsumer config generation

3. **Validates ProducerConsumer Integration**: Ensure generated configs can be used to start actual streaming pipelines

4. **Covers Edge Cases**: Test scenarios that might break in production:
   - Reports without groups
   - Groups without variables
   - Variables with mismatched group levels
   - Complex expressions requiring fallback parsing

### Test Strategy

**Approach**: Black-box integration testing focusing on the public API contract between DataLoader and StreamingPipeline.

**Key Principles**:
- Test through public APIs only (`load_for_typst/4`, `stream_for_typst/4`)
- Use realistic report definitions from test helpers
- Verify generated configs match ProducerConsumer expectations
- Don't test internal implementation details (already covered by unit tests)

---

## Technical Details

### Test Data Structure

We'll use and extend `build_complex_report/1` from `test_helpers.ex`:

**Current Report Structure** (lines 129-221):
```elixir
%AshReports.Report{
  name: :complex_test_report,
  driving_resource: AshReports.Test.Order,
  variables: [
    %AshReports.Variable{
      name: :total_sales,
      type: :sum,
      expression: {:sum, :total_amount},
      reset_on: :report  # ← Need to add reset_on: :group for testing
    }
  ],
  groups: [
    %AshReports.Group{
      name: :by_region,
      level: 1,
      expression: {:field, :customer, :region}  # ← Already correct format
    }
  ],
  # ... bands and elements ...
}
```

**Enhancements Needed**:
1. Add multi-level grouping variant (region → customer)
2. Add group-scoped variables with `reset_on: :group` and `reset_group: N`
3. Add edge case variants (no groups, no variables, mismatched levels)

### Expected ProducerConsumer Config Format

Based on `ProducerConsumer` documentation (lines 140-146, 194-199):

```elixir
# Single-level grouping
[
  %{
    group_by: :region,  # ← Single field as atom
    level: 1,
    aggregations: [:sum, :count],
    sort: :asc
  }
]

# Multi-level grouping (cumulative)
[
  %{
    group_by: :territory,  # ← Level 1: single atom
    level: 1,
    aggregations: [:sum, :count],
    sort: :asc
  },
  %{
    group_by: [:territory, :customer_name],  # ← Level 2: list of atoms
    level: 2,
    aggregations: [:sum, :avg],
    sort: :asc
  }
]
```

### Test Cases to Implement

#### 1. Basic Single-Level Grouping Integration

**Goal**: Verify that a report with one group level generates valid ProducerConsumer config

**Setup**:
- Use `build_complex_report/1` with single group (by region)
- Add group-scoped variable with `reset_on: :group, reset_group: 1`

**Expected Outcome**:
```elixir
[
  %{
    group_by: :region,
    level: 1,
    aggregations: [:sum, :count],  # From variables
    sort: :asc
  }
]
```

**Assertions**:
- Config is a list with 1 element
- `group_by` is an atom (`:region`)
- `level` is 1
- `aggregations` includes types from variables
- Config can be passed to `ProducerConsumer.start_link/1`

---

#### 2. Multi-Level Grouping Integration (Region → Customer)

**Goal**: Verify cumulative grouping for hierarchical reports

**Setup**:
- Create report with 2 groups:
  - Level 1: `expression: {:field, :customer, :region}`
  - Level 2: `expression: {:field, :customer, :name}`
- Add variables for each level:
  - Variable 1: `reset_on: :group, reset_group: 1, type: :sum`
  - Variable 2: `reset_on: :group, reset_group: 2, type: :count`

**Expected Outcome**:
```elixir
[
  %{group_by: :region, level: 1, aggregations: [:sum], sort: :asc},
  %{group_by: [:region, :name], level: 2, aggregations: [:count], sort: :asc}
]
```

**Assertions**:
- Config has 2 elements (one per level)
- Level 1: `group_by` is atom
- Level 2: `group_by` is list of atoms (cumulative)
- Variables are correctly mapped to their group levels
- Sort order is preserved from group definitions

---

#### 3. Variable Filtering by `reset_on` and `reset_group`

**Goal**: Verify that only group-scoped variables are included in aggregations

**Setup**:
- Report with 1 group (level 1: region)
- Multiple variables with different scopes:
  - Variable A: `reset_on: :report` (should be excluded)
  - Variable B: `reset_on: :group, reset_group: 1` (should be included)
  - Variable C: `reset_on: :page` (should be excluded)
  - Variable D: `reset_on: :group, reset_group: 2` (should be excluded - no level 2)

**Expected Outcome**:
```elixir
[
  %{
    group_by: :region,
    level: 1,
    aggregations: [:sum],  # Only from Variable B
    sort: :asc
  }
]
```

**Assertions**:
- Only Variable B's type (`:sum`) appears in aggregations
- Variables A, C, D are filtered out
- No errors or warnings about mismatched variables

---

#### 4. Edge Case: Report with No Groups

**Goal**: Verify graceful handling when report has no group definitions

**Setup**:
- Report with empty groups list: `groups: []`
- Variables present but no groups

**Expected Outcome**:
```elixir
[]  # Empty list
```

**Assertions**:
- Returns empty list (not nil or error)
- No crashes or warnings
- DataLoader continues to work normally

---

#### 5. Edge Case: Groups with No Variables

**Goal**: Verify default aggregations when no variables are defined

**Setup**:
- Report with groups but empty variables list: `variables: []`
- Single group: level 1, by region

**Expected Outcome**:
```elixir
[
  %{
    group_by: :region,
    level: 1,
    aggregations: [:sum, :count],  # Default aggregations
    sort: :asc
  }
]
```

**Assertions**:
- Config uses default aggregations (`:sum`, `:count`)
- No errors or crashes
- Logged debug message about using defaults

---

#### 6. Edge Case: Variables with Mismatched Group Levels

**Goal**: Verify handling when variable `reset_group` doesn't match any group level

**Setup**:
- Report with groups: level 1 (region), level 3 (product) - **note: no level 2**
- Variable: `reset_on: :group, reset_group: 2` (references non-existent level)

**Expected Outcome**:
```elixir
[
  %{group_by: :region, level: 1, aggregations: [:sum, :count], sort: :asc},
  %{group_by: [:region, :product], level: 3, aggregations: [:sum, :count], sort: :asc}
]
```

**Assertions**:
- Mismatched variable is ignored (logged warning)
- Config is still generated for existing levels
- Default aggregations used since no matching variables

---

#### 7. Edge Case: Complex Expressions Requiring Fallback

**Goal**: Verify fallback parsing when expression cannot be parsed

**Setup**:
- Group with unparseable expression (e.g., complex calculation)
- Expression that `ExpressionParser.extract_field_with_fallback/2` falls back on

**Expected Outcome**:
```elixir
[
  %{
    group_by: :by_region,  # Falls back to group name
    level: 1,
    aggregations: [:sum, :count],
    sort: :asc
  }
]
```

**Assertions**:
- Fallback uses group name when expression parsing fails
- Warning is logged about fallback usage
- Config is still valid and usable

---

#### 8. ProducerConsumer Integration Test

**Goal**: Verify that generated configs can actually start a ProducerConsumer

**Setup**:
- Build report with multi-level groups and variables
- Generate config via `DataLoader` (internal)
- Attempt to start ProducerConsumer with generated config

**Expected Outcome**:
- ProducerConsumer starts successfully
- No validation errors from GenStage
- Config is accepted and stored in state

**Assertions**:
- `ProducerConsumer.start_link/1` returns `{:ok, pid}`
- Process is alive and registered
- Telemetry events fire correctly

---

#### 9. Variable Type Mapping Validation

**Goal**: Verify all variable types map to correct aggregation functions

**Setup**:
- Report with multiple variable types:
  - `:sum` → `:sum`
  - `:average` → `:avg`
  - `:count` → `:count`
  - `:min` → `:min`
  - `:max` → `:max`

**Expected Outcome**:
```elixir
[
  %{
    group_by: :region,
    level: 1,
    aggregations: [:sum, :avg, :count, :min, :max],
    sort: :asc
  }
]
```

**Assertions**:
- All variable types are correctly mapped
- Aggregations list contains all 5 types
- Order doesn't matter (unique list)

---

#### 10. Three-Level Hierarchical Grouping

**Goal**: Verify complex hierarchical grouping (Territory → Customer → Order Type)

**Setup**:
- Report with 3 group levels:
  - Level 1: territory
  - Level 2: customer_name
  - Level 3: order_type
- Variables at each level

**Expected Outcome**:
```elixir
[
  %{group_by: :territory, level: 1, aggregations: [:sum], sort: :asc},
  %{group_by: [:territory, :customer_name], level: 2, aggregations: [:count], sort: :asc},
  %{group_by: [:territory, :customer_name, :order_type], level: 3, aggregations: [:avg], sort: :asc}
]
```

**Assertions**:
- All 3 levels present
- Cumulative fields are correct at each level
- Variables are correctly distributed across levels

---

### Integration with Existing Test Infrastructure

**Test Helper Usage**:

```elixir
# Reuse existing helpers
import AshReports.TestHelpers

setup do
  # Setup test data
  setup_test_data()
  on_exit(fn -> cleanup_test_data() end)
  :ok
end

# Build enhanced reports for testing
def build_report_with_multi_level_grouping do
  build_complex_report(name: :multi_level_test)
  |> add_second_group_level()
  |> add_group_scoped_variables()
end
```

**Test Module Structure**:

```elixir
defmodule AshReports.Typst.DataLoaderIntegrationTest do
  use ExUnit.Case, async: false  # Due to streaming pipeline startup

  import AshReports.TestHelpers
  alias AshReports.Typst.DataLoader

  describe "DSL to ProducerConsumer config generation" do
    # Tests 1-10 here
  end

  describe "end-to-end streaming pipeline integration" do
    # Test 8 here (ProducerConsumer startup)
  end

  # Helper functions for building test reports
  defp build_report_with_groups(opts) do
    # ...
  end
end
```

---

## Implementation Plan

### Step 1: Create Test Module Structure

**File**: `test/ash_reports/typst/data_loader_integration_test.exs`

**Actions**:
1. Create new test module `AshReports.Typst.DataLoaderIntegrationTest`
2. Import test helpers and aliases
3. Set up async: false (due to streaming pipeline startup)
4. Create describe blocks for different test categories

**Success Criteria**:
- File exists and compiles
- Test module loads without errors
- Setup/teardown hooks work correctly

---

### Step 2: Implement Report Builder Helpers

**Goal**: Create helper functions to build test reports with various configurations

**Functions to Create**:

```elixir
# Helper: Build report with single-level grouping
defp build_report_single_group(opts \\ []) do
  # Based on build_complex_report, but simplified
end

# Helper: Build report with multi-level grouping (2 levels)
defp build_report_two_level_grouping(opts \\ []) do
  # Territory → Customer
end

# Helper: Build report with multi-level grouping (3 levels)
defp build_report_three_level_grouping(opts \\ []) do
  # Territory → Customer → Order Type
end

# Helper: Build report with mixed-scope variables
defp build_report_mixed_variables(opts \\ []) do
  # Some group-scoped, some report-scoped, some page-scoped
end

# Helper: Add group-scoped variables to existing report
defp add_group_variables(report, level, variable_types) do
  # Adds variables with reset_on: :group, reset_group: level
end
```

**Success Criteria**:
- Helpers return valid `AshReports.Report` structs
- Helpers are reusable across multiple tests
- Helpers accept opts for customization

---

### Step 3: Implement Basic Integration Tests (Tests 1-3)

**Tests**:
1. Basic single-level grouping integration
2. Multi-level grouping integration (Region → Customer)
3. Variable filtering by `reset_on` and `reset_group`

**Implementation Approach**:

```elixir
test "generates valid config for single-level grouping" do
  # Given: Report with single group
  report = build_report_single_group(
    group_field: :region,
    group_level: 1,
    variables: [%{type: :sum, reset_on: :group, reset_group: 1}]
  )

  # When: Build grouped aggregations (via internal test interface)
  config = DataLoader.__test_build_grouped_aggregations__(report)

  # Then: Verify config structure
  assert [group_config] = config
  assert group_config.group_by == :region
  assert group_config.level == 1
  assert :sum in group_config.aggregations
  assert group_config.sort == :asc
end
```

**Success Criteria**:
- All 3 tests pass
- Configs match expected format
- No compilation or runtime errors

---

### Step 4: Implement Edge Case Tests (Tests 4-7)

**Tests**:
4. Report with no groups
5. Groups with no variables
6. Variables with mismatched group levels
7. Complex expressions requiring fallback

**Implementation Focus**:
- Test error handling and fallback logic
- Verify no crashes or undefined behavior
- Check warning logs are emitted appropriately

**Success Criteria**:
- All 4 tests pass
- Edge cases are handled gracefully
- Warnings are logged when appropriate

---

### Step 5: Implement ProducerConsumer Integration Test (Test 8)

**Goal**: Verify generated configs can start actual ProducerConsumer processes

**Implementation**:

```elixir
test "generated config can start ProducerConsumer successfully" do
  # Given: Report with multi-level grouping
  report = build_report_two_level_grouping()

  # When: Generate config
  grouped_aggregations = DataLoader.__test_build_grouped_aggregations__(report)

  # And: Attempt to start ProducerConsumer
  producer_pid = spawn_mock_producer()
  stream_id = "integration-test-#{:rand.uniform(10000)}"

  opts = [
    stream_id: stream_id,
    subscribe_to: [{producer_pid, []}],
    grouped_aggregations: grouped_aggregations
  ]

  result = ProducerConsumer.start_link(opts)

  # Then: ProducerConsumer starts successfully
  assert {:ok, pid} = result
  assert Process.alive?(pid)

  # Cleanup
  cleanup_process(pid)
  cleanup_process(producer_pid)
end
```

**Success Criteria**:
- ProducerConsumer accepts generated config
- Process starts and registers successfully
- No validation errors from GenStage

---

### Step 6: Implement Variable Mapping Test (Test 9)

**Goal**: Verify all variable types map correctly to aggregation functions

**Implementation**:

```elixir
test "maps all variable types to correct aggregations" do
  # Given: Report with all variable types
  report = %{
    groups: [%{level: 1, name: :test_group, expression: :region, sort: :asc}],
    variables: [
      %{type: :sum, reset_on: :group, reset_group: 1},
      %{type: :average, reset_on: :group, reset_group: 1},
      %{type: :count, reset_on: :group, reset_group: 1},
      %{type: :min, reset_on: :group, reset_group: 1},
      %{type: :max, reset_on: :group, reset_group: 1}
    ]
  }

  # When: Generate config
  config = DataLoader.__test_build_grouped_aggregations__(report)

  # Then: All types are mapped
  assert [group_config] = config
  assert :sum in group_config.aggregations
  assert :avg in group_config.aggregations  # average → avg
  assert :count in group_config.aggregations
  assert :min in group_config.aggregations
  assert :max in group_config.aggregations
end
```

**Success Criteria**:
- All 5 variable types are correctly mapped
- Mapping follows documented rules (`:average` → `:avg`)
- No duplicates in aggregations list

---

### Step 7: Implement Three-Level Grouping Test (Test 10)

**Goal**: Verify complex hierarchical grouping works correctly

**Implementation**:

```elixir
test "handles three-level hierarchical grouping with cumulative fields" do
  # Given: Report with 3 group levels
  report = build_report_three_level_grouping()

  # When: Generate config
  config = DataLoader.__test_build_grouped_aggregations__(report)

  # Then: All levels are present with cumulative grouping
  assert [level1, level2, level3] = config

  assert level1.group_by == :territory
  assert level1.level == 1

  assert level2.group_by == [:territory, :customer_name]
  assert level2.level == 2

  assert level3.group_by == [:territory, :customer_name, :order_type]
  assert level3.level == 3
end
```

**Success Criteria**:
- All 3 levels are generated correctly
- Cumulative fields are correct at each level
- Variables are distributed to correct levels

---

### Step 8: Add Logging and Telemetry Verification

**Goal**: Verify that appropriate logs and telemetry events are emitted

**Implementation**:

```elixir
test "emits telemetry events during config generation" do
  # Setup telemetry handler
  test_pid = self()
  handler_id = "integration-test-#{:rand.uniform(10000)}"

  :telemetry.attach(
    handler_id,
    [:ash_reports, :streaming, :producer_consumer, :batch_transformed],
    fn event_name, measurements, metadata, _ ->
      send(test_pid, {:telemetry_event, event_name, measurements, metadata})
    end,
    nil
  )

  # Given: Report with grouping
  report = build_report_single_group()

  # When: Generate config and start pipeline
  # ... (pipeline startup code)

  # Then: Telemetry events are received
  assert_receive {:telemetry_event, [:ash_reports, :streaming, :producer_consumer, :batch_transformed], _, _}

  # Cleanup
  :telemetry.detach(handler_id)
end
```

**Success Criteria**:
- Telemetry events are emitted correctly
- Event metadata includes stream_id and grouped_aggregations
- Logs contain appropriate debug/warning messages

---

### Step 9: Documentation and Comments

**Goal**: Document test cases and their purpose for future maintainers

**Actions**:
1. Add module-level documentation explaining test scope
2. Add comments to each test explaining what's being verified
3. Document test data builders and their usage
4. Add examples of expected outcomes

**Success Criteria**:
- Each test has a clear docstring or comment
- Helper functions are documented
- Test module @moduledoc explains integration scope

---

### Step 10: Run Full Test Suite and Validate

**Goal**: Ensure all tests pass and provide meaningful coverage

**Actions**:
1. Run `mix test test/ash_reports/typst/data_loader_integration_test.exs`
2. Run full test suite to ensure no regressions
3. Check test coverage for DataLoader module
4. Validate that all 10 test cases pass

**Success Criteria**:
- All 10 integration tests pass
- No test failures in existing test suite
- Coverage for DataLoader DSL integration is >90%
- No warnings or errors in test output

---

## Success Criteria

### Functional Requirements

**✅ Complete when**:

1. **Test Suite Passes**: All 10 integration tests pass consistently
   - Basic single-level grouping
   - Multi-level grouping (2 and 3 levels)
   - Variable filtering by scope
   - Edge cases (no groups, no variables, mismatched levels, fallback parsing)
   - ProducerConsumer integration
   - Variable type mapping
   - Telemetry verification

2. **Config Validation**: Generated configs match ProducerConsumer contract
   - Single field as atom: `group_by: :field`
   - Multiple fields as list: `group_by: [:field1, :field2]`
   - All required keys present: `group_by`, `level`, `aggregations`, `sort`
   - Configs can be used to start ProducerConsumer processes

3. **Edge Cases Handled**: No crashes or undefined behavior for:
   - Reports with no groups → returns empty list
   - Groups with no variables → uses default aggregations
   - Variables with mismatched levels → ignored with warning
   - Complex expressions → falls back to group name

4. **Integration Verified**: End-to-end flow works correctly
   - DSL parsing extracts correct fields
   - Variables are filtered by reset_on and reset_group
   - Cumulative grouping accumulates fields correctly
   - ProducerConsumer accepts and uses generated configs

### Non-Functional Requirements

**✅ Complete when**:

1. **Test Coverage**: DataLoader DSL integration code has >90% coverage
2. **Test Maintainability**: Test helpers are reusable and well-documented
3. **Test Performance**: Full test suite runs in <5 seconds
4. **Documentation**: Test module has clear @moduledoc and comments

### Validation Checklist

Before marking section 2.4.4 as complete, verify:

- [ ] All 10 integration tests pass
- [ ] No regressions in existing test suite
- [ ] Test helpers are reusable and documented
- [ ] Edge cases are covered comprehensively
- [ ] ProducerConsumer integration works end-to-end
- [ ] Telemetry events are verified
- [ ] Warning logs are tested for fallback scenarios
- [ ] Test module has comprehensive documentation
- [ ] Code review completed
- [ ] Planning document updated with implementation notes

---

## Notes

### Dependencies

**Requires**:
- ✅ Section 2.4.1: Expression parsing and field extraction (Complete)
- ✅ Section 2.4.2: Variable-to-aggregation mapping (Complete)
- ✅ Section 2.4.3: Cumulative grouping (Complete)
- ✅ `test/support/test_helpers.ex`: Report builders (Available)
- ✅ `ProducerConsumer` module: Aggregation config acceptance (Available)

### Implementation Considerations

1. **Test Isolation**: Use `async: false` for ProducerConsumer integration tests due to process registration

2. **Test Data**: Leverage existing `build_complex_report/1` but enhance with group-scoped variables

3. **Telemetry Testing**: Use `:telemetry.attach/4` for event verification (see existing pattern in `producer_consumer_test.exs`)

4. **Process Cleanup**: Use helper functions for cleanup:
   ```elixir
   defp cleanup_process(pid) when is_pid(pid) do
     if Process.alive?(pid) do
       Process.exit(pid, :kill)
       :timer.sleep(10)
     end
   end
   ```

5. **Mock Producer**: For ProducerConsumer tests, use simple mock producer:
   ```elixir
   defp spawn_mock_producer do
     spawn(fn -> :timer.sleep(:infinity) end)
   end
   ```

### Future Enhancements

After section 2.4.4 is complete, consider:

1. **Performance Testing**: Add benchmarks for config generation with large numbers of groups
2. **Property-Based Testing**: Use StreamData to generate random report configurations
3. **Regression Tests**: Add specific tests for any bugs discovered in production
4. **Integration with Real Data**: Test with actual Ash resources instead of mocks

### Related Documentation

- Planning document: `/home/ducky/code/ash_reports/planning/typst_refactor_plan.md`
- DSL integration research: `/home/ducky/code/ash_reports/planning/grouped_aggregation_dsl_integration.md`
- ProducerConsumer docs: `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex`
- Test helpers: `/home/ducky/code/ash_reports/test/support/test_helpers.ex`

---

**Planning Document Complete** - Ready for implementation approval.
