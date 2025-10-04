# Feature Planning: Stage 2.4.1 - Expression Parsing and Field Extraction

**Feature ID**: Stage 2.4.1
**Created**: 2025-10-01
**Status**: Planning
**Priority**: High
**Category**: DSL-Driven Grouped Aggregation Configuration

## Overview

Implementation of expression parsing and field extraction for Section 2.4.1 of the Typst refactor plan. This feature enables automatic configuration of the streaming pipeline's grouped aggregations from AshReports DSL group definitions by parsing `Ash.Expr.t()` expressions and extracting field names.

## Problem Statement

### Current State

The streaming pipeline's `ProducerConsumer` supports grouped aggregations via manual configuration:

```elixir
ProducerConsumer.start_link(
  stream_id: "sales-report",
  subscribe_to: [{producer, []}],
  grouped_aggregations: [
    %{
      group_by: :region,
      aggregations: [:sum, :count, :avg]
    }
  ]
)
```

However, AshReports already has rich DSL definitions for groups:

```elixir
%AshReports.Group{
  name: :by_region,
  level: 1,
  expression: expr(customer.region),  # Ash.Expr.t()
  sort: :asc
}
```

### The Gap

There is no automated way to:

1. Parse `Ash.Expr.t()` expressions from group definitions
2. Extract the actual field names used for grouping (e.g., `customer.region` → `:region`)
3. Handle nested field access and relationship traversal
4. Validate expressions before attempting to use them
5. Provide fallback mechanisms for unparseable expressions

### Challenges with Ash.Expr Parsing

Based on research of the existing codebase (`GroupProcessor`, `CalculationEngine`), `Ash.Expr.t()` expressions have complex internal structure:

```elixir
# Simple field reference
%Ash.Expr{expression: {:ref, [], :field_name}}
%Ash.Expr{expression: :field_name}

# Relationship traversal (customer.region)
%Ash.Expr{expression: {:get_path, _, [%{expression: {:ref, [], :customer}}, :region]}}

# Complex nested relationships
{:field, :customer, :region}
{:field, :rel1, :rel2, :field_name}
```

The challenge is extracting meaningful field names from these varied structures while handling edge cases gracefully.

## Research Conducted

### 1. Existing Code Analysis

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/group_processor.ex`

The `GroupProcessor` module already has partial expression parsing logic:

```elixir
# Lines 332-362: evaluate_group_expression/2
defp evaluate_group_expression(expression, record) do
  case expression do
    # Simple field reference
    field when is_atom(field) ->
      Map.get(record, field)

    # Ash.Expr expressions
    %{__struct__: Ash.Expr} = ash_expr ->
      evaluate_ash_expression_for_group(ash_expr, record)

    # Nested field reference
    {:field, relationship, field} ->
      evaluate_nested_field(record, [relationship, field])

    # Complex nested field
    {:field, rel1, rel2, field} ->
      evaluate_nested_field(record, [rel1, rel2, field])
    # ...
  end
end

# Lines 394-414: extract_field_from_ash_expr_for_group/1
defp extract_field_from_ash_expr_for_group(ash_expr) do
  try do
    case ash_expr do
      %{expression: {:ref, [], field}} when is_atom(field) ->
        {:ok, field}

      %{expression: field} when is_atom(field) ->
        {:ok, field}

      # Handle relationship traversal like addresses.state
      %{expression: {:get_path, _, [%{expression: {:ref, [], rel}}, field]}} ->
        {:ok, [rel, field]}

      _ ->
        :error
    end
  rescue
    _error -> :error
  end
end
```

**Key Insights**:
- Pattern matching on `Ash.Expr` struct already exists
- Handles simple refs and get_path for relationship traversal
- Returns `{:ok, field}` or `{:ok, [rel, field]}` for nested paths
- Uses error tuples for unparseable expressions

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/calculation_engine.ex`

The `CalculationEngine` provides evaluation capabilities but focuses on computing values rather than extracting field names. It validates expressions (lines 88-98) and provides error handling patterns we can adopt.

**File**: `/home/ducky/code/ash_reports/planning/grouped_aggregation_dsl_integration.md`

Lines 280-285 show the exact extraction pattern we need to implement:

```elixir
defp extract_field_from_expression({:field, field_name}), do: field_name
defp extract_field_from_expression({:field, _rel, field_name}), do: field_name
defp extract_field_from_expression(expr) when is_atom(expr), do: expr
# Handle Ash.Expr.t() parsing...
```

