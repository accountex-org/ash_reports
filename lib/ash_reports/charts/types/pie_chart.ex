defmodule AshReports.Charts.Types.PieChart do
  @moduledoc """
  Pie chart implementation using Contex.

  Displays proportional data as slices of a pie, with optional percentage labels.

  ## Data Format

  Data should be a list of maps with category and value fields:

      [
        %{category: "Product A", value: 100},
        %{category: "Product B", value: 150},
        %{category: "Product C", value: 75}
      ]

  Alternative format with label/value:

      [
        %{label: "Apples", value: 45},
        %{label: "Oranges", value: 30},
        %{label: "Bananas", value: 25}
      ]

  ## Configuration

  Standard chart configuration plus:
  - `show_percentages` - Whether to show percentage labels (default: true)
  - `donut_width` - If set, creates donut chart with specified width (default: nil)

  ## Examples

      # Simple pie chart
      data = [
        %{category: "A", value: 30},
        %{category: "B", value: 70}
      ]
      config = %Config{title: "Distribution"}
      chart = PieChart.build(data, config)

      # Donut chart
      config = %Config{title: "Donut", donut_width: 20}
      chart = PieChart.build(data, config)
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.PieChartConfig
  alias Contex.{Dataset, PieChart}

  @impl true
  def build(data, %PieChartConfig{} = config) do
    do_build(data, config)
  end

  def build(data, config) when is_map(config) do
    struct_keys = Map.keys(%PieChartConfig{})
    filtered_config = Map.take(config, struct_keys)
    config_struct = struct!(PieChartConfig, filtered_config)
    do_build(data, config_struct)
  end

  defp do_build(data, config) do
    # Convert data to Contex Dataset
    dataset = Dataset.new(data)

    # Get column names
    {cat_col, val_col} = get_column_names(data)

    # Get colors for the chart
    colors = get_colors(config)

    # Build Contex options
    contex_opts =
      config
      |> build_contex_options(cat_col, val_col, colors)
      |> Map.to_list()

    # Build pie chart with all options
    PieChart.new(dataset, contex_opts)
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Check if all items have category/label and value
    if Enum.all?(data, &valid_data_point?/1) do
      # Validate that values sum to positive number
      total =
        data
        |> Enum.map(fn item ->
          Map.get(item, :value) || Map.get(item, "value", 0)
        end)
        |> Enum.sum()

      if total > 0 do
        :ok
      else
        {:error, "Sum of values must be positive"}
      end
    else
      {:error, "All data points must have category/label and value"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(%{category: _cat, value: value}) when is_number(value) and value >= 0,
    do: true

  defp valid_data_point?(%{label: _label, value: value}) when is_number(value) and value >= 0,
    do: true

  defp valid_data_point?(%{"category" => _cat, "value" => value})
       when is_number(value) and value >= 0,
       do: true

  defp valid_data_point?(%{"label" => _label, "value" => value})
       when is_number(value) and value >= 0,
       do: true

  defp valid_data_point?(_), do: false

  defp get_column_names(data) do
    first = List.first(data)

    cond do
      Map.has_key?(first, :category) ->
        {:category, :value}

      Map.has_key?(first, :label) ->
        {:label, :value}

      Map.has_key?(first, "category") ->
        {"category", "value"}

      Map.has_key?(first, "label") ->
        {"label", "value"}

      true ->
        # Fallback
        {:category, :value}
    end
  end

  defp build_contex_options(config, cat_col, val_col, colors) do
    %{
      mapping: %{category_col: cat_col, value_col: val_col},
      colour_palette: colors
    }
    |> maybe_add_data_labels(config.data_labels)
  end

  defp maybe_add_data_labels(opts, true), do: Map.put(opts, :data_labels, true)
  defp maybe_add_data_labels(opts, _), do: opts

  defp get_colors(%PieChartConfig{colours: colours}) when is_list(colours) and length(colours) > 0 do
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
