# Chart Pipeline Integration - Phase 1 Implementation Plan

**Status**: Ready for Implementation  
**Version**: 1.0  
**Last Updated**: 2025-01-06  
**Estimated Duration**: 2 weeks (10 working days)  
**Owner**: Development Team

---

## Executive Summary

Phase 1 establishes the foundation for declarative chart definitions by creating a Chart DataLoader module, implementing a Transform DSL, integrating charts into the existing pipeline, and ensuring 100% backwards compatibility with imperative charts.

**Key Objectives:**
1. Enable basic declarative charts using `driving_resource` + `transform` DSL
2. Achieve 100% backwards compatibility with existing imperative charts
3. Reduce chart code by 60% for common patterns
4. Maintain <10ms pipeline overhead for simple charts
5. Provide clear migration path from imperative to declarative

**Success Metrics:**
- All 8 existing demo charts continue working without modification
- At least 2 demo charts converted to declarative style
- Unit test coverage >90% for new modules
- Integration tests pass for both imperative and declarative modes
- Documentation complete with migration examples

---

## Implementation Order & Dependencies

### Dependency Graph

```
Phase 1.1: Chart DataLoader
    ↓
Phase 1.2: Transform DSL ← (depends on DataLoader)
    ↓
Phase 1.3: Pipeline Integration ← (depends on DataLoader + Transform)
    ↓
Phase 1.4: Backwards Compatibility ← (depends on Pipeline Integration)
    ↓
Phase 1.5: Integration Tests ← (depends on all above)
```

**Critical Path**: DataLoader → Transform → Pipeline → Compatibility → Tests

**Parallel Work Opportunities**:
- Documentation can be written alongside implementation
- Unit tests can be written immediately after each module
- Backwards compatibility layer can start during Pipeline Integration

---

## Phase 1.1: Chart DataLoader Module (Days 1-2)

**Goal**: Create module to load chart data through AshReports pipeline  
**Duration**: 2 days  
**Risk Level**: Medium (integrating with existing DataLoader)

### Prerequisites

Before starting, study these existing modules:
1. `/lib/ash_reports/data_loader/data_loader.ex` - Main DataLoader API and patterns
2. `/lib/ash_reports/query_builder.ex` - Query building patterns
3. `/lib/ash_reports/charts/data_source_helpers.ex` - Current optimization patterns
4. `/lib/ash_reports/charts/charts.ex` - Current chart execution flow

### Implementation Steps

#### Step 1.1.1: Module Structure Setup (2 hours)

**File**: `/lib/ash_reports/charts/data_loader.ex`

**Tasks**:
1. Create module skeleton with `@moduledoc` documenting purpose and examples
2. Define public API functions:
   ```elixir
   @spec load_chart_data(module(), atom(), map()) :: 
     {:ok, {records :: [map()], metadata :: map()}} | {:error, term()}
   
   @spec load_chart_data(module(), atom(), map(), keyword()) :: 
     {:ok, {records :: [map()], metadata :: map()}} | {:error, term()}
   ```
3. Add `@type` definitions for return values
4. Import required modules: `AshReports.{QueryBuilder, Domain.Info}`

**Acceptance Criteria**:
- Module compiles without errors
- Dialyzer shows no warnings
- Documentation generates correctly with `mix docs`

**Code Template**:
```elixir
defmodule AshReports.Charts.DataLoader do
  @moduledoc """
  Loads chart data through the AshReports pipeline architecture.
  
  This module enables declarative chart definitions using `driving_resource`
  and `scope` functions, integrating charts into the same optimized pipeline
  used by reports.
  
  ## Examples
  
      # Load data for a declarative chart
      {:ok, {records, metadata}} = DataLoader.load_chart_data(
        MyApp.Domain,
        :customer_distribution,
        %{region: "West"}
      )
  """
  
  alias AshReports.{QueryBuilder, Domain.Info}
  
  @type load_options :: [
    streaming: boolean(),
    batch_size: pos_integer(),
    actor: term()
  ]
  
  @type load_result :: {
    records :: [map()],
    metadata :: %{
      record_count: non_neg_integer(),
      execution_time_ms: non_neg_integer(),
      source_records: non_neg_integer()
    }
  }
end
```

#### Step 1.1.2: Chart Definition Detection (3 hours)

**Tasks**:
1. Implement `detect_chart_mode/1` to determine if chart is declarative or imperative
2. Implement `parse_chart_definition/1` to extract driving_resource and scope
3. Add validation for chart definition completeness
4. Handle error cases with clear messages

**Logic Flow**:
```elixir
defp detect_chart_mode(chart) do
  cond do
    has_driving_resource?(chart) -> {:ok, :declarative}
    has_data_source_function?(chart) -> {:ok, :imperative}
    true -> {:error, :missing_data_source}
  end
end

defp has_driving_resource?(%{driving_resource: resource}) 
  when is_atom(resource), do: true
defp has_driving_resource?(_), do: false

defp has_data_source_function?(%{data_source: fun}) 
  when is_function(fun, 0), do: true
defp has_data_source_function?(_), do: false
```

**Error Cases to Handle**:
- Chart has neither `driving_resource` nor `data_source`
- `driving_resource` is not a valid Ash resource
- `scope` function returns invalid query
- Parameters validation fails

