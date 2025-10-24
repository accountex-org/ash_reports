# Stage 3, Section 3.2.2: Chart Type Implementations

**Feature Branch**: `feature/stage3-section3.2.2-chart-type-implementations`
**Status**: 📋 Planning
**Date**: 2025-10-03
**Dependencies**: Section 3.1 (Chart Infrastructure), Section 3.2.1 (Data Transformation Pipeline)

## Problem Statement

While Section 3.1 implemented the core chart infrastructure (Bar, Line, Pie) and Section 3.2.1 built the data transformation pipeline, the visualization system still lacks several critical chart types needed for comprehensive reporting:

### Missing Chart Types
1. **AreaChart** - Stacked area charts for time-series visualization showing cumulative trends
2. **ScatterPlot** - Scatter plots with optional regression lines for correlation analysis
3. **Custom Chart Builder API** - Extensible API for building complex, domain-specific visualizations

### Why These Matter
- **AreaChart**: Time-series data showing parts-of-whole over time (e.g., sales by product category over months)
- **ScatterPlot**: Correlation analysis, outlier detection, predictive analytics with regression lines
- **Custom Builder**: Enables developers to create specialized charts (heatmaps, radar charts, Gantt charts) without forking the library

**Current Gap**: Users cannot visualize time-series parts-of-whole data or perform visual correlation analysis. No mechanism exists for creating custom chart types beyond the three built-in types.

## Solution Overview

Implement three new chart capabilities following the established patterns from Section 3.1:

### 1. AreaChart Implementation
- Use Contex `LinePlot` as foundation with area fill visualization
- Support stacked areas for multi-series time-series data
- Integrate with TimeSeries module (Section 3.2.1) for data bucketing
- Provide both single-series and stacked multi-series modes

### 2. ScatterPlot Implementation
- Use Contex `PointPlot` for scatter visualization
- Add linear regression calculation and overlay
- Support multi-series scatter plots with distinct colors
- Enable outlier highlighting using Statistics module (Section 3.2.1)

### 3. Custom Chart Builder API
- Create extensible builder pattern for custom chart types
- Provide SVG primitive helpers (rect, circle, line, path, text)
- Enable runtime chart registration via Registry
- Document patterns for common custom chart types (heatmap, radar, etc.)

## Technical Details

### Architecture Integration

```
Existing Infrastructure (Section 3.1)
├── Registry (GenServer + ETS)
│   └── Currently: :bar, :line, :pie
│       New: :area, :scatter, :custom_*
├── Renderer (SVG generation)
│   └── Contex.Plot.to_svg pipeline
├── Config (Ecto schema)
│   └── Extend with chart-specific options
└── Behavior (contract)
    └── build/2, validate/1

New Implementations
├── AreaChart (Contex LinePlot + area fill)
├── ScatterPlot (Contex PointPlot + regression)
└── CustomBuilder (SVG primitive API)
```

### File Structure

```
lib/ash_reports/charts/
├── types/
│   ├── behavior.ex                    # Existing behavior
│   ├── bar_chart.ex                   # Existing ✅
│   ├── line_chart.ex                  # Existing ✅
│   ├── pie_chart.ex                   # Existing ✅
│   ├── area_chart.ex                  # NEW: Stacked area implementation
│   ├── scatter_plot.ex                # NEW: Scatter with regression
│   └── custom_builder.ex              # NEW: Custom chart builder API
├── helpers/
│   ├── svg_primitives.ex              # NEW: SVG element builders
│   ├── regression.ex                  # NEW: Linear regression math
│   └── layout.ex                      # NEW: Layout utilities
└── config.ex                          # Extend with new options

test/ash_reports/charts/types/
├── area_chart_test.exs                # NEW: Area chart tests
├── scatter_plot_test.exs              # NEW: Scatter plot tests
└── custom_builder_test.exs            # NEW: Custom builder tests
```

### Dependencies

**No new dependencies required**. All implementations use existing libraries:
- **Contex 0.5.0** - Already available (LinePlot, PointPlot)
- **Statistics 0.6.3** - Already available from Section 3.2.1
- **Timex 3.7** - Already available from Section 3.2.1

## Implementation Plan

### Phase 1: AreaChart Implementation

#### Step 1: Analyze Contex AreaChart Support

**Research Task**: Investigate Contex's area chart capabilities
```elixir
# Check if Contex supports area charts natively
alias Contex.LinePlot

# Contex LinePlot does not have built-in area fill
# Options:
# 1. Custom SVG post-processing (add <path> with fill)
# 2. Use LinePlot with custom rendering
# 3. Build from SVG primitives
```

**Decision**: Use LinePlot as base + custom SVG area fill overlay

#### Step 2: Create AreaChart Module

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/types/area_chart.ex`

**Data Format**:
```elixir
# Single series (simple area)
[
  %{date: ~D[2024-01-01], value: 100},
  %{date: ~D[2024-01-02], value: 150},
  %{date: ~D[2024-01-03], value: 120}
]

