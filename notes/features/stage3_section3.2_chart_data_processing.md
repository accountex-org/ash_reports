# Stage 3 Section 3.2: Chart Data Processing

**Feature Branch**: `feature/stage3-section3.2-chart-data-processing`
**Implementation Date**: TBD
**Status**: 📋 Planning
**Dependencies**: Section 3.1 (Chart Infrastructure), Stage 2 (GenStage Streaming)

## Problem Statement

While Section 3.1 established the chart generation infrastructure (registry, renderer, basic chart types), we now need comprehensive data processing capabilities to transform Ash resource data into chart-ready formats. Charts require:

- **Data extraction from Ash resources** - Query and aggregate data efficiently
- **Aggregation functions** - Sum, count, avg, min, max, statistical calculations
- **Time-series bucketing** - Daily, weekly, monthly grouping for trends
- **Multi-dimensional pivoting** - Complex data transformations for advanced charts
- **Large dataset handling** - Stream 1M records → aggregate to 500-1000 datapoints
- **Statistical calculations** - Percentiles, std deviation, median for analysis

**Impact**: Without these processing capabilities, charts are limited to pre-aggregated data and cannot handle real-world reporting scenarios with large datasets or complex analytics.

**Performance Goal**: Efficiently process 1M+ records and aggregate to 500-1000 chart datapoints for optimal SVG rendering performance.

## Solution Overview

Implement a comprehensive chart data processing pipeline that:

1. **Data Extraction** (`AshReports.Charts.DataExtractor`) - Query Ash resources and extract chart data
2. **Aggregation Pipeline** - Leverage existing GenStage infrastructure for large datasets
3. **Time-Series Bucketing** - Group data by time intervals (daily, weekly, monthly, quarterly, yearly)
4. **Statistical Functions** - Add percentile, std deviation, median calculations
5. **Multi-Dimensional Pivoting** - Transform data for complex chart types
6. **Additional Chart Types** - AreaChart and ScatterPlot implementations
7. **Dynamic Configuration** - Runtime chart config from Report DSL

## Technical Details

### Architecture Overview

```
Ash Resource Query
    ↓
DataExtractor (< 10K records: direct query)
    ↓                    ↓
    ↓              (>= 10K records: GenStage streaming)
    ↓                    ↓
    ↓          StreamingPipeline.Producer
    ↓                    ↓
    ↓          ProducerConsumer (aggregation)
    ↓                    ↓
    ↓          Consume stream → aggregated data
    ↓                    ↓
Aggregated Data (500-1000 datapoints)
    ↓
Chart Generation (Contex/VegaLite)
    ↓
SVG Output
```

### Integration with Existing Infrastructure

**Leverage Stage 2 GenStage Pipeline**:
- Producer: Chunked Ash query execution (already implemented)
- ProducerConsumer: Aggregation functions (sum, count, avg, min, max - already implemented)
- Need to add: Time-series bucketing, statistical calculations, pivoting

**Leverage Section 2.4 DSL Integration**:
- `build_grouped_aggregations_from_dsl/1` - Auto-configure aggregations from Report DSL
- Expression parsing for field extraction
- Variable-to-aggregation mapping

### Dependencies

**Required Libraries**:
```elixir
# Already available
{:contex, "~> 0.5.0"}        # Chart rendering
{:gen_stage, "~> 1.2"}       # Streaming pipeline
{:flow, "~> 1.2"}            # Parallel processing

# New dependencies for Section 3.2
{:statistics, "~> 0.6.3"}    # Statistical calculations (median, percentiles, std dev)
{:timex, "~> 3.7"}           # Time manipulation and bucketing
```

**Why Statistics Library**:
- Provides median, percentile, standard deviation, variance
- Pure Elixir implementation
- Well-maintained and stable
- Example: `Statistics.median([1,2,3])` returns 2

**Why Timex**:
- Advanced time manipulation and date arithmetic
- Time bucketing utilities (beginning_of_day, beginning_of_week, etc.)
- Timezone support for global reports
- Better than standard DateTime for complex time operations

### File Structure

```
lib/ash_reports/charts/
├── charts.ex                      # Main module (existing)
├── registry.ex                    # Chart type registry (existing)
├── renderer.ex                    # SVG rendering (existing)
├── config.ex                      # Chart configuration (existing)
├── cache.ex                       # ETS cache (existing)
├── data_extractor.ex              # NEW: Ash resource data extraction
├── aggregator.ex                  # NEW: Aggregation functions
├── time_series.ex                 # NEW: Time-series bucketing
├── statistics.ex                  # NEW: Statistical calculations
├── pivot.ex                       # NEW: Multi-dimensional pivoting
├── types/
│   ├── bar_chart.ex              # Existing
│   ├── line_chart.ex             # Existing
│   ├── pie_chart.ex              # Existing
│   ├── area_chart.ex             # NEW: Area chart implementation
│   ├── scatter_plot.ex           # NEW: Scatter plot with regression
│   └── behavior.ex               # Existing

test/ash_reports/charts/
├── data_extractor_test.exs        # NEW
├── aggregator_test.exs            # NEW
├── time_series_test.exs           # NEW
├── statistics_test.exs            # NEW
├── pivot_test.exs                 # NEW
├── types/
│   ├── area_chart_test.exs       # NEW
│   └── scatter_plot_test.exs     # NEW
```

