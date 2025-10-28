# Graphs and Visualizations

This guide covers adding charts and visualizations to AshReports using the basic chart element integration.

> **Important**: This guide reflects the current basic chart implementation. For the planned full-featured chart engine with multiple providers, interactive features, and auto-selection, see [ROADMAP.md Phase 2](../../ROADMAP.md#phase-2-enhanced-chart-engine).

## Table of Contents

- [Current Chart Capabilities](#current-chart-capabilities)
- [Basic Chart Element](#basic-chart-element)
- [Supported Chart Types](#supported-chart-types)
- [Chart Data Format](#chart-data-format)
- [Chart Positioning and Sizing](#chart-positioning-and-sizing)
- [Complete Examples](#complete-examples)
- [Limitations and Planned Features](#limitations-and-planned-features)

## Current Chart Capabilities

AshReports currently provides basic chart integration through the `chart` element type with support for:

- **Chart Types**: Bar, Line, Pie, Area, Scatter
- **Data Source**: Expression-based data sourcing
- **Output**: SVG generation via Contex library
- **Configuration**: Basic config via map or expression
- **Styling**: Width, height, and caption options

### What's NOT Currently Available

The following features are planned for future releases (see ROADMAP.md):

- ❌ Multiple chart providers (Chart.js, D3.js, Plotly)
- ❌ Interactive charts with zoom/pan
- ❌ Real-time chart updates
- ❌ Auto chart selection based on data
- ❌ ChartEngine and ChartConfig modules
- ❌ Advanced theming and styling
- ❌ Chart data accumulation and aggregation
- ❌ Drill-down navigation

## Basic Chart Element

Charts are added as elements within bands using the `chart` element:

```elixir
band :analytics do
  type :detail

  chart :monthly_sales_chart do
    chart_type :bar
    data_source :sales_data  # Expression that returns chart data
    title "Monthly Sales"
    position(x: 0, y: 0, width: 100, height: 40)
  end
end
```

### Chart Element Schema

The chart element supports the following options:

```elixir
chart :chart_name do
  # Required
  chart_type :bar  # :bar, :line, :pie, :area, :scatter
  data_source :expression  # Expression returning chart data

  # Optional
  title "Chart Title"  # String or expression
  caption "Chart Caption"  # String or expression
  config %{}  # Map or expression returning config
  embed_options %{width: 800, height: 400}

  # Standard element properties
  position(x: 0, y: 0, width: 100, height: 50)
  style(...)
  conditional expr(...)
end
```

## Supported Chart Types

### Bar Charts

Best for comparing values across categories:

```elixir
chart :revenue_by_region do
  chart_type :bar
  data_source :regional_revenue_data
  title "Revenue by Region"
  position(x: 0, y: 0, width: 100, height: 40)
end
```

**Data format:**
```elixir
[
  %{category: "North", value: 15000},
  %{category: "South", value: 12000},
  %{category: "East", value: 18000},
  %{category: "West", value: 14000}
]
```

### Line Charts

Best for showing trends over time:

```elixir
chart :sales_trend do
  chart_type :line
  data_source :monthly_sales_data
  title "Sales Trend (12 Months)"
  position(x: 0, y: 0, width: 100, height: 40)
end
```

**Data format:**
```elixir
[
  %{x: "Jan", y: 1200},
  %{x: "Feb", y: 1350},
  %{x: "Mar", y: 1100},
  %{x: "Apr", y: 1500}
]
```

### Pie Charts

Best for showing proportions and percentages:

```elixir
chart :market_share do
  chart_type :pie
  data_source :market_share_data
  title "Market Share by Product"
  position(x: 0, y: 0, width: 50, height: 40)
end
```

**Data format:**
```elixir
[
  %{label: "Product A", value: 35},
  %{label: "Product B", value: 25},
  %{label: "Product C", value: 20},
  %{label: "Product D", value: 20}
]
```

### Area Charts

Similar to line charts but with filled areas:

```elixir
chart :cumulative_revenue do
  chart_type :area
  data_source :cumulative_data
  title "Cumulative Revenue"
  position(x: 0, y: 0, width: 100, height: 40)
end
```

**Data format:** Same as line charts

### Scatter Charts

Best for showing correlations between two variables:

```elixir
chart :price_vs_sales do
  chart_type :scatter
  data_source :correlation_data
  title "Price vs Sales Volume"
  position(x: 0, y: 0, width: 100, height: 40)
end
```

**Data format:**
```elixir
[
  %{x: 10.5, y: 250},
  %{x: 15.0, y: 180},
  %{x: 20.0, y: 120},
  %{x: 25.5, y: 90}
]
```

## Chart Data Format

### Data Source Expressions

The `data_source` must be an expression that evaluates to chart data. This is typically:

1. A reference to a variable or aggregate
2. A reference to processed data in the render context
3. A field that contains pre-formatted chart data

> **Note**: Full expression evaluation and data processing for charts is under development. Currently, data should be prepared in the expected format before rendering.

### Example Data Structures

```elixir
# Simple bar/line chart data
[
  %{x: "Category 1", y: 100},
  %{x: "Category 2", y: 150},
  %{x: "Category 3", y: 75}
]

# Pie chart data
[
  %{label: "Segment A", value: 45},
  %{label: "Segment B", value: 30},
  %{label: "Segment C", value: 25}
]

# Scatter plot data
[
  %{x: 10, y: 20},
  %{x: 15, y: 35},
  %{x: 20, y: 25}
]

# Multi-series data (if supported by chart type)
[
  %{series: "2023", x: "Q1", y: 100},
  %{series: "2023", x: "Q2", y: 120},
  %{series: "2024", x: "Q1", y: 110},
  %{series: "2024", x: "Q2", y: 140}
]
```

## Chart Positioning and Sizing

Charts use the same positioning system as other elements:

```elixir
chart :sales_chart do
  chart_type :bar
  data_source :sales_data

  # Position within band
  position(
    x: 0,      # Horizontal position
    y: 0,      # Vertical position
    width: 100, # Width in units
    height: 40  # Height in units
  )

  # Embed options for SVG generation
  embed_options %{
    width: 800,   # SVG width in pixels
    height: 400   # SVG height in pixels
  }
end
```

### Responsive Sizing

For responsive charts in HTML output:

```elixir
chart :responsive_chart do
  chart_type :line
  data_source :trend_data
  position(x: 0, y: 0, width: 100, height: 40)

  embed_options %{
    width: 1200,
    height: 600
  }

  style(max_width: "100%", height: "auto")
end
```

## Complete Examples

### Sales Report with Bar Chart

```elixir
report :monthly_sales_with_chart do
  title "Monthly Sales Report"
  driving_resource MyApp.Sale

  parameter :year, :integer do
    required true
    default Date.utc_today().year
  end

  # Report title
  band :title do
    type :title

    label :report_title do
      text "Monthly Sales Analysis"
      style(font_size: 24, font_weight: :bold)
    end
  end

  # Chart band
  band :chart_section do
    type :detail

    label :chart_title do
      text "Visual Overview"
      style(font_size: 18, font_weight: :bold)
    end

    chart :monthly_sales_chart do
      chart_type :bar
      data_source :monthly_aggregates  # Pre-processed data
      title "Sales by Month"
      caption "All amounts in USD"

      position(x: 0, y: 5, width: 100, height: 40)

      embed_options %{
        width: 1000,
        height: 500
      }
    end
  end

  # Detail data table
  band :details do
    type :detail

    field :month do
      source :month_name
    end

    field :total_sales do
      source :total
      format :currency
    end

    field :transaction_count do
      source :count
      format :number
    end
  end
end
```

### Multi-Chart Dashboard Report

```elixir
report :executive_dashboard do
  title "Executive Dashboard"
  driving_resource MyApp.Sale

  parameter :start_date, :date
  parameter :end_date, :date

  # Title
  band :title do
    type :title

    label :dashboard_title do
      text "Executive Dashboard"
      style(font_size: 28, font_weight: :bold)
    end
  end

  # Top metrics charts
  band :top_charts do
    type :detail

    # Revenue trend line chart
    chart :revenue_trend do
      chart_type :line
      data_source :revenue_by_day
      title "Revenue Trend"
      position(x: 0, y: 0, width: 60, height: 30)
      embed_options %{width: 600, height: 300}
    end

    # Market share pie chart
    chart :market_share do
      chart_type :pie
      data_source :product_shares
      title "Market Share"
      position(x: 65, y: 0, width: 35, height: 30)
      embed_options %{width: 350, height: 300}
    end
  end

  # Bottom metrics charts
  band :bottom_charts do
    type :detail

    # Customer growth area chart
    chart :customer_growth do
      chart_type :area
      data_source :customer_counts
      title "Customer Growth"
      position(x: 0, y: 0, width: 48, height: 30)
      embed_options %{width: 480, height: 300}
    end

    # Product performance bar chart
    chart :product_performance do
      chart_type :bar
      data_source :product_sales
      title "Product Performance"
      position(x: 52, y: 0, width: 48, height: 30)
      embed_options %{width: 480, height: 300}
    end
  end
end
```

### Grouped Report with Summary Chart

```elixir
report :regional_sales_with_chart do
  title "Regional Sales Analysis"
  driving_resource MyApp.Sale

  group :by_region do
    level 1
    expression :region
    sort :asc
  end

  variable :region_total do
    type :sum
    expression :total
    reset_on :group
    reset_group 1
  end

  # Report title
  band :title do
    type :title

    label :title do
      text "Regional Sales Analysis"
      style(font_size: 24, font_weight: :bold)
    end
  end

  # Region header
  band :region_header do
    type :group_header
    group_level 1

    field :region_name do
      source :region
      style(font_size: 18, font_weight: :bold)
    end
  end

  # Region details
  band :details do
    type :detail

    field :product_name do
      source :product.name
    end

    field :quantity do
      source :quantity
      format :number
    end

    field :amount do
      source :total
      format :currency
    end
  end

  # Region footer with mini chart
  band :region_footer do
    type :group_footer
    group_level 1

    label :region_summary do
      text "Region Summary"
      style(font_weight: :bold)
    end

    expression :region_total_display do
      expression :region_total
      format :currency
      style(font_weight: :bold, font_size: 16)
    end
  end

  # Overall summary with chart
  band :summary do
    type :summary

    label :summary_title do
      text "Overall Performance"
      style(font_size: 20, font_weight: :bold)
    end

    chart :regional_comparison do
      chart_type :bar
      data_source :regional_totals  # Aggregated from groups
      title "Sales by Region"
      caption "Comparison of all regions"
      position(x: 0, y: 5, width: 100, height: 40)
    end
  end
end
```

## Chart Configuration

### Basic Config Map

The `config` option accepts a map of chart-specific settings:

```elixir
chart :configured_chart do
  chart_type :bar
  data_source :sales_data

  config %{
    # Chart-specific options (passed to Contex)
    axis_label_rotation: 45,
    show_data_labels: true,
    color_palette: [:blue, :green, :red]
  }
end
```

> **Note**: Configuration options depend on the Contex library capabilities. See [Contex documentation](https://github.com/mindok/contex) for available options.

## Integration with Report Variables

Charts can reference report variables for dynamic data:

```elixir
variable :monthly_totals do
  type :sum
  expression :total
  reset_on :group
  reset_group 1
end

band :summary do
  type :summary

  chart :monthly_chart do
    chart_type :bar
    data_source :monthly_totals  # Reference the variable
    title "Monthly Totals"
  end
end
```

> **Note**: Variable-to-chart data transformation is still under development. Currently works best with pre-formatted data.

## Limitations and Planned Features

### Current Limitations

1. **Limited Chart Types**: Only 5 basic types (bar, line, pie, area, scatter)
2. **Static Charts**: No interactivity in generated reports
3. **Single Provider**: Only Contex library support
4. **Manual Data Formatting**: Data must be pre-formatted for charts
5. **Basic Styling**: Limited customization options
6. **No Real-time**: Charts are static snapshots

### Planned Features (See ROADMAP.md)

#### Phase 2: Enhanced Chart Engine

- **Multiple Providers**: Chart.js, D3.js, Plotly support
- **Auto Chart Selection**: Automatically suggest best chart type for data
- **Interactive Charts**: Zoom, pan, click/hover events
- **Real-time Updates**: Live data streaming to charts
- **Advanced Styling**: Themes, custom colors, fonts
- **Chart Variables**: Accumulate data specifically for charts

#### Example of Planned Features

```elixir
# THIS DOES NOT WORK YET - Planned for Phase 2

# Auto-select best chart type
chart :auto_chart do
  data_source :sales_data
  auto_select true  # Analyzes data and picks best chart type
  providers [:chartjs, :d3js]  # Try multiple providers
end

# Interactive chart with drill-down
chart :interactive_sales do
  chart_type :bar
  data_source :sales_by_category
  provider :chartjs

  interactions do
    zoom true
    pan true
    click_handler &MyApp.Reports.drill_down_category/2
  end

  real_time true
  update_interval :timer.seconds(30)
end

# Advanced theming
chart :themed_chart do
  chart_type :line
  data_source :trend_data
  theme :corporate

  colors palette: :blue_gradient
  fonts title: "Roboto", labels: "Open Sans"

  animations entry: :fade, update: :morph
end
```

See [ROADMAP.md Phase 2](../../ROADMAP.md#phase-2-enhanced-chart-engine) for complete details on planned chart enhancements.

## Best Practices

### Current Best Practices

1. **Pre-process Data**: Format data for charts before rendering
2. **Size Appropriately**: Choose embed_options that work for your output format
3. **Keep It Simple**: Stick to basic chart types that work reliably
4. **Test Output**: Verify charts render correctly in all output formats (HTML, PDF)
5. **Position Carefully**: Leave adequate space for chart rendering

### Performance Tips

1. **Limit Data Points**: Too many data points can slow chart generation
2. **Use Appropriate Types**: Bar charts for <20 items, line charts for trends
3. **Consider Output Format**: PDFs may render charts differently than HTML

## Troubleshooting

### Common Issues

**Charts not appearing in output:**
- Verify data_source expression returns valid data
- Check chart positioning doesn't exceed band bounds
- Ensure Contex dependency is properly installed

**Chart rendering errors:**
- Validate data format matches chart type requirements
- Check for null/nil values in data
- Verify embed_options dimensions are reasonable

**PDF rendering issues:**
- Charts may appear differently in PDF vs HTML
- Consider adjusting embed_options for PDF output
- Test with smaller datasets first

## Next Steps

1. Review [Report Creation Guide](report-creation.md) for variables and aggregates
2. Learn about [Integration](integration.md) with Phoenix for interactive reports
3. Check [ROADMAP.md](../../ROADMAP.md) for upcoming chart features
4. Experiment with [Contex documentation](https://github.com/mindok/contex) for advanced options

## See Also

- [ROADMAP.md Phase 2](../../ROADMAP.md#phase-2-enhanced-chart-engine) - Planned chart engine
- [Contex Library](https://github.com/mindok/contex) - Current chart provider
- [Advanced Features](advanced-features.md) - Other visualization options
- [Report Creation](report-creation.md) - Variables and data aggregation
