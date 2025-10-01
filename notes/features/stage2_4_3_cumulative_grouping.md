# Stage 2.4.3: Cumulative Grouping Implementation Plan

## Overview

This document details the implementation plan for adding cumulative grouping support to the AshReports DataLoader streaming pipeline. The enhancement will transform flat single-field groupings into hierarchical cumulative groupings that include all fields from lower levels.

**Status**: Planning Phase
**Dependencies**: Section 2.4.1 (Expression Parser - ✅ Complete), Section 2.4.2 (Variable-to-Aggregation Mapping - ⏳ Pending)
**Location**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex`
**Related Files**:
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex`
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/expression_parser.ex`

---

## Problem Statement

### Current Behavior

The `build_grouped_aggregations_from_dsl/1` function (lines 419-434) currently generates flat grouping configurations where each level groups by a single field:

```elixir
# Input: Report with 3 group levels
report.groups = [
  %{level: 1, name: :territory_group, expression: expr(territory)},
  %{level: 2, name: :customer_group, expression: expr(customer_name)},
  %{level: 3, name: :order_type_group, expression: expr(order_type)}
]

# Current Output (INCORRECT for hierarchical reports):
[
  %{group_by: :territory, level: 1, aggregations: [:sum, :count], sort: :asc},
  %{group_by: :customer_name, level: 2, aggregations: [:sum, :count], sort: :asc},
  %{group_by: :order_type, level: 3, aggregations: [:sum, :count], sort: :asc}
]
```

**Problem**: This produces independent groupings at each level, which doesn't reflect the hierarchical nature of Crystal Reports-style grouping where:
- Level 1 shows territory totals
- Level 2 shows territory → customer subtotals (grouped by BOTH fields)
- Level 3 shows territory → customer → order_type sub-subtotals (grouped by ALL THREE fields)

### Required Behavior

Each grouping level should accumulate fields from all previous levels to create a proper hierarchy:

```elixir
# Required Output (CORRECT for hierarchical reports):
[
  %{group_by: :territory, level: 1, aggregations: [:sum, :count], sort: :asc},
  %{group_by: [:territory, :customer_name], level: 2, aggregations: [:sum, :count], sort: :asc},
  %{group_by: [:territory, :customer_name, :order_type], level: 3, aggregations: [:sum, :count], sort: :asc}
]
```

**Rationale**: This ensures that when processing a stream of records, the ProducerConsumer can properly compute:
1. **Territory-level aggregates**: Sum/count for each territory
2. **Customer-level aggregates**: Sum/count for each (territory, customer) pair
3. **Order Type-level aggregates**: Sum/count for each (territory, customer, order_type) tuple

---

## Design Analysis

### Current Implementation Flow

1. **Entry Point** (line 419): `build_grouped_aggregations_from_dsl(report)`
   - Extracts groups from report DSL
   - Sorts by level (line 431): `Enum.sort_by(& &1.level)`
   - Maps each group to config (line 432): `Enum.map(&build_aggregation_config_for_group(&1, report))`

2. **Per-Group Processing** (lines 437-476): `build_aggregation_config_for_group(group, report)`
   - Extracts field name via ExpressionParser (lines 439-450)
   - Derives aggregations from variables (line 454)
   - Returns single-field config: `%{group_by: field_name, level: level, ...}`

3. **Data Flow**:
   ```
   Report DSL → Sort by Level → Map Each Group Independently → Return List
   ```

### Required Implementation Flow

To support cumulative grouping, we need to change from independent mapping to accumulative reduction:

```
Report DSL → Sort by Level → Reduce with Accumulator → Collect Fields Cumulatively → Return List
```

**Key Insight**: We need to track accumulated fields across iterations, not process each group in isolation.

---

## Implementation Strategy

### Approach: Accumulative Reduction

Replace the current `Enum.map` with `Enum.reduce` to accumulate fields from previous levels:

```elixir
# Current (line 430-433):
group_list
|> Enum.sort_by(& &1.level)
|> Enum.map(&build_aggregation_config_for_group(&1, report))
|> Enum.reject(&is_nil/1)