## Success Criteria

### Functional Requirements
- [ ] DataExtractor can query Ash resources and extract chart data
- [ ] Aggregation functions: sum, count, avg, min, max, grouping
- [ ] Time-series bucketing: daily, weekly, monthly, quarterly, yearly
- [ ] Statistical calculations: median, percentiles (25th, 50th, 75th, 90th, 95th), std deviation, variance
- [ ] Multi-dimensional data pivoting for complex charts
- [ ] GenStage streaming integration for datasets >10K records
- [ ] AreaChart implementation using Contex
- [ ] ScatterPlot implementation with optional regression lines
- [ ] Dynamic chart configuration from Report DSL

### Performance Requirements
- Direct query: <100ms for datasets <10K records
- Streaming pipeline: 1M records → 500-1000 datapoints in <5 seconds
- Memory efficiency: <1.5x baseline memory usage
- Aggregation throughput: >1000 records/second
- Statistical calculations: <200ms for 10K datapoints

### Testing Requirements
- Unit tests for all modules (>80% coverage)
- Integration tests with Ash resources
- Performance benchmarks for large datasets
- Statistical accuracy validation tests
- Time-series bucketing correctness tests

## Implementation Plan

### Phase 1: Data Extraction and Aggregation (Section 3.2.1)

#### Step 1: Add Dependencies
```bash
# Add to mix.exs
{:statistics, "~> 0.6.3"}
{:timex, "~> 3.7"}

# Update dependencies
mix deps.get
```

#### Step 2: Create DataExtractor Module
**File**: `lib/ash_reports/charts/data_extractor.ex`

**Purpose**: Query Ash resources and extract chart data with intelligent routing:
- Datasets <10K records: Direct Ash query
- Datasets ≥10K records: GenStage streaming pipeline

**Key Functions**:
```elixir
@spec extract_for_chart(domain, resource, query, chart_type, opts) ::
  {:ok, chart_data} | {:error, term}

@spec estimate_dataset_size(domain, resource, query) :: pos_integer

@spec extract_with_aggregation(domain, resource, query, aggregation_opts) ::
  {:ok, aggregated_data} | {:error, term}

@spec extract_with_streaming(domain, resource, query, aggregation_opts) ::
  {:ok, aggregated_data} | {:error, term}
```

**Implementation Details**:
- Use `Ash.count/2` to estimate dataset size
- Route to direct query or streaming based on size threshold
- Integrate with existing StreamingPipeline (Section 2.5)
- Support aggregation specifications from chart config
- Handle relationship traversal for nested data

#### Step 3: Implement Aggregation Module
**File**: `lib/ash_reports/charts/aggregator.ex`

**Purpose**: Provide aggregation functions that work with both direct queries and streaming pipelines

**Aggregation Functions**:
```elixir
# Basic aggregations (leverage ProducerConsumer implementations)
@spec sum(data, field) :: number
@spec count(data) :: pos_integer
@spec avg(data, field) :: float
@spec min(data, field) :: number
@spec max(data, field) :: number

# Grouping aggregations
@spec group_by(data, fields, aggregations) :: grouped_data

# Running calculations
@spec running_total(data, field) :: [{index, total}]
@spec moving_average(data, field, window_size) :: [{index, avg}]
```

**Key Design Decision**: Reuse ProducerConsumer aggregation logic for consistency
- Extract aggregation algorithms to shared module
- ProducerConsumer calls this module for streaming
- Aggregator calls this module for in-memory data

#### Step 4: Implement Time-Series Bucketing
**File**: `lib/ash_reports/charts/time_series.ex`

**Purpose**: Group time-series data by intervals for trend analysis

**Bucket Functions**:
```elixir
@type bucket_interval :: :hourly | :daily | :weekly | :monthly | :quarterly | :yearly | :custom

@spec bucket_by_interval(data, datetime_field, interval, opts) :: bucketed_data

@spec bucket_by_day(data, datetime_field) :: daily_buckets
@spec bucket_by_week(data, datetime_field, opts) :: weekly_buckets  # week_start: :monday | :sunday
@spec bucket_by_month(data, datetime_field) :: monthly_buckets
@spec bucket_by_quarter(data, datetime_field) :: quarterly_buckets
@spec bucket_by_year(data, datetime_field) :: yearly_buckets

@spec bucket_by_custom(data, datetime_field, bucket_fn) :: custom_buckets
```

**Implementation Strategy**:
- Use Timex for date manipulation (beginning_of_week, beginning_of_month, etc.)
- Support timezone-aware bucketing
- Handle missing buckets (fill with zeros or interpolate)
- Support bucket aggregation (sum, avg, count per bucket)