**Unit Tests** (write alongside implementation):
```elixir
# test/ash_reports/charts/data_loader_test.exs
describe "detect_chart_mode/1" do
  test "returns :declarative for chart with driving_resource"
  test "returns :imperative for chart with data_source function"
  test "returns error for chart with neither"
end

describe "parse_chart_definition/1" do
  test "extracts driving_resource from chart"
  test "extracts scope function if present"
  test "handles missing scope gracefully"
end
```

#### Step 1.1.3: QueryBuilder Integration (3 hours)

**Tasks**:
1. Implement `build_chart_query/3` that leverages existing QueryBuilder
2. Apply chart's `scope` function to filter data
3. Pass parameters to scope function
4. Handle scope validation errors

**Implementation**:
```elixir
defp build_chart_query(chart, params, _opts) do
  # Create a minimal report-like structure for QueryBuilder
  report_like = %{
    driving_resource: chart.driving_resource,
    parameters: chart.parameters || [],
    scope: chart.scope,
    groups: [],  # Charts don't use report-style grouping
    bands: []    # Charts don't have bands
  }
  
  # Use existing QueryBuilder
  case QueryBuilder.build(report_like, params) do
    {:ok, query} -> {:ok, query}
    {:error, reason} -> {:error, {:query_build_failed, reason}}
  end
end
```

**Key Considerations**:
- Chart parameters use same structure as report parameters
- Scope function receives validated parameters
- QueryBuilder handles parameter validation automatically
- Reuse existing parameter validation logic

**Unit Tests**:
```elixir
describe "build_chart_query/3" do
  test "builds query from driving_resource"
  test "applies scope function with parameters"
  test "validates parameters before building query"
  test "returns error for invalid parameters"
end
```

#### Step 1.1.4: Query Execution (3 hours)

**Tasks**:
1. Execute query using `Ash.read/2`
2. Capture execution metadata (time, record count)
3. Handle execution errors gracefully
4. Support actor for authorization

**Implementation**:
```elixir
defp execute_chart_query(query, domain, opts) do
  start_time = System.monotonic_time(:millisecond)
  
  read_opts = [domain: domain]
  read_opts = if opts[:actor], do: Keyword.put(read_opts, :actor, opts[:actor]), else: read_opts
  
  case Ash.read(query, read_opts) do
    {:ok, records} ->
      end_time = System.monotonic_time(:millisecond)
      
      metadata = %{
        record_count: length(records),
        execution_time_ms: end_time - start_time,
        source_records: length(records)
      }
      
      {:ok, {records, metadata}}
      
    {:error, error} ->
      {:error, {:query_execution_failed, error}}
  end
end
```

**Error Handling**:
- Wrap Ash errors with chart context
- Provide clear error messages
- Include chart name in error metadata
- Don't swallow authorization errors

**Unit Tests**:
```elixir
describe "execute_chart_query/3" do
  test "executes query and returns records with metadata"
  test "includes execution time in metadata"
  test "passes actor for authorization"
  test "handles query errors gracefully"
end
```

#### Step 1.1.5: Main API Implementation (2 hours)

**Tasks**:
1. Implement `load_chart_data/3` public function
2. Implement `load_chart_data/4` with options
3. Wire together: detect → parse → build → execute
4. Add comprehensive error handling

**Implementation**:
```elixir
@doc """
Loads data for a chart through the pipeline.

Supports both declarative charts (driving_resource + scope) and 
imperative charts (data_source function). Automatically detects
chart mode and routes appropriately.
"""
@spec load_chart_data(module(), atom(), map(), load_options()) :: 
  {:ok, load_result()} | {:error, term()}
def load_chart_data(domain, chart_name, params, opts \\ []) do
  with {:ok, chart} <- get_chart(domain, chart_name),
       {:ok, mode} <- detect_chart_mode(chart),
       {:ok, result} <- load_by_mode(mode, domain, chart, params, opts) do
    {:ok, result}
  end
end

defp load_by_mode(:declarative, domain, chart, params, opts) do
  with {:ok, query} <- build_chart_query(chart, params, opts),
       {:ok, result} <- execute_chart_query(query, domain, opts) do
    {:ok, result}
  end
end

defp load_by_mode(:imperative, _domain, chart, _params, _opts) do
  # Delegate to existing imperative execution
  # This will be implemented in Phase 1.4
  {:error, :imperative_not_yet_supported}
end
```

**Unit Tests**:
```elixir
describe "load_chart_data/3" do
  test "loads declarative chart successfully"
  test "returns metadata with record count"
  test "applies parameters to scope"
  test "returns error for invalid chart name"
end
```

### Deliverables

1. **Module**: `lib/ash_reports/charts/data_loader.ex` (250-300 LOC)
2. **Tests**: `test/ash_reports/charts/data_loader_test.exs` (150-200 LOC, 12+ tests)
3. **Documentation**: Module docs with 3+ usage examples

### Risk Mitigation

**Risk**: QueryBuilder expects report structure, charts are different  
**Mitigation**: Create adapter layer that wraps chart as report-like structure

**Risk**: Existing DataLoader might not be suitable for charts  
**Mitigation**: Keep Charts.DataLoader independent, only reuse QueryBuilder

**Risk**: Performance overhead from pipeline  
**Mitigation**: Add benchmarks early, optimize if needed

---

## Phase 1.2: Transform DSL Implementation (Days 3-5)

**Goal**: Create DSL for declarative data transformations  
**Duration**: 3 days  
**Risk Level**: High (new DSL design, critical for user experience)

### Prerequisites

