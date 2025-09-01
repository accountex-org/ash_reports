defmodule AshReports.DataLoader.Cache do
  @moduledoc """
  ETS-based result caching for AshReports DataLoader with performance optimization.

  This module provides high-performance caching for report data and query results
  using ETS (Erlang Term Storage) for memory-efficient storage and fast retrieval.
  The cache supports TTL (Time To Live) expiration, size limits, and efficient
  key generation for optimal cache hit ratios.

  ## Key Features

  - **ETS-Based Storage**: High-performance in-memory storage using ETS tables
  - **TTL Support**: Automatic expiration of cached entries based on time
  - **Size Management**: Configurable cache size limits with LRU eviction
  - **Smart Key Generation**: Intelligent cache key generation for optimal hit ratios
  - **Memory Monitoring**: Built-in memory usage tracking and optimization
  - **Cache Statistics**: Comprehensive metrics for monitoring and debugging

  ## Cache Strategies

  - **Query Results**: Cache raw query results for repeated identical queries
  - **Processed Data**: Cache processed pipeline results including variables and groups
  - **Relationship Data**: Cache relationship loading results for performance
  - **Report Metadata**: Cache report compilation and configuration data

  ## Usage

      # Start cache for a domain
      {:ok, cache} = Cache.start_link(name: :my_reports_cache)

      # Cache query results
      cache_key = Cache.build_key(report, params, :query_result)
      Cache.put(cache, cache_key, query_results, ttl: :timer.minutes(15))

      # Retrieve cached results
      case Cache.get(cache, cache_key) do
        {:hit, cached_results} -> cached_results
        :miss -> execute_query_and_cache_result()
      end

      # Cache with conditional update
      Cache.put_if_absent(cache, cache_key, expensive_computation_result)

  ## Performance Characteristics

  - **Get Operations**: O(1) average, O(log n) worst case
  - **Put Operations**: O(1) average, O(log n) worst case
  - **Memory Usage**: Configurable limits with automatic eviction
  - **TTL Processing**: Background cleanup with minimal performance impact

  """

  use GenServer

  @type cache_server :: GenServer.server()
  @type cache_key :: term()
  @type cache_value :: term()
  @type cache_result :: {:hit, cache_value()} | :miss
  @type cache_options :: [
          name: atom(),
          max_size: pos_integer(),
          default_ttl: pos_integer(),
          cleanup_interval: pos_integer(),
          memory_limit_mb: pos_integer()
        ]

  @type cache_entry :: %{
          key: cache_key(),
          value: cache_value(),
          inserted_at: pos_integer(),
          expires_at: pos_integer() | :never,
          access_count: pos_integer(),
          last_accessed: pos_integer()
        }

  @type cache_stats :: %{
          size: pos_integer(),
          memory_usage_bytes: pos_integer(),
          hit_count: pos_integer(),
          miss_count: pos_integer(),
          eviction_count: pos_integer(),
          hit_ratio: float()
        }

  # Default configuration
  @default_max_size 10_000
  @default_ttl :timer.minutes(30)
  @default_cleanup_interval :timer.minutes(5)
  @default_memory_limit_mb 256

  # ETS table configuration
  @table_options [:set, :public, :named_table, {:read_concurrency, true}]

  @doc """
  Starts a new cache server.

  ## Options

  - `:name` - Name for the cache server (required for named caches)
  - `:max_size` - Maximum number of entries (default: 10,000)
  - `:default_ttl` - Default TTL in milliseconds (default: 30 minutes)
  - `:cleanup_interval` - Background cleanup interval (default: 5 minutes)
  - `:memory_limit_mb` - Memory limit in MB (default: 256)

  ## Examples

      {:ok, pid} = Cache.start_link(name: :reports_cache)

      {:ok, pid} = Cache.start_link(
        name: :large_reports_cache,
        max_size: 50_000,
        default_ttl: :timer.hours(2),
        memory_limit_mb: 512
      )

  """
  @spec start_link(cache_options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Retrieves a value from the cache.

  Returns `{:hit, value}` if the key exists and has not expired,
  or `:miss` if the key doesn't exist or has expired.

  ## Examples

      case Cache.get(:reports_cache, cache_key) do
        {:hit, value} -> use_cached_value(value)
        :miss -> compute_and_cache_value()
      end

  """
  @spec get(cache_server(), cache_key()) :: cache_result()
  def get(server, key) do
    GenServer.call(server, {:get, key})
  end

  @doc """
  Stores a value in the cache.

  ## Options

  - `:ttl` - Time to live in milliseconds (overrides default)
  - `:replace` - Whether to replace existing entries (default: true)

  ## Examples

      Cache.put(:reports_cache, key, value)
      Cache.put(:reports_cache, key, value, ttl: :timer.hours(1))

  """
  @spec put(cache_server(), cache_key(), cache_value(), Keyword.t()) :: :ok
  def put(server, key, value, opts \\ []) do
    GenServer.cast(server, {:put, key, value, opts})
  end

  @doc """
  Stores a value only if the key doesn't already exist.

  Returns `:ok` if the value was stored, or `:exists` if the key already exists.

  """
  @spec put_if_absent(cache_server(), cache_key(), cache_value(), Keyword.t()) ::
          :ok | :exists
  def put_if_absent(server, key, value, opts \\ []) do
    GenServer.call(server, {:put_if_absent, key, value, opts})
  end

  @doc """
  Removes a specific key from the cache.

  """
  @spec delete(cache_server(), cache_key()) :: :ok
  def delete(server, key) do
    GenServer.cast(server, {:delete, key})
  end

  @doc """
  Clears all entries from the cache.

  """
  @spec clear(cache_server()) :: :ok
  def clear(server) do
    GenServer.cast(server, :clear)
  end

  @doc """
  Gets cache statistics for monitoring and debugging.

  """
  @spec stats(cache_server()) :: cache_stats()
  def stats(server) do
    GenServer.call(server, :stats)
  end

  @doc """
  Builds a cache key from report parameters and operation type.

  Generates consistent, hashable keys for caching report-related data.

  ## Examples

      key = Cache.build_key(report, params, :query_result)
      key = Cache.build_key(report, params, :processed_data, extra: "metadata")

  """
  @spec build_key(AshReports.Report.t(), map(), atom(), Keyword.t()) :: cache_key()
  def build_key(report, params, operation_type, opts \\ []) do
    base_key = %{
      report_name: report.name,
      driving_resource: report.driving_resource,
      params: normalize_params(params),
      operation: operation_type
    }

    extra_data = Keyword.get(opts, :extra, %{})
    actor_id = Keyword.get(opts, :actor_id)

    key_with_extras =
      base_key
      |> Map.merge(extra_data)
      |> maybe_add_actor(actor_id)

    # Generate a consistent hash for the key
    :erlang.phash2(key_with_extras)
  end

  @doc """
  Forces cleanup of expired entries.

  Normally cleanup happens automatically in the background, but this
  can be called to force immediate cleanup.

  """
  @spec cleanup(cache_server()) :: :ok
  def cleanup(server) do
    GenServer.cast(server, :cleanup)
  end

  @doc """
  Checks if the cache contains a specific key (without updating access time).

  """
  @spec has_key?(cache_server(), cache_key()) :: boolean()
  def has_key?(server, key) do
    GenServer.call(server, {:has_key, key})
  end

  @doc """
  Gets the remaining TTL for a cache entry in milliseconds.

  Returns `:never` for entries without expiration, or `:not_found` if the key doesn't exist.

  """
  @spec ttl(cache_server(), cache_key()) :: pos_integer() | :never | :not_found
  def ttl(server, key) do
    GenServer.call(server, {:ttl, key})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Extract configuration
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    default_ttl = Keyword.get(opts, :default_ttl, @default_ttl)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @default_cleanup_interval)
    memory_limit_mb = Keyword.get(opts, :memory_limit_mb, @default_memory_limit_mb)
    table_name = Keyword.get(opts, :name, __MODULE__)

    # Create ETS table for cache storage
    table_id = :ets.new(table_name, @table_options)

    # Schedule periodic cleanup
    if cleanup_interval > 0 do
      Process.send_after(self(), :cleanup, cleanup_interval)
    end

    state = %{
      table_id: table_id,
      max_size: max_size,
      default_ttl: default_ttl,
      cleanup_interval: cleanup_interval,
      memory_limit_mb: memory_limit_mb,
      stats: %{
        hit_count: 0,
        miss_count: 0,
        eviction_count: 0
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    result = do_get(state.table_id, key)

    updated_stats =
      case result do
        {:hit, _} -> %{state.stats | hit_count: state.stats.hit_count + 1}
        :miss -> %{state.stats | miss_count: state.stats.miss_count + 1}
      end

    {:reply, result, %{state | stats: updated_stats}}
  end

  @impl GenServer
  def handle_call({:put_if_absent, key, value, opts}, _from, state) do
    result = do_put_if_absent(state, key, value, opts)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:stats, _from, state) do
    stats = build_stats(state)
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call({:has_key, key}, _from, state) do
    exists = :ets.member(state.table_id, key)
    {:reply, exists, state}
  end

  @impl GenServer
  def handle_call({:ttl, key}, _from, state) do
    ttl = get_ttl(state.table_id, key)
    {:reply, ttl, state}
  end

  @impl GenServer
  def handle_cast({:put, key, value, opts}, state) do
    do_put(state, key, value, opts)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:delete, key}, state) do
    :ets.delete(state.table_id, key)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:clear, state) do
    :ets.delete_all_objects(state.table_id)
    {:noreply, %{state | stats: %{hit_count: 0, miss_count: 0, eviction_count: 0}}}
  end

  @impl GenServer
  def handle_cast(:cleanup, state) do
    eviction_count = cleanup_expired_entries(state.table_id)

    updated_stats = %{
      state.stats
      | eviction_count: state.stats.eviction_count + eviction_count
    }

    {:noreply, %{state | stats: updated_stats}}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    # Perform cleanup
    cleanup_expired_entries(state.table_id)

    # Check memory usage and evict if needed
    maybe_evict_by_memory(state)

    # Schedule next cleanup
    if state.cleanup_interval > 0 do
      Process.send_after(self(), :cleanup, state.cleanup_interval)
    end

    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Clean up ETS table
    :ets.delete(state.table_id)
    :ok
  end

  # Private Implementation Functions

  defp do_get(table_id, key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table_id, key) do
      [{^key, entry}] ->
        if entry.expires_at == :never or entry.expires_at > now do
          # Update access time and count
          updated_entry = %{
            entry
            | last_accessed: now,
              access_count: entry.access_count + 1
          }

          :ets.insert(table_id, {key, updated_entry})
          {:hit, entry.value}
        else
          # Entry expired, remove it
          :ets.delete(table_id, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp do_put(state, key, value, opts) do
    now = System.monotonic_time(:millisecond)
    ttl = Keyword.get(opts, :ttl, state.default_ttl)
    replace = Keyword.get(opts, :replace, true)

    expires_at =
      if ttl == :never do
        :never
      else
        now + ttl
      end

    entry = %{
      key: key,
      value: value,
      inserted_at: now,
      expires_at: expires_at,
      access_count: 0,
      last_accessed: now
    }

    if replace or not :ets.member(state.table_id, key) do
      :ets.insert(state.table_id, {key, entry})

      # Check if we need to evict entries
      maybe_evict_by_size(state)
    end

    :ok
  end

  defp do_put_if_absent(state, key, value, opts) do
    case :ets.lookup(state.table_id, key) do
      [] ->
        do_put(state, key, value, opts)
        :ok

      [_] ->
        :exists
    end
  end

  defp cleanup_expired_entries(table_id) do
    now = System.monotonic_time(:millisecond)

    # Find all expired entries
    match_spec = [
      {{:"$1", %{expires_at: :"$2"}}, [{:"/=", :"$2", :never}, {:<, :"$2", now}], [:"$1"]}
    ]

    expired_keys = :ets.select(table_id, match_spec)

    # Delete expired entries
    Enum.each(expired_keys, fn key ->
      :ets.delete(table_id, key)
    end)

    length(expired_keys)
  end

  defp maybe_evict_by_size(state) do
    current_size = :ets.info(state.table_id, :size)

    if current_size > state.max_size do
      # Evict 10% of oldest/least accessed entries
      evict_count = div(state.max_size, 10)
      evict_lru_entries(state.table_id, evict_count)
    end
  end

  defp maybe_evict_by_memory(state) do
    # Words to bytes
    memory_bytes = :ets.info(state.table_id, :memory) * 8
    memory_mb = div(memory_bytes, 1024 * 1024)

    if memory_mb > state.memory_limit_mb do
      # Evict 20% of entries to free memory
      current_size = :ets.info(state.table_id, :size)
      evict_count = div(current_size, 5)
      evict_lru_entries(state.table_id, evict_count)
    end
  end

  defp evict_lru_entries(table_id, count) do
    # Get all entries sorted by last_accessed (LRU)
    match_spec = [
      {{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}
    ]

    all_entries = :ets.select(table_id, match_spec)

    # Sort by last_accessed and take the oldest ones
    oldest_entries =
      all_entries
      |> Enum.sort_by(fn {_key, entry} -> entry.last_accessed end)
      |> Enum.take(count)

    # Delete the oldest entries
    Enum.each(oldest_entries, fn {key, _entry} ->
      :ets.delete(table_id, key)
    end)

    length(oldest_entries)
  end

  defp build_stats(state) do
    size = :ets.info(state.table_id, :size)
    memory_bytes = :ets.info(state.table_id, :memory) * 8

    total_requests = state.stats.hit_count + state.stats.miss_count

    hit_ratio =
      if total_requests > 0 do
        state.stats.hit_count / total_requests
      else
        0.0
      end

    %{
      size: size,
      memory_usage_bytes: memory_bytes,
      hit_count: state.stats.hit_count,
      miss_count: state.stats.miss_count,
      eviction_count: state.stats.eviction_count,
      hit_ratio: hit_ratio
    }
  end

  defp get_ttl(table_id, key) do
    case :ets.lookup(table_id, key) do
      [{^key, entry}] -> calculate_remaining_ttl(entry.expires_at)
      [] -> :not_found
    end
  end

  defp calculate_remaining_ttl(:never), do: :never

  defp calculate_remaining_ttl(expires_at) do
    now = System.monotonic_time(:millisecond)
    remaining = expires_at - now

    if remaining > 0, do: remaining, else: :not_found
  end

  # Utility functions

  defp normalize_params(params) when is_map(params) do
    params
    |> Enum.sort()
    |> Enum.into(%{})
  end

  defp normalize_params(params), do: params

  defp maybe_add_actor(key, nil), do: key

  defp maybe_add_actor(key, actor_id) do
    Map.put(key, :actor_id, actor_id)
  end
end
