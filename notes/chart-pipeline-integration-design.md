# Chart Pipeline Integration Design

**Date**: 2025-01-06
**Status**: Proposal
**Authors**: Architecture Review

## Executive Summary

This document proposes integrating charts into the AshReports pipeline architecture to provide declarative data loading, automatic relationship optimization, and consistent behavior with reports. Currently, charts use imperative code (`fn -> ... end`) which bypasses all pipeline optimizations and forces users to handle N+1 problems manually.

## Problem Statement

### Current Architecture Issues

**Charts today:**
- Use imperative `data_source(fn -> ... end)` callbacks
- Bypass DataLoader, QueryBuilder, and pipeline infrastructure
- Require manual relationship loading (causing N+1 problems)
- No streaming support for large datasets
- No automatic telemetry/monitoring
- Inconsistent with report architecture
- Users must write optimization code themselves

**Real-world impact:**
- Charts taking 8+ minutes for 325K records due to N+1 problems
- Users must learn DataSourceHelpers and optimization patterns
- Architectural inconsistency confuses users
- Code duplication between charts and reports

### Why This Matters

Charts are **first-class citizens** in AshReports (defined at domain level alongside reports), but they're treated as **second-class citizens** architecturally. This creates:

1. **Performance footguns** - Easy to write slow charts
2. **Cognitive overhead** - Two completely different patterns for data loading
3. **Maintenance burden** - Optimization code duplicated across charts
4. **Feature gaps** - Charts missing streaming, scope DSL, parameter validation

## Proposed Architecture

### High-Level Design

**Unify charts and reports under the same three-stage pipeline:**

```
┌─────────────────────────────────────────────────────────────┐
│                      User-Facing DSL                         │
│  ┌──────────────┐              ┌──────────────┐            │
│  │   Reports    │              │   Charts     │            │
│  │              │              │              │            │
│  │ driving_res  │              │ driving_res  │            │
│  │ scope(...)   │              │ scope(...)   │            │
│  │ bands/fields │              │ transform    │            │
│  └──────────────┘              └──────────────┘            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              Stage 1: Data Loading (DataLoader)              │
│                                                              │
│  • QueryBuilder builds optimized Ash queries                │
│  • Automatic relationship detection & batch loading         │
│  • Streaming support for large datasets                     │
│  • VariableState for calculations                           │
│  • GroupProcessor for aggregations                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         Stage 2: Context Building (RenderContext)            │
│                                                              │
│  • Merge data with definition                               │
│  • Prepare variables and metadata                           │
│  • Chart-specific: Apply transformations                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           Stage 3: Rendering (RenderPipeline)                │
│                                                              │
│  • Reports → HTML/PDF/JSON renderers                        │
│  • Charts → SVG generation via AshReports.Charts            │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Declarative over imperative** - DSL describes *what*, not *how*
2. **Automatic optimization** - Framework handles relationship loading
3. **Consistent patterns** - Charts and reports share infrastructure
4. **Backwards compatible** - Support both imperative and declarative (with deprecation)
5. **Gradual migration** - Existing charts continue to work

## Proposed DSL Changes

### Phase 1: Declarative Data Source (Simple)

Add declarative options that work with the pipeline:

```elixir
# BEFORE (Imperative - current)
pie_chart :customer_status_distribution do
  data_source(fn ->
    customers =
      Customer
      |> Ash.Query.load(:customer_tier)  # Loads calculation, not relationship
      |> Ash.read!(domain: Domain)

    chart_data =
      customers
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, custs} ->
        %{category: status, value: length(custs)}
      end)

    {:ok, chart_data, %{source_records: length(customers)}}
  end)

  config do
    # ... chart config
  end
end

# AFTER (Declarative - proposed)
pie_chart :customer_status_distribution do
  driving_resource Customer

  # Optional: Filter records (same as reports)
  scope fn params ->
    Customer
    |> Ash.Query.filter(status != :deleted)
  end

  # Chart-specific transformation DSL
  transform do
    # Group by field and count
    group_by :status
    aggregate :count

    # Map to chart format
    as_category :status
    as_value :count
  end

  config do
    # ... chart config
  end
