defmodule AshReports.Charts.Types.AreaChart do
  @moduledoc """
  Area chart implementation using Contex LinePlot with area fill.

  Supports simple and stacked area charts for time-series data visualization,
  showing how values change over time with filled areas below the lines.

  ## Data Format

  Data should be a list of maps with x and y coordinates:

      [
        %{x: 1, y: 10},
        %{x: 2, y: 15},
        %{x: 3, y: 12}
      ]

  For time-series data:

      [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

  For stacked areas (multiple series):

      [
        %{x: 1, series: "Product A", y: 10},
        %{x: 1, series: "Product B", y: 15},
        %{x: 2, series: "Product A", y: 12},
        %{x: 2, series: "Product B", y: 18}
      ]

  ## Configuration

  Standard chart configuration plus:
  - `mode` - `:simple` (default) or `:stacked`
  - `opacity` - Fill opacity from 0.0 to 1.0 (default: 0.7)
  - `smooth_lines` - Whether to use smooth curves (default: true)

  ## Examples

      # Simple area chart
      data = [%{x: 1, y: 10}, %{x: 2, y: 20}, %{x: 3, y: 15}]
      config = %Config{title: "Trend Over Time"}
      {:ok, svg} = Charts.generate(:area, data, config)

      # Stacked area chart
      data = [
        %{x: 1, series: "Product A", y: 10},
        %{x: 1, series: "Product B", y: 5},
        %{x: 2, series: "Product A", y: 15},
        %{x: 2, series: "Product B", y: 8}
      ]
      config = %Config{mode: :stacked, opacity: 0.6}
      {:ok, svg} = Charts.generate(:area, data, config)

  ## Area Fill Strategy

  Area charts are implemented by:
  1. Using Contex LinePlot to generate base line chart SVG
  2. Post-processing the SVG to add `<path>` elements with area fills
  3. Applying opacity and stacking logic as needed

  **Note**: Stacked mode uses opacity overlays rather than true cumulative
  stacking. For true cumulative stacking, pre-process data with
  `AshReports.Charts.TimeSeries.bucket/4` or custom aggregation.
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.AreaChartConfig
  alias Contex.{Dataset, LinePlot}

  @impl true
  def build(data, %AreaChartConfig{} = config) do
    do_build(data, config)
  end

  def build(data, config) when is_map(config) do
    struct_keys = Map.keys(%AreaChartConfig{})
    filtered_config = Map.take(config, struct_keys)
    config_struct = struct!(AreaChartConfig, filtered_config)
    do_build(data, config_struct)
  end

  defp do_build(data, config) do
    # Validate data is properly sorted by x values
    sorted_data = sort_by_x(data)

    # Convert to Contex Dataset
    dataset = Dataset.new(sorted_data)

    # Determine columns and series
    {x_col, y_cols, series_col} = get_column_mapping(sorted_data)

    # Get colors
    colors = get_colors(config)

    # Build Contex options
    contex_opts =
      config
      |> build_contex_options(x_col, y_cols, series_col, colors)
      |> Map.to_list()

    # Build base line plot
    line_plot = LinePlot.new(dataset, contex_opts)

    # Store area chart metadata for SVG post-processing
    Map.put(line_plot, :area_chart_meta, %{
      mode: config.mode || :simple,
      opacity: config.opacity || 0.7,
      y_cols: y_cols
    })
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Check if all items have required fields
    if Enum.all?(data, &valid_data_point?/1) do
      # Ensure data is time-ordered
      if is_time_ordered?(data) do
        :ok
      else
        {:error, "Area chart data must be sorted by x values or dates"}
      end
    else
      {:error, "All data points must have x/y coordinates or date/value pairs"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(%{x: x, y: y}) when is_number(x) and is_number(y), do: true
  defp valid_data_point?(%{"x" => x, "y" => y}) when is_number(x) and is_number(y), do: true

  # Support date/value format
  defp valid_data_point?(%{date: %Date{}, value: value}) when is_number(value), do: true
  defp valid_data_point?(%{"date" => %Date{}, "value" => value}) when is_number(value), do: true

  # Support DateTime/value format
  defp valid_data_point?(%{date: %DateTime{}, value: value}) when is_number(value), do: true

  # Support series-based format
  defp valid_data_point?(%{x: x, series: _, y: y}) when is_number(x) and is_number(y), do: true

  defp valid_data_point?(_), do: false

  defp is_time_ordered?(data) do
    x_values = Enum.map(data, &get_x_value/1)

    x_values == Enum.sort(x_values)
  end

  defp sort_by_x(data) do
    Enum.sort_by(data, &get_x_value/1)
  end

  defp get_x_value(%{x: x}), do: x
  defp get_x_value(%{date: date}), do: Date.to_erl(date)
  defp get_x_value(%{"x" => x}), do: x
  defp get_x_value(%{"date" => date}), do: Date.to_erl(date)
  defp get_x_value(_), do: 0

  defp get_column_mapping(data) do
    first = List.first(data)

    cond do
      # Series-based format
      Map.has_key?(first, :series) ->
        {:x, [:y], :series}

      Map.has_key?(first, "series") ->
        {"x", ["y"], "series"}

      # Simple x/y format
      Map.has_key?(first, :x) && Map.has_key?(first, :y) ->
        {:x, [:y], nil}

      # Date/value format
      Map.has_key?(first, :date) && Map.has_key?(first, :value) ->
        {:date, [:value], nil}

      # String keys
      Map.has_key?(first, "x") && Map.has_key?(first, "y") ->
        {"x", ["y"], nil}

      Map.has_key?(first, "date") && Map.has_key?(first, "value") ->
        {"date", ["value"], nil}

      true ->
        # Fallback
        {:x, [:y], nil}
    end
  end

  defp build_mapping(x_col, y_cols, nil) do
    %{x_col: x_col, y_cols: y_cols}
  end

  defp build_mapping(x_col, y_cols, series_col) do
    %{x_col: x_col, y_cols: y_cols, fill_col: series_col}
  end

  defp build_contex_options(config, x_col, y_cols, series_col, colors) do
    %{
      mapping: build_mapping(x_col, y_cols, series_col),
      colour_palette: colors
    }
    |> maybe_add_option(:smoothed, config.smooth_lines, true)
  end

  defp maybe_add_option(opts, _key, nil, _default), do: opts

  defp maybe_add_option(opts, key, value, default) when value != default do
    Map.put(opts, key, value)
  end

  defp maybe_add_option(opts, _key, _value, _default), do: opts

  defp get_colors(%AreaChartConfig{colours: colours}) when is_list(colours) and length(colours) > 0 do
    # Contex expects hex colors without the # prefix
    Enum.map(colours, fn color ->
      String.trim_leading(color, "#")
    end)
  end

  defp get_colors(_config) do
    # Use default Contex colors
    :default
  end
end
