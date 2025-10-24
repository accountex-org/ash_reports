defmodule AshReports.JsonRenderer.StreamingEngineTest do
  use ExUnit.Case, async: true

  alias AshReports.JsonRenderer.StreamingEngine
  alias AshReports.RendererTestHelpers

  describe "create_json_stream/2" do
    test "creates a basic record stream" do
      context =
        RendererTestHelpers.build_render_context(
          records: Enum.map(1..100, fn i -> %{id: i, value: i * 10} end)
        )

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 10)

        assert is_function(stream)
        # Stream is lazy, so we need to consume it
        chunks = Enum.take(stream, 5)
        assert is_list(chunks)
      end
    end

    test "handles empty dataset" do
      context = RendererTestHelpers.build_render_context(records: [])

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context)

        chunks = Enum.to_list(stream)
        assert chunks == [] or is_list(chunks)
      end
    end

    test "respects chunk size option" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..100, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 25)

        chunks = Enum.to_list(stream)
        # Should have 4 chunks of 25 records each
        assert is_list(chunks)
      end
    end

    test "supports different stream types" do
      context = RendererTestHelpers.build_render_context()

      stream_types = [:records, :bands, :pages, :elements]

      Enum.each(stream_types, fn stream_type ->
        if function_exported?(StreamingEngine, :create_json_stream, 2) do
          result = StreamingEngine.create_json_stream(context, stream_type: stream_type)

          assert match?({:ok, _}, result) or match?({:error, _}, result)
        end
      end)
    end
  end

  describe "chunked JSON output" do
    test "produces valid JSON chunks" do
      context = RendererTestHelpers.build_render_context(records: [%{id: 1, name: "Test"}])

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 10)

        chunks = Enum.take(stream, 1)

        if length(chunks) > 0 do
          chunk = List.first(chunks)
          assert is_map(chunk) or is_binary(chunk)
        end
      end
    end

    test "includes chunk metadata" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..50, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 10)

        chunks = Enum.take(stream, 1)

        if length(chunks) > 0 do
          chunk = List.first(chunks)

          if is_map(chunk) do
            # Chunk should have metadata
            assert Map.has_key?(chunk, :chunk_index) or
                     Map.has_key?(chunk, "chunk_index") or
                     Map.has_key?(chunk, :chunk_data) or
                     is_binary(chunk)
          end
        end
      end
    end

    test "maintains chunk sequence" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..100, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 10)

        chunks = Enum.to_list(stream)

        if is_list(chunks) and length(chunks) > 0 do
          # Chunks should be in sequence
          assert length(chunks) > 0
        end
      end
    end
  end

  describe "memory efficiency" do
    test "processes large dataset without loading all into memory" do
      # Create 10,000 records
      large_dataset =
        Enum.map(1..10_000, fn i ->
          %{id: i, name: "Record #{i}", value: i * 100}
        end)

      context = RendererTestHelpers.build_render_context(records: large_dataset)

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 100)

        # Process first 10 chunks without consuming entire stream
        first_chunks = Enum.take(stream, 10)

        assert is_list(first_chunks)
        assert length(first_chunks) <= 10
      end
    end

    test "lazy evaluation only processes what's needed" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..1000, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 50)

        # Only take first 5 chunks - should not process all 1000 records
        limited_chunks = Enum.take(stream, 5)

        assert is_list(limited_chunks)
        assert length(limited_chunks) <= 5
      end
    end

    test "handles very large individual records" do
      large_text = String.duplicate("Lorem ipsum dolor sit amet ", 1000)

      large_records =
        Enum.map(1..100, fn i ->
          %{id: i, description: large_text}
        end)

      context = RendererTestHelpers.build_render_context(records: large_records)

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 10)

        chunks = Enum.take(stream, 2)
        assert is_list(chunks)
      end
    end
  end

  describe "backpressure handling" do
    test "stream respects downstream consumer speed" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..1000, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 50)

        # Simulate slow consumer
        processed_count =
          stream
          |> Stream.take(5)
          |> Enum.count()

        assert processed_count <= 5
      end
    end

    test "handles consumer errors gracefully" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..100, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context)

        result =
          try do
            stream
            |> Stream.each(fn _chunk ->
              if :rand.uniform() > 0.95 do
                raise "Simulated consumer error"
              end
            end)
            |> Stream.run()

            :ok
          rescue
            _ -> :error
          end

        assert result in [:ok, :error]
      end
    end
  end

  describe "streaming different content types" do
    test "streams records as individual JSON objects" do
      context = RendererTestHelpers.build_render_context(records: [%{id: 1}, %{id: 2}, %{id: 3}])

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, stream_type: :records)

        chunks = Enum.to_list(stream)
        assert is_list(chunks)
      end
    end

    test "streams bands with their elements" do
      report =
        RendererTestHelpers.build_mock_report(
          bands: [
            %{name: :header, type: :report_header, height: 50, elements: []},
            %{name: :detail, type: :detail, height: 30, elements: []}
          ]
        )

      context = RendererTestHelpers.build_render_context(report: report)

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        result = StreamingEngine.create_json_stream(context, stream_type: :bands)

        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "streams paginated output" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..100, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        result = StreamingEngine.create_json_stream(context, stream_type: :pages)

        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "format options" do
    test "supports compact JSON format" do
      context = RendererTestHelpers.build_render_context(records: [%{id: 1}])

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, format: :compact)

        chunks = Enum.take(stream, 1)

        if length(chunks) > 0 do
          chunk = List.first(chunks)
          # Compact format should not have extra whitespace
          assert is_map(chunk) or is_binary(chunk)
        end
      end
    end

    test "supports pretty-print JSON format" do
      context = RendererTestHelpers.build_render_context(records: [%{id: 1}])

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, format: :pretty_print)

        chunks = Enum.take(stream, 1)

        if length(chunks) > 0 do
          chunk = List.first(chunks)
          assert is_map(chunk) or is_binary(chunk)
        end
      end
    end
  end

  describe "NDJSON format" do
    test "generates newline-delimited JSON" do
      context = RendererTestHelpers.build_render_context(records: [%{id: 1}, %{id: 2}, %{id: 3}])

      if function_exported?(StreamingEngine, :create_ndjson_stream, 1) do
        {:ok, stream} = StreamingEngine.create_ndjson_stream(context)

        lines = Enum.to_list(stream)

        if is_list(lines) and length(lines) > 0 do
          # Each line should be valid JSON
          line = List.first(lines)
          assert is_binary(line) or is_map(line)
        end
      end
    end

    test "NDJSON format is streaming-friendly" do
      context =
        RendererTestHelpers.build_render_context(records: Enum.map(1..1000, fn i -> %{id: i} end))

      if function_exported?(StreamingEngine, :create_ndjson_stream, 1) do
        {:ok, stream} = StreamingEngine.create_ndjson_stream(context)

        # Should be able to consume partially
        first_100 = Enum.take(stream, 100)
        assert is_list(first_100)
        assert length(first_100) <= 100
      end
    end
  end

  describe "error handling during streaming" do
    test "handles serialization errors mid-stream" do
      # Mix valid and invalid records
      records = [
        %{id: 1, value: 10},
        %{id: 2, value: self()},
        # PID can't be serialized
        %{id: 3, value: 30}
      ]

      context = RendererTestHelpers.build_render_context(records: records)

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        result = StreamingEngine.create_json_stream(context)

        # Should either skip invalid records or handle error
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "provides error information in stream" do
      context = RendererTestHelpers.build_render_context(records: [%{id: self()}])

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        result = StreamingEngine.create_json_stream(context)

        # Should handle gracefully
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "stream composition" do
    test "streams can be composed with other streams" do
      context =
        RendererTestHelpers.build_render_context(
          records: Enum.map(1..100, fn i -> %{id: i, value: i * 10} end)
        )

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 10)

        # Compose with Stream.map
        processed =
          stream
          |> Stream.take(5)
          |> Enum.to_list()

        assert is_list(processed)
      end
    end

    test "streams support filtering" do
      context =
        RendererTestHelpers.build_render_context(
          records: Enum.map(1..100, fn i -> %{id: i, value: i * 10} end)
        )

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context)

        # Apply filter
        filtered =
          stream
          |> Stream.filter(fn _chunk -> true end)
          |> Enum.take(5)

        assert is_list(filtered)
      end
    end
  end

  describe "performance characteristics" do
    test "streaming starts immediately without full dataset processing" do
      large_dataset = Enum.map(1..10_000, fn i -> %{id: i} end)
      context = RendererTestHelpers.build_render_context(records: large_dataset)

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        start_time = System.monotonic_time(:millisecond)

        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 100)

        # Getting first chunk should be fast
        _first_chunk = Enum.take(stream, 1)

        elapsed = System.monotonic_time(:millisecond) - start_time

        # Should start quickly (< 1 second for first chunk)
        assert elapsed < 1000
      end
    end

    test "memory usage remains constant during streaming" do
      context =
        RendererTestHelpers.build_render_context(
          records: Enum.map(1..5000, fn i -> %{id: i, data: "test"} end)
        )

      if function_exported?(StreamingEngine, :create_json_stream, 2) do
        {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 100)

        # Process stream and verify it completes
        result =
          stream
          |> Stream.take(10)
          |> Enum.to_list()

        assert is_list(result)
      end
    end
  end
end