end
```

**Benefits:**
- Automatic relationship optimization
- Declarative intent
- Framework handles N+1 problems
- Streaming support
- Consistent with reports

### Phase 2: Complex Transformations

Support more complex chart transformations:

```elixir
# Bar chart with relationship traversal
bar_chart :product_sales_by_category do
  driving_resource InvoiceLineItem

  # Relationships declared, automatically optimized
  load_relationships [:product, product: :category]

  transform do
    # Group by nested field
    group_by expr(product.category.name)

    # Multiple aggregations
    aggregate :count, as: :quantity
    aggregate :sum, field: :line_total, as: :revenue

    # Use revenue for chart value
    as_category :name
    as_value :revenue

    # Optional: Sort and limit
    sort_by :revenue, :desc
    limit 10
  end

  config do
    title "Top 10 Categories by Revenue"
    width 700
    height 450
  end
end
```

### Phase 3: Multi-Series Charts

Support complex visualizations:

```elixir
# Line chart with multiple series
line_chart :monthly_revenue_by_region do
  driving_resource Invoice

  transform do
    # Group by two dimensions
    group_by [:month, :region]

    # Create series from one dimension
    series_by :region

    # Aggregate for values
    aggregate :sum, field: :total, as: :revenue

    as_x :month
    as_y :revenue
  end

  config do
    title "Revenue Trends by Region"
    width 800
    height 400
  end
end
```

### Phase 4: Advanced Features

Add report-like features to charts:

```elixir
pie_chart :customer_distribution do
  driving_resource Customer

  # Parameters (like reports)
  parameter :region, :atom
  parameter :min_tier, :string, default: "Bronze"

  # Scope with parameters
  scope fn params ->
    Customer
    |> then(fn query ->
      if params[:region] do
        filter(query, region == ^params[:region])
      else
        query
      end
    end)
  end

  # Variables (like reports)
  variable :total_customers do
    type :count
    expression expr(1)
  end

  transform do
    group_by :customer_tier
    aggregate :count

    as_category :customer_tier
    as_value :count
  end

  config do
    title "Customer Distribution - [total_customers] Total"
    data_labels true
  end
end
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Enable basic declarative charts through pipeline

**Tasks:**
1. Create `AshReports.Charts.DataLoader` module
   - Integrate with existing DataLoader
   - Handle chart-specific transformations
   - Use QueryBuilder for optimization

2. Create `AshReports.Charts.Transform` DSL
   - `group_by/1`, `aggregate/2`
   - `as_category/1`, `as_value/1`
   - Basic transformation engine

3. Update chart runner to detect declarative vs imperative
   - If `driving_resource` present → use pipeline
   - Else → use legacy `data_source` function

4. Backwards compatibility
   - Keep `data_source(fn -> ... end)` working
   - Add deprecation warning

**Deliverables:**
- Working declarative pie/bar charts
- Pipeline integration for simple aggregations
- Deprecation guide for imperative style

### Phase 2: Advanced Transformations (Weeks 3-4)

**Goal**: Support complex aggregations and relationships

**Tasks:**
1. Relationship loading optimization
   - Integrate with QueryBuilder's relationship extraction
   - Use DataSourceHelpers patterns internally
   - Automatic batch loading

2. Complex aggregations
   - Multiple aggregate types (count, sum, avg, min, max)
   - Nested field access (product.category.name)
   - Custom expressions

3. Chart-specific features
   - Sorting and limiting
   - Filtering post-aggregation
   - Data formatting helpers

**Deliverables:**
- Line, area, scatter charts fully supported
- Relationship traversal working
- Performance benchmarks vs imperative

### Phase 3: Parameters & Variables (Weeks 5-6)

**Goal**: Full feature parity with reports