Before starting, study:
1. `/lib/ash_reports/dsl.ex` - Spark DSL patterns and entity definitions
2. `/lib/ash_reports/variable.ex` - Variable aggregation patterns
3. `/lib/ash_reports/group_processor.ex` - Group-by processing patterns
4. Spark DSL documentation for entity/section patterns

### Implementation Steps

#### Step 1.2.1: Transform Module Structure (4 hours)

**File**: `/lib/ash_reports/charts/transform.ex`

**Tasks**:
1. Define `Transform` struct with all fields
2. Create parser functions for DSL blocks
3. Create executor functions for applying transforms
4. Document with comprehensive examples

**Transform Struct**:
```elixir
defmodule AshReports.Charts.Transform do
  @moduledoc """
  Declarative data transformation DSL for charts.
  
  Transforms allow grouping, aggregating, and mapping data from
  driving_resource records into chart-ready format.
  """
  
  defstruct [
    :group_by,        # Field or expression to group by
    aggregates: [],   # List of aggregation operations
    mappings: %{},    # Chart field mappings (category, value, x, y)
    filters: [],      # Post-aggregation filters
    sort_by: nil,     # Sort results by field
    limit: nil        # Limit number of results
  ]
  
  @type aggregate_type :: :count | :sum | :avg | :min | :max
  
  @type aggregate :: %{
    type: aggregate_type(),
    field: atom() | Ash.Expr.t(),
    as: atom()
  }
  
  @type t :: %__MODULE__{
    group_by: atom() | Ash.Expr.t() | nil,
    aggregates: [aggregate()],
    mappings: %{atom() => atom() | Ash.Expr.t()},
    filters: [function()],
    sort_by: {atom(), :asc | :desc} | nil,
    limit: pos_integer() | nil
  }
end
```

**Key Design Decisions**:
- Use struct for transform definition (not GenServer/Agent)
- Keep transforms pure - no side effects
- Make transforms composable
- Support both atoms and Ash expressions

#### Step 1.2.2: Spark DSL Integration (6 hours)

**File**: `/lib/ash_reports/dsl.ex` (modify existing)

**Tasks**:
1. Add `transform` section to chart entities
2. Define `group_by`, `aggregate`, and mapping macros
3. Create entity schemas for transform components
4. Update chart entities to include transform

**DSL Structure**:
```elixir
# In chart entity definition
def pie_chart_entity do
  %Entity{
    name: :pie_chart,
    # ... existing fields ...
    entities: [
      # Add transform section
      transform: [transform_entity()]
    ]
  }
end

def transform_entity do
  %Section{
    name: :transform,
    describe: "Data transformation pipeline for chart",
    schema: [
      group_by: [
        type: {:or, [:atom, {:custom, Ash.Expr, :expr, []}]},
        doc: "Field or expression to group records by"
      ],
      sort_by: [
        type: {:or, [:atom, {:tuple, [:atom, {:in, [:asc, :desc]}]}]},
        doc: "Field and direction to sort results"
      ],
      limit: [
        type: :pos_integer,
        doc: "Maximum number of results to return"
      ]
    ],
    entities: [
      aggregate_entity(),
      mapping_entity()
    ]
  }
end
```

**Example Usage** (target syntax):
```elixir
pie_chart :status_distribution do
  driving_resource Customer
  
  transform do
    group_by :status
    aggregate :count, as: :customer_count
    
    as_category expr(status)
    as_value expr(customer_count)
  end
  
  config do
    title "Customer Status Distribution"
  end
end
```

**Unit Tests**:
```elixir
describe "Transform DSL parsing" do
  test "parses group_by with atom field"
  test "parses group_by with Ash expression"
  test "parses aggregate declarations"
  test "parses mapping macros"
  test "validates transform structure"
end
```

#### Step 1.2.3: Group-By Implementation (4 hours)

**Tasks**:
1. Implement in-memory grouping using `Enum.group_by/2`
2. Support atom fields: `group_by :status`
3. Support Ash expressions: `group_by expr(product.category.name)`
4. Handle nil values in grouping field

**Implementation**:
```elixir
defp apply_group_by(records, nil), do: {:ok, %{nil => records}}

defp apply_group_by(records, group_by) do
  grouped = Enum.group_by(records, fn record ->
    resolve_group_value(record, group_by)
  end)
  
  {:ok, grouped}
rescue
  error -> {:error, {:group_by_failed, error}}
end

defp resolve_group_value(record, field) when is_atom(field) do
  Map.get(record, field)
end

defp resolve_group_value(record, %Ash.Expr{} = expression) do
  # Resolve Ash expression against record
  case AshReports.ExpressionEvaluator.evaluate(expression, record) do
    {:ok, value} -> value
    {:error, _} -> nil
  end
end
```

**Edge Cases**:
- Grouping field is nil
- Grouping field doesn't exist on record
- Expression evaluation fails
- Multiple records with same group value

**Unit Tests**:
```elixir
describe "group_by" do
  test "groups by simple atom field"
  test "groups by Ash expression"
  test "handles nil group values"
  test "handles nested field access"
  test "returns all records when group_by is nil"
end
```

#### Step 1.2.4: Aggregate Implementation (6 hours)

**Tasks**:
1. Implement `:count` aggregation
2. Implement `:sum` aggregation
3. Implement `:avg` aggregation
4. Implement `:min` and `:max` aggregations
5. Handle Decimal types correctly