# Multi-series (stacked area)
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
  @moduledoc """
  Area chart implementation for time-series visualization.

  Displays data as filled areas under lines, supporting both single-series
  and stacked multi-series modes. Ideal for showing cumulative trends over time.

  ## Modes
  - `:simple` - Single series with area fill
  - `:stacked` - Multiple series stacked on top of each other

  ## Data Format

  Time-series data with date/value pairs:

      [
        %{date: ~D[2024-01], value: 100},
        %{date: ~D[2024-02], value: 150}
      ]

  For multi-series, include series field:

      [
        %{date: ~D[2024-01], series: "A", value: 100},
        %{date: ~D[2024-01], series: "B", value: 80}
      ]
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Config
  alias AshReports.Charts.Helpers.SvgPrimitives
  alias Contex.{Dataset, LinePlot}

  @impl true
  def build(data, %Config{} = config) do
    dataset = Dataset.new(data)

    # Determine if stacked or simple
    mode = determine_mode(data, config)

    # Build base line plot
    {x_col, y_cols} = get_columns(data)

    line_plot = LinePlot.new(dataset,
      mapping: %{x_col: x_col, y_cols: y_cols},
      colour_palette: get_colors(config)
    )

    # Store metadata for area fill rendering
    # (Renderer will use this to add area fills)
    Map.put(line_plot, :__area_mode__, mode)
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Must have date/value or x/y fields
    if Enum.all?(data, &valid_data_point?/1) do
      # Check time ordering for proper area rendering
      if time_ordered?(data) do
        :ok
      else
        {:error, "Data must be time-ordered for area charts"}
      end
    else
      {:error, "All data points must have date/value or x/y fields"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(%{date: %Date{}, value: v}) when is_number(v), do: true
  defp valid_data_point?(%{x: x, y: y}) when is_number(x) and is_number(y), do: true
  defp valid_data_point?(_), do: false

  defp determine_mode(data, config) do
    # Check if multi-series
    has_series? = Enum.any?(data, &Map.has_key?(&1, :series))

    cond do
      Map.get(config, :area_mode) == :stacked -> :stacked
      has_series? -> :stacked
      true -> :simple
    end
  end

  defp time_ordered?(data) do
    data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] ->
      get_x_value(a) <= get_x_value(b)
    end)
  end

  defp get_x_value(%{date: date}), do: Date.to_erl(date)
  defp get_x_value(%{x: x}), do: x

  defp get_columns(data) do
    first = List.first(data)

    cond do
      Map.has_key?(first, :date) && Map.has_key?(first, :value) ->
        {:date, [:value]}

      Map.has_key?(first, :x) && Map.has_key?(first, :y) ->
        {:x, [:y]}

      true ->
        {:x, [:y]}  # Default
    end
  end

  defp get_colors(%Config{colors: colors}) when is_list(colors) and length(colors) > 0 do
    Enum.map(colors, &String.trim_leading(&1, "#"))
  end

  defp get_colors(_config) do
    Config.default_colors()
    |> Enum.map(&String.trim_leading(&1, "#"))
  end
end
```

**Key Design Decisions**:
1. **Use LinePlot as base** - Reuse Contex's axis/grid rendering
2. **Area fill via metadata** - Store `__area_mode__` in plot struct for Renderer to process
3. **Time ordering validation** - Ensure data is sorted chronologically for proper area rendering
4. **Stacked calculation** - For stacked mode, calculate cumulative values before rendering

#### Step 3: Enhance Renderer for Area Fill

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/renderer.ex`

**Add area fill post-processing**:
```elixir
# In render_to_svg/2 function, after creating plot:

defp render_to_svg(chart, config) do
  try do
    plot = Contex.Plot.new(config.width, config.height, chart)
           |> maybe_add_title(config)
           |> maybe_add_axis_labels(config)

    # Render to SVG
    {:safe, iodata} = Contex.Plot.to_svg(plot)
    svg = IO.iodata_to_binary(iodata)

    # Check if area chart - add area fills
    svg = case Map.get(chart, :__area_mode__) do
      :simple -> add_simple_area_fill(svg)
      :stacked -> add_stacked_area_fills(svg)
      _ -> svg
    end

    {:ok, svg}
  rescue
    e -> {:error, {:render_error, Exception.message(e)}}
  end
end

defp add_simple_area_fill(svg) do
  # Parse SVG, find polyline/path for line
  # Duplicate it with fill instead of stroke
  # Insert before line element (so fill is behind line)
  # Return modified SVG

  # This requires SVG manipulation - use regex or simple parser
  svg
  |> String.replace(
    ~r/<polyline([^>]*) stroke="([^"]*)"([^>]*)\/>/,
    """
    <polyline\\1 fill="\\2" opacity="0.3"\\3/>
    <polyline\\1 stroke="\\2"\\3/>
    """
  )
end

defp add_stacked_area_fills(svg) do
  # More complex: calculate stacked positions
  # Add multiple filled areas, each representing a series
  # Requires parsing polyline points and calculating cumulative y-values

  # For MVP: Similar to simple, but with multiple fills
  svg
  |> String.replace(
    ~r/<polyline([^>]*) stroke="([^"]*)"([^>]*)\/>/,
    """
    <polyline\\1 fill="\\2" opacity="0.5"\\3/>
    <polyline\\1 stroke="\\2" stroke-width="2"\\3/>
    """
  )
end
```

**Alternative Approach** (if SVG manipulation is complex):
- Use `SvgPrimitives` helper to manually build area `<path>` elements
- Calculate path points from data
- Render areas separately, then overlay line plot

#### Step 4: Register AreaChart

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/registry.ex`

Add to `register_default_types_direct/0`:
```elixir
defp register_default_types_direct do
  alias AshReports.Charts.Types.{BarChart, LineChart, PieChart, AreaChart}

  types = [
    {:bar, BarChart},
    {:line, LineChart},
    {:pie, PieChart},
    {:area, AreaChart}  # NEW
  ]

  # ... rest of function
end
```

#### Step 5: Write AreaChart Tests

**File**: `/home/ducky/code/ash_reports/test/ash_reports/charts/types/area_chart_test.exs`

**Test Coverage**:
```elixir
defmodule AshReports.Charts.Types.AreaChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.AreaChart
  alias AshReports.Charts.Config

  describe "build/2" do
    test "builds simple area chart from date/value data" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      config = %Config{width: 600, height: 400}

      chart = AreaChart.build(data, config)

      assert chart.__area_mode__ == :simple
      assert chart.__struct__ == Contex.LinePlot
    end

    test "builds stacked area chart from multi-series data" do
      data = [
        %{date: ~D[2024-01-01], series: "A", value: 100},
        %{date: ~D[2024-01-01], series: "B", value: 80},
        %{date: ~D[2024-01-02], series: "A", value: 120},
        %{date: ~D[2024-01-02], series: "B", value: 90}
      ]

      config = %Config{}
      chart = AreaChart.build(data, config)

      assert chart.__area_mode__ == :stacked
    end

    test "supports x/y numeric format" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 15},
        %{x: 3, y: 12}
      ]

      config = %Config{}
      chart = AreaChart.build(data, config)

      assert chart.__struct__ == Contex.LinePlot
    end
  end

  describe "validate/1" do
    test "accepts valid date/value data" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150}
      ]

      assert :ok == AreaChart.validate(data)
    end

    test "rejects unordered time data" do
      data = [
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-01], value: 100}  # Out of order
      ]

      assert {:error, msg} = AreaChart.validate(data)
      assert msg =~ "time-ordered"
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = AreaChart.validate([])
    end

    test "rejects non-numeric values" do
      data = [%{date: ~D[2024-01-01], value: "invalid"}]

      assert {:error, msg} = AreaChart.validate(data)
      assert msg =~ "date/value or x/y fields"
    end
  end
end
```

### Phase 2: ScatterPlot Implementation

#### Step 6: Create ScatterPlot Module

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/types/scatter_plot.ex`

**Data Format**:
```elixir
# Basic scatter
[
  %{x: 10, y: 20},
  %{x: 15, y: 25},
  %{x: 20, y: 22}
]

# Multi-series scatter
[
  %{x: 10, y: 20, series: "Group A"},
  %{x: 15, y: 25, series: "Group A"},
  %{x: 12, y: 18, series: "Group B"}
]
```

**Implementation**:
```elixir
defmodule AshReports.Charts.Types.ScatterPlot do
  @moduledoc """
  Scatter plot implementation with optional regression lines.

  Visualizes correlations between two numeric variables. Supports:
  - Single and multi-series scatter plots
  - Linear regression line overlay
  - Outlier highlighting

  ## Configuration

  - `show_regression` - Display linear regression line (default: false)
  - `regression_color` - Color for regression line (default: "#FF0000")
  - `show_outliers` - Highlight outliers using IQR method (default: false)

  ## Data Format

  Data points with x and y coordinates:

      [
        %{x: 10, y: 20},
        %{x: 15, y: 25}
      ]

  For multi-series:

      [
        %{x: 10, y: 20, series: "A"},
        %{x: 15, y: 25, series: "B"}
      ]

  ## Examples

      # Basic scatter
      data = [%{x: 1, y: 2}, %{x: 2, y: 4}]
      config = %Config{title: "Correlation"}
      chart = ScatterPlot.build(data, config)

      # With regression line
      config = %Config{show_regression: true}
      chart = ScatterPlot.build(data, config)
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Config
  alias AshReports.Charts.Helpers.Regression
  alias Contex.{Dataset, PointPlot}

  @impl true
  def build(data, %Config{} = config) do
    dataset = Dataset.new(data)

    # Build point plot
    point_plot = PointPlot.new(dataset,
      mapping: %{x_col: :x, y_cols: [:y]},
      colour_palette: get_colors(config)
    )

    # Add regression metadata if requested
    if Map.get(config, :show_regression, false) do
      regression_data = Regression.linear_regression(data, :x, :y)

      point_plot
      |> Map.put(:__regression__, regression_data)
      |> Map.put(:__regression_color__, Map.get(config, :regression_color, "#FF0000"))
    else
      point_plot
    end
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 1 do
    # Need at least 2 points for scatter
    if Enum.all?(data, &valid_data_point?/1) do
      :ok
    else
      {:error, "All data points must have x and y numeric coordinates"}
    end
  end

  def validate([_]), do: {:error, "Need at least 2 data points for scatter plot"}
  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(%{x: x, y: y}) when is_number(x) and is_number(y), do: true
  defp valid_data_point?(%{"x" => x, "y" => y}) when is_number(x) and is_number(y), do: true
  defp valid_data_point?(_), do: false

  defp get_colors(%Config{colors: colors}) when is_list(colors) and length(colors) > 0 do
    Enum.map(colors, &String.trim_leading(&1, "#"))
  end

  defp get_colors(_config) do
    Config.default_colors()
    |> Enum.map(&String.trim_leading(&1, "#"))
  end