**Example Usage**:
```elixir
# Daily sales bucketing
data = [
  %{date: ~U[2024-01-15 10:30:00Z], amount: 100},
  %{date: ~U[2024-01-15 14:20:00Z], amount: 150},
  %{date: ~U[2024-01-16 09:15:00Z], amount: 200}
]

TimeSeries.bucket_by_day(data, :date, aggregate: :sum, field: :amount)
# => [
#      %{bucket: ~D[2024-01-15], amount: 250},
#      %{bucket: ~D[2024-01-16], amount: 200}
#    ]
```

#### Step 5: Implement Statistical Calculations
**File**: `lib/ash_reports/charts/statistics.ex`

**Purpose**: Calculate statistical metrics for data analysis

**Statistical Functions**:
```elixir
# Central tendency
@spec median(data, field) :: float
@spec mode(data, field) :: term

# Spread
@spec variance(data, field) :: float
@spec standard_deviation(data, field) :: float
@spec range(data, field) :: {min, max}

# Percentiles
@spec percentile(data, field, percent) :: float  # percent: 0-100
@spec quartiles(data, field) :: {q1, q2, q3}
@spec percentiles(data, field, [percent]) :: [{percent, value}]

# Distribution
@spec histogram(data, field, bins) :: histogram_data
@spec frequency_distribution(data, field) :: distribution_data
```

**Implementation Strategy**:
- Delegate to `statistics` library for core calculations
- Provide convenience wrappers with field extraction
- Support both in-memory and streaming calculations
- Add validation for numeric data types

**Example Usage**:
```elixir
sales_data = [
  %{amount: 100}, %{amount: 150}, %{amount: 200},
  %{amount: 180}, %{amount: 120}, %{amount: 250}
]

Statistics.median(sales_data, :amount)
# => 165.0

Statistics.percentiles(sales_data, :amount, [25, 50, 75, 90, 95])
# => [{25, 125.0}, {50, 165.0}, {75, 215.0}, {90, 241.0}, {95, 247.5}]

Statistics.standard_deviation(sales_data, :amount)
# => 56.8
```

#### Step 6: Implement Multi-Dimensional Pivoting
**File**: `lib/ash_reports/charts/pivot.ex`

**Purpose**: Transform data for complex multi-dimensional charts

**Pivot Functions**:
```elixir
@spec pivot(data, row_field, col_field, value_field, agg_fn) :: pivoted_data

@spec pivot_table(data, rows, columns, values, aggregations) :: pivot_table

@spec unpivot(pivoted_data, opts) :: normalized_data

@spec cross_tabulate(data, field1, field2) :: crosstab_data
```

**Implementation Strategy**:
- Group by row and column fields
- Apply aggregation to value field
- Generate matrix structure for heatmaps/tables
- Support multiple value fields and aggregations

**Example Usage**:
```elixir
sales_data = [
  %{region: "North", product: "A", sales: 100},
  %{region: "North", product: "B", sales: 150},
  %{region: "South", product: "A", sales: 200},
  %{region: "South", product: "B", sales: 180}
]

Pivot.pivot(sales_data, :region, :product, :sales, &Enum.sum/1)
# => %{
#      "North" => %{"A" => 100, "B" => 150},
#      "South" => %{"A" => 200, "B" => 180}
#    }
```

#### Step 7: Integration with GenStage Streaming
**Enhancement**: Extend existing StreamingPipeline integration

**Key Changes**:
- Add time-series bucketing to ProducerConsumer aggregations
- Add statistical calculations to aggregation options
- Support pivoting in grouped aggregations

**New Aggregation Options**:
```elixir
# In ProducerConsumer.start_link/1
grouped_aggregations: [
  %{
    group_by: {:time_bucket, :created_at, :daily},  # NEW: time bucketing
    aggregations: [:sum, :count, :avg, :median, :percentile_95],  # NEW: statistical
    fields: [:amount],
    bucket_opts: [timezone: "America/New_York", fill_missing: true]  # NEW: bucket options
  }
]
```

**Implementation Location**: Enhance `lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex`

#### Step 8: Write Tests for Phase 1
**Test Coverage**:
- DataExtractor tests:
  - Direct query extraction
  - Streaming pipeline routing
  - Size estimation accuracy
  - Relationship handling
- Aggregator tests:
  - All aggregation functions (sum, count, avg, min, max)
  - Grouping with multiple fields
  - Running calculations accuracy
- TimeSeries tests:
  - All bucket intervals (hourly, daily, weekly, monthly, quarterly, yearly)
  - Timezone handling
  - Missing bucket fill strategies
  - Bucket aggregation correctness
- Statistics tests:
  - All statistical functions accuracy
  - Percentile calculations
  - Histogram generation
  - Edge cases (empty data, single value, outliers)
- Pivot tests:
  - Simple pivot operations
  - Multi-dimensional pivoting
  - Cross-tabulation
  - Unpivot operations

### Phase 2: Additional Chart Types (Section 3.2.2)

#### Step 9: Implement AreaChart
**File**: `lib/ash_reports/charts/types/area_chart.ex`

**Purpose**: Stacked area charts for time-series data visualization

**Note**: Contex does not natively support area charts. Implementation options:
1. **Extend LinePlot with fill** - Modify SVG to add filled paths
2. **Custom implementation** - Build area chart from scratch using SVG primitives
3. **Use VegaLite** - If needed for advanced features (defer to future)