# Proposed:
group_list
|> Enum.sort_by(& &1.level)
|> Enum.reduce({[], []}, fn group, {configs, accumulated_fields} ->
     # Extract field for current group
     field = extract_field_for_group(group)

     # Add to accumulated fields
     new_accumulated_fields = accumulated_fields ++ [field]

     # Build config with cumulative grouping
     config = build_aggregation_config_for_group_cumulative(
       group,
       report,
       new_accumulated_fields
     )

     # Return updated accumulator
     {configs ++ [config], new_accumulated_fields}
   end)
|> elem(0)  # Extract configs list
|> Enum.reject(&is_nil/1)
```

### Algorithm Breakdown

**Step 1: Initialize Accumulator**
- Start with empty configs list and empty field list: `{[], []}`

**Step 2: Iterate Through Sorted Groups**
- For each group at level N:
  1. Extract the field name using ExpressionParser
  2. Append to accumulated_fields list
  3. Build config using accumulated_fields (not just current field)
  4. Add config to configs list
  5. Return updated accumulator

**Step 3: Extract Results**
- Take first element of tuple (configs list)
- Filter out nil values (failed parsing)

### Field Accumulation Examples

**Example 1: Three-Level Hierarchy**

```elixir
# Iteration 1: Level 1 (Territory)
accumulated_fields = []
current_field = :territory
new_accumulated_fields = [] ++ [:territory] = [:territory]
config_1 = %{group_by: :territory, level: 1, ...}

# Iteration 2: Level 2 (Customer)
accumulated_fields = [:territory]
current_field = :customer_name
new_accumulated_fields = [:territory] ++ [:customer_name] = [:territory, :customer_name]
config_2 = %{group_by: [:territory, :customer_name], level: 2, ...}

# Iteration 3: Level 3 (Order Type)
accumulated_fields = [:territory, :customer_name]
current_field = :order_type
new_accumulated_fields = [:territory, :customer_name] ++ [:order_type]
config_3 = %{group_by: [:territory, :customer_name, :order_type], level: 3, ...}

# Final Result:
[config_1, config_2, config_3]
```

**Example 2: Single-Level Grouping**

```elixir
# Iteration 1: Level 1 only
accumulated_fields = []
current_field = :region
new_accumulated_fields = [] ++ [:region] = [:region]
config_1 = %{group_by: :region, level: 1, ...}

# Final Result:
[config_1]
```

---

## Detailed Implementation Plan

### Phase 1: Refactor build_grouped_aggregations_from_dsl/1

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex`
**Lines**: 419-434

**Changes**:

1. **Replace Enum.map with Enum.reduce** (line 430-433)

   **Before**:
   ```elixir
   group_list
   |> Enum.sort_by(& &1.level)
   |> Enum.map(&build_aggregation_config_for_group(&1, report))
   |> Enum.reject(&is_nil/1)
   ```

   **After**:
   ```elixir
   group_list
   |> Enum.sort_by(& &1.level)
   |> Enum.reduce({[], []}, fn group, {configs, accumulated_fields} ->
        build_cumulative_config(group, report, configs, accumulated_fields)
      end)
   |> elem(0)
   |> Enum.reject(&is_nil/1)
   ```

2. **Add helper function: build_cumulative_config/4**

   **Location**: After line 476 (end of current build_aggregation_config_for_group/2)

   ```elixir
   defp build_cumulative_config(group, report, configs, accumulated_fields) do
     # Extract field name from group expression
     field_name = extract_field_for_group(group)

     case field_name do
       {:ok, field} ->
         # Accumulate this field with previous levels
         new_accumulated_fields = accumulated_fields ++ [field]

         # Determine group_by value based on accumulated fields
         group_by =
           case new_accumulated_fields do
             [single_field] -> single_field
             multiple_fields -> multiple_fields
           end

         # Derive aggregations from variables
         aggregations = derive_aggregations_for_group(group.level, report)

         # Build configuration
         config = %{
           group_by: group_by,
           level: group.level,
           aggregations: aggregations,
           sort: group.sort || :asc
         }

         Logger.debug("""
         Group #{group.name} (level #{group.level}):
           - Extracted field: #{inspect(field)}
           - Accumulated fields: #{inspect(new_accumulated_fields)}
           - Group by: #{inspect(group_by)}
           - Aggregations: #{inspect(aggregations)}
         """)

         {configs ++ [config], new_accumulated_fields}

       {:error, reason} ->
         Logger.warning("""
         Failed to extract field from group #{group.name} at level #{group.level}:
         #{inspect(reason)}
         Skipping this group configuration.
         """)

         {configs ++ [nil], accumulated_fields}
     end
   rescue
     error ->
       Logger.error("""
       Failed to build aggregation config for group #{inspect(group)}:
       #{inspect(error)}
       """)

       {configs ++ [nil], accumulated_fields}
   end
   ```

