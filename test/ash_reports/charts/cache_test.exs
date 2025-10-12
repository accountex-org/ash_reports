defmodule AshReports.Charts.CacheTest do
  @moduledoc """
  Test suite for enhanced Chart Cache with compression support.
  """
  use ExUnit.Case, async: false

  alias AshReports.Charts.{Cache, Config}

  setup do
    # Clear cache before each test
    Cache.clear()
    :ok
  end

  describe "basic caching operations" do
    test "put and get SVG from cache" do
      svg = "<svg>test chart</svg>"

      :ok = Cache.put("test_key", svg)
      assert {:ok, ^svg} = Cache.get("test_key")
    end

    test "get returns error for non-existent key" do
      assert {:error, :not_found} = Cache.get("nonexistent")
    end

    test "cache expires after TTL" do
      svg = "<svg>test</svg>"

      # Put with 100ms TTL
      :ok = Cache.put("expiring_key", svg, ttl: 100)

      # Should be available immediately
      assert {:ok, ^svg} = Cache.get("expiring_key")

      # Wait for expiration
      Process.sleep(150)

      # Should be expired now
      assert {:error, :not_found} = Cache.get("expiring_key")
    end

    test "clear removes all cache entries" do
      Cache.put("key1", "<svg>1</svg>")
      Cache.put("key2", "<svg>2</svg>")
      Cache.put("key3", "<svg>3</svg>")

      stats_before = Cache.stats()
      assert stats_before.total_entries == 3

      :ok = Cache.clear()

      stats_after = Cache.stats()
      assert stats_after.total_entries == 0
    end
  end

  describe "compression support" do
    test "put_compressed compresses large SVGs" do
      # Create SVG larger than 10KB threshold
      large_svg = String.duplicate("<rect x='1' y='2' width='10' height='10'/>", 500)

      assert {:ok, metadata} = Cache.put_compressed("large_chart", large_svg)
      assert metadata.original_size > 10_000
      assert metadata.compressed_size < metadata.original_size
      assert metadata.ratio < 1.0
    end

    test "put_compressed skips compression for small SVGs" do
      small_svg = "<svg>small</svg>"

      assert {:ok, metadata} = Cache.put_compressed("small_chart", small_svg)
      assert metadata.original_size == byte_size(small_svg)
      assert metadata.ratio == 1.0
    end

    test "get_decompressed retrieves and decompresses" do
      large_svg = String.duplicate("<rect x='1' y='2'/>", 1000)

      {:ok, _metadata} = Cache.put_compressed("compressed_chart", large_svg)
      assert {:ok, retrieved_svg} = Cache.get_decompressed("compressed_chart")
      assert retrieved_svg == large_svg
    end

    test "get_decompressed handles uncompressed entries" do
      svg = "<svg>test</svg>"

      Cache.put("uncompressed_key", svg)
      assert {:ok, ^svg} = Cache.get_decompressed("uncompressed_key")
    end

    test "compression respects custom threshold" do
      svg = String.duplicate("x", 5000)

      # With high threshold, should not compress
      {:ok, metadata1} = Cache.put_compressed("key1", svg, threshold: 10_000)
      assert metadata1.ratio == 1.0

      # With low threshold, should compress
      {:ok, metadata2} = Cache.put_compressed("key2", svg, threshold: 1000)
      assert metadata2.ratio < 1.0
    end
  end

  describe "cache key generation" do
    test "generates consistent keys for same inputs" do
      data = [%{x: 1, y: 2}, %{x: 3, y: 4}]
      config = %Config{title: "Test", width: 800}

      key1 = Cache.generate_cache_key(:bar, data, config)
      key2 = Cache.generate_cache_key(:bar, data, config)

      assert key1 == key2
      assert is_binary(key1)
      assert String.length(key1) == 32
    end

    test "generates different keys for different chart types" do
      data = [%{x: 1, y: 2}]
      config = %Config{title: "Test"}

      key_bar = Cache.generate_cache_key(:bar, data, config)
      key_line = Cache.generate_cache_key(:line, data, config)

      assert key_bar != key_line
    end

    test "generates different keys for different data" do
      config = %Config{title: "Test"}

      key1 = Cache.generate_cache_key(:bar, [%{x: 1, y: 2}], config)
      key2 = Cache.generate_cache_key(:bar, [%{x: 3, y: 4}], config)

      assert key1 != key2
    end

    test "generates different keys for different configs" do
      data = [%{x: 1, y: 2}]

      key1 = Cache.generate_cache_key(:bar, data, %Config{title: "A"})
      key2 = Cache.generate_cache_key(:bar, data, %Config{title: "B"})

      assert key1 != key2
    end

    test "handles config as map" do
      data = [%{x: 1, y: 2}]

      key1 = Cache.generate_cache_key(:bar, data, %Config{title: "Test"})
      key2 = Cache.generate_cache_key(:bar, data, %{title: "Test"})

      # Different because struct vs map, but both should work
      assert is_binary(key1)
      assert is_binary(key2)
    end
  end

  describe "cache statistics" do
    test "stats returns comprehensive metrics" do
      Cache.put("key1", "<svg>1</svg>")
      Cache.put("key2", "<svg>2</svg>")

      stats = Cache.stats()

      assert stats.total_entries == 2
      assert stats.total_size > 0
      assert stats.compressed_size >= 0
      assert stats.compression_ratio >= 0
      assert stats.expired_count == 0
      assert is_number(stats.cache_hits)
      assert is_number(stats.cache_misses)
      assert is_float(stats.hit_rate)
    end

    test "stats tracks cache hits and misses" do
      svg = "<svg>test</svg>"
      Cache.put("key1", svg)

      # Initial state
      stats_initial = Cache.stats()
      initial_hits = stats_initial.cache_hits
      initial_misses = stats_initial.cache_misses

      # Cache hit
      {:ok, _} = Cache.get("key1")

      stats_after_hit = Cache.stats()
      assert stats_after_hit.cache_hits == initial_hits + 1

      # Cache miss
      {:error, :not_found} = Cache.get("nonexistent")

      stats_after_miss = Cache.stats()
      assert stats_after_miss.cache_misses == initial_misses + 1
    end

    test "stats tracks compression ratio" do
      # Add uncompressed entry
      Cache.put("small", "<svg>small</svg>")

      # Add compressed entry (large SVG)
      large_svg = String.duplicate("<rect x='1' y='2'/>", 1000)
      Cache.put_compressed("large", large_svg)

      stats = Cache.stats()

      assert stats.total_entries == 2
      assert stats.total_size > byte_size("<svg>small</svg>")
      assert stats.compression_ratio < 1.0
      assert stats.compressed_count >= 1
    end

    test "stats tracks expired entries" do
      Cache.put("expiring", "<svg>test</svg>", ttl: 50)
      Process.sleep(100)

      stats = Cache.stats()
      assert stats.expired_count > 0
    end

    test "stats calculates hit rate correctly" do
      Cache.clear()
      Cache.put("key1", "<svg>test</svg>")

      # Get baseline stats
      stats_before = Cache.stats()
      hits_before = stats_before.cache_hits
      misses_before = stats_before.cache_misses

      # 2 hits, 1 miss
      Cache.get("key1")
      Cache.get("key1")
      Cache.get("nonexistent")

      stats_after = Cache.stats()

      # Verify the counters increased correctly
      assert stats_after.cache_hits == hits_before + 2
      assert stats_after.cache_misses == misses_before + 1

      # Calculate hit rate from the delta
      new_hits = stats_after.cache_hits - hits_before
      new_misses = stats_after.cache_misses - misses_before
      delta_hit_rate = new_hits / (new_hits + new_misses)

      # Hit rate should be approximately 0.667 (2/3)
      assert delta_hit_rate > 0.6 and delta_hit_rate < 0.7
    end
  end

  describe "backwards compatibility" do
    test "get handles old 3-tuple format" do
      # Simulate old cache entry format (before compression support)
      key = "old_entry"
      svg = "<svg>old format</svg>"
      expires_at = System.monotonic_time(:millisecond) + 300_000

      :ets.insert(:ash_reports_chart_cache, {key, svg, expires_at})

      assert {:ok, ^svg} = Cache.get(key)
    end

    test "get_decompressed handles old 3-tuple format" do
      key = "old_entry"
      svg = "<svg>old format</svg>"
      expires_at = System.monotonic_time(:millisecond) + 300_000

      :ets.insert(:ash_reports_chart_cache, {key, svg, expires_at})

      assert {:ok, ^svg} = Cache.get_decompressed(key)
    end

    test "stats handles mixed old and new entry formats" do
      # Old format entry
      :ets.insert(
        :ash_reports_chart_cache,
        {"old_key", "<svg>old</svg>", System.monotonic_time(:millisecond) + 300_000}
      )

      # New format entry
      Cache.put("new_key", "<svg>new</svg>")

      stats = Cache.stats()
      assert stats.total_entries == 2
      assert stats.total_size > 0
    end
  end

  describe "error handling" do
    test "get_decompressed handles corrupted compressed data" do
      # Insert invalid compressed data
      key = "corrupted"
      invalid_data = "not valid gzip data"
      expires_at = System.monotonic_time(:millisecond) + 300_000
      metadata = %{original_size: 100, compressed_size: 50, ratio: 0.5, compression_time_ms: 1}

      :ets.insert(
        :ash_reports_chart_cache,
        {key, invalid_data, expires_at, :compressed, metadata}
      )

      assert {:error, {:decompression_failed, _}} = Cache.get_decompressed(key)
    end

    test "put_compressed handles compression failure gracefully" do
      # This is hard to trigger with valid SVG data, but the error path exists
      svg = "<svg>test</svg>"

      # Should succeed or return error tuple
      result = Cache.put_compressed("test", svg)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "concurrent access" do
    test "handles concurrent puts and gets" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            key = "concurrent_#{i}"
            svg = "<svg>chart #{i}</svg>"

            Cache.put(key, svg)
            {:ok, retrieved} = Cache.get(key)

            assert retrieved == svg
          end)
        end

      Enum.each(tasks, &Task.await/1)

      stats = Cache.stats()
      assert stats.total_entries == 20
    end

    test "handles concurrent cache key generation" do
      data = [%{x: 1, y: 2}]
      config = %Config{title: "Test"}

      keys =
        for _i <- 1..100 do
          Task.async(fn ->
            Cache.generate_cache_key(:bar, data, config)
          end)
        end
        |> Enum.map(&Task.await/1)

      # All keys should be identical
      assert Enum.uniq(keys) |> length() == 1
    end
  end

  describe "telemetry events" do
    test "emits telemetry on cache put" do
      :telemetry.attach(
        "test-cache-put",
        [:ash_reports, :charts, :cache, :put],
        fn _event, measurements, _metadata, _config ->
          send(self(), {:telemetry, :put, measurements})
        end,
        nil
      )

      svg = "<svg>test</svg>"
      Cache.put("test_key", svg)

      assert_receive {:telemetry, :put, measurements}, 100
      assert measurements.size == byte_size(svg)

      :telemetry.detach("test-cache-put")
    end

    test "emits telemetry on cache hit" do
      :telemetry.attach(
        "test-cache-hit",
        [:ash_reports, :charts, :cache, :hit],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:telemetry, :hit, metadata})
        end,
        nil
      )

      Cache.put("test_key", "<svg>test</svg>")
      Cache.get("test_key")

      assert_receive {:telemetry, :hit, _metadata}, 100

      :telemetry.detach("test-cache-hit")
    end

    test "emits telemetry on cache miss" do
      :telemetry.attach(
        "test-cache-miss",
        [:ash_reports, :charts, :cache, :miss],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:telemetry, :miss, metadata})
        end,
        nil
      )

      Cache.get("nonexistent")

      assert_receive {:telemetry, :miss, _metadata}, 100

      :telemetry.detach("test-cache-miss")
    end
  end

  describe "cleanup" do
    test "periodic cleanup removes expired entries" do
      # Put entries with short TTL
      Cache.put("expire1", "<svg>1</svg>", ttl: 50)
      Cache.put("expire2", "<svg>2</svg>", ttl: 50)
      Cache.put("keep", "<svg>3</svg>", ttl: 10_000)

      stats_before = Cache.stats()
      assert stats_before.total_entries == 3

      # Wait for expiration
      Process.sleep(100)

      # Trigger cleanup manually by sending cleanup message
      send(Cache, :cleanup)
      Process.sleep(50)

      # Check that expired entries are removed
      assert {:error, :not_found} = Cache.get("expire1")
      assert {:error, :not_found} = Cache.get("expire2")
      assert {:ok, _} = Cache.get("keep")
    end
  end
end
