# Performance Optimization

This guide covers performance best practices for AshReports, focusing on avoiding common pitfalls that can cause severe slowdowns with large datasets.

## Table of Contents

- [Understanding N+1 Query Problems](#understanding-n1-query-problems)
- [Chart Data Source Optimization](#chart-data-source-optimization)
- [Using DataSourceHelpers](#using-datasourcehelpers)
- [Report Data Loading Best Practices](#report-data-loading-best-practices)
- [Performance Monitoring](#performance-monitoring)

## Understanding N+1 Query Problems

### What is an N+1 Query Problem?

An N+1 query problem occurs when you load a collection of N records and then make an additional query for each record to load a relationship. This results in:

- 1 query to load N records
- N queries to load relationships (one per record)
- **Total: N+1 queries**

### Real-World Impact

With large datasets, this can cause catastrophic performance degradation:

| Records | Queries | Time (ETS) | Time (Database) |
|---------|---------|-----------|-----------------|
| 100 | 101 | ~10ms | ~1s |
| 1,000 | 1,001 | ~100ms | ~10s |
| 10,000 | 10,001 | ~1s | ~2min |
| 100,000 | 100,001 | ~10s | ~20min |
| **325,000** | **325,001** | **~8min** | **Hours** |

### Identifying N+1 Problems

**Common Pattern (❌ Problematic):**

```elixir
# This loads relationships for EVERY record!
data_source(fn ->
  InvoiceLineItem
  |> Ash.Query.load(product: :category)  # N+1 problem!
  |> Ash.read!(domain: MyApp.Domain)
  |> process_data()
end)
```

**Why This is Slow:**
- Loads 325,000 line items
- Makes 325,000 queries to load products (one per line item!)
- Makes 325,000 more queries to load categories
- **Total: ~650,000 queries** → 8+ minutes

## Chart Data Source Optimization

### The Optimized Pattern

Instead of eagerly loading relationships, load them separately and join in memory:

```elixir
data_source(fn ->
  # 1. Load main records WITHOUT relationships (1 query)
  source_records =
    InvoiceLineItem
    |> Ash.Query.new()
    |> Ash.read!(domain: MyApp.Domain)

  # 2. Extract unique related IDs (in-memory operation)
  product_ids =
    source_records
    |> Enum.map(& &1.product_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  # With 325K line items, typically only ~1,000 unique products!

  # 3. Load related records once (1 query)
  products =
    Product
    |> Ash.Query.new()
    |> Ash.Query.load(:category)
    |> Ash.read!(domain: MyApp.Domain)
    |> Enum.filter(&(&1.id in product_ids))
    |> Map.new(fn product -> {product.id, product} end)

  # 4. Join in memory using lookup map (fast!)
  chart_data =
    source_records
    |> Enum.filter(&Map.has_key?(products, &1.product_id))
    |> Enum.group_by(fn item ->
      products[item.product_id].category.name
    end)
    |> Enum.map(fn {category, items} ->
      %{category: category, value: length(items)}
    end)

  {:ok, chart_data, %{source_records: length(source_records)}}
end)
```

**Performance Improvement:**
- Total queries: **3** (vs 650,000)
- Execution time: **<1 second** (vs 8+ minutes)
- **~500x speedup!**

## Using DataSourceHelpers

AshReports provides the `AshReports.Charts.DataSourceHelpers` module to make this pattern easier.

### Quick Start

```elixir
alias AshReports.Charts.DataSourceHelpers

data_source(fn ->
  # Load records with optimized relationship loading
  {:ok, {line_items, products_map}} =
    DataSourceHelpers.load_with_relationship(
      InvoiceLineItem,
      Product,
      :product_id,
      domain: MyApp.Domain,
      preload: :category
    )

  # Use the lookup map to join in memory
  chart_data =
    line_items
    |> Enum.filter(&Map.has_key?(products_map, &1.product_id))
    |> Enum.group_by(fn item ->
      products_map[item.product_id].category.name
    end)
    |> Enum.map(fn {category, items} ->
      %{category: category, value: length(items)}
    end)

  {:ok, chart_data, %{source_records: length(line_items)}}
end)
```

### Available Helper Functions

#### build_lookup_map/2

Creates a fast O(1) lookup map from a collection:

```elixir
products = Ash.read!(Product, domain: MyApp.Domain)
products_map = DataSourceHelpers.build_lookup_map(products, :id)
# => %{1 => %Product{id: 1}, 2 => %Product{id: 2}, ...}

# Now lookup is O(1) instead of O(N)
product = products_map[line_item.product_id]
```

#### extract_unique_ids/2

Extracts unique IDs from a collection, filtering out nils:

```elixir
product_ids = DataSourceHelpers.extract_unique_ids(line_items, :product_id)
# => [1, 2, 5, 8, 15, ...] (only unique IDs)
```

#### load_related_batch/4

Loads related records in a single query:

```elixir
{:ok, products_map} = DataSourceHelpers.load_related_batch(
  line_items,
  :product_id,
  Product,
  domain: MyApp.Domain,
  preload: :category,
  key_field: :id
)
```

#### join_with_lookup/3

Joins collections using a lookup map:

```elixir
joined = DataSourceHelpers.join_with_lookup(
  line_items,
  products_map,
  :product_id
)
# => [{line_item1, product1}, {line_item2, product2}, ...]
```

#### warn_if_loaded/2

Runtime check to detect N+1 issues:

```elixir
InvoiceLineItem
|> Ash.read!(domain: MyApp.Domain)
|> DataSourceHelpers.warn_if_loaded([:product, :invoice])
# Logs warning if relationships are loaded
```

### Complete Example with Helpers

```elixir
bar_chart :product_sales_by_category do
  data_source(fn ->
    alias AshReports.Charts.DataSourceHelpers

    # Optimized loading with helpers
    {:ok, {line_items, products_map}} =
      DataSourceHelpers.load_with_relationship(
        InvoiceLineItem,
        Product,
        :product_id,
        domain: MyApp.Domain,
        preload: :category
      )

    # Group by category using the lookup map
    chart_data =
      line_items
      |> Enum.filter(&Map.has_key?(products_map, &1.product_id))
      |> Enum.group_by(fn item ->
        products_map[item.product_id].category.name
      end)
      |> Enum.map(fn {category, items} ->
        %{category: category, value: length(items)}
      end)
      |> Enum.sort_by(& &1.value, :desc)

    {:ok, chart_data, %{source_records: length(line_items)}}
  end)

  config do
    width 700
    height 450
    title "Sales by Product Category"
    type :simple
    orientation :vertical
  end
end
```

## Report Data Loading Best Practices

### Use Streaming for Large Reports

For reports with large datasets, use the streaming option:

```elixir
{:ok, result} = AshReports.Runner.run_report(
  MyApp.Domain,
  :financial_summary,
  %{},
  format: :json,
  streaming: true,
  chunk_size: 500
)
```

### Limit Data Early

Apply filters at the query level, not after loading:

```elixir
# ✅ GOOD - Filter in the query
InvoiceLineItem
|> Ash.Query.filter(inserted_at >= ^start_date)
|> Ash.read!(domain: MyApp.Domain)

# ❌ BAD - Load everything then filter
InvoiceLineItem
|> Ash.read!(domain: MyApp.Domain)
|> Enum.filter(&(&1.inserted_at >= start_date))
```

### Use Aggregates When Possible

Let the data layer do aggregations instead of loading all records:

```elixir
# ✅ GOOD - Use Ash aggregates
Customer
|> Ash.Query.load(:invoice_count)

# ❌ BAD - Count in memory
customers = Ash.read!(Customer)
Enum.map(customers, fn customer ->
  invoice_count = customer.invoices |> length()
end)
```

## Performance Monitoring

### Add Telemetry Events

AshReports emits telemetry events for monitoring:

```elixir
:telemetry.attach_many(
  "report-performance",
  [
    [:ash_reports, :runner, :data_loading, :stop],
    [:ash_reports, :runner, :rendering, :stop],
    [:ash_reports, :charts, :generate, :stop]
  ],
  fn event, measurements, metadata, _config ->
    stage = List.last(event)
    Logger.info("#{stage} took #{measurements.duration}ms")
  end,
  nil
)
```

### Log Execution Time

Add timing to your data_source functions:

```elixir
data_source(fn ->
  require Logger
  start = System.monotonic_time(:millisecond)

  # ... load data ...

  duration = System.monotonic_time(:millisecond) - start
  Logger.info("Chart data loaded in #{duration}ms")

  {:ok, chart_data, %{source_records: count, duration_ms: duration}}
end)
```

### Monitor Record Counts

Return metadata about how many records were processed:

```elixir
{:ok, chart_data, %{
  source_records: length(source_records),
  filtered_records: length(filtered_records),
  unique_products: length(product_ids)
}}
```

## Checklist for Large Datasets

When working with datasets >10,000 records:

- [ ] Avoid using `Ash.Query.load/2` in data_source functions
- [ ] Load relationships separately and join in memory
- [ ] Use `DataSourceHelpers` for common patterns
- [ ] Apply filters at the query level
- [ ] Use aggregates instead of loading all records
- [ ] Add telemetry monitoring
- [ ] Log execution times during development
- [ ] Test with production-size datasets
- [ ] Return record count metadata
- [ ] Consider streaming for very large reports

## Common Pitfalls to Avoid

### 1. Loading Relationships Eagerly

```elixir
# ❌ NEVER do this with large datasets
Ash.Query.load(product: [:category, :supplier, :reviews])
```

### 2. Multiple Passes Over Data

```elixir
# ❌ BAD - Three passes over the same data
total = Enum.sum(items)
count = Enum.count(items)
average = total / count

# ✅ GOOD - One pass with Enum.reduce
{total, count} = Enum.reduce(items, {0, 0}, fn item, {sum, cnt} ->
  {sum + item.value, cnt + 1}
end)
```

### 3. Nested Enums

```elixir
# ❌ BAD - O(N²) complexity
Enum.map(items, fn item ->
  related = Enum.find(others, &(&1.id == item.other_id))
end)

# ✅ GOOD - O(N) with lookup map
others_map = DataSourceHelpers.build_lookup_map(others, :id)
Enum.map(items, fn item ->
  related = others_map[item.other_id]
end)
```

## Resources

- [AshReports.Charts.DataSourceHelpers](https://hexdocs.pm/ash_reports/AshReports.Charts.DataSourceHelpers.html) - API documentation
- [Graphs and Visualizations Guide](graphs-and-visualizations.md) - Chart DSL documentation
- [Ash Query Documentation](https://hexdocs.pm/ash/Ash.Query.html) - Query building guide