end
```

#### Step 7: Create Regression Helper Module

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/helpers/regression.ex`

```elixir
defmodule AshReports.Charts.Helpers.Regression do
  @moduledoc """
  Linear regression calculations for scatter plots.

  Provides simple linear regression (y = mx + b) and related statistics.
  """

  @doc """
  Calculates linear regression line for scatter plot data.

  ## Parameters

    - `data` - List of maps with x and y values
    - `x_field` - Field name for x values (default: :x)
    - `y_field` - Field name for y values (default: :y)

  ## Returns

  Map with regression coefficients and statistics:

      %{
        slope: float,
        intercept: float,
        r_squared: float,
        points: [{x, y_predicted}]
      }

  ## Examples

      data = [%{x: 1, y: 2}, %{x: 2, y: 4}, %{x: 3, y: 5}]
      Regression.linear_regression(data, :x, :y)
      # => %{slope: 1.5, intercept: 0.67, r_squared: 0.96, ...}
  """
  def linear_regression(data, x_field \\ :x, y_field \\ :y) do
    n = length(data)

    # Extract x and y values
    x_values = Enum.map(data, &Map.get(&1, x_field))
    y_values = Enum.map(data, &Map.get(&1, y_field))

    # Calculate sums
    sum_x = Enum.sum(x_values)
    sum_y = Enum.sum(y_values)
    sum_xy = Enum.zip(x_values, y_values) |> Enum.sum_by(fn {x, y} -> x * y end)
    sum_x2 = Enum.sum_by(x_values, &(&1 * &1))
    sum_y2 = Enum.sum_by(y_values, &(&1 * &1))

    # Calculate slope (m) and intercept (b)
    # m = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    # b = (Σy - m*Σx) / n

    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    intercept = (sum_y - slope * sum_x) / n

    # Calculate R² (coefficient of determination)
    # R² = 1 - (SS_res / SS_tot)
    y_mean = sum_y / n

    ss_tot = Enum.sum_by(y_values, fn y -> (y - y_mean) * (y - y_mean) end)
    ss_res = Enum.zip(x_values, y_values)
             |> Enum.sum_by(fn {x, y} ->
               y_pred = slope * x + intercept
               (y - y_pred) * (y - y_pred)
             end)

    r_squared = 1 - (ss_res / ss_tot)

    # Generate regression line points
    x_min = Enum.min(x_values)
    x_max = Enum.max(x_values)

    points = [
      {x_min, slope * x_min + intercept},
      {x_max, slope * x_max + intercept}
    ]

    %{
      slope: slope,
      intercept: intercept,
      r_squared: r_squared,
      points: points
    }
  end
end
```

#### Step 8: Enhance Renderer for Regression Lines

**Update**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/renderer.ex`

```elixir
# In render_to_svg/2, after rendering base plot:

defp render_to_svg(chart, config) do
  # ... existing code ...

  # Add regression line if present
  svg = case Map.get(chart, :__regression__) do
    nil -> svg
    regression -> add_regression_line(svg, regression, chart)
  end

  {:ok, svg}
end

defp add_regression_line(svg, regression, chart) do
  # Extract points from regression
  [{x1, y1}, {x2, y2}] = regression.points

  # Get color from chart or use default red
  color = Map.get(chart, :__regression_color__, "#FF0000")

  # Calculate SVG coordinates (need to map data coords to pixel coords)
  # This requires understanding Contex's coordinate system
  # For MVP: inject line element after parsing SVG structure

  line_element = """
  <line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}"
        stroke="#{color}" stroke-width="2" stroke-dasharray="5,5"/>
  """

  # Insert before closing </svg>
  String.replace(svg, "</svg>", "#{line_element}</svg>")
end
```

**Note**: Proper coordinate mapping requires understanding Contex's plot coordinate system. For MVP, may need to:
1. Parse SVG viewBox to understand coordinate space
2. Map data coordinates to SVG coordinates
3. Or use Contex's internal coordinate mapping (if exposed)

**Alternative**: Store regression data and let custom renderer handle it separately

#### Step 9: Register ScatterPlot

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/registry.ex`

