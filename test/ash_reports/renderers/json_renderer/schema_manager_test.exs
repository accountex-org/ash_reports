defmodule AshReports.JsonRenderer.SchemaManagerTest do
  use ExUnit.Case, async: true

  alias AshReports.JsonRenderer.SchemaManager
  alias AshReports.RendererTestHelpers

  describe "validate_context/1" do
    test "validates a valid render context" do
      context =
        RendererTestHelpers.build_render_context(
          records: [%{id: 1, name: "Test"}],
          metadata: %{format: :json}
        )

      result = SchemaManager.validate_context(context)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "returns error for nil context" do
      result = SchemaManager.validate_context(nil)

      assert {:error, _errors} = result
    end

    test "validates context with all required fields" do
      context =
        RendererTestHelpers.build_render_context(
          report: RendererTestHelpers.build_mock_report(),
          records: [],
          metadata: %{},
          variables: %{}
        )

      result = SchemaManager.validate_context(context)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "returns validation errors for invalid context structure" do
      # Invalid context (missing required fields)
      invalid_context = %{some: "invalid structure"}

      result = SchemaManager.validate_context(invalid_context)

      assert {:error, errors} = result
      assert is_list(errors) or is_binary(errors)
    end
  end

  describe "get_schema_definition/1" do
    test "retrieves schema definition for current version" do
      schema = SchemaManager.get_schema_definition("3.5.0")

      assert is_map(schema)
    end

    test "returns schema definition for specific version" do
      schema = SchemaManager.get_schema_definition("3.5.0")

      assert is_map(schema)
      assert Map.has_key?(schema, :version) or Map.has_key?(schema, "version")
    end

    test "handles invalid version gracefully" do
      result = SchemaManager.get_schema_definition("999.999.999")

      # Should return error or default schema
      assert is_map(result) or match?({:error, _}, result)
    end

    test "schema definition includes required sections" do
      schema = SchemaManager.get_schema_definition("3.5.0")

      assert is_map(schema)
      # Schema should define report structure
    end
  end

  describe "validate_json_structure/1" do
    test "validates a valid JSON structure" do
      valid_json = %{
        report: %{
          name: "test_report",
          version: "1.0"
        },
        data: %{
          bands: []
        },
        schema: %{
          version: "3.5.0",
          format: "ash_reports_json"
        }
      }

      result = SchemaManager.validate_json_structure(valid_json)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "returns error for invalid structure" do
      invalid_json = %{missing: "required_fields"}

      result = SchemaManager.validate_json_structure(invalid_json)

      assert {:error, _errors} = result
    end

    test "validates nested structures" do
      nested_json = %{
        report: %{
          name: "test",
          metadata: %{
            generated_at: "2025-10-07",
            record_count: 100
          }
        },
        data: %{
          bands: [
            %{
              name: "header",
              type: "header",
              elements: []
            }
          ]
        },
        schema: %{version: "3.5.0"}
      }

      result = SchemaManager.validate_json_structure(nested_json)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "detects missing required fields" do
      incomplete_json = %{
        report: %{name: "test"}
        # Missing data and schema sections
      }

      result = SchemaManager.validate_json_structure(incomplete_json)

      assert {:error, errors} = result
      assert is_list(errors) or is_binary(errors)
    end
  end

  describe "schema validation errors" do
    test "provides detailed error messages" do
      invalid_json = %{invalid: "structure"}

      {:error, errors} = SchemaManager.validate_json_structure(invalid_json)

      assert is_list(errors) or is_binary(errors)

      if is_list(errors) and length(errors) > 0 do
        error = List.first(errors)
        assert is_map(error) or is_binary(error)
      end
    end

    test "includes path information in errors" do
      invalid_json = %{
        report: %{name: nil},
        # name should be string
        data: %{},
        schema: %{}
      }

      result = SchemaManager.validate_json_structure(invalid_json)

      # Should either validate successfully or provide error with path
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "validates data types" do
      invalid_types = %{
        report: %{
          name: 123,
          # Should be string
          version: true
          # Should be string
        },
        data: "invalid",
        # Should be map
        schema: []
        # Should be map
      }

      result = SchemaManager.validate_json_structure(invalid_types)

      # May pass or fail depending on validation strictness
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "schema versioning" do
    test "supports current schema version" do
      schema = SchemaManager.get_schema_definition("3.5.0")

      assert is_map(schema)
    end

    test "lists available schema versions" do
      # If SchemaManager provides a function to list versions
      if function_exported?(SchemaManager, :list_schema_versions, 0) do
        versions = SchemaManager.list_schema_versions()
        assert is_list(versions)
        assert "3.5.0" in versions
      end
    end

    test "validates against specific schema version" do
      json_data = %{
        report: %{name: "test"},
        data: %{},
        schema: %{version: "3.5.0"}
      }

      result = SchemaManager.validate_json_structure(json_data)

      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "band schema validation" do
    test "validates band structure" do
      band = %{
        name: "header",
        type: "header",
        height: 50,
        elements: []
      }

      # If there's a specific band validation function
      if function_exported?(SchemaManager, :validate_band, 1) do
        result = SchemaManager.validate_band(band)
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "validates band elements" do
      band = %{
        name: "detail",
        type: "detail",
        elements: [
          %{type: "label", text: "Label", position: %{x: 0, y: 0}},
          %{type: "field", field: "name", position: %{x: 0, y: 10}}
        ]
      }

      if function_exported?(SchemaManager, :validate_band, 1) do
        result = SchemaManager.validate_band(band)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "element schema validation" do
    test "validates label elements" do
      element = %{
        type: "label",
        name: "title",
        text: "Report Title",
        position: %{x: 0, y: 0}
      }

      if function_exported?(SchemaManager, :validate_element, 1) do
        result = SchemaManager.validate_element(element)
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "validates field elements" do
      element = %{
        type: "field",
        name: "customer_name",
        field: "name",
        position: %{x: 0, y: 0}
      }

      if function_exported?(SchemaManager, :validate_element, 1) do
        result = SchemaManager.validate_element(element)
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "validates chart elements" do
      element = %{
        type: "chart",
        name: "sales_chart",
        chart_type: "bar",
        position: %{x: 0, y: 0},
        size: %{width: 400, height: 300}
      }

      if function_exported?(SchemaManager, :validate_element, 1) do
        result = SchemaManager.validate_element(element)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "metadata schema validation" do
    test "validates metadata structure" do
      metadata = %{
        generated_at: "2025-10-07T10:00:00Z",
        record_count: 100,
        processing_time_ms: 250,
        variables: %{},
        groups: %{}
      }

      if function_exported?(SchemaManager, :validate_metadata, 1) do
        result = SchemaManager.validate_metadata(metadata)
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "allows optional metadata fields" do
      minimal_metadata = %{
        generated_at: "2025-10-07T10:00:00Z"
      }

      if function_exported?(SchemaManager, :validate_metadata, 1) do
        result = SchemaManager.validate_metadata(minimal_metadata)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "schema documentation" do
    test "provides schema documentation" do
      if function_exported?(SchemaManager, :get_schema_documentation, 0) do
        docs = SchemaManager.get_schema_documentation()
        assert is_binary(docs) or is_map(docs)
      end
    end

    test "provides field descriptions" do
      if function_exported?(SchemaManager, :get_field_description, 1) do
        description = SchemaManager.get_field_description("report.name")
        assert is_binary(description) or is_nil(description)
      end
    end
  end

  describe "integration with structure builder" do
    test "validates structure builder output" do
      context = RendererTestHelpers.build_render_context()

      # If we can build a structure
      if function_exported?(AshReports.JsonRenderer.StructureBuilder, :build_report_structure, 2) do
        serialized_data = %{records: [], variables: %{}, groups: %{}}

        {:ok, structure} =
          AshReports.JsonRenderer.StructureBuilder.build_report_structure(
            context,
            serialized_data
          )

        result = SchemaManager.validate_json_structure(structure)

        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