**Recommended Approach**: Extend LinePlot with SVG fill

**Data Format**:
```elixir
[
  %{date: ~D[2024-01-01], series: "Product A", value: 100},
  %{date: ~D[2024-01-01], series: "Product B", value: 80},
  %{date: ~D[2024-01-02], series: "Product A", value: 120},
  %{date: ~D[2024-01-02], series: "Product B", value: 90}
]
```

**Implementation Strategy**:
```elixir
defmodule AshReports.Charts.Types.AreaChart do
  @behaviour AshReports.Charts.Types.Behavior

  @impl true
  def build(data, config) do
    # Use Contex.LinePlot as base
    dataset = Dataset.new(data)

    line_plot = LinePlot.new(dataset,
      mapping: %{x_col: :date, y_cols: extract_series(data)},
      colour_palette: config.colors
    )

    # Will need custom SVG manipulation to add fill
    line_plot
  end

  # Custom SVG post-processing to add area fills
  defp add_area_fills(svg, config) do
    # Parse SVG, add <path> elements with fill for area effect
    # This is a custom implementation
  end
end
```

**Alternative**: Mark as "Future Enhancement" if complex

#### Step 10: Implement ScatterPlot
**File**: `lib/ash_reports/charts/types/scatter_plot.ex`

**Purpose**: Scatter plots with optional linear regression lines

**Note**: Contex supports PointPlot (scatter plot equivalent)

**Data Format**:
```elixir
[
  %{x: 10, y: 20},
  %{x: 15, y: 25},
  %{x: 20, y: 22},
  %{x: 25, y: 30}
]
```

**Implementation Strategy**:
```elixir
defmodule AshReports.Charts.Types.ScatterPlot do
  @behaviour AshReports.Charts.Types.Behavior

  alias Contex.{Dataset, PointPlot}

  @impl true
  def build(data, config) do
    dataset = Dataset.new(data)

    point_plot = PointPlot.new(dataset,
      mapping: %{x_col: :x, y_cols: [:y]},
      colour_palette: config.colors
    )

    # Add regression line if configured
    if config.show_regression do
      add_regression_line(point_plot, data)
    else
      point_plot
    end
  end

  defp add_regression_line(plot, data) do
    # Calculate linear regression: y = mx + b
    {slope, intercept} = linear_regression(data)

    # Add regression line to plot (may need custom SVG overlay)
    # Contex may not support this directly, would need custom implementation
    plot
  end

  defp linear_regression(data) do
    # Simple linear regression calculation
    # y = mx + b
    # m = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    # b = (Σy - m*Σx) / n

    n = length(data)
    sum_x = Enum.sum_by(data, & &1.x)
    sum_y = Enum.sum_by(data, & &1.y)
    sum_xy = Enum.sum_by(data, &(&1.x * &1.y))
    sum_x2 = Enum.sum_by(data, &(&1.x * &1.x))

    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    intercept = (sum_y - slope * sum_x) / n

    {slope, intercept}
  end
end
```

#### Step 11: Write Tests for Phase 2
**Test Coverage**:
- AreaChart tests:
  - Single series area chart
  - Stacked multi-series area chart
  - SVG fill validation
  - Data ordering and interpolation
- ScatterPlot tests:
  - Basic scatter plot generation
  - Regression line calculation accuracy
  - Regression line SVG rendering
  - Outlier handling
  - Multi-series scatter plots

### Phase 3: Dynamic Chart Configuration (Section 3.2.3)

#### Step 12: Report DSL Chart Configuration
**Purpose**: Enable runtime chart configuration from Report DSL

**DSL Enhancement** (future work - Section 3.3.2):
```elixir
# In Report DSL
report :sales_dashboard do
  charts do
    chart :sales_trend do
      type :line
      title "Sales Trend"
      data_source :sales_by_month  # References a data extraction query

      x_axis field: :month, label: "Month"
      y_axis field: :amount, label: "Sales ($)"

      series do
        series "2023", field: :sales_2023, color: "#4ECDC4"
        series "2024", field: :sales_2024, color: "#45B7D1"
      end

      dimensions width: 800, height: 400
      theme :modern_blue
    end
  end
end
```

**For Section 3.2**: Focus on programmatic configuration:
```elixir
# Build chart config from params/options
def build_chart_config(report, chart_name, params) do
  chart_def = get_chart_definition(report, chart_name)

  %Config{
    title: resolve_title(chart_def, params),
    width: get_dimension(chart_def, :width, params),
    height: get_dimension(chart_def, :height, params),
    colors: resolve_theme(chart_def, params),
    x_axis_label: resolve_label(chart_def, :x_axis, params),
    y_axis_label: resolve_label(chart_def, :y_axis, params)
  }
end
```

#### Step 13: Conditional Chart Rendering
**Purpose**: Render charts based on data conditions

