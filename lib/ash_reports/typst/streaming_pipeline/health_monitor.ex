defmodule AshReports.Typst.StreamingPipeline.HealthMonitor do
  @moduledoc """
  Health monitoring and telemetry for streaming pipelines.

  The HealthMonitor periodically checks the health of all active streaming pipelines and:
  - Tracks memory usage and enforces circuit breakers
  - Monitors throughput (records/second)
  - Detects stalled pipelines
  - Emits telemetry events for observability
  - Takes automatic corrective actions for unhealthy pipelines

  ## Telemetry Events

  The following telemetry events are emitted:

  - `[:ash_reports, :streaming, :pipeline, :start]` - Pipeline started
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{stream_id: binary(), report_name: atom()}`

  - `[:ash_reports, :streaming, :pipeline, :stop]` - Pipeline completed
    - Measurements: `%{duration: integer(), records_processed: integer()}`
    - Metadata: `%{stream_id: binary(), status: atom()}`

  - `[:ash_reports, :streaming, :pipeline, :exception]` - Pipeline failed
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{stream_id: binary(), reason: term()}`

  - `[:ash_reports, :streaming, :health_check]` - Periodic health check
    - Measurements: `%{active_pipelines: integer(), total_memory: integer()}`
    - Metadata: `%{timestamp: DateTime.t()}`

  - `[:ash_reports, :streaming, :memory_warning]` - Memory threshold exceeded
    - Measurements: `%{memory_usage: integer(), threshold: integer()}`
    - Metadata: `%{stream_id: binary(), action: :throttle | :pause}`

  - `[:ash_reports, :streaming, :throughput]` - Throughput measurement
    - Measurements: `%{records_per_second: float()}`
    - Metadata: `%{stream_id: binary()}`

  ## Circuit Breaker Logic

  When a pipeline exceeds the memory threshold:
  1. Emit `:memory_warning` telemetry
  2. Update pipeline status to `:paused`
  3. Log warning message
  4. The Producer will automatically pause production based on registry status

  ## Configuration

  Configure in your application config:

      config :ash_reports, :streaming,
        health_check_interval: 5_000,  # 5 seconds
        memory_threshold: 500_000_000, # 500MB per pipeline
        stall_timeout: 30_000          # 30 seconds
  """

  use GenServer
  require Logger

  alias AshReports.Typst.StreamingPipeline.Registry

  @default_health_check_interval :timer.seconds(5)
  # 500MB
  @default_memory_threshold 500_000_000
  @default_stall_timeout :timer.seconds(30)

  # Client API

  @doc """
  Starts the HealthMonitor GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Emits a pipeline start telemetry event.
  """
  @spec emit_start(binary(), atom()) :: :ok
  def emit_start(stream_id, report_name) do
    :telemetry.execute(
      [:ash_reports, :streaming, :pipeline, :start],
      %{system_time: System.system_time()},
      %{stream_id: stream_id, report_name: report_name}
    )
  end

  @doc """
  Emits a pipeline stop telemetry event.
  """
  @spec emit_stop(binary(), atom(), integer(), integer()) :: :ok
  def emit_stop(stream_id, status, duration_ms, records_processed) do
    :telemetry.execute(
      [:ash_reports, :streaming, :pipeline, :stop],
      %{duration: duration_ms, records_processed: records_processed},
      %{stream_id: stream_id, status: status}
    )
  end

  @doc """
  Emits a pipeline exception telemetry event.
  """
  @spec emit_exception(binary(), integer(), term()) :: :ok
  def emit_exception(stream_id, duration_ms, reason) do
    :telemetry.execute(
      [:ash_reports, :streaming, :pipeline, :exception],
      %{duration: duration_ms},
      %{stream_id: stream_id, reason: reason}
    )
  end

  @doc """
  Emits a throughput telemetry event.
  """
  @spec emit_throughput(binary(), float()) :: :ok
  def emit_throughput(stream_id, records_per_second) do
    :telemetry.execute(
      [:ash_reports, :streaming, :throughput],
      %{records_per_second: records_per_second},
      %{stream_id: stream_id}
    )
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Get configuration
    streaming_config = Application.get_env(:ash_reports, :streaming, [])

    health_check_interval =
      Keyword.get(streaming_config, :health_check_interval, @default_health_check_interval)

    memory_threshold = Keyword.get(streaming_config, :memory_threshold, @default_memory_threshold)
    stall_timeout = Keyword.get(streaming_config, :stall_timeout, @default_stall_timeout)

    state = %{
      health_check_interval: health_check_interval,
      memory_threshold: memory_threshold,
      stall_timeout: stall_timeout,
      last_check: DateTime.utc_now()
    }

    # Schedule first health check
    schedule_health_check(health_check_interval)

    Logger.info("StreamingPipeline.HealthMonitor started successfully")

    {:ok, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    perform_health_check(state)
    schedule_health_check(state.health_check_interval)
    {:noreply, %{state | last_check: DateTime.utc_now()}}
  end

  # Private Functions

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  defp perform_health_check(state) do
    pipelines = Registry.list_pipelines(status: :running)
    active_count = length(pipelines)

    # Calculate total memory usage
    total_memory =
      Enum.reduce(pipelines, 0, fn pipeline, acc ->
        acc + (pipeline.memory_usage || 0)
      end)

    # Emit health check telemetry
    :telemetry.execute(
      [:ash_reports, :streaming, :health_check],
      %{active_pipelines: active_count, total_memory: total_memory},
      %{timestamp: DateTime.utc_now()}
    )

    # Check each pipeline for issues
    Enum.each(pipelines, fn pipeline ->
      check_pipeline_memory(pipeline, state)
      check_pipeline_stall(pipeline, state)
      calculate_throughput(pipeline)
    end)
  end

  defp check_pipeline_memory(pipeline, state) do
    memory_usage = pipeline.memory_usage || 0

    if memory_usage > state.memory_threshold do
      Logger.warning(
        "Pipeline #{pipeline.stream_id} exceeded memory threshold: #{format_bytes(memory_usage)}"
      )

      # Emit memory warning telemetry
      :telemetry.execute(
        [:ash_reports, :streaming, :memory_warning],
        %{memory_usage: memory_usage, threshold: state.memory_threshold},
        %{stream_id: pipeline.stream_id, action: :pause}
      )

      # Pause the pipeline (Producer will check status and pause)
      Registry.update_status(pipeline.stream_id, :paused)
    end
  end

  defp check_pipeline_stall(pipeline, state) do
    last_updated = pipeline.last_updated_at
    now = DateTime.utc_now()
    diff_ms = DateTime.diff(now, last_updated, :millisecond)

    if diff_ms > state.stall_timeout do
      Logger.warning(
        "Pipeline #{pipeline.stream_id} appears stalled (no updates for #{diff_ms}ms)"
      )

      # Emit stall warning (using exception event)
      :telemetry.execute(
        [:ash_reports, :streaming, :pipeline, :exception],
        %{duration: diff_ms},
        %{stream_id: pipeline.stream_id, reason: :stalled}
      )

      # Mark as failed
      Registry.update_status(pipeline.stream_id, :failed)
    end
  end

  defp calculate_throughput(pipeline) do
    started_at = pipeline.started_at
    now = DateTime.utc_now()
    duration_seconds = DateTime.diff(now, started_at, :second)

    if duration_seconds > 0 do
      records_per_second = pipeline.records_processed / duration_seconds
      emit_throughput(pipeline.stream_id, records_per_second)
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)}KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024 do
    "#{Float.round(bytes / (1024 * 1024), 2)}MB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / (1024 * 1024 * 1024), 2)}GB"
  end
end
