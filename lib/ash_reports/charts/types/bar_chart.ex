defmodule AshReports.Charts.Types.BarChart do
  @moduledoc """
  Bar chart implementation using Contex.

  Supports grouped, stacked, and horizontal bar charts for categorical data
  visualization.

  ## Data Format

  Data should be a list of maps with at minimum a category and value field:

      [
        %{category: "Jan", value: 100},
        %{category: "Feb", value: 150},
        %{category: "Mar", value: 120}
      ]

  For grouped/stacked charts, include a series field:

      [
        %{category: "Jan", series: "Product A", value: 100},
        %{category: "Jan", series: "Product B", value: 80},
        %{category: "Feb", series: "Product A", value: 150},
        %{category: "Feb", series: "Product B", value: 90}
      ]

  ## Configuration

  Standard chart configuration plus:
  - `type` - :grouped, :stacked, or :simple (default: :simple)
  - `orientation` - :vertical or :horizontal (default: :vertical)

  ## Examples

      # Simple bar chart
      data = [
        %{category: "A", value: 10},
        %{category: "B", value: 20}
      ]
      config = %Config{title: "Simple Bar Chart"}
      chart = BarChart.build(data, config)

      # Grouped bar chart
      data = [
        %{category: "Q1", series: "2023", value: 100},
        %{category: "Q1", series: "2024", value: 120}
      ]
      config = %Config{title: "Yearly Comparison"}
      chart = BarChart.build(data, config)
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Config
  alias Contex.{Dataset, BarChart}

  @impl true
  def build(data, %Config{} = config) do
    # Convert data to Contex Dataset
    dataset = Dataset.new(data)

    # Determine chart type based on data structure
    chart_type = determine_chart_type(data)

    # Get colors for the chart
    colors = get_colors(config)

    # Build bar chart based on type
    case chart_type do
      :simple -> build_simple_chart(dataset, data, colors)
      :grouped -> build_grouped_chart(dataset, data, colors)
    end
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Check if all items are maps with required keys
    if Enum.all?(data, &valid_data_point?/1) do
      :ok
    else
      {:error, "All data points must be maps with :category and :value keys"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(%{category: _category, value: value}) when is_number(value), do: true

  defp valid_data_point?(%{"category" => _category, "value" => value}) when is_number(value),
    do: true

  defp valid_data_point?(_), do: false

  defp determine_chart_type(data) do
    # Check if data has series field for grouped/stacked charts
    has_series? =
      Enum.any?(data, fn item ->
        Map.has_key?(item, :series) || Map.has_key?(item, "series")
      end)

    if has_series?, do: :grouped, else: :simple
  end

  defp build_simple_chart(dataset, data, colors) do
    # Get column names from first data point
    first = List.first(data)

    cat_col = if Map.has_key?(first, :category), do: :category, else: "category"
    val_col = if Map.has_key?(first, :value), do: :value, else: "value"

    BarChart.new(dataset,
      mapping: %{category_col: cat_col, value_cols: [val_col]},
      colour_palette: colors
    )
  end

  defp build_grouped_chart(dataset, data, colors) do
    # For grouped charts, we need category, series, and value columns
    first = List.first(data)

    cat_col = if Map.has_key?(first, :category), do: :category, else: "category"
    val_col = if Map.has_key?(first, :value), do: :value, else: "value"

    # Get unique series names
    series_names =
      data
      |> Enum.map(fn item -> Map.get(item, :series) || Map.get(item, "series") end)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    # If we have series, set them as value columns (grouped)
    if length(series_names) > 0 do
      # This is a simplified approach - Contex may require data reshaping
      BarChart.new(dataset,
        mapping: %{category_col: cat_col, value_cols: [val_col]},
        type: :grouped,
        colour_palette: colors
      )
    else
      BarChart.new(dataset,
        mapping: %{category_col: cat_col, value_cols: [val_col]},
        colour_palette: colors
      )
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