**Implementation**:
```elixir
defmodule AshReports.Charts.ConditionalRenderer do
  @spec should_render?(chart_config, data, conditions) :: boolean

  def should_render?(config, data, conditions) do
    Enum.all?(conditions, fn condition ->
      evaluate_condition(condition, data)
    end)
  end

  defp evaluate_condition({:min_records, count}, data) do
    length(data) >= count
  end

  defp evaluate_condition({:has_field, field}, data) do
    data |> List.first() |> Map.has_key?(field)
  end

  defp evaluate_condition({:custom, check_fn}, data) do
    check_fn.(data)
  end
end
```

**Usage**:
```elixir
# Only render if we have at least 10 data points
conditions = [min_records: 10, has_field: :sales]

if ConditionalRenderer.should_render?(config, data, conditions) do
  Charts.generate(:line, data, config)
else
  {:ok, render_no_data_message(config)}
end
```

#### Step 14: Chart Theming System
**Purpose**: Predefined and custom chart themes

**Implementation**:
```elixir
defmodule AshReports.Charts.Theme do
  @themes %{
    modern_blue: %{
      colors: ["#4ECDC4", "#45B7D1", "#5F9EA0", "#7FCDCD"],
      font_family: "Inter, sans-serif",
      font_size: 14,
      background: "#FFFFFF",
      grid_color: "#E0E0E0"
    },
    dark_mode: %{
      colors: ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4"],
      font_family: "Inter, sans-serif",
      font_size: 14,
      background: "#1A1A1A",
      grid_color: "#333333"
    },
    minimal: %{
      colors: ["#000000", "#666666", "#999999", "#CCCCCC"],
      font_family: "Helvetica, Arial, sans-serif",
      font_size: 12,
      background: "#FFFFFF",
      grid_color: "#F5F5F5"
    }
  }

  @spec apply_theme(config, theme_name) :: config
  def apply_theme(config, theme_name) when is_atom(theme_name) do
    case Map.fetch(@themes, theme_name) do
      {:ok, theme} -> merge_theme(config, theme)
      :error -> config
    end
  end

  @spec apply_custom_theme(config, theme_map) :: config
  def apply_custom_theme(config, theme_map) when is_map(theme_map) do
    merge_theme(config, theme_map)
  end
end
```

#### Step 15: Layout and Responsive Sizing
**Purpose**: Chart sizing and layout options

**Implementation**:
```elixir
defmodule AshReports.Charts.Layout do
  @spec responsive_dimensions(config, container_width, container_height) :: {width, height}

  def responsive_dimensions(config, container_width, container_height) do
    case config.sizing_mode do
      :fixed -> {config.width, config.height}
      :percentage -> calculate_percentage_size(config, container_width, container_height)
      :aspect_ratio -> calculate_aspect_ratio_size(config, container_width)
    end
  end

  defp calculate_percentage_size(config, container_width, container_height) do
    width = trunc(container_width * (config.width_percent / 100))
    height = trunc(container_height * (config.height_percent / 100))
    {width, height}
  end

  defp calculate_aspect_ratio_size(config, container_width) do
    # Maintain aspect ratio (e.g., 16:9)
    width = container_width
    height = trunc(width / config.aspect_ratio)
    {width, height}
  end
end
```

#### Step 16: Legend and Axis Customization
**Purpose**: Detailed control over chart elements

**Config Extensions**:
```elixir
defmodule AshReports.Charts.Config do
  use Ecto.Schema

  embedded_schema do
    # ... existing fields ...

    # Legend configuration
    field :show_legend, :boolean, default: true
    field :legend_position, Ecto.Enum, values: [:top, :bottom, :left, :right], default: :right
    field :legend_font_size, :integer, default: 12

    # Axis configuration
    embeds_one :x_axis, AxisConfig do
      field :label, :string
      field :show_ticks, :boolean, default: true
      field :show_grid, :boolean, default: true
      field :tick_interval, :integer
      field :format, :string  # e.g., "%Y-%m-%d" for dates
    end

    embeds_one :y_axis, AxisConfig do
      field :label, :string
      field :show_ticks, :boolean, default: true
      field :show_grid, :boolean, default: true
      field :tick_interval, :integer
      field :format, :string  # e.g., "$%d" for currency
    end
  end
end
```

#### Step 17: Data Labels and Annotations
**Purpose**: Add labels and annotations to charts

**Implementation**:
```elixir
defmodule AshReports.Charts.Annotations do
  @spec add_data_labels(chart, data, opts) :: chart
  def add_data_labels(chart, data, opts \\ []) do
    # Add value labels on data points
    # Position: :above, :below, :inside
    # Format: number format string

    # This would require SVG post-processing
    # Add <text> elements at appropriate positions
  end

  @spec add_threshold_line(chart, value, opts) :: chart
  def add_threshold_line(chart, value, opts \\ []) do
    # Add horizontal/vertical threshold line
    # e.g., budget line, target line, average line

    # Add <line> element to SVG
  end

  @spec add_annotation(chart, annotation) :: chart
  def add_annotation(chart, %{x: x, y: y, text: text}) do
    # Add text annotation at specific point
    # with optional arrow/pointer

    # Add <text> and <path> elements to SVG
  end
end
```

#### Step 18: Write Tests for Phase 3
**Test Coverage**:
- DSL configuration tests:
  - Config building from chart definitions
  - Parameter resolution
  - Default value handling
