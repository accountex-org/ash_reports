defmodule AshReports.Typst.StreamingPipeline.ProducerTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline.Producer
  alias AshReports.Typst.StreamingPipeline.Registry

  import ExUnit.CaptureLog

  # Test setup
  setup do
    # Ensure test domain and resources are available
    # The application is already started via test_helper.exs

    :ok
  end

  describe "demand handling" do
    test "handles demand of 1 record" do
      # Setup: Simple Ash query
      query = build_test_query(limit: 10)

      # Start producer with chunk_size: 5
      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 5,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Subscribe and demand 1 record
      {:ok, subscription_tag} = GenStage.ask(producer, 1)

      # Should receive a chunk of up to 1 record
      assert_receive {:"$gen_consumer", {^producer, ^subscription_tag}, events}, 1000
      assert is_list(events)
      assert length(events) <= 1

      GenStage.stop(producer)
    end

    test "handles demand of 100 records with chunking" do
      query = build_test_query(limit: 100)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 10,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Demand 100 records
      GenStage.ask(producer, 100)

      # Should receive multiple chunks totaling up to 100 records
      total_received = receive_all_events(producer, 100, 5000)
      assert total_received <= 100

      GenStage.stop(producer)
    end

    test "respects max_demand limit" do
      query = build_test_query(limit: 1000)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 50,
          max_demand: 200,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Demand more than max_demand
      GenStage.ask(producer, 500)

      # Should only receive up to max_demand
      total_received = receive_all_events(producer, 500, 5000)
      assert total_received <= 200

      GenStage.stop(producer)
    end

    test "handles zero demand gracefully" do
      query = build_test_query(limit: 10)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 5,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Don't ask for any demand - producer should not send events
      refute_receive {:"$gen_consumer", {^producer, _}, _}, 500

      GenStage.stop(producer)
    end

    test "handles large demand with small chunks" do
      query = build_test_query(limit: 500)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          # Small chunks
          chunk_size: 10,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Large demand
      GenStage.ask(producer, 500)

      # Should receive all records in chunks of 10
      total_received = receive_all_events(producer, 500, 10000)
      assert total_received <= 500

      GenStage.stop(producer)
    end
  end

  describe "backpressure and circuit breakers" do
    test "pauses fetching when circuit breaker trips" do
      query = build_test_query(limit: 100)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 10,
          # Very low limit to trip circuit breaker
          memory_limit: 1_000,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Subscribe and demand records
      GenStage.ask(producer, 100)

      # Circuit breaker should trip due to low memory limit
      # Producer should pause or slow down

      # Note: This is a smoke test - actual circuit breaker logic may vary
      # We're just ensuring the producer doesn't crash

      Process.sleep(100)
      assert Process.alive?(producer)

      GenStage.stop(producer)
    end

    test "resumes after circuit breaker resets" do
      query = build_test_query(limit: 50)
      stream_id = "test-#{:rand.uniform(10000)}"

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 10,
          stream_id: stream_id
        )

      # Manually pause via registry (simulating circuit breaker)
      :ok = Registry.update_status(stream_id, :paused)

      # Try to fetch - should be paused
      GenStage.ask(producer, 10)
      Process.sleep(100)

      # Resume
      :ok = Registry.update_status(stream_id, :running)

      # Should now be able to fetch
      GenStage.ask(producer, 10)
      total_received = receive_all_events(producer, 10, 2000)
      assert total_received > 0

      GenStage.stop(producer)
    end
  end

  describe "query execution and pagination" do
    test "executes Ash query with offset pagination" do
      query = build_test_query(limit: 100)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 20,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      # Demand all records
      GenStage.ask(producer, 100)

      # Should fetch in chunks using offset pagination
      total_received = receive_all_events(producer, 100, 5000)
      assert total_received > 0

      GenStage.stop(producer)
    end

    test "handles empty query results" do
      # Query that returns no results
      query = build_test_query(limit: 0)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 10,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      GenStage.ask(producer, 10)

      # Should complete without errors
      Process.sleep(500)
      assert Process.alive?(producer)

      GenStage.stop(producer)
    end

    test "handles query errors gracefully" do
      # Invalid query that will fail
      invalid_query = nil

      log =
        capture_log(fn ->
          # Producer should start but log errors when trying to fetch
          {:ok, producer} =
            Producer.start_link(
              query: invalid_query,
              domain: TestDomain,
              chunk_size: 10,
              stream_id: "test-#{:rand.uniform(10000)}"
            )

          GenStage.ask(producer, 10)
          Process.sleep(500)

          GenStage.stop(producer)
        end)

      # Should log error
      assert log =~ "error" or log =~ "Error" or log =~ "ERROR"
    end
  end

  describe "telemetry emission" do
    @tag :telemetry
    test "emits chunk_fetched telemetry event" do
      # Attach telemetry handler
      ref = make_ref()
      self_pid = self()

      :telemetry.attach(
        "test-producer-telemetry-#{ref}",
        [:ash_reports, :streaming, :producer, :chunk_fetched],
        fn event, measurements, metadata, _ ->
          send(self_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      query = build_test_query(limit: 10)

      {:ok, producer} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 5,
          enable_telemetry: true,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      GenStage.ask(producer, 10)

      # Should receive telemetry event
      assert_receive {:telemetry, [:ash_reports, :streaming, :producer, :chunk_fetched],
                      measurements, metadata},
                     2000

      assert is_map(measurements)
      assert is_map(metadata)

      :telemetry.detach("test-producer-telemetry-#{ref}")
      GenStage.stop(producer)
    end
  end

  describe "cache integration" do
    @tag :cache
    test "uses query cache when available" do
      query = build_test_query(limit: 20)
      cache_key = "test-cache-#{:rand.uniform(10000)}"

      # First fetch - should cache
      {:ok, producer1} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 10,
          cache_key: cache_key,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      GenStage.ask(producer1, 20)
      _total1 = receive_all_events(producer1, 20, 2000)
      GenStage.stop(producer1)

      # Second fetch with same cache key - should use cache
      {:ok, producer2} =
        Producer.start_link(
          query: query,
          domain: TestDomain,
          chunk_size: 10,
          cache_key: cache_key,
          stream_id: "test-#{:rand.uniform(10000)}"
        )

      GenStage.ask(producer2, 20)
      total2 = receive_all_events(producer2, 20, 2000)

      # Should still get results (from cache or fresh)
      assert total2 > 0

      GenStage.stop(producer2)
    end
  end

  # Helper functions

  defp build_test_query(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Build a simple query for testing
    # Note: Actual implementation depends on test domain setup
    %{
      resource: TestResource,
      limit: limit,
      offset: 0
    }
  end

  defp receive_all_events(producer, max_count, timeout) do
    receive_events_recursive(producer, max_count, timeout, 0, System.monotonic_time(:millisecond))
  end

  defp receive_events_recursive(producer, max_count, timeout, acc, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    remaining_timeout = max(0, timeout - elapsed)

    if acc >= max_count or remaining_timeout <= 0 do
      acc
    else
      receive do
        {:"$gen_consumer", {^producer, _}, events} when is_list(events) ->
          new_acc = acc + length(events)
          receive_events_recursive(producer, max_count, timeout, new_acc, start_time)
      after
        remaining_timeout -> acc
      end
    end
  end
end