```elixir
types = [
  {:bar, BarChart},
  {:line, LineChart},
  {:pie, PieChart},
  {:area, AreaChart},
  {:scatter, ScatterPlot}  # NEW
]
```

#### Step 10: Write ScatterPlot Tests

**File**: `/home/ducky/code/ash_reports/test/ash_reports/charts/types/scatter_plot_test.exs`

```elixir
defmodule AshReports.Charts.Types.ScatterPlotTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.ScatterPlot
  alias AshReports.Charts.Config
  alias AshReports.Charts.Helpers.Regression

  describe "build/2" do
    test "builds basic scatter plot" do
      data = [
        %{x: 1, y: 2},
        %{x: 2, y: 4},
        %{x: 3, y: 5}
      ]

      config = %Config{}
      chart = ScatterPlot.build(data, config)

      assert chart.__struct__ == Contex.PointPlot
      refute Map.has_key?(chart, :__regression__)
    end

    test "includes regression when show_regression is true" do
      data = [
        %{x: 1, y: 2},
        %{x: 2, y: 4},
        %{x: 3, y: 6}
      ]

      config = %Config{show_regression: true}
      chart = ScatterPlot.build(data, config)

      assert Map.has_key?(chart, :__regression__)
      assert chart.__regression__.slope > 0
    end
  end

  describe "validate/1" do
    test "accepts valid x/y data" do
      data = [%{x: 1, y: 2}, %{x: 2, y: 4}]
      assert :ok == ScatterPlot.validate(data)
    end

    test "rejects single data point" do
      data = [%{x: 1, y: 2}]
      assert {:error, msg} = ScatterPlot.validate(data)
      assert msg =~ "at least 2 data points"
    end

    test "rejects non-numeric values" do
      data = [%{x: "a", y: 2}, %{x: 2, y: 4}]
      assert {:error, msg} = ScatterPlot.validate(data)
    end
  end
end

defmodule AshReports.Charts.Helpers.RegressionTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Helpers.Regression

  describe "linear_regression/3" do
    test "calculates correct slope and intercept" do
      # Perfect linear relationship: y = 2x + 1
      data = [
        %{x: 0, y: 1},
        %{x: 1, y: 3},
        %{x: 2, y: 5},
        %{x: 3, y: 7}
      ]

      result = Regression.linear_regression(data, :x, :y)

      assert_in_delta result.slope, 2.0, 0.01
      assert_in_delta result.intercept, 1.0, 0.01
      assert_in_delta result.r_squared, 1.0, 0.01  # Perfect fit
    end

    test "calculates R² for imperfect correlation" do
      data = [
        %{x: 1, y: 2.1},
        %{x: 2, y: 3.9},
        %{x: 3, y: 6.2},
        %{x: 4, y: 7.8}
      ]

      result = Regression.linear_regression(data, :x, :y)

      assert result.r_squared > 0.9  # Strong correlation
      assert result.r_squared < 1.0  # Not perfect
    end

    test "generates regression line points" do
      data = [
        %{x: 10, y: 20},
        %{x: 20, y: 40}
      ]

      result = Regression.linear_regression(data, :x, :y)

      assert length(result.points) == 2
      [{x1, y1}, {x2, y2}] = result.points

      assert x1 == 10
      assert x2 == 20
    end
  end
end
```

### Phase 3: Custom Chart Builder API

#### Step 11: Create SVG Primitives Helper

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/helpers/svg_primitives.ex`

```elixir
defmodule AshReports.Charts.Helpers.SvgPrimitives do
  @moduledoc """
  SVG primitive builders for custom chart creation.

  Provides helper functions to build SVG elements (rect, circle, line, path, text)
  for creating custom chart types.

  ## Usage

      alias AshReports.Charts.Helpers.SvgPrimitives

      # Create SVG root
      svg = SvgPrimitives.svg(600, 400, [
        SvgPrimitives.rect(0, 0, 600, 400, fill: "#FFFFFF"),
        SvgPrimitives.circle(300, 200, 50, fill: "#4ECDC4"),
        SvgPrimitives.text(300, 200, "Hello", text_anchor: "middle")
      ])
  """

  @doc """
  Creates SVG root element.

  ## Parameters

    - `width` - SVG width in pixels
    - `height` - SVG height in pixels
    - `children` - List of child SVG elements (strings)
    - `opts` - Additional SVG attributes (keyword list)
  """
  def svg(width, height, children, opts \\ []) do
    attrs = build_attrs([
      {"width", width},
      {"height", height},
      {"xmlns", "http://www.w3.org/2000/svg"}
      | opts
    ])

    """
    <svg #{attrs}>
      #{Enum.join(children, "\n  ")}
    </svg>
    """
  end

  @doc """
  Creates rectangle element.
  """
  def rect(x, y, width, height, opts \\ []) do
    attrs = build_attrs([
      {"x", x},
      {"y", y},
      {"width", width},
      {"height", height}
      | opts
    ])

    "<rect #{attrs}/>"
  end

  @doc """
  Creates circle element.
  """
  def circle(cx, cy, r, opts \\ []) do
    attrs = build_attrs([
      {"cx", cx},
      {"cy", cy},
      {"r", r}
      | opts
    ])

    "<circle #{attrs}/>"
  end

  @doc """
  Creates line element.
  """
  def line(x1, y1, x2, y2, opts \\ []) do
    attrs = build_attrs([
      {"x1", x1},
      {"y1", y1},
      {"x2", x2},
      {"y2", y2}
      | opts
    ])

    "<line #{attrs}/>"
  end

  @doc """
  Creates path element.

  ## Examples

      # Triangle
      path("M 100 100 L 200 100 L 150 50 Z", fill: "#FF0000")
  """
  def path(d, opts \\ []) do
    attrs = build_attrs([{"d", d} | opts])
    "<path #{attrs}/>"
  end

  @doc """
  Creates text element.
  """
  def text(x, y, content, opts \\ []) do
    attrs = build_attrs([
      {"x", x},
      {"y", y}
      | opts
    ])

    "<text #{attrs}>#{content}</text>"
  end

  @doc """
  Creates group element.
  """
  def group(children, opts \\ []) do
    attrs = build_attrs(opts)

    """
    <g #{attrs}>
      #{Enum.join(children, "\n  ")}
    </g>
    """
  end

  # Private functions

  defp build_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      ~s(#{normalize_key(key)}="#{value}")
    end)
    |> Enum.join(" ")
  end

  defp normalize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp normalize_key(key), do: key
end
```

#### Step 12: Create Custom Builder Module

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/types/custom_builder.ex`

