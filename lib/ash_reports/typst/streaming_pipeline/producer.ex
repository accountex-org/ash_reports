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

  alias AshReports.Typst.StreamingPipeline.{
    HealthMonitor,
    QueryCache,
    Registry,
    RelationshipLoader
  }

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
  - `:enable_cache` - Enable query result caching (default: true)
  - `:memory_limit` - Per-stream memory limit in bytes (default: 500MB)
  - `:max_retries` - Maximum retry attempts for failed queries (default: 3)
  - `:load_config` - Relationship loading configuration (default: nil)
    - `:strategy` - `:eager`, `:lazy`, or `:selective` (default: `:selective`)
    - `:max_depth` - Maximum relationship depth (default: 3)
    - `:required` - Required relationships to preload (default: [])
    - `:optional` - Optional relationships (default: [])
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
    enable_cache = Keyword.get(opts, :enable_cache, true)
    memory_limit = Keyword.get(opts, :memory_limit, default_memory_limit())
    max_retries = Keyword.get(opts, :max_retries, 3)
    load_config = Keyword.get(opts, :load_config, nil)

    # Apply relationship loading strategy if configured
    enhanced_query =
      if load_config do
        Logger.debug(
          "Producer #{stream_id} applying relationship loading strategy: #{inspect(load_config)}"
        )

        RelationshipLoader.apply_load_strategy(query, load_config)
      else
        query
      end

    # Register this producer with the Registry
    Registry.update_producer_consumer(stream_id, self())

    # Schedule memory checks
    schedule_memory_check()

    state = %{
      domain: domain,
      resource: resource,
      query: enhanced_query,
      stream_id: stream_id,
      chunk_size: chunk_size,
      metadata: metadata,
      offset: 0,
      total_fetched: 0,
      completed: false,
      paused: false,
      enable_cache: enable_cache,
      memory_limit: memory_limit,
      max_retries: max_retries,
      retry_count: 0,
      degraded_mode: false,
      load_config: load_config
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
    # Adjust chunk size if in degraded mode
    effective_chunk_size =
      if state.degraded_mode do
        max(div(state.chunk_size, 2), 100)
      else
        state.chunk_size
      end

    # Fetch next chunk
    chunk_result =
      execute_chunked_query(
        state.domain,
        state.query,
        state.offset,
        effective_chunk_size,
        state
      )

    case chunk_result do
      {:ok, []} ->
        # No more data available
        {Enum.reverse(acc), state}

      {:ok, records} ->
        new_offset = state.offset + length(records)
        new_total = state.total_fetched + length(records)
        new_state = %{state | offset: new_offset, total_fetched: new_total, retry_count: 0}

        # Check memory usage and enable degraded mode if needed
        memory_usage = get_process_memory()

        new_state =
          if memory_usage > state.memory_limit * 0.8 do
            Logger.warning(
              "Producer #{state.stream_id} entering degraded mode (memory: #{memory_usage})"
            )

            %{new_state | degraded_mode: true}
          else
            %{new_state | degraded_mode: false}
          end

        # If we got fewer records than chunk_size, we've reached the end
        if length(records) < effective_chunk_size do
          {Enum.reverse(records ++ acc), new_state}
        else
          # Continue fetching if we still need more records
          new_acc = records ++ acc
          fetch_records(records_needed - length(records), new_state, new_acc)
        end

      {:error, reason} ->
        # Handle retries
        if state.retry_count < state.max_retries do
          Logger.warning(
            "Producer #{state.stream_id} retrying after error (attempt #{state.retry_count + 1}/#{state.max_retries}): #{inspect(reason)}"
          )

          # Exponential backoff
          backoff = (:timer.seconds(1) * :math.pow(2, state.retry_count)) |> round()
          Process.sleep(backoff)

          # Retry with updated retry count
          new_state = %{state | retry_count: state.retry_count + 1}
          fetch_records(records_needed, new_state, acc)
        else
          Logger.debug(fn ->
            "Producer #{state.stream_id} failed after #{state.max_retries} retries: #{inspect(reason)}"
          end)

          Logger.error("Producer #{state.stream_id} failed after #{state.max_retries} retries")

          :telemetry.execute(
            [:ash_reports, :streaming, :producer, :error],
            %{offset: state.offset, retry_count: state.retry_count},
            %{stream_id: state.stream_id, reason: reason}
          )

          HealthMonitor.emit_exception(state.stream_id, elapsed_time(state), reason)
          Registry.update_status(state.stream_id, :failed)

          # Cleanup resources before returning
          cleanup_resources(state)

          # Return what we have so far
          {Enum.reverse(acc), %{state | completed: true}}
        end
    end
  end

  defp execute_chunked_query(domain, query, offset, limit, state) do
    # Generate cache key if caching is enabled
    if state.enable_cache do
      cache_key = QueryCache.generate_key(domain, state.resource, query, offset, limit)

      case QueryCache.get(cache_key) do
        {:ok, cached_results} ->
          Logger.debug("Producer #{state.stream_id} cache hit for offset #{offset}")
          {:ok, cached_results}

        :miss ->
          Logger.debug("Producer #{state.stream_id} cache miss for offset #{offset}")
          execute_and_cache_query(domain, query, offset, limit, cache_key)
      end
    else
      execute_and_cache_query(domain, query, offset, limit, nil)
    end
  end

  defp execute_and_cache_query(domain, query, offset, limit, cache_key) do
    try do
      # Apply limit and offset to query
      chunked_query =
        query
        |> Ash.Query.limit(limit)
        |> Ash.Query.offset(offset)

      # Execute the query
      case Ash.read(chunked_query, domain: domain) do
        {:ok, results} ->
          # Cache the results if cache_key is provided
          if cache_key do
            QueryCache.put(cache_key, results)
          end

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

  defp default_memory_limit do
    config = Application.get_env(:ash_reports, :streaming, [])
    # Default to 500MB per pipeline
    Keyword.get(config, :max_memory_per_pipeline, 500_000_000)
  end

  defp cleanup_resources(state) do
    # Log cleanup operation
    Logger.debug("Producer #{state.stream_id} cleaning up resources")

    # Clear any cached queries for this stream
    # Note: QueryCache is global, so we just log this for observability
    # Actual cache cleanup happens via TTL and LRU eviction

    # Force garbage collection to free memory
    :erlang.garbage_collect(self())

    :ok
  end
end
