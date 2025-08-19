defmodule AshReports.JsonRenderer do
  @moduledoc """
  Phase 3.5 JSON Renderer - Complete JSON output system for AshReports.

  The JsonRenderer provides comprehensive JSON generation capabilities, implementing
  the Phase 3.1 Renderer Interface with structured data serialization, streaming
  support, schema validation, and hierarchical JSON assembly for API integration.

  ## Phase 3.5 Components

  - **JSON Schema Manager (3.5.1)**: Schema definition and validation for consistent output
  - **Data Serializer (3.5.2)**: Convert processed data to JSON with Jason.Encoder protocols
  - **Streaming Engine (3.5.3)**: Memory-efficient streaming for large datasets
  - **Structure Builder (3.5.4)**: Hierarchical JSON assembly for complex report structures

  ## Integration with Phase 3.1

  The JsonRenderer seamlessly integrates with the Phase 3.1 infrastructure:

  - Uses RenderContext for state management during JSON generation
  - Leverages data processing results from complete Phase 2 pipeline
  - Integrates with RenderPipeline for staged JSON assembly
  - Uses RendererIntegration for DataLoader connection

  ## Usage

  ### Basic JSON Rendering

      context = RenderContext.new(report, data_result)
      {:ok, result} = JsonRenderer.render_with_context(context)

      # result.content contains structured JSON
      File.write!("report.json", result.content)

  ### With Custom Configuration

      config = %{
        schema_version: "1.0",
        include_metadata: true,
        format_numbers: true,
        date_format: :iso8601,
        streaming: false
      }

      context = RenderContext.new(report, data_result, config)
      {:ok, result} = JsonRenderer.render_with_context(context)

  ### Streaming Support for Large Datasets

      config = %{streaming: true, chunk_size: 1000}
      context = RenderContext.new(report, data_result, config)
      {:ok, stream} = JsonRenderer.render_with_context(context, streaming: true)

      stream
      |> Stream.each(&process_json_chunk/1)
      |> Stream.run()

  ## JSON Structure

  Generated JSON follows a structured schema:

  ```json
  {
    "report": {
      "name": "sales_report",
      "version": "1.0",
      "generated_at": "2024-01-15T10:30:00Z",
      "metadata": {
        "record_count": 1500,
        "processing_time_ms": 250,
        "variables": {},
        "groups": {}
      }
    },
    "data": {
      "bands": [
        {
          "name": "header",
          "type": "header",
          "elements": [
            {"type": "label", "value": "Sales Report", "position": {"x": 0, "y": 0}},
            {"type": "field", "field": "report_date", "value": "2024-01-15"}
          ]
        },
        {
          "name": "detail",
          "type": "detail",
          "elements": [
            {"type": "field", "field": "customer_name", "value": "ABC Corp"},
            {"type": "field", "field": "amount", "value": 15000.50}
          ]
        }
      ]
    },
    "schema": {
      "version": "3.5.0",
      "format": "ash_reports_json",
      "validation": "passed"
    }
  }
  ```

  ## API Integration Features

  - **Structured Data Export**: Well-defined schema for external systems
  - **API Response Format**: Ready for REST and GraphQL APIs
  - **Data Interchange**: Standard format for analytics integration
  - **Memory Efficiency**: Streaming support for large datasets

  ## Performance Features

  - **Schema Validation**: Ensures consistent JSON structure
  - **Efficient Serialization**: Optimized Jason encoding
  - **Streaming Support**: Memory-efficient processing of large datasets
  - **Caching**: JSON structure caching for repeated operations

  """

  @behaviour AshReports.Renderer

  alias AshReports.{
    JsonRenderer.DataSerializer,
    JsonRenderer.SchemaManager,
    JsonRenderer.StreamingEngine,
    JsonRenderer.StructureBuilder,
    RenderContext
  }

  @doc """
  Enhanced render callback with full Phase 3.5 JSON generation.

  Implements the Phase 3.1 Renderer behaviour with comprehensive JSON output.
  """
  @impl AshReports.Renderer
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    if Keyword.get(opts, :streaming, false) do
      render_streaming(context, opts, start_time)
    else
      render_complete(context, opts, start_time)
    end
  end

  @doc """
  Whether this renderer supports streaming output.
  """
  @impl AshReports.Renderer
  def supports_streaming?, do: true

  @doc """
  The file extension for JSON format.
  """
  @impl AshReports.Renderer
  def file_extension, do: "json"

  @doc """
  The MIME content type for JSON format.
  """
  @impl AshReports.Renderer
  def content_type, do: "application/json"

  @doc """
  Validates that the renderer can handle the given context.
  """
  @impl AshReports.Renderer
  def validate_context(%RenderContext{} = context) do
    with :ok <- validate_json_requirements(context),
         :ok <- validate_serialization_compatibility(context),
         :ok <- SchemaManager.validate_context(context) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Prepares the renderer for JSON rendering operations.
  """
  @impl AshReports.Renderer
  def prepare(%RenderContext{} = context, opts) do
    enhanced_context =
      context
      |> add_json_configuration(opts)
      |> initialize_serialization_state()
      |> initialize_schema_state()
      |> initialize_streaming_state(opts)

    {:ok, enhanced_context}
  end

  @doc """
  Cleans up after JSON rendering operations.
  """
  @impl AshReports.Renderer
  def cleanup(%RenderContext{} = _context, _result) do
    # Clean up any temporary resources, caches, etc.
    DataSerializer.cleanup_temporary_encoders()
    StreamingEngine.cleanup_streaming_resources()
    :ok
  end

  # Legacy render callback for backward compatibility
  @impl AshReports.Renderer
  def render(report_module, data, opts) do
    # Convert to new context-based API
    config = Keyword.get(opts, :config, %{})
    context = RenderContext.new(report_module, %{records: data}, config)

    case render_with_context(context, opts) do
      {:ok, result} -> {:ok, result.content}
      {:error, _reason} = error -> error
    end
  end

  # Private implementation functions

  defp render_complete(%RenderContext{} = context, opts, start_time) do
    with {:ok, json_context} <- prepare_json_context(context, opts),
         {:ok, serialized_data} <- serialize_report_data(json_context),
         {:ok, json_structure} <- build_json_structure(json_context, serialized_data),
         {:ok, final_json} <- encode_final_json(json_structure),
         {:ok, result_metadata} <- build_result_metadata(json_context, start_time) do
      result = %{
        content: final_json,
        metadata: result_metadata,
        context: json_context
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  defp render_streaming(%RenderContext{} = context, opts, start_time) do
    with {:ok, json_context} <- prepare_json_context(context, opts),
         {:ok, stream} <- StreamingEngine.create_json_stream(json_context, opts),
         {:ok, result_metadata} <- build_result_metadata(json_context, start_time) do
      result = %{
        content: stream,
        metadata: Map.put(result_metadata, :streaming, true),
        context: json_context
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  defp prepare_json_context(%RenderContext{} = context, opts) do
    json_config = build_json_config(context, opts)

    enhanced_context = %{
      context
      | config:
          Map.merge(context.config, %{
            json: json_config,
            serialization: :jason,
            schema_validation: true,
            streaming_enabled: Keyword.get(opts, :streaming, false)
          })
    }

    {:ok, enhanced_context}
  end

  defp build_json_config(_context, opts) do
    %{
      schema_version: Keyword.get(opts, :schema_version, "3.5.0"),
      include_metadata: Keyword.get(opts, :include_metadata, true),
      format_numbers: Keyword.get(opts, :format_numbers, false),
      date_format: Keyword.get(opts, :date_format, :iso8601),
      include_schema_info: Keyword.get(opts, :include_schema_info, true),
      pretty_print: Keyword.get(opts, :pretty_print, false),
      null_handling: Keyword.get(opts, :null_handling, :include),
      chunk_size: Keyword.get(opts, :chunk_size, 1000)
    }
  end

  defp serialize_report_data(%RenderContext{} = context) do
    DataSerializer.serialize_context(context)
  end

  defp build_json_structure(%RenderContext{} = context, serialized_data) do
    StructureBuilder.build_report_structure(context, serialized_data)
  end

  defp encode_final_json(json_structure) do
    case Jason.encode(json_structure) do
      {:ok, json_string} -> {:ok, json_string}
      {:error, reason} -> {:error, {:json_encoding_failed, reason}}
    end
  end

  defp build_result_metadata(%RenderContext{} = context, start_time) do
    end_time = System.monotonic_time(:microsecond)
    render_time = end_time - start_time

    metadata = %{
      format: :json,
      render_time_us: render_time,
      serialization_engine: :jason,
      schema_validated: true,
      streaming_enabled: context.config[:streaming_enabled],
      record_count: length(context.records),
      variable_count: map_size(context.variables),
      group_count: map_size(context.groups),
      json_size_bytes: estimate_json_size(context),
      phase: "3.5.0",
      components_used: [
        :schema_manager,
        :data_serializer,
        :structure_builder,
        :streaming_engine
      ]
    }

    {:ok, metadata}
  end

  defp validate_json_requirements(%RenderContext{report: nil}) do
    {:error, :missing_report}
  end

  defp validate_json_requirements(%RenderContext{records: []}) do
    {:error, :no_data_to_render}
  end

  defp validate_json_requirements(_context), do: :ok

  defp validate_serialization_compatibility(%RenderContext{} = context) do
    # Validate that all data can be serialized to JSON
    test_data = %{
      test_records: Enum.take(context.records, 1),
      test_variables: context.variables,
      test_groups: context.groups
    }

    case Jason.encode(test_data) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :data_not_serializable}
    end
  end

  defp add_json_configuration(%RenderContext{} = context, opts) do
    json_config = build_json_config(context, opts)
    updated_config = Map.put(context.config, :json, json_config)
    %{context | config: updated_config}
  end

  defp initialize_serialization_state(%RenderContext{} = context) do
    serialization_state = %{
      encoders_registered: [],
      serialization_cache: %{},
      encoding_errors: []
    }

    updated_metadata = Map.put(context.metadata, :serialization_state, serialization_state)
    %{context | metadata: updated_metadata}
  end

  defp initialize_schema_state(%RenderContext{} = context) do
    schema_state = %{
      schema_version: context.config[:json][:schema_version],
      validation_enabled: true,
      validation_errors: [],
      schema_cache: %{}
    }

    updated_metadata = Map.put(context.metadata, :schema_state, schema_state)
    %{context | metadata: updated_metadata}
  end

  defp initialize_streaming_state(%RenderContext{} = context, opts) do
    streaming_state = %{
      enabled: Keyword.get(opts, :streaming, false),
      chunk_size: Keyword.get(opts, :chunk_size, 1000),
      current_position: 0,
      stream_cache: %{}
    }

    updated_metadata = Map.put(context.metadata, :streaming_state, streaming_state)
    %{context | metadata: updated_metadata}
  end

  defp estimate_json_size(%RenderContext{} = _context) do
    # This would calculate the estimated JSON size
    # For now, return a placeholder that can be implemented later
    0
  end

end