### 2. DSL Structure Analysis

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/group.ex`

```elixir
@type t :: %__MODULE__{
  name: atom(),
  level: pos_integer(),
  expression: Ash.Expr.t(),  # This is what we need to parse
  sort: :asc | :desc
}
```

**File**: `/home/ducky/code/ash_reports/test/support/test_helpers.ex` (lines 158-163)

Test fixture showing real-world group usage:

```elixir
groups: [
  %AshReports.Group{
    name: :by_region,
    level: 1,
    expression: {:field, :customer, :region}
  }
]
```

### 3. Integration Points

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex`

The `DataLoader` module is where we'll implement the DSL-to-ProducerConsumer configuration mapping. Current state shows the module has:
- Access to report definitions (lines 129-138)
- Streaming pipeline creation (lines 267-293)
- Report configuration building (lines 324-332)

This is the ideal location for `build_grouped_aggregations_from_dsl/1` function.

## Solution Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     AshReports.Typst.DataLoader                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  load_for_typst/4                                               │
│    │                                                             │
│    ├──> get_report_definition/2                                 │
│    │      └─> Extract groups: [%Group{expression: Ash.Expr}]   │
│    │                                                             │
│    ├──> build_grouped_aggregations_from_dsl/1  ← NEW            │
│    │      │                                                      │
│    │      ├──> parse_group_expressions/1                        │
│    │      │     └─> extract_field_from_expression/1  ← CORE     │
│    │      │           │                                          │
│    │      │           ├─> Pattern: Simple atom                  │
│    │      │           ├─> Pattern: {:field, name}               │
│    │      │           ├─> Pattern: {:field, rel, name}          │
│    │      │           ├─> Pattern: Ash.Expr simple ref          │
│    │      │           ├─> Pattern: Ash.Expr get_path            │
│    │      │           └─> Fallback: Return group name           │
│    │      │                                                      │
│    │      ├──> map_variables_to_aggregations/2                  │
│    │      │     └─> Extract variable types (:sum, :avg, etc)    │
│    │      │                                                      │
│    │      └──> generate_aggregation_config/2                    │
│    │            └─> Build ProducerConsumer config format        │
│    │                                                             │
│    └──> create_streaming_pipeline/4                             │
│           └─> Pass generated config to ProducerConsumer         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

         ↓ Configuration flows to ↓

┌─────────────────────────────────────────────────────────────────┐
│           StreamingPipeline.ProducerConsumer                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  grouped_aggregations: [                                        │
│    %{                                                            │
│      group_by: :region,           ← Extracted from expression   │
│      aggregations: [:sum, :count] ← Derived from variables      │
│    }                                                             │
│  ]                                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Core Module: ExpressionParser

Create a new focused module for expression parsing:

**Location**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/expression_parser.ex`

**Responsibilities**:
1. Parse `Ash.Expr.t()` expressions
2. Extract field names from various expression formats
3. Handle relationship traversal patterns
4. Validate expressions before extraction
5. Provide descriptive error information

**Public API**:

```elixir
defmodule AshReports.Typst.ExpressionParser do
  @moduledoc """
  Parses Ash.Expr.t() expressions to extract field names for grouped aggregations.

  Supports:
  - Simple field references: :field_name
  - Tuple notation: {:field, :name} or {:field, :rel, :name}
  - Ash expressions: expr(customer.region)
  - Complex nested relationships

  Used by DataLoader to automatically configure streaming pipeline
  grouped aggregations from Report DSL definitions.
  """

  @type expression :: atom() | tuple() | Ash.Expr.t()
  @type field_name :: atom()
  @type field_path :: [atom()]
  @type extraction_result :: {:ok, field_name()} | {:ok, field_path()} | {:error, term()}

  @doc """
  Extracts the field name from an expression.

  Returns the final field name in the path for grouping purposes.
  For relationship traversal like customer.region, returns :region.

  ## Examples

      iex> extract_field(:customer_name)
      {:ok, :customer_name}

      iex> extract_field({:field, :customer, :region})
      {:ok, :region}

      iex> extract_field(expr(customer.region))
      {:ok, :region}

      iex> extract_field(unparseable_expr)
      {:error, {:unparseable_expression, unparseable_expr}}
  """
  @spec extract_field(expression()) :: extraction_result()
  def extract_field(expression)

  @doc """
  Extracts the full field path from an expression.

  Returns the complete path for relationship traversal.

  ## Examples

      iex> extract_field_path({:field, :customer, :region})
      {:ok, [:customer, :region]}

      iex> extract_field_path(:simple_field)
      {:ok, [:simple_field]}
  """
  @spec extract_field_path(expression()) :: extraction_result()
  def extract_field_path(expression)

  @doc """
  Validates that an expression is parseable.

  ## Examples

      iex> validate_expression(:field_name)
      :ok

      iex> validate_expression({:complex, :unparseable, :thing})
      {:error, {:unsupported_expression_type, {:complex, :unparseable, :thing}}}
  """
  @spec validate_expression(expression()) :: :ok | {:error, term()}
  def validate_expression(expression)

  @doc """
  Extracts field with fallback to a default value.

  Useful when you must have a field name for configuration.

  ## Examples

      iex> extract_field_with_fallback({:field, :region}, :default_field)
      :region

      iex> extract_field_with_fallback(unparseable_expr, :fallback_name)
      :fallback_name
  """
  @spec extract_field_with_fallback(expression(), field_name()) :: field_name()
  def extract_field_with_fallback(expression, fallback)