3. **Add helper function: extract_field_for_group/1**

   **Purpose**: Centralize field extraction logic with proper error handling

   ```elixir
   defp extract_field_for_group(group) do
     case ExpressionParser.extract_field_with_fallback(group.expression, group.name) do
       {:ok, field} -> {:ok, field}
       error -> error
     end
   end
   ```

### Phase 2: Update build_aggregation_config_for_group/2 (Refactoring)

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex`
**Lines**: 437-476

**Option A: Keep for backward compatibility (recommended)**
- Keep existing function as-is
- Mark with `@deprecated` tag
- Document migration path to new cumulative approach

**Option B: Remove entirely**
- Since it's only called from build_grouped_aggregations_from_dsl/1
- Can be safely removed once new approach is implemented
- Extract reusable logic (derive_aggregations_for_group) to separate function

**Recommendation**: Keep for now, remove in future refactor after testing.

### Phase 3: Maintain Field Order Consistency

**Challenge**: Ensure field order matches database query sort order

The groups are already sorted by level (line 431), which ensures proper hierarchical order:
- Level 1 fields come first
- Level 2 fields come second
- Level 3+ fields follow in sequence

**Implementation**: No additional changes needed - the accumulation algorithm naturally preserves order.

**Validation**: Add assertion in tests to verify field order matches group level order.

---

## Edge Cases and Handling

### Case 1: Single-Level Grouping

**Input**:
```elixir
groups = [%{level: 1, expression: expr(region)}]
```

**Expected Output**:
```elixir
[%{group_by: :region, level: 1, ...}]
```

**Handling**:
- When accumulated_fields = `[:region]` (single item)
- Return atom directly: `group_by: :region`
- Not wrapped in list: ✅ Correct

**Code**:
```elixir
group_by =
  case new_accumulated_fields do
    [single_field] -> single_field
    multiple_fields -> multiple_fields
  end
```

### Case 2: Missing Levels (Sparse Hierarchy)

**Input**:
```elixir
groups = [
  %{level: 1, expression: expr(region)},
  %{level: 3, expression: expr(product)}  # Missing level 2!
]
```

**Expected Behavior**:
- Accumulate fields regardless of level numbers
- Level numbers are just metadata for band rendering
- Grouping hierarchy is based on order, not level numbers

**Output**:
```elixir
[
  %{group_by: :region, level: 1, ...},
  %{group_by: [:region, :product], level: 3, ...}
]
```

**Handling**: No special logic needed - accumulation works regardless of level numbers.

### Case 3: Expression Parsing Failure

**Input**:
```elixir
groups = [
  %{level: 1, expression: valid_expr(region)},
  %{level: 2, expression: invalid_complex_expr()},  # Parsing fails
  %{level: 3, expression: expr(product)}
]
```

**Expected Behavior**:
- Log warning for level 2
- Add `nil` to configs
- Continue with level 3
- **Critical**: What should accumulated_fields be for level 3?

**Option A**: Skip failed level entirely (recommended)
```elixir
{configs ++ [nil], accumulated_fields}  # Don't add to accumulated_fields
```
Result for level 3: `group_by: [:region, :product]` ✅

**Option B**: Use fallback name
```elixir
{configs ++ [nil], accumulated_fields ++ [group.name]}
```
Result for level 3: `group_by: [:region, :customer_group, :product]` ❌ (uses group name, not field)

**Recommendation**: Use Option A - skip failed levels entirely to avoid invalid field names in group_by.

### Case 4: No Groups Defined

**Input**:
```elixir
groups = []
```

**Current Behavior** (line 422-425):
```elixir
case groups do
  [] ->
    Logger.debug("No groups defined in report, skipping aggregation configuration")
    []
