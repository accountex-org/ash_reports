defmodule AshReports.Streaming.Consumer do
  @moduledoc """
  Behavior and utilities for consuming streamed data from the GenStage pipeline.

  This module defines a standardized protocol that all renderers (HTML, HEEX, JSON, PDF)
  implement to consume streamed data chunks from the AshReports streaming pipeline.

  ## Architecture

  The StreamingConsumer behavior provides a consistent interface for renderers to:
  - Consume chunks of data as they arrive from the GenStage pipeline
  - Process data incrementally without loading everything into memory
  - Track progress and handle errors gracefully
  - Finalize output after all chunks are consumed

  ## Implementing a StreamingConsumer

  To create a renderer that supports streaming, implement the `StreamingConsumer` behavior:

      defmodule MyRenderer do
        @behaviour AshReports.Streaming.Consumer

        @impl true
        def consume_chunk(chunk, state) do
          # Process this chunk of data
          processed = process_records(chunk.records)
          new_state = update_state(state, processed)
          {:ok, new_state}
        end

        @impl true
        def finalize(state) do
          # Generate final output
          output = build_final_output(state)
          {:ok, output}
        end
      end

  ## Using Helper Functions

  This module provides helper functions for common streaming patterns:

  ### Buffering

      # Buffer chunks until reaching batch size
      {:ok, buffer} = Consumer.create_buffer(batch_size: 100)
      {:buffering, buffer} = Consumer.add_to_buffer(buffer, chunk)
      {:flush, records, buffer} = Consumer.add_to_buffer(buffer, last_chunk)

  ### Error Handling

      # Wrap consumer with automatic error handling
      safe_consumer = Consumer.with_error_handling(&my_consume_function/2,
        on_error: &handle_error/2
      )

  ### Progress Tracking

      # Track progress through the stream
      {:ok, tracker} = Consumer.create_progress_tracker(total: 10000)
      tracker = Consumer.update_progress(tracker, processed: 1000)
      percentage = Consumer.progress_percentage(tracker)

  ## Example: HTML Renderer with Streaming

      defmodule HtmlRenderer do
        @behaviour AshReports.Streaming.Consumer

        @impl true
        def consume_chunk(chunk, state) do
          # Convert records to HTML fragments
          html_fragments = Enum.map(chunk.records, &to_html/1)

          # Append to accumulated HTML
          new_html = state.html <> Enum.join(html_fragments, "\\n")
          new_state = %{state | html: new_html, count: state.count + length(chunk.records)}

          {:ok, new_state}
        end

        @impl true
        def finalize(state) do
          # Wrap accumulated HTML in document structure
          complete_html =
            "<!DOCTYPE html>" <>
            "<html><body>" <>
            state.html <>
            "</body></html>"

          {:ok, %{content: complete_html, metadata: %{record_count: state.count}}}
        end
      end

  ## Chunk Format

  Chunks passed to `consume_chunk/2` have this structure:

      %{
        records: [%{...}, %{...}],           # Batch of processed records
        metadata: %{
          chunk_index: 0,                    # Index of this chunk
          chunk_size: 100,                   # Number of records in chunk
          total_processed: 100               # Total records processed so far
        }
      }
  """

  @typedoc """
  State maintained by the consumer across chunk processing.

  This can be any term - typically a map containing accumulated results,
  counters, buffers, or other state needed by the renderer.
  """
  @type consumer_state :: term()

  @typedoc """
  A chunk of data from the streaming pipeline.
  """
  @type chunk :: %{
          records: [map()],
          metadata: %{
            chunk_index: non_neg_integer(),
            chunk_size: non_neg_integer(),
            total_processed: non_neg_integer()
          }
        }

  @typedoc """
  Result of consuming a chunk.
  """
  @type consume_result :: {:ok, consumer_state()} | {:error, term()}

  @typedoc """
  Result of finalizing the consumer.
  """
  @type finalize_result :: {:ok, term()} | {:error, term()}

  @doc """
  Consumes a chunk of streamed data.

  Called for each chunk of data as it arrives from the GenStage pipeline.
  The consumer should process the chunk and return updated state.

  ## Parameters

    * `chunk` - A chunk of data containing records and metadata
    * `state` - Current consumer state

  ## Returns

    * `{:ok, new_state}` - Successfully processed chunk
    * `{:error, reason}` - Failed to process chunk
  """
  @callback consume_chunk(chunk(), consumer_state()) :: consume_result()

  @doc """
  Finalizes processing after all chunks have been consumed.

  Called once after all chunks have been processed. The consumer should
  generate its final output based on the accumulated state.

  ## Parameters

    * `state` - Final consumer state after all chunks

  ## Returns

    * `{:ok, result}` - Successfully generated final output
    * `{:error, reason}` - Failed to finalize
  """
  @callback finalize(consumer_state()) :: finalize_result()

  # Buffering Helper

  @typedoc """
  Buffer for batching chunks before processing.
  """
  @type buffer :: %{
          records: [map()],
          batch_size: pos_integer(),
          total_buffered: non_neg_integer()
        }

  @typedoc """
  Result of adding to buffer.
  """
  @type buffer_result ::
          {:buffering, buffer()}
          | {:flush, records :: [map()], buffer()}

  @doc """
  Creates a new buffer for batching chunks.

  ## Options

    * `:batch_size` - Number of records to accumulate before flushing (default: 100)

  ## Examples

      {:ok, buffer} = Consumer.create_buffer(batch_size: 50)
  """
  @spec create_buffer(keyword()) :: {:ok, buffer()}
  def create_buffer(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 100)

    buffer = %{
      records: [],
      batch_size: batch_size,
      total_buffered: 0
    }

    {:ok, buffer}
  end

  @doc """
  Adds records to the buffer.

  Returns `{:buffering, buffer}` if more records can be added, or
  `{:flush, records, buffer}` when the batch size is reached.

  ## Examples

      {:ok, buffer} = Consumer.create_buffer(batch_size: 2)
      {:buffering, buffer} = Consumer.add_to_buffer(buffer, [%{id: 1}])
      {:flush, records, buffer} = Consumer.add_to_buffer(buffer, [%{id: 2}])
  """
  @spec add_to_buffer(buffer(), [map()]) :: buffer_result()
  def add_to_buffer(buffer, records) when is_list(records) do
    new_records = buffer.records ++ records
    new_total = buffer.total_buffered + length(records)

    if length(new_records) >= buffer.batch_size do
      # Flush the buffer
      new_buffer = %{buffer | records: [], total_buffered: new_total}
      {:flush, new_records, new_buffer}
    else
      # Keep buffering
      new_buffer = %{buffer | records: new_records, total_buffered: new_total}
      {:buffering, new_buffer}
    end
  end

  @doc """
  Flushes any remaining records in the buffer.

  Call this after processing all chunks to ensure no records are left buffered.

  ## Examples

      {:ok, remaining_records} = Consumer.flush_buffer(buffer)
  """
  @spec flush_buffer(buffer()) :: {:ok, [map()]}
  def flush_buffer(buffer) do
    {:ok, buffer.records}
  end

  # Error Handling Helper

  @typedoc """
  Options for error handling.
  """
  @type error_handling_opts :: [
          on_error: (term(), consumer_state() -> {:ok, consumer_state()} | {:error, term()}),
          max_retries: non_neg_integer(),
          retry_delay: non_neg_integer()
        ]

  @doc """
  Wraps a consume function with error handling.

  Returns a new function that catches errors and handles them according to options.

  ## Options

    * `:on_error` - Function to call on error: `fn error, state -> {:ok, state} | {:error, term()} end`
    * `:max_retries` - Maximum retry attempts (default: 0)
    * `:retry_delay` - Delay between retries in milliseconds (default: 1000)

  ## Examples

      safe_consume = Consumer.with_error_handling(
        &my_consume/2,
        on_error: fn error, state ->
          Logger.error("Chunk processing failed: \#{inspect(error)}")
          {:ok, state}  # Continue processing
        end
      )

      {:ok, state} = safe_consume.(chunk, state)
  """
  @spec with_error_handling(
          (chunk(), consumer_state() -> consume_result()),
          error_handling_opts()
        ) ::
          (chunk(), consumer_state() -> consume_result())
  def with_error_handling(consume_fn, opts \\ []) do
    on_error = Keyword.get(opts, :on_error, &default_error_handler/2)
    max_retries = Keyword.get(opts, :max_retries, 0)
    retry_delay = Keyword.get(opts, :retry_delay, 1000)

    fn chunk, state ->
      do_with_retry(consume_fn, chunk, state, on_error, max_retries, retry_delay, 0)
    end
  end

  defp do_with_retry(consume_fn, chunk, state, on_error, max_retries, retry_delay, attempt) do
    try do
      consume_fn.(chunk, state)
    rescue
      error ->
        if attempt < max_retries do
          Process.sleep(retry_delay)
          do_with_retry(consume_fn, chunk, state, on_error, max_retries, retry_delay, attempt + 1)
        else
          on_error.(error, state)
        end
    catch
      kind, reason ->
        error = {kind, reason}

        if attempt < max_retries do
          Process.sleep(retry_delay)
          do_with_retry(consume_fn, chunk, state, on_error, max_retries, retry_delay, attempt + 1)
        else
          on_error.(error, state)
        end
    end
  end

  defp default_error_handler(error, _state) do
    {:error, {:consume_chunk_failed, error}}
  end

  # Progress Tracking Helper

  @typedoc """
  Progress tracker for monitoring streaming progress.
  """
  @type progress_tracker :: %{
          total: non_neg_integer() | nil,
          processed: non_neg_integer(),
          started_at: DateTime.t(),
          last_update: DateTime.t()
        }

  @doc """
  Creates a new progress tracker.

  ## Options

    * `:total` - Total number of records expected (default: nil for unknown)

  ## Examples

      {:ok, tracker} = Consumer.create_progress_tracker(total: 10000)
  """
  @spec create_progress_tracker(keyword()) :: {:ok, progress_tracker()}
  def create_progress_tracker(opts \\ []) do
    total = Keyword.get(opts, :total)
    now = DateTime.utc_now()

    tracker = %{
      total: total,
      processed: 0,
      started_at: now,
      last_update: now
    }

    {:ok, tracker}
  end

  @doc """
  Updates the progress tracker with new processed count.

  ## Examples

      tracker = Consumer.update_progress(tracker, processed: 1000)
      tracker = Consumer.update_progress(tracker, increment: 100)
  """
  @spec update_progress(progress_tracker(), keyword()) :: progress_tracker()
  def update_progress(tracker, opts) do
    processed =
      cond do
        Keyword.has_key?(opts, :processed) ->
          Keyword.get(opts, :processed)

        Keyword.has_key?(opts, :increment) ->
          tracker.processed + Keyword.get(opts, :increment)

        true ->
          tracker.processed
      end

    %{tracker | processed: processed, last_update: DateTime.utc_now()}
  end

  @doc """
  Calculates progress percentage (0-100).

  Returns `nil` if total is unknown.

  ## Examples

      percentage = Consumer.progress_percentage(tracker)
      # => 45.5
  """
  @spec progress_percentage(progress_tracker()) :: float() | nil
  def progress_percentage(%{total: nil}), do: nil

  def progress_percentage(%{total: total, processed: processed}) when total > 0 do
    processed / total * 100.0
  end

  def progress_percentage(_), do: 0.0

  @doc """
  Estimates time remaining based on current progress.

  Returns `{:ok, seconds}` or `{:error, :unknown_total}` if total is not set.

  ## Examples

      {:ok, seconds_remaining} = Consumer.estimate_remaining(tracker)
      # => {:ok, 125.5}
  """
  @spec estimate_remaining(progress_tracker()) :: {:ok, float()} | {:error, :unknown_total}
  def estimate_remaining(%{total: nil}), do: {:error, :unknown_total}

  def estimate_remaining(%{total: _total, processed: 0}), do: {:ok, :infinity}

  def estimate_remaining(%{total: total, processed: processed, started_at: started_at}) do
    elapsed_seconds = DateTime.diff(DateTime.utc_now(), started_at, :second)
    records_per_second = processed / max(elapsed_seconds, 1)
    remaining_records = total - processed

    if records_per_second > 0 do
      {:ok, remaining_records / records_per_second}
    else
      {:ok, :infinity}
    end
  end

  @doc """
  Gets a summary of current progress.

  ## Examples

      summary = Consumer.progress_summary(tracker)
      # => %{
      #   processed: 5000,
      #   total: 10000,
      #   percentage: 50.0,
      #   elapsed_seconds: 125,
      #   estimated_remaining_seconds: 125.0
      # }
  """
  @spec progress_summary(progress_tracker()) :: map()
  def progress_summary(tracker) do
    elapsed = DateTime.diff(DateTime.utc_now(), tracker.started_at, :second)

    base_summary = %{
      processed: tracker.processed,
      total: tracker.total,
      percentage: progress_percentage(tracker),
      elapsed_seconds: elapsed
    }

    case estimate_remaining(tracker) do
      {:ok, remaining} ->
        Map.put(base_summary, :estimated_remaining_seconds, remaining)

      {:error, :unknown_total} ->
        base_summary
    end
  end
end
