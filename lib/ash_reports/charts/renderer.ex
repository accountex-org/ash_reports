defmodule AshReports.Charts.Renderer do
  @moduledoc """
  SVG rendering module for charts using Contex.

  This module handles the conversion of chart structures to SVG output,
  including optimization and error handling with fallback rendering.

  ## Rendering Pipeline

  1. Validate data using chart module's validate/1
  2. Build chart structure using chart module's build/2
  3. Render to SVG using Contex.Plot
  4. Optimize SVG (remove unnecessary attributes)
  5. Return SVG string

  ## Caching

  This module does NOT handle caching. All caching logic is centralized in the
  Charts module to avoid duplicate cache entries and maintain a single source
  of truth. If you need cached rendering, use `AshReports.Charts.generate/4`.

  ## Error Handling

  If rendering fails, the module will attempt fallback rendering with a simple
  text-based chart or error message.
  """

  alias AshReports.Charts.Config
  require Logger

  @doc """
  Renders a chart to SVG format.

  Note: This function does NOT cache the result. Caching is handled by the
  Charts module to avoid duplicate cache logic. Use this function when you
  want direct rendering without caching overhead.

  ## Parameters

    - `chart_module` - Module implementing the chart behavior
    - `data` - List of maps containing chart data
    - `config` - Chart configuration struct

  ## Returns

    - `{:ok, svg}` - Successfully rendered SVG string
    - `{:error, reason}` - Rendering failed

  ## Examples

      alias AshReports.Charts.Types.BarChart

      data = [%{x: "A", y: 10}, %{x: "B", y: 20}]
      config = %Config{width: 600, height: 400}

      {:ok, svg} = Renderer.render(BarChart, data, config)
  """
  @spec render(module(), list(map()), Config.t()) :: {:ok, String.t()} | {:error, term()}
  def render(chart_module, data, config) do
    do_render(chart_module, data, config)
  end


  # Private functions

  defp do_render(chart_module, data, config) do
    with :ok <- validate_data(chart_module, data),
         chart <- build_chart(chart_module, data, config),
         {:ok, svg} <- render_to_svg(chart, config) do
      {:ok, optimize_svg(svg)}
    else
      {:error, reason} = error ->
        Logger.error("Chart rendering failed: #{inspect(reason)}")
        # Attempt fallback rendering
        case fallback_render(data, config, reason) do
          {:ok, _svg} = result -> result
          _ -> error
        end
    end
  end

  defp validate_data(chart_module, data) do
    if function_exported?(chart_module, :validate, 1) do
      chart_module.validate(data)
    else
      # Skip validation if not implemented
      :ok
    end
  end

  defp build_chart(chart_module, data, config) do
    chart_module.build(data, config)
  end

  defp render_to_svg(chart, config) do
    try do
      # Use defaults for missing dimensions
      width = Map.get(config, :width, 600)
      height = Map.get(config, :height, 400)

      # Create Contex.Plot with the chart
      plot =
        Contex.Plot.new(width, height, chart)
        |> maybe_add_title(config)
        |> maybe_add_axis_labels(config)

      # Render to SVG - returns {:safe, iodata}
      {:safe, iodata} = Contex.Plot.to_svg(plot)

      # Convert iodata to string
      svg = IO.iodata_to_binary(iodata)

      # Apply area chart post-processing if needed
      svg = maybe_add_area_fill(svg, chart)

      {:ok, svg}
    rescue
      e ->
        {:error, {:render_error, Exception.message(e)}}
    end
  end

  defp maybe_add_title(plot, %{title: title}) when is_binary(title) and title != "" do
    Contex.Plot.titles(plot, title, "")
  end

  defp maybe_add_title(plot, _config), do: plot

  defp maybe_add_axis_labels(plot, config) do
    plot
    |> maybe_add_x_axis_label(config)
    |> maybe_add_y_axis_label(config)
  end

  defp maybe_add_x_axis_label(plot, %{x_axis_label: label})
       when is_binary(label) and label != "" do
    # Note: Contex doesn't have direct axis label support in all chart types
    # This is a placeholder for future enhancement
    plot
  end

  defp maybe_add_x_axis_label(plot, _config), do: plot

  defp maybe_add_y_axis_label(plot, %{y_axis_label: label})
       when is_binary(label) and label != "" do
    # Note: Contex doesn't have direct axis label support in all chart types
    # This is a placeholder for future enhancement
    plot
  end

  defp maybe_add_y_axis_label(plot, _config), do: plot

  defp maybe_add_area_fill(svg, %{area_chart_meta: meta}) do
    # Extract line paths from SVG and add area fills
    add_area_paths(svg, meta)
  end

  defp maybe_add_area_fill(svg, _chart), do: svg

  defp add_area_paths(svg, %{opacity: opacity}) do
    # Find all <path> elements with stroke (line paths)
    # Add corresponding <path> elements with fill for area effect

    # Pattern to match line paths: <path d="..." stroke="..." .../>
    line_pattern = ~r/<path\s+d="([^"]+)"\s+stroke="([^"]+)"[^>]*\/>/

    matches = Regex.scan(line_pattern, svg)

    if length(matches) > 0 do
      # Build area paths from line paths
      _area_paths =
        matches
        |> Enum.with_index()
        |> Enum.map(fn {[_full_match, d_attr, color], _index} ->
          # Create area path by closing the line to the x-axis
          # This is a simplified approach - extract coordinates and close path
          area_d = create_area_path(d_attr)

          # Create filled path element with opacity
          ~s(<path d="#{area_d}" fill="#{color}" opacity="#{opacity}" stroke="none" />)
        end)
        |> Enum.join("\n")

      # Insert area paths before line paths (so lines appear on top)
      String.replace(
        svg,
        line_pattern,
        fn match ->
          # Return both area path and original line path
          area_index =
            length(Regex.scan(line_pattern, String.slice(svg, 0, String.length(svg)))) - 1

          if area_index >= 0 and area_index < length(matches) do
            [_, d_attr, color] = Enum.at(matches, area_index)
            area_d = create_area_path(d_attr)

            ~s(<path d="#{area_d}" fill="#{color}" opacity="#{opacity}" stroke="none" />\n#{match})
          else
            match
          end
        end,
        global: false
      )
      |> close_area_paths(matches, opacity)
    else
      svg
    end
  end

  defp close_area_paths(svg, matches, opacity) do
    # More robust approach: insert area fills into SVG properly
    # Find the chart group and prepend area paths

    matches
    |> Enum.reduce(svg, fn [_full_match, d_attr, color], acc ->
      area_d = create_area_path(d_attr)
      area_path = ~s(<path d="#{area_d}" fill="#{color}" opacity="#{opacity}" stroke="none" />)

      # Insert before the first </g> closing tag
      String.replace(
        acc,
        ~r/<\/g>/,
        fn match ->
          area_path <> "\n" <> match
        end,
        global: false
      )
    end)
  end

  defp create_area_path(line_d) do
    # Parse SVG path data and close to baseline
    # Extract M (moveto) and L (lineto) commands
    # Example: "M 50,100 L 100,80 L 150,90" -> "M 50,100 L 100,80 L 150,90 L 150,200 L 50,200 Z"

    # Find all coordinate pairs
    coords = Regex.scan(~r/([ML])\s*([\d.]+)\s*,\s*([\d.]+)/, line_d)

    if length(coords) > 0 do
      # Get first and last x coordinates
      [_, _first_cmd, first_x, _first_y] = List.first(coords)
      [_, _last_cmd, last_x, _last_y] = List.last(coords)

      # Get the baseline y (we'll use a high value as approximation)
      # In a real implementation, this should be calculated from the chart's y-scale
      # This should be dynamic based on chart height
      baseline_y = "200"

      # Build area path: original line + line to baseline + line back to start + close
      line_d <> " L #{last_x},#{baseline_y} L #{first_x},#{baseline_y} Z"
    else
      # Fallback: just close the path
      line_d <> " Z"
    end
  end

  defp optimize_svg(svg) when is_binary(svg) do
    svg
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp fallback_render(data, config, reason) do
    Logger.warning("Using fallback renderer due to: #{inspect(reason)}")

    # Use defaults for missing dimensions
    width = Map.get(config, :width, 600)
    height = Map.get(config, :height, 400)
    font_family = Map.get(config, :font_family, "Arial, sans-serif")
    font_size = Map.get(config, :font_size, 14)

    # Generate simple text-based error SVG
    svg = """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#f8f9fa"/>
      <text x="50%" y="50%" text-anchor="middle" font-family="#{font_family}" font-size="#{font_size}">
        Chart generation failed: #{inspect(reason)}
      </text>
      <text x="50%" y="60%" text-anchor="middle" font-family="#{font_family}" font-size="#{font_size - 2}" fill="#6c757d">
        Data points: #{length(data)}
      </text>
    </svg>
    """

    {:ok, String.trim(svg)}
  end

end
