defmodule AshReports.Charts.Types.ScatterPlot do
  @moduledoc """
  Scatter plot implementation using Contex PointPlot.

  Supports scatter plots for correlation analysis and data distribution visualization.

  ## Data Format

  Data should be a list of maps with x and y coordinates:

      [
        %{x: 1.5, y: 10.2},
        %{x: 2.3, y: 15.7},
        %{x: 3.1, y: 12.5}
      ]

  ## Configuration

  Standard chart configuration plus:
  - `point_size` - Size of scatter points (default: 5)
  - `show_regression` - Whether to show regression line (default: false) - Future feature

  ## Examples

      # Simple scatter plot
      data = [%{x: 1, y: 10}, %{x: 2, y: 20}, %{x: 3, y: 15}]
      config = %Config{title: "Correlation Analysis"}
      {:ok, svg} = Charts.generate(:scatter, data, config)
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.ScatterChartConfig
  alias Contex.{Dataset, PointPlot}

  @impl true
  def build(data, %ScatterChartConfig{} = config) do
    # Convert to Contex Dataset
    dataset = Dataset.new(data)

    # Determine x and y column names
    {x_col, y_col} = get_column_names(data)

    # Get colors
    colors = get_colors(config)

    # Build Contex options
    contex_opts = build_contex_options(config, x_col, y_col, colors)

    # Build point plot with all options
    PointPlot.new(dataset, contex_opts)
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
  defp valid_data_point?(_), do: false

  defp get_column_names(data) do
    first = List.first(data)

    cond do
      Map.has_key?(first, :x) && Map.has_key?(first, :y) ->
        {:x, :y}

      Map.has_key?(first, "x") && Map.has_key?(first, "y") ->
        {"x", "y"}

      true ->
        # Fallback
        {:x, :y}
    end
  end

  defp build_contex_options(config, x_col, y_col, colors) do
    %{
      mapping: %{x_col: x_col, y_cols: [y_col]},
      colour_palette: colors
    }
    |> maybe_add_axis_label_rotation(config.axis_label_rotation)
  end

  defp maybe_add_axis_label_rotation(opts, :auto), do: opts
  defp maybe_add_axis_label_rotation(opts, nil), do: opts

  defp maybe_add_axis_label_rotation(opts, rotation) when rotation in [:"45", :"90"] do
    Map.put(opts, :axis_label_rotation, rotation)
  end

  defp maybe_add_axis_label_rotation(opts, _), do: opts

  defp get_colors(%ScatterChartConfig{colours: colours}) when is_list(colours) and length(colours) > 0 do
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