- Conditional rendering tests:
  - Min records condition
  - Field existence condition
  - Custom condition functions
- Theme tests:
  - Predefined theme application
  - Custom theme application
  - Theme merging with config
- Layout tests:
  - Fixed sizing
  - Percentage-based sizing
  - Aspect ratio calculations
  - Responsive behavior
- Customization tests:
  - Legend positioning and styling
  - Axis label and tick configuration
  - Grid line customization
- Annotation tests:
  - Data label rendering
  - Threshold line placement
  - Custom annotation positioning

#### Step 19: Integration Testing
**End-to-End Scenarios**:

**Test 1: Large Dataset Chart Generation**
```elixir
# Generate chart from 100K records with streaming aggregation
test "chart from large dataset with time-series bucketing" do
  # Create 100K sales records
  records = generate_large_dataset(100_000)

  # Extract and aggregate to daily buckets (365 datapoints)
  {:ok, chart_data} = DataExtractor.extract_for_chart(
    MyApp.Reporting,
    MyApp.Sales.Order,
    query,
    :line,
    aggregation: [
      group_by: {:time_bucket, :created_at, :daily},
      aggregations: [:sum],
      fields: [:amount]
    ]
  )

  # Should have ~365 datapoints (1 year of daily data)
  assert length(chart_data) <= 365

  # Generate chart
  config = %Config{title: "Daily Sales Trend", width: 800, height: 400}
  {:ok, svg} = Charts.generate(:line, chart_data, config)

  # Validate SVG
  assert svg =~ ~r/<svg/
  assert svg =~ "Daily Sales Trend"
end
```

**Test 2: Statistical Analysis Chart**
```elixir
test "scatter plot with regression line and percentile bands" do
  data = generate_correlation_data(1000)

  # Calculate statistics
  {:ok, stats} = Statistics.percentiles(data, :y, [25, 75])

  # Generate scatter plot with regression
  config = %Config{
    title: "Correlation Analysis",
    show_regression: true,
    annotations: [
      %{type: :threshold, value: stats[{25, :value}], label: "25th Percentile"},
      %{type: :threshold, value: stats[{75, :value}], label: "75th Percentile"}
    ]
  }

  {:ok, svg} = Charts.generate(:scatter, data, config)

  # Should include regression line and percentile bands
  assert svg =~ "regression"
end
```

**Test 3: Multi-Dimensional Pivot Chart**
```elixir
test "heatmap from pivoted sales data" do
  # Sales by region and product category
  sales = load_sales_by_region_and_category()

  # Pivot data
  pivoted = Pivot.pivot(sales, :region, :category, :amount, &Enum.sum/1)

  # Convert to heatmap format
  heatmap_data = Pivot.to_heatmap_format(pivoted)

  # Generate heatmap (custom chart type)
  config = %Config{title: "Sales Heatmap", theme: :dark_mode}
  {:ok, svg} = Charts.generate(:heatmap, heatmap_data, config)

  assert svg =~ ~r/<rect/  # Heatmap uses rectangles
end
```

#### Step 20: Documentation and Examples
**Documentation Tasks**:
- [ ] Update main Charts module docs with new capabilities
- [ ] Document DataExtractor API and usage patterns
- [ ] Document aggregation and time-series bucketing
- [ ] Document statistical calculations with examples
- [ ] Document pivoting and multi-dimensional data
- [ ] Create chart type gallery with examples
- [ ] Document theming and customization options
- [ ] Add performance tuning guide
- [ ] Create migration guide from basic charts

## Testing Strategy

### Unit Tests
- **DataExtractor**: Query building, size estimation, streaming routing
- **Aggregator**: All aggregation functions, accuracy validation
- **TimeSeries**: Bucket intervals, timezone handling, fill strategies
- **Statistics**: Statistical accuracy (use known datasets with expected results)
- **Pivot**: Pivot operations, matrix generation, unpivoting
- **AreaChart**: SVG generation, fill rendering, stacking
- **ScatterPlot**: Point plotting, regression calculation, overlay rendering

### Integration Tests
- **Ash Resource Integration**: Query execution, relationship handling
- **GenStage Pipeline**: Streaming aggregation, memory efficiency
- **End-to-End**: Full chart generation from resource to SVG
- **DSL Integration**: Config from Report DSL, variable resolution
- **Multi-Chart Reports**: Multiple charts in single report

### Performance Tests
- **Benchmark Suite**:
  - Direct query: 1K, 10K records
  - Streaming: 100K, 1M records
  - Aggregation throughput: records/second
  - Statistical calculations: calculation time
  - SVG generation: render time and output size

