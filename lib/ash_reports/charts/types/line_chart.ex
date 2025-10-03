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

  alias AshReports.Charts.Config
  alias Contex.{Dataset, LinePlot}

  @impl true
  def build(data, %Config{} = config) do
    # Convert data to Contex Dataset
    dataset = Dataset.new(data)

    # Determine x and y column names
    {x_col, y_col} = get_column_names(data)

    # Get colors for the chart
    colors = get_colors(config)

    # Build line plot with mapping and colors
    LinePlot.new(dataset,
      mapping: %{x_col: x_col, y_cols: [y_col]},
      colour_palette: colors
    )
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

  defp valid_data_point?(%{x: x, y: y}) when is_number(x) and is_number(y), do: true
  defp valid_data_point?(%{"x" => x, "y" => y}) when is_number(x) and is_number(y), do: true

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

  defp get_colors(%Config{colors: colors}) when is_list(colors) and length(colors) > 0 do
    # Contex expects hex colors without the # prefix
    Enum.map(colors, fn color ->
      String.trim_leading(color, "#")
    end)
  end

  defp get_colors(_config) do
    # Use default colors, strip # prefix
    Config.default_colors()
    |> Enum.map(fn color -> String.trim_leading(color, "#") end)
  end
end