**Implementation**:
```elixir
defp apply_aggregates(grouped_records, aggregates) do
  Enum.map(grouped_records, fn {group_key, records} ->
    aggregate_values = 
      Enum.reduce(aggregates, %{}, fn agg, acc ->
        value = compute_aggregate(agg, records)
        Map.put(acc, agg.as, value)
      end)
    
    {group_key, aggregate_values}
  end)
  |> Map.new()
end

defp compute_aggregate(%{type: :count}, records) do
  length(records)
end

defp compute_aggregate(%{type: :sum, field: field}, records) do
  records
  |> Enum.map(&get_field_value(&1, field))
  |> Enum.reject(&is_nil/1)
  |> sum_values()
end

defp compute_aggregate(%{type: :avg, field: field}, records) do
  values = 
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
  
  if values == [] do
    nil
  else
    sum = sum_values(values)
    count = length(values)
    divide_values(sum, count)
  end
end

# Handle both regular numbers and Decimals
defp sum_values([first | _rest] = values) when is_struct(first, Decimal) do
  Enum.reduce(values, Decimal.new(0), &Decimal.add/2)
end

defp sum_values(values) do
  Enum.sum(values)
end
```

**Unit Tests**:
```elixir
describe "aggregates" do
  test "count returns number of records in group"
  test "sum totals numeric field values"
  test "sum handles Decimal values"
  test "avg calculates mean of field values"
  test "avg handles empty groups"
  test "min finds minimum value"
  test "max finds maximum value"
  test "aggregates ignore nil values"
end
```

#### Step 1.2.5: Data Mapping (4 hours)

**Tasks**:
1. Implement `as_category` for pie/bar charts
2. Implement `as_value` for pie/bar charts
3. Implement `as_x` and `as_y` for line/scatter charts
4. Handle missing or nil values

**Implementation**:
```elixir
defp apply_mappings(aggregated_data, mappings, group_by_field) do
  aggregated_data
  |> Enum.map(fn {group_key, aggregate_values} ->
    # Build chart data point
    data_point = %{}
    
    # Apply each mapping
    data_point = 
      Enum.reduce(mappings, data_point, fn {chart_field, source}, acc ->
        value = resolve_mapping_value(source, group_key, aggregate_values, group_by_field)
        Map.put(acc, chart_field, value)
      end)
    
    data_point
  end)
  |> Enum.reject(&has_nil_required_fields?/1)
end

defp resolve_mapping_value(atom, _group_key, aggregate_values, _group_by) 
  when is_atom(atom) do
  Map.get(aggregate_values, atom)
end

defp resolve_mapping_value(expr, group_key, aggregate_values, group_by) 
  when is_struct(expr, Ash.Expr) do
  # Evaluate expression with group_key and aggregate values available
  # This is simplified - actual implementation needs full expression evaluator
  nil
end
```

**Mapping Examples**:
```elixir
# Pie chart
as_category expr(status)      # Maps group_by value to :category
as_value expr(customer_count) # Maps aggregate to :value

# Line chart  
as_x expr(month)              # Maps group_by to :x
as_y expr(total_revenue)      # Maps aggregate to :y

# Results in:
[
  %{category: "active", value: 150},
  %{category: "inactive", value: 45}
]

[
  %{x: "2024-01", y: 15000.50},
  %{x: "2024-02", y: 18250.75}
]
```

**Unit Tests**:
```elixir
describe "mappings" do
  test "as_category maps to category field"
  test "as_value maps to value field"
  test "as_x and as_y map for scatter plots"
  test "handles missing aggregate values"
  test "filters out records with nil required fields"
end
```

#### Step 1.2.6: Transform Execution Pipeline (4 hours)

**Tasks**:
1. Create main `execute/2` function
2. Chain operations: group → aggregate → map
3. Apply optional sort and limit
4. Return chart-ready data

**Implementation**:
```elixir
@doc """
Executes a transform on records, returning chart-ready data.

## Examples

    transform = %Transform{
      group_by: :status,
      aggregates: [%{type: :count, as: :count}],
      mappings: %{category: :status, value: :count}
    }
    
    {:ok, chart_data} = Transform.execute(transform, records)
    # => [%{category: "active", value: 150}, ...]
"""
@spec execute(t(), [map()]) :: {:ok, [map()]} | {:error, term()}
def execute(%Transform{} = transform, records) when is_list(records) do
  with {:ok, grouped} <- apply_group_by(records, transform.group_by),
       aggregated <- apply_aggregates(grouped, transform.aggregates),
       mapped <- apply_mappings(aggregated, transform.mappings, transform.group_by),
       sorted <- apply_sort(mapped, transform.sort_by),
       limited <- apply_limit(sorted, transform.limit) do
    {:ok, limited}
  end
end

defp apply_sort(data, nil), do: data
defp apply_sort(data, {field, direction}) do
  Enum.sort_by(data, &Map.get(&1, field), direction)
end

defp apply_limit(data, nil), do: data
defp apply_limit(data, limit), do: Enum.take(data, limit)
```

**Unit Tests**:
```elixir
describe "execute/2" do
  test "transforms records to chart data"
  test "applies group_by, aggregate, and mapping"
  test "sorts results when sort_by specified"
  test "limits results when limit specified"
  test "returns error on invalid transform"
end
```

### Deliverables

1. **Module**: `lib/ash_reports/charts/transform.ex` (400-500 LOC)
2. **DSL Updates**: Modifications to `lib/ash_reports/dsl.ex` (100-150 LOC)
3. **Tests**: `test/ash_reports/charts/transform_test.exs` (300+ LOC, 20+ tests)
4. **Documentation**: Transform guide with 5+ examples

