defmodule AshReports.ChartEngine.ChartImageGenerator do
  @moduledoc """
  Server-side chart image generation for PDF rendering in Phase 6.3.

  Generates high-quality chart images for embedding in PDF reports using
  headless browser rendering with Chart.js, D3.js, or Plotly for consistent
  chart appearance across interactive and static formats.

  ## Features

  - **High-Quality Image Generation**: 300 DPI chart images for print quality
  - **Multi-Provider Support**: Chart.js, D3.js, Plotly rendering
  - **Headless Browser Integration**: Placeholder for future image generation support
  - **Performance Optimization**: Image caching and parallel generation
  - **Format Support**: PNG, SVG, JPEG with configurable quality
  - **RTL and Locale Support**: International chart rendering

  ## Usage Examples

  ### Generate Chart Image for PDF

      {:ok, image_data} = ChartImageGenerator.generate_chart_image(
        chart_config,
        context,
        %{format: :png, width: 800, height: 600, quality: 300}
      )
      
      # image_data contains binary PNG data for PDF embedding

  ### Batch Image Generation

      chart_images = ChartImageGenerator.generate_multiple_images(
        chart_configs,
        context,
        %{format: :png, quality: 300}
      )

  ### Cached Image Generation

      {:ok, cached_image} = ChartImageGenerator.generate_with_cache(
        chart_config,
        context,
        image_options
      )

  """

  alias AshReports.ChartEngine.{ChartConfig, ChartDataProcessor}
  alias AshReports.HtmlRenderer.ChartIntegrator
  alias AshReports.RenderContext

  require Logger

  @image_cache_name :ash_reports_chart_images
  # 30 minutes
  @cache_ttl 1800_000
  @default_image_options %{
    format: :png,
    width: 800,
    height: 600,
    # DPI
    quality: 300,
    background: "#ffffff"
  }

  @doc """
  Generate chart image for PDF embedding.
  """
  @spec generate_chart_image(ChartConfig.t(), RenderContext.t(), map()) ::
          {:ok, binary()} | {:error, String.t()}
  def generate_chart_image(chart_config, context, options \\ %{}) do
    image_options = Map.merge(@default_image_options, options)

    with {:ok, html_content} <- generate_chart_html(chart_config, context),
         {:ok, image_binary} <- render_html_to_image(html_content, image_options) do
      {:ok, image_binary}
    else
      {:error, reason} -> {:error, "Chart image generation failed: #{reason}"}
    end
  end

  @doc """
  Generate multiple chart images efficiently with parallel processing.
  """
  @spec generate_multiple_images([ChartConfig.t()], RenderContext.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def generate_multiple_images(chart_configs, context, options \\ %{}) do
    # Use Task.async_stream for parallel generation
    chart_configs
    |> Task.async_stream(
      fn chart_config ->
        chart_id = ChartDataProcessor.generate_chart_id(chart_config)

        case generate_chart_image(chart_config, context, options) do
          {:ok, image_data} -> {chart_id, {:ok, image_data}}
          {:error, reason} -> {chart_id, {:error, reason}}
        end
      end,
      max_concurrency: 4,
      timeout: 30_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> Map.new()
    |> then(&{:ok, &1})
  rescue
    error -> {:error, "Batch image generation failed: #{Exception.message(error)}"}
  end

  @doc """
  Generate chart image with caching for performance.
  """
  @spec generate_with_cache(ChartConfig.t(), RenderContext.t(), map()) ::
          {:ok, binary()} | {:error, String.t()}
  def generate_with_cache(chart_config, context, options \\ %{}) do
    cache_key = generate_image_cache_key(chart_config, context, options)

    case get_image_from_cache(cache_key) do
      {:ok, cached_image} ->
        {:ok, cached_image}

      :miss ->
        case generate_chart_image(chart_config, context, options) do
          {:ok, image_data} ->
            :ok = store_image_in_cache(cache_key, image_data)
            {:ok, image_data}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Clear image cache to free memory.
  """
  @spec clear_image_cache() :: :ok
  def clear_image_cache do
    try do
      :ets.delete_all_objects(@image_cache_name)
    rescue
      _ -> :ok
    end

    :ok
  end

  # Private image generation functions

  defp generate_chart_html(chart_config, context) do
    # Generate standalone HTML for chart rendering
    case ChartIntegrator.render_chart(chart_config, context) do
      {:ok, chart_output} ->
        standalone_html = create_standalone_chart_html(chart_output, context)
        {:ok, standalone_html}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_standalone_chart_html(chart_output, context) do
    """
    <!DOCTYPE html>
    <html lang="#{context.locale}" dir="#{context.text_direction}">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Chart</title>
      <style>
        body { 
          margin: 0; 
          padding: 20px; 
          font-family: #{ChartDataProcessor.get_locale_font(context.locale)}; 
        }
        .ash-chart-container { 
          width: 100%; 
          height: 100%; 
        }
      </style>
    </head>
    <body>
      #{chart_output.html}
      <script>
        #{chart_output.javascript}
      </script>
    </body>
    </html>
    """
  end

  defp render_html_to_image(_html_content, _image_options) do
    # Placeholder for future HTML to image conversion
    # TODO: Implement chart image generation using a headless browser or similar tool
    # This would be used to generate chart images for embedding in PDF reports
    {:error, "Chart image generation not yet implemented"}
  rescue
    error -> {:error, "Image rendering failed: #{Exception.message(error)}"}
  end

  # Cache management

  defp generate_image_cache_key(chart_config, context, options) do
    cache_data = %{
      chart_config: Map.take(chart_config, [:type, :data, :title, :provider]),
      locale: context.locale,
      text_direction: context.text_direction,
      image_options: options
    }

    :crypto.hash(:md5, :erlang.term_to_binary(cache_data))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 12)
  end

  defp get_image_from_cache(cache_key) do
    case :ets.lookup(@image_cache_name, cache_key) do
      [{^cache_key, {image_data, expires_at}}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, image_data}
        else
          :ets.delete(@image_cache_name, cache_key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    _ -> :miss
  end

  defp store_image_in_cache(cache_key, image_data) do
    # Ensure cache table exists
    try do
      :ets.new(@image_cache_name, [:set, :public, :named_table])
    rescue
      # Table already exists
      ArgumentError -> :ok
    end

    expires_at = DateTime.add(DateTime.utc_now(), @cache_ttl, :millisecond)
    :ets.insert(@image_cache_name, {cache_key, {image_data, expires_at}})
    :ok
  end
end