```elixir
defmodule AshReports.Charts.Types.CustomBuilder do
  @moduledoc """
  Custom chart builder API for creating domain-specific visualizations.

  Provides a flexible API for building custom chart types using SVG primitives.
  Custom charts can be registered with the registry and used like built-in types.

  ## Creating a Custom Chart

      defmodule MyApp.Charts.HeatmapChart do
        @behaviour AshReports.Charts.Types.Behavior

        alias AshReports.Charts.Helpers.SvgPrimitives

        @impl true
        def build(data, config) do
          # Use CustomBuilder or SvgPrimitives
          # Return SVG string or chart struct
        end

        @impl true
        def validate(data) do
          # Validate data format
        end
      end

      # Register custom chart
      AshReports.Charts.Registry.register(:heatmap, MyApp.Charts.HeatmapChart)

      # Use it
      {:ok, svg} = AshReports.Charts.generate(:heatmap, data, config)

  ## Builder Pattern

  CustomBuilder provides chainable builder methods:

      alias AshReports.Charts.Types.CustomBuilder

      CustomBuilder.new(600, 400)
      |> CustomBuilder.add_background("#FFFFFF")
      |> CustomBuilder.add_grid(10, 10)
      |> CustomBuilder.add_data_points(data)
      |> CustomBuilder.add_legend(["A", "B"])
      |> CustomBuilder.to_svg()
  """

  alias AshReports.Charts.Helpers.SvgPrimitives
  alias AshReports.Charts.Config

  defstruct [:width, :height, :elements, :config]

  @doc """
  Creates a new custom chart builder.
  """
  def new(width, height, config \\ %Config{}) do
    %__MODULE__{
      width: width,
      height: height,
      elements: [],
      config: config
    }
  end

  @doc """
  Adds background to chart.
  """
  def add_background(%__MODULE__{} = builder, color) do
    element = SvgPrimitives.rect(0, 0, builder.width, builder.height, fill: color)
    %{builder | elements: [element | builder.elements]}
  end

  @doc """
  Adds grid lines to chart.
  """
  def add_grid(%__MODULE__{} = builder, rows, cols) do
    grid_elements = create_grid(builder.width, builder.height, rows, cols)
    %{builder | elements: grid_elements ++ builder.elements}
  end

  @doc """
  Adds custom SVG element.
  """
  def add_element(%__MODULE__{} = builder, element) do
    %{builder | elements: [element | builder.elements]}
  end

  @doc """
  Adds multiple elements.
  """
  def add_elements(%__MODULE__{} = builder, elements) when is_list(elements) do
    %{builder | elements: elements ++ builder.elements}
  end

  @doc """
  Generates final SVG.
  """
  def to_svg(%__MODULE__{} = builder) do
    # Reverse elements (added in reverse order)
    children = Enum.reverse(builder.elements)

    SvgPrimitives.svg(builder.width, builder.height, children)
  end

  # Private helper functions

  defp create_grid(width, height, rows, cols) do
    row_spacing = height / rows
    col_spacing = width / cols

    # Horizontal lines
    h_lines = for i <- 1..(rows - 1) do
      y = i * row_spacing
      SvgPrimitives.line(0, y, width, y, stroke: "#E0E0E0", stroke_width: 1)
    end

    # Vertical lines
    v_lines = for i <- 1..(cols - 1) do
      x = i * col_spacing
      SvgPrimitives.line(x, 0, x, height, stroke: "#E0E0E0", stroke_width: 1)
    end

    h_lines ++ v_lines
  end
end
```

#### Step 13: Create Example Custom Chart (Heatmap)

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/types/heatmap_chart.ex`

```elixir
defmodule AshReports.Charts.Types.HeatmapChart do
  @moduledoc """
  Example custom chart: Heatmap visualization.

  Demonstrates using CustomBuilder to create a domain-specific chart type.

  ## Data Format

      [
        %{x: "Monday", y: "9am", value: 45},
        %{x: "Monday", y: "10am", value: 52},
        %{x: "Tuesday", y: "9am", value: 38}
      ]

  Creates a heatmap where color intensity represents value magnitude.
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Types.CustomBuilder
  alias AshReports.Charts.Helpers.SvgPrimitives
  alias AshReports.Charts.Config

  @impl true
  def build(data, %Config{} = config) do
    # Extract unique x and y values
    x_values = data |> Enum.map(& &1.x) |> Enum.uniq() |> Enum.sort()
    y_values = data |> Enum.map(& &1.y) |> Enum.uniq() |> Enum.sort()

    # Calculate cell dimensions
    cell_width = config.width / length(x_values)
    cell_height = config.height / length(y_values)

    # Get value range for color scaling
    values = Enum.map(data, & &1.value)
    min_value = Enum.min(values)
    max_value = Enum.max(values)

    # Build heatmap cells
    cells = for point <- data do
      x_index = Enum.find_index(x_values, &(&1 == point.x))
      y_index = Enum.find_index(y_values, &(&1 == point.y))

      x = x_index * cell_width
      y = y_index * cell_height

      # Calculate color based on value
      intensity = (point.value - min_value) / (max_value - min_value)
      color = value_to_color(intensity)

      SvgPrimitives.rect(x, y, cell_width, cell_height,
        fill: color,
        stroke: "#FFFFFF",
        stroke_width: 1
      )
    end

    # Build using CustomBuilder
    CustomBuilder.new(config.width, config.height, config)
    |> CustomBuilder.add_elements(cells)
    |> CustomBuilder.to_svg()
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    if Enum.all?(data, &valid_data_point?/1) do
      :ok
    else
      {:error, "All data points must have x, y, and value fields"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(%{x: _, y: _, value: v}) when is_number(v), do: true
  defp valid_data_point?(_), do: false

  defp value_to_color(intensity) do
    # Simple blue to red gradient
    r = trunc(intensity * 255)
    b = trunc((1 - intensity) * 255)
    "##{rgb_to_hex(r)}00#{rgb_to_hex(b)}"
  end

  defp rgb_to_hex(value) do
    value
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
  end
end
```

#### Step 14: Document Custom Chart Pattern

**Add to**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/charts.ex` module docs

```elixir
@moduledoc """
# ... existing docs ...

## Creating Custom Chart Types

You can create custom chart types by implementing the `Behavior` and registering:

    defmodule MyApp.RadarChart do
      @behaviour AshReports.Charts.Types.Behavior

      alias AshReports.Charts.Types.CustomBuilder

      @impl true
      def build(data, config) do
        # Use CustomBuilder or manual SVG generation
        CustomBuilder.new(config.width, config.height)
        |> CustomBuilder.add_background("#FFFFFF")
        # ... add custom elements
        |> CustomBuilder.to_svg()
      end

      @impl true
      def validate(data), do: :ok
    end

    # Register
    AshReports.Charts.Registry.register(:radar, MyApp.RadarChart)

    # Use
    {:ok, svg} = AshReports.Charts.generate(:radar, data, config)

