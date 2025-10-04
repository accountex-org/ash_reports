defmodule AshReports.Charts.Cache do
  @moduledoc """
  ETS-based caching system for compiled SVG charts.

  This module provides fast in-memory caching of chart SVG output with
  time-to-live (TTL) support for automatic expiration.

  ## Features

  - Fast ETS-based storage
  - TTL-based automatic expiration
  - Periodic cleanup of expired entries
  - Telemetry events for monitoring

  ## Usage

      # Cache an SVG with 5 minute TTL
      Cache.put("chart_key", "<svg>...</svg>", ttl: 300_000)

      # Retrieve from cache
      {:ok, svg} = Cache.get("chart_key")

      # Clear all cache
      Cache.clear()
  """

  use GenServer
  require Logger

  @table_name :ash_reports_chart_cache
  # Cleanup every minute
  @cleanup_interval 60_000
  # 5 minutes default TTL
  @default_ttl 300_000

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
    expires_at = System.monotonic_time(:millisecond) + ttl

    entry = {key, svg, expires_at}
    :ets.insert(@table_name, entry)

    :telemetry.execute(
      [:ash_reports, :charts, :cache, :put],
      %{size: byte_size(svg)},
      %{key: key, ttl: ttl}
    )

    :ok
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

    case :ets.lookup(@table_name, key) do
      [{^key, svg, expires_at}] when expires_at > now ->
        {:ok, svg}

      [{^key, _svg, _expires_at}] ->
        # Expired entry, delete it
        :ets.delete(@table_name, key)
        {:error, :not_found}

      [] ->
        {:error, :not_found}
    end
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
  Gets cache statistics.

  ## Returns

  Map with cache statistics:
    - `total_entries` - Total number of cached items
    - `total_size` - Total size of cached SVGs in bytes
    - `expired_count` - Number of expired entries

  ## Examples

      Cache.stats()
      # => %{total_entries: 42, total_size: 125000, expired_count: 3}
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

    stats = %{
      total_entries: length(all_entries),
      total_size:
        all_entries
        |> Enum.map(fn {_key, svg, _expires} -> byte_size(svg) end)
        |> Enum.sum(),
      expired_count: Enum.count(all_entries, fn {_key, _svg, expires} -> expires <= now end)
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
      |> Enum.filter(fn {_key, _svg, expires_at} -> expires_at <= now end)
      |> Enum.map(fn {key, _svg, _expires_at} -> key end)

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
end
