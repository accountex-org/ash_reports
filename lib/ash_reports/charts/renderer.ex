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

  The renderer integrates with the cache module to store compiled SVG output
  for improved performance on repeated requests.

  ## Error Handling

  If rendering fails, the module will attempt fallback rendering with a simple
  text-based chart or error message.
  """

  alias AshReports.Charts.{Config, Cache}
  require Logger

  @doc """
  Renders a chart to SVG format.

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
    # Generate cache key
    cache_key = generate_cache_key(chart_module, data, config)

    # Check cache first
    case Cache.get(cache_key) do
      {:ok, svg} ->
        Logger.debug("Chart cache hit for #{inspect(chart_module)}")

        :telemetry.execute(
          [:ash_reports, :charts, :cache, :hit],
          %{count: 1},
          %{chart_module: chart_module}
        )

        {:ok, svg}

      {:error, :not_found} ->
        Logger.debug("Chart cache miss for #{inspect(chart_module)}")

        :telemetry.execute(
          [:ash_reports, :charts, :cache, :miss],
          %{count: 1},
          %{chart_module: chart_module}
        )

        # Render and cache
        case do_render(chart_module, data, config) do
          {:ok, svg} = result ->
            # Cache with 5 minute TTL
            Cache.put(cache_key, svg, ttl: 300_000)
            result

          error ->
            error
        end
    end
  end

  @doc """
  Renders a chart without caching.

  Useful for testing or when caching is not desired.

  ## Parameters

    - `chart_module` - Module implementing the chart behavior
    - `data` - List of maps containing chart data
    - `config` - Chart configuration struct

  ## Returns

    - `{:ok, svg}` - Successfully rendered SVG string
    - `{:error, reason}` - Rendering failed
  """
  @spec render_without_cache(module(), list(map()), Config.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render_without_cache(chart_module, data, config) do
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
      # Create Contex.Plot with the chart
      plot =
        Contex.Plot.new(config.width, config.height, chart)
        |> maybe_add_title(config)
        |> maybe_add_axis_labels(config)

      # Render to SVG - returns {:safe, iodata}
      {:safe, iodata} = Contex.Plot.to_svg(plot)

      # Convert iodata to string
      svg = IO.iodata_to_binary(iodata)

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

  defp optimize_svg(svg) when is_binary(svg) do
    svg
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp fallback_render(data, config, reason) do
    Logger.warning("Using fallback renderer due to: #{inspect(reason)}")

    # Generate simple text-based error SVG
    svg = """
    <svg width="#{config.width}" height="#{config.height}" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#f8f9fa"/>
      <text x="50%" y="50%" text-anchor="middle" font-family="#{config.font_family}" font-size="#{config.font_size}">
        Chart generation failed: #{inspect(reason)}
      </text>
      <text x="50%" y="60%" text-anchor="middle" font-family="#{config.font_family}" font-size="#{config.font_size - 2}" fill="#6c757d">
        Data points: #{length(data)}
      </text>
    </svg>
    """

    {:ok, String.trim(svg)}
  end

  defp generate_cache_key(chart_module, data, config) do
    # Generate hash-based cache key
    key_data = %{
      module: chart_module,
      data_hash: :erlang.phash2(data),
      config_hash: :erlang.phash2(config)
    }

    :erlang.phash2(key_data)
    |> Integer.to_string(16)
  end
end