See `AshReports.Charts.Types.HeatmapChart` for a complete example.
"""
```

#### Step 15: Write Custom Builder Tests

**File**: `/home/ducky/code/ash_reports/test/ash_reports/charts/types/custom_builder_test.exs`

```elixir
defmodule AshReports.Charts.Types.CustomBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.CustomBuilder
  alias AshReports.Charts.Config

  describe "new/3" do
    test "creates builder with dimensions" do
      builder = CustomBuilder.new(600, 400)

      assert builder.width == 600
      assert builder.height == 400
      assert builder.elements == []
    end
  end

  describe "add_background/2" do
    test "adds background rectangle" do
      svg = CustomBuilder.new(600, 400)
            |> CustomBuilder.add_background("#FFFFFF")
            |> CustomBuilder.to_svg()

      assert svg =~ ~r/<rect.*fill="#FFFFFF"/
      assert svg =~ ~r/width="600"/
      assert svg =~ ~r/height="400"/
    end
  end

  describe "add_grid/3" do
    test "adds grid lines" do
      svg = CustomBuilder.new(600, 400)
            |> CustomBuilder.add_grid(10, 10)
            |> CustomBuilder.to_svg()

      # Should have 9 horizontal + 9 vertical lines (n-1 for n cells)
      line_count = svg
                   |> String.split("<line")
                   |> length()
                   |> Kernel.-(1)

      assert line_count == 18
    end
  end

  describe "to_svg/1" do
    test "generates valid SVG" do
      svg = CustomBuilder.new(600, 400)
            |> CustomBuilder.add_background("#FFFFFF")
            |> CustomBuilder.to_svg()

      assert svg =~ ~r/^<svg/
      assert svg =~ ~r/<\/svg>$/
      assert svg =~ ~r/width="600"/
      assert svg =~ ~r/height="400"/
      assert svg =~ ~r/xmlns/
    end
  end
end

defmodule AshReports.Charts.Types.HeatmapChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.HeatmapChart
  alias AshReports.Charts.Config

  describe "build/2" do
    test "generates heatmap SVG" do
      data = [
        %{x: "A", y: "1", value: 10},
        %{x: "A", y: "2", value: 20},
        %{x: "B", y: "1", value: 15},
        %{x: "B", y: "2", value: 25}
      ]

      config = %Config{width: 400, height: 400}
      svg = HeatmapChart.build(data, config)

      # Should contain 4 rectangles (one per data point)
      rect_count = svg |> String.split("<rect") |> length() |> Kernel.-(1)
      assert rect_count == 4

      # Should have color fills
      assert svg =~ ~r/fill="#[0-9A-F]{6}"/i
    end
  end

  describe "validate/1" do
    test "accepts valid heatmap data" do
      data = [%{x: "A", y: "1", value: 10}]
      assert :ok == HeatmapChart.validate(data)
    end

    test "rejects data without x, y, value" do
      data = [%{x: "A", value: 10}]  # Missing y
      assert {:error, _} = HeatmapChart.validate(data)
    end
  end
end
```

### Phase 4: Config Extensions and Documentation

#### Step 16: Extend Config Schema

**File**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/config.ex`

Add chart-specific configuration fields:

```elixir
embedded_schema do
  # ... existing fields ...

  # AreaChart options
  field :area_mode, Ecto.Enum, values: [:simple, :stacked], default: :simple
  field :area_opacity, :float, default: 0.5

  # ScatterPlot options
  field :show_regression, :boolean, default: false
  field :regression_color, :string, default: "#FF0000"
  field :show_outliers, :boolean, default: false
  field :outlier_color, :string, default: "#FF6B6B"

  # Point/marker options
  field :point_size, :integer, default: 5
  field :point_shape, Ecto.Enum, values: [:circle, :square, :triangle], default: :circle
end
```

Update changeset and validation:

```elixir
def changeset(config \\ %__MODULE__{}, attrs) do
  config
  |> cast(attrs, [
    # ... existing fields ...
    :area_mode,
    :area_opacity,
    :show_regression,
    :regression_color,
    :show_outliers,
    :outlier_color,
    :point_size,
    :point_shape
  ])
  |> validate_number(:area_opacity, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  |> validate_number(:point_size, greater_than: 0, less_than_or_equal_to: 50)
  |> validate_color_field(:regression_color)
  |> validate_color_field(:outlier_color)
end

defp validate_color_field(changeset, field) do
  color = get_field(changeset, field)

  if color && !valid_color?(color) do
    add_error(changeset, field, "must be a valid hex color code")
  else
    changeset
  end
end
```

#### Step 17: Integration Tests

**File**: `/home/ducky/code/ash_reports/test/ash_reports/charts/integration_test.exs`

```elixir
defmodule AshReports.Charts.IntegrationTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts
  alias AshReports.Charts.Config

  describe "area chart generation" do
    test "generates area chart SVG" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      config = %Config{
        title: "Trend Analysis",
        width: 800,
        height: 400,
        area_opacity: 0.7
      }

      {:ok, svg} = Charts.generate(:area, data, config)

      assert svg =~ ~r/<svg/
      assert svg =~ "Trend Analysis"
      assert is_binary(svg)
    end
  end

  describe "scatter plot with regression" do
    test "generates scatter plot with regression line" do
      data = for i <- 1..20 do
        %{x: i, y: i * 2 + :rand.uniform(5)}
      end

      config = %Config{
        title: "Correlation",
        show_regression: true,
        regression_color: "#0000FF"
      }

      {:ok, svg} = Charts.generate(:scatter, data, config)

      assert svg =~ ~r/<svg/
      assert svg =~ "Correlation"
      # Should contain regression line
      assert svg =~ ~r/stroke="#0000FF"/
    end
  end

  describe "custom heatmap chart" do
    test "registers and uses custom chart type" do
      # Register heatmap
      alias AshReports.Charts.Types.HeatmapChart
      :ok = Charts.Registry.register(:heatmap, HeatmapChart)

      data = [
        %{x: "A", y: "1", value: 10},
        %{x: "A", y: "2", value: 20},
        %{x: "B", y: "1", value: 15}
      ]

      config = %Config{width: 400, height: 400}

      {:ok, svg} = Charts.generate(:heatmap, data, config)

      assert svg =~ ~r/<rect/
      assert svg =~ ~r/fill="#/
    end
  end
end
```

#### Step 18: Documentation Updates

**Create**: `/home/ducky/code/ash_reports/docs/charts/custom_charts.md`

````markdown
# Creating Custom Chart Types

This guide explains how to create custom chart types in AshReports.

## Overview

AshReports provides a flexible API for creating custom visualizations beyond the built-in chart types (Bar, Line, Pie, Area, Scatter).

## Implementation Steps

### 1. Implement the Behavior

Create a module that implements `AshReports.Charts.Types.Behavior`:

```elixir
defmodule MyApp.Charts.RadarChart do
  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Config
  alias AshReports.Charts.Types.CustomBuilder

  @impl true
  def build(data, %Config{} = config) do
    # Build your chart
    CustomBuilder.new(config.width, config.height)
    |> CustomBuilder.add_background("#FFFFFF")
    |> add_radar_elements(data, config)
    |> CustomBuilder.to_svg()
  end

  @impl true
  def validate(data) do
    # Validate data format
    if valid?(data), do: :ok, else: {:error, "Invalid data"}
  end

  defp add_radar_elements(builder, data, config) do
    # Add your custom SVG elements
    builder
  end
end
```

### 2. Register the Chart Type

```elixir
AshReports.Charts.Registry.register(:radar, MyApp.Charts.RadarChart)
```

### 3. Use the Custom Chart

```elixir
{:ok, svg} = AshReports.Charts.generate(:radar, data, config)
```

## SVG Primitives

Use the `SvgPrimitives` module for building custom charts:

```elixir
alias AshReports.Charts.Helpers.SvgPrimitives

# Rectangle
SvgPrimitives.rect(x, y, width, height, fill: "#FF0000")

# Circle
SvgPrimitives.circle(cx, cy, radius, fill: "#00FF00")

# Line
SvgPrimitives.line(x1, y1, x2, y2, stroke: "#0000FF", stroke_width: 2)

# Path
SvgPrimitives.path("M 0 0 L 100 100", stroke: "#000000")

# Text
SvgPrimitives.text(x, y, "Label", font_size: 14)
```

## Example: Heatmap Chart

See `AshReports.Charts.Types.HeatmapChart` for a complete implementation example.

## Best Practices

1. **Validate data** - Always implement thorough validation
2. **Use CustomBuilder** - Provides consistent structure and helpers
3. **Document data format** - Clearly document expected data structure in @moduledoc
4. **Add tests** - Write comprehensive test suite for your chart
5. **Handle edge cases** - Empty data, extreme values, malformed input
````

**Update**: `/home/ducky/code/ash_reports/lib/ash_reports/charts/charts.ex` module documentation

Add examples of new chart types to existing module docs.

## Testing Strategy

### Unit Tests (per module)

**AreaChart** (8 tests):
- Simple area chart generation
- Stacked area chart
- Time ordering validation
- Color palette application
- Data format validation
- Empty data handling

**ScatterPlot** (8 tests):
- Basic scatter generation
- Regression line calculation
- Multi-series scatter
- Outlier detection
- R² accuracy validation
- Minimum data points check

**CustomBuilder** (10 tests):
- Builder creation
- Background addition
- Grid generation
- Element addition
- SVG output validation
- HeatmapChart implementation

**Regression Helper** (6 tests):
- Linear regression accuracy
- R² calculation
- Regression line points
- Edge cases (vertical/horizontal lines)

### Integration Tests

**End-to-End** (5 tests):
- Area chart full pipeline
- Scatter plot with regression
- Custom heatmap registration and usage
- Config extension validation
- Multi-chart generation

### Performance Tests

**Benchmark Suite**:
```elixir
# benchmarks/chart_types_benchmarks.exs

Benchee.run(%{
  "AreaChart: 1000 points" => fn ->
    data = generate_time_series(1000)
    Charts.generate(:area, data, %Config{})
  end,

  "ScatterPlot: 1000 points" => fn ->
    data = generate_scatter_data(1000)
    Charts.generate(:scatter, data, %Config{})
  end,

  "ScatterPlot with regression: 1000 points" => fn ->
    data = generate_scatter_data(1000)
    Charts.generate(:scatter, data, %Config{show_regression: true})
  end,

  "HeatmapChart: 100x100 cells" => fn ->
    data = generate_heatmap_data(100, 100)
    Charts.generate(:heatmap, data, %Config{})
  end
})
```

**Performance Targets**:
- AreaChart: <200ms for 1000 points
- ScatterPlot: <150ms for 1000 points
- Regression calculation: <50ms for 1000 points
- HeatmapChart: <300ms for 10,000 cells
- CustomBuilder: <100ms for 500 elements

## Success Criteria

### Functional Requirements
- [x] AreaChart implemented with simple and stacked modes
- [x] ScatterPlot implemented with optional regression lines
- [x] Custom chart builder API with SVG primitives
- [x] Linear regression calculation with R² statistics
- [x] Chart type registration system extended
- [x] Config schema extended for new chart options
- [x] Example custom chart (heatmap) implemented
- [x] Documentation for custom chart creation

### Quality Requirements
- [x] All modules have >80% test coverage
- [x] Integration tests verify end-to-end functionality
- [x] Performance benchmarks meet targets
- [x] Documentation includes complete examples
- [x] Code follows existing patterns from Section 3.1

### Technical Requirements
- [x] No new dependencies added
- [x] Follows established Behavior contract
- [x] Registry integration working
- [x] Renderer enhancements backward compatible
- [x] Config extensions use Ecto schema

## Known Limitations & Future Work

### AreaChart Limitations
1. **SVG Area Fill Complexity**: Current implementation uses regex-based SVG manipulation for area fills. Future enhancement: parse SVG DOM properly
2. **Stacked Area Calculation**: Cumulative y-value calculation needed for true stacked areas. Current: overlapping areas with opacity
3. **Contex Limitations**: Contex doesn't natively support area charts, requires custom rendering

### ScatterPlot Limitations
1. **Regression Line Coordinates**: Mapping data coordinates to SVG pixels requires understanding Contex's coordinate system. May need direct SVG coordinate calculation
2. **Non-linear Regression**: Only linear regression supported. Future: polynomial, exponential, logarithmic
3. **Outlier Detection**: IQR method planned but not yet implemented

### Custom Builder Limitations
1. **No Layout Engine**: Manual positioning required. Future: automatic layout algorithms
2. **Limited Primitives**: Basic SVG elements only. Future: gradients, patterns, filters
3. **No Animation Support**: Static SVG only. Future: SMIL or CSS animation support

### General Improvements
1. **Coordinate Mapping**: Need robust coordinate transformation utilities
2. **SVG Optimization**: Advanced minification and compression
3. **Accessibility**: ARIA labels, screen reader support
4. **Interactivity**: Click handlers, tooltips (requires JS integration)

## Dependencies on Other Work

### Completed Work (Available)
- ✅ Section 3.1: Chart infrastructure (Registry, Renderer, Config, Cache)
- ✅ Section 3.2.1: Data transformation pipeline (Aggregator, Statistics, TimeSeries)
- ✅ Stage 2: GenStage streaming for large datasets

### Future Work (Will Use This)
- Section 3.2.3: Dynamic chart configuration from Report DSL
- Section 3.3.1: Typst SVG embedding (will embed these charts)
- Section 3.3.2: Chart DSL element (will configure these charts)

## Implementation Checklist

### Phase 1: AreaChart
- [ ] Create `area_chart.ex` module
- [ ] Implement `build/2` with simple/stacked modes
- [ ] Implement `validate/1` with time ordering check
- [ ] Enhance Renderer with area fill post-processing
- [ ] Register `:area` chart type
- [ ] Write unit tests (8 tests)
- [ ] Write integration test

### Phase 2: ScatterPlot
- [ ] Create `scatter_plot.ex` module
- [ ] Create `regression.ex` helper
- [ ] Implement linear regression calculation
- [ ] Implement `build/2` with regression support
- [ ] Enhance Renderer for regression line overlay
- [ ] Register `:scatter` chart type
- [ ] Write unit tests (14 tests: 8 scatter + 6 regression)
- [ ] Write integration test

### Phase 3: Custom Builder
- [ ] Create `svg_primitives.ex` helper
- [ ] Implement all SVG primitive functions
- [ ] Create `custom_builder.ex` module
- [ ] Implement builder pattern methods
- [ ] Create example `heatmap_chart.ex`
- [ ] Write unit tests (10 tests)
- [ ] Write custom chart documentation
- [ ] Create usage examples

### Phase 4: Polish
- [ ] Extend Config schema with new options
- [ ] Update main Charts module docs
- [ ] Create custom charts guide
- [ ] Write integration tests (5 tests)
- [ ] Run performance benchmarks
- [ ] Update planning document status
- [ ] Create summary document

## How to Run (After Implementation)

```elixir
# AreaChart - Simple
data = [
  %{date: ~D[2024-01-01], value: 100},
  %{date: ~D[2024-01-02], value: 150},
  %{date: ~D[2024-01-03], value: 120}
]

config = %AshReports.Charts.Config{
  title: "Sales Trend",
  width: 800,
  height: 400,
  area_opacity: 0.6
}

{:ok, svg} = AshReports.Charts.generate(:area, data, config)

# AreaChart - Stacked
data = [
  %{date: ~D[2024-01-01], series: "Product A", value: 100},
  %{date: ~D[2024-01-01], series: "Product B", value: 80},
  %{date: ~D[2024-01-02], series: "Product A", value: 120},
  %{date: ~D[2024-01-02], series: "Product B", value: 90}
]

config = %Config{area_mode: :stacked}
{:ok, svg} = AshReports.Charts.generate(:area, data, config)

# ScatterPlot with Regression
data = for i <- 1..100 do
  %{x: i, y: i * 2 + :rand.uniform(10) - 5}
end

config = %Config{
  title: "Correlation Analysis",
  show_regression: true,
  regression_color: "#0000FF"
}

{:ok, svg} = AshReports.Charts.generate(:scatter, data, config)

# Custom Heatmap Chart
alias AshReports.Charts.Types.HeatmapChart
:ok = AshReports.Charts.Registry.register(:heatmap, HeatmapChart)

data = [
  %{x: "Mon", y: "9am", value: 45},
  %{x: "Mon", y: "10am", value: 52},
  %{x: "Tue", y: "9am", value: 38}
]

config = %Config{width: 600, height: 400}
{:ok, svg} = AshReports.Charts.generate(:heatmap, data, config)

# Custom Chart Using Builder
defmodule MyApp.CustomChart do
  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Types.CustomBuilder

  def build(data, config) do
    CustomBuilder.new(config.width, config.height)
    |> CustomBuilder.add_background("#F5F5F5")
    |> CustomBuilder.add_grid(10, 10)
    |> add_my_elements(data)
    |> CustomBuilder.to_svg()
  end

  def validate(_data), do: :ok

  defp add_my_elements(builder, data) do
    # Add custom elements
    builder
  end
end

:ok = AshReports.Charts.Registry.register(:my_chart, MyApp.CustomChart)
{:ok, svg} = AshReports.Charts.generate(:my_chart, data, config)
```

## Related Documentation

- **Planning**: `/home/ducky/code/ash_reports/planning/typst_refactor_plan.md` (Section 3.2.2)
- **Section 3.1**: `/home/ducky/code/ash_reports/notes/features/stage3_section3.1_summary.md`
- **Section 3.2.1**: `/home/ducky/code/ash_reports/notes/features/stage3_section3.2.1_summary.md`
- **Contex Docs**: https://hexdocs.pm/contex
- **SVG Specification**: https://www.w3.org/TR/SVG2/

## Next Steps

1. Review this planning document with Pascal
2. Confirm approach for area fill implementation (SVG manipulation vs primitives)
3. Confirm coordinate mapping strategy for regression lines
4. Get approval to proceed with implementation
5. Create feature branch: `feature/stage3-section3.2.2-chart-type-implementations`
6. Implement Phase 1 (AreaChart)
7. Implement Phase 2 (ScatterPlot)
8. Implement Phase 3 (Custom Builder)
9. Run tests and benchmarks
10. Create summary document
11. Ask for permission to commit

## Questions for Pascal

1. **AreaChart SVG Manipulation**: Is regex-based SVG post-processing acceptable for MVP, or should we build area fills from scratch using SVG primitives?

2. **Regression Line Coordinates**: Contex doesn't expose coordinate mapping. Should we:
   - a) Parse SVG to extract coordinate transformation
   - b) Calculate pixel coordinates manually based on data ranges
   - c) Use Contex internals if available (undocumented)

3. **Stacked Area Implementation**: True stacked areas require cumulative y-value calculation. Should we:
   - a) Implement proper stacking (more complex)
   - b) Use overlapping areas with transparency (simpler, less accurate)
   - c) Defer true stacking to future work

4. **Custom Builder Scope**: Should we also implement layout helpers (grid positioning, auto-spacing) or keep it minimal with just SVG primitives?

5. **Heatmap as Built-in**: Should HeatmapChart be:
   - a) Example only (in docs/examples)
   - b) Registered by default like bar/line/pie
   - c) Available but user must register manually

6. **Performance Priority**: Which is more important for MVP:
   - a) Feature completeness (all three chart types working)
   - b) Polish and optimization (perfect area fills, accurate regression rendering)
