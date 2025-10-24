defmodule AshReports.Charts.Cache do
  @moduledoc """
  ETS-based caching system for compiled SVG charts with compression support.

  This module provides fast in-memory caching of chart SVG output with
  time-to-live (TTL) support for automatic expiration and optional compression.

  ## Features

  - Fast ETS-based storage
  - TTL-based automatic expiration
  - Periodic cleanup of expired entries
  - SVG compression support for size reduction
  - Cache key generation from chart parameters
  - Cache hit/miss statistics
  - Telemetry events for monitoring

  ## Usage

      # Cache an SVG with 5 minute TTL
      Cache.put("chart_key", "<svg>...</svg>", ttl: 300_000)

      # Cache with compression
      Cache.put_compressed("chart_key", "<svg>...</svg>", ttl: 300_000)

      # Retrieve from cache
      {:ok, svg} = Cache.get("chart_key")

      # Retrieve and decompress
      {:ok, svg} = Cache.get_decompressed("chart_key")

      # Generate cache key from chart parameters
      key = Cache.generate_cache_key(:bar, data, config)

      # Clear all cache
      Cache.clear()

      # Get statistics
      Cache.stats()
  """

  use GenServer
  require Logger
  alias AshReports.Charts.Compression

  @table_name :ash_reports_chart_cache
  # Cleanup every minute
  @cleanup_interval 60_000
  # 5 minutes default TTL
  @default_ttl 300_000
  # Maximum number of cache entries (LRU eviction after this limit)
  @default_max_entries 1000

  # Client API

  @doc """
  Starts the cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores an SVG in the cache with optional TTL.

  ## Parameters

    - `key` - Cache key (string or atom)
    - `svg` - SVG string to cache
    - `opts` - Options
      - `:ttl` - Time to live in milliseconds (default: 300_000 / 5 minutes)

  ## Returns

  `:ok`

  ## Examples

      Cache.put("bar_chart_123", "<svg>...</svg>")
      Cache.put("line_chart_456", "<svg>...</svg>", ttl: 600_000)
  """
  @spec put(term(), String.t(), keyword()) :: :ok
  def put(key, svg, opts \\ []) when is_binary(svg) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    now = System.monotonic_time(:millisecond)
    expires_at = now + ttl

    # Check if we need to evict entries before inserting
    evict_if_needed()

    # Store with last_accessed_at timestamp for LRU
    entry = {key, svg, expires_at, now}
    :ets.insert(@table_name, entry)

    :telemetry.execute(
      [:ash_reports, :charts, :cache, :put],
      %{size: byte_size(svg)},
      %{key: key, ttl: ttl}
    )

    :ok
  end

  @doc """
  Stores a compressed SVG in the cache with optional TTL.

  Automatically compresses the SVG if it meets the size threshold.

  ## Parameters

    - `key` - Cache key (string or atom)
    - `svg` - SVG string to compress and cache
    - `opts` - Options
      - `:ttl` - Time to live in milliseconds (default: 300_000 / 5 minutes)
      - `:threshold` - Minimum size to trigger compression (default: 10,000 bytes)

  ## Returns

  `{:ok, metadata}` - Returns compression metadata

  ## Examples

      Cache.put_compressed("bar_chart_123", "<svg>...</svg>")
      # => {:ok, %{compressed: true, ratio: 0.35, ...}}
  """
  @spec put_compressed(term(), String.t(), keyword()) ::
          {:ok, Compression.compression_metadata()} | {:error, term()}
  def put_compressed(key, svg, opts \\ []) when is_binary(svg) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    now = System.monotonic_time(:millisecond)

    case Compression.compress_if_needed(svg, opts) do
      {:ok, :compressed, compressed, metadata} ->
        expires_at = now + ttl

        # Check if we need to evict entries before inserting
        evict_if_needed()

        # Store with compression flag and last_accessed_at
        entry = {key, compressed, expires_at, :compressed, metadata, now}
        :ets.insert(@table_name, entry)

        :telemetry.execute(
          [:ash_reports, :charts, :cache, :put_compressed],
          %{
            original_size: metadata.original_size,
            compressed_size: metadata.compressed_size,
            ratio: metadata.ratio
          },
          %{key: key, ttl: ttl}
        )

        {:ok, metadata}

      {:ok, :uncompressed, svg_data} ->
        # Store uncompressed (too small to benefit from compression)
        put(key, svg_data, opts)

        {:ok,
         %{
           original_size: byte_size(svg_data),
           compressed_size: byte_size(svg_data),
           ratio: 1.0,
           compression_time_ms: 0
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves an SVG from the cache.

  ## Parameters

    - `key` - Cache key

  ## Returns

    - `{:ok, svg}` - Cache hit, returns SVG
    - `{:error, :not_found}` - Cache miss or expired

  ## Examples

      Cache.get("bar_chart_123")
      # => {:ok, "<svg>...</svg>"}

      Cache.get("unknown_key")
      # => {:error, :not_found}
  """
  @spec get(term()) :: {:ok, String.t()} | {:error, :not_found}
  def get(key) do
    now = System.monotonic_time(:millisecond)

    result =
      case :ets.lookup(@table_name, key) do
        # Legacy format (no access time) - 3-tuple - migrate on access
        [{^key, svg, expires_at}] when expires_at > now ->
          increment_cache_hit()
          # Migrate to new format with access time
          :ets.insert(@table_name, {key, svg, expires_at, now})
          {:ok, svg}

        # Current format with access time - 4-tuple
        [{^key, svg, expires_at, _last_accessed}] when expires_at > now ->
          increment_cache_hit()
          # Update access time
          :ets.insert(@table_name, {key, svg, expires_at, now})
          {:ok, svg}

        # Current format with compression and access time - 6-tuple (uncompressed)
        [{^key, svg, expires_at, :uncompressed, metadata, _last_accessed}] when expires_at > now ->
          increment_cache_hit()
          # Update access time
          :ets.insert(@table_name, {key, svg, expires_at, :uncompressed, metadata, now})
          {:ok, svg}

        # Current format with compression and access time - 6-tuple (compressed)
        [{^key, _data, expires_at, :compressed, _metadata, _last_accessed}] when expires_at > now ->
          # Compressed data - can't return directly, use get_decompressed
          increment_cache_hit()
          {:error, :compressed_data}

        # Expired entries (all formats)
        [{^key, _data, _expires_at, _flag, _metadata, _last_acc}] ->
          :ets.delete(@table_name, key)
          increment_cache_miss()
          {:error, :not_found}

        [{^key, _data, _expires_at, _last_acc}] ->
          :ets.delete(@table_name, key)
          increment_cache_miss()
          {:error, :not_found}

        [{^key, _data, _expires_at}] ->
          :ets.delete(@table_name, key)
          increment_cache_miss()
          {:error, :not_found}

        [] ->
          increment_cache_miss()
          {:error, :not_found}
      end

    emit_cache_telemetry(result, key)
    result
  end

  @doc """
  Retrieves and decompresses an SVG from the cache.

  Handles both compressed and uncompressed cache entries.

  ## Parameters

    - `key` - Cache key

  ## Returns

    - `{:ok, svg}` - Cache hit, returns decompressed SVG
    - `{:error, :not_found}` - Cache miss or expired
    - `{:error, :decompression_failed}` - Decompression error

  ## Examples

      Cache.get_decompressed("bar_chart_123")
      # => {:ok, "<svg>...</svg>"}
  """
  @spec get_decompressed(term()) :: {:ok, String.t()} | {:error, term()}
  def get_decompressed(key) do
    now = System.monotonic_time(:millisecond)

    result =
      case :ets.lookup(@table_name, key) do
        # Legacy format (no compression, no access time) - 3-tuple - migrate on access
        [{^key, svg, expires_at}] when expires_at > now ->
          increment_cache_hit()
          # Migrate to new format with access time
          :ets.insert(@table_name, {key, svg, expires_at, now})
          {:ok, svg}

        # Current format with access time - 4-tuple
        [{^key, svg, expires_at, _last_accessed}] when expires_at > now ->
          increment_cache_hit()
          # Update access time
          :ets.insert(@table_name, {key, svg, expires_at, now})
          {:ok, svg}

        # Current format with uncompressed data - 6-tuple
        [{^key, svg, expires_at, :uncompressed, metadata, _last_accessed}] when expires_at > now ->
          increment_cache_hit()
          # Update access time
          :ets.insert(@table_name, {key, svg, expires_at, :uncompressed, metadata, now})
          {:ok, svg}

        # Current format with compressed data - 6-tuple
        [{^key, compressed, expires_at, :compressed, metadata, _last_accessed}]
        when expires_at > now ->
          increment_cache_hit()

          case Compression.decompress(compressed) do
            {:ok, svg} ->
              # Update access time
              :ets.insert(@table_name, {key, compressed, expires_at, :compressed, metadata, now})
              {:ok, svg}

            {:error, reason} ->
              {:error, reason}
          end

        # Expired entries (all formats)
        [{^key, _data, _expires_at, _flag, _metadata, _last_acc}] ->
          :ets.delete(@table_name, key)
          increment_cache_miss()
          {:error, :not_found}

        [{^key, _data, _expires_at, _last_acc}] ->
          :ets.delete(@table_name, key)
          increment_cache_miss()
          {:error, :not_found}

        [{^key, _data, _expires_at}] ->
          :ets.delete(@table_name, key)
          increment_cache_miss()
          {:error, :not_found}

        [] ->
          increment_cache_miss()
          {:error, :not_found}
      end

    emit_cache_telemetry(result, key)
    result
  end

  @doc """
  Clears all cached entries.

  ## Returns

  `:ok`

  ## Examples

      Cache.clear()
      # => :ok
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Generates a cache key from chart parameters.

  Creates a unique cache key by hashing the chart type, data, and configuration.
  Same parameters will always produce the same key.

  ## Parameters

    - `chart_type` - Chart type atom (`:bar`, `:line`, etc.)
    - `data` - List of data maps for the chart
    - `config` - Chart configuration struct or map

  ## Returns

  Binary cache key (SHA256 hash)

  ## Examples

      key = Cache.generate_cache_key(:bar, [%{x: 1, y: 2}], %{width: 800})
      # => "a3f5c2..."
  """
  @spec generate_cache_key(atom(), list(map()), map() | struct()) :: binary()
  def generate_cache_key(chart_type, data, config) do
    # Convert config struct to map for consistent hashing
    config_map =
      if is_struct(config) do
        Map.from_struct(config)
      else
        config
      end

    # Create a deterministic representation for hashing
    hash_input = :erlang.term_to_binary({chart_type, data, config_map})

    # Generate SHA256 hash
    :crypto.hash(:sha256, hash_input)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end

  @doc """
  Gets cache statistics.

  ## Returns

  Map with cache statistics:
    - `total_entries` - Total number of cached items
    - `total_size` - Total size of original SVGs in bytes
    - `compressed_size` - Total size of compressed data in bytes
    - `compression_ratio` - Overall compression ratio
    - `expired_count` - Number of expired entries
    - `cache_hits` - Total cache hits
    - `cache_misses` - Total cache misses
    - `hit_rate` - Cache hit rate (0.0 to 1.0)

  ## Examples

      Cache.stats()
      # => %{
      #   total_entries: 42,
      #   total_size: 125000,
      #   compressed_size: 45000,
      #   compression_ratio: 0.36,
      #   expired_count: 3,
      #   cache_hits: 150,
      #   cache_misses: 50,
      #   hit_rate: 0.75
      # }
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for cache
    :ets.new(@table_name, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Create ETS table for stats tracking
    :ets.new(:ash_reports_cache_stats, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Initialize stats counters
    :ets.insert(:ash_reports_cache_stats, {:cache_hits, 0})
    :ets.insert(:ash_reports_cache_stats, {:cache_misses, 0})

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.debug("AshReports.Charts.Cache initialized")

    {:ok, %{}}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    count = :ets.info(@table_name, :size)
    :ets.delete_all_objects(@table_name)

    Logger.debug("Cleared #{count} entries from chart cache")

    :telemetry.execute(
      [:ash_reports, :charts, :cache, :clear],
      %{count: count},
      %{}
    )

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    now = System.monotonic_time(:millisecond)
    all_entries = :ets.tab2list(@table_name)

    # Get cache hit/miss stats
    [{_, cache_hits}] = :ets.lookup(:ash_reports_cache_stats, :cache_hits)
    [{_, cache_misses}] = :ets.lookup(:ash_reports_cache_stats, :cache_misses)

    total_requests = cache_hits + cache_misses
    hit_rate = if total_requests > 0, do: cache_hits / total_requests, else: 0.0

    # Calculate size statistics
    {total_size, compressed_size, compressed_count} =
      Enum.reduce(all_entries, {0, 0, 0}, fn entry, {t_size, c_size, c_count} ->
        case entry do
          # Legacy format - 3-tuple
          {_key, svg, _expires} ->
            size = byte_size(svg)
            {t_size + size, c_size + size, c_count}

          # Current format with access time - 4-tuple
          {_key, svg, _expires, _last_accessed} ->
            size = byte_size(svg)
            {t_size + size, c_size + size, c_count}

          # Current compressed format with access time - 6-tuple
          {_key, data, _expires, :compressed, metadata, _last_accessed} ->
            {t_size + metadata.original_size, c_size + byte_size(data), c_count + 1}

          # Current uncompressed format with access time - 6-tuple
          {_key, data, _expires, :uncompressed, _metadata, _last_accessed} ->
            size = byte_size(data)
            {t_size + size, c_size + size, c_count}
        end
      end)

    compression_ratio =
      if total_size > 0, do: compressed_size / total_size, else: 1.0

    stats = %{
      total_entries: length(all_entries),
      total_size: total_size,
      compressed_size: compressed_size,
      compression_ratio: Float.round(compression_ratio, 3),
      compressed_count: compressed_count,
      expired_count: Enum.count(all_entries, fn entry ->
        case entry do
          # 6-tuple
          {_key, _data, expires, _flag, _meta, _last_acc} -> expires <= now
          # 4-tuple
          {_key, _data, expires, _last_acc} -> expires <= now
          # 3-tuple (legacy)
          {_key, _data, expires} -> expires <= now
        end
      end),
      cache_hits: cache_hits,
      cache_misses: cache_misses,
      hit_rate: Float.round(hit_rate, 3)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    now = System.monotonic_time(:millisecond)

    expired_keys =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn entry ->
        expires_at =
          case entry do
            # 6-tuple: {key, data, expires, flag, meta, last_accessed}
            {_key, _data, exp, _flag, _meta, _last_acc} -> exp
            # 4-tuple: {key, svg, expires, last_accessed}
            {_key, _data, exp, _last_acc} -> exp
            # 3-tuple: {key, svg, expires} (legacy)
            {_key, _data, exp} -> exp
          end

        expires_at <= now
      end)
      |> Enum.map(fn entry ->
        case entry do
          {key, _data, _expires_at, _flag, _meta, _last_acc} -> key
          {key, _data, _expires_at, _last_acc} -> key
          {key, _data, _expires_at} -> key
        end
      end)

    Enum.each(expired_keys, fn key ->
      :ets.delete(@table_name, key)
    end)

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")

      :telemetry.execute(
        [:ash_reports, :charts, :cache, :cleanup],
        %{count: length(expired_keys)},
        %{}
      )
    end
  end

  defp increment_cache_hit do
    :ets.update_counter(:ash_reports_cache_stats, :cache_hits, {2, 1}, {:cache_hits, 0})
  end

  defp increment_cache_miss do
    :ets.update_counter(:ash_reports_cache_stats, :cache_misses, {2, 1}, {:cache_misses, 0})
  end

  defp emit_cache_telemetry(result, key) do
    case result do
      {:ok, _svg} ->
        :telemetry.execute(
          [:ash_reports, :charts, :cache, :hit],
          %{},
          %{key: key}
        )

      {:error, :not_found} ->
        :telemetry.execute(
          [:ash_reports, :charts, :cache, :miss],
          %{},
          %{key: key}
        )

      _ ->
        :ok
    end
  end

  defp evict_if_needed do
    current_size = :ets.info(@table_name, :size)

    if current_size >= @default_max_entries do
      # Calculate how many entries to evict (10% of max)
      evict_count = max(div(@default_max_entries, 10), 1)
      evict_lru_entries(evict_count)
    end
  end

  defp evict_lru_entries(count) do
    # Get all entries with their access times
    entries = :ets.tab2list(@table_name)

    # Extract entries with last_accessed_at timestamp
    entries_with_access =
      Enum.map(entries, fn entry ->
        last_accessed =
          case entry do
            # 4-tuple format: {key, svg, expires_at, last_accessed}
            {_key, _data, _expires, last_acc} when is_integer(last_acc) ->
              last_acc

            # 6-tuple format: {key, data, expires_at, flag, metadata, last_accessed}
            {_key, _data, _expires, _flag, _metadata, last_acc} when is_integer(last_acc) ->
              last_acc

            # Old formats without access time - use 0 (will be evicted first)
            _ ->
              0
          end

        {entry, last_accessed}
      end)

    # Sort by last_accessed (oldest first)
    sorted_entries =
      entries_with_access
      |> Enum.sort_by(fn {_entry, last_accessed} -> last_accessed end)
      |> Enum.take(count)

    # Delete the LRU entries
    evicted_keys =
      Enum.map(sorted_entries, fn {entry, _last_accessed} ->
        key =
          case entry do
            {k, _, _, _} -> k
            {k, _, _, _, _, _} -> k
            {k, _, _} -> k
          end

        :ets.delete(@table_name, key)
        key
      end)

    if length(evicted_keys) > 0 do
      Logger.debug("Evicted #{length(evicted_keys)} LRU entries from cache (limit: #{@default_max_entries})")

      :telemetry.execute(
        [:ash_reports, :charts, :cache, :eviction],
        %{count: length(evicted_keys)},
        %{reason: :lru, limit: @default_max_entries}
      )
    end
  end
end