### Risk Mitigation

**Risk**: DSL complexity confuses users  
**Mitigation**: Provide many examples, start with simple cases

**Risk**: Expression evaluation is complex  
**Mitigation**: Start with simple atom fields, add expressions incrementally

**Risk**: Performance issues with large datasets  
**Mitigation**: Benchmark early, use Stream if needed

---

## Phase 1.3: Pipeline Integration (Days 6-7)

**Goal**: Integrate charts into execution pipeline  
**Duration**: 2 days  
**Risk Level**: Medium (integration complexity)

### Implementation Steps

#### Step 1.3.1: Chart Runner Updates (4 hours)

**File**: Modify existing chart execution (likely in `Charts` module or LiveView)

**Tasks**:
1. Detect declarative vs imperative charts
2. Route declarative charts through DataLoader + Transform
3. Keep imperative charts using existing path
4. Preserve all metadata

**Implementation**:
```elixir
# In chart viewer/runner
def execute_chart(domain, chart_name, params) do
  chart = AshReports.Domain.Info.chart(domain, chart_name)
  
  case detect_chart_type(chart) do
    :declarative ->
      execute_declarative_chart(domain, chart, params)
    
    :imperative ->
      execute_imperative_chart(domain, chart, params)
  end
end

defp execute_declarative_chart(domain, chart, params) do
  with {:ok, {records, loader_metadata}} <- 
         AshReports.Charts.DataLoader.load_chart_data(domain, chart.name, params),
       {:ok, chart_data} <- apply_transform_if_present(chart, records),
       {:ok, svg} <- AshReports.Charts.generate(chart.type, chart_data, chart.config) do
    metadata = Map.merge(loader_metadata, %{
      mode: :declarative,
      chart_data_points: length(chart_data)
    })
    
    {:ok, svg, metadata}
  end
end

defp apply_transform_if_present(chart, records) do
  if chart.transform do
    AshReports.Charts.Transform.execute(chart.transform, records)
  else
    # No transform, return records as-is
    {:ok, records}
  end
end
```

**Unit Tests**:
```elixir
describe "chart execution" do
  test "declarative charts use pipeline"
  test "imperative charts use legacy path"
  test "metadata includes mode and metrics"
  test "transform applied after data loading"
end
```

#### Step 1.3.2: Telemetry Events (3 hours)

**Tasks**:
1. Add telemetry events for chart pipeline stages
2. Include chart name, type, and mode in metadata
3. Measure duration of each stage
4. Document events for users

**Events to Emit**:
```elixir
# Data loading stage
:telemetry.execute(
  [:ash_reports, :charts, :data_loading, :start],
  %{system_time: System.system_time()},
  %{chart_name: name, chart_type: type, mode: :declarative}
)

:telemetry.execute(
  [:ash_reports, :charts, :data_loading, :stop],
  %{duration: duration, record_count: count},
  %{chart_name: name, chart_type: type, mode: :declarative}
)

# Transform stage
:telemetry.execute(
  [:ash_reports, :charts, :transform, :start],
  %{system_time: System.system_time()},
  %{chart_name: name}
)

:telemetry.execute(
  [:ash_reports, :charts, :transform, :stop],
  %{duration: duration, data_points: count},
  %{chart_name: name}
)
```

**Documentation**:
Create `guides/telemetry/chart_events.md` documenting all events

**Unit Tests**:
```elixir
describe "telemetry" do
  test "emits data_loading start/stop events"
  test "emits transform start/stop events"
  test "includes correct metadata"
  test "measures duration accurately"
end
```

#### Step 1.3.3: Configuration Options (2 hours)

**Tasks**:
1. Add application config for chart mode
2. Support `:auto`, `:declarative`, `:legacy` modes
3. Add config validation
4. Document configuration options

**Configuration**:
```elixir
# config/config.exs
config :ash_reports, :chart_mode, :auto  # default

# :auto - Detect based on chart definition
# :declarative - Force declarative (error on imperative)
# :legacy - Force imperative (ignore driving_resource)
```

**Implementation**:
```elixir
defp should_use_declarative?(chart) do
  mode = Application.get_env(:ash_reports, :chart_mode, :auto)
  
  case mode do
    :auto -> has_driving_resource?(chart)
    :declarative -> true
    :legacy -> false
    _ -> raise "Invalid chart_mode: #{mode}"
  end
end
```

### Deliverables

1. **Integration Code**: Modifications to chart execution (100-150 LOC)
2. **Telemetry**: Event definitions and documentation
3. **Tests**: Integration tests (100+ LOC, 10+ tests)
4. **Config Documentation**: Configuration guide

---

## Phase 1.4: Backwards Compatibility Layer (Days 8-9)

**Goal**: Ensure 100% compatibility with imperative charts  
**Duration**: 2 days  
**Risk Level**: Low (mostly validation)

### Implementation Steps

#### Step 1.4.1: Imperative Chart Support (4 hours)

**Tasks**:
1. Keep existing `data_source(fn -> ... end)` working
2. Support all return formats: `data`, `{:ok, data}`, `{:ok, data, metadata}`
3. Execute data_source functions without modification
4. Preserve metadata