**Tasks:**
1. Parameter support
   - Add `parameter` DSL to charts
   - Integrate with scope function
   - Validation and defaults

2. Variable support
   - Use VariableState for chart variables
   - Enable variable interpolation in titles/labels
   - Metadata in chart output

3. Streaming support
   - Enable streaming for large datasets
   - Chunked aggregations
   - Memory-efficient processing

**Deliverables:**
- Charts accept parameters
- Variables in chart metadata
- Streaming benchmarks

### Phase 4: Migration & Documentation (Weeks 7-8)

**Goal**: Complete migration path and documentation

**Tasks:**
1. Migration tooling
   - Codemod to convert imperative → declarative
   - Automated refactoring suggestions
   - Warning system for deprecated patterns

2. Documentation
   - Update all chart guides
   - Performance optimization guide updates
   - Migration guide for existing charts
   - Architecture documentation

3. Demo updates
   - Migrate all 8 charts to declarative style
   - Performance comparison benchmarks
   - Best practices examples

**Deliverables:**
- Complete documentation
- Migration guide
- Fully migrated demo
- Blog post on architecture

## Migration Strategy

### Deprecation Timeline

**Phase 1 (Release X.X)**: Soft deprecation
- Imperative `data_source(fn -> ...)` still works
- Warning logged on first use: "Imperative data_source is deprecated, consider using declarative style"
- Documentation shows declarative as primary

**Phase 2 (Release X+1.X)**: Hard deprecation
- Loud warnings on every chart load
- Documentation explicitly marks as deprecated
- Codemod tool available

**Phase 3 (Release X+2.0)**: Removal
- Major version bump
- Imperative style removed
- Only declarative supported

### Automated Migration Tool

Create `mix ash_reports.migrate_charts` task:

```elixir
# Detects this:
pie_chart :my_chart do
  data_source(fn ->
    records = Ash.read!(Resource)
    # Simple grouping and counting
    Enum.group_by(records, & &1.field)
    |> Enum.map(fn {k, v} -> %{category: k, value: length(v)} end)
  end)
end

# Suggests this:
pie_chart :my_chart do
  driving_resource Resource

  transform do
    group_by :field
    aggregate :count
    as_category :field
    as_value :count
  end
end
```

### Backwards Compatibility

Support both patterns during transition:

```elixir
defmodule AshReports.Charts.Runner do
  def execute_chart(chart) do
    cond do
      # New declarative style
      Map.has_key?(chart, :driving_resource) ->
        execute_declarative_chart(chart)

      # Legacy imperative style
      is_function(chart.data_source, 0) ->
        Logger.warning("Imperative data_source is deprecated")
        execute_imperative_chart(chart)

      true ->
        {:error, "Invalid chart definition"}
    end
  end
end
```

## Examples: Before & After

### Example 1: Simple Pie Chart

**BEFORE** (Current - 30 lines):
```elixir
pie_chart :customer_status_distribution do
  data_source(fn ->
    source_records =
      AshReportsDemo.Customer
      |> Ash.Query.new()
      |> Ash.Query.load(:customer_tier)
      |> Ash.read!(domain: AshReportsDemo.Domain)

    chart_data =
      source_records
      |> Enum.group_by(fn customer ->
        case customer.status do
          :active -> "Active"
          :inactive -> "Inactive"
          :suspended -> "Suspended"
          _ -> "Unknown"
        end
      end)
      |> Enum.map(fn {status, customers} ->
        %{category: status, value: length(customers)}
      end)
      |> Enum.sort_by(& &1.value, :desc)

    {:ok, chart_data, %{source_records: length(source_records)}}
  end)

  config do
    width 600
    height 400
    title "Customer Status Distribution"
    data_labels true
    colours ["10B981", "F59E0B", "EF4444"]
  end
end
```

**AFTER** (Proposed - 17 lines):
```elixir
pie_chart :customer_status_distribution do
  driving_resource Customer

  transform do
    group_by :status
    aggregate :count
    as_category :status
    as_value :count
    sort_by :count, :desc
  end

  config do
    width 600
    height 400
    title "Customer Status Distribution"
    data_labels true
    colours ["10B981", "F59E0B", "EF4444"]
  end
end
```

