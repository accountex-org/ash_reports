defmodule AshReports.DataLoader.CacheTest do
  use ExUnit.Case, async: true

  alias AshReports.DataLoader.Cache

  setup do
    # Start a cache for each test
    {:ok, cache_pid} = Cache.start_link(name: :"test_cache_#{:erlang.unique_integer()}")
    {:ok, cache: cache_pid}
  end

  describe "start_link/1" do
    test "starts cache with default options" do
      assert {:ok, pid} = Cache.start_link(name: :default_test_cache)
      assert Process.alive?(pid)
    end

    test "starts cache with custom options" do
      assert {:ok, pid} =
               Cache.start_link(
                 name: :custom_test_cache,
                 max_size: 5000,
                 default_ttl: :timer.hours(1),
                 memory_limit_mb: 128
               )

      assert Process.alive?(pid)
    end
  end

  describe "get/2 and put/4" do
    test "stores and retrieves values", %{cache: cache} do
      key = "test_key"
      value = %{data: "test_value", number: 42}

      # Initially should be a miss
      assert :miss = Cache.get(cache, key)

      # Store the value
      :ok = Cache.put(cache, key, value)

      # Should now be a hit
      assert {:hit, ^value} = Cache.get(cache, key)
    end

    test "stores and retrieves with custom TTL", %{cache: cache} do
      key = "ttl_key"
      value = "ttl_value"

      # Store with very short TTL
      :ok = Cache.put(cache, key, value, ttl: 50)

      # Should be available immediately
      assert {:hit, ^value} = Cache.get(cache, key)

      # Wait for expiration
      Process.sleep(100)

      # Should now be expired
      assert :miss = Cache.get(cache, key)
    end

    test "overwrites existing values by default", %{cache: cache} do
      key = "overwrite_key"
      value1 = "first_value"
      value2 = "second_value"

      # Store first value
      :ok = Cache.put(cache, key, value1)
      assert {:hit, ^value1} = Cache.get(cache, key)

      # Store second value (should overwrite)
      :ok = Cache.put(cache, key, value2)
      assert {:hit, ^value2} = Cache.get(cache, key)
    end

    test "handles various data types", %{cache: cache} do
      test_cases = [
        {"string", "test_string"},
        {"integer", 12345},
        {"float", 123.45},
        {"list", [1, 2, 3, "four"]},
        {"map", %{key: "value", nested: %{data: true}}},
        {"tuple", {:ok, "result"}},
        {"atom", :test_atom}
      ]

      for {key, value} <- test_cases do
        :ok = Cache.put(cache, key, value)
        assert {:hit, ^value} = Cache.get(cache, key)
      end
    end
  end

  describe "put_if_absent/4" do
    test "stores value when key doesn't exist", %{cache: cache} do
      key = "absent_key"
      value = "new_value"

      assert :ok = Cache.put_if_absent(cache, key, value)
      assert {:hit, ^value} = Cache.get(cache, key)
    end

    test "doesn't overwrite existing value", %{cache: cache} do
      key = "existing_key"
      original_value = "original"
      new_value = "should_not_be_stored"

      # Store original value
      :ok = Cache.put(cache, key, original_value)

      # Try to store new value (should be rejected)
      assert :exists = Cache.put_if_absent(cache, key, new_value)

      # Original value should remain
      assert {:hit, ^original_value} = Cache.get(cache, key)
    end
  end

  describe "delete/2" do
    test "removes existing key", %{cache: cache} do
      key = "delete_key"
      value = "delete_value"

      # Store value
      :ok = Cache.put(cache, key, value)
      assert {:hit, ^value} = Cache.get(cache, key)

      # Delete value
      :ok = Cache.delete(cache, key)
      assert :miss = Cache.get(cache, key)
    end

    test "is safe to call on non-existent key", %{cache: cache} do
      assert :ok = Cache.delete(cache, "non_existent_key")
    end
  end

  describe "clear/1" do
    test "removes all entries", %{cache: cache} do
      # Store multiple values
      for i <- 1..5 do
        :ok = Cache.put(cache, "key_#{i}", "value_#{i}")
      end

      # Verify they exist
      for i <- 1..5 do
        expected_value = "value_#{i}"
        assert {:hit, ^expected_value} = Cache.get(cache, "key_#{i}")
      end

      # Clear cache
      :ok = Cache.clear(cache)

      # Verify all are gone
      for i <- 1..5 do
        assert :miss = Cache.get(cache, "key_#{i}")
      end
    end
  end

  describe "has_key?/2" do
    test "returns true for existing keys", %{cache: cache} do
      key = "exists_key"
      value = "exists_value"

      refute Cache.has_key?(cache, key)

      :ok = Cache.put(cache, key, value)
      assert Cache.has_key?(cache, key)
    end

    test "returns false for non-existent keys", %{cache: cache} do
      refute Cache.has_key?(cache, "non_existent")
    end

    test "doesn't update access time", %{cache: cache} do
      key = "no_update_key"
      value = "no_update_value"

      :ok = Cache.put(cache, key, value, ttl: 100)

      # Check existence (shouldn't update access time)
      assert Cache.has_key?(cache, key)

      # Wait and check again
      Process.sleep(50)
      assert Cache.has_key?(cache, key)

      # Wait for expiration
      Process.sleep(100)
      refute Cache.has_key?(cache, key)
    end
  end

  describe "ttl/2" do
    test "returns remaining TTL for non-expired entries", %{cache: cache} do
      key = "ttl_test_key"
      value = "ttl_test_value"
      ttl = 5000

      :ok = Cache.put(cache, key, value, ttl: ttl)

      remaining_ttl = Cache.ttl(cache, key)
      assert is_integer(remaining_ttl)
      assert remaining_ttl > 0
      assert remaining_ttl <= ttl
    end

    test "returns :never for entries without expiration", %{cache: cache} do
      key = "never_expires_key"
      value = "never_expires_value"

      :ok = Cache.put(cache, key, value, ttl: :never)
      assert :never = Cache.ttl(cache, key)
    end

    test "returns :not_found for non-existent keys", %{cache: cache} do
      assert :not_found = Cache.ttl(cache, "non_existent_key")
    end

    test "returns :not_found for expired keys", %{cache: cache} do
      key = "expired_key"
      value = "expired_value"

      :ok = Cache.put(cache, key, value, ttl: 50)

      # Wait for expiration
      Process.sleep(100)

      assert :not_found = Cache.ttl(cache, key)
    end
  end

  describe "stats/1" do
    test "returns cache statistics", %{cache: cache} do
      # Store some test data
      :ok = Cache.put(cache, "key1", "value1")
      :ok = Cache.put(cache, "key2", "value2")

      # Generate some hits and misses
      # hit
      Cache.get(cache, "key1")
      # hit
      Cache.get(cache, "key1")
      # miss
      Cache.get(cache, "non_existent")

      stats = Cache.stats(cache)

      assert %{
               size: size,
               memory_usage_bytes: memory,
               hit_count: hit_count,
               miss_count: miss_count,
               eviction_count: eviction_count,
               hit_ratio: hit_ratio
             } = stats

      assert size >= 2
      assert memory > 0
      assert hit_count >= 2
      assert miss_count >= 1
      assert eviction_count >= 0
      assert hit_ratio > 0.0 and hit_ratio <= 1.0
    end

    test "calculates hit ratio correctly", %{cache: cache} do
      :ok = Cache.put(cache, "test_key", "test_value")

      # Generate predictable hits and misses
      # hit
      Cache.get(cache, "test_key")
      # hit
      Cache.get(cache, "test_key")
      # miss
      Cache.get(cache, "missing1")
      # miss
      Cache.get(cache, "missing2")

      stats = Cache.stats(cache)
      # 2 hits out of 4 total requests
      expected_ratio = 2 / 4
      assert_in_delta stats.hit_ratio, expected_ratio, 0.01
    end
  end

  describe "build_key/4" do
    test "builds consistent keys for same inputs" do
      report = build_test_report()
      params = %{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]}

      key1 = Cache.build_key(report, params, :query_result)
      key2 = Cache.build_key(report, params, :query_result)

      assert key1 == key2
    end

    test "builds different keys for different inputs" do
      report = build_test_report()
      params1 = %{start_date: ~D[2024-01-01]}
      params2 = %{start_date: ~D[2024-02-01]}

      key1 = Cache.build_key(report, params1, :query_result)
      key2 = Cache.build_key(report, params2, :query_result)

      assert key1 != key2
    end

    test "builds different keys for different operation types" do
      report = build_test_report()
      params = %{date: ~D[2024-01-01]}

      key1 = Cache.build_key(report, params, :query_result)
      key2 = Cache.build_key(report, params, :processed_data)

      assert key1 != key2
    end

    test "includes actor in key when provided" do
      report = build_test_report()
      params = %{date: ~D[2024-01-01]}

      key1 = Cache.build_key(report, params, :query_result)
      key2 = Cache.build_key(report, params, :query_result, actor_id: 123)

      assert key1 != key2
    end

    test "includes extra data in key" do
      report = build_test_report()
      params = %{date: ~D[2024-01-01]}

      key1 = Cache.build_key(report, params, :query_result)
      key2 = Cache.build_key(report, params, :query_result, extra: %{version: "1.0"})

      assert key1 != key2
    end

    test "normalizes parameter order" do
      report = build_test_report()
      params1 = %{b: 2, a: 1, c: 3}
      params2 = %{a: 1, b: 2, c: 3}

      key1 = Cache.build_key(report, params1, :query_result)
      key2 = Cache.build_key(report, params2, :query_result)

      assert key1 == key2
    end
  end

  describe "cleanup/1" do
    test "forces cleanup of expired entries", %{cache: cache} do
      # Store entries with short TTL
      :ok = Cache.put(cache, "short_ttl_1", "value1", ttl: 50)
      :ok = Cache.put(cache, "short_ttl_2", "value2", ttl: 50)
      :ok = Cache.put(cache, "long_ttl", "value3", ttl: 5000)

      # Verify they exist
      assert {:hit, "value1"} = Cache.get(cache, "short_ttl_1")
      assert {:hit, "value2"} = Cache.get(cache, "short_ttl_2")
      assert {:hit, "value3"} = Cache.get(cache, "long_ttl")

      # Wait for expiration
      Process.sleep(100)

      # Force cleanup
      :ok = Cache.cleanup(cache)

      # Expired entries should be gone
      assert :miss = Cache.get(cache, "short_ttl_1")
      assert :miss = Cache.get(cache, "short_ttl_2")

      # Non-expired entry should remain
      assert {:hit, "value3"} = Cache.get(cache, "long_ttl")
    end
  end

  describe "cache eviction" do
    test "evicts entries when cache size limit is reached" do
      # Start cache with small size limit
      {:ok, small_cache} =
        Cache.start_link(
          name: :small_cache_test,
          max_size: 3
        )

      # Fill cache to capacity
      for i <- 1..3 do
        :ok = Cache.put(small_cache, "key_#{i}", "value_#{i}")
      end

      # All should be present
      for i <- 1..3 do
        expected_value = "value_#{i}"
        assert {:hit, ^expected_value} = Cache.get(small_cache, "key_#{i}")
      end

      # Add one more (should trigger eviction)
      :ok = Cache.put(small_cache, "key_4", "value_4")

      # New entry should be present
      assert {:hit, "value_4"} = Cache.get(small_cache, "key_4")

      # At least one old entry should be evicted
      stats = Cache.stats(small_cache)
      assert stats.size <= 3
    end
  end

  describe "concurrent access" do
    test "handles concurrent reads and writes", %{cache: cache} do
      # Start multiple processes that read and write concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            key = "concurrent_key_#{i}"
            value = "concurrent_value_#{i}"

            :ok = Cache.put(cache, key, value)

            # Do multiple reads
            for _j <- 1..5 do
              assert {:hit, ^value} = Cache.get(cache, key)
            end

            :ok
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)

      # All tasks should succeed
      assert Enum.all?(results, &(&1 == :ok))
    end
  end

  # Helper functions

  defp build_test_report do
    %AshReports.Report{
      name: :test_report,
      title: "Test Report",
      driving_resource: DataLoaderCacheTestResource,
      parameters: []
    }
  end
end

defmodule DataLoaderCacheTestResource do
  def __resource__, do: true
end
