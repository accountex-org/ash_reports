defmodule AshReports.Charts.Types.LineChart do
  @moduledoc """
  Line chart implementation using Contex.

  Supports single and multi-series line charts for time-series and continuous
  data visualization.

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
        %{date: ~D[2024-01-02], value: 150}
      ]

  For multi-series:

      [
        %{x: 1, series: "A", y: 10},
        %{x: 1, series: "B", y: 15},
        %{x: 2, series: "A", y: 12},
        %{x: 2, series: "B", y: 18}
      ]

  ## Configuration

  Standard chart configuration plus:
  - `smooth_lines` - Whether to use smooth curves (default: false)
  - `show_points` - Whether to show data points (default: true)
  - `fill_below` - Whether to fill area below line (default: false)

  ## Examples

      # Simple line chart
      data = [%{x: 1, y: 10}, %{x: 2, y: 20}]
      config = %Config{title: "Trend"}
      chart = LineChart.build(data, config)

      # Multi-series
      data = [
        %{x: 1, series: "Product A", y: 10},
        %{x: 1, series: "Product B", y: 15}
      ]
      chart = LineChart.build(data, config)
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.LineChartConfig
  alias Contex.{Dataset, LinePlot}

  @impl true
  def build(data, %LineChartConfig{} = config) do
    do_build(data, config)
  end

  def build(data, config) when is_map(config) do
    struct_keys = Map.keys(%LineChartConfig{})
    filtered_config = Map.take(config, struct_keys)
    config_struct = struct!(LineChartConfig, filtered_config)
    do_build(data, config_struct)
  end

  defp do_build(data, config) do
    # Convert data to Contex Dataset
    dataset = Dataset.new(data)

    # Determine x and y column names
    {x_col, y_col} = get_column_names(data)

    # Get colors for the chart
    colors = get_colors(config)

    # Build Contex options
    contex_opts =
      config
      |> build_contex_options(x_col, y_col, colors)
      |> Map.to_list()

    # Build line plot with all options
    LinePlot.new(dataset, contex_opts)
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Check if all items have x and y values
    if Enum.all?(data, &valid_data_point?/1) do
      :ok
    else
      {:error, "All data points must have x and y coordinates"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  # Support numeric x and y
  defp valid_data_point?(%{x: x, y: y}) when is_number(x) and is_number(y), do: true
  defp valid_data_point?(%{"x" => x, "y" => y}) when is_number(x) and is_number(y), do: true

  # Support string x (categorical) and numeric y
  defp valid_data_point?(%{x: x, y: y}) when is_binary(x) and is_number(y), do: true
  defp valid_data_point?(%{"x" => x, "y" => y}) when is_binary(x) and is_number(y), do: true

  # Support date/value format
  defp valid_data_point?(%{date: %Date{}, value: value}) when is_number(value), do: true
  defp valid_data_point?(%{"date" => %Date{}, "value" => value}) when is_number(value), do: true

  # Support DateTime/value format
  defp valid_data_point?(%{date: %DateTime{}, value: value}) when is_number(value), do: true

  defp valid_data_point?(_), do: false

  defp get_column_names(data) do
    first = List.first(data)

    cond do
      Map.has_key?(first, :x) && Map.has_key?(first, :y) ->
        {:x, :y}

      Map.has_key?(first, :date) && Map.has_key?(first, :value) ->
        {:date, :value}

      Map.has_key?(first, "x") && Map.has_key?(first, "y") ->
        {"x", "y"}

      Map.has_key?(first, "date") && Map.has_key?(first, "value") ->
        {"date", "value"}

      true ->
        # Fallback to first two numeric keys found
        {:x, :y}
    end
  end

  defp build_contex_options(config, x_col, y_col, colors) do
    # Convert stroke_width to integer if it's a string
    stroke_width =
      case config.stroke_width do
        width when is_binary(width) -> String.to_integer(width)
        width when is_integer(width) -> width
        _ -> 2
      end

    base_opts = %{
      mapping: %{x_col: x_col, y_cols: [y_col]}
    }

    # Only add colour_palette if we have actual colors (not :default)
    opts =
      case colors do
        colors when is_list(colors) -> Map.put(base_opts, :colour_palette, colors)
        _ -> base_opts
      end

    opts
    |> maybe_add_option(:smoothed, config.smoothed, true)
    |> maybe_add_option(:stroke_width, stroke_width, 2)
    |> maybe_add_option(:custom_x_formatter, &format_gregorian_days/1, nil)
    |> maybe_add_axis_label_rotation(config.axis_label_rotation)
  end

  defp maybe_add_option(opts, _key, nil, _default), do: opts

  defp maybe_add_option(opts, key, value, default) when value != default do
    Map.put(opts, key, value)
  end

  defp maybe_add_option(opts, _key, _value, _default), do: opts

  defp maybe_add_axis_label_rotation(opts, :auto), do: opts
  defp maybe_add_axis_label_rotation(opts, nil), do: opts

  defp maybe_add_axis_label_rotation(opts, rotation) when rotation in [:"45", :"90"] do
    Map.put(opts, :axis_label_rotation, rotation)
  end

  defp maybe_add_axis_label_rotation(opts, _), do: opts

  defp get_colors(%LineChartConfig{colours: colours}) when is_list(colours) and length(colours) > 0 do
    # Contex expects hex colors without the # prefix
    Enum.map(colours, fn color ->
      String.trim_leading(color, "#")
    end)
  end

  defp get_colors(_config) do
    # Use default Contex colors
    :default
  end

  # Format gregorian days back to readable month labels
  defp format_gregorian_days(value) when is_number(value) do
    try do
      # Convert gregorian days to Date
      date = Date.from_gregorian_days(round(value))
      # Format as "Mon YYYY" (e.g., "Jan 2024")
      month_name = month_abbr(date.month)
      "#{month_name} #{date.year}"
    rescue
      _ -> to_string(round(value))
    end
  end

  defp format_gregorian_days(value), do: to_string(value)

  defp month_abbr(1), do: "Jan"
  defp month_abbr(2), do: "Feb"
  defp month_abbr(3), do: "Mar"
  defp month_abbr(4), do: "Apr"
  defp month_abbr(5), do: "May"
  defp month_abbr(6), do: "Jun"
  defp month_abbr(7), do: "Jul"
  defp month_abbr(8), do: "Aug"
  defp month_abbr(9), do: "Sep"
  defp month_abbr(10), do: "Oct"
  defp month_abbr(11), do: "Nov"
  defp month_abbr(12), do: "Dec"
end
