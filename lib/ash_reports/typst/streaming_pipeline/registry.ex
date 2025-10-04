defmodule AshReports.Typst.StreamingPipeline.Registry do
  @moduledoc """
  ETS-based registry for tracking active streaming pipelines.

  This registry maintains state for all active streaming pipelines and provides:
  - Registration and deregistration of streaming pipelines
  - Process monitoring with automatic cleanup on termination
  - Query capabilities for pipeline management
  - Health status tracking

  ## ETS Schema

  The registry uses a `:public`, `:set` ETS table with the following structure:

      {:stream, stream_id, %{
        producer_pid: pid(),
        producer_consumer_pid: pid() | nil,
        status: :running | :paused | :completed | :failed,
        started_at: DateTime.t(),
        completed_at: DateTime.t() | nil,
        records_processed: non_neg_integer(),
        memory_usage: non_neg_integer(),
        last_updated_at: DateTime.t(),
        metadata: map()
      }}

  ## Examples

      # Register a new pipeline
      {:ok, stream_id} = Registry.register_pipeline(producer_pid, %{
        report_name: :sales_report,
        domain: MyApp.Domain
      })

      # Update pipeline status
      :ok = Registry.update_status(stream_id, :running)

      # Get pipeline info
      {:ok, info} = Registry.get_pipeline(stream_id)

      # List all active pipelines
      pipelines = Registry.list_pipelines()

      # Deregister (automatic on process termination)
      :ok = Registry.deregister_pipeline(stream_id)
  """

  use GenServer
  require Logger

  @table_name :streaming_pipeline_registry
  @cleanup_interval :timer.seconds(30)

  # Client API

  @doc """
  Starts the registry GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new streaming pipeline.

  Returns `{:ok, stream_id}` where `stream_id` is a unique identifier.
  Automatically monitors the producer process.
  """
  @spec register_pipeline(pid(), map()) :: {:ok, binary()} | {:error, term()}
  def register_pipeline(producer_pid, metadata \\ %{}) when is_pid(producer_pid) do
    GenServer.call(__MODULE__, {:register, producer_pid, metadata})
  end

  @doc """
  Updates the status of a pipeline.
  """
  @spec update_status(binary(), atom()) :: :ok | {:error, :not_found}
  def update_status(stream_id, status)
      when status in [:running, :paused, :completed, :failed] do
    GenServer.call(__MODULE__, {:update_status, stream_id, status})
  end

  @doc """
  Updates the producer_consumer PID for a pipeline.
  """
  @spec update_producer_consumer(binary(), pid()) :: :ok | {:error, :not_found}
  def update_producer_consumer(stream_id, producer_consumer_pid)
      when is_pid(producer_consumer_pid) do
    GenServer.call(__MODULE__, {:update_producer_consumer, stream_id, producer_consumer_pid})
  end

  @doc """
  Increments the records processed counter.
  """
  @spec increment_records(binary(), non_neg_integer()) :: :ok | {:error, :not_found}
  def increment_records(stream_id, count) when is_integer(count) and count > 0 do
    GenServer.call(__MODULE__, {:increment_records, stream_id, count})
  end

  @doc """
  Updates the memory usage for a pipeline.
  """
  @spec update_memory_usage(binary(), non_neg_integer()) :: :ok | {:error, :not_found}
  def update_memory_usage(stream_id, memory_bytes)
      when is_integer(memory_bytes) and memory_bytes >= 0 do
    GenServer.call(__MODULE__, {:update_memory, stream_id, memory_bytes})
  end

  @doc """
  Stores partition worker information for a partitioned pipeline.

  Used by horizontal scaling to track multiple worker PIDs for result merging.
  """
  @spec store_partition_workers(binary(), [map()]) :: :ok | {:error, :not_found}
  def store_partition_workers(stream_id, workers) when is_list(workers) do
    GenServer.call(__MODULE__, {:store_partition_workers, stream_id, workers})
  end

  @doc """
  Retrieves partition worker information for a partitioned pipeline.
  """
  @spec get_partition_workers(binary()) :: {:ok, [map()]} | {:error, :not_found}
  def get_partition_workers(stream_id) do
    GenServer.call(__MODULE__, {:get_partition_workers, stream_id})
  end

  @doc """
  Gets pipeline information by stream_id.
  """
  @spec get_pipeline(binary()) :: {:ok, map()} | {:error, :not_found}
  def get_pipeline(stream_id) do
    case :ets.lookup(@table_name, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] -> {:ok, info}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active pipelines.

  Options:
  - `:status` - Filter by status (:running, :paused, :completed, :failed)
  """
  @spec list_pipelines(keyword()) :: [map()]
  def list_pipelines(opts \\ []) do
    status_filter = Keyword.get(opts, :status)

    @table_name
    |> :ets.match({{:stream, :"$1"}, :"$2"})
    |> Enum.map(fn [stream_id, info] ->
      Map.put(info, :stream_id, stream_id)
    end)
    |> maybe_filter_by_status(status_filter)
  end

  @doc """
  Counts pipelines by status.

  Returns: %{running: 5, paused: 2, completed: 10, failed: 1}
  """
  @spec count_by_status() :: map()
  def count_by_status do
    list_pipelines()
    |> Enum.group_by(& &1.status)
    |> Map.new(fn {status, pipelines} -> {status, length(pipelines)} end)
    |> Map.merge(%{running: 0, paused: 0, completed: 0, failed: 0}, fn _k, v1, _v2 -> v1 end)
  end

  @doc """
  Deregisters a pipeline.

  This is typically called automatically when a monitored process terminates.
  """
  @spec deregister_pipeline(binary()) :: :ok
  def deregister_pipeline(stream_id) do
    GenServer.call(__MODULE__, {:deregister, stream_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    table =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: false
      ])

    # Schedule periodic cleanup
    schedule_cleanup()

    state = %{
      table: table,
      # %{monitor_ref => stream_id}
      monitors: %{}
    }

    Logger.info("StreamingPipeline.Registry started successfully")

    {:ok, state}
  end

  @impl true
  def handle_call({:register, producer_pid, metadata}, _from, state) do
    stream_id = generate_stream_id()
    monitor_ref = Process.monitor(producer_pid)

    pipeline_info = %{
      producer_pid: producer_pid,
      producer_consumer_pid: nil,
      status: :running,
      started_at: DateTime.utc_now(),
      completed_at: nil,
      records_processed: 0,
      memory_usage: 0,
      last_updated_at: DateTime.utc_now(),
      metadata: metadata
    }

    :ets.insert(state.table, {{:stream, stream_id}, pipeline_info})

    new_state = %{state | monitors: Map.put(state.monitors, monitor_ref, stream_id)}

    Logger.debug("Registered streaming pipeline: #{stream_id}")

    {:reply, {:ok, stream_id}, new_state}
  end

  @impl true
  def handle_call({:update_status, stream_id, status}, _from, state) do
    case :ets.lookup(state.table, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] ->
        updated_info = %{
          info
          | status: status,
            completed_at:
              if(status in [:completed, :failed], do: DateTime.utc_now(), else: info.completed_at),
            last_updated_at: DateTime.utc_now()
        }

        :ets.insert(state.table, {{:stream, stream_id}, updated_info})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:update_producer_consumer, stream_id, producer_consumer_pid}, _from, state) do
    case :ets.lookup(state.table, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] ->
        # Monitor the producer_consumer as well
        Process.monitor(producer_consumer_pid)

        updated_info = %{
          info
          | producer_consumer_pid: producer_consumer_pid,
            last_updated_at: DateTime.utc_now()
        }

        :ets.insert(state.table, {{:stream, stream_id}, updated_info})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:increment_records, stream_id, count}, _from, state) do
    case :ets.lookup(state.table, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] ->
        updated_info = %{
          info
          | records_processed: info.records_processed + count,
            last_updated_at: DateTime.utc_now()
        }

        :ets.insert(state.table, {{:stream, stream_id}, updated_info})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:update_memory, stream_id, memory_bytes}, _from, state) do
    case :ets.lookup(state.table, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] ->
        updated_info = %{info | memory_usage: memory_bytes, last_updated_at: DateTime.utc_now()}
        :ets.insert(state.table, {{:stream, stream_id}, updated_info})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:deregister, stream_id}, _from, state) do
    :ets.delete(state.table, {:stream, stream_id})
    Logger.debug("Deregistered streaming pipeline: #{stream_id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_partition_workers, stream_id, workers}, _from, state) do
    case :ets.lookup(state.table, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] ->
        updated_info = %{
          info
          | partition_workers: workers,
            last_updated_at: DateTime.utc_now()
        }

        :ets.insert(state.table, {{:stream, stream_id}, updated_info})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_partition_workers, stream_id}, _from, state) do
    case :ets.lookup(state.table, {:stream, stream_id}) do
      [{{:stream, ^stream_id}, info}] ->
        workers = Map.get(info, :partition_workers, [])
        {:reply, {:ok, workers}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    case Map.get(state.monitors, monitor_ref) do
      nil ->
        {:noreply, state}

      stream_id ->
        # Update status to failed
        case :ets.lookup(state.table, {:stream, stream_id}) do
          [{{:stream, ^stream_id}, info}] ->
            updated_info = %{
              info
              | status: :failed,
                completed_at: DateTime.utc_now(),
                last_updated_at: DateTime.utc_now()
            }

            :ets.insert(state.table, {{:stream, stream_id}, updated_info})

          [] ->
            :ok
        end

        new_state = %{state | monitors: Map.delete(state.monitors, monitor_ref)}
        Logger.debug("Pipeline process terminated: #{stream_id}")
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up completed/failed pipelines older than 1 hour
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)

    @table_name
    |> :ets.match({{:stream, :"$1"}, :"$2"})
    |> Enum.each(fn [stream_id, info] ->
      if info.status in [:completed, :failed] and
           info.completed_at != nil and
           DateTime.compare(info.completed_at, cutoff_time) == :lt do
        :ets.delete(state.table, {:stream, stream_id})
        Logger.debug("Cleaned up old pipeline: #{stream_id}")
      end
    end)

    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp generate_stream_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp maybe_filter_by_status(pipelines, nil), do: pipelines

  defp maybe_filter_by_status(pipelines, status) do
    Enum.filter(pipelines, fn pipeline -> pipeline.status == status end)
  end
end