**Implementation**:
```elixir
defp execute_imperative_chart(_domain, chart, _params) do
  case chart.data_source.() do
    {:ok, data, metadata} ->
      {:ok, data, Map.put(metadata, :mode, :imperative)}
    
    {:ok, data} ->
      {:ok, data, %{mode: :imperative}}
    
    data when is_list(data) ->
      {:ok, data, %{mode: :imperative}}
    
    {:error, reason} ->
      {:error, reason}
  end
end
```

**Validation Tests**:
- Test all 8 existing demo charts without modification
- Verify outputs match previous implementation
- Check metadata is preserved

#### Step 1.4.2: Deprecation Warnings (3 hours)

**Tasks**:
1. Log warning when imperative chart executed
2. Include migration guide link in warning
3. Only log once per chart per application boot
4. Make warnings configurable

**Implementation**:
```elixir
defmodule AshReports.Charts.DeprecationWarnings do
  @moduledoc false
  use Agent
  
  def start_link(_opts) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end
  
  def warn_imperative_chart(chart_name) do
    if Application.get_env(:ash_reports, :show_deprecation_warnings, true) do
      Agent.get_and_update(__MODULE__, fn warned ->
        if MapSet.member?(warned, chart_name) do
          {false, warned}
        else
          {true, MapSet.put(warned, chart_name)}
        end
      end)
      |> maybe_log_warning(chart_name)
    end
  end
  
  defp maybe_log_warning(true, chart_name) do
    Logger.warning("""
    [AshReports Deprecation] Chart :#{chart_name} uses imperative data_source.
    
    Consider migrating to declarative style with driving_resource for:
    - Automatic N+1 query optimization
    - 60% less code
    - Better testability
    
    See: https://hexdocs.pm/ash_reports/migrating-charts.html
    """)
  end
  
  defp maybe_log_warning(false, _), do: :ok
end
```

**Unit Tests**:
```elixir
describe "deprecation warnings" do
  test "logs warning on first imperative chart execution"
  test "does not log on subsequent executions"
  test "respects :show_deprecation_warnings config"
  test "includes migration guide link"
end
```

#### Step 1.4.3: Compatibility Testing (4 hours)

**Tasks**:
1. Run full test suite with all demo charts
2. Test mixed imperative + declarative in same domain
3. Verify no breaking changes
4. Document compatibility guarantees

**Test Suite**:
```elixir
# test/ash_reports/charts/backwards_compatibility_test.exs
defmodule AshReports.Charts.BackwardsCompatibilityTest do
  use ExUnit.Case
  
  describe "imperative charts" do
    test "all 8 demo charts execute without errors" do
      charts = [
        :customer_status_distribution,
        :monthly_revenue,
        :product_sales_by_category,
        :top_products_by_revenue,
        :inventory_levels_over_time,
        :price_quantity_analysis,
        :invoice_payment_timeline,
        :customer_health_trend
      ]
      
      Enum.each(charts, fn chart_name ->
        assert {:ok, _svg, _metadata} = 
          AshReportsDemo.execute_chart(chart_name, %{})
      end)
    end
    
    test "imperative and declarative charts work together"
    test "metadata format is consistent"
    test "no performance regression"
  end
end
```

### Deliverables

1. **Compatibility Layer**: Imperative execution support (100 LOC)
2. **Deprecation System**: Warning infrastructure (80 LOC)
3. **Tests**: Comprehensive compatibility tests (200+ LOC, 15+ tests)
4. **Documentation**: Compatibility guarantees document

---

## Phase 1.5: Integration Tests (Day 10)

**Goal**: End-to-end validation of Phase 1  
**Duration**: 1 day  
**Risk Level**: Low (validation phase)

### Test Suites

#### Suite 1.5.1: Simple Declarative Chart (2 hours)

**Tests**:
```elixir
describe "simple declarative pie chart" do
  test "executes successfully with driving_resource"
  test "applies group_by and count aggregation"
  test "produces valid chart data format"
  test "generates SVG successfully"
  test "includes metadata with record count"
end

describe "simple declarative bar chart" do
  test "executes with transform"
  test "sorts results correctly"
  test "limits to top N results"
  test "handles nil values gracefully"
end
```

#### Suite 1.5.2: Backwards Compatibility (2 hours)

**Tests**:
```elixir
describe "imperative chart compatibility" do
  test "all 8 demo charts work unchanged"
  test "data_source function executes"
  test "metadata preserved"
  test "deprecation warning logged"
end

describe "mixed mode domain" do
  test "declarative and imperative charts coexist"
  test "correct execution path chosen per chart"
  test "telemetry events distinguish modes"
end
```

#### Suite 1.5.3: Performance Validation (2 hours)

**Tests**:
```elixir
describe "performance" do
  test "declarative chart with :large dataset completes in <5s" do
    # Generate :large dataset (325K records)
    AshReportsDemo.DataGenerator.generate(:large)
    
    {duration, {:ok, _svg, _metadata}} = 
      :timer.tc(fn ->
        AshReportsDemo.execute_chart(:product_sales_by_category, %{})
      end)
    
    assert duration < 5_000_000  # 5 seconds in microseconds
  end
  
  test "pipeline overhead <50ms for simple chart" do
    # Compare declarative vs imperative execution time
    # Overhead should be minimal
  end
  
  test "memory usage reasonable for large datasets"
end
```

### Deliverables

1. **Integration Tests**: 3 test suites (300+ LOC, 20+ tests)
2. **Performance Benchmarks**: Documented results
3. **Test Report**: Summary of coverage and results

---

## Concrete Examples

### Example 1: Simple Pie Chart Migration

