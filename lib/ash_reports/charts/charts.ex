defmodule AshReports.Charts do
  @moduledoc """
  Main module for chart generation in AshReports.

  This module provides the public API for generating SVG charts using pure Elixir
  libraries (Contex). It supports various chart types including bar charts, line
  charts, pie charts, and more.

  ## Usage

      # Generate a bar chart
      data = [
        %{category: "Jan", value: 100},
        %{category: "Feb", value: 150},
        %{category: "Mar", value: 120}
      ]

      config = %AshReports.Charts.BarChartConfig{
        title: "Monthly Sales",
        width: 600,
        height: 400
      }

      {:ok, svg} = AshReports.Charts.generate(:bar, data, config)

  ## Supported Chart Types

  - `:bar` - Bar charts (grouped, stacked, horizontal)
  - `:line` - Line charts (single/multi-series)
  - `:pie` - Pie charts (with percentage labels)
  - `:area` - Area charts (stacked areas for time-series)
  - `:scatter` - Scatter plots (with optional regression lines)

  ## Caching

  Chart SVG output is automatically cached using ETS for performance. The cache
  key is generated from the chart type, data, and configuration.

  ## Telemetry

  This module emits the following telemetry events:

  - `[:ash_reports, :charts, :generate, :start]` - Chart generation started
  - `[:ash_reports, :charts, :generate, :stop]` - Chart generation completed
  - `[:ash_reports, :charts, :generate, :exception]` - Chart generation failed
  """

  alias AshReports.Charts.{Cache, Registry, Renderer, Theme}

  @doc """
  Generates a chart and returns SVG string.

  Automatically caches generated charts for improved performance. Cache keys are
  generated from chart type, data, and configuration to ensure deterministic caching.

  ## Parameters

    - `type` - Chart type atom (e.g., `:bar`, `:line`, `:pie`)
    - `data` - List of maps containing chart data
    - `config` - Chart configuration (type-specific config struct or map)
    - `opts` - Options (keyword list)
      - `:cache` - Enable/disable caching (default: `true`)
      - `:cache_ttl` - Cache time-to-live in milliseconds (default: `300_000` / 5 minutes)
      - `:compression_threshold` - Minimum SVG size for compression (default: `10_000` bytes)

  ## Returns

    - `{:ok, svg}` - Successfully generated SVG string
    - `{:error, reason}` - Error occurred during generation

  ## Examples

      # Generate a simple bar chart (with caching)
      data = [%{x: "A", y: 10}, %{x: "B", y: 20}]
      config = %AshReports.Charts.BarChartConfig{title: "Test Chart"}
      {:ok, svg} = AshReports.Charts.generate(:bar, data, config)

      # With custom configuration
      config = %AshReports.Charts.LineChartConfig{
        title: "Sales Report",
        width: 800,
        height: 600,
        colours: ["#FF6B6B", "#4ECDC4", "#45B7D1"]
      }
      {:ok, svg} = AshReports.Charts.generate(:line, data, config)

      # Disable caching
      {:ok, svg} = AshReports.Charts.generate(:bar, data, config, cache: false)

      # Custom cache TTL (10 minutes)
      {:ok, svg} = AshReports.Charts.generate(:bar, data, config, cache_ttl: 600_000)

      # Custom compression threshold (20KB)
      {:ok, svg} = AshReports.Charts.generate(:bar, data, config, compression_threshold: 20_000)
  """
  @spec generate(atom(), list(map()), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate(type, data, config \\ %{}, opts \\ []) do
    start_time = System.monotonic_time()

    metadata = %{
      chart_type: type,
      data_count: length(data)
    }

    :telemetry.execute(
      [:ash_reports, :charts, :generate, :start],
      %{system_time: System.system_time()},
      metadata
    )

    # Check cache first (unless explicitly disabled)
    use_cache = Keyword.get(opts, :cache, true)

    result =
      if use_cache do
        # Generate cache key from inputs
        cache_key = Cache.generate_cache_key(type, data, config)

        case Cache.get_decompressed(cache_key) do
          {:ok, cached_svg} ->
            # Cache hit - return cached SVG
            duration = System.monotonic_time() - start_time

            :telemetry.execute(
              [:ash_reports, :charts, :generate, :stop],
              %{duration: duration, cache_hit: true},
              Map.merge(metadata, %{svg_size: byte_size(cached_svg), from_cache: true})
            )

            {:ok, cached_svg}

          {:error, :not_found} ->
            # Cache miss - generate and cache
            generate_and_cache(type, data, config, opts, cache_key, start_time, metadata)

          {:error, _reason} ->
            # Cache error - fall back to generation without caching
            generate_without_cache(type, data, config, start_time, metadata)
        end
      else
        # Cache disabled - generate without caching
        generate_without_cache(type, data, config, start_time, metadata)
      end

    result
  end

  @doc """
  Lists all available chart types.

  ## Returns

  List of chart type atoms that can be used with `generate/3`.

  ## Examples

      AshReports.Charts.list_types()
      # => [:bar, :line, :pie, :area, :scatter]
  """
  @spec list_types() :: [atom()]
  def list_types do
    Registry.list()
  end

  @doc """
  Checks if a chart type is available.

  ## Parameters

    - `type` - Chart type atom

  ## Returns

  Boolean indicating if the chart type is registered.

  ## Examples

      AshReports.Charts.type_available?(:bar)
      # => true

      AshReports.Charts.type_available?(:unknown)
      # => false
  """
  @spec type_available?(atom()) :: boolean()
  def type_available?(type) do
    case Registry.get(type) do
      {:ok, _module} -> true
      {:error, _} -> false
    end
  end

  # Private functions

  defp generate_and_cache(type, data, config, opts, cache_key, start_time, metadata) do
    case generate_chart(type, data, config, start_time, metadata) do
      {:ok, svg} ->
        # Cache the generated SVG with compression
        ttl = Keyword.get(opts, :cache_ttl, 300_000)
        threshold = Keyword.get(opts, :compression_threshold, 10_000)

        Cache.put_compressed(cache_key, svg, ttl: ttl, threshold: threshold)

        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:ash_reports, :charts, :generate, :stop],
          %{duration: duration, cache_hit: false},
          Map.merge(metadata, %{svg_size: byte_size(svg), from_cache: false})
        )

        {:ok, svg}

      error ->
        error
    end
  end

  defp generate_without_cache(type, data, config, start_time, metadata) do
    case generate_chart(type, data, config, start_time, metadata) do
      {:ok, svg} ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:ash_reports, :charts, :generate, :stop],
          %{duration: duration},
          Map.put(metadata, :svg_size, byte_size(svg))
        )

        {:ok, svg}

      error ->
        error
    end
  end

  defp generate_chart(type, data, config, start_time, metadata) do
    with {:ok, chart_module} <- Registry.get(type),
         {:ok, config} <- normalize_config(config),
         {:ok, config} <- apply_theme(config),
         :ok <- check_min_data_points(data, config),
         {:ok, svg} <- Renderer.render(chart_module, data, config) do
      {:ok, svg}
    else
      {:error, reason} = error ->
        :telemetry.execute(
          [:ash_reports, :charts, :generate, :exception],
          %{duration: System.monotonic_time() - start_time},
          Map.put(metadata, :error, reason)
        )

        error
    end
  end

  defp normalize_config(config) when is_map(config), do: {:ok, config}

  defp normalize_config(_), do: {:error, :invalid_config}

  defp apply_theme(%{theme_name: theme_name} = config) when theme_name != :default do
    # Apply theme if it's not the default
    if Theme.exists?(theme_name) do
      themed_config = Theme.apply(config, theme_name)
      {:ok, themed_config}
    else
      # Theme doesn't exist, just use config as-is
      {:ok, config}
    end
  end

  defp apply_theme(config), do: {:ok, config}

  defp check_min_data_points(data, %{min_data_points: min}) when is_integer(min) do
    if length(data) >= min do
      :ok
    else
      {:error,
       {:insufficient_data, "Chart requires at least #{min} data points, got #{length(data)}"}}
    end
  end

  defp check_min_data_points(_data, _config), do: :ok
end
