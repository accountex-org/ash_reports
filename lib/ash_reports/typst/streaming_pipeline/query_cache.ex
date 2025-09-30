defmodule AshReports.Typst.StreamingPipeline.QueryCache do
  @moduledoc """
  ETS-based query result caching for streaming pipelines.

  Caches query results to avoid re-executing identical queries across multiple
  streaming sessions. Uses TTL-based expiration and LRU eviction when cache
  size limits are reached.

  ## Features

  - **TTL-based expiration**: Cached entries expire after configurable time
  - **LRU eviction**: Least recently used entries evicted when cache is full
  - **Memory-aware**: Tracks cache size and enforces limits
  - **Query fingerprinting**: Generates unique keys from query structure

  ## Configuration

      config :ash_reports, :query_cache,
        enabled: true,
        ttl_seconds: 300,        # 5 minutes
        max_entries: 1000,
        max_memory_mb: 100

  ## Usage

      # Check cache before executing query
      case QueryCache.get(query_key) do
        {:ok, cached_results} ->
          cached_results

        :miss ->
          results = execute_query(query)
          QueryCache.put(query_key, results)
          results
      end
  """

  use GenServer
  require Logger

  @table_name :streaming_query_cache
  @cleanup_interval :timer.minutes(1)

  # Cache entry structure: {key, value, inserted_at, last_accessed_at, size_bytes}

  # Client API

  @doc """
  Starts the QueryCache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a cached query result.

  Returns `{:ok, result}` if found and not expired, `:miss` otherwise.
  """
  @spec get(binary()) :: {:ok, term()} | :miss
  def get(key) do
    if cache_enabled?() do
      GenServer.call(__MODULE__, {:get, key})
    else
      :miss
    end
  end

  @doc """
  Stores a query result in the cache.
  """
  @spec put(binary(), term()) :: :ok
  def put(key, value) do
    if cache_enabled?() do
      GenServer.cast(__MODULE__, {:put, key, value})
    else
      :ok
    end
  end

  @doc """
  Generates a cache key from a query structure.

  Creates a fingerprint based on the query's filter, sort, limit, and offset.
  """
  @spec generate_key(module(), module(), Ash.Query.t(), integer(), integer()) :: binary()
  def generate_key(domain, resource, query, offset, limit) do
    # Extract relevant query components for fingerprinting
    filter = query.filter
    sort = query.sort
    load = query.load

    fingerprint_data = %{
      domain: domain,
      resource: resource,
      filter: inspect(filter),
      sort: inspect(sort),
      load: inspect(load),
      offset: offset,
      limit: limit
    }

    # Generate hash
    :crypto.hash(:sha256, :erlang.term_to_binary(fingerprint_data))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Clears the entire cache.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Returns cache statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for cache
    table =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Schedule cleanup
    schedule_cleanup()

    state = %{
      table: table,
      stats: %{
        hits: 0,
        misses: 0,
        evictions: 0,
        size_bytes: 0,
        entry_count: 0
      }
    }

    Logger.info("QueryCache started successfully")

    {:ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    now = System.system_time(:second)
    ttl = cache_ttl()

    case :ets.lookup(@table_name, key) do
      [{^key, value, inserted_at, _last_accessed, size_bytes}] ->
        # Check if expired
        if now - inserted_at > ttl do
          # Expired - remove it
          :ets.delete(@table_name, key)

          new_stats =
            state.stats
            |> Map.update!(:misses, &(&1 + 1))
            |> Map.update!(:size_bytes, &(&1 - size_bytes))
            |> Map.update!(:entry_count, &(&1 - 1))

          {:reply, :miss, %{state | stats: new_stats}}
        else
          # Valid cache hit - update last accessed time
          :ets.insert(@table_name, {key, value, inserted_at, now, size_bytes})

          new_stats = Map.update!(state.stats, :hits, &(&1 + 1))

          {:reply, {:ok, value}, %{state | stats: new_stats}}
        end

      [] ->
        # Cache miss
        new_stats = Map.update!(state.stats, :misses, &(&1 + 1))
        {:reply, :miss, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)

    new_stats = %{
      hits: state.stats.hits,
      misses: state.stats.misses,
      evictions: state.stats.evictions,
      size_bytes: 0,
      entry_count: 0
    }

    {:reply, :ok, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    hit_rate =
      if state.stats.hits + state.stats.misses > 0 do
        state.stats.hits / (state.stats.hits + state.stats.misses) * 100
      else
        0.0
      end

    stats =
      state.stats
      |> Map.put(:hit_rate_percent, Float.round(hit_rate, 2))
      |> Map.put(:size_mb, Float.round(state.stats.size_bytes / 1_024_000, 2))

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:put, key, value}, state) do
    now = System.system_time(:second)
    size_bytes = estimate_size(value)

    # Check if we need to evict before inserting
    new_state =
      if should_evict?(state, size_bytes) do
        evict_lru_entries(state, size_bytes)
      else
        state
      end

    # Insert new entry
    :ets.insert(@table_name, {key, value, now, now, size_bytes})

    updated_stats =
      new_state.stats
      |> Map.update!(:size_bytes, &(&1 + size_bytes))
      |> Map.update!(:entry_count, &(&1 + 1))

    {:noreply, %{new_state | stats: updated_stats}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired entries
    now = System.system_time(:second)
    ttl = cache_ttl()

    expired_entries =
      @table_name
      |> :ets.tab2list()
      |> Enum.filter(fn {_key, _value, inserted_at, _last_accessed, _size} ->
        now - inserted_at > ttl
      end)

    # Delete expired entries and update stats
    {evicted_count, freed_bytes} =
      Enum.reduce(expired_entries, {0, 0}, fn {key, _value, _inserted, _accessed, size}, {count, bytes} ->
        :ets.delete(@table_name, key)
        {count + 1, bytes + size}
      end)

    new_stats =
      state.stats
      |> Map.update!(:size_bytes, &(&1 - freed_bytes))
      |> Map.update!(:entry_count, &(&1 - evicted_count))
      |> Map.update!(:evictions, &(&1 + evicted_count))

    if evicted_count > 0 do
      Logger.debug("QueryCache: Evicted #{evicted_count} expired entries (#{freed_bytes} bytes)")
    end

    schedule_cleanup()
    {:noreply, %{state | stats: new_stats}}
  end

  # Private Functions

  defp cache_enabled? do
    config = Application.get_env(:ash_reports, :query_cache, [])
    Keyword.get(config, :enabled, true)
  end

  defp cache_ttl do
    config = Application.get_env(:ash_reports, :query_cache, [])
    Keyword.get(config, :ttl_seconds, 300)
  end

  defp max_entries do
    config = Application.get_env(:ash_reports, :query_cache, [])
    Keyword.get(config, :max_entries, 1000)
  end

  defp max_memory_bytes do
    config = Application.get_env(:ash_reports, :query_cache, [])
    max_mb = Keyword.get(config, :max_memory_mb, 100)
    max_mb * 1_024_000
  end

  defp should_evict?(state, new_entry_size) do
    state.stats.entry_count >= max_entries() or
      state.stats.size_bytes + new_entry_size > max_memory_bytes()
  end

  defp evict_lru_entries(state, needed_space) do
    # Get all entries sorted by last accessed time (LRU first)
    entries =
      @table_name
      |> :ets.tab2list()
      |> Enum.sort_by(fn {_key, _value, _inserted, last_accessed, _size} -> last_accessed end)

    # Calculate how many entries to evict
    target_entries = max(state.stats.entry_count - max_entries() + 1, 0)
    target_bytes = max(state.stats.size_bytes + needed_space - max_memory_bytes(), 0)

    # Evict entries until we meet targets
    {evicted_count, freed_bytes} =
      entries
      |> Enum.reduce_while({0, 0}, fn {key, _value, _inserted, _accessed, size}, {count, bytes} ->
        if count < target_entries or bytes < target_bytes do
          :ets.delete(@table_name, key)
          {:cont, {count + 1, bytes + size}}
        else
          {:halt, {count, bytes}}
        end
      end)

    new_stats =
      state.stats
      |> Map.update!(:size_bytes, &(&1 - freed_bytes))
      |> Map.update!(:entry_count, &(&1 - evicted_count))
      |> Map.update!(:evictions, &(&1 + evicted_count))

    if evicted_count > 0 do
      Logger.debug("QueryCache: Evicted #{evicted_count} LRU entries (#{freed_bytes} bytes)")
    end

    %{state | stats: new_stats}
  end

  defp estimate_size(value) do
    # Rough estimate of memory size
    byte_size(:erlang.term_to_binary(value))
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end