**Benefits**: 43% less code, automatic optimization, declarative intent

### Example 2: Bar Chart with Relationships

**BEFORE** (Current - with N+1 problem - 55 lines):
```elixir
bar_chart :product_sales_by_category do
  data_source(fn ->
    # Load line items without relationships (optimized)
    source_records =
      InvoiceLineItem
      |> Ash.Query.new()
      |> Ash.read!(domain: Domain)

    # Extract unique product IDs
    product_ids =
      source_records
      |> Enum.map(& &1.product_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Load products with categories in one query
    products =
      Product
      |> Ash.Query.new()
      |> Ash.Query.load(:category)
      |> Ash.read!(domain: Domain)
      |> Enum.filter(&(&1.id in product_ids))
      |> Map.new(fn product -> {product.id, product} end)

    # Join in memory and aggregate
    chart_data =
      source_records
      |> Enum.filter(&Map.has_key?(products, &1.product_id))
      |> Enum.group_by(fn item ->
        products[item.product_id].category.name
      end)
      |> Enum.map(fn {category, items} ->
        total_revenue =
          items
          |> Enum.reduce(Decimal.new(0), fn item, acc ->
            Decimal.add(acc, item.line_total)
          end)
          |> Decimal.to_float()

        %{category: category, value: total_revenue}
      end)
      |> Enum.sort_by(& &1.value, :desc)

    {:ok, chart_data, %{source_records: length(source_records)}}
  end)

  config do
    width 700
    height 450
    title "Sales by Product Category"
    type :simple
    orientation :vertical
    data_labels true
    colours ["8B5CF6", "EC4899", "F59E0B", "10B981", "3B82F6"]
  end
end
```

**AFTER** (Proposed - 22 lines):
```elixir
bar_chart :product_sales_by_category do
  driving_resource InvoiceLineItem

  # Framework automatically optimizes relationship loading
  load_relationships [:product, product: :category]

  transform do
    group_by expr(product.category.name)
    aggregate :sum, field: :line_total, as: :revenue
    as_category :name
    as_value :revenue
    sort_by :revenue, :desc
  end

  config do
    width 700
    height 450
    title "Sales by Product Category"
    type :simple
    orientation :vertical
    data_labels true
    colours ["8B5CF6", "EC4899", "F59E0B", "10B981", "3B82F6"]
  end
end
```

**Benefits**: 60% less code, no manual optimization needed, declarative relationships

### Example 3: Scatter Chart with Filtering

**BEFORE** (Current - 50 lines):
```elixir
scatter_chart :price_quantity_analysis do
  data_source(fn ->
    {:ok, {line_items, products_map}} =
      AshReports.Charts.DataSourceHelpers.load_with_relationship(
        InvoiceLineItem,
        Product,
        :product_id,
        domain: Domain
      )

    # Calculate sales quantities by product
    sales_by_product =
      line_items
      |> Enum.filter(&Map.has_key?(products_map, &1.product_id))
      |> Enum.group_by(& &1.product_id)
      |> Map.new(fn {product_id, items} ->
        total_qty = Enum.reduce(items, 0, fn item, acc ->
          acc + item.quantity
        end)
        {product_id, total_qty}
      end)

    # Map products to price/quantity coordinates
    chart_data =
      products_map
      |> Map.values()
      |> Enum.filter(&Map.has_key?(sales_by_product, &1.id))
      |> Enum.map(fn product ->
        %{
          x: Decimal.to_float(product.price),
          y: Map.get(sales_by_product, product.id, 0)
        }
      end)
      |> Enum.filter(&(&1.y > 0))

    {:ok, chart_data, %{source_records: length(line_items)}}
  end)

  config do
    width 700
    height 500
    title "Price vs Quantity Correlation"
    axis_label_rotation :auto
    colours ["8B5CF6"]
  end
end
```

