defmodule AshReports.JsonRenderer.StreamingEngine do
  @moduledoc """
  Streaming Engine for AshReports JSON Renderer.

  The StreamingEngine provides memory-efficient streaming capabilities for
  processing large datasets in JSON format. It uses Elixir's Stream module
  to create lazy, composable streams that can handle datasets of any size
  without loading everything into memory.

  ## Streaming Features

  - **Memory Efficiency**: Process large datasets without memory exhaustion
  - **Lazy Evaluation**: Only process data as needed
  - **Composable Streams**: Chain multiple processing steps efficiently
  - **Chunk-Based Processing**: Configurable chunk sizes for optimal performance
  - **Back-Pressure Handling**: Automatic flow control for downstream consumers

  ## Stream Types

  - **Record Streams**: Stream individual records as JSON objects
  - **Band Streams**: Stream complete bands with their elements
  - **Page Streams**: Stream page-by-page for paginated output
  - **Element Streams**: Stream individual report elements

  ## Usage

      # Create a basic record stream
      {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 100)

      stream
      |> Stream.each(&process_json_chunk/1)
      |> Stream.run()

      # Stream with custom processing
      opts = [chunk_size: 500, format: :pretty_print]
      {:ok, stream} = StreamingEngine.create_json_stream(context, opts)

      # Collect results lazily
      results = Enum.take(stream, 10)

  """

  alias AshReports.{JsonRenderer.DataSerializer, RenderContext}

  @type stream_options :: [
          chunk_size: pos_integer(),
          format: :compact | :pretty_print,
          include_metadata: boolean(),
          stream_type: :records | :bands | :pages | :elements
        ]

  @type json_chunk :: %{
          chunk_data: String.t(),
          chunk_index: non_neg_integer(),
          total_chunks: pos_integer() | :unknown,
          metadata: map()
        }

  @default_chunk_size 1000

  @doc """
  Creates a JSON stream from a RenderContext.

  ## Examples

      {:ok, stream} = StreamingEngine.create_json_stream(context)
      {:ok, stream} = StreamingEngine.create_json_stream(context, chunk_size: 500)

  """
  @spec create_json_stream(RenderContext.t(), stream_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def create_json_stream(%RenderContext{} = context, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    stream_type = Keyword.get(opts, :stream_type, :records)

    case stream_type do
      :records -> create_record_stream(context, chunk_size, opts)
      :bands -> create_band_stream(context, chunk_size, opts)
      :pages -> create_page_stream(context, chunk_size, opts)
      :elements -> create_element_stream(context, chunk_size, opts)
      _ -> {:error, {:unsupported_stream_type, stream_type}}
    end
  end

  @doc """
  Creates a record-based JSON stream.

  ## Examples

      {:ok, stream} = StreamingEngine.create_record_stream(context, 100)

  """
  @spec create_record_stream(RenderContext.t(), pos_integer(), stream_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def create_record_stream(%RenderContext{} = context, chunk_size, opts \\ []) do
    total_records = length(context.records)
    total_chunks = div(total_records + chunk_size - 1, chunk_size)

    stream =
      context.records
      |> Stream.chunk_every(chunk_size)
      |> Stream.with_index()
      |> Stream.map(fn {record_chunk, chunk_index} ->
        create_record_chunk(record_chunk, chunk_index, total_chunks, context, opts)
      end)

    {:ok, stream}
  rescue
    error -> {:error, {:stream_creation_failed, error}}
  end

  @doc """
  Creates a band-based JSON stream.

  ## Examples

      {:ok, stream} = StreamingEngine.create_band_stream(context, 50)

  """
  @spec create_band_stream(RenderContext.t(), pos_integer(), stream_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def create_band_stream(%RenderContext{} = context, chunk_size, opts \\ []) do
    bands = get_report_bands(context)

    stream =
      Stream.resource(
        fn -> {bands, context, 0} end,
        fn
          {[], _context, _index} ->
            {:halt, nil}

          {remaining_bands, stream_context, index} ->
            {current_bands, rest} = Enum.split(remaining_bands, chunk_size)
            chunk = create_band_chunk(current_bands, index, stream_context, opts)
            {[chunk], {rest, stream_context, index + 1}}
        end,
        fn _ -> :ok end
      )

    {:ok, stream}
  rescue
    error -> {:error, {:band_stream_creation_failed, error}}
  end

  @doc """
  Creates a page-based JSON stream for paginated output.

  ## Examples

      {:ok, stream} = StreamingEngine.create_page_stream(context, 20)

  """
  @spec create_page_stream(RenderContext.t(), pos_integer(), stream_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def create_page_stream(%RenderContext{} = context, page_size, opts \\ []) do
    total_records = length(context.records)
    total_pages = div(total_records + page_size - 1, page_size)

    stream =
      0..(total_pages - 1)
      |> Stream.map(fn page_index ->
        start_index = page_index * page_size
        page_records = Enum.slice(context.records, start_index, page_size)
        create_page_chunk(page_records, page_index, total_pages, context, opts)
      end)

    {:ok, stream}
  rescue
    error -> {:error, {:page_stream_creation_failed, error}}
  end

  @doc """
  Creates an element-based JSON stream.

  ## Examples

      {:ok, stream} = StreamingEngine.create_element_stream(context, 200)

  """
  @spec create_element_stream(RenderContext.t(), pos_integer(), stream_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def create_element_stream(%RenderContext{} = context, chunk_size, opts \\ []) do
    elements = get_all_elements(context)
    total_elements = length(elements)
    total_chunks = div(total_elements + chunk_size - 1, chunk_size)

    stream =
      elements
      |> Stream.chunk_every(chunk_size)
      |> Stream.with_index()
      |> Stream.map(fn {element_chunk, chunk_index} ->
        create_element_chunk(element_chunk, chunk_index, total_chunks, context, opts)
      end)

    {:ok, stream}
  rescue
    error -> {:error, {:element_stream_creation_failed, error}}
  end

  @doc """
  Collects a stream into a single JSON document.

  ## Examples

      {:ok, json_document} = StreamingEngine.collect_stream(stream)

  """
  @spec collect_stream(Enumerable.t()) :: {:ok, String.t()} | {:error, term()}
  def collect_stream(stream) do
    chunks =
      stream
      |> Enum.map(& &1.chunk_data)
      |> Enum.join(",")

    json_document = "[" <> chunks <> "]"
    {:ok, json_document}
  rescue
    error -> {:error, {:stream_collection_failed, error}}
  end

  @doc """
  Transforms a stream with a custom function.

  ## Examples

      transformed_stream = StreamingEngine.transform_stream(stream, &custom_transformer/1)

  """
  @spec transform_stream(Enumerable.t(), function()) :: Enumerable.t()
  def transform_stream(stream, transformer_fn) when is_function(transformer_fn, 1) do
    Stream.map(stream, transformer_fn)
  end

  @doc """
  Filters a stream based on a predicate function.

  ## Examples

      filtered_stream = StreamingEngine.filter_stream(stream, &has_data?/1)

  """
  @spec filter_stream(Enumerable.t(), function()) :: Enumerable.t()
  def filter_stream(stream, predicate_fn) when is_function(predicate_fn, 1) do
    Stream.filter(stream, predicate_fn)
  end

  @doc """
  Cleans up streaming resources and temporary data.
  """
  @spec cleanup_streaming_resources() :: :ok
  def cleanup_streaming_resources do
    # Clean up any streaming-specific resources
    Process.delete(:ash_reports_streaming_cache)
    :ok
  end

  # Private implementation functions

  defp create_record_chunk(records, chunk_index, total_chunks, context, opts) do
    serialization_opts = build_serialization_options(opts)

    chunk_data =
      case DataSerializer.serialize_records(records, serialization_opts) do
        {:ok, serialized_records} ->
          encode_chunk_data(serialized_records, opts)

        {:error, reason} ->
          encode_error_chunk(reason, chunk_index)
      end

    %{
      chunk_data: chunk_data,
      chunk_index: chunk_index,
      total_chunks: total_chunks,
      metadata: %{
        chunk_type: :records,
        record_count: length(records),
        context_id: get_context_id(context),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp create_band_chunk(bands, chunk_index, context, opts) do
    serialization_opts = build_serialization_options(opts)

    chunk_data =
      case serialize_bands(bands, context, serialization_opts) do
        {:ok, serialized_bands} ->
          encode_chunk_data(serialized_bands, opts)

        {:error, reason} ->
          encode_error_chunk(reason, chunk_index)
      end

    %{
      chunk_data: chunk_data,
      chunk_index: chunk_index,
      total_chunks: :unknown,
      metadata: %{
        chunk_type: :bands,
        band_count: length(bands),
        context_id: get_context_id(context),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp create_page_chunk(page_records, page_index, total_pages, context, opts) do
    serialization_opts = build_serialization_options(opts)

    chunk_data =
      case DataSerializer.serialize_records(page_records, serialization_opts) do
        {:ok, serialized_records} ->
          page_data = %{
            page: page_index + 1,
            total_pages: total_pages,
            records: serialized_records
          }

          encode_chunk_data(page_data, opts)

        {:error, reason} ->
          encode_error_chunk(reason, page_index)
      end

    %{
      chunk_data: chunk_data,
      chunk_index: page_index,
      total_chunks: total_pages,
      metadata: %{
        chunk_type: :page,
        record_count: length(page_records),
        page_number: page_index + 1,
        context_id: get_context_id(context),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp create_element_chunk(elements, chunk_index, total_chunks, context, opts) do
    serialization_opts = build_serialization_options(opts)

    chunk_data =
      case serialize_elements(elements, context, serialization_opts) do
        {:ok, serialized_elements} ->
          encode_chunk_data(serialized_elements, opts)

        {:error, reason} ->
          encode_error_chunk(reason, chunk_index)
      end

    %{
      chunk_data: chunk_data,
      chunk_index: chunk_index,
      total_chunks: total_chunks,
      metadata: %{
        chunk_type: :elements,
        element_count: length(elements),
        context_id: get_context_id(context),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp encode_chunk_data(data, opts) do
    case Keyword.get(opts, :format, :compact) do
      :pretty_print ->
        Jason.encode!(data, pretty: true)

      :compact ->
        Jason.encode!(data)
    end
  end

  defp encode_error_chunk(reason, chunk_index) do
    error_data = %{
      error: true,
      reason: to_string(reason),
      chunk_index: chunk_index,
      timestamp: DateTime.utc_now()
    }

    Jason.encode!(error_data)
  end

  defp build_serialization_options(opts) do
    [
      date_format: Keyword.get(opts, :date_format, :iso8601),
      number_precision: Keyword.get(opts, :number_precision),
      include_nulls: Keyword.get(opts, :include_nulls, true)
    ]
  end

  defp get_report_bands(%RenderContext{report: %{bands: bands}}) when is_list(bands), do: bands
  defp get_report_bands(_context), do: []

  defp get_all_elements(%RenderContext{} = context) do
    context
    |> get_report_bands()
    |> Enum.flat_map(fn band ->
      Map.get(band, :elements, [])
    end)
  end

  defp serialize_bands(bands, context, opts) do
    bands
    |> Enum.reduce_while({:ok, []}, fn band, {:ok, acc} ->
      elements = Map.get(band, :elements, [])

      case serialize_elements(elements, context, opts) do
        {:ok, serialized_elements} ->
          band_data = %{
            name: Map.get(band, :name, "unknown"),
            type: Map.get(band, :type, "unknown"),
            elements: serialized_elements
          }

          {:cont, {:ok, [band_data | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:band_serialization_failed, band, reason}}}
      end
    end)
    |> case do
      {:ok, reversed_bands} -> {:ok, Enum.reverse(reversed_bands)}
      {:error, _reason} = error -> error
    end
  end

  defp serialize_elements(elements, _context, opts) do
    elements
    |> Enum.reduce_while({:ok, []}, fn element, {:ok, acc} ->
      case DataSerializer.serialize_with_options(element, opts) do
        {:ok, serialized} ->
          {:cont, {:ok, [serialized | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:element_serialization_failed, element, reason}}}
      end
    end)
    |> case do
      {:ok, reversed_elements} -> {:ok, Enum.reverse(reversed_elements)}
      {:error, _reason} = error -> error
    end
  end

  defp get_context_id(%RenderContext{created_at: created_at}) do
    :erlang.phash2({created_at, self()}, 1_000_000)
  end
end
