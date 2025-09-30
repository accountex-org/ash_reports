# Research: Report DSL Group-Level Variables and Aggregation Integration

**Date**: 2025-09-30
**Context**: How to integrate ProducerConsumer grouped aggregations with Report DSL definitions

## Current State Analysis

### 1. Report DSL Structure

The AshReports DSL already has comprehensive support for grouping and variables:

#### Groups Definition (lib/ash_reports/group.ex)
```elixir
%AshReports.Group{
  name: :by_region,
  level: 1,                      # 1 = top-level, 2 = nested, etc.
  expression: expr(customer.region),
  sort: :asc
}
```

#### Variables Definition (lib/ash_reports/variable.ex)
```elixir
%AshReports.Variable{
  name: :region_total,
  type: :sum,                    # :sum, :count, :average, :min, :max, :custom
  expression: expr(amount),
  reset_on: :group,              # :detail, :group, :page, :report
  reset_group: 1                 # Which group level triggers reset
}
```

#### Band Structure (test/support/test_helpers.ex, lines 177-218)
```elixir
%AshReports.Band{
  type: :group_header,
  group_level: 1,
  elements: [
    %Element.Field{source: {:field, :customer, :region}}
  ]
}

%AshReports.Band{
  type: :group_footer,
  group_level: 1,
  elements: [
    %Element.Aggregate{
      source: {:sum, :total_amount},
      format: :currency
    }
  ]
}
```

### 2. ProducerConsumer Grouped Aggregations (Just Implemented)

```elixir
ProducerConsumer.start_link(
  stream_id: "sales-report",
  subscribe_to: [{producer, []}],
  grouped_aggregations: [
    %{
      group_by: :region,              # Single field
      aggregations: [:sum, :count, :avg]
    },
    %{
      group_by: [:region, :customer_name],  # Multi-level
      aggregations: [:sum, :count]
    }
  ]
)

# Result:
grouped_aggregation_state = %{
  [:region] => %{
    "North America" => %{sum: %{amount: 450000}, count: 235},
    "Europe" => %{sum: %{amount: 380000}, count: 180}
  },
  [:region, :customer_name] => %{
    {"North America", "Acme"} => %{sum: %{amount: 250000}, count: 120}
  }
}
```

### 3. DataProcessor Grouping (Existing)

```elixir
# lib/ash_reports/typst/data_processor.ex, lines 445-475
DataProcessor.process_groups(records, groups)

# Returns:
[
  %{
    group_key: "North America",
    records: [...],
    nested_groups: [...],
    record_count: 235
  }
]
```

**Limitation**: DataProcessor groups are created per-batch, not accumulated across streaming batches.

### 4. DSLGenerator Template Generation (Deferred)

```elixir
# lib/ash_reports/typst/dsl_generator.ex, lines 303-307
defp generate_nested_grouping(_groups, report, context) do
  # NOTE: Nested grouping implementation deferred to future iteration
  # Current implementation provides flat detail processing for all group scenarios
  generate_simple_detail_processing(report, context)
end
```

**Gap**: No integration between report DSL groups/variables and Typst template generation with statistics.

## The Integration Gap

### What's Missing

The connection between:

1. **Report DSL** → Groups and Variables definitions
2. **ProducerConsumer** → Streaming grouped aggregations
3. **DSLGenerator** → Typst templates with group headers/footers
4. **DataProcessor** → Data transformation for rendering

### Example Use Case

```elixir
# User defines report with DSL:
report :sales_by_region do
  driving_resource Sales

  groups do
    group :by_region do
      level 1
      expression expr(customer.region)
      sort :asc
    end

    group :by_customer do
      level 2
      expression expr(customer.name)
      sort :asc
    end
  end

  variables do
    variable :region_total do
      type :sum
      expression expr(amount)
      reset_on :group
      reset_group 1  # Reset on region change
    end

    variable :customer_total do
      type :sum
      expression expr(amount)
      reset_on :group
      reset_group 2  # Reset on customer change
    end

    variable :grand_total do
      type :sum
      expression expr(amount)
      reset_on :report
    end
  end

  bands do
    band :group_header_region do
      type :group_header
      group_level 1
      elements do
        field :region_name do
          source expr(customer.region)
        end
      end
    end

    band :group_footer_region do
      type :group_footer
      group_level 1
      elements do
        label "Region Total:"
        aggregate :region_sum do
          source variable(:region_total)  # ← Should show accumulated total
          format :currency
        end
      end
    end

    band :detail do
      type :detail
      elements do
        field :customer, source: expr(customer.name)
        field :amount, source: expr(amount), format: :currency
      end
    end
  end
end
```

### Expected Behavior

When rendering this report with streaming:

1. **Producer** streams 100K sales records
2. **ProducerConsumer** accumulates statistics per group across batches:
   - `%{[:region] => %{"North" => %{sum: %{amount: 450000}, count: 235}}}`