```

**Expected Behavior**: Return empty list ✅

**Handling**: No changes needed - handled before entering reduce.

### Case 5: Duplicate Field Names

**Input**:
```elixir
groups = [
  %{level: 1, expression: expr(region)},
  %{level: 2, expression: expr(region)}  # Same field name!
]
```

**Expected Output**:
```elixir
[
  %{group_by: :region, level: 1, ...},
  %{group_by: [:region, :region], level: 2, ...}  # Is this valid?
]
```

**ProducerConsumer Handling** (lines 686-695 in producer_consumer.ex):
```elixir
defp extract_group_value(record, group_by) when is_list(group_by) do
  # Multi-field grouping - create tuple of values
  values = Enum.map(group_by, fn field -> Map.get(record, field) end)
  List.to_tuple(values)
end
```

**Result**: Would create tuple `{region_value, region_value}` which is valid but semantically meaningless.

**Recommendation**: Add validation in build_cumulative_config/4 to detect duplicates:
```elixir
if field in accumulated_fields do
  Logger.warning("Duplicate field #{inspect(field)} in group hierarchy at level #{group.level}")
end
```

Don't fail - just warn. Let it proceed as duplicate groupings might be intentional in edge cases.

---

## Testing Strategy

### Unit Tests

**File**: `test/ash_reports/typst/data_loader_test.exs`

**Test Cases**:

1. **Test: Three-level cumulative grouping**
   ```elixir
   test "builds cumulative grouping configs for three-level hierarchy" do
     groups = [
       %Group{level: 1, name: :territory, expression: expr(territory)},
       %Group{level: 2, name: :customer, expression: expr(customer_name)},
       %Group{level: 3, name: :order_type, expression: expr(order_type)}
     ]

     report = %Report{groups: groups, variables: []}

     result = DataLoader.build_grouped_aggregations_from_dsl(report)

     assert length(result) == 3
     assert Enum.at(result, 0).group_by == :territory
     assert Enum.at(result, 1).group_by == [:territory, :customer_name]
     assert Enum.at(result, 2).group_by == [:territory, :customer_name, :order_type]
   end
   ```

2. **Test: Single-level grouping returns atom**
   ```elixir
   test "single-level grouping returns atom not list" do
     groups = [%Group{level: 1, name: :region, expression: expr(region)}]
     report = %Report{groups: groups, variables: []}

     result = DataLoader.build_grouped_aggregations_from_dsl(report)

     assert length(result) == 1
     assert Enum.at(result, 0).group_by == :region  # Not [:region]
   end
   ```

3. **Test: Missing levels (sparse hierarchy)**
   ```elixir
   test "handles missing levels correctly" do
     groups = [
       %Group{level: 1, expression: expr(region)},
       %Group{level: 5, expression: expr(product)}
     ]
     report = %Report{groups: groups, variables: []}

     result = DataLoader.build_grouped_aggregations_from_dsl(report)

     assert length(result) == 2
     assert Enum.at(result, 0).group_by == :region
     assert Enum.at(result, 1).group_by == [:region, :product]
   end
   ```

4. **Test: Expression parsing failure**
   ```elixir
   test "skips groups with unparseable expressions" do
     groups = [
       %Group{level: 1, expression: expr(valid_field)},
       %Group{level: 2, expression: {:invalid, "expression"}},
       %Group{level: 3, expression: expr(another_field)}
     ]
     report = %Report{groups: groups, variables: []}

     result = DataLoader.build_grouped_aggregations_from_dsl(report)

     assert length(result) == 2  # Middle one filtered out
     assert Enum.at(result, 0).group_by == :valid_field
     assert Enum.at(result, 1).group_by == [:valid_field, :another_field]
   end
   ```

5. **Test: Empty groups list**
   ```elixir
   test "returns empty list when no groups defined" do
     report = %Report{groups: [], variables: []}

     result = DataLoader.build_grouped_aggregations_from_dsl(report)

     assert result == []
   end
   ```

6. **Test: Field order preservation**
   ```elixir
   test "preserves field order based on group level" do
     groups = [
       %Group{level: 2, expression: expr(customer)},  # Intentionally out of order
       %Group{level: 1, expression: expr(territory)},
       %Group{level: 3, expression: expr(product)}
     ]
     report = %Report{groups: groups, variables: []}

     result = DataLoader.build_grouped_aggregations_from_dsl(report)

     # Should be sorted by level before processing
     assert Enum.at(result, 0).group_by == :territory
     assert Enum.at(result, 1).group_by == [:territory, :customer]
     assert Enum.at(result, 2).group_by == [:territory, :customer, :product]
   end
   ```

### Integration Tests

**File**: `test/ash_reports/typst/streaming_pipeline_test.exs`

**Test Case**: End-to-end cumulative grouping in streaming pipeline

```elixir
test "streaming pipeline correctly groups with cumulative fields" do
  # Setup report with 2-level grouping
  report = build_test_report_with_groups([
    %{level: 1, field: :region},
    %{level: 2, field: :customer_id}
  ])

  # Create test data
  records = [
    %{region: "West", customer_id: 1, amount: 100},
    %{region: "West", customer_id: 1, amount: 200},
    %{region: "West", customer_id: 2, amount: 150},
    %{region: "East", customer_id: 3, amount: 300}
  ]

  # Start streaming pipeline
  {:ok, _stream_id, stream} = StreamingPipeline.start_pipeline([
    domain: TestDomain,
    resource: TestResource,
    query: build_query(records),
    report_config: build_report_config(report),
    grouped_aggregations: DataLoader.build_grouped_aggregations_from_dsl(report)
  ])

  # Consume stream
  results = Enum.to_list(stream)

  # Get final aggregation state from ProducerConsumer
  # (Requires adding introspection API to ProducerConsumer)
  final_state = get_final_aggregation_state(stream_id)

  # Verify level 1 grouping (by region only)
  west_totals = final_state[[:region]]["West"]
  assert west_totals.sum == 450  # 100 + 200 + 150
  assert west_totals.count == 3

  east_totals = final_state[[:region]]["East"]
  assert east_totals.sum == 300
  assert east_totals.count == 1

  # Verify level 2 grouping (by region AND customer_id)
  west_customer_1 = final_state[[:region, :customer_id]][{"West", 1}]
  assert west_customer_1.sum == 300  # 100 + 200
  assert west_customer_1.count == 2

  west_customer_2 = final_state[[:region, :customer_id]][{"West", 2}]
  assert west_customer_2.sum == 150
  assert west_customer_2.count == 1

  east_customer_3 = final_state[[:region, :customer_id]][{"East", 3}]
  assert east_customer_3.sum == 300
  assert east_customer_3.count == 1