**AFTER** (Proposed - 22 lines):
```elixir
scatter_chart :price_quantity_analysis do
  driving_resource InvoiceLineItem

  load_relationships [:product]

  transform do
    # Group by product and sum quantities
    group_by :product_id
    aggregate :sum, field: :quantity, as: :total_quantity

    # Filter out zero quantities
    filter expr(total_quantity > 0)

    # Map to x/y coordinates
    as_x expr(product.price)
    as_y :total_quantity
  end

  config do
    width 700
    height 500
    title "Price vs Quantity Correlation"
    axis_label_rotation :auto
    colours ["8B5CF6"]
  end
end
```

**Benefits**: 56% less code, no DataSourceHelpers needed, automatic optimization

## Technical Considerations

### Performance

**Expected improvements:**
- Automatic relationship batching → eliminate N+1 problems
- Query optimization via QueryBuilder
- Streaming support for large datasets
- Built-in caching at pipeline level

**Benchmarks needed:**
- Compare declarative vs imperative on large datasets
- Measure pipeline overhead for simple charts
- Memory usage with streaming enabled

### Breaking Changes

**Minimal breaking changes:**
- Imperative `data_source` continues to work (deprecated)
- New `driving_resource` is opt-in
- Migration path spans 2+ major versions

**What breaks in major version:**
- `data_source(fn -> ... end)` removed
- Must use declarative style

### Edge Cases

**Complex transformations:**
- Some charts may need custom logic that DSL can't express
- Solution: Escape hatch via `custom_transform` callback
- Falls back to imperative style for edge cases

**Performance critical paths:**
- Some users may want full control for optimization
- Solution: Keep imperative style as "advanced" feature
- Document when to use each approach

### Testing Strategy

**Unit tests:**
- Transform DSL parser
- Pipeline integration
- Backwards compatibility

**Integration tests:**
- All 7 chart types
- Complex relationship loading
- Large dataset performance

**Migration tests:**
- Automated migration tool accuracy
- Before/after output comparison

## Success Metrics

### User Experience
- [ ] 80%+ reduction in chart code lines
- [ ] Zero manual optimization code needed
- [ ] Declarative patterns match report patterns
- [ ] Migration tool converts 90%+ of charts automatically

### Performance
- [ ] Zero N+1 problems in declarative charts
- [ ] <1s execution time for 325K records
- [ ] Streaming support for datasets >1M records
- [ ] Pipeline overhead <10ms for simple charts

### Adoption
- [ ] All demo charts migrated to declarative
- [ ] Documentation updated
- [ ] Community feedback positive
- [ ] <5% of users stay on imperative style

## Open Questions

1. **Transform DSL complexity**: How complex should the transform DSL be? Should it support arbitrary Elixir code or stay purely declarative?

2. **Backwards compatibility duration**: How long should we support imperative style? 2 versions? 3 versions?

3. **Custom transformations**: What's the escape hatch for complex charts that don't fit the DSL?

4. **Performance overhead**: Is the pipeline overhead acceptable for very simple charts?

5. **Multi-series charts**: How should the DSL handle charts with multiple data series?

## Next Steps

1. **Review & feedback**: Share with team for architectural review
2. **Prototype**: Build Phase 1 proof-of-concept
3. **Benchmark**: Performance comparison with current implementation
4. **RFC**: Create formal RFC for community feedback
5. **Implementation**: Begin Phase 1 development

## Conclusion

Integrating charts into the AshReports pipeline will:
- **Eliminate N+1 problems** automatically
- **Reduce code complexity** by 50%+
- **Unify architecture** for consistency
- **Enable advanced features** (streaming, parameters, variables)
- **Improve maintainability** with declarative patterns

The migration path is gradual and backwards-compatible, allowing users to adopt at their own pace while providing clear benefits for new development.

---

**Status**: Awaiting review and approval
**Next Review**: After Phase 1 prototype completion