**Before (Imperative - 15 lines)**:
```elixir
pie_chart :customer_status_distribution do
  data_source(fn ->
    source_records =
      AshReportsDemo.Customer
      |> Ash.Query.new()
      |> Ash.read!(domain: AshReportsDemo.Domain)

    chart_data =
      source_records
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, customers} ->
        %{
          category: status |> Atom.to_string() |> String.capitalize(),
          value: length(customers)
        }
      end)

    {:ok, chart_data, %{source_records: length(source_records)}}
  end)
  
  config do
    title "Customer Status Distribution"
  end
end
```

**After (Declarative - 10 lines, 33% reduction)**:
```elixir
pie_chart :customer_status_distribution do
  driving_resource Customer
  
  transform do
    group_by :status
    aggregate :count, as: :customer_count
    
    as_category expr(status |> to_string() |> capitalize())
    as_value expr(customer_count)
  end
  
  config do
    title "Customer Status Distribution"
  end
end
```

### Example 2: Bar Chart with Relationships

**Before (Imperative with manual optimization - 25 lines)**:
```elixir
bar_chart :product_sales_by_category do
  data_source(fn ->
    {:ok, {line_items, products_map}} =
      AshReports.Charts.DataSourceHelpers.load_related_batch(
        AshReportsDemo.InvoiceLineItem
        |> Ash.Query.new()
        |> Ash.read!(domain: AshReportsDemo.Domain),
        :product_id,
        AshReportsDemo.Product,
        domain: AshReportsDemo.Domain,
        preload: :category
      )

    chart_data =
      line_items
      |> Enum.filter(&Map.has_key?(products_map, &1.product_id))
      |> Enum.group_by(fn item ->
        product = products_map[item.product_id]
        if product.category, do: product.category.name, else: "Uncategorized"
      end)
      |> Enum.map(fn {category, items} ->
        %{category: category, value: length(items)}
      end)
      |> Enum.sort_by(& &1.value, :desc)

    {:ok, chart_data, %{source_records: length(line_items)}}
  end)
  
  config do
    title "Sales by Product Category"
  end
end
```

**After (Declarative with automatic optimization - 11 lines, 56% reduction)**:
```elixir
bar_chart :product_sales_by_category do
  driving_resource InvoiceLineItem
  
  transform do
    group_by expr(product.category.name)
    aggregate :count, as: :item_count
    
    as_category expr(group_key)
    as_value expr(item_count)
    
    sort_by {:value, :desc}
  end
  
  config do
    title "Sales by Product Category"
  end
end
```

**Key Improvements**:
- No manual relationship optimization needed
- Clearer intent with declarative DSL
- Automatic N+1 prevention
- 56% code reduction

---

## Risk Assessment & Mitigation

### High-Risk Areas

#### Risk 1: Transform DSL Too Complex
**Probability**: Medium  
**Impact**: High (poor user experience)  
**Mitigation**:
- Start with simple cases (atom fields only)
- Provide comprehensive examples
- Get early user feedback
- Add helper macros for common patterns

#### Risk 2: Performance Regression
**Probability**: Low  
**Impact**: High (adoption blocker)  
**Mitigation**:
- Benchmark early and often
- Set performance targets upfront (<10ms overhead)
- Add fast-path for simple charts
- Profile with real datasets

#### Risk 3: Breaking Existing Charts
**Probability**: Low  
**Impact**: Critical (breaks production)  
**Mitigation**:
- Extensive backwards compatibility testing
- Run full demo suite on every change
- No changes to imperative execution path
- Beta testing period

### Medium-Risk Areas

#### Risk 4: Integration Complexity
**Probability**: Medium  
**Impact**: Medium (delays)  
**Mitigation**:
- Keep Chart.DataLoader independent
- Reuse QueryBuilder without modification
- Clear interface boundaries
- Integration tests early

#### Risk 5: Documentation Gaps
**Probability**: Medium  
**Impact**: Medium (poor adoption)  
**Mitigation**:
- Write docs alongside code
- Provide migration examples
- Document all error cases
- User testing of docs

### Low-Risk Areas

#### Risk 6: Telemetry Overhead
**Probability**: Low  
**Impact**: Low  
**Mitigation**:
- Telemetry is very efficient
- Make telemetry optional if needed
- Minimal metadata

---

## Testing Strategy

### Unit Test First Approach

For each module/function:
1. Write tests BEFORE implementation
2. Test happy path first
3. Add edge cases
4. Test error conditions
5. Achieve >90% coverage

### Test Pyramid

```
        Integration Tests (20 tests)
       /                            \
      /     Backwards Compat (15)    \
     /    Transform Tests (20)         \
    /  DataLoader Tests (12)             \
   /__________Unit Tests (67)______________\
```

**Total Tests**: ~67 unit tests + 20 integration tests = 87 tests

### Testing Checklist

- [ ] All public functions have unit tests
- [ ] All error cases have tests
- [ ] Edge cases documented and tested
- [ ] Integration tests pass
- [ ] Demo charts work
- [ ] Performance benchmarks pass
- [ ] No Dialyzer warnings
- [ ] No Credo warnings
- [ ] Coverage >90%

---

## Time Estimates

### Detailed Breakdown