end
```

### Enhanced DataLoader Integration

**Location**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex`

Add new private functions:

```elixir
defp build_grouped_aggregations_from_dsl(report) do
  groups = report.groups || []
  variables = report.variables || []

  groups
  |> Enum.map(fn group ->
    build_aggregation_config_for_group(group, variables)
  end)
  |> Enum.reject(&is_nil/1)
end

defp build_aggregation_config_for_group(group, variables) do
  case ExpressionParser.extract_field(group.expression) do
    {:ok, field_name} ->
      aggregation_types = derive_aggregations_for_group(group, variables)

      %{
        group_by: field_name,
        aggregations: aggregation_types
      }

    {:error, reason} ->
      Logger.warning("""
      Failed to parse group expression for #{group.name}: #{inspect(reason)}
      Using group name as fallback field.
      """)

      # Fallback: use group name as field
      aggregation_types = derive_aggregations_for_group(group, variables)

      %{
        group_by: group.name,
        aggregations: aggregation_types
      }
  end
end

defp derive_aggregations_for_group(group, variables) do
  # Find variables that reset at this group level
  group_level = group.level

  group_variables =
    variables
    |> Enum.filter(fn var ->
      var.reset_on == :group and var.reset_group == group_level
    end)

  # Map variable types to aggregation types
  group_variables
  |> Enum.map(fn var ->
    case var.type do
      :sum -> :sum
      :count -> :count
      :average -> :avg
      :min -> :min
      :max -> :max
      _ -> nil
    end
  end)
  |> Enum.reject(&is_nil/1)
  |> Enum.uniq()
  |> case do
    [] -> [:sum, :count]  # Default aggregations
    list -> list
  end
end
```

### Pattern Matching Strategy

The `extract_field/1` function will use pattern matching in order of specificity:

```elixir
# Pattern 1: Simple atom (most common in tests)
defp do_extract_field(field) when is_atom(field) do
  {:ok, field}
end

# Pattern 2: Tuple notation - simple {:field, name}
defp do_extract_field({:field, field_name}) when is_atom(field_name) do
  {:ok, field_name}
end

# Pattern 3: Tuple notation - relationship traversal {:field, rel, name}
defp do_extract_field({:field, _relationship, field_name}) when is_atom(field_name) do
  {:ok, field_name}  # Return final field in path
end

# Pattern 4: Multi-level relationship {:field, rel1, rel2, name}
defp do_extract_field({:field, _rel1, _rel2, field_name}) when is_atom(field_name) do
  {:ok, field_name}
end

# Pattern 5: Ash.Expr with simple ref
defp do_extract_field(%Ash.Expr{expression: {:ref, [], field}}) when is_atom(field) do
  {:ok, field}
end

# Pattern 6: Ash.Expr with simple atom expression
defp do_extract_field(%Ash.Expr{expression: field}) when is_atom(field) do
  {:ok, field}
end

# Pattern 7: Ash.Expr with get_path (relationship.field)
defp do_extract_field(%Ash.Expr{expression: {:get_path, _, [%{expression: {:ref, [], _rel}}, field]}})
    when is_atom(field) do
  {:ok, field}  # Return the field being accessed, not the relationship
end

# Pattern 8: Ash.Expr - delegate to existing parser
defp do_extract_field(%Ash.Expr{} = ash_expr) do
  case extract_from_ash_expr(ash_expr) do
    {:ok, result} -> {:ok, result}
    :error -> {:error, {:unparseable_ash_expr, ash_expr}}
  end
end

# Pattern 9: Fallback - unparseable
defp do_extract_field(expression) do
  {:error, {:unsupported_expression_type, expression}}
end
```

