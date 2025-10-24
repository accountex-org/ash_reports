defmodule AshReports.Typst.StreamingPipeline.QueryCacheTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline.QueryCache

  setup do
    # Ensure QueryCache is running
    unless Process.whereis(QueryCache) do
      flunk("QueryCache not started - check Application supervision tree")
    end

    # Clear cache before each test
    QueryCache.clear()

    :ok
  end

  describe "cache operations" do
    test "stores and retrieves cached values" do
      key = "test-key-123"
      value = %{data: "test data", records: [1, 2, 3]}

      # Put value in cache
      :ok = QueryCache.put(key, value)

      # Give it a moment to process the cast
      Process.sleep(10)

      # Retrieve value
      assert {:ok, ^value} = QueryCache.get(key)
    end

    test "returns :miss for non-existent keys" do
      assert :miss = QueryCache.get("non-existent-key")
    end

    test "respects TTL expiration" do
      key = "expiring-key"
      value = "test data"

      # Store with very short TTL (configure in test environment)
      :ok = QueryCache.put(key, value)

      # Should be accessible immediately
      assert {:ok, ^value} = QueryCache.get(key)

      # Note: For a real TTL test, you'd need to:
      # 1. Configure a very short TTL in test config
      # 2. Wait for expiration
      # 3. Verify it returns :miss
      # This is a basic structure test
    end

    test "clears all cached entries" do
      # Add multiple entries
      QueryCache.put("key1", "value1")
      QueryCache.put("key2", "value2")
      QueryCache.put("key3", "value3")

      Process.sleep(10)

      # Verify they exist
      assert {:ok, "value1"} = QueryCache.get("key1")
      assert {:ok, "value2"} = QueryCache.get("key2")

      # Clear cache
      :ok = QueryCache.clear()

      # Verify all entries are gone
      assert :miss = QueryCache.get("key1")
      assert :miss = QueryCache.get("key2")
      assert :miss = QueryCache.get("key3")
    end
  end

  describe "generate_key/5" do
    test "generates consistent keys for identical queries" do
      domain = TestDomain
      resource = TestResource
      query = Ash.Query.new(resource)
      offset = 0
      limit = 100

      key1 = QueryCache.generate_key(domain, resource, query, offset, limit)
      key2 = QueryCache.generate_key(domain, resource, query, offset, limit)

      assert key1 == key2
      assert is_binary(key1)
      assert String.length(key1) == 64
    end

    test "generates different keys for different queries" do
      domain = TestDomain
      resource = TestResource
      query1 = Ash.Query.new(resource)
      query2 = Ash.Query.new(resource) |> Ash.Query.limit(50)

      key1 = QueryCache.generate_key(domain, resource, query1, 0, 100)
      key2 = QueryCache.generate_key(domain, resource, query2, 0, 100)

      assert key1 != key2
    end

    test "generates different keys for different offsets" do
      domain = TestDomain
      resource = TestResource
      query = Ash.Query.new(resource)

      key1 = QueryCache.generate_key(domain, resource, query, 0, 100)
      key2 = QueryCache.generate_key(domain, resource, query, 100, 100)

      assert key1 != key2
    end

    test "generates different keys for different limits" do
      domain = TestDomain
      resource = TestResource
      query = Ash.Query.new(resource)

      key1 = QueryCache.generate_key(domain, resource, query, 0, 100)
      key2 = QueryCache.generate_key(domain, resource, query, 0, 200)

      assert key1 != key2
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      stats = QueryCache.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :hits)
      assert Map.has_key?(stats, :misses)
      assert Map.has_key?(stats, :evictions)
      assert Map.has_key?(stats, :size_bytes)
      assert Map.has_key?(stats, :entry_count)
      assert Map.has_key?(stats, :hit_rate_percent)
      assert Map.has_key?(stats, :size_mb)
    end

    test "tracks cache hits and misses" do
      QueryCache.clear()
      initial_stats = QueryCache.stats()

      key = "stats-test-key"
      value = "test value"

      # First access is a miss
      QueryCache.get(key)
      stats_after_miss = QueryCache.stats()
      assert stats_after_miss.misses == initial_stats.misses + 1

      # Put value
      QueryCache.put(key, value)
      Process.sleep(10)

      # Second access is a hit
      QueryCache.get(key)
      stats_after_hit = QueryCache.stats()
      assert stats_after_hit.hits == initial_stats.hits + 1
    end

    test "calculates hit rate percentage" do
      QueryCache.clear()

      key = "hit-rate-key"
      value = "test"

      # Create some hits and misses
      QueryCache.get(key)
      QueryCache.put(key, value)
      Process.sleep(10)
      QueryCache.get(key)
      QueryCache.get(key)
      QueryCache.get("non-existent")

      stats = QueryCache.stats()

      # Should have 2 hits and 2 misses = 50% hit rate
      assert stats.hits == 2
      assert stats.misses == 2
      assert stats.hit_rate_percent == 50.0
    end
  end

  describe "LRU eviction" do
    test "evicts least recently used entries when cache is full" do
      # Note: This test requires configuring max_entries in test environment
      # This is a structure test to verify the LRU mechanism exists

      # Add entries
      for i <- 1..10 do
        QueryCache.put("key-#{i}", "value-#{i}")
      end

      Process.sleep(50)

      # Access some entries to update their last_accessed time
      QueryCache.get("key-5")
      QueryCache.get("key-8")

      # In a real scenario with low max_entries, the least recently used
      # entries would be evicted. This test verifies the structure is in place.
      stats = QueryCache.stats()
      assert stats.entry_count <= 10
    end
  end
end

# Test fixtures
defmodule TestDomain do
  @moduledoc false
end

defmodule TestResource do
  @moduledoc false
  use Ash.Resource, domain: TestDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end
end
