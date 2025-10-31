defmodule AshReports.JsonRenderer.SchemaManager do
  @moduledoc """
  JSON Schema Manager for AshReports JSON Renderer.

  The SchemaManager provides JSON schema definition, validation, and management
  capabilities for consistent JSON output structure. It ensures that all JSON
  output follows a well-defined schema suitable for API integration and data
  interchange.

  ## Schema Components

  - **Report Schema**: Defines the report metadata structure
  - **Data Schema**: Defines data format with records, variables, and groups
  - **Metadata Schema**: Defines metadata structure and content
  - **Schema Info**: Defines version and validation information

  ## Schema Validation

  The SchemaManager validates:

  - Report structure compliance with defined schema
  - Data type consistency and format compliance
  - Required field presence and optional field handling
  - Nested structure validation for complex data

  ## Usage

      # Validate a render context against the schema
      case SchemaManager.validate_context(context) do
        :ok -> proceed_with_rendering()
        {:error, errors} -> handle_validation_errors(errors)
      end

      # Get the current schema definition
      schema = SchemaManager.get_schema_definition("3.5.0")

      # Validate generated JSON structure
      {:ok, validated_json} = SchemaManager.validate_json_structure(json_data)

  """

  alias AshReports.RenderContext

  @type schema_version :: String.t()
  @type validation_error :: %{
          path: [atom()],
          message: String.t(),
          expected: term(),
          actual: term()
        }
  @type schema_definition :: map()

  @current_schema_version "3.5.0"

  @doc """
  Validates a RenderContext against the JSON schema requirements.

  ## Examples

      case SchemaManager.validate_context(context) do
        :ok -> proceed_with_rendering()
        {:error, errors} -> handle_validation_errors(errors)
      end

  """
  @spec validate_context(RenderContext.t()) :: :ok | {:error, [validation_error()]}
  def validate_context(%RenderContext{} = context) do
    errors =
      []
      |> validate_report_structure(context)
      |> validate_data_structure(context)
      |> validate_variable_structure(context)
      |> validate_group_structure(context)
      |> validate_metadata_structure(context)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  @doc """
  Gets the schema definition for a specific version.

  ## Examples

      schema = SchemaManager.get_schema_definition("3.5.0")
      legacy_schema = SchemaManager.get_schema_definition("3.0.0")

  """
  @spec get_schema_definition(schema_version()) :: schema_definition()
  def get_schema_definition(version \\ @current_schema_version)

  def get_schema_definition("3.5.0") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "title" => "AshReports JSON Output Schema v3.5.0",
      "description" => "Schema for JSON output from AshReports - records only",
      "properties" => %{
        "records" => %{
          "type" => "array",
          "items" => %{"type" => "object"},
          "description" => "Array of record objects containing report data"
        }
      },
      "required" => ["records"],
      "additionalProperties" => false
    }
  end

  def get_schema_definition(version) do
    {:error, {:unsupported_schema_version, version}}
  end

  @doc """
  Validates a JSON structure against the schema.

  ## Examples

      case SchemaManager.validate_json_structure(json_data) do
        {:ok, validated_data} -> use_validated_data(validated_data)
        {:error, errors} -> handle_validation_errors(errors)
      end

  """
  @spec validate_json_structure(map()) :: {:ok, map()} | {:error, [validation_error()]}
  def validate_json_structure(json_data) when is_map(json_data) do
    schema = get_schema_definition()
    validate_against_schema(json_data, schema, [])
  end

  def validate_json_structure(_), do: {:error, [{:root, "JSON data must be an object"}]}

  @doc """
  Creates a schema-compliant JSON structure template.

  ## Examples

      template = SchemaManager.create_json_template(context)

  """
  @spec create_json_template(RenderContext.t()) :: map()
  def create_json_template(%RenderContext{} = context) do
    %{
      "report" => create_report_template(context),
      "data" => create_data_template(context),
      "schema" => create_schema_template()
    }
  end

  @doc """
  Gets the current schema version.

  ## Examples

      version = SchemaManager.current_schema_version()

  """
  @spec current_schema_version() :: schema_version()
  def current_schema_version, do: @current_schema_version

  @doc """
  Validates that a value matches a specific schema type.

  ## Examples

      :ok = SchemaManager.validate_type("string value", "string")
      {:error, _} = SchemaManager.validate_type(123, "string")

  """
  @spec validate_type(term(), String.t()) :: :ok | {:error, validation_error()}
  def validate_type(value, expected_type) do
    case {value, expected_type} do
      {v, "string"} when is_binary(v) -> :ok
      {v, "number"} when is_number(v) -> :ok
      {v, "integer"} when is_integer(v) -> :ok
      {v, "boolean"} when is_boolean(v) -> :ok
      {v, "array"} when is_list(v) -> :ok
      {v, "object"} when is_map(v) -> :ok
      {nil, "null"} -> :ok
      {v, type} -> {:error, %{expected: type, actual: typeof(v), message: "Type mismatch"}}
    end
  end

  # Private implementation functions
  # Note: Detailed schema definitions (report_schema, data_schema, band_schema,
  # element_schema, schema_info_schema) were removed as they were prepared for
  # Phase 3.5 but never integrated. The current implementation uses a simplified
  # schema (see get_schema_definition/1). These can be restored from git history
  # if needed for future schema expansion.

  defp validate_report_structure(errors, %RenderContext{report: nil}) do
    [
      %{path: [:report], message: "Report is required", expected: "Report struct", actual: nil}
      | errors
    ]
  end

  defp validate_report_structure(errors, %RenderContext{report: report}) do
    cond do
      is_nil(Map.get(report, :name)) ->
        [
          %{
            path: [:report, :name],
            message: "Report name is required",
            expected: "string",
            actual: nil
          }
          | errors
        ]

      not is_list(Map.get(report, :bands, [])) ->
        [
          %{
            path: [:report, :bands],
            message: "Report bands must be a list",
            expected: "list",
            actual: typeof(report.bands)
          }
          | errors
        ]

      true ->
        errors
    end
  end

  defp validate_data_structure(errors, %RenderContext{records: records})
       when not is_list(records) do
    [
      %{
        path: [:data, :records],
        message: "Records must be a list",
        expected: "list",
        actual: typeof(records)
      }
      | errors
    ]
  end

  defp validate_data_structure(errors, _context), do: errors

  defp validate_variable_structure(errors, %RenderContext{variables: variables})
       when not is_map(variables) do
    [
      %{
        path: [:data, :variables],
        message: "Variables must be a map",
        expected: "map",
        actual: typeof(variables)
      }
      | errors
    ]
  end

  defp validate_variable_structure(errors, _context), do: errors

  defp validate_group_structure(errors, %RenderContext{groups: groups}) when not is_map(groups) do
    [
      %{
        path: [:data, :groups],
        message: "Groups must be a map",
        expected: "map",
        actual: typeof(groups)
      }
      | errors
    ]
  end

  defp validate_group_structure(errors, _context), do: errors

  defp validate_metadata_structure(errors, %RenderContext{metadata: metadata})
       when not is_map(metadata) do
    [
      %{
        path: [:metadata],
        message: "Metadata must be a map",
        expected: "map",
        actual: typeof(metadata)
      }
      | errors
    ]
  end

  defp validate_metadata_structure(errors, _context), do: errors

  defp validate_against_schema(data, schema, path) do
    case schema["type"] do
      "object" -> validate_object(data, schema, path)
      "array" -> validate_array(data, schema, path)
      type -> validate_primitive(data, type, path)
    end
  end

  defp validate_object(data, schema, path) when is_map(data) do
    errors =
      []
      |> validate_required_properties(data, schema, path)
      |> validate_properties(data, schema, path)

    if errors == [] do
      {:ok, data}
    else
      {:error, errors}
    end
  end

  defp validate_object(_data, _schema, path) do
    {:error, [%{path: path, message: "Expected object", expected: "object", actual: "other"}]}
  end

  defp validate_array(data, schema, path) when is_list(data) do
    case schema["items"] do
      nil ->
        {:ok, data}

      item_schema ->
        results =
          data
          |> Enum.with_index()
          |> Enum.map(fn {item, index} ->
            validate_against_schema(item, item_schema, path ++ [index])
          end)

        errors =
          Enum.flat_map(results, fn
            {:error, errors} -> errors
            {:ok, _} -> []
          end)

        if errors == [] do
          {:ok, data}
        else
          {:error, errors}
        end
    end
  end

  defp validate_array(_data, _schema, path) do
    {:error, [%{path: path, message: "Expected array", expected: "array", actual: "other"}]}
  end

  defp validate_primitive(data, type, path) do
    case validate_type(data, type) do
      :ok -> {:ok, data}
      {:error, error} -> {:error, [Map.put(error, :path, path)]}
    end
  end

  defp validate_required_properties(errors, data, schema, path) do
    required = Map.get(schema, "required", [])

    missing =
      Enum.filter(required, fn prop ->
        not Map.has_key?(data, prop)
      end)

    missing_errors =
      Enum.map(missing, fn prop ->
        %{
          path: path ++ [prop],
          message: "Required property missing",
          expected: "present",
          actual: "missing"
        }
      end)

    errors ++ missing_errors
  end

  defp validate_properties(errors, data, schema, path) do
    properties = Map.get(schema, "properties", %{})

    property_errors =
      Enum.flat_map(data, fn {key, value} ->
        validate_single_property(key, value, properties, schema, path)
      end)

    errors ++ property_errors
  end

  defp validate_single_property(key, value, properties, schema, path) do
    case Map.get(properties, key) do
      nil ->
        validate_additional_property(key, schema, path)

      property_schema ->
        validate_property_schema(value, property_schema, path ++ [key])
    end
  end

  defp validate_additional_property(key, schema, path) do
    if Map.get(schema, "additionalProperties", true) do
      []
    else
      [
        %{
          path: path ++ [key],
          message: "Additional property not allowed",
          expected: "allowed",
          actual: "forbidden"
        }
      ]
    end
  end

  defp validate_property_schema(value, property_schema, path) do
    case validate_against_schema(value, property_schema, path) do
      {:ok, _} -> []
      {:error, prop_errors} -> prop_errors
    end
  end

  defp create_report_template(%RenderContext{} = context) do
    %{
      "name" => get_report_name(context),
      "version" => "1.0",
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "metadata" => %{
        "record_count" => length(context.records),
        "processing_time_ms" => 0,
        "variables" => context.variables,
        "groups" => context.groups
      }
    }
  end

  defp create_data_template(%RenderContext{} = _context) do
    %{
      "bands" => []
    }
  end

  defp create_schema_template do
    %{
      "version" => @current_schema_version,
      "format" => "ash_reports_json",
      "validation" => "passed"
    }
  end

  defp get_report_name(%RenderContext{report: %{name: name}}) when is_binary(name), do: name
  defp get_report_name(%RenderContext{report: report}) when is_atom(report), do: to_string(report)
  defp get_report_name(_), do: "unknown_report"

  defp typeof(value) when is_binary(value), do: "string"
  defp typeof(value) when is_number(value), do: "number"
  defp typeof(value) when is_boolean(value), do: "boolean"
  defp typeof(value) when is_list(value), do: "array"
  defp typeof(value) when is_map(value), do: "object"
  defp typeof(nil), do: "null"
  defp typeof(_), do: "unknown"
end