end
```

**Note**: This test requires adding introspection capability to ProducerConsumer to expose aggregation state. This is outside the scope of 2.4.3 but should be tracked for future work.

### Visual Regression Tests

**File**: `test/ash_reports/typst/visual_regression_test.exs`

**Test Case**: Verify group totals render correctly in generated PDF

```elixir
test "cumulative grouping renders correct subtotals in PDF" do
  # Generate report with 2-level grouping
  {:ok, pdf_path} = generate_test_report_with_grouping()

  # Extract text from PDF
  {:ok, text} = extract_pdf_text(pdf_path)

  # Verify group headers and totals appear
  assert text =~ "Region: West"
  assert text =~ "Customer #1 Total: $300.00"
  assert text =~ "Customer #2 Total: $150.00"
  assert text =~ "West Region Total: $450.00"

  assert text =~ "Region: East"
  assert text =~ "Customer #3 Total: $300.00"
  assert text =~ "East Region Total: $300.00"
end
```

---

## Performance Considerations

### Memory Impact

**Current Approach** (Enum.map):
- Processes each group independently
- No additional memory overhead beyond list comprehension

**New Approach** (Enum.reduce with accumulator):
- Accumulates field list during iteration
- Memory overhead: `O(n)` where n = number of groups
- Typical case: 2-3 groups → ~100 bytes overhead
- Worst case: 10 groups → ~400 bytes overhead

**Impact**: Negligible - memory overhead is minimal compared to actual data processing.

### CPU Impact

**Current Approach**:
- `n` iterations (one per group)
- Each iteration: parse expression + derive aggregations

**New Approach**:
- `n` iterations (one per group)
- Each iteration: parse expression + derive aggregations + list concatenation

**Additional Operations**:
- List concatenation: `O(m)` where m = accumulated fields
- Total additional cost: `O(n²)` in worst case (n groups, each concatenating up to n fields)
- Practical impact: With typical 2-3 groups, cost is negligible (< 1ms)

**Impact**: Negligible - CPU overhead is minimal for typical group counts (< 5).

### ProducerConsumer Impact

**Memory per Group Config**:
```elixir
# Current:
%{group_by: :territory, ...}  # Single field
# Memory: ~600 bytes per unique territory value