**Performance Targets**:
```elixir
# benchmarks/chart_data_processing_benchmarks.exs

benchmarks = %{
  "DataExtractor: Direct query (10K records)" => fn ->
    DataExtractor.extract_for_chart(domain, resource, query, :bar)
  end,

  "DataExtractor: Streaming (1M records -> 1K datapoints)" => fn ->
    DataExtractor.extract_with_streaming(domain, resource, large_query,
      aggregation: [group_by: :category, aggregations: [:sum]])
  end,

  "TimeSeries: Daily bucketing (100K records)" => fn ->
    TimeSeries.bucket_by_day(time_series_data, :timestamp)
  end,

  "Statistics: Percentiles (10K datapoints)" => fn ->
    Statistics.percentiles(data, :value, [25, 50, 75, 90, 95])
  end,

  "Pivot: 2D pivot (10K records, 50x20 matrix)" => fn ->
    Pivot.pivot(sales_data, :region, :product, :amount, &Enum.sum/1)
  end
}

Benchee.run(benchmarks,
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ]
)
```

### Visual Validation Tests
- [ ] Capture SVG output for visual regression testing
- [ ] Validate chart structure and elements
- [ ] Test responsive sizing accuracy
- [ ] Validate theme application
- [ ] Test annotation positioning

## Performance Considerations

### Memory Efficiency

**Direct Query (<10K records)**:
- Load all records: ~100KB per 1K records
- Aggregate in-memory: O(n) memory
- Total: ~1MB for 10K records

**Streaming (≥10K records)**:
- Chunk size: 1000 records
- Buffer size: 1000 records
- Memory usage: ~200KB constant (regardless of dataset size)
- Aggregated output: 500-1000 datapoints (~50KB)

### Processing Throughput

**Aggregation Performance**:
- Direct query: ~10K records/sec (in-memory)
- Streaming: ~1K-2K records/sec (with backpressure)
- Time-series bucketing: ~5K records/sec
- Statistical calculations: ~10K records/sec (median, percentiles)
- Pivoting: ~8K records/sec

**Chart Generation**:
- Simple charts: <50ms
- Complex charts: <200ms
- AreaChart with fill: <150ms
- ScatterPlot with regression: <100ms

### Optimization Strategies

1. **Smart Routing**:
   - Small datasets: Direct query (faster, simpler)
   - Large datasets: Streaming (memory safe)
   - Threshold: 10K records

2. **Caching**:
   - Cache aggregated data (TTL: 5 minutes)
   - Cache SVG output (existing cache system)
   - Cache statistical calculations

3. **Parallel Processing**:
   - Use Flow for independent calculations
   - Parallel bucket aggregation
   - Parallel statistical calculations

4. **Database Optimization**:
   - Push aggregation to database when possible (Ash.Query.aggregate)
   - Use database time bucketing (PostgreSQL: date_trunc)
   - Index on grouping/bucketing fields

## Edge Cases and Error Handling

### Data Quality Issues
- **Empty datasets**: Return "No data" chart or error
- **Null values**: Filter or replace with defaults
- **Outliers**: Optional outlier detection and removal
- **Invalid dates**: Skip or use fallback bucketing

### Processing Errors
- **Memory overflow**: Circuit breaker activation, reduce chunk size
- **Aggregation failure**: Fallback to simpler aggregation
- **Statistical calculation errors**: Return partial results or skip
- **Pivot dimension overflow**: Warn and truncate

### Chart Generation Errors
- **Data format mismatch**: Validate and transform
- **Contex rendering failure**: Fallback to simple chart or error message
- **SVG too large**: Warn and suggest data reduction

## Dependencies on Other Work

### Completed Work (Available Now)
- **Section 3.1**: Chart infrastructure (registry, renderer, config, cache)
- **Stage 2**: GenStage streaming pipeline with aggregations
- **Section 2.4**: DSL-driven aggregation configuration

### Future Work (Dependencies)
- **Section 3.3.1**: Typst SVG embedding (will use charts from this section)
- **Section 3.3.2**: Report DSL chart element (will configure charts from this section)

### Integration Points
- **DataLoader**: Reuse Ash query building and execution
- **StreamingPipeline**: Reuse Producer, ProducerConsumer for large datasets
- **DataProcessor**: Reuse type conversion and formatting
- **ExpressionParser**: Reuse for extracting chart data fields from DSL

## Future Enhancements

### Advanced Chart Types
- HeatmapChart (2D color-coded matrix)
- RadarChart (multi-dimensional comparison)
- GanttChart (project timelines)
- TreemapChart (hierarchical data)
- CandlestickChart (financial data)

### Advanced Analytics
- Trend analysis (moving averages, exponential smoothing)
- Anomaly detection (outlier identification)
- Correlation analysis (between multiple series)
- Forecasting (basic prediction models)

### Interactive Features (for Web)
- Zoom and pan
- Drill-down on data points
- Dynamic filtering
- Export to PNG/PDF
- Real-time updates via LiveView

### VegaLite Integration
- Grammar of graphics approach
- More complex visualizations
- Declarative chart specifications
- Advanced interactivity

## Current Status

### What's Completed
- ✅ Planning document created
- ✅ Architecture designed
- ✅ Dependencies identified (statistics, timex)
- ✅ File structure planned
- ✅ Implementation plan detailed
- ✅ Section 3.1 complete (chart infrastructure)
- ✅ Stage 2 complete (GenStage streaming)

