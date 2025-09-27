defmodule AshReports.ChartEngine.ChartDataProcessor do
  @moduledoc """
  Universal chart data processing for all AshReports renderers.

  Provides renderer-agnostic chart data preparation and optimization,
  enabling consistent chart generation across HTML, HEEX, PDF, and JSON
  renderers with appropriate format-specific optimizations.

  ## Features

  - **Universal Processing**: Single data pipeline for all renderer types
  - **Renderer Optimization**: Format-specific optimizations for each output type
  - **Data Validation**: Comprehensive validation for chart data integrity
  - **Format Conversion**: Seamless conversion between chart data formats
  - **Performance Optimization**: Caching and preprocessing for efficient rendering
  - **Error Handling**: Graceful degradation for invalid or missing data

  ## Usage Examples

  ### Process for PDF Rendering

      chart_data = ChartDataProcessor.process_for_renderer(
        chart_config,
        context,
        :pdf
      )
      
      # Result optimized for static PDF generation

  ### Process for JSON API

      json_data = ChartDataProcessor.process_for_renderer(
        chart_config,
        context,
        :json
      )
      
      # Result includes API metadata and serialization format

  ### Universal Processing with Caching

      cached_data = ChartDataProcessor.process_with_cache(
        chart_config,
        context,
        [:pdf, :json, :html]
      )

  """

  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.RenderContext

  @cache_name :ash_reports_chart_data_cache
  # 1 hour
  @cache_ttl 3600_000

  @doc """
  Process chart data for specific renderer with optimizations.
  """
  @spec process_for_renderer(ChartConfig.t(), RenderContext.t(), atom()) ::
          {:ok, map()} | {:error, String.t()}
  def process_for_renderer(chart_config, context, renderer_type) do
    chart_config
    |> prepare_base_data(context)
    |> apply_renderer_optimizations(renderer_type, context)
    |> validate_output_compatibility(renderer_type)
  rescue
    error -> {:error, "Chart data processing failed: #{Exception.message(error)}"}
  end

  @doc """
  Process chart data for multiple renderers with shared caching.
  """
  @spec process_for_multiple_renderers(ChartConfig.t(), RenderContext.t(), [atom()]) ::
          {:ok, map()} | {:error, String.t()}
  def process_for_multiple_renderers(chart_config, context, renderer_types) do
    base_data = prepare_base_data(chart_config, context)

    results =
      renderer_types
      |> Enum.map(fn renderer_type ->
        case apply_renderer_optimizations(base_data, renderer_type, context) do
          {:ok, processed_data} ->
            {renderer_type, {:ok, processed_data}}

            # {:error, reason} ->
            #   {renderer_type, {:error, reason}}
        end
      end)
      |> Map.new()

    {:ok, results}
  rescue
    error -> {:error, "Multi-renderer processing failed: #{Exception.message(error)}"}
  end

  @doc """
  Prepare chart data with caching for improved performance.
  """
  @spec process_with_cache(ChartConfig.t(), RenderContext.t(), [atom()]) ::
          {:ok, map()} | {:error, String.t()}
  def process_with_cache(chart_config, context, renderer_types) do
    cache_key = generate_cache_key(chart_config, context, renderer_types)

    case get_from_cache(cache_key) do
      {:ok, cached_results} ->
        {:ok, cached_results}

      :miss ->
        case process_for_multiple_renderers(chart_config, context, renderer_types) do
          {:ok, results} ->
            :ok = store_in_cache(cache_key, results)
            {:ok, results}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Private implementation functions

  defp prepare_base_data(chart_config, context) do
    # Create universal chart data structure
    base_data = %{
      chart_config: chart_config,
      context: context,
      data: normalize_chart_data(chart_config.data),
      metadata: extract_chart_metadata(chart_config, context),
      timestamp: DateTime.utc_now()
    }

    {:ok, base_data}
  end

  defp apply_renderer_optimizations({:ok, base_data}, :pdf, context) do
    # Optimize data for PDF static rendering
    pdf_data = %{
      base_data
      | data: optimize_for_static_rendering(base_data.data),
        image_config: prepare_image_generation_config(base_data.chart_config, context),
        pdf_metadata: %{
          print_optimized: true,
          high_resolution: true,
          color_profile: "CMYK"
        }
    }

    {:ok, pdf_data}
  end

  defp apply_renderer_optimizations({:ok, base_data}, :json, context) do
    # Optimize data for JSON API output
    json_data = %{
      base_data
      | data: serialize_for_json(base_data.data),
        api_metadata: prepare_api_metadata(base_data.chart_config, context),
        endpoints: generate_chart_endpoints(base_data.chart_config),
        export_formats: [:json, :csv, :png, :svg]
    }

    {:ok, json_data}
  end

  defp apply_renderer_optimizations({:ok, base_data}, :html, _context) do
    # HTML data already optimized in existing system
    {:ok, base_data}
  end

  defp apply_renderer_optimizations({:ok, base_data}, :heex, _context) do
    # HEEX data already optimized in existing system
    {:ok, base_data}
  end

  # defp apply_renderer_optimizations({:error, reason}, _renderer_type, _context) do
  #   {:error, reason}
  # end

  defp validate_output_compatibility({:ok, processed_data}, renderer_type) do
    case renderer_type do
      :pdf ->
        if Map.has_key?(processed_data, :image_config) do
          {:ok, processed_data}
        else
          {:error, "PDF chart data missing image configuration"}
        end

      :json ->
        if Map.has_key?(processed_data, :api_metadata) do
          {:ok, processed_data}
        else
          {:error, "JSON chart data missing API metadata"}
        end

      _ ->
        {:ok, processed_data}
    end
  end

  # defp validate_output_compatibility({:error, reason}, _renderer_type) do
  #   {:error, reason}
  # end

  defp normalize_chart_data(data) when is_list(data) do
    # Normalize list data to standard format
    data
    |> Enum.map(&normalize_data_point/1)
  end

  defp normalize_chart_data(data) when is_map(data) do
    # Normalize map data to standard format
    data
    |> Map.to_list()
    |> Enum.map(fn {key, values} ->
      %{
        series: to_string(key),
        data: Enum.map(values, &normalize_data_point/1)
      }
    end)
  end

  defp normalize_chart_data(data), do: data

  defp normalize_data_point({x, y}), do: %{x: x, y: y}
  defp normalize_data_point([x, y]), do: %{x: x, y: y}
  defp normalize_data_point(%{x: _x, y: _y} = point), do: point
  defp normalize_data_point(value) when is_number(value), do: %{x: 0, y: value}
  defp normalize_data_point(value), do: %{x: to_string(value), y: 0}

  defp extract_chart_metadata(chart_config, context) do
    %{
      title: chart_config.title,
      type: chart_config.type,
      provider: chart_config.provider,
      locale: context.locale,
      text_direction: context.text_direction,
      interactive: chart_config.interactive,
      real_time: chart_config.real_time,
      created_at: DateTime.utc_now()
    }
  end

  defp optimize_for_static_rendering(data) when is_list(data) do
    # Optimize data for static PDF rendering
    data
    # Limit data points for PDF performance
    |> Enum.take(1000)
    |> Enum.map(fn point ->
      # Remove metadata for smaller size
      %{point | metadata: nil}
    end)
  end

  defp optimize_for_static_rendering(data), do: data

  defp prepare_image_generation_config(_chart_config, context) do
    %{
      width: 800,
      height: 600,
      format: :png,
      # 300 DPI for print
      quality: 300,
      background: "#ffffff",
      font_family: get_locale_font(context.locale),
      rtl: context.text_direction == "rtl"
    }
  end

  defp serialize_for_json(data) do
    # Ensure data is JSON-serializable
    Jason.encode!(data) |> Jason.decode!()
  rescue
    _ -> []
  end

  defp prepare_api_metadata(chart_config, context) do
    %{
      api_version: "1.0",
      chart_id: generate_chart_id(chart_config),
      endpoints: generate_chart_endpoints(chart_config),
      interactive_state: extract_interactive_state(chart_config),
      locale_info: %{
        locale: context.locale,
        text_direction: context.text_direction,
        timezone: context.metadata[:timezone] || "UTC"
      }
    }
  end

  @doc """
  Generate API endpoints for chart operations.
  """
  @spec generate_chart_endpoints(ChartConfig.t()) :: map()
  def generate_chart_endpoints(chart_config) do
    chart_id = generate_chart_id(chart_config)

    %{
      data: "/api/charts/#{chart_id}/data",
      config: "/api/charts/#{chart_id}/config",
      export: "/api/charts/#{chart_id}/export",
      interactions: "/api/charts/#{chart_id}/interactions"
    }
  end

  defp extract_interactive_state(chart_config) do
    %{
      interactive: chart_config.interactive,
      real_time: chart_config.real_time,
      interactions: chart_config.interactions || [],
      filters_applied: chart_config.filters || %{},
      current_view: chart_config.current_view || :default
    }
  end

  @doc """
  Generate unique chart ID from configuration.
  """
  @spec generate_chart_id(ChartConfig.t()) :: String.t()
  def generate_chart_id(chart_config) do
    # Generate consistent chart ID
    base = "#{chart_config.type}_#{chart_config.title || "chart"}"

    hash =
      :crypto.hash(:md5, :erlang.term_to_binary(chart_config))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)

    "#{base}_#{hash}"
  end

  @doc """
  Get appropriate font for locale.
  """
  @spec get_locale_font(String.t()) :: String.t()
  def get_locale_font("ar"), do: "Noto Sans Arabic"
  def get_locale_font("he"), do: "Noto Sans Hebrew"
  def get_locale_font("fa"), do: "Noto Sans Arabic"
  def get_locale_font("ur"), do: "Noto Sans Urdu"
  def get_locale_font("ja"), do: "Noto Sans JP"
  def get_locale_font("zh"), do: "Noto Sans SC"
  def get_locale_font(_), do: "Arial"

  # Cache management

  defp generate_cache_key(chart_config, context, renderer_types) do
    cache_data = %{
      chart_config: chart_config,
      locale: context.locale,
      text_direction: context.text_direction,
      renderer_types: Enum.sort(renderer_types)
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(cache_data))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp get_from_cache(cache_key) do
    case :ets.lookup(@cache_name, cache_key) do
      [{^cache_key, {data, expires_at}}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, data}
        else
          :ets.delete(@cache_name, cache_key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    _ -> :miss
  end

  defp store_in_cache(cache_key, data) do
    # Ensure cache table exists
    try do
      :ets.new(@cache_name, [:set, :public, :named_table])
    rescue
      # Table already exists
      ArgumentError -> :ok
    end

    expires_at = DateTime.add(DateTime.utc_now(), @cache_ttl, :millisecond)
    :ets.insert(@cache_name, {cache_key, {data, expires_at}})
    :ok
  end
end