### Error Handling Strategy

**Validation Errors** (fail fast during configuration):
- Invalid expression structure → Log warning, use fallback
- Nil or missing expressions → Skip group from aggregation config
- Circular references (future) → Error, halt pipeline setup

**Runtime Errors** (graceful degradation):
- Field not found in record → Return nil for group value
- Type mismatch → Log warning, attempt coercion
- Relationship not loaded → Warning, use nil or relationship ID

**Logging Levels**:
- `debug`: Successfully parsed expression
- `warning`: Used fallback field name
- `error`: Complete failure to configure aggregations

## Implementation Plan

### Step 1: Create ExpressionParser Module

**Tasks**:
1. Create new file `/home/ducky/code/ash_reports/lib/ash_reports/typst/expression_parser.ex`
2. Implement module documentation with clear examples
3. Define type specifications
4. Implement `extract_field/1` with all pattern matching cases
5. Implement `extract_field_path/1` for full path extraction
6. Implement `validate_expression/1` for pre-flight checks
7. Implement `extract_field_with_fallback/2` for safe defaults
8. Add comprehensive pattern guards and error tuples

**Acceptance Criteria**:
- [ ] All 9 expression patterns handled
- [ ] Returns `{:ok, field_name}` for parseable expressions
- [ ] Returns `{:error, reason}` for unparseable expressions
- [ ] No raised exceptions, only error tuples
- [ ] Module documentation includes all supported patterns

### Step 2: Unit Tests for ExpressionParser

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/expression_parser_test.exs`

**Test Cases**:

```elixir
describe "extract_field/1" do
  test "extracts simple atom field" do
    assert ExpressionParser.extract_field(:customer_name) == {:ok, :customer_name}
  end

  test "extracts from {:field, name} tuple" do
    assert ExpressionParser.extract_field({:field, :region}) == {:ok, :region}
  end

  test "extracts field from relationship traversal" do
    assert ExpressionParser.extract_field({:field, :customer, :region}) == {:ok, :region}
  end

  test "extracts from multi-level relationship" do
    assert ExpressionParser.extract_field({:field, :customer, :address, :state}) == {:ok, :state}
  end

  test "extracts from Ash.Expr simple ref" do
    expr = %Ash.Expr{expression: {:ref, [], :amount}}
    assert ExpressionParser.extract_field(expr) == {:ok, :amount}
  end

  test "extracts from Ash.Expr get_path relationship" do
    expr = %Ash.Expr{
      expression: {:get_path, :_, [%{expression: {:ref, [], :customer}}, :region]}
    }
    assert ExpressionParser.extract_field(expr) == {:ok, :region}
  end

  test "returns error for unparseable expression" do
    complex_expr = {:unknown, :pattern, :here}
    assert {:error, {:unsupported_expression_type, _}} =
      ExpressionParser.extract_field(complex_expr)
  end

  test "handles nil expression" do
    assert {:error, _} = ExpressionParser.extract_field(nil)
  end
end

describe "extract_field_path/1" do
  test "returns single element path for simple field" do
    assert ExpressionParser.extract_field_path(:region) == {:ok, [:region]}
  end

  test "returns full path for relationship traversal" do
    assert ExpressionParser.extract_field_path({:field, :customer, :region}) ==
      {:ok, [:customer, :region]}
  end

  test "returns multi-level path" do
    assert ExpressionParser.extract_field_path({:field, :customer, :address, :state}) ==
      {:ok, [:customer, :address, :state]}
  end
end

describe "validate_expression/1" do
  test "validates simple atom" do
    assert ExpressionParser.validate_expression(:field) == :ok
  end

  test "validates tuple notation" do
    assert ExpressionParser.validate_expression({:field, :customer, :name}) == :ok
  end

  test "rejects invalid expression" do
    assert {:error, _} = ExpressionParser.validate_expression({:unsupported, :thing})
  end
