defmodule AshReports.Typst.StreamingPipeline do
  @moduledoc """
  Main API for creating and managing GenStage streaming pipelines.

  This module provides a high-level interface for streaming large datasets from Ash
  resources through a transformation pipeline to consumers. It handles:

  - Pipeline creation and lifecycle management
  - Producer-consumer stage coordination
  - Health monitoring and circuit breakers
  - Resource cleanup on completion/failure

  **Design Note**: This module is designed for internal use by `AshReports.Typst.DataLoader`.
  Transformation functions are generated internally from DSL definitions, not provided
  by external callers. This ensures type safety and prevents arbitrary code execution.

  ## Architecture

  A streaming pipeline consists of three stages:

      Producer → ProducerConsumer → Consumer
      (Query)    (DSL Transform)    (Stream)

  1. **Producer**: Fetches data from Ash resources in chunks
  2. **ProducerConsumer**: Applies DSL-generated transformations
  3. **Consumer**: Elixir Stream for downstream consumption

  ## Usage

      # Typical usage (called internally by DataLoader):
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
        domain: MyApp.Reporting,
        resource: MyApp.Sales.Order,
        query: Ash.Query.filter(Order, status == :completed)
      )

      # Consume the stream
      stream
      |> Stream.chunk_every(100)
      |> Stream.each(&render_chunk/1)
      |> Stream.run()

      # Or use Enum
      orders = Enum.to_list(stream)

  ## Configuration

      config :ash_reports, :streaming,
        chunk_size: 1000,
        producer_consumer_max_demand: 500,
        memory_threshold: 500_000_000  # 500MB

  ## Pipeline Management

      # Get pipeline status
      {:ok, info} = StreamingPipeline.get_pipeline_info(stream_id)

      # Pause a pipeline (circuit breaker)
      :ok = StreamingPipeline.pause_pipeline(stream_id)

      # Resume a pipeline
      :ok = StreamingPipeline.resume_pipeline(stream_id)

      # Stop a pipeline early
      :ok = StreamingPipeline.stop_pipeline(stream_id)

      # List all active pipelines
      pipelines = StreamingPipeline.list_pipelines()

  ## Error Handling

  Pipelines automatically handle errors:
  - Query failures are logged and the pipeline marks as `:failed`
  - Transformation errors are logged, problematic records are skipped
  - Circuit breakers pause pipelines when memory thresholds are exceeded

  ## Telemetry

  Subscribe to telemetry events for observability:

      :telemetry.attach("pipeline-monitor", [:ash_reports, :streaming, :pipeline, :start], &handle_event/4, nil)

  Events emitted:
  - `[:ash_reports, :streaming, :pipeline, :start]`
  - `[:ash_reports, :streaming, :pipeline, :stop]`
  - `[:ash_reports, :streaming, :pipeline, :exception]`
  - `[:ash_reports, :streaming, :health_check]`
  - `[:ash_reports, :streaming, :producer, :chunk_fetched]`
  - `[:ash_reports, :streaming, :producer_consumer, :batch_transformed]`

  ## Usage Scenarios

  ### Scenario 1: Monitoring Long-Running Reports

  When generating large reports, you may want to show progress to users:

      # Start the pipeline
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(...)

      # Start async consumption in a Task
      task = Task.async(fn -> Enum.to_list(stream) end)

      # Poll for progress (e.g., every 500ms)
      defp poll_progress(stream_id) do
        case StreamingPipeline.get_aggregation_snapshot(stream_id) do
          {:ok, snapshot} ->
            IO.puts "Progress: \#{snapshot.progress.percent_complete}%"
            IO.puts "Records: \#{snapshot.progress.records_processed}"
            IO.puts "Status: \#{snapshot.progress.status}"

            unless snapshot.stable do
              Process.sleep(500)
              poll_progress(stream_id)
            end
          {:error, _} ->
            :timer.sleep(100)
            poll_progress(stream_id)
        end
      end

      # Wait for completion
      spawn(fn -> poll_progress(stream_id) end)
      results = Task.await(task, :infinity)

  ### Scenario 2: Phoenix LiveView Progress Updates

  Integrate pipeline progress with LiveView for real-time updates:

      # In your LiveView mount/3
      def mount(_params, _session, socket) do
        {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(...)

        # Schedule progress updates
        if connected?(socket) do
          :timer.send_interval(500, self(), :update_progress)
        end

        # Start async consumption
        Task.async(fn -> Enum.to_list(stream) end)

        {:ok, assign(socket, stream_id: stream_id, progress: 0)}
      end

      # Handle progress updates
      def handle_info(:update_progress, socket) do
        case StreamingPipeline.get_aggregation_snapshot(socket.assigns.stream_id) do
          {:ok, snapshot} ->
            progress = snapshot.progress.percent_complete || 0
            {:noreply, assign(socket, progress: progress)}
          {:error, _} ->
            {:noreply, socket}
        end
      end

  ### Scenario 3: Error Handling and Retry

  Handle pipeline failures gracefully:

      defp start_pipeline_with_retry(opts, max_retries \\\\ 3) do
        case StreamingPipeline.start_pipeline(opts) do
          {:ok, stream_id, stream} ->
            # Monitor the pipeline
            case consume_with_monitoring(stream_id, stream) do
              {:ok, results} -> {:ok, results}
              {:error, reason} -> retry_pipeline(opts, reason, max_retries)
            end
          {:error, reason} ->
            retry_pipeline(opts, reason, max_retries)
        end
      end

      defp consume_with_monitoring(stream_id, stream) do
        try do
          results = Enum.to_list(stream)

          # Check final status
          case StreamingPipeline.get_pipeline_info(stream_id) do
            {:ok, %{status: :completed}} -> {:ok, results}
            {:ok, %{status: :failed}} -> {:error, :pipeline_failed}
            _ -> {:ok, results}
          end
        rescue
          e -> {:error, e}
        end
      end

      defp retry_pipeline(_opts, _reason, 0), do: {:error, :max_retries_exceeded}
      defp retry_pipeline(opts, reason, retries_left) do
        Logger.warn("Pipeline failed: \#{inspect(reason)}, retrying...")
        :timer.sleep(1000)
        start_pipeline_with_retry(opts, retries_left - 1)
      end

  ### Scenario 4: Optimal Partition Count Configuration

  Configure partition_count based on workload characteristics:

      # For aggregation-heavy reports, use CPU core count
      defp determine_partition_count(report_config) do
        aggregation_count = length(report_config[:grouped_aggregations] || [])

        cond do
          # No aggregations - single worker sufficient
          aggregation_count == 0 -> 1

          # Light aggregations - 2-4 workers
          aggregation_count <= 5 -> min(4, System.schedulers_online())

          # Heavy aggregations - scale to cores
          aggregation_count > 5 -> System.schedulers_online()
        end
      end

      # Example usage
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
        domain: MyApp.Reporting,
        resource: Order,
        query: query,
        partition_count: determine_partition_count(report_config)
      )

  ### Scenario 5: Pipeline Dashboard

  Build a monitoring dashboard for all active pipelines:

      defmodule PipelineMonitor do
        def get_dashboard_stats do
          # Get overall counts
          counts = StreamingPipeline.pipeline_counts()

          # Get details for running pipelines
          running = StreamingPipeline.list_pipelines(status: :running)
          |> Enum.map(fn pipeline ->
            {:ok, snapshot} = StreamingPipeline.get_aggregation_snapshot(pipeline.stream_id)

            %{
              stream_id: pipeline.stream_id,
              report_name: pipeline.metadata.report_name,
              started_at: pipeline.started_at,
              progress: snapshot.progress.percent_complete,
              records_processed: snapshot.progress.records_processed,
              memory_usage: pipeline.memory_usage
            }
          end)

          %{
            counts: counts,
            running_pipelines: running,
            total_memory: Enum.sum(Enum.map(running, & &1.memory_usage))
          }
        end
      end

  ## Public API Summary

  This module provides three categories of public functions:

  **Pipeline Lifecycle** (for DataLoader and custom consumers):
  - `start_pipeline/1` - Create and start a new pipeline
  - `stop_pipeline/1` - Stop a pipeline early

  **Pipeline Monitoring** (for dashboards and progress tracking):
  - `get_pipeline_info/1` - Get status and progress for one pipeline
  - `list_pipelines/1` - List all active pipelines (optionally filtered)
  - `pipeline_counts/0` - Get counts by status (running, paused, completed, failed)

  **Pipeline Control** (for circuit breakers and error recovery):
  - `pause_pipeline/1` - Pause a running pipeline
  - `resume_pipeline/1` - Resume a paused pipeline

  **Aggregation Results** (for accessing streaming aggregations):
  - `get_aggregation_snapshot/1` - Get current state while streaming (for progress)
  - `get_aggregation_state/1` - Get final state after completion (for results)

  **Internal Functions**: All functions starting with `defp` are internal implementation
  details and should not be called directly. They are marked with `@doc false`.
  """

  require Logger

  alias AshReports.Typst.StreamingPipeline.{
    HealthMonitor,
    PartitionedProducerConsumer,
    Producer,
    ProducerConsumer,
    Registry,
    Supervisor
  }

  @type stream_id :: binary()
  @type pipeline_stream :: Enumerable.t()

  # Public API

  @doc """
  Starts a new streaming pipeline.

  Creates a Producer → ProducerConsumer → Stream pipeline for processing large datasets.

  **Note**: This function is designed for internal use by AshReports.Typst.DataLoader.
  The transformer function is generated internally from DSL definitions and should not
  be provided by external callers.

  ## Options

  - `:domain` - The Ash domain module (required)
  - `:resource` - The Ash resource module (required)
  - `:query` - The Ash query to execute (required)
  - `:chunk_size` - Records per chunk (default: 1000)
  - `:max_demand` - ProducerConsumer max demand (default: 500)
  - `:partition_count` - Number of parallel workers for aggregations (default: 1)

  **Internal Options** (used by DataLoader only):
  - `:transformer` - DSL-generated transformation function (internal use only)
  - `:report_config` - Report configuration (internal use only)

  ## Horizontal Scalability

  Set `:partition_count` to enable parallel aggregation processing:

      # 4 parallel workers (≈4x throughput for aggregations)
      StreamingPipeline.start_pipeline(
        domain: MyApp,
        resource: Order,
        query: query,
        partition_count: 4
      )

  Recommended: partition_count = number of CPU cores

  ## Partition Count Best Practices

  Choose partition_count based on your workload:

  - **No aggregations**: Use 1 (default) - no benefit from parallelization
  - **Light aggregations (1-5)**: Use 2-4 workers - moderate speedup
  - **Heavy aggregations (5+)**: Use `System.schedulers_online()` - maximize throughput
  - **Large datasets (millions)**: Start with 4, scale up if CPU underutilized

  Rule of thumb: `partition_count = min(aggregation_count, System.schedulers_online())`

  ## Returns

  - `{:ok, stream_id, stream}` - Pipeline started successfully, returns stream_id and Elixir Stream
  - `{:error, reason}` - Failed to start pipeline

  ## Examples

      # Basic usage (typically called by DataLoader)
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
        domain: MyApp.Reporting,
        resource: Order,
        query: Ash.Query.filter(Order, status == :completed)
      )

      # Consume the stream
      results = Enum.to_list(stream)
  """
  @spec start_pipeline(keyword()) :: {:ok, stream_id(), pipeline_stream()} | {:error, term()}
  def start_pipeline(opts) do
    # Validate required options
    with {:ok, domain} <- fetch_required(opts, :domain),
         {:ok, resource} <- fetch_required(opts, :resource),
         {:ok, query} <- fetch_required(opts, :query) do
      # Extract optional configuration
      transformer = Keyword.get(opts, :transformer, &Function.identity/1)
      chunk_size = Keyword.get(opts, :chunk_size, default_chunk_size())
      max_demand = Keyword.get(opts, :max_demand, default_max_demand())
      report_config = Keyword.get(opts, :report_config, %{})
      metadata = extract_metadata(opts)

      # Register pipeline first (generates stream_id)
      case Registry.register_pipeline(self(), metadata) do
        {:ok, stream_id} ->
          Logger.info("Starting streaming pipeline #{stream_id}")

          # Emit start telemetry
          report_name = Map.get(metadata, :report_name, :unknown)
          HealthMonitor.emit_start(stream_id, report_name)

          # Start the Producer stage
          producer_opts = [
            domain: domain,
            resource: resource,
            query: query,
            stream_id: stream_id,
            chunk_size: chunk_size,
            metadata: metadata
          ]

          # Start the pipeline stages
          start_pipeline_stages(stream_id, producer_opts, max_demand, transformer, report_config)

        {:error, reason} ->
          {:error, {:registration_failed, reason}}
      end
    end
  end

  @doc """
  Gets information about a pipeline.

  Returns the current status, progress, and metadata for a pipeline.

  ## Examples

      {:ok, info} = StreamingPipeline.get_pipeline_info(stream_id)
      # => {:ok, %{
      #   status: :running,
      #   records_processed: 5000,
      #   memory_usage: 123456789,
      #   started_at: ~U[2025-01-15 10:30:00Z],
      #   metadata: %{report_name: :sales_report}
      # }}
  """
  @spec get_pipeline_info(stream_id()) :: {:ok, map()} | {:error, :not_found}
  def get_pipeline_info(stream_id) do
    Registry.get_pipeline(stream_id)
  end

  @doc """
  Lists all active pipelines, optionally filtered by status.

  ## Examples

      # All pipelines
      all = StreamingPipeline.list_pipelines()

      # Only running pipelines
      running = StreamingPipeline.list_pipelines(status: :running)

      # Only failed pipelines
      failed = StreamingPipeline.list_pipelines(status: :failed)
  """
  @spec list_pipelines(keyword()) :: [map()]
  def list_pipelines(opts \\ []) do
    Registry.list_pipelines(opts)
  end

  @doc """
  Pauses a running pipeline (circuit breaker).

  The Producer will stop fetching data until resumed.

  ## Circuit Breaker Pattern

  Commonly used when:
  - Memory usage exceeds threshold (automatic via HealthMonitor)
  - Downstream system becomes unavailable
  - Manual intervention needed for debugging

  Example:

      # Monitor memory and pause if threshold exceeded
      case StreamingPipeline.get_pipeline_info(stream_id) do
        {:ok, %{memory_usage: memory}} when memory > @max_memory ->
          StreamingPipeline.pause_pipeline(stream_id)
          # Trigger garbage collection, wait for memory to clear
          :erlang.garbage_collect()
          :timer.sleep(5000)
          StreamingPipeline.resume_pipeline(stream_id)
        _ ->
          :ok
      end

  ## Examples

      :ok = StreamingPipeline.pause_pipeline(stream_id)
  """
  @spec pause_pipeline(stream_id()) :: :ok | {:error, :not_found}
  def pause_pipeline(stream_id) do
    Logger.info("Pausing pipeline #{stream_id}")
    Registry.update_status(stream_id, :paused)
  end

  @doc """
  Resumes a paused pipeline.

  See `pause_pipeline/1` for the circuit breaker pattern and common use cases.

  ## Examples

      :ok = StreamingPipeline.resume_pipeline(stream_id)
  """
  @spec resume_pipeline(stream_id()) :: :ok | {:error, :not_found}
  def resume_pipeline(stream_id) do
    Logger.info("Resuming pipeline #{stream_id}")
    Registry.update_status(stream_id, :running)
  end

  @doc """
  Stops a pipeline early.

  Marks the pipeline as completed and stops the Producer/ProducerConsumer stages.

  ## Examples

      :ok = StreamingPipeline.stop_pipeline(stream_id)
  """
  @spec stop_pipeline(stream_id()) :: :ok | {:error, :not_found}
  def stop_pipeline(stream_id) do
    Logger.info("Stopping pipeline #{stream_id}")

    with {:ok, info} <- Registry.get_pipeline(stream_id) do
      # Stop the producer if it exists
      if info.producer_pid && Process.alive?(info.producer_pid) do
        GenStage.stop(info.producer_pid, :normal)
      end

      # Stop the producer_consumer if it exists
      if info.producer_consumer_pid && Process.alive?(info.producer_consumer_pid) do
        GenStage.stop(info.producer_consumer_pid, :normal)
      end

      Registry.update_status(stream_id, :completed)
    end
  end

  @doc """
  Gets the count of pipelines by status.

  ## Examples

      counts = StreamingPipeline.pipeline_counts()
      # => %{running: 5, paused: 2, completed: 10, failed: 1}
  """
  @spec pipeline_counts() :: map()
  def pipeline_counts do
    Registry.count_by_status()
  end

  @doc """
  Gets a snapshot of current aggregation state while streaming is in progress.

  This function can be called while streaming is still active to monitor progress.
  The returned state may be incomplete if streaming is not yet finished.

  ## Parameters

    * `stream_id` - The unique identifier for the pipeline

  ## Returns

    * `{:ok, snapshot}` - Current state snapshot with:
      - `:aggregations` - Current simple aggregations (may be incomplete)
      - `:grouped_aggregations` - Current grouped aggregations (may be incomplete)
      - `:progress` - Progress information:
        - `:records_processed` - Number of records processed so far
        - `:percent_complete` - Estimated completion (0-100), or nil if unknown
        - `:status` - Pipeline status (:running, :paused, :completed, :failed)
      - `:stable` - Boolean: true if final, false if still updating
    * `{:error, reason}` - Failed to retrieve snapshot

  ## Polling Frequency Recommendations

  - **LiveView updates**: Poll every 500-1000ms for smooth progress bars
  - **Logs/metrics**: Poll every 5-10 seconds to reduce overhead
  - **Dashboards**: Poll every 2-5 seconds for near-real-time updates

  Avoid polling faster than 100ms as it may impact pipeline performance.

  ## Examples

      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(...)

      # Start async consumption
      task = Task.async(fn -> Enum.to_list(stream) end)

      # Monitor progress while streaming
      {:ok, snapshot} = StreamingPipeline.get_aggregation_snapshot(stream_id)
      IO.puts "Progress: \#{snapshot.progress.percent_complete}%"
      IO.puts "Processed: \#{snapshot.progress.records_processed} records"
      IO.puts "Stable: \#{snapshot.stable}"

      # Wait for completion
      Task.await(task)

      # Get final stable results
      {:ok, final} = StreamingPipeline.get_aggregation_state(stream_id)
      final.stable  # => true
  """
  @spec get_aggregation_snapshot(stream_id()) ::
          {:ok, map()} | {:error, :not_found | :no_producer_consumer | term()}
  def get_aggregation_snapshot(stream_id) do
    with {:ok, pipeline_info} <- Registry.get_pipeline(stream_id) do
      # Get current aggregation state (may be incomplete)
      aggregation_result = get_current_aggregation_state(stream_id, pipeline_info)

      case aggregation_result do
        {:ok, agg_state} ->
          # Build snapshot with progress info
          snapshot = %{
            aggregations: agg_state.aggregations,
            grouped_aggregations: agg_state.grouped_aggregations,
            progress: %{
              records_processed: Map.get(pipeline_info, :records_processed, 0),
              percent_complete: calculate_progress_percentage(pipeline_info),
              status: Map.get(pipeline_info, :status, :running)
            },
            stable: Map.get(pipeline_info, :status) == :completed
          }

          {:ok, snapshot}

        error ->
          error
      end
    end
  end

  @doc """
  Retrieves the final aggregation state from a streaming pipeline.

  This function queries the ProducerConsumer to get the aggregation state after
  streaming completes. Use `get_aggregation_snapshot/1` to monitor progress
  while streaming is in progress.

  ## Parameters

    * `stream_id` - The unique identifier for the pipeline

  ## Returns

    * `{:ok, aggregation_data}` - Map containing aggregation state
    * `{:error, :not_found}` - Pipeline not found
    * `{:error, :no_producer_consumer}` - ProducerConsumer not available
    * `{:error, term()}` - Other errors

  ## Aggregation Data Format

  ```elixir
  %{
    aggregations: %{...},           # Global aggregations
    grouped_aggregations: %{...},   # Grouped aggregations by key
    group_counts: %{...},           # Count of unique groups
    total_transformed: 12345        # Total records processed
  }
  ```

  ## Examples

      # After streaming completes
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(...)
      Enum.to_list(stream)  # Drain the stream
      {:ok, agg_data} = StreamingPipeline.get_aggregation_state(stream_id)

      # Use for chart generation
      ChartDataCollector.convert_aggregations_to_charts(
        agg_data.grouped_aggregations,
        chart_configs
      )
  """
  @spec get_aggregation_state(stream_id()) ::
          {:ok, map()} | {:error, :not_found | :no_producer_consumer | term()}
  def get_aggregation_state(stream_id) do
    with {:ok, pipeline_info} <- Registry.get_pipeline(stream_id) do
      get_current_aggregation_state(stream_id, pipeline_info)
    end
  end

  # Private helper to get current aggregation state (used by both functions)
  @doc false
  defp get_current_aggregation_state(stream_id, pipeline_info) do
    # Check if this is a partitioned pipeline
    case Registry.get_partition_workers(stream_id) do
      {:ok, [_ | _] = workers} ->
        # Merge results from all partition workers
        PartitionedProducerConsumer.merge_partitions(workers)

      _ ->
        # Single worker pipeline
        with {:ok, producer_consumer_pid} <- get_producer_consumer_pid(pipeline_info) do
          try do
            GenStage.call(producer_consumer_pid, :get_aggregation_state, 5000)
          catch
            :exit, {:noproc, _} ->
              {:error, :producer_consumer_stopped}

            :exit, {:timeout, _} ->
              {:error, :timeout}
          end
        end
    end
  end

  # Calculate completion percentage for progress tracking
  # Returns nil when total record count is unavailable
  @doc false
  defp calculate_progress_percentage(pipeline_info) do
    total_records = Map.get(pipeline_info.metadata, :total_records)
    records_processed = Map.get(pipeline_info, :records_processed, 0)

    cond do
      # If completed, always 100%
      Map.get(pipeline_info, :status) == :completed ->
        100.0

      # If we have total count, calculate percentage
      is_integer(total_records) and total_records > 0 ->
        min(100.0, records_processed / total_records * 100.0)

      # Unknown total - return nil
      # Enhancement: Could estimate from query COUNT(*) before streaming
      true ->
        nil
    end
  end

  # Private Functions

  @doc false
  defp get_producer_consumer_pid(%{producer_consumer_pid: pid}) when is_pid(pid) do
    if Process.alive?(pid) do
      {:ok, pid}
    else
      {:error, :producer_consumer_stopped}
    end
  end

  defp get_producer_consumer_pid(_), do: {:error, :no_producer_consumer}

  @doc false
  defp fetch_required(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_required_option, key}}
    end
  end

  @doc false
  defp extract_metadata(opts) do
    # Extract relevant metadata from options
    %{
      domain: Keyword.get(opts, :domain),
      resource: Keyword.get(opts, :resource),
      report_name: Keyword.get(opts, :report_name, :unknown),
      report_config: Keyword.get(opts, :report_config, %{})
    }
  end

  @doc false
  defp create_stream(producer_consumer_pid, _stream_id) do
    # Create an Elixir Stream from the ProducerConsumer
    GenStage.stream([{producer_consumer_pid, []}])
  end

  @doc false
  defp default_chunk_size do
    streaming_config = Application.get_env(:ash_reports, :streaming, [])
    Keyword.get(streaming_config, :chunk_size, 1000)
  end

  @doc false
  defp default_max_demand do
    streaming_config = Application.get_env(:ash_reports, :streaming, [])
    Keyword.get(streaming_config, :producer_consumer_max_demand, 500)
  end

  @doc false
  defp start_pipeline_stages(stream_id, producer_opts, max_demand, transformer, report_config) do
    partition_count = Keyword.get(producer_opts, :partition_count, 1)

    with {:ok, pipeline_supervisor_pid} <- get_pipeline_supervisor(stream_id),
         {:ok, producer_pid} <-
           start_producer_stage(pipeline_supervisor_pid, producer_opts, stream_id),
         {:ok, stream} <-
           start_producer_consumer_stage(
             pipeline_supervisor_pid,
             stream_id,
             producer_pid,
             max_demand,
             transformer,
             report_config,
             partition_count
           ) do
      {:ok, stream_id, stream}
    end
  end

  @doc false
  defp get_pipeline_supervisor(stream_id) do
    case Supervisor.pipeline_supervisor() do
      {:error, reason} ->
        Registry.deregister_pipeline(stream_id)
        {:error, {:supervisor_not_found, reason}}

      pipeline_supervisor_pid ->
        {:ok, pipeline_supervisor_pid}
    end
  end

  @doc false
  defp start_producer_stage(pipeline_supervisor_pid, producer_opts, stream_id) do
    case DynamicSupervisor.start_child(pipeline_supervisor_pid, {Producer, producer_opts}) do
      {:ok, producer_pid} ->
        {:ok, producer_pid}

      {:error, reason} ->
        Logger.debug(fn -> "Failed to start Producer: #{inspect(reason)}" end)
        Logger.error("Failed to start Producer")
        Registry.deregister_pipeline(stream_id)
        {:error, {:producer_start_failed, reason}}
    end
  end

  @doc false
  defp start_producer_consumer_stage(
         pipeline_supervisor_pid,
         stream_id,
         producer_pid,
         max_demand,
         transformer,
         report_config,
         partition_count
       ) do
    grouped_aggregations = get_in(report_config, [:grouped_aggregations]) || []

    if partition_count > 1 and length(grouped_aggregations) > 0 do
      # Start partitioned workers for parallel aggregation processing
      start_partitioned_workers(
        stream_id,
        producer_pid,
        max_demand,
        transformer,
        report_config,
        partition_count
      )
    else
      # Start single ProducerConsumer (backward compatible)
      start_single_worker(
        pipeline_supervisor_pid,
        stream_id,
        producer_pid,
        max_demand,
        transformer,
        report_config
      )
    end
  end

  @doc false
  defp start_single_worker(
         pipeline_supervisor_pid,
         stream_id,
         producer_pid,
         max_demand,
         transformer,
         report_config
       ) do
    producer_consumer_opts = [
      stream_id: stream_id,
      subscribe_to: [{producer_pid, max_demand: max_demand}],
      transformer: transformer,
      report_config: report_config,
      max_demand: max_demand
    ]

    case DynamicSupervisor.start_child(
           pipeline_supervisor_pid,
           {ProducerConsumer, producer_consumer_opts}
         ) do
      {:ok, producer_consumer_pid} ->
        stream = create_stream(producer_consumer_pid, stream_id)
        {:ok, stream}

      {:error, reason} ->
        Logger.debug(fn -> "Failed to start ProducerConsumer: #{inspect(reason)}" end)
        Logger.error("Failed to start ProducerConsumer")
        Registry.update_status(stream_id, :failed)
        {:error, {:producer_consumer_start_failed, reason}}
    end
  end

  @doc false
  defp start_partitioned_workers(
         stream_id,
         producer_pid,
         max_demand,
         transformer,
         report_config,
         partition_count
       ) do
    partition_opts = [
      stream_id: stream_id,
      producer_pid: producer_pid,
      max_demand: max_demand,
      transformer: transformer,
      partition_count: partition_count,
      grouped_aggregations: get_in(report_config, [:grouped_aggregations]) || []
    ]

    case PartitionedProducerConsumer.start_partitions(partition_opts) do
      {:ok, workers} ->
        # Store worker info in registry for result merging
        Registry.store_partition_workers(stream_id, workers)

        # Create stream from first worker (all workers produce same transformed records)
        # Aggregations will be merged at the end via get_aggregation_state
        first_worker = hd(workers)
        stream = create_stream(first_worker.pid, stream_id)
        {:ok, stream}

      {:error, reason} ->
        Logger.debug(fn ->
          "Failed to start partitioned workers: #{inspect(reason)}"
        end)

        Logger.error("Failed to start partitioned ProducerConsumer workers")
        Registry.update_status(stream_id, :failed)
        {:error, {:partitioned_workers_start_failed, reason}}
    end
  end
end
