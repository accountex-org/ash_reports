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

  alias AshReports.Charts.Config
  alias Contex.Sparkline

  @impl true
  def build(data, %Config{} = config) do
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

  defp apply_size_config(sparkline, %Config{} = config) do
    sparkline
    |> maybe_set_width(config)
    |> maybe_set_height(config)
  end

  defp maybe_set_width(sparkline, %Config{width: width})
       when is_number(width) and width != 600 do
    # Only override if width is explicitly set (not the default 600)
    %{sparkline | width: width}
  end

  defp maybe_set_width(sparkline, _config), do: sparkline

  defp maybe_set_height(sparkline, %Config{height: height})
       when is_number(height) and height != 400 do
    # Only override if height is explicitly set (not the default 400)
    %{sparkline | height: height}
  end

  defp maybe_set_height(sparkline, _config), do: sparkline

  defp apply_color_config(sparkline, %Config{colors: [fill, line | _]}) do
    # If colors provided, use first for fill and second for line
    # Contex expects CSS colors (with # prefix for hex)
    Sparkline.colours(sparkline, ensure_css_color(fill), ensure_css_color(line))
  end

  defp apply_color_config(sparkline, %Config{colors: [color]}) do
    # Single color provided, use for both fill and line with different opacity
    fill = ensure_css_color(color) <> "33"  # Add alpha for fill
    line = ensure_css_color(color)
    Sparkline.colours(sparkline, fill, line)
  end

  defp apply_color_config(sparkline, _config) do
    # Use default Contex colors (green)
    sparkline
  end

  defp apply_style_config(sparkline, _config) do
    # Use Contex defaults for style configuration
    # Future enhancement: add style fields to Config struct
    sparkline
  end

  # Ensure color has # prefix if it's a hex code
  defp ensure_css_color(color) when is_binary(color) do
    if String.starts_with?(color, "#") do
      color
    else
      # Check if it looks like a hex code (6 hex digits)
      if String.match?(color, ~r/^[0-9A-Fa-f]{6}$/) do
        "#" <> color
      else
        color  # Assume it's already a valid CSS color like "red" or "rgba(...)"
      end
    end
  end

  defp ensure_css_color(color), do: color
end