end

describe "extract_field_with_fallback/2" do
  test "returns extracted field when parseable" do
    assert ExpressionParser.extract_field_with_fallback(:region, :fallback) == :region
  end

  test "returns fallback when unparseable" do
    assert ExpressionParser.extract_field_with_fallback({:bad, :expr}, :my_fallback) ==
      :my_fallback
  end
end
```

**Acceptance Criteria**:
- [ ] All pattern variations tested
- [ ] Error cases covered
- [ ] Edge cases (nil, empty) tested
- [ ] Test coverage > 95%

### Step 3: Enhance DataLoader with DSL Integration

**Tasks**:
1. Add `alias AshReports.Typst.ExpressionParser` to DataLoader
2. Implement `build_grouped_aggregations_from_dsl/1` private function
3. Implement `build_aggregation_config_for_group/2` with error handling
4. Implement `derive_aggregations_for_group/2` to map variables
5. Integrate into `create_streaming_pipeline/4` - pass config to pipeline
6. Add logging for configuration decisions (debug level)
7. Handle empty groups list gracefully

**Changes to `create_streaming_pipeline/4`**:

```elixir
defp create_streaming_pipeline(domain, report, params, opts) do
  with {:ok, query} <- build_query_from_report(domain, report, params) do
    transformer = build_typst_transformer(report, opts)

    # NEW: Build grouped aggregations from DSL
    grouped_aggregations = build_grouped_aggregations_from_dsl(report)

    Logger.debug("""
    Configured grouped aggregations from DSL:
    #{inspect(grouped_aggregations, pretty: true)}
    """)

    pipeline_opts = [
      domain: domain,
      resource: report.resource,
      query: query,
      transformer: transformer,
      chunk_size: Keyword.get(opts, :chunk_size, 500),
      max_demand: Keyword.get(opts, :max_demand, 1000),
      report_name: report.name,
      report_config: build_report_config(report, params),
      grouped_aggregations: grouped_aggregations  # NEW: Auto-configured!
    ]

    case StreamingPipeline.start_pipeline(pipeline_opts) do
      {:ok, _stream_id, stream} ->
        {:ok, stream}
      {:error, reason} ->
        {:error, {:streaming_pipeline_failed, reason}}
    end
  end
end
```

**Acceptance Criteria**:
- [ ] Reports with groups automatically configure aggregations
- [ ] Reports without groups work unchanged (empty list)
- [ ] Variables with `reset_on: :group` mapped to aggregation types
- [ ] Unparseable expressions logged with warning, fallback used
- [ ] No breaking changes to existing DataLoader API

### Step 4: Integration Tests

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/data_loader_dsl_integration_test.exs`

**Test Scenarios**:

```elixir
defmodule AshReports.Typst.DataLoaderDSLIntegrationTest do
  use AshReports.DataCase

  alias AshReports.Typst.DataLoader

  describe "build_grouped_aggregations_from_dsl/1" do
    test "generates config for single-level grouping" do
      report = build_report_with_groups([
        %Group{name: :by_region, level: 1, expression: {:field, :customer, :region}}
      ])

      config = DataLoader.build_grouped_aggregations_from_dsl(report)

      assert [%{group_by: :region, aggregations: aggregations}] = config
      assert :sum in aggregations
      assert :count in aggregations
    end

    test "generates config for multi-level grouping" do
      report = build_report_with_groups([
        %Group{name: :by_region, level: 1, expression: :region},
        %Group{name: :by_customer, level: 2, expression: {:field, :customer, :name}}
      ])

      config = DataLoader.build_grouped_aggregations_from_dsl(report)

      assert length(config) == 2
      assert Enum.any?(config, &(&1.group_by == :region))
      assert Enum.any?(config, &(&1.group_by == :name))
    end

    test "maps variable types to aggregation types" do
      variables = [
        %Variable{name: :total, type: :sum, reset_on: :group, reset_group: 1},
        %Variable{name: :avg_amount, type: :average, reset_on: :group, reset_group: 1},
        %Variable{name: :record_count, type: :count, reset_on: :group, reset_group: 1}
      ]

      report = build_report_with_groups_and_vars(
        [%Group{name: :by_region, level: 1, expression: :region}],
        variables
      )

      config = DataLoader.build_grouped_aggregations_from_dsl(report)

      assert [%{aggregations: aggs}] = config
      assert :sum in aggs
      assert :avg in aggs
      assert :count in aggs
    end

    test "handles Ash.Expr expressions" do
      ash_expr = %Ash.Expr{expression: {:ref, [], :customer_id}}

      report = build_report_with_groups([
        %Group{name: :by_customer, level: 1, expression: ash_expr}
      ])

      config = DataLoader.build_grouped_aggregations_from_dsl(report)

      assert [%{group_by: :customer_id}] = config
    end

    test "uses fallback for unparseable expressions" do
      unparseable = {:complex, :unsupported, :expression}

      report = build_report_with_groups([
        %Group{name: :by_region, level: 1, expression: unparseable}
      ])

      config = DataLoader.build_grouped_aggregations_from_dsl(report)

      # Should fall back to using group name
      assert [%{group_by: :by_region}] = config
    end

    test "returns empty list when no groups defined" do
      report = %Report{groups: []}

      assert DataLoader.build_grouped_aggregations_from_dsl(report) == []
    end

    test "provides default aggregations when no variables defined" do
      report = build_report_with_groups([
        %Group{name: :by_region, level: 1, expression: :region}
      ], [])

      config = DataLoader.build_grouped_aggregations_from_dsl(report)

      assert [%{aggregations: aggs}] = config
      # Default to sum and count
      assert :sum in aggs
      assert :count in aggs
    end
  end

  describe "streaming pipeline with auto-configured aggregations" do
    @tag :integration
    test "creates streaming pipeline with DSL-derived config" do
      # This would test the full integration with a real report
      # and verify that the streaming pipeline receives the correct config
    end
  end
end
```