| Phase | Tasks | Estimated Time | Buffer | Total |
|-------|-------|----------------|--------|-------|
| 1.1 Chart DataLoader | 5 major tasks | 13 hours | 3 hours | 16 hours (2 days) |
| 1.2 Transform DSL | 6 major tasks | 28 hours | 4 hours | 32 hours (4 days) |
| 1.3 Pipeline Integration | 3 major tasks | 9 hours | 3 hours | 12 hours (1.5 days) |
| 1.4 Backwards Compat | 3 major tasks | 11 hours | 3 hours | 14 hours (1.75 days) |
| 1.5 Integration Tests | 3 test suites | 6 hours | 2 hours | 8 hours (1 day) |
| **TOTAL** | | **67 hours** | **15 hours** | **82 hours (10.25 days)** |

### Assumptions

- Developer has experience with Elixir and Ash
- Existing modules (DataLoader, QueryBuilder) work as documented
- No major design changes required during implementation
- Review and feedback cycles included in buffer
- Working days = 8 hours

### Critical Path

Days 1-2 → Days 3-5 → Days 6-7 → Days 8-9 → Day 10

No parallel work possible on critical path, but documentation and unit tests can be done alongside.

---

## Success Criteria

### Must Have (Phase 1 Complete)

- [ ] `AshReports.Charts.DataLoader` module complete with tests
- [ ] Transform DSL implemented and integrated
- [ ] At least 2 demo charts converted to declarative
- [ ] All 8 demo charts still work (imperative)
- [ ] >90% test coverage on new code
- [ ] Integration tests pass
- [ ] No Dialyzer warnings
- [ ] Documentation complete with examples
- [ ] Performance targets met (<10ms overhead)

### Nice to Have (Stretch Goals)

- [ ] 3+ demo charts converted to declarative
- [ ] Performance guide updated
- [ ] Video walkthrough of migration
- [ ] Community feedback incorporated
- [ ] Migration tool prototype started

### Metrics

**Code Quality**:
- Credo score: No warnings
- Dialyzer: No errors
- Test coverage: >90%
- Documentation coverage: 100% of public functions

**Performance**:
- Pipeline overhead: <10ms for simple charts
- Large dataset (325K): <5 seconds
- Memory usage: <1.5x baseline

**User Experience**:
- Code reduction: 60% for common patterns
- Migration guide: <10 minutes to read
- First declarative chart: <5 minutes to write

---

## Next Steps After Phase 1

Once Phase 1 is complete and validated:

1. **Phase 2 Planning** (1 day)
   - Review Phase 1 learnings
   - Adjust Phase 2 plan based on feedback
   - Identify optimization opportunities

2. **User Feedback** (1 week)
   - Share with beta users
   - Collect feedback on DSL
   - Gather migration pain points

3. **Phase 2 Kickoff** (Week 3)
   - Advanced transformations
   - Relationship optimization
   - Complex aggregations

---

## Appendix A: Module Dependencies

```
AshReports.Charts.DataLoader
  ├─ depends on: AshReports.QueryBuilder
  ├─ depends on: AshReports.Domain.Info
  └─ depends on: Ash.Query

AshReports.Charts.Transform
  ├─ depends on: Ash.Expr (for expressions)
  └─ depends on: (no major dependencies)

AshReports.Dsl (modifications)
  ├─ depends on: Spark.Dsl
  └─ extends: existing chart entities

Integration Layer
  ├─ depends on: Charts.DataLoader
  ├─ depends on: Charts.Transform
  └─ depends on: existing Charts module
```

---

## Appendix B: File Structure

```
lib/ash_reports/
  charts/
    data_loader.ex              # NEW - 300 LOC
    transform.ex                # NEW - 500 LOC
    deprecation_warnings.ex     # NEW - 80 LOC
    charts.ex                   # MODIFIED - +100 LOC
  dsl.ex                        # MODIFIED - +150 LOC

test/ash_reports/
  charts/
    data_loader_test.exs        # NEW - 200 LOC, 12 tests
    transform_test.exs          # NEW - 300 LOC, 20 tests
    backwards_compatibility_test.exs  # NEW - 200 LOC, 15 tests
    integration/
      declarative_charts_test.exs     # NEW - 150 LOC, 10 tests
      performance_test.exs            # NEW - 100 LOC, 5 tests

guides/user/
  migrating-charts.md           # NEW
  declarative-charts.md         # NEW

notes/features/
  chart-pipeline-phase-1.md     # THIS DOCUMENT
```

**Total New Code**: ~1,200 LOC (implementation) + ~950 LOC (tests)  
**Total Modified Code**: ~250 LOC  
**Total Documentation**: ~1,500 words across 2 guides

---

## Appendix C: Quick Start Checklist

When starting implementation:

**Day 1 Morning**:
- [ ] Create feature branch: `feature/chart-pipeline-phase-1`
- [ ] Review existing DataLoader and QueryBuilder code
- [ ] Create `lib/ash_reports/charts/data_loader.ex` skeleton
- [ ] Write first 3 unit tests

**Day 1 Afternoon**:
- [ ] Implement chart mode detection
- [ ] Implement QueryBuilder integration
- [ ] Run tests, fix failures
- [ ] Commit: "Add Charts.DataLoader structure"

**Day 3 Morning**:
- [ ] Start Transform module
- [ ] Define Transform struct
- [ ] Implement group_by for atoms
- [ ] Write 5 unit tests

Continue following daily breakdown in main sections above.

---

## Document Maintenance

**Review Schedule**: Weekly during implementation  
**Update Triggers**: Major design changes, risk events, timeline changes  
**Owner**: Development Team Lead  

**Version History**:
- v1.0 (2025-01-06): Initial comprehensive plan created

---

**END OF DOCUMENT**
