defmodule AshReports.Streaming.ConsumerTest do
  use ExUnit.Case, async: true

  alias AshReports.Streaming.Consumer

  describe "buffering functionality" do
    test "create_buffer/1 creates a buffer with default batch size" do
      {:ok, buffer} = Consumer.create_buffer()

      assert buffer.batch_size == 100
      assert buffer.records == []
      assert buffer.total_buffered == 0
    end

    test "create_buffer/1 creates a buffer with custom batch size" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 50)

      assert buffer.batch_size == 50
      assert buffer.records == []
      assert buffer.total_buffered == 0
    end

    test "add_to_buffer/2 buffers records without flushing" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 5)

      {:buffering, buffer} = Consumer.add_to_buffer(buffer, [%{id: 1}, %{id: 2}])

      assert length(buffer.records) == 2
      assert buffer.total_buffered == 2
    end

    test "add_to_buffer/2 flushes when batch size is reached" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 3)

      {:buffering, buffer} = Consumer.add_to_buffer(buffer, [%{id: 1}])
      {:buffering, buffer} = Consumer.add_to_buffer(buffer, [%{id: 2}])
      {:flush, records, new_buffer} = Consumer.add_to_buffer(buffer, [%{id: 3}])

      assert length(records) == 3
      assert Enum.map(records, & &1.id) == [1, 2, 3]
      assert new_buffer.records == []
      assert new_buffer.total_buffered == 3
    end

    test "add_to_buffer/2 flushes when adding multiple records exceeds batch size" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 2)

      {:flush, records, new_buffer} =
        Consumer.add_to_buffer(buffer, [%{id: 1}, %{id: 2}, %{id: 3}])

      assert length(records) == 3
      assert new_buffer.records == []
      assert new_buffer.total_buffered == 3
    end

    test "flush_buffer/1 returns remaining buffered records" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 10)

      {:buffering, buffer} = Consumer.add_to_buffer(buffer, [%{id: 1}, %{id: 2}])
      {:ok, remaining} = Consumer.flush_buffer(buffer)

      assert length(remaining) == 2
      assert Enum.map(remaining, & &1.id) == [1, 2]
    end

    test "flush_buffer/1 returns empty list when buffer is empty" do
      {:ok, buffer} = Consumer.create_buffer()

      {:ok, remaining} = Consumer.flush_buffer(buffer)

      assert remaining == []
    end

    test "buffer tracks total_buffered correctly across flushes" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 2)

      {:flush, _records, buffer} = Consumer.add_to_buffer(buffer, [%{id: 1}, %{id: 2}])
      assert buffer.total_buffered == 2

      {:flush, _records, buffer} = Consumer.add_to_buffer(buffer, [%{id: 3}, %{id: 4}])
      assert buffer.total_buffered == 4

      {:buffering, buffer} = Consumer.add_to_buffer(buffer, [%{id: 5}])
      assert buffer.total_buffered == 5
    end
  end

  describe "error handling functionality" do
    test "with_error_handling/2 wraps successful consume function" do
      consume_fn = fn _chunk, state ->
        {:ok, state + 1}
      end

      safe_consume = Consumer.with_error_handling(consume_fn)
      chunk = %{records: [%{id: 1}], metadata: %{}}

      {:ok, new_state} = safe_consume.(chunk, 0)

      assert new_state == 1
    end

    test "with_error_handling/2 catches raised errors and calls on_error" do
      consume_fn = fn _chunk, _state ->
        raise "Test error"
      end

      error_handler = fn error, state ->
        {:ok, Map.put(state, :error_caught, true) |> Map.put(:error, error)}
      end

      safe_consume = Consumer.with_error_handling(consume_fn, on_error: error_handler)
      chunk = %{records: [%{id: 1}], metadata: %{}}

      {:ok, new_state} = safe_consume.(chunk, %{error_caught: false})

      assert new_state.error_caught == true
      assert match?(%RuntimeError{}, new_state.error)
    end

    test "with_error_handling/2 catches thrown errors" do
      consume_fn = fn _chunk, _state ->
        throw(:test_throw)
      end

      error_caught = ref = make_ref()

      error_handler = fn _error, _state ->
        send(self(), {:error_handled, error_caught})
        {:ok, :error_handled}
      end

      safe_consume = Consumer.with_error_handling(consume_fn, on_error: error_handler)
      chunk = %{records: [], metadata: %{}}

      {:ok, result} = safe_consume.(chunk, %{})

      assert result == :error_handled
      assert_received {:error_handled, ^error_caught}
    end

    test "with_error_handling/2 retries on failure" do
      # Create a counter to track attempts
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      consume_fn = fn _chunk, state ->
        attempt = Agent.get_and_update(agent, fn count -> {count + 1, count + 1} end)

        if attempt < 3 do
          raise "Attempt #{attempt} failed"
        else
          {:ok, state}
        end
      end

      safe_consume = Consumer.with_error_handling(consume_fn, max_retries: 2, retry_delay: 10)
      chunk = %{records: [], metadata: %{}}

      {:ok, _state} = safe_consume.(chunk, %{})

      # Should have attempted 3 times (initial + 2 retries)
      final_count = Agent.get(agent, & &1)
      assert final_count == 3

      Agent.stop(agent)
    end

    test "with_error_handling/2 gives up after max retries" do
      consume_fn = fn _chunk, _state ->
        raise "Always fails"
      end

      error_handler = fn error, _state ->
        {:error, {:max_retries_exceeded, error}}
      end

      safe_consume =
        Consumer.with_error_handling(consume_fn,
          max_retries: 2,
          retry_delay: 10,
          on_error: error_handler
        )

      chunk = %{records: [], metadata: %{}}

      {:error, {:max_retries_exceeded, _}} = safe_consume.(chunk, %{})
    end

    test "with_error_handling/2 uses default error handler when not provided" do
      consume_fn = fn _chunk, _state ->
        raise ArgumentError, "test error"
      end

      safe_consume = Consumer.with_error_handling(consume_fn)
      chunk = %{records: [], metadata: %{}}

      {:error, {:consume_chunk_failed, error}} = safe_consume.(chunk, %{})

      assert match?(%ArgumentError{}, error)
    end
  end

  describe "progress tracking functionality" do
    test "create_progress_tracker/1 creates tracker with default values" do
      {:ok, tracker} = Consumer.create_progress_tracker()

      assert tracker.total == nil
      assert tracker.processed == 0
      assert %DateTime{} = tracker.started_at
      assert %DateTime{} = tracker.last_update
    end

    test "create_progress_tracker/1 creates tracker with total" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 1000)

      assert tracker.total == 1000
      assert tracker.processed == 0
    end

    test "update_progress/2 updates processed count" do
      {:ok, tracker} = Consumer.create_progress_tracker()

      updated = Consumer.update_progress(tracker, processed: 500)

      assert updated.processed == 500
      assert DateTime.compare(updated.last_update, tracker.last_update) == :gt
    end

    test "update_progress/2 increments processed count" do
      {:ok, tracker} = Consumer.create_progress_tracker()
      tracker = Consumer.update_progress(tracker, processed: 100)

      updated = Consumer.update_progress(tracker, increment: 50)

      assert updated.processed == 150
    end

    test "progress_percentage/1 returns nil when total is unknown" do
      {:ok, tracker} = Consumer.create_progress_tracker()

      assert Consumer.progress_percentage(tracker) == nil
    end

    test "progress_percentage/1 calculates correct percentage" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 1000)
      tracker = Consumer.update_progress(tracker, processed: 250)

      percentage = Consumer.progress_percentage(tracker)

      assert percentage == 25.0
    end

    test "progress_percentage/1 returns 0 when total is 0" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 0)

      percentage = Consumer.progress_percentage(tracker)

      assert percentage == 0.0
    end

    test "progress_percentage/1 handles 100% completion" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 500)
      tracker = Consumer.update_progress(tracker, processed: 500)

      percentage = Consumer.progress_percentage(tracker)

      assert percentage == 100.0
    end

    test "estimate_remaining/1 returns error when total is unknown" do
      {:ok, tracker} = Consumer.create_progress_tracker()

      assert Consumer.estimate_remaining(tracker) == {:error, :unknown_total}
    end

    test "estimate_remaining/1 returns infinity when no progress made" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 1000)

      assert Consumer.estimate_remaining(tracker) == {:ok, :infinity}
    end

    test "estimate_remaining/1 calculates time remaining" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 1000)

      # Simulate that 1 second has passed
      started_at = DateTime.add(DateTime.utc_now(), -1, :second)
      tracker = %{tracker | started_at: started_at, processed: 100}

      {:ok, remaining} = Consumer.estimate_remaining(tracker)

      # Should be approximately 9 seconds (900 records at 100 records/sec)
      assert_in_delta remaining, 9.0, 1.0
    end

    test "progress_summary/1 includes all progress information" do
      {:ok, tracker} = Consumer.create_progress_tracker(total: 1000)

      # Simulate progress
      started_at = DateTime.add(DateTime.utc_now(), -10, :second)
      tracker = %{tracker | started_at: started_at, processed: 500}

      summary = Consumer.progress_summary(tracker)

      assert summary.processed == 500
      assert summary.total == 1000
      assert summary.percentage == 50.0
      assert summary.elapsed_seconds >= 9
      assert is_float(summary.estimated_remaining_seconds)
    end

    test "progress_summary/1 works without total" do
      {:ok, tracker} = Consumer.create_progress_tracker()
      tracker = Consumer.update_progress(tracker, processed: 500)

      summary = Consumer.progress_summary(tracker)

      assert summary.processed == 500
      assert summary.total == nil
      assert summary.percentage == nil
      assert is_integer(summary.elapsed_seconds)
      refute Map.has_key?(summary, :estimated_remaining_seconds)
    end
  end

  describe "behavior contract" do
    defmodule TestConsumer do
      @behaviour AshReports.Streaming.Consumer

      @impl true
      def consume_chunk(chunk, state) do
        records = chunk.records
        new_count = state.count + length(records)
        new_records = state.all_records ++ records

        {:ok, %{state | count: new_count, all_records: new_records}}
      end

      @impl true
      def finalize(state) do
        {:ok, %{total_count: state.count, records: state.all_records}}
      end
    end

    test "consumer behavior can be implemented" do
      initial_state = %{count: 0, all_records: []}

      chunk1 = %{records: [%{id: 1}, %{id: 2}], metadata: %{chunk_index: 0}}
      chunk2 = %{records: [%{id: 3}], metadata: %{chunk_index: 1}}

      {:ok, state} = TestConsumer.consume_chunk(chunk1, initial_state)
      assert state.count == 2

      {:ok, state} = TestConsumer.consume_chunk(chunk2, state)
      assert state.count == 3

      {:ok, result} = TestConsumer.finalize(state)

      assert result.total_count == 3
      assert length(result.records) == 3
      assert Enum.map(result.records, & &1.id) == [1, 2, 3]
    end
  end

  describe "integration scenarios" do
    defmodule BufferedConsumer do
      @behaviour AshReports.Streaming.Consumer

      @impl true
      def consume_chunk(chunk, state) do
        # Use buffering helper
        case Consumer.add_to_buffer(state.buffer, chunk.records) do
          {:buffering, new_buffer} ->
            {:ok, %{state | buffer: new_buffer}}

          {:flush, records, new_buffer} ->
            # Process flushed batch
            processed = process_batch(records)
            new_output = state.output ++ processed
            {:ok, %{state | buffer: new_buffer, output: new_output}}
        end
      end

      @impl true
      def finalize(state) do
        # Flush remaining buffered records
        {:ok, remaining} = Consumer.flush_buffer(state.buffer)
        processed = process_batch(remaining)
        final_output = state.output ++ processed

        {:ok, final_output}
      end

      defp process_batch(records) do
        Enum.map(records, fn record -> "Processed: #{record.id}" end)
      end
    end

    test "consumer with buffering helper" do
      {:ok, buffer} = Consumer.create_buffer(batch_size: 3)
      initial_state = %{buffer: buffer, output: []}

      # Send chunks smaller than batch size
      chunk1 = %{records: [%{id: 1}, %{id: 2}], metadata: %{}}
      {:ok, state} = BufferedConsumer.consume_chunk(chunk1, initial_state)
      assert state.output == []

      # This chunk should trigger flush
      chunk2 = %{records: [%{id: 3}], metadata: %{}}
      {:ok, state} = BufferedConsumer.consume_chunk(chunk2, state)
      assert length(state.output) == 3

      # Add one more chunk
      chunk3 = %{records: [%{id: 4}], metadata: %{}}
      {:ok, state} = BufferedConsumer.consume_chunk(chunk3, state)

      # Finalize to get remaining buffered record
      {:ok, final_output} = BufferedConsumer.finalize(state)

      assert length(final_output) == 4
      assert "Processed: 4" in final_output
    end

    test "consumer with error handling and progress tracking" do
      consume_fn = fn chunk, state ->
        # Update progress
        tracker = Consumer.update_progress(state.tracker, increment: length(chunk.records))

        # Simulate occasional errors
        if rem(state.chunk_count, 3) == 2 do
          raise "Simulated error"
        end

        new_state = %{
          state
          | chunk_count: state.chunk_count + 1,
            tracker: tracker,
            total_records: state.total_records + length(chunk.records)
        }

        {:ok, new_state}
      end

      error_handler = fn _error, state ->
        # Log error and continue
        new_state = %{state | error_count: state.error_count + 1}
        {:ok, new_state}
      end

      safe_consume = Consumer.with_error_handling(consume_fn, on_error: error_handler)

      {:ok, tracker} = Consumer.create_progress_tracker(total: 10)

      initial_state = %{
        chunk_count: 0,
        total_records: 0,
        error_count: 0,
        tracker: tracker
      }

      # Process multiple chunks
      chunks = [
        %{records: [%{id: 1}], metadata: %{}},
        %{records: [%{id: 2}], metadata: %{}},
        %{records: [%{id: 3}], metadata: %{}},
        %{records: [%{id: 4}], metadata: %{}}
      ]

      final_state =
        Enum.reduce(chunks, initial_state, fn chunk, state ->
          {:ok, new_state} = safe_consume.(chunk, state)
          new_state
        end)

      # Should have processed some chunks and caught some errors
      assert final_state.chunk_count > 0
      assert final_state.error_count > 0
      assert final_state.total_records > 0

      # Progress should be updated
      assert final_state.tracker.processed > 0
    end
  end
end