**Acceptance Criteria**:
- [ ] Single-level grouping generates correct config
- [ ] Multi-level grouping generates config for each level
- [ ] Variable types correctly mapped to aggregations
- [ ] Ash.Expr expressions properly parsed
- [ ] Fallback mechanism tested
- [ ] Empty/nil cases handled
- [ ] Default aggregations applied

### Step 5: Documentation and Examples

**Tasks**:
1. Update `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex` moduledoc
2. Add section explaining auto-configuration from DSL
3. Provide example showing groups → aggregations mapping
4. Document fallback behavior for unparseable expressions
5. Update planning document with final implementation notes

**Documentation Example to Add**:

```elixir
## Automatic Grouped Aggregation Configuration

DataLoader automatically configures the streaming pipeline's grouped aggregations
based on your Report DSL group and variable definitions.

### Example

    report :sales_by_region do
      driving_resource Sales

      groups do
        group :by_region do
          level 1
          expression expr(customer.region)
        end
      end

      variables do
        variable :region_total do
          type :sum
          expression expr(amount)
          reset_on :group
          reset_group 1
        end
      end
    end

This automatically configures the streaming pipeline as:

    ProducerConsumer.start_link(
      grouped_aggregations: [
        %{
          group_by: :region,        # Extracted from expr(customer.region)
          aggregations: [:sum]      # Derived from variable type :sum
        }
      ]
    )

### Supported Expression Formats

- Simple atom: `:field_name`
- Tuple notation: `{:field, :relationship, :field_name}`
- Ash expressions: `expr(customer.region)` → extracts `:region`
- Multi-level: `{:field, :rel1, :rel2, :field_name}` → extracts `:field_name`

### Fallback Behavior

If an expression cannot be parsed, the system logs a warning and uses the
group's name as the field name. This ensures reports continue to work even
with complex or custom expressions.
```

**Acceptance Criteria**:
- [ ] Moduledoc updated with auto-configuration section
- [ ] Example code demonstrates DSL → config mapping
- [ ] Supported patterns documented
- [ ] Fallback behavior explained
- [ ] Links to ExpressionParser module docs

## Success Criteria

### Functional Requirements

- [ ] **Expression Parsing**: Successfully extracts field names from all 9 pattern types
- [ ] **Ash.Expr Support**: Handles `expr(customer.region)` → `:region` extraction
- [ ] **Relationship Traversal**: Extracts terminal field from nested paths
- [ ] **Error Handling**: Returns error tuples, never raises exceptions
- [ ] **Fallback Mechanism**: Uses group name when expression unparseable
- [ ] **DSL Integration**: DataLoader auto-configures ProducerConsumer from Report DSL
- [ ] **Variable Mapping**: Variables with `reset_on: :group` mapped to aggregation types
- [ ] **Backward Compatibility**: Existing DataLoader API unchanged

