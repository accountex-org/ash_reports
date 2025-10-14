defmodule AshReports.Charts.PerformanceMonitor do
  @moduledoc """
  Performance monitoring and telemetry aggregation for chart generation.

  This module provides real-time performance monitoring by listening to telemetry
  events emitted by the Charts subsystem and aggregating metrics for analysis.

  ## Features

  - Real-time metrics aggregation
  - Cache hit rate tracking
  - Average chart generation time
  - Memory usage monitoring
  - Compression effectiveness tracking
  - Parallel processing performance

  ## Usage

      # Start the performance monitor
      PerformanceMonitor.start_link()

      # Get current metrics
      metrics = PerformanceMonitor.get_metrics()

      # Reset metrics
      PerformanceMonitor.reset_metrics()

  ## Telemetry Events

  This module attaches to the following telemetry events:

  - `[:ash_reports, :charts, :generate, :start]` - Chart generation started
  - `[:ash_reports, :charts, :generate, :stop]` - Chart generation completed
  - `[:ash_reports, :charts, :cache, :hit]` - Cache hit
  - `[:ash_reports, :charts, :cache, :miss]` - Cache miss
  - `[:ash_reports, :charts, :cache, :put_compressed]` - Compressed cache entry
  - `[:ash_reports, :chart_preprocessor, :preprocess, :start]` - Preprocessing started
  - `[:ash_reports, :chart_preprocessor, :preprocess, :stop]` - Preprocessing completed

  ## Metrics

  The `get_metrics/0` function returns a map with the following keys:

  - `:total_charts_generated` - Total number of charts generated
  - `:avg_generation_time_ms` - Average generation time in milliseconds
  - `:cache_hit_rate` - Cache hit rate (0.0 to 1.0)
  - `:cache_hits` - Total cache hits
  - `:cache_misses` - Total cache misses
  - `:avg_compression_ratio` - Average compression ratio
  - `:total_compressed_entries` - Total compressed cache entries
  - `:avg_preprocessing_time_ms` - Average preprocessing time for multi-chart reports
  - `:memory_usage_bytes` - Approximate memory usage of cached charts
  """

  use GenServer
  require Logger

  @table_name :ash_reports_performance_metrics

  # Client API

  @doc """
  Starts the performance monitor GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets current performance metrics.

  ## Returns

  Map containing performance metrics:
    - `:total_charts_generated` - Total number of charts generated
    - `:avg_generation_time_ms` - Average generation time in milliseconds
    - `:cache_hit_rate` - Cache hit rate (0.0 to 1.0)
    - `:cache_hits` - Total cache hits
    - `:cache_misses` - Total cache misses
    - `:avg_compression_ratio` - Average compression ratio
    - `:total_compressed_entries` - Total compressed cache entries
    - `:avg_preprocessing_time_ms` - Average preprocessing time
    - `:memory_usage_bytes` - Approximate memory usage

  ## Examples

      iex> PerformanceMonitor.get_metrics()
      %{
        total_charts_generated: 42,
        avg_generation_time_ms: 15.3,
        cache_hit_rate: 0.75,
        cache_hits: 30,
        cache_misses: 10,
        avg_compression_ratio: 0.35,
        total_compressed_entries: 20,
        avg_preprocessing_time_ms: 125.5,
        memory_usage_bytes: 512000
      }
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Resets all performance metrics to zero.

  Useful for benchmarking or testing.

  ## Examples

      iex> PerformanceMonitor.reset_metrics()
      :ok
  """
  @spec reset_metrics() :: :ok
  def reset_metrics do
    GenServer.call(__MODULE__, :reset_metrics)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for metrics storage
    :ets.new(@table_name, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Initialize all metric counters
    initialize_metrics()

    # Attach telemetry handlers
    attach_telemetry_handlers()

    Logger.debug("AshReports.Charts.PerformanceMonitor initialized")

    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = compute_metrics()
    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:reset_metrics, _from, state) do
    initialize_metrics()
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Detach telemetry handlers on shutdown
    :telemetry.detach("ash_reports_chart_generate_start")
    :telemetry.detach("ash_reports_chart_generate_stop")
    :telemetry.detach("ash_reports_cache_hit")
    :telemetry.detach("ash_reports_cache_miss")
    :telemetry.detach("ash_reports_cache_put_compressed")
    :telemetry.detach("ash_reports_preprocess_start")
    :telemetry.detach("ash_reports_preprocess_stop")
    :ok
  end

  # Private Functions

  defp initialize_metrics do
    :ets.insert(@table_name, {:total_charts_generated, 0})
    :ets.insert(@table_name, {:total_generation_time, 0})
    :ets.insert(@table_name, {:cache_hits, 0})
    :ets.insert(@table_name, {:cache_misses, 0})
    # Store compression ratio as integer (scaled by 10000) for atomic operations
    # e.g., ratio 0.35 is stored as 3500
    :ets.insert(@table_name, {:total_compression_ratio_scaled, 0})
    :ets.insert(@table_name, {:total_compressed_entries, 0})
    :ets.insert(@table_name, {:total_preprocessing_time, 0})
    :ets.insert(@table_name, {:total_preprocessing_count, 0})
    :ets.insert(@table_name, {:memory_usage_bytes, 0})
  end

  defp attach_telemetry_handlers do
    # Chart generation start
    :telemetry.attach(
      "ash_reports_chart_generate_start",
      [:ash_reports, :charts, :generate, :start],
      &__MODULE__.handle_chart_generate_start/4,
      nil
    )

    # Chart generation stop
    :telemetry.attach(
      "ash_reports_chart_generate_stop",
      [:ash_reports, :charts, :generate, :stop],
      &__MODULE__.handle_chart_generate_stop/4,
      nil
    )

    # Cache hit
    :telemetry.attach(
      "ash_reports_cache_hit",
      [:ash_reports, :charts, :cache, :hit],
      &__MODULE__.handle_cache_hit/4,
      nil
    )

    # Cache miss
    :telemetry.attach(
      "ash_reports_cache_miss",
      [:ash_reports, :charts, :cache, :miss],
      &__MODULE__.handle_cache_miss/4,
      nil
    )

    # Cache put compressed
    :telemetry.attach(
      "ash_reports_cache_put_compressed",
      [:ash_reports, :charts, :cache, :put_compressed],
      &__MODULE__.handle_cache_put_compressed/4,
      nil
    )

    # Preprocessing start
    :telemetry.attach(
      "ash_reports_preprocess_start",
      [:ash_reports, :chart_preprocessor, :preprocess, :start],
      &__MODULE__.handle_preprocess_start/4,
      nil
    )

    # Preprocessing stop
    :telemetry.attach(
      "ash_reports_preprocess_stop",
      [:ash_reports, :chart_preprocessor, :preprocess, :stop],
      &__MODULE__.handle_preprocess_stop/4,
      nil
    )
  end

  defp compute_metrics do
    [{_, total_charts}] = :ets.lookup(@table_name, :total_charts_generated)
    [{_, total_gen_time}] = :ets.lookup(@table_name, :total_generation_time)
    [{_, cache_hits}] = :ets.lookup(@table_name, :cache_hits)
    [{_, cache_misses}] = :ets.lookup(@table_name, :cache_misses)
    [{_, total_comp_ratio_scaled}] = :ets.lookup(@table_name, :total_compression_ratio_scaled)
    [{_, total_comp_entries}] = :ets.lookup(@table_name, :total_compressed_entries)
    [{_, total_prep_time}] = :ets.lookup(@table_name, :total_preprocessing_time)
    [{_, total_prep_count}] = :ets.lookup(@table_name, :total_preprocessing_count)
    [{_, memory_usage}] = :ets.lookup(@table_name, :memory_usage_bytes)

    avg_generation_time =
      if total_charts > 0 do
        Float.round(total_gen_time / total_charts / 1_000_000, 2)
      else
        0.0
      end

    cache_hit_rate =
      if cache_hits + cache_misses > 0 do
        Float.round(cache_hits / (cache_hits + cache_misses), 3)
      else
        0.0
      end

    # Convert scaled integer back to float and calculate average
    avg_compression_ratio =
      if total_comp_entries > 0 do
        Float.round(total_comp_ratio_scaled / total_comp_entries / 10_000, 3)
      else
        0.0
      end

    avg_preprocessing_time =
      if total_prep_count > 0 do
        Float.round(total_prep_time / total_prep_count / 1_000_000, 2)
      else
        0.0
      end

    %{
      total_charts_generated: total_charts,
      avg_generation_time_ms: avg_generation_time,
      cache_hit_rate: cache_hit_rate,
      cache_hits: cache_hits,
      cache_misses: cache_misses,
      avg_compression_ratio: avg_compression_ratio,
      total_compressed_entries: total_comp_entries,
      avg_preprocessing_time_ms: avg_preprocessing_time,
      memory_usage_bytes: memory_usage
    }
  end

  # Telemetry Event Handlers

  @doc false
  def handle_chart_generate_start(_event, _measurements, _metadata, _config) do
    # Track chart generation start (could be used for in-flight tracking)
    :ok
  end

  @doc false
  def handle_chart_generate_stop(_event, measurements, metadata, _config) do
    # Only count non-cached charts (from_cache: false)
    if Map.get(metadata, :from_cache, false) == false do
      :ets.update_counter(@table_name, :total_charts_generated, {2, 1})
      :ets.update_counter(@table_name, :total_generation_time, {2, measurements.duration})

      # Update memory usage estimate (approximate based on SVG size)
      if svg_size = Map.get(metadata, :svg_size) do
        :ets.update_counter(@table_name, :memory_usage_bytes, {2, svg_size})
      end
    end

    :ok
  end

  @doc false
  def handle_cache_hit(_event, _measurements, _metadata, _config) do
    :ets.update_counter(@table_name, :cache_hits, {2, 1})
    :ok
  end

  @doc false
  def handle_cache_miss(_event, _measurements, _metadata, _config) do
    :ets.update_counter(@table_name, :cache_misses, {2, 1})
    :ok
  end

  @doc false
  def handle_cache_put_compressed(_event, measurements, _metadata, _config) do
    :ets.update_counter(@table_name, :total_compressed_entries, {2, 1})

    # Convert float ratio to scaled integer for atomic accumulation
    # e.g., 0.35 -> 3500, 0.4 -> 4000
    # This allows us to use atomic update_counter instead of read-modify-write
    ratio = Map.get(measurements, :ratio, 1.0)
    ratio_scaled = round(ratio * 10_000)
    :ets.update_counter(@table_name, :total_compression_ratio_scaled, {2, ratio_scaled})

    :ok
  end

  @doc false
  def handle_preprocess_start(_event, _measurements, _metadata, _config) do
    # Track preprocessing start
    :ok
  end

  @doc false
  def handle_preprocess_stop(_event, measurements, _metadata, _config) do
    :ets.update_counter(@table_name, :total_preprocessing_count, {2, 1})
    :ets.update_counter(@table_name, :total_preprocessing_time, {2, measurements.duration})
    :ok
  end
end