# New:
%{group_by: [:territory, :customer_name], ...}  # Multi-field
# Memory: ~600 bytes per unique (territory, customer_name) tuple
```

**Key Insight**: Memory usage is determined by **unique group values**, not field count.

**Example**:
- 5 territories → 5 groups → 3 KB
- 5 territories × 20 customers → 100 groups → 60 KB
- 5 territories × 20 customers × 10 order types → 1000 groups → 600 KB

**Max Groups Protection** (producer_consumer.ex, line 589):
```elixir
max_groups: @default_max_groups_per_config  # 10,000 per grouping config
```

**Impact**: Cumulative grouping increases memory usage linearly with data cardinality, but protection limits are already in place.

---

## Risks and Mitigations

### Risk 1: Breaking Change for Existing Reports

**Risk**: Existing reports expecting flat grouping may break

**Mitigation**:
1. This is a new feature being added to an in-development system
2. No production reports exist yet (Stage 2.4 is still in progress)
3. Add comprehensive tests to validate new behavior
4. Document in migration guide if needed later

**Likelihood**: Low
**Impact**: Medium
**Overall**: Low Risk

### Risk 2: Expression Parser Failures

**Risk**: Complex expressions may fail to parse, breaking group hierarchy

**Mitigation**:
1. Expression parser already has fallback mechanism (extract_field_with_fallback)
2. Comprehensive error handling with logging
3. Skip failed groups instead of failing entire pipeline
4. Add test coverage for edge cases

**Likelihood**: Medium
**Impact**: Low (graceful degradation)
**Overall**: Low Risk

### Risk 3: Memory Growth with Deep Hierarchies

**Risk**: Reports with many group levels could accumulate large field lists

**Mitigation**:
1. Practical limit: Most reports have 2-4 group levels
2. Field list memory is negligible (~100 bytes for 10 fields)
3. ProducerConsumer has max_groups protection
4. Monitor memory usage in performance tests

**Likelihood**: Low
**Impact**: Low
**Overall**: Very Low Risk

### Risk 4: Field Order Bugs

**Risk**: Incorrect field order could produce wrong grouping results

**Mitigation**:
1. Groups already sorted by level before processing
2. Add explicit test for field order preservation
3. Document field order requirements
4. Add assertion in code to verify sort order

**Likelihood**: Low
**Impact**: High (would produce incorrect results)
**Overall**: Medium Risk → **Requires careful testing**

---

## Success Criteria

### Functional Requirements

- [ ] Single-level grouping returns atom (not list)
- [ ] Multi-level grouping returns accumulated field list
- [ ] Field order matches group level order
- [ ] Expression parsing failures are handled gracefully
- [ ] Empty groups list returns empty result
- [ ] Sparse level numbers (1, 3, 5) work correctly

### Non-Functional Requirements

- [ ] Memory overhead < 1 KB for typical reports
- [ ] CPU overhead < 5% compared to current implementation
- [ ] All existing tests continue to pass
- [ ] No breaking changes to public API
- [ ] Clear error messages for parsing failures

### Testing Requirements

- [ ] 6+ unit tests covering edge cases
- [ ] Integration test with ProducerConsumer
- [ ] Visual regression test for PDF output
- [ ] Performance benchmark showing negligible impact
- [ ] Test coverage > 95% for new code

---

## Implementation Checklist

### Phase 1: Code Implementation

- [ ] Refactor `build_grouped_aggregations_from_dsl/1` to use Enum.reduce
- [ ] Add `build_cumulative_config/4` helper function
- [ ] Add `extract_field_for_group/1` helper function
- [ ] Add duplicate field detection (warning only)
- [ ] Update existing log messages to show accumulated fields
- [ ] Add code comments explaining cumulative algorithm

### Phase 2: Testing

- [ ] Write 6 unit tests (see Testing Strategy section)
- [ ] Write integration test with ProducerConsumer
- [ ] Write visual regression test for PDF output
- [ ] Add performance benchmark for group config building
- [ ] Verify all existing tests pass
- [ ] Add test for field order preservation

### Phase 3: Documentation

- [ ] Update function documentation for `build_grouped_aggregations_from_dsl/1`
- [ ] Add code examples showing cumulative grouping
- [ ] Update planning/typst_refactor_plan.md with completion status
- [ ] Document breaking changes (if any)
- [ ] Add migration guide section (for future reference)

### Phase 4: Code Review

- [ ] Self-review implementation against this plan
- [ ] Check error handling coverage
- [ ] Verify log messages are clear and helpful
- [ ] Ensure code follows Elixir style guide
- [ ] Validate test coverage meets requirements

---

## Future Enhancements

### Enhancement 1: Explicit Group Dependencies

Instead of implicit accumulation by level order, allow explicit dependencies:

```elixir
groups = [
  %{level: 1, name: :territory, field: :territory, depends_on: []},
  %{level: 2, name: :customer, field: :customer_id, depends_on: [:territory]},
  %{level: 3, name: :product, field: :product_id, depends_on: [:territory, :customer]}
]
```

**Benefit**: More explicit, self-documenting, allows validation of dependencies

### Enhancement 2: Grouping Expression Language

Support complex grouping expressions beyond simple fields:

```elixir
%{
  level: 2,
  expression: expr(fragment("date_trunc('month', ?)", order_date)),
  field_alias: :order_month
}
```

**Benefit**: More powerful grouping capabilities (time bucketing, calculated groups)

### Enhancement 3: ProducerConsumer Introspection API

Add public API to query aggregation state:

```elixir
ProducerConsumer.get_grouped_aggregations(stream_id)
# Returns: %{[:region] => %{"West" => %{sum: 450, count: 3}}}
```

**Benefit**: Enables testing, debugging, and real-time monitoring

---

## Questions for Review

1. **Should we keep build_aggregation_config_for_group/2?**
   - Current plan: Keep for now, deprecate later
   - Alternative: Remove immediately since it's only called in one place

2. **How should duplicate fields be handled?**
   - Current plan: Warn but allow
   - Alternative: Raise error to prevent invalid configurations

3. **Should field order validation be strict?**
   - Current plan: Rely on Enum.sort_by, add assertion
   - Alternative: Add explicit validation step with clear error messages

4. **Should we add ProducerConsumer introspection API now?**
   - Current plan: Defer to future work
   - Alternative: Add minimal API for testing purposes

5. **Should this feature be configurable?**
   - Current plan: Always use cumulative grouping
   - Alternative: Add option to enable/disable cumulative behavior

---

## Conclusion

This plan provides a comprehensive approach to implementing cumulative grouping in the AshReports DataLoader. The implementation is straightforward (reduce instead of map), has minimal performance impact, and properly handles edge cases. The key insight is that we need to accumulate fields across iterations rather than processing each group independently.

**Next Steps**:
1. Review this plan with Pascal for approval
2. Implement Phase 1 (code changes)
3. Implement Phase 2 (testing)
4. Complete checklist items
5. Mark Section 2.4.3 as complete in typst_refactor_plan.md

**Estimated Effort**: 4-6 hours (2 hours coding, 2-4 hours testing)
**Risk Level**: Low
**Priority**: High (blocks Section 2.4.4 integration testing)