3. **DSLGenerator** generates Typst template that:
   - Renders group headers with region name
   - Renders detail records
   - Renders group footers with `$450,000` (from accumulated stats)
4. **Typst** compiles to PDF with properly formatted group subtotals

## Proposed Solutions

### Option 1: DSL-Driven ProducerConsumer Configuration ⭐ Recommended

**Where**: Enhance `DataLoader.load_report_data/2` to auto-configure ProducerConsumer

**How**:
```elixir
defmodule AshReports.Typst.DataLoader do
  def load_report_data(report, params, opts \\ []) do
    # Extract groups and variables from report DSL
    grouped_aggregations = build_grouped_aggregations_from_dsl(report)

    # Start streaming pipeline with auto-generated config
    {:ok, producer} = Producer.start_link(...)
    {:ok, transformer} = ProducerConsumer.start_link(
      stream_id: stream_id,
      subscribe_to: [{producer, []}],
      grouped_aggregations: grouped_aggregations  # Auto-generated!
    )

    # Return data + aggregations
    {:ok, %{
      records: stream,
      grouped_aggregations: transformer_state.grouped_aggregation_state
    }}
  end

  defp build_grouped_aggregations_from_dsl(report) do
    groups = report.groups || []
    variables = report.variables || []

    # Map report groups to ProducerConsumer grouped_aggregations config
    Enum.map(groups, fn group ->
      # Extract field from group expression
      group_field = extract_field_from_expression(group.expression)

      # Find variables that reset at this group level
      group_variables = Enum.filter(variables, fn var ->
        var.reset_on == :group and var.reset_group == group.level
      end)

      # Map variable types to aggregation types
      aggregations = Enum.map(group_variables, fn var ->
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

      %{
        group_by: group_field,
        aggregations: aggregations
      }
    end)
  end

  defp extract_field_from_expression({:field, field_name}), do: field_name
  defp extract_field_from_expression({:field, _rel, field_name}), do: field_name
  defp extract_field_from_expression(expr) when is_atom(expr), do: expr
  # Handle Ash.Expr.t() parsing...
end
```

**Benefits**:
- ✅ Zero user configuration - automatic from DSL
- ✅ Type-safe mapping from variables to aggregations
- ✅ Supports multi-level grouping naturally
- ✅ Variables with `reset_on: :group` automatically create grouped aggregations

### Option 2: Enhance DSLGenerator to Access Aggregation State

**Where**: Update `DSLGenerator.generate_nested_grouping/3`

**How**:
```elixir
defp generate_nested_grouping(groups, report, context) do
  # Assume context includes: %{aggregation_state: grouped_aggregation_state}

  """
  // Group Processing with Aggregations
  #{generate_group_structure(groups, report, context)}
  """
end

defp generate_group_structure([primary_group | nested_groups], report, context) do
  group_field = extract_field(primary_group.expression)
  group_level = primary_group.level

  # Generate Typst code that accesses aggregation state
  """
  // Group by #{group_field}
  #let groups = data.grouped_aggregations[[:#{group_field}]]

  #for (group_value, stats) in groups {
    // Group Header (level #{group_level})
    #{generate_group_header_band(report, group_level, context)}

    // Group statistics available as: stats.sum, stats.count, stats.avg

    // Detail records for this group
    #for record in data.records.filter(r => r.#{group_field} == group_value) {
      #{generate_detail_band(report, context)}
    }

    // Group Footer (level #{group_level})
    #{generate_group_footer_band(report, group_level, context, "stats")}

    #{if nested_groups != [], do: generate_group_structure(nested_groups, report, context), else: ""}
  }
  """
end

defp generate_group_footer_band(report, group_level, context, stats_var) do
  footer_band = find_band(report.bands, :group_footer, group_level)

  if footer_band do
    elements = Enum.map(footer_band.elements, fn element ->
      case element do
        %Element.Aggregate{source: {:sum, field}} ->
          "[Total: ##{stats_var}.sum.#{field}]"

        %Element.Aggregate{source: {:variable, var_name}} ->
          # Look up variable definition to find its source field
          variable = find_variable(report.variables, var_name)
          field = extract_field(variable.expression)
          "[#{var_name}: ##{stats_var}.sum.#{field}]"

        _ ->
          generate_element(element, context)
      end
    end)

    Enum.join(elements, "\n")
  else
    ""
  end
end
```

**Benefits**:
- ✅ Clean separation: ProducerConsumer calculates, DSLGenerator renders
- ✅ Template has direct access to statistics
- ✅ Supports complex group footer layouts

### Option 3: Merge Aggregations into DataProcessor Groups

**Where**: Enhance `DataProcessor.process_groups/2`

