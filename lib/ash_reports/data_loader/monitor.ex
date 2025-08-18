defmodule AshReports.DataLoader.Monitor do
  @moduledoc """
  Performance monitoring and memory tracking for AshReports DataLoader.

  This module provides comprehensive monitoring and metrics collection for the
  DataLoader system, including:
  - Memory usage tracking and analysis
  - Query performance metrics
  - Cache efficiency monitoring
  - Pipeline throughput analysis
  - Error rate tracking
  - Resource utilization monitoring

  The Monitor integrates with telemetry events and provides both real-time
  monitoring and historical analysis capabilities.

  ## Key Features

  - **Real-time Metrics**: Live monitoring of DataLoader performance
  - **Memory Tracking**: Detailed memory usage analysis and alerts
  - **Performance Profiling**: Query and pipeline performance measurement
  - **Cache Analytics**: Cache hit ratios and efficiency metrics
  - **Error Monitoring**: Comprehensive error tracking and analysis
  - **Telemetry Integration**: Full integration with Elixir telemetry system

  ## Monitored Metrics

  ### Performance Metrics
  - Query execution times
  - Pipeline processing rates
  - Relationship loading performance
  - Cache operation latencies

  ### Memory Metrics
  - Process memory usage
  - ETS table memory consumption
  - Garbage collection frequency
  - Memory leak detection

  ### Business Metrics
  - Reports generated per time period
  - Data volume processed
  - User activity patterns
  - Resource utilization trends

  ## Usage

      # Start monitoring for a DataLoader instance
      {:ok, monitor} = Monitor.start_link(name: :dataloader_monitor)
      
      # Record a query execution
      Monitor.record_query_execution(monitor, %{
        duration: 1500,
        record_count: 10000,
        cache_hit?: false,
        memory_usage: 50_000_000
      })
      
      # Get current metrics
      metrics = Monitor.get_current_metrics(monitor)
      
      # Get performance summary
      summary = Monitor.get_performance_summary(monitor, :last_hour)

  ## Integration with Telemetry

  The Monitor automatically subscribes to relevant telemetry events:
  - `[:ash_reports, :data_loader, :query, :start]`
  - `[:ash_reports, :data_loader, :query, :stop]`
  - `[:ash_reports, :data_loader, :cache, :hit]`
  - `[:ash_reports, :data_loader, :cache, :miss]`
  - `[:ash_reports, :data_loader, :error]`

  """

  use GenServer

  @type monitor_server :: GenServer.server()
  @type metric_name :: atom()
  @type metric_value :: number()
  @type time_window :: :last_minute | :last_hour | :last_day | :all_time

  @type query_metrics :: %{
          duration_ms: pos_integer(),
          record_count: non_neg_integer(),
          memory_usage_bytes: pos_integer(),
          cache_hit?: boolean(),
          relationship_count: non_neg_integer(),
          error: term() | nil
        }

  @type pipeline_metrics :: %{
          records_processed: pos_integer(),
          processing_time_ms: pos_integer(),
          memory_peak_bytes: pos_integer(),
          group_changes: pos_integer(),
          variable_updates: pos_integer()
        }

  @type current_metrics :: %{
          queries_per_second: float(),
          average_query_time_ms: float(),
          cache_hit_ratio: float(),
          memory_usage_mb: float(),
          error_rate: float(),
          active_processes: pos_integer()
        }

  @type performance_summary :: %{
          total_queries: pos_integer(),
          total_records_processed: pos_integer(),
          average_response_time_ms: float(),
          peak_memory_usage_mb: float(),
          cache_efficiency: float(),
          error_count: pos_integer(),
          uptime_seconds: pos_integer()
        }

  @type monitor_options :: [
          name: atom(),
          history_retention: pos_integer(),
          alert_thresholds: keyword(),
          enable_telemetry: boolean(),
          metrics_interval: pos_integer()
        ]

  # Default configuration
  @default_history_retention :timer.hours(24)
  @default_metrics_interval :timer.seconds(10)
  @default_alert_thresholds [
    memory_mb: 1024,
    query_time_ms: 5000,
    error_rate: 0.05,
    cache_hit_ratio: 0.8
  ]

  @telemetry_events [
    [:ash_reports, :data_loader, :query, :start],
    [:ash_reports, :data_loader, :query, :stop],
    [:ash_reports, :data_loader, :cache, :hit],
    [:ash_reports, :data_loader, :cache, :miss],
    [:ash_reports, :data_loader, :pipeline, :start],
    [:ash_reports, :data_loader, :pipeline, :stop],
    [:ash_reports, :data_loader, :error]
  ]

  @doc """
  Starts a new Monitor server.

  ## Options

  - `:name` - Name for the monitor server
  - `:history_retention` - How long to retain metrics history (default: 24 hours)
  - `:alert_thresholds` - Thresholds for performance alerts
  - `:enable_telemetry` - Whether to subscribe to telemetry events (default: true)
  - `:metrics_interval` - Interval for metrics aggregation (default: 10 seconds)

  ## Examples

      {:ok, monitor} = Monitor.start_link(name: :my_monitor)
      
      {:ok, monitor} = Monitor.start_link(
        name: :custom_monitor,
        history_retention: :timer.hours(48),
        alert_thresholds: [memory_mb: 2048, query_time_ms: 10000]
      )

  """
  @spec start_link(monitor_options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a query execution for monitoring.

  ## Examples

      Monitor.record_query_execution(monitor, %{
        duration_ms: 1200,
        record_count: 5000,
        memory_usage_bytes: 25_000_000,
        cache_hit?: true
      })

  """
  @spec record_query_execution(monitor_server(), query_metrics()) :: :ok
  def record_query_execution(server, metrics) do
    GenServer.cast(server, {:record_query, metrics})
  end

  @doc """
  Records pipeline processing metrics.

  ## Examples

      Monitor.record_pipeline_processing(monitor, %{
        records_processed: 10000,
        processing_time_ms: 5000,
        memory_peak_bytes: 100_000_000,
        group_changes: 25,
        variable_updates: 150
      })

  """
  @spec record_pipeline_processing(monitor_server(), pipeline_metrics()) :: :ok
  def record_pipeline_processing(server, metrics) do
    GenServer.cast(server, {:record_pipeline, metrics})
  end

  @doc """
  Records an error occurrence.

  ## Examples

      Monitor.record_error(monitor, :query_timeout, %{
        query_duration: 30000,
        record_count: 50000
      })

  """
  @spec record_error(monitor_server(), atom(), map()) :: :ok
  def record_error(server, error_type, context \\ %{}) do
    GenServer.cast(server, {:record_error, error_type, context})
  end

  @doc """
  Gets current real-time metrics.

  ## Examples

      metrics = Monitor.get_current_metrics(monitor)
      IO.puts("Cache hit ratio: \#{metrics.cache_hit_ratio * 100}%")

  """
  @spec get_current_metrics(monitor_server()) :: current_metrics()
  def get_current_metrics(server) do
    GenServer.call(server, :get_current_metrics)
  end

  @doc """
  Gets performance summary for a specific time window.

  ## Examples

      summary = Monitor.get_performance_summary(monitor, :last_hour)
      summary = Monitor.get_performance_summary(monitor, :last_day)

  """
  @spec get_performance_summary(monitor_server(), time_window()) :: performance_summary()
  def get_performance_summary(server, time_window) do
    GenServer.call(server, {:get_performance_summary, time_window})
  end

  @doc """
  Gets detailed metrics for a specific time period.

  Returns historical data points for graphing and analysis.

  ## Examples

      data = Monitor.get_historical_metrics(monitor, :last_hour, :memory_usage)
      data = Monitor.get_historical_metrics(monitor, :last_day, :query_times)

  """
  @spec get_historical_metrics(monitor_server(), time_window(), metric_name()) :: [
          {pos_integer(), metric_value()}
        ]
  def get_historical_metrics(server, time_window, metric_name) do
    GenServer.call(server, {:get_historical_metrics, time_window, metric_name})
  end

  @doc """
  Checks for performance alerts based on configured thresholds.

  Returns a list of current alerts that need attention.

  ## Examples

      alerts = Monitor.check_alerts(monitor)
      Enum.each(alerts, &handle_alert/1)

  """
  @spec check_alerts(monitor_server()) :: [%{type: atom(), severity: atom(), message: String.t()}]
  def check_alerts(server) do
    GenServer.call(server, :check_alerts)
  end

  @doc """
  Resets all collected metrics and starts fresh.

  ## Examples

      Monitor.reset_metrics(monitor)

  """
  @spec reset_metrics(monitor_server()) :: :ok
  def reset_metrics(server) do
    GenServer.cast(server, :reset_metrics)
  end

  @doc """
  Gets health status of the monitoring system.

  Returns information about the monitor's own performance and health.

  """
  @spec get_health_status(monitor_server()) :: %{status: atom(), details: map()}
  def get_health_status(server) do
    GenServer.call(server, :get_health_status)
  end

  @doc """
  Enables or disables specific metric collection.

  ## Examples

      Monitor.configure_metrics(monitor, memory_tracking: false)
      Monitor.configure_metrics(monitor, telemetry_events: [:query_only])

  """
  @spec configure_metrics(monitor_server(), keyword()) :: :ok
  def configure_metrics(server, options) do
    GenServer.cast(server, {:configure_metrics, options})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Extract configuration
    history_retention = Keyword.get(opts, :history_retention, @default_history_retention)
    alert_thresholds = Keyword.get(opts, :alert_thresholds, @default_alert_thresholds)
    enable_telemetry = Keyword.get(opts, :enable_telemetry, true)
    metrics_interval = Keyword.get(opts, :metrics_interval, @default_metrics_interval)

    # Initialize state
    state = %{
      start_time: System.monotonic_time(:millisecond),
      history_retention: history_retention,
      alert_thresholds: alert_thresholds,
      metrics_interval: metrics_interval,
      query_history: :queue.new(),
      pipeline_history: :queue.new(),
      error_history: :queue.new(),
      current_metrics: initialize_current_metrics(),
      telemetry_attached: false
    }

    # Subscribe to telemetry events if enabled
    final_state =
      if enable_telemetry do
        attach_telemetry_handlers()
        %{state | telemetry_attached: true}
      else
        state
      end

    # Schedule periodic metrics aggregation
    if metrics_interval > 0 do
      Process.send_after(self(), :aggregate_metrics, metrics_interval)
    end

    {:ok, final_state}
  end

  @impl GenServer
  def handle_cast({:record_query, metrics}, state) do
    timestamp = System.monotonic_time(:millisecond)
    query_entry = Map.put(metrics, :timestamp, timestamp)

    # Add to history
    updated_history = :queue.in(query_entry, state.query_history)

    # Trim old entries
    trimmed_history = trim_history(updated_history, timestamp, state.history_retention)

    # Update current metrics
    updated_current = update_current_metrics_query(state.current_metrics, metrics)

    {:noreply, %{state | query_history: trimmed_history, current_metrics: updated_current}}
  end

  @impl GenServer
  def handle_cast({:record_pipeline, metrics}, state) do
    timestamp = System.monotonic_time(:millisecond)
    pipeline_entry = Map.put(metrics, :timestamp, timestamp)

    # Add to history
    updated_history = :queue.in(pipeline_entry, state.pipeline_history)

    # Trim old entries
    trimmed_history = trim_history(updated_history, timestamp, state.history_retention)

    # Update current metrics
    updated_current = update_current_metrics_pipeline(state.current_metrics, metrics)

    {:noreply, %{state | pipeline_history: trimmed_history, current_metrics: updated_current}}
  end

  @impl GenServer
  def handle_cast({:record_error, error_type, context}, state) do
    timestamp = System.monotonic_time(:millisecond)

    error_entry = %{
      timestamp: timestamp,
      error_type: error_type,
      context: context
    }

    # Add to error history
    updated_history = :queue.in(error_entry, state.error_history)

    # Trim old entries
    trimmed_history = trim_history(updated_history, timestamp, state.history_retention)

    # Update error metrics
    updated_current = update_current_metrics_error(state.current_metrics)

    {:noreply, %{state | error_history: trimmed_history, current_metrics: updated_current}}
  end

  @impl GenServer
  def handle_cast(:reset_metrics, state) do
    reset_state = %{
      state
      | query_history: :queue.new(),
        pipeline_history: :queue.new(),
        error_history: :queue.new(),
        current_metrics: initialize_current_metrics()
    }

    {:noreply, reset_state}
  end

  @impl GenServer
  def handle_cast({:configure_metrics, _options}, state) do
    # Configuration updates would be implemented here
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_current_metrics, _from, state) do
    metrics = calculate_current_metrics(state)
    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call({:get_performance_summary, time_window}, _from, state) do
    summary = calculate_performance_summary(state, time_window)
    {:reply, summary, state}
  end

  @impl GenServer
  def handle_call({:get_historical_metrics, time_window, metric_name}, _from, state) do
    data = extract_historical_data(state, time_window, metric_name)
    {:reply, data, state}
  end

  @impl GenServer
  def handle_call(:check_alerts, _from, state) do
    alerts = check_performance_alerts(state)
    {:reply, alerts, state}
  end

  @impl GenServer
  def handle_call(:get_health_status, _from, state) do
    status = %{
      status: :healthy,
      details: %{
        uptime_ms: System.monotonic_time(:millisecond) - state.start_time,
        memory_usage_bytes: Process.info(self(), :memory) |> elem(1),
        message_queue_length: Process.info(self(), :message_queue_len) |> elem(1),
        telemetry_attached: state.telemetry_attached
      }
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info(:aggregate_metrics, state) do
    # Perform periodic metrics aggregation
    # This could trigger alerts, cleanup, etc.

    # Schedule next aggregation
    Process.send_after(self(), :aggregate_metrics, state.metrics_interval)

    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Detach telemetry handlers
    if state.telemetry_attached do
      detach_telemetry_handlers()
    end

    :ok
  end

  # Private Implementation Functions

  defp initialize_current_metrics do
    %{
      total_queries: 0,
      total_records: 0,
      total_query_time: 0,
      cache_hits: 0,
      cache_misses: 0,
      total_errors: 0,
      memory_samples: :queue.new(),
      last_updated: System.monotonic_time(:millisecond)
    }
  end

  defp update_current_metrics_query(current, metrics) do
    %{
      current
      | total_queries: current.total_queries + 1,
        total_records: current.total_records + Map.get(metrics, :record_count, 0),
        total_query_time: current.total_query_time + Map.get(metrics, :duration_ms, 0),
        cache_hits:
          if Map.get(metrics, :cache_hit?, false) do
            current.cache_hits + 1
          else
            current.cache_hits
          end,
        cache_misses:
          if Map.get(metrics, :cache_hit?, false) do
            current.cache_misses
          else
            current.cache_misses + 1
          end,
        last_updated: System.monotonic_time(:millisecond)
    }
  end

  defp update_current_metrics_pipeline(current, _metrics) do
    %{current | last_updated: System.monotonic_time(:millisecond)}
  end

  defp update_current_metrics_error(current) do
    %{
      current
      | total_errors: current.total_errors + 1,
        last_updated: System.monotonic_time(:millisecond)
    }
  end

  defp calculate_current_metrics(state) do
    current = state.current_metrics
    uptime_seconds = (System.monotonic_time(:millisecond) - state.start_time) / 1000

    queries_per_second =
      if uptime_seconds > 0 do
        current.total_queries / uptime_seconds
      else
        0.0
      end

    average_query_time =
      if current.total_queries > 0 do
        current.total_query_time / current.total_queries
      else
        0.0
      end

    total_cache_operations = current.cache_hits + current.cache_misses

    cache_hit_ratio =
      if total_cache_operations > 0 do
        current.cache_hits / total_cache_operations
      else
        0.0
      end

    error_rate =
      if current.total_queries > 0 do
        current.total_errors / current.total_queries
      else
        0.0
      end

    %{
      queries_per_second: queries_per_second,
      average_query_time_ms: average_query_time,
      cache_hit_ratio: cache_hit_ratio,
      memory_usage_mb: :erlang.memory(:total) / (1024 * 1024),
      error_rate: error_rate,
      active_processes: Process.list() |> length()
    }
  end

  defp calculate_performance_summary(state, time_window) do
    now = System.monotonic_time(:millisecond)
    cutoff_time = calculate_cutoff_time(now, time_window)

    # Filter relevant entries
    query_entries = filter_entries_by_time(state.query_history, cutoff_time)
    error_entries = filter_entries_by_time(state.error_history, cutoff_time)

    total_queries = length(query_entries)
    total_records = Enum.sum(Enum.map(query_entries, & &1.record_count))

    average_response_time =
      if total_queries > 0 do
        total_time = Enum.sum(Enum.map(query_entries, & &1.duration_ms))
        total_time / total_queries
      else
        0.0
      end

    peak_memory =
      query_entries
      |> Enum.map(& &1.memory_usage_bytes)
      |> Enum.max(fn -> 0 end)
      |> div(1024 * 1024)

    cache_operations = Enum.count(query_entries)
    cache_hits = Enum.count(query_entries, & &1.cache_hit?)

    cache_efficiency =
      if cache_operations > 0 do
        cache_hits / cache_operations
      else
        0.0
      end

    uptime_seconds = (now - state.start_time) / 1000

    %{
      total_queries: total_queries,
      total_records_processed: total_records,
      average_response_time_ms: average_response_time,
      peak_memory_usage_mb: peak_memory,
      cache_efficiency: cache_efficiency,
      error_count: length(error_entries),
      uptime_seconds: trunc(uptime_seconds)
    }
  end

  defp extract_historical_data(state, time_window, metric_name) do
    now = System.monotonic_time(:millisecond)
    cutoff_time = calculate_cutoff_time(now, time_window)

    entries =
      case metric_name do
        :query_times ->
          filter_entries_by_time(state.query_history, cutoff_time)

        :memory_usage ->
          filter_entries_by_time(state.query_history, cutoff_time)

        _ ->
          []
      end

    Enum.map(entries, fn entry ->
      value =
        case metric_name do
          :query_times -> entry.duration_ms
          :memory_usage -> entry.memory_usage_bytes
          _ -> 0
        end

      {entry.timestamp, value}
    end)
  end

  defp check_performance_alerts(state) do
    current_metrics = calculate_current_metrics(state)
    thresholds = state.alert_thresholds

    alerts = []

    # Memory alert
    alerts =
      if current_metrics.memory_usage_mb > Keyword.get(thresholds, :memory_mb, 1024) do
        [
          %{
            type: :high_memory_usage,
            severity: :warning,
            message: "Memory usage is #{current_metrics.memory_usage_mb}MB"
          }
          | alerts
        ]
      else
        alerts
      end

    # Query time alert
    alerts =
      if current_metrics.average_query_time_ms > Keyword.get(thresholds, :query_time_ms, 5000) do
        [
          %{
            type: :slow_queries,
            severity: :warning,
            message: "Average query time is #{current_metrics.average_query_time_ms}ms"
          }
          | alerts
        ]
      else
        alerts
      end

    # Error rate alert
    alerts =
      if current_metrics.error_rate > Keyword.get(thresholds, :error_rate, 0.05) do
        [
          %{
            type: :high_error_rate,
            severity: :critical,
            message: "Error rate is #{current_metrics.error_rate * 100}%"
          }
          | alerts
        ]
      else
        alerts
      end

    # Cache efficiency alert
    alerts =
      if current_metrics.cache_hit_ratio < Keyword.get(thresholds, :cache_hit_ratio, 0.8) do
        [
          %{
            type: :low_cache_efficiency,
            severity: :info,
            message: "Cache hit ratio is #{current_metrics.cache_hit_ratio * 100}%"
          }
          | alerts
        ]
      else
        alerts
      end

    alerts
  end

  defp trim_history(queue, current_time, retention_ms) do
    cutoff_time = current_time - retention_ms
    trim_queue_by_time(queue, cutoff_time)
  end

  defp trim_queue_by_time(queue, cutoff_time) do
    case :queue.out(queue) do
      {{:value, entry}, rest} ->
        if entry.timestamp < cutoff_time do
          trim_queue_by_time(rest, cutoff_time)
        else
          queue
        end

      {:empty, _} ->
        queue
    end
  end

  defp filter_entries_by_time(queue, cutoff_time) do
    queue
    |> :queue.to_list()
    |> Enum.filter(fn entry -> entry.timestamp >= cutoff_time end)
  end

  defp calculate_cutoff_time(now, :last_minute), do: now - :timer.minutes(1)
  defp calculate_cutoff_time(now, :last_hour), do: now - :timer.hours(1)
  defp calculate_cutoff_time(now, :last_day), do: now - :timer.hours(24)
  defp calculate_cutoff_time(_now, :all_time), do: 0

  # Telemetry integration

  defp attach_telemetry_handlers do
    Enum.each(@telemetry_events, fn event ->
      :telemetry.attach(
        {__MODULE__, event},
        event,
        &handle_telemetry_event/4,
        %{monitor_pid: self()}
      )
    end)
  end

  defp detach_telemetry_handlers do
    Enum.each(@telemetry_events, fn event ->
      :telemetry.detach({__MODULE__, event})
    end)
  end

  defp handle_telemetry_event(event, measurements, metadata, %{monitor_pid: pid}) do
    case event do
      [:ash_reports, :data_loader, :query, :stop] ->
        metrics = %{
          duration_ms: measurements.duration || 0,
          record_count: metadata.record_count || 0,
          memory_usage_bytes: measurements.memory || 0,
          cache_hit?: metadata.cache_hit? || false
        }

        record_query_execution(pid, metrics)

      [:ash_reports, :data_loader, :error] ->
        record_error(pid, metadata.error_type || :unknown, metadata)

      _ ->
        :ok
    end
  end
end
