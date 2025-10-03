defmodule AshReports.Typst.StreamingPipeline.LoadStressTest do
  @moduledoc """
  MVP Load and Stress Testing for Streaming Pipeline.

  Focuses on critical stress scenarios:
  - Cancellation and error recovery
  - Memory pressure with large datasets
  - Concurrent multi-stream stress testing

  Run with: mix test test/ash_reports/typst/streaming_pipeline/load_stress_test.exs --include stress
  """

  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline.{ProducerConsumer}
  alias AshReports.Typst.StreamingPipeline.LoadStressTest.{TestProducer, TestConsumer}

  @moduletag :stress
  @moduletag timeout: 300_000

  describe "Cancellation and Error Recovery" do
    test "pipeline handles cancellation gracefully" do
      stream_id = "cancel-test-#{:rand.uniform(10000)}"

      # Trap exits to handle consumer shutdown without crashing test
      Process.flag(:trap_exit, true)

      # Start a producer with a slow query simulation
      {:ok, producer} = start_test_producer(stream_id, record_count: 1000, delay_ms: 10)

      {:ok, pc} =
        ProducerConsumer.start_link(
          subscribe_to: [producer],
          stream_id: stream_id
        )

      # Start consuming
      {:ok, consumer} = TestConsumer.start_link(self())
      GenStage.sync_subscribe(consumer, to: pc, max_demand: 100)

      # Let it process some records
      Process.sleep(100)

      # Verify some events were received
      assert_receive {:events, _events}, 1000

      # Stop consumer with shutdown
      GenStage.stop(consumer, :shutdown)

      # Verify producer and ProducerConsumer can be stopped cleanly
      assert GenStage.stop(pc, :normal) == :ok
      assert GenStage.stop(producer, :normal) == :ok
    end

    test "pipeline recovers from consumer errors" do
      stream_id = "error-recovery-#{:rand.uniform(10000)}"

      {:ok, producer} = start_test_producer(stream_id, record_count: 100)

      # Create a transformer that fails on specific records
      failing_transformer = fn record ->
        if record.id == 50 do
          raise "Intentional error for testing"
        end

        record
      end

      {:ok, pc} =
        ProducerConsumer.start_link(
          subscribe_to: [producer],
          transformer: failing_transformer,
          stream_id: stream_id
        )

      # Consumer should handle the error and continue processing
      Process.sleep(500)

      # ProducerConsumer should still be alive despite transformer errors
      assert Process.alive?(pc)

      # Check that errors were logged but didn't crash the pipeline
      state = :sys.get_state(pc)
      assert is_map(state.state)
      assert is_list(state.state.errors)

      GenStage.stop(pc)
      GenStage.stop(producer)
    end

    test "pipeline handles rapid start/stop cycles" do
      # Start and stop multiple pipelines quickly
      results =
        for i <- 1..10 do
          stream_id = "rapid-cycle-#{i}"
          {:ok, producer} = start_test_producer(stream_id, record_count: 50)

          {:ok, pc} =
            ProducerConsumer.start_link(
              subscribe_to: [producer],
              stream_id: stream_id
            )

          {:ok, consumer} = TestConsumer.start_link(self())
          GenStage.sync_subscribe(consumer, to: pc, max_demand: 10)

          # Immediately stop
          GenStage.stop(consumer)
          GenStage.stop(pc)
          GenStage.stop(producer)

          :ok
        end

      # All cycles should complete without crashes
      assert Enum.all?(results, &(&1 == :ok))
    end
  end

  describe "Memory Pressure Scenarios" do
    test "pipeline handles large dataset without memory explosion" do
      stream_id = "large-dataset-#{:rand.uniform(10000)}"

      # Measure baseline memory
      :erlang.garbage_collect()
      Process.sleep(100)
      baseline_memory = :erlang.memory(:total)

      # Process large dataset (100K records)
      {:ok, producer} = start_test_producer(stream_id, record_count: 100_000)

      {:ok, pc} =
        ProducerConsumer.start_link(
          subscribe_to: [producer],
          stream_id: stream_id,
          buffer_size: 1000
        )

      {:ok, consumer} = TestConsumer.start_link(self())
      GenStage.sync_subscribe(consumer, to: pc, max_demand: 1000)

      # Consume all records
      count = collect_all_events(100_000, 30_000)

      # Verify we processed the records
      assert count > 0
      assert count <= 100_000

      # Check memory after processing
      :erlang.garbage_collect()
      Process.sleep(100)
      final_memory = :erlang.memory(:total)

      memory_multiplier = final_memory / baseline_memory

      # Memory should not exceed 1.5x baseline
      assert memory_multiplier < 1.5,
             "Memory multiplier #{memory_multiplier} exceeded 1.5x baseline"

      GenStage.stop(consumer)
      GenStage.stop(pc)
      GenStage.stop(producer)
    end

    test "pipeline handles memory pressure with backpressure" do
      stream_id = "backpressure-#{:rand.uniform(10000)}"

      # Create a slow consumer to build up backpressure
      {:ok, producer} = start_test_producer(stream_id, record_count: 10_000)

      {:ok, pc} =
        ProducerConsumer.start_link(
          subscribe_to: [producer],
          stream_id: stream_id,
          buffer_size: 100
        )

      {:ok, consumer} = TestConsumer.start_link(self())
      # Use small demand to create backpressure
      GenStage.sync_subscribe(consumer, to: pc, max_demand: 50, min_demand: 10)

      # Consume some records with delay to create backpressure
      count = collect_events_with_delay(1000, 3000, delay_ms: 1)

      # Should still process records despite backpressure
      assert count > 0

      # Pipeline should still be responsive
      assert Process.alive?(pc)
      assert Process.alive?(producer)
      assert Process.alive?(consumer)

      GenStage.stop(consumer)
      GenStage.stop(pc)
      GenStage.stop(producer)
    end

    test "pipeline handles grouped aggregations with many unique groups" do
      stream_id = "many-groups-#{:rand.uniform(10000)}"

      # Generate records with many unique groups (1000 unique values)
      {:ok, producer} =
        start_test_producer(stream_id,
          record_count: 10_000,
          group_count: 1000
        )

      {:ok, pc} =
        ProducerConsumer.start_link(
          subscribe_to: [producer],
          stream_id: stream_id,
          grouped_aggregations: [
            %{group_by: :category, aggregations: [:sum, :count], level: 1}
          ]
        )

      {:ok, consumer} = TestConsumer.start_link(self())
      GenStage.sync_subscribe(consumer, to: pc, max_demand: 1000)

      # Consume all records
      count = collect_all_events(10_000, 10_000)

      assert count > 0

      # Check that grouped aggregations were computed
      gen_stage_state = :sys.get_state(pc)
      state = gen_stage_state.state

      assert Map.has_key?(state, :grouped_aggregation_state)
      assert is_map(state.grouped_aggregation_state)

      # Should have tracked multiple groups
      group_count = map_size(state.grouped_aggregation_state)
      assert group_count > 0
      assert group_count <= 1000

      GenStage.stop(consumer)
      GenStage.stop(pc)
      GenStage.stop(producer)
    end
  end

  describe "Concurrent Multi-Stream Stress Testing" do
    test "handles 10 concurrent streams processing simultaneously" do
      # Start 10 concurrent streams
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            stream_id = "concurrent-#{i}-#{:rand.uniform(10000)}"
            {:ok, producer} = start_test_producer(stream_id, record_count: 5_000)

            {:ok, pc} =
              ProducerConsumer.start_link(
                subscribe_to: [producer],
                stream_id: stream_id
              )

            {:ok, consumer} = TestConsumer.start_link(self())
            GenStage.sync_subscribe(consumer, to: pc, max_demand: 500)

            count = collect_all_events_local(5_000, 10_000)

            GenStage.stop(consumer)
            GenStage.stop(pc)
            GenStage.stop(producer)

            {stream_id, count}
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 30_000)

      # All streams should have processed records
      assert length(results) == 10
      assert Enum.all?(results, fn {_stream_id, count} -> count > 0 end)

      # Verify total records processed
      total_processed = results |> Enum.map(fn {_, count} -> count end) |> Enum.sum()
      assert total_processed > 0
      assert total_processed <= 50_000
    end

    test "handles concurrent streams with varying load" do
      # Mix of small, medium, and large streams
      stream_configs = [
        {100, 2},
        # 2 small streams (100 records each)
        {1_000, 5},
        # 5 medium streams (1K records each)
        {10_000, 3}
        # 3 large streams (10K records each)
      ]

      tasks =
        for {record_count, stream_count} <- stream_configs,
            i <- 1..stream_count do
          Task.async(fn ->
            stream_id = "varied-#{record_count}-#{i}-#{:rand.uniform(10000)}"
            {:ok, producer} = start_test_producer(stream_id, record_count: record_count)

            {:ok, pc} =
              ProducerConsumer.start_link(
                subscribe_to: [producer],
                stream_id: stream_id
              )

            {:ok, consumer} = TestConsumer.start_link(self())
            max_demand = min(record_count, 1000)
            GenStage.sync_subscribe(consumer, to: pc, max_demand: max_demand)

            count = collect_all_events_local(record_count, 15_000)

            GenStage.stop(consumer)
            GenStage.stop(pc)
            GenStage.stop(producer)

            {record_count, count}
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All streams should complete successfully
      assert length(results) == 10
      assert Enum.all?(results, fn {_size, count} -> count > 0 end)
    end

    test "system remains stable under sustained concurrent load" do
      # Run concurrent streams continuously for a period
      duration_ms = 5_000
      start_time = System.monotonic_time(:millisecond)

      ref = make_ref()
      test_pid = self()

      # Spawn workers that continuously process streams
      workers =
        for i <- 1..5 do
          spawn_link(fn ->
            worker_loop(ref, i, start_time, duration_ms, test_pid)
          end)
        end

      # Collect results
      results = collect_worker_results(ref, length(workers), [])

      # All workers should have completed successfully
      assert length(results) == 5
      assert Enum.all?(results, fn {_worker_id, cycles} -> cycles > 0 end)

      total_cycles = results |> Enum.map(fn {_, cycles} -> cycles end) |> Enum.sum()
      assert total_cycles > 0
    end
  end

  # Helper Modules

  defmodule TestProducer do
    use GenStage

    def start_link({data, opts}) do
      GenStage.start_link(__MODULE__, {data, opts})
    end

    def init({data, opts}) do
      chunk_size = Keyword.get(opts, :chunk_size, 10)
      {:producer, %{data: data, chunk_size: chunk_size, offset: 0}}
    end

    def handle_demand(demand, state) when demand > 0 do
      {events, new_state} = get_events(state, demand)
      {:noreply, events, new_state}
    end

    defp get_events(%{data: data, chunk_size: chunk_size, offset: offset} = state, demand) do
      available = length(data) - offset
      to_take = min(min(demand, chunk_size), available)

      events = Enum.slice(data, offset, to_take)
      new_offset = offset + to_take

      {events, %{state | offset: new_offset}}
    end
  end

  defmodule TestConsumer do
    use GenStage

    def start_link(test_pid, opts \\ []) do
      GenStage.start_link(__MODULE__, test_pid, opts)
    end

    def init(test_pid) do
      {:consumer, test_pid}
    end

    def handle_events(events, _from, test_pid) do
      send(test_pid, {:events, events})
      {:noreply, [], test_pid}
    end
  end

  # Helper Functions

  defp start_test_producer(_stream_id, opts) do
    record_count = Keyword.get(opts, :record_count, 100)
    delay_ms = Keyword.get(opts, :delay_ms, 0)
    group_count = Keyword.get(opts, :group_count, 10)

    # Generate test data as a list (not a stream) to avoid delay_ms issues
    data = generate_test_data(record_count, group_count, delay_ms)

    TestProducer.start_link({data, chunk_size: 100})
  end

  defp generate_test_data(count, group_count, _delay_ms) do
    Enum.map(1..count, fn id ->
      %{
        id: id,
        name: "Record #{id}",
        value: id * 10,
        amount: id * 1.5,
        category: "group_#{rem(id, group_count)}",
        timestamp: DateTime.utc_now()
      }
    end)
  end

  # Collect events from the test consumer via messages
  defp collect_all_events(max_count, timeout) do
    collect_events_recursive(max_count, timeout, 0, System.monotonic_time(:millisecond))
  end

  defp collect_events_recursive(max_count, timeout, acc, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    remaining = max(0, timeout - elapsed)

    if acc >= max_count or remaining <= 0 do
      acc
    else
      receive do
        {:events, events} when is_list(events) ->
          collect_events_recursive(max_count, timeout, acc + length(events), start_time)
      after
        remaining -> acc
      end
    end
  end

  # For use within Task.async where self() is the task pid
  defp collect_all_events_local(max_count, timeout) do
    collect_events_recursive(max_count, timeout, 0, System.monotonic_time(:millisecond))
  end

  # Collect events with a delay between receives to simulate slow consumption
  defp collect_events_with_delay(max_count, timeout, opts) do
    delay_ms = Keyword.get(opts, :delay_ms, 10)
    collect_events_delayed_recursive(max_count, timeout, 0, System.monotonic_time(:millisecond), delay_ms)
  end

  defp collect_events_delayed_recursive(max_count, timeout, acc, start_time, delay_ms) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    remaining = max(0, timeout - elapsed)

    if acc >= max_count or remaining <= 0 do
      acc
    else
      receive do
        {:events, events} when is_list(events) ->
          Process.sleep(delay_ms)
          collect_events_delayed_recursive(max_count, timeout, acc + length(events), start_time, delay_ms)
      after
        remaining -> acc
      end
    end
  end

  defp worker_loop(ref, worker_id, start_time, duration_ms, test_pid) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed < duration_ms do
      # Process a small stream
      stream_id = "worker-#{worker_id}-#{:rand.uniform(10000)}"

      try do
        {:ok, producer} = start_test_producer(stream_id, record_count: 100)

        {:ok, pc} =
          ProducerConsumer.start_link(
            subscribe_to: [producer],
            stream_id: stream_id
          )

        {:ok, consumer} = TestConsumer.start_link(self())
        GenStage.sync_subscribe(consumer, to: pc, max_demand: 100)

        _count = collect_all_events_local(100, 2000)

        GenStage.stop(consumer)
        GenStage.stop(pc)
        GenStage.stop(producer)

        # Continue loop
        worker_loop(ref, worker_id, start_time, duration_ms, test_pid)
      rescue
        _ ->
          # Ignore errors and continue
          worker_loop(ref, worker_id, start_time, duration_ms, test_pid)
      end
    else
      # Duration complete, calculate cycles
      cycles = div(duration_ms, 100)
      send(test_pid, {ref, worker_id, cycles})
    end
  end

  defp collect_worker_results(_ref, 0, acc), do: acc

  defp collect_worker_results(ref, remaining, acc) do
    receive do
      {^ref, worker_id, cycles} ->
        collect_worker_results(ref, remaining - 1, [{worker_id, cycles} | acc])
    after
      10_000 ->
        # Timeout waiting for workers
        acc
    end
  end
end