**How**:
```elixir
def process_groups(records, groups, grouped_aggregation_state \\ %{}) do
  # ... existing grouping logic ...

  # Merge aggregation state into group structures
  grouped_data = create_grouped_structure(records, groups)
  enriched_groups = merge_aggregations(grouped_data, grouped_aggregation_state, groups)

  {:ok, enriched_groups}
end

defp merge_aggregations(grouped_data, agg_state, groups) do
  Enum.map(grouped_data, fn group ->
    # Extract group key
    group_fields = extract_group_fields(groups)
    agg_key = List.wrap(group_fields)

    # Find matching aggregation stats
    stats = Map.get(agg_state, agg_key, %{})
              |> Map.get(group.group_key, %{})

    # Merge into group structure
    Map.put(group, :aggregations, stats)
  end)
end

# Result:
[
  %{
    group_key: "North America",
    records: [...],
    nested_groups: [...],
    record_count: 235,
    aggregations: %{sum: %{amount: 450000}, count: 235, avg: %{...}}  # ← Added!
  }
]
```

**Benefits**:
- ✅ Groups and statistics together in one structure
- ✅ Easy to access in templates: `group.aggregations.sum.amount`
- ⚠️ Requires passing aggregation state through DataProcessor

## Recommended Implementation Path

### Phase 1: Auto-Configuration (Option 1)
1. Implement `build_grouped_aggregations_from_dsl/1` in DataLoader
2. Parse report groups and variables to generate ProducerConsumer config
3. Test with simple single-level grouping

### Phase 2: Template Generation (Option 2)
1. Update DSLGenerator to handle `grouped_aggregation_state` in context
2. Implement `generate_nested_grouping/3` with aggregation access
3. Generate Typst code that renders group headers/footers with statistics
4. Test with multi-level grouping

### Phase 3: DataProcessor Integration (Optional - Option 3)
1. Enhance `process_groups/2` to accept aggregation state
2. Merge statistics into group structures
3. Simplify template generation (no need to query separate state)

## Critical Design Questions

### Q1: Expression Parsing
**Problem**: How to extract field name from `Ash.Expr.t()` expressions?

**Options**:
- A) Pattern match common expression types: `{:field, name}`, `expr(field)`, etc.
- B) Use Ash expression introspection APIs
- C) Require explicit field name in group definition: `group_by_field: :region`

**Recommendation**: Start with A (pattern matching), add C as fallback/override

### Q2: Variable-to-Aggregation Mapping
**Problem**: Variables have complex expressions, aggregations operate on all numeric fields

**Options**:
- A) Parse variable expression to extract target field: `expr(amount)` → `:amount`
- B) Calculate all aggregations, let templates filter: `stats.sum.amount`
- C) Add explicit field list to group config: `fields: [:amount, :quantity]`

**Recommendation**: B (calculate all) - most flexible, matches current implementation

### Q3: Multi-Level Group Hierarchy
**Problem**: Report has 3 group levels, how to structure aggregations?

**Example**:
```elixir
groups: [
  %{level: 1, expression: :territory},
  %{level: 2, expression: :customer_name},
  %{level: 3, expression: :order_type}
]

# Should generate:
grouped_aggregations: [
  %{group_by: :territory, aggregations: [...]},
  %{group_by: [:territory, :customer_name], aggregations: [...]},
  %{group_by: [:territory, :customer_name, :order_type], aggregations: [...]}
]
```

**Recommendation**: Generate aggregations for each level independently AND cumulatively for proper subtotals

### Q4: Data Flow Architecture
**Problem**: Where does aggregation state live during rendering?

**Current Flow**:
```
DSL → DataLoader → Producer → ProducerConsumer → Consumer → Renderer
                                     ↓
                           (aggregation state in memory)
```

**Options**:
- A) Pass aggregation state as separate parameter to DSLGenerator
- B) Merge into data structure before rendering
- C) Store in Registry, query during rendering

**Recommendation**: A (pass as parameter) - explicit, testable, no global state

## Next Steps

1. **Ask Pascal**:
   - Which option(s) should we implement?
   - Any concerns about the DSL → aggregation mapping approach?
   - Should we support explicit field filtering for aggregations?

2. **Prototype Phase 1**:
   - Implement `build_grouped_aggregations_from_dsl/1`
   - Test with existing test_helpers.ex complex report
   - Validate expression parsing works

3. **Prototype Phase 2**:
   - Update DSLGenerator with aggregation-aware template generation
   - Generate Typst templates with group header/footer statistics
   - Test end-to-end: DSL → Streaming → Rendering

## References

- **Report DSL**: `lib/ash_reports/dsl.ex`
- **Variable Logic**: `lib/ash_reports/variable.ex` (lines 74-86: reset logic, 91-124: calculation)
- **Group Definition**: `lib/ash_reports/group.ex`
- **ProducerConsumer**: `lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex` (lines 413-458: grouped aggregations)
- **DataProcessor**: `lib/ash_reports/typst/data_processor.ex` (lines 445-475: grouping)
- **DSLGenerator**: `lib/ash_reports/typst/dsl_generator.ex` (lines 291-327: grouping - deferred)
- **Test Example**: `test/support/test_helpers.ex` (lines 129-221: complex report with groups/variables)