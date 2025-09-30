defmodule AshReports.Typst.StreamingPipeline do
  @moduledoc """
  Main API for creating and managing GenStage streaming pipelines.

  This module provides a high-level interface for streaming large datasets from Ash
  resources through a transformation pipeline to consumers. It handles:

  - Pipeline creation and lifecycle management
  - Producer-consumer stage coordination
  - Health monitoring and circuit breakers
  - Resource cleanup on completion/failure

  ## Architecture

  A streaming pipeline consists of three stages:

      Producer → ProducerConsumer → Consumer
      (Query)    (Transform)        (Your code)

  1. **Producer**: Fetches data from Ash resources in chunks
  2. **ProducerConsumer**: Transforms raw records
  3. **Consumer**: Your code that processes transformed data (e.g., renders to Typst)

  ## Usage

      # Basic usage: create a pipeline and consume the stream
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
        domain: MyApp.Reporting,
        resource: MyApp.Sales.Order,
        query: Ash.Query.filter(Order, status == :completed),
        transformer: &transform_order/1
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
  """

  require Logger

  alias AshReports.Typst.StreamingPipeline.{
    HealthMonitor,
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

  ## Options

  - `:domain` - The Ash domain module (required)
  - `:resource` - The Ash resource module (required)
  - `:query` - The Ash query to execute (required)
  - `:transformer` - Function to transform records (default: identity)
  - `:chunk_size` - Records per chunk (default: 1000)
  - `:max_demand` - ProducerConsumer max demand (default: 500)
  - `:report_config` - Additional config passed to transformer (optional)

  ## Returns

  - `{:ok, stream_id, stream}` - Pipeline started successfully, returns stream_id and Elixir Stream
  - `{:error, reason}` - Failed to start pipeline

  ## Examples

      # Basic usage
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
        domain: MyApp.Reporting,
        resource: Order,
        query: Ash.Query.filter(Order, status == :completed)
      )

      # With custom transformer
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
        domain: MyApp.Reporting,
        resource: Order,
        query: query,
        transformer: fn order ->
          %{
            id: order.id,
            total: Money.to_string(order.total),
            date: Calendar.strftime(order.date, "%Y-%m-%d")
          }
        end
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

  # Private Functions

  defp fetch_required(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_required_option, key}}
    end
  end

  defp extract_metadata(opts) do
    # Extract relevant metadata from options
    %{
      domain: Keyword.get(opts, :domain),
      resource: Keyword.get(opts, :resource),
      report_name: Keyword.get(opts, :report_name, :unknown),
      report_config: Keyword.get(opts, :report_config, %{})
    }
  end

  defp create_stream(producer_consumer_pid, _stream_id) do
    # Create an Elixir Stream from the ProducerConsumer
    GenStage.stream([{producer_consumer_pid, []}])
  end

  defp default_chunk_size do
    streaming_config = Application.get_env(:ash_reports, :streaming, [])
    Keyword.get(streaming_config, :chunk_size, 1000)
  end

  defp default_max_demand do
    streaming_config = Application.get_env(:ash_reports, :streaming, [])
    Keyword.get(streaming_config, :producer_consumer_max_demand, 500)
  end

  defp start_pipeline_stages(stream_id, producer_opts, max_demand, transformer, report_config) do
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
             report_config
           ) do
      {:ok, stream_id, stream}
    end
  end

  defp get_pipeline_supervisor(stream_id) do
    case Supervisor.pipeline_supervisor() do
      {:error, reason} ->
        Registry.deregister_pipeline(stream_id)
        {:error, {:supervisor_not_found, reason}}

      pipeline_supervisor_pid ->
        {:ok, pipeline_supervisor_pid}
    end
  end

  defp start_producer_stage(pipeline_supervisor_pid, producer_opts, stream_id) do
    case DynamicSupervisor.start_child(pipeline_supervisor_pid, {Producer, producer_opts}) do
      {:ok, producer_pid} ->
        {:ok, producer_pid}

      {:error, reason} ->
        Logger.error("Failed to start Producer: #{inspect(reason)}")
        Registry.deregister_pipeline(stream_id)
        {:error, {:producer_start_failed, reason}}
    end
  end

  defp start_producer_consumer_stage(
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
        Logger.error("Failed to start ProducerConsumer: #{inspect(reason)}")
        Registry.update_status(stream_id, :failed)
        {:error, {:producer_consumer_start_failed, reason}}
    end
  end
end