### Quality Requirements

- [ ] **Test Coverage**: > 95% for ExpressionParser module
- [ ] **Integration Tests**: Full DSL → streaming pipeline tested
- [ ] **Documentation**: Comprehensive moduledocs with examples
- [ ] **Logging**: Appropriate debug/warning logs for config decisions
- [ ] **Performance**: No measurable overhead in pipeline setup
- [ ] **Code Quality**: Passes Credo checks, follows project style

### Edge Cases Handled

- [ ] Nil expressions → skip group from config
- [ ] Empty groups list → empty aggregations config
- [ ] No variables defined → default to [:sum, :count]
- [ ] Unparseable expressions → fallback to group name
- [ ] Multiple groups same level → all configured independently
- [ ] Variables reset at non-existent level → ignored

## Technical Details

### Dependencies

- **Existing**: `Ash.Expr` struct (from Ash framework)
- **Existing**: `AshReports.Group` struct
- **Existing**: `AshReports.Variable` struct
- **Existing**: `AshReports.Typst.DataLoader` module
- **New**: `AshReports.Typst.ExpressionParser` module (to be created)

### File Locations

**New Files**:
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/expression_parser.ex`
- `/home/ducky/code/ash_reports/test/ash_reports/typst/expression_parser_test.exs`
- `/home/ducky/code/ash_reports/test/ash_reports/typst/data_loader_dsl_integration_test.exs`

**Modified Files**:
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex` (add private functions)

### Integration with Existing Systems

**GroupProcessor**: The ExpressionParser can leverage patterns from `GroupProcessor.extract_field_from_ash_expr_for_group/1` but will be more focused on field name extraction rather than value evaluation.

**CalculationEngine**: Uses similar error handling patterns and validation approach, but ExpressionParser is specialized for parsing structure, not computing values.

**DataProcessor**: No direct integration, but both will handle the same group definitions. ExpressionParser focuses on configuration time, DataProcessor on runtime.

**StreamingPipeline**: Receives the generated configuration as the `grouped_aggregations` option. No changes needed to pipeline code.

## Testing Strategy

### Unit Tests

**Target**: `ExpressionParser` module
**File**: `test/ash_reports/typst/expression_parser_test.exs`
**Coverage**: All 9 expression patterns + edge cases
**Focus**: Pure function behavior, pattern matching correctness

### Integration Tests

**Target**: DataLoader DSL integration
**File**: `test/ash_reports/typst/data_loader_dsl_integration_test.exs`
**Coverage**: Full report definition → aggregation config flow
**Focus**: DSL parsing, variable mapping, config generation

### Manual Testing

**Scenario 1**: Simple report with one group level
- Create report DSL with `expr(customer.region)`
- Verify ProducerConsumer receives `group_by: :region`
- Check logs show successful parsing

**Scenario 2**: Complex multi-level grouping
- Create report with 3 group levels
- Verify all 3 groups appear in config
- Check aggregations derived from variables

**Scenario 3**: Unparseable expression
- Use intentionally complex expression
- Verify warning logged
- Check fallback to group name used

### Performance Testing

- Measure pipeline setup time with/without DSL parsing
- Ensure parsing adds < 1ms to setup time
- Profile expression parsing for optimization opportunities

## Notes and Considerations

### Design Decisions

**Decision 1**: Return terminal field name, not full path

For grouped aggregations, we need the actual field being accessed (e.g., `:region`) rather than the relationship path (e.g., `[:customer, :region]`). This matches how ProducerConsumer expects `group_by` field names.

Rationale:
```elixir
# Expression: {:field, :customer, :region}
# We need: group_by: :region
# Not: group_by: [:customer, :region]
```

However, `extract_field_path/1` is provided for cases where the full path is needed.

**Decision 2**: Separate ExpressionParser module vs inline in DataLoader

A dedicated module provides:
- Better testability (pure functions, no GenStage coupling)
- Reusability (other modules can parse expressions)
- Clear separation of concerns (parsing vs pipeline management)
- Easier to extend with new expression patterns

**Decision 3**: Error tuples over exceptions

Following Elixir conventions and existing AshReports patterns:
- Predictable error handling
- Allows fallback strategies
- No need for try/rescue in calling code
- Matches patterns in CalculationEngine

**Decision 4**: Default aggregations when no variables

