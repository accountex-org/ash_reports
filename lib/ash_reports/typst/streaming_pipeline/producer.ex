defmodule AshReports.Typst.StreamingPipeline.Producer do
  @moduledoc """
  GenStage Producer for executing chunked Ash queries.

  This producer implements a demand-driven query execution strategy where:
  - Data is fetched from Ash resources in configurable chunk sizes
  - Backpressure is automatically handled by GenStage
  - Memory usage is monitored and circuit breakers are enforced
  - Telemetry events are emitted for observability

  ## Architecture

  The Producer acts as the data source in the streaming pipeline:

      Producer → ProducerConsumer → Consumer
      (Query)    (Transform)        (Render)

  ## Chunking Strategy

  Queries are executed in chunks using `limit` and `offset`:

      # Chunk 1: LIMIT 1000 OFFSET 0
      # Chunk 2: LIMIT 1000 OFFSET 1000
      # Chunk 3: LIMIT 1000 OFFSET 2000

  This prevents loading entire datasets into memory at once.

  ## Circuit Breaker

  The producer monitors memory usage and pauses when:
  - Memory threshold exceeded (configured via Registry)
  - Registry marks pipeline as `:paused`
  - Automatic resume when memory drops below threshold

  ## Configuration

      config :ash_reports, :streaming,
        chunk_size: 1000,
        max_memory_per_pipeline: 500_000_000  # 500MB

  ## Usage

  Producers are typically started via the StreamingPipeline API:

      {:ok, producer_pid} = StreamingPipeline.Producer.start_link(
        domain: MyApp.Reporting,
        resource: MyApp.Sales.Order,
        query: query,
        stream_id: "abc123",
        chunk_size: 1000
      )

  ## Telemetry

  Emits the following events:
  - `[:ash_reports, :streaming, :producer, :chunk_fetched]`
  - `[:ash_reports, :streaming, :producer, :completed]`
  - `[:ash_reports, :streaming, :producer, :error]`
  """

  use GenStage
  require Logger

  alias AshReports.Typst.StreamingPipeline.{HealthMonitor, Registry}

  @default_chunk_size 1000
  # Check memory every 1 second
  @memory_check_interval 1000

  # Client API

  @doc """
  Starts a Producer GenStage process.

  ## Options

  - `:domain` - The Ash domain module (required)
  - `:resource` - The Ash resource module (required)
  - `:query` - The Ash query to execute (required)
  - `:stream_id` - Unique identifier for this pipeline (required)
  - `:chunk_size` - Number of records per chunk (default: 1000)
  - `:metadata` - Additional metadata to track (default: %{})
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Extract required options
    domain = Keyword.fetch!(opts, :domain)
    resource = Keyword.fetch!(opts, :resource)
    query = Keyword.fetch!(opts, :query)
    stream_id = Keyword.fetch!(opts, :stream_id)

    # Extract optional configuration
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    metadata = Keyword.get(opts, :metadata, %{})

    # Register this producer with the Registry
    Registry.update_producer_consumer(stream_id, self())

    # Schedule memory checks
    schedule_memory_check()

    state = %{
      domain: domain,
      resource: resource,
      query: query,
      stream_id: stream_id,
      chunk_size: chunk_size,
      metadata: metadata,
      offset: 0,
      total_fetched: 0,
      completed: false,
      paused: false
    }

    Logger.debug("StreamingPipeline.Producer started for stream #{stream_id}")

    {:producer, state, dispatcher: GenStage.DemandDispatcher}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    # Check if paused (circuit breaker)
    case check_circuit_breaker(state.stream_id) do
      :paused ->
        Logger.debug("Producer #{state.stream_id} paused due to circuit breaker")
        # Reschedule to check again later
        Process.send_after(self(), :check_resume, 1000)
        {:noreply, [], %{state | paused: true}}

      :running ->
        fetch_and_emit_chunks(demand, state)
    end
  end

  @impl true
  def handle_info(:check_resume, state) do
    case check_circuit_breaker(state.stream_id) do
      :running ->
        Logger.info("Producer #{state.stream_id} resumed after circuit breaker")
        # Resume will happen naturally on next demand
        {:noreply, [], %{state | paused: false}}

      :paused ->
        # Still paused, check again later
        Process.send_after(self(), :check_resume, 1000)
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_info(:memory_check, state) do
    # Update memory usage in Registry
    memory_usage = get_process_memory()
    Registry.update_memory_usage(state.stream_id, memory_usage)

    schedule_memory_check()
    {:noreply, [], state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Producer #{state.stream_id} received unexpected message: #{inspect(msg)}")
    {:noreply, [], state}
  end

  # Private Functions

  defp fetch_and_emit_chunks(demand, state) do
    if state.completed do
      # No more data to fetch
      {:noreply, [], state}
    else
      # Calculate how many records we need to fulfill demand
      records_needed = demand

      # Fetch chunks until we have enough records or run out of data
      {events, new_state} = fetch_records(records_needed, state, [])

      if events == [] do
        # No more data available - mark as completed
        Logger.info(
          "Producer #{state.stream_id} completed (fetched #{new_state.total_fetched} total records)"
        )

        HealthMonitor.emit_stop(
          state.stream_id,
          :completed,
          elapsed_time(state),
          new_state.total_fetched
        )

        Registry.update_status(state.stream_id, :completed)

        {:noreply, events, %{new_state | completed: true}}
      else
        # Emit telemetry for chunk
        :telemetry.execute(
          [:ash_reports, :streaming, :producer, :chunk_fetched],
          %{records: length(events), offset: state.offset},
          %{stream_id: state.stream_id}
        )

        # Update records processed count
        Registry.increment_records(state.stream_id, length(events))

        {:noreply, events, new_state}
      end
    end
  end

  defp fetch_records(records_needed, state, acc) when records_needed <= 0 do
    # We have enough records
    {Enum.reverse(acc), state}
  end

  defp fetch_records(records_needed, state, acc) do
    # Fetch next chunk
    chunk_result =
      execute_chunked_query(
        state.domain,
        state.query,
        state.offset,
        state.chunk_size
      )

    case chunk_result do
      {:ok, []} ->
        # No more data available
        {Enum.reverse(acc), state}

      {:ok, records} ->
        new_offset = state.offset + length(records)
        new_total = state.total_fetched + length(records)
        new_state = %{state | offset: new_offset, total_fetched: new_total}

        # If we got fewer records than chunk_size, we've reached the end
        if length(records) < state.chunk_size do
          {Enum.reverse(records ++ acc), new_state}
        else
          # Continue fetching if we still need more records
          new_acc = records ++ acc
          fetch_records(records_needed - length(records), new_state, new_acc)
        end

      {:error, reason} ->
        Logger.error("Producer #{state.stream_id} failed to fetch chunk: #{inspect(reason)}")

        :telemetry.execute(
          [:ash_reports, :streaming, :producer, :error],
          %{offset: state.offset},
          %{stream_id: state.stream_id, reason: reason}
        )

        HealthMonitor.emit_exception(state.stream_id, elapsed_time(state), reason)
        Registry.update_status(state.stream_id, :failed)

        # Return what we have so far
        {Enum.reverse(acc), %{state | completed: true}}
    end
  end

  defp execute_chunked_query(domain, query, offset, limit) do
    try do
      # Apply limit and offset to query
      chunked_query =
        query
        |> Ash.Query.limit(limit)
        |> Ash.Query.offset(offset)

      # Execute the query
      case Ash.read(chunked_query, domain: domain) do
        {:ok, results} ->
          {:ok, results}

        {:error, error} ->
          {:error, error}
      end
    rescue
      exception ->
        {:error, exception}
    end
  end

  defp check_circuit_breaker(stream_id) do
    case Registry.get_pipeline(stream_id) do
      {:ok, %{status: :paused}} -> :paused
      {:ok, %{status: :running}} -> :running
      # Default to running for other statuses
      {:ok, %{status: _}} -> :running
      {:error, :not_found} -> :running
    end
  end

  defp get_process_memory do
    {:memory, bytes} = Process.info(self(), :memory)
    bytes
  end

  defp schedule_memory_check do
    Process.send_after(self(), :memory_check, @memory_check_interval)
  end

  defp elapsed_time(state) do
    # Get start time from registry
    case Registry.get_pipeline(state.stream_id) do
      {:ok, %{started_at: started_at}} ->
        DateTime.diff(DateTime.utc_now(), started_at, :millisecond)

      _ ->
        0
    end
  end
end
