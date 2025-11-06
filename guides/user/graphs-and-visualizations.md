# Graphs and Visualizations

This guide covers adding charts and visualizations to AshReports using the declarative chart DSL.

## Table of Contents

- [Chart Architecture](#chart-architecture)
- [Defining Charts](#defining-charts)
- [Using Charts in Bands](#using-charts-in-bands)
- [Chart Types](#chart-types)
  - [Bar Charts](#bar-charts)
  - [Line Charts](#line-charts)
  - [Pie Charts](#pie-charts)
  - [Area Charts](#area-charts)
  - [Scatter Plots](#scatter-plots)
  - [Sparklines](#sparklines)
  - [Gantt Charts](#gantt-charts)
- [Chart Configuration](#chart-configuration)
- [Data Sources](#data-sources)
- [Complete Examples](#complete-examples)

## Chart Architecture

AshReports uses a **two-level architecture** for charts:

1. **Chart Definitions** - Defined at the `reports` level, specifying data and configuration
2. **Chart Elements** - Referenced in report bands, specifying where to place the chart

This separation allows charts to be:
- **Reusable** across multiple bands and reports
- **Testable** independently of layout
- **Maintainable** with centralized configuration

### Basic Structure

```elixir
defmodule MyApp.Reports do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    # Level 1: Chart Definitions (reusable)
    bar_chart :sales_by_region do
      data_source expr(aggregate_sales_by_region())
      config do
        width 800
        height 400
        title "Sales by Region"
      end
    end

    # Report using the chart
    report :monthly_report do
      bands do
        band :summary do
          type :detail

          elements do
            # Level 2: Chart Element (references definition)
            bar_chart :sales_by_region
          end
        end
      end
    end
  end
end
```

## Defining Charts

Charts are defined at the `reports` level using type-specific entities. Each chart type has its own DSL function and configuration options.

### Chart Definition Syntax

```elixir
<chart_type> :chart_name do
  data_source expr(...)  # Expression that evaluates to chart data

  config do
    # Type-specific configuration options
    width 600
    height 400
    title "Chart Title"
    # ... more options
  end
end
```

### Available Chart Types

| Chart Type | DSL Function | Use Case |
|------------|--------------|----------|
| Bar Chart | `bar_chart` | Comparing values across categories |
| Line Chart | `line_chart` | Showing trends over time |
| Pie Chart | `pie_chart` | Displaying proportions and percentages |
| Area Chart | `area_chart` | Visualizing cumulative values over time |
| Scatter Plot | `scatter_chart` | Showing correlation between variables |
| Sparkline | `sparkline` | Inline micro-charts for trends |
| Gantt Chart | `gantt_chart` | Project timelines and task scheduling |

## Using Charts in Bands

Once defined, charts are referenced in report bands using the same type-specific function:

```elixir
report :sales_report do
  bands do
    band :analytics do
      type :detail

      elements do
        # Reference the chart by name
        bar_chart :sales_by_region

        # Can reference multiple charts
        line_chart :trend_analysis
        pie_chart :market_share
      end
    end
  end
end
```

The chart element uses the definition's configuration but can be placed anywhere in the band hierarchy.

## Chart Types

### Bar Charts

Best for comparing values across categories with support for simple, grouped, and stacked variations.

**Definition:**

```elixir
bar_chart :revenue_by_region do
  data_source expr(aggregate_revenue_by_region())

  config do
    width 800
    height 500
    title "Revenue by Region"
    type :simple          # :simple, :grouped, or :stacked
    orientation :vertical # :vertical or :horizontal
    data_labels true
    padding 2
    colours ["4285F4", "EA4335", "FBBC04", "34A853"]
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `type` | atom | :simple | Bar type: `:simple`, `:grouped`, `:stacked` |
| `orientation` | atom | :vertical | Bar orientation: `:vertical`, `:horizontal` |
| `data_labels` | boolean | true | Show values on bars |
| `padding` | integer | 2 | Padding between bars in pixels |
| `colours` | list | [] | Hex colors without # prefix |

**Data Format:**

```elixir
# Simple bar chart
[
  %{category: "North", value: 15000},
  %{category: "South", value: 12000},
  %{category: "East", value: 18000},
  %{category: "West", value: 14000}
]

# Grouped bar chart (multiple series)
[
  %{category: "Q1", series: "2023", value: 100},
  %{category: "Q1", series: "2024", value: 120},
  %{category: "Q2", series: "2023", value: 110},
  %{category: "Q2", series: "2024", value: 135}
]
```

**Usage in Band:**

```elixir
band :regional_summary do
  type :detail

  elements do
    bar_chart :revenue_by_region
  end
end
```

### Line Charts

Best for showing trends and changes over time with support for single and multi-series data.

**Definition:**

```elixir
line_chart :sales_trend do
  data_source expr(monthly_sales_data())

  config do
    width 900
    height 400
    title "Sales Trend (12 Months)"
    smoothed true
    stroke_width "2"
    colours ["4285F4", "34A853"]
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `smoothed` | boolean | true | Use smooth curves |
| `stroke_width` | string | "2" | Line thickness |
| `colours` | list | [] | Hex colors without # prefix |
| `axis_label_rotation` | atom | :auto | Label rotation: `:auto`, `45`, `90` |

**Data Format:**

```elixir
# Single series
[
  %{x: "Jan", y: 1200},
  %{x: "Feb", y: 1350},
  %{x: "Mar", y: 1100},
  %{x: "Apr", y: 1500}
]

# Multi-series
[
  %{x: 1, series: "Product A", y: 10},
  %{x: 1, series: "Product B", y: 15},
  %{x: 2, series: "Product A", y: 12},
  %{x: 2, series: "Product B", y: 18}
]
```

**Usage in Band:**

```elixir
band :trend_analysis do
  type :detail

  elements do
    line_chart :sales_trend
  end
end
```

### Pie Charts

Best for showing proportions and percentages of a whole.

**Definition:**

```elixir
pie_chart :market_share do
  data_source expr(product_market_share())

  config do
    width 600
    height 500
    title "Market Share by Product"
    show_percentages true
    donut_width nil  # Set to integer for donut chart (e.g., 20)
    colours ["FF6384", "36A2EB", "FFCE56", "4BC0C0"]
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `show_percentages` | boolean | true | Display percentage labels |
| `donut_width` | integer | nil | Width for donut chart (nil for pie) |
| `colours` | list | [] | Hex colors without # prefix |

**Data Format:**

```elixir
[
  %{category: "Product A", value: 35},
  %{category: "Product B", value: 25},
  %{category: "Product C", value: 20},
  %{category: "Product D", value: 20}
]

# Alternative with label field
[
  %{label: "Segment A", value: 45},
  %{label: "Segment B", value: 30},
  %{label: "Segment C", value: 25}
]
```

**Usage in Band:**

```elixir
band :market_analysis do
  type :detail

  elements do
    pie_chart :market_share
  end
end
```

### Area Charts

Best for visualizing cumulative values and trends over time with filled areas.

**Definition:**

```elixir
area_chart :cumulative_revenue do
  data_source expr(revenue_over_time())

  config do
    width 800
    height 400
    title "Cumulative Revenue"
    mode :simple      # :simple or :stacked
    opacity 0.7       # Fill opacity (0.0 to 1.0)
    smooth_lines true
    colours ["4285F4", "34A853"]
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `mode` | atom | :simple | `:simple` or `:stacked` |
| `opacity` | float | 0.7 | Fill opacity (0.0 to 1.0) |
| `smooth_lines` | boolean | true | Use smooth curves |
| `colours` | list | [] | Hex colors without # prefix |

**Data Format:**

```elixir
# Simple area
[
  %{x: 1, y: 10},
  %{x: 2, y: 15},
  %{x: 3, y: 12}
]

# Stacked areas (multiple series)
[
  %{x: 1, series: "Product A", y: 10},
  %{x: 1, series: "Product B", y: 5},
  %{x: 2, series: "Product A", y: 15},
  %{x: 2, series: "Product B", y: 8}
]
```

**Usage in Band:**

```elixir
band :revenue_trends do
  type :detail

  elements do
    area_chart :cumulative_revenue
  end
end
```

### Scatter Plots

Best for showing correlation and distribution between two variables.

**Definition:**

```elixir
scatter_chart :price_vs_sales do
  data_source expr(price_sales_correlation())

  config do
    width 700
    height 500
    title "Price vs Sales Correlation"
    point_size 5
    colours ["FF6D01"]
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `point_size` | integer | 5 | Size of scatter points |
| `colours` | list | [] | Hex colors without # prefix |

**Data Format:**

```elixir
[
  %{x: 10.5, y: 20.3},
  %{x: 15.2, y: 35.7},
  %{x: 20.1, y: 25.4},
  %{x: 25.8, y: 45.2}
]
```

**Usage in Band:**

```elixir
band :correlation_analysis do
  type :detail

  elements do
    scatter_chart :price_vs_sales
  end
end
```

### Sparklines

Compact inline charts (default 100×20px) perfect for dashboards and table cells.

**Definition:**

```elixir
sparkline :daily_trend do
  data_source expr(last_30_days_data())

  config do
    width 100
    height 20
    line_colour "rgba(0, 200, 50, 0.7)"
    fill_colour "rgba(0, 200, 50, 0.2)"
    spot_radius 2
    spot_colour "red"
    line_width 1
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 100 | Chart width in pixels |
| `height` | integer | 20 | Chart height in pixels |
| `line_colour` | string | "rgba(0,200,50,0.7)" | CSS color for line |
| `fill_colour` | string | "rgba(0,200,50,0.2)" | CSS color for fill |
| `spot_radius` | integer | 2 | Radius of highlight spots |
| `spot_colour` | string | "red" | CSS color for spots |
| `line_width` | integer | 1 | Width of the line |

**Data Format:**

```elixir
# Simple array of numbers
[1, 5, 10, 15, 12, 12, 15, 14, 20, 14, 10, 15, 15]

# Or map format
[
  %{value: 10},
  %{value: 15},
  %{value: 12}
]
```

**Usage in Band:**

Sparklines are perfect for inline display within other elements:

```elixir
band :metrics do
  type :detail

  elements do
    field :metric_name do
      source :name
    end

    sparkline :daily_trend

    field :current_value do
      source :value
    end
  end
end
```

**Use Cases:**
- Dashboard metric trends
- Table cell visualizations
- Mobile-optimized displays
- Quick trend indicators
- Space-constrained layouts

### Gantt Charts

Project timeline visualization with task scheduling and dependencies.

**Definition:**

```elixir
gantt_chart :project_timeline do
  data_source expr(sprint_tasks())

  config do
    width 1000
    height 600
    title "Sprint Planning Q1 2024"
    padding 2
    show_task_labels true
    colours ["4285F4", "EA4335", "FBBC04", "34A853"]
  end
end
```

**Configuration Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `padding` | integer | 2 | Padding between task bars |
| `show_task_labels` | boolean | true | Display task labels |
| `colours` | list | [] | Hex colors for categories |

**Data Format:**

```elixir
[
  %{
    category: "Phase 1",
    task: "Design",
    start_time: ~N[2024-01-01 00:00:00],
    end_time: ~N[2024-01-15 00:00:00],
    task_id: "task_1"  # Optional
  },
  %{
    category: "Phase 1",
    task: "Development",
    start_time: ~N[2024-01-10 00:00:00],
    end_time: ~N[2024-02-01 00:00:00]
  },
  %{
    category: "Phase 2",
    task: "Testing",
    start_time: ~N[2024-01-25 00:00:00],
    end_time: ~N[2024-02-10 00:00:00]
  }
]
```

**⚠️ Important DateTime Requirements:**

- `start_time` and `end_time` **MUST** be `NaiveDateTime` or `DateTime` types
- String dates will **NOT** be automatically converted
- Use `NaiveDateTime.new!/2` or `DateTime.from_naive!/2` to create proper values

**Usage in Band:**

```elixir
band :project_planning do
  type :detail

  elements do
    gantt_chart :project_timeline
  end
end
```

**Use Cases:**
- Project timeline visualization
- Sprint planning and tracking
- Resource allocation
- Task dependency visualization
- Milestone tracking

## Chart Configuration

### Config Block Structure

All chart configurations use a `config do ... end` block with type-specific options:

```elixir
bar_chart :my_chart do
  data_source expr(...)

  config do
    # Common options (available on all chart types)
    width 800
    height 400
    title "Chart Title"

    # Type-specific options
    type :grouped        # Bar chart only
    orientation :vertical # Bar chart only
    smoothed true        # Line/Area charts only
  end
end
```

### Common Configuration Options

These options are available on all chart types:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | integer | 600 | Chart width in pixels |
| `height` | integer | 400 | Chart height in pixels |
| `title` | string | nil | Chart title |
| `colours` | list | [] | Color palette (hex without #) |

### Color Specification

Colors are specified as hex codes **without** the `#` prefix:

```elixir
config do
  # Correct
  colours ["4285F4", "EA4335", "FBBC04", "34A853"]

  # Incorrect - don't include #
  colours ["#4285F4", "#EA4335"]  # Will be stripped automatically
end
```

### Default Color Palette

If `colours` is not specified, the default palette is used:

```elixir
["4285F4", "EA4335", "FBBC04", "34A853", "FF6D01", "46BDC6"]
```

## Data Sources

The `data_source` field specifies how to obtain chart data at render time.

### Expression-Based Data Sources

Use `expr()` to define expressions that evaluate to chart data:

```elixir
bar_chart :sales_by_region do
  # Expression referencing an aggregation
  data_source expr(aggregate_sales_by_region())

  config do
    title "Regional Sales"
  end
end
```

### Data Source Types

1. **Aggregation References** - Reference computed aggregations
   ```elixir
   data_source expr(my_aggregation())
   ```

2. **Field References** - Reference report data fields
   ```elixir
   data_source expr(chart_data_field)
   ```

3. **Variable References** - Reference report variables
   ```elixir
   data_source expr(monthly_totals_var)
   ```

4. **Records Reference** - Access all report records
   ```elixir
   data_source expr(records)
   ```

### Data Preparation

Chart data must be in the format expected by the chart type (see each chart type's "Data Format" section above).

Data can be prepared:
- In the driving resource query
- Via Ash aggregations
- Through report variables
- Using custom expressions

### Performance Considerations for Data Sources

⚠️ **IMPORTANT**: When working with large datasets, avoid eager loading relationships in your data_source functions!

**Common N+1 Problem:**

```elixir
# ❌ BAD - This causes N+1 queries with large datasets!
data_source(fn ->
  InvoiceLineItem
  |> Ash.Query.load(product: :category)  # Loads for EVERY line item!
  |> Ash.read!(domain: MyApp.Domain)
  |> process_into_chart_data()
end)
```

With 325,000 line items, this performs **325,000+ individual queries** and can take **8+ minutes**!

**Optimized Pattern:**

```elixir
# ✅ GOOD - Load relationships separately
data_source(fn ->
  alias AshReports.Charts.DataSourceHelpers

  # Use helper to load with optimization
  {:ok, {line_items, products_map}} =
    DataSourceHelpers.load_with_relationship(
      InvoiceLineItem,
      Product,
      :product_id,
      domain: MyApp.Domain,
      preload: :category
    )

  # Join in memory using the lookup map
  chart_data = process_with_lookup(line_items, products_map)

  {:ok, chart_data, %{source_records: length(line_items)}}
end)
```

This reduces execution from **8 minutes to <1 second** on large datasets!

**See the [Performance Optimization Guide](performance-optimization.md) for:**
- Detailed explanation of N+1 problems
- Complete examples with DataSourceHelpers
- Best practices for large datasets
- Monitoring and profiling techniques

## Complete Examples

### Example 1: Sales Report with Multiple Charts

```elixir
defmodule MyApp.Reports.SalesAnalytics do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    # Define reusable charts
    bar_chart :sales_by_region do
      data_source expr(regional_sales_data())

      config do
        width 800
        height 500
        title "Sales by Region"
        type :grouped
        data_labels true
        colours ["4285F4", "34A853", "FBBC04", "EA4335"]
      end
    end

    line_chart :monthly_trend do
      data_source expr(monthly_sales_trend())

      config do
        width 900
        height 400
        title "12-Month Sales Trend"
        smoothed true
        stroke_width "3"
        colours ["4285F4"]
      end
    end

    pie_chart :product_distribution do
      data_source expr(product_sales_distribution())

      config do
        width 600
        height 500
        title "Sales Distribution by Product"
        show_percentages true
        colours ["FF6384", "36A2EB", "FFCE56", "4BC0C0", "9966FF"]
      end
    end

    # Report using the charts
    report :quarterly_sales do
      title "Quarterly Sales Analytics"
      description "Comprehensive sales analysis"
      driving_resource MyApp.Sales.Order

      parameter :quarter, :integer, required: true
      parameter :year, :integer, required: true

      bands do
        band :report_header do
          type :title

          elements do
            label :title do
              text "Quarterly Sales Report"
              style font_size: 24, font_weight: :bold
            end
          end
        end

        band :regional_analysis do
          type :detail

          elements do
            label :section_title do
              text "Regional Performance"
              style font_size: 18, font_weight: :bold
            end

            bar_chart :sales_by_region
          end
        end

        band :trend_analysis do
          type :detail

          elements do
            label :section_title do
              text "Monthly Trends"
              style font_size: 18, font_weight: :bold
            end

            line_chart :monthly_trend
          end
        end

        band :product_analysis do
          type :detail

          elements do
            label :section_title do
              text "Product Distribution"
              style font_size: 18, font_weight: :bold
            end

            pie_chart :product_distribution
          end
        end
      end
    end
  end
end
```

### Example 2: Dashboard with Sparklines

```elixir
defmodule MyApp.Reports.Dashboard do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    # Define compact sparklines for each metric
    sparkline :revenue_trend do
      data_source expr(last_7_days_revenue())

      config do
        width 120
        height 30
        line_colour "rgba(34, 168, 83, 0.8)"
        fill_colour "rgba(34, 168, 83, 0.2)"
      end
    end

    sparkline :orders_trend do
      data_source expr(last_7_days_orders())

      config do
        width 120
        height 30
        line_colour "rgba(66, 133, 244, 0.8)"
        fill_colour "rgba(66, 133, 244, 0.2)"
      end
    end

    sparkline :customers_trend do
      data_source expr(last_7_days_customers())

      config do
        width 120
        height 30
        line_colour "rgba(251, 188, 4, 0.8)"
        fill_colour "rgba(251, 188, 4, 0.2)"
      end
    end

    report :executive_dashboard do
      title "Executive Dashboard"
      driving_resource MyApp.Sales.Metric

      bands do
        band :metrics do
          type :detail

          elements do
            # Revenue Metric
            label :revenue_label do
              text "Revenue (7d)"
              style font_weight: :bold
            end

            sparkline :revenue_trend

            field :revenue_current do
              source :current_revenue
              format :currency
              style font_size: 18
            end

            # Orders Metric
            label :orders_label do
              text "Orders (7d)"
              style font_weight: :bold
            end

            sparkline :orders_trend

            field :orders_current do
              source :current_orders
              format :number
              style font_size: 18
            end

            # Customers Metric
            label :customers_label do
              text "New Customers (7d)"
              style font_weight: :bold
            end

            sparkline :customers_trend

            field :customers_current do
              source :current_customers
              format :number
              style font_size: 18
            end
          end
        end
      end
    end
  end
end
```

### Example 3: Project Timeline Report

```elixir
defmodule MyApp.Reports.ProjectTracking do
  use Ash.Domain,
    extensions: [AshReports.Domain]

  reports do
    gantt_chart :sprint_timeline do
      data_source expr(sprint_tasks())

      config do
        width 1200
        height 600
        title "Sprint 1 Timeline"
        padding 3
        show_task_labels true
        colours ["4285F4", "EA4335", "FBBC04", "34A853"]
      end
    end

    bar_chart :task_completion do
      data_source expr(task_status_breakdown())

      config do
        width 600
        height 400
        title "Task Status"
        type :stacked
        orientation :horizontal
        colours ["34A853", "FBBC04", "EA4335"]
      end
    end

    report :sprint_review do
      title "Sprint Review"
      driving_resource MyApp.Projects.Task

      parameter :sprint_id, :integer, required: true

      bands do
        band :header do
          type :title

          elements do
            label :title do
              text "Sprint Review Report"
              style font_size: 24, font_weight: :bold
            end
          end
        end

        band :timeline do
          type :detail

          elements do
            label :timeline_title do
              text "Project Timeline"
              style font_size: 18, font_weight: :bold
            end

            gantt_chart :sprint_timeline
          end
        end

        band :status_summary do
          type :detail

          elements do
            label :status_title do
              text "Task Status Breakdown"
              style font_size: 18, font_weight: :bold
            end

            bar_chart :task_completion
          end
        end
      end
    end
  end
end
```

## Best Practices

### 1. Naming Conventions

- Use descriptive chart names: `:sales_by_region` not `:chart1`
- Name charts by what they show, not by type
- Use snake_case for chart names

### 2. Data Preparation

- Prepare data in the expected format before rendering
- Use Ash aggregations for data transformation
- Validate data structure matches chart requirements

### 3. Performance

- Keep data sets reasonable (<1000 points for most charts)
- Use sparklines for high-density data visualization
- Consider report generation time when adding multiple charts

### 4. Color Palette

- Use consistent colors across related charts
- Ensure sufficient contrast for readability
- Consider colorblind-friendly palettes

### 5. Chart Sizing

- Standard sizes: 600×400 (small), 800×500 (medium), 1000×600 (large)
- Sparklines: 100×20 (compact), 150×30 (readable)
- Gantt charts: Wider is better (1000+ width)

### 6. Reusability

- Define charts once at the reports level
- Reference charts in multiple bands
- Use consistent configuration across reports

## Troubleshooting

### Common Issues

**Chart not rendering:**
- Verify data source expression is valid
- Check data format matches chart type requirements
- Ensure chart is defined before being referenced

**Wrong data format error:**
- Review chart type's "Data Format" section
- Validate field names (category/value, x/y, etc.)
- For Gantt charts, ensure DateTime types (not strings)

**Colors not applied:**
- Remove `#` prefix from hex colors
- Ensure color list has enough values for data series
- Check spelling: `colours` (British) not `colors`

**Chart too small/large:**
- Adjust `width` and `height` in config block
- Consider PDF page size constraints
- Use appropriate sizes for chart type

### Getting Help

- Check examples in this guide
- Review chart type moduledocs
- Open issue on GitHub for bugs
- Ask in Ash Framework Discord

---

**Next Steps:**

- [Integration Guide](integration.md) - Using charts in Phoenix/LiveView
- [Advanced Features](advanced-features.md) - Custom formatting and theming
- [Report Creation](report-creation.md) - Building complete reports