### What's Next
1. Get approval for implementation plan
2. Create feature branch: `feature/stage3-section3.2-chart-data-processing`
3. Add dependencies (statistics, timex)
4. Implement Phase 1 (Data Extraction and Aggregation)
5. Implement Phase 2 (Additional Chart Types)
6. Implement Phase 3 (Dynamic Configuration)
7. Write comprehensive tests
8. Performance benchmarking
9. Documentation updates
10. Create commit after permission

### How to Run (After Implementation)

```elixir
# Example 1: Simple bar chart from Ash resource
alias AshReports.Charts

{:ok, data} = Charts.DataExtractor.extract_for_chart(
  MyApp.Reporting,
  MyApp.Sales.Order,
  Ash.Query.new(MyApp.Sales.Order),
  :bar,
  aggregation: [
    group_by: :product_category,
    aggregations: [:sum],
    fields: [:amount]
  ]
)

config = %Charts.Config{
  title: "Sales by Category",
  width: 600,
  height: 400,
  theme: :modern_blue
}

{:ok, svg} = Charts.generate(:bar, data, config)

# Example 2: Time-series line chart with streaming (large dataset)
{:ok, data} = Charts.DataExtractor.extract_for_chart(
  MyApp.Reporting,
  MyApp.Sales.Order,
  large_query,  # 1M records
  :line,
  aggregation: [
    group_by: {:time_bucket, :created_at, :daily},
    aggregations: [:sum],
    fields: [:amount]
  ]
)
# Automatically uses streaming pipeline, aggregates to ~365 daily datapoints

config = %Charts.Config{
  title: "Daily Sales Trend",
  x_axis: %{label: "Date", show_grid: true},
  y_axis: %{label: "Sales ($)", format: "$%d"}
}

{:ok, svg} = Charts.generate(:line, data, config)

# Example 3: Scatter plot with statistical analysis
data = load_customer_data()

# Add percentile annotations
{:ok, stats} = Charts.Statistics.percentiles(data, :lifetime_value, [25, 50, 75, 95])

config = %Charts.Config{
  title: "Customer Lifetime Value Analysis",
  show_regression: true,
  annotations: [
    %{type: :threshold, value: stats[{50, :value}], label: "Median"},
    %{type: :threshold, value: stats[{95, :value}], label: "95th Percentile"}
  ]
}

{:ok, svg} = Charts.generate(:scatter, data, config)

# Example 4: Multi-dimensional pivot for heatmap
sales_data = load_regional_sales()

pivoted = Charts.Pivot.pivot(
  sales_data,
  :region,
  :product_category,
  :sales,
  &Enum.sum/1
)

# Convert to heatmap format and generate
heatmap_data = Charts.Pivot.to_heatmap_format(pivoted)

config = %Charts.Config{
  title: "Sales Heatmap: Region × Category",
  theme: :dark_mode
}

{:ok, svg} = Charts.generate(:heatmap, heatmap_data, config)
```

## Related Documentation

- **Planning**: `planning/typst_refactor_plan.md` (Section 3.2)
- **Section 3.1**: `notes/features/stage3_section3.1_elixir_chart_infrastructure.md`
- **Stage 2**: GenStage streaming pipeline documentation
- **Contex Docs**: https://hexdocs.pm/contex
- **Statistics Docs**: https://hexdocs.pm/statistics
- **Timex Docs**: https://hexdocs.pm/timex
- **Ash Query Docs**: https://hexdocs.pm/ash/Ash.Query.html

## Questions for Pascal

1. **AreaChart Implementation**: Contex doesn't natively support area charts. Should we:
   - a) Extend LinePlot with custom SVG fill (medium complexity)
   - b) Build custom area chart from SVG primitives (high complexity)
   - c) Defer to VegaLite integration (future work)
   - d) Mark as "not supported" for now

2. **Statistical Library Choice**: Is `statistics` library acceptable, or prefer:
   - a) statistics (simple, pure Elixir)
   - b) Numerix (more features, uses Flow for parallel)
   - c) statistex (from benchee, optimized for reuse)

3. **Time Bucketing Location**: Should time-series bucketing be:
   - a) In DataExtractor (before aggregation)
   - b) In ProducerConsumer (during streaming aggregation)
   - c) Both (user choice based on dataset size)

4. **Regression Line for ScatterPlot**: Contex PointPlot doesn't support overlay lines. Should we:
   - a) Custom SVG post-processing to add regression line
   - b) Use separate LinePlot overlay (may be complex)
   - c) Calculate regression but skip visual rendering
   - d) Wait for VegaLite integration

5. **Dataset Size Threshold**: 10K records for streaming vs direct query - is this appropriate?
   - Current: <10K = direct, ≥10K = streaming
   - Alternative: Make configurable per chart/report

6. **Pivot Memory Limits**: Large pivots can create huge matrices. Should we:
   - a) Set hard limits (e.g., max 1000x1000 matrix)
   - b) Warn but allow (with memory monitoring)
   - c) Sample/downsample automatically

7. **Heatmap Chart**: Not in original plan, but natural fit for pivot data. Add to scope?
   - Would need custom implementation (Contex doesn't support)
   - Useful for multi-dimensional analysis
   - Can use rectangle-based SVG (relatively simple)