When a group exists but no variables are defined, we default to `[:sum, :count]` because:
- Provides useful statistics out of the box
- Matches common report requirements
- Low overhead (count is cheap, sum applies to numeric fields)
- Can be overridden via explicit configuration if needed

### Known Limitations

**Limitation 1**: Complex calculated expressions

Expressions like `expr(price * quantity)` cannot be directly mapped to a field name. These would need explicit handling or require users to define calculated attributes on resources.

**Mitigation**: Document that complex expressions need resource calculations or custom handling.

**Limitation 2**: Dynamic field references

If expressions reference fields determined at runtime, we cannot extract them at configuration time.

**Mitigation**: Fallback to group name ensures system continues working.

**Limitation 3**: Circular or self-referential expressions

Currently not detected or prevented.

**Future Enhancement**: Add validation to detect and prevent circular references.

### Future Enhancements

**Enhancement 1**: Support for aggregate expressions in groups

Currently we extract field names. Future could support grouping by aggregate results:
```elixir
expression: expr(sum(line_items.amount))  # Group by calculated total
```

**Enhancement 2**: Expression simplification

For complex expressions, attempt to simplify to extractable form:
```elixir
expr(customer.region || "Unknown")  # Extract :region, ignore default
```

**Enhancement 3**: Validation and warnings

- Warn if grouping field not in resource attributes
- Warn if relationship not defined
- Suggest corrections for common mistakes

**Enhancement 4**: Multi-field grouping

Support grouping by multiple fields in single group level:
```elixir
expression: [expr(region), expr(category)]  # Group by combination
```

### References

**Planning Documents**:
- `/home/ducky/code/ash_reports/planning/grouped_aggregation_dsl_integration.md` (lines 436-456)
- `/home/ducky/code/ash_reports/planning/typst_refactor_plan.md` (Stage 2.4.1)

**Related Modules**:
- `/home/ducky/code/ash_reports/lib/ash_reports/group_processor.ex` (lines 332-414)
- `/home/ducky/code/ash_reports/lib/ash_reports/calculation_engine.ex` (evaluation patterns)
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex` (integration point)

**DSL Definitions**:
- `/home/ducky/code/ash_reports/lib/ash_reports/group.ex` (Group struct)
- `/home/ducky/code/ash_reports/lib/ash_reports/variable.ex` (Variable struct)

**Test Examples**:
- `/home/ducky/code/ash_reports/test/support/test_helpers.ex` (lines 129-221)

## Risk Assessment

### Low Risk

- **Pattern matching Ash.Expr**: Existing code in GroupProcessor provides proven patterns
- **Error handling**: Clear error tuple pattern established in codebase
- **Unit testing**: Pure functions easy to test comprehensively

### Medium Risk

- **Ash.Expr structure changes**: If Ash framework changes expression internals, patterns may break
  - *Mitigation*: Comprehensive tests will catch this, fallback mechanism provides graceful degradation

- **Variable-to-aggregation mapping**: Edge cases in variable types
  - *Mitigation*: Default aggregations ensure functionality, extensive integration tests

### High Risk

None identified. This is a well-scoped feature with clear boundaries and fallback mechanisms.

## Implementation Timeline

**Estimated Effort**: 1-2 days

**Phase 1** (4-6 hours): ExpressionParser module
- Module creation and documentation
- Pattern matching implementation
- Unit tests

**Phase 2** (2-3 hours): DataLoader integration
- Add DSL parsing functions
- Integrate with streaming pipeline
- Logging and error handling

**Phase 3** (2-3 hours): Integration tests
- DSL → config test cases
- Multi-level grouping tests
- Edge case coverage

**Phase 4** (1-2 hours): Documentation and review
- Update moduledocs
- Add usage examples
- Code review and refinement

## Approval Checklist

Before implementation:
- [ ] Pascal has reviewed and approved the design
- [ ] Approach for handling Ash.Expr parsing confirmed
- [ ] Fallback strategy for unparseable expressions approved
- [ ] Variable-to-aggregation mapping logic validated
- [ ] Test coverage expectations clear

Ready to implement:
- [ ] All steps in implementation plan clear
- [ ] File locations confirmed
- [ ] Success criteria understood
- [ ] Edge cases identified
- [ ] No blocking questions remain

---

**Next Steps**: Present this plan to Pascal for review and approval. Upon approval, begin with Step 1: Create ExpressionParser module.
