defmodule AshReports.Charts.Types.Sparkline do
  @moduledoc """
  Sparkline chart implementation using Contex.

  Sparklines are ultra-compact inline charts (default 20px height) designed for
  embedding in tables, dashboards, and mobile displays to show trends at a glance.

  ## Data Format

  Sparklines accept flexible data formats:

  ### Simple array format:

      [1, 5, 10, 15, 12, 12, 15, 14, 20, 14, 10, 15, 15]

  ### Map format with value key:

      [
        %{value: 10},
        %{value: 15},
        %{value: 12}
      ]

  ### Map format with string keys:

      [
        %{"value" => 10},
        %{"value" => 15},
        %{"value" => 12}
      ]

  ## Configuration

  Standard chart configuration plus sparkline-specific options:
  - `width` - Chart width in pixels (default: 100)
  - `height` - Chart height in pixels (default: 20)
  - `line_colour` - CSS color for line (default: "rgba(0, 200, 50, 0.7)")
  - `fill_colour` - CSS color for fill (default: "rgba(0, 200, 50, 0.2)")
  - `spot_radius` - Radius of highlighted spots (default: 2)
  - `spot_colour` - CSS color for spots (default: "red")
  - `line_width` - Width of the line (default: 1)

  ## Examples

      # Simple sparkline with array
      data = [0, 5, 10, 15, 12, 12, 15, 14, 20]
      config = %Config{width: 100, height: 20}
      chart = Sparkline.build(data, config)

      # Sparkline with map data
      data = [%{value: 10}, %{value: 20}, %{value: 15}]
      config = %Config{
        width: 150,
        height: 30,
        colors: ["#fad48e", "#ff9838"]
      }
      chart = Sparkline.build(data, config)

  ## Use Cases

  - Dashboard metric trends
  - Inline table cell charts
  - Mobile-optimized visualizations
  - Quick trend indicators
  - Compact time-series displays
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.SparklineConfig
  alias Contex.Sparkline

  @impl true
  def build(data, %SparklineConfig{} = config) do
    do_build(data, config)
  end

  def build(data, config) when is_map(config) do
    struct_keys = Map.keys(%SparklineConfig{})
    filtered_config = Map.take(config, struct_keys)
    config_struct = struct!(SparklineConfig, filtered_config)
    do_build(data, config_struct)
  end

  defp do_build(data, config) do
    # Extract numeric values from data
    values = extract_values(data)

    # Create sparkline with values
    sparkline = Sparkline.new(values)

    # Apply configuration
    sparkline
    |> apply_size_config(config)
    |> apply_color_config(config)
    |> apply_style_config(config)
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Check if all items are valid sparkline data points
    if Enum.all?(data, &valid_data_point?/1) do
      # Ensure we have at least 2 data points for meaningful sparkline
      if length(data) >= 2 do
        :ok
      else
        {:error, "Sparkline requires at least 2 data points"}
      end
    else
      {:error, "All data points must be numbers or maps with :value key"}
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp valid_data_point?(value) when is_number(value), do: true
  defp valid_data_point?(%{value: value}) when is_number(value), do: true
  defp valid_data_point?(%{"value" => value}) when is_number(value), do: true
  defp valid_data_point?(_), do: false

  defp extract_values(data) do
    Enum.map(data, fn
      value when is_number(value) -> value
      %{value: value} when is_number(value) -> value
      %{"value" => value} when is_number(value) -> value
      _ -> 0
    end)
  end

  defp apply_size_config(sparkline, %SparklineConfig{} = config) do
    sparkline
    |> maybe_set_width(config)
    |> maybe_set_height(config)
  end

  defp maybe_set_width(sparkline, %SparklineConfig{width: width})
       when is_number(width) and width != 100 do
    # Override if width is explicitly set (SparklineConfig default is 100)
    %{sparkline | width: width}
  end

  defp maybe_set_width(sparkline, _config), do: sparkline

  defp maybe_set_height(sparkline, %SparklineConfig{height: height})
       when is_number(height) and height != 20 do
    # Override if height is explicitly set (SparklineConfig default is 20)
    %{sparkline | height: height}
  end

  defp maybe_set_height(sparkline, _config), do: sparkline

  defp apply_color_config(sparkline, %SparklineConfig{fill_colour: fill, line_colour: line})
       when not is_nil(fill) and not is_nil(line) do
    # Use explicit fill and line colours from config
    Sparkline.colours(sparkline, fill, line)
  end

  defp apply_color_config(sparkline, %SparklineConfig{line_colour: line})
       when not is_nil(line) do
    # Only line colour provided, use default fill
    Sparkline.colours(sparkline, "rgba(0, 200, 50, 0.2)", line)
  end

  defp apply_color_config(sparkline, _config) do
    # Use default Contex colors (green)
    sparkline
  end

  defp apply_style_config(sparkline, %SparklineConfig{} = _config) do
    # Note: Contex Sparkline doesn't expose separate functions for spot_radius,
    # spot_colour, or line_width. These would need to be set in Sparkline.new/2
    # options or via SVG post-processing. Current Contex API is limited.
    sparkline
  end
end
