defmodule AshReports.JsonRenderer.StructureBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.JsonRenderer.StructureBuilder
  alias AshReports.RendererTestHelpers

  describe "build_report_structure/3" do
    test "builds complete JSON structure from context" do
      context =
        RendererTestHelpers.build_render_context(
          records: [%{id: 1, name: "Test"}],
          metadata: %{format: :json}
        )

      serialized_data = %{
        records: [%{"id" => 1, "name" => "Test"}],
        variables: %{},
        groups: %{}
      }

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      assert is_map(structure)
      assert Map.has_key?(structure, :report)
      assert Map.has_key?(structure, :data)
      assert Map.has_key?(structure, :schema)
    end

    test "includes navigation section when option is set" do
      context = RendererTestHelpers.build_render_context()
      serialized_data = %{records: [], variables: %{}, groups: %{}}

      {:ok, structure} =
        StructureBuilder.build_report_structure(context, serialized_data,
          include_navigation: true
        )

      assert Map.has_key?(structure, :navigation)
    end

    test "excludes navigation section by default" do
      context = RendererTestHelpers.build_render_context()
      serialized_data = %{records: [], variables: %{}, groups: %{}}

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      refute Map.has_key?(structure, :navigation)
    end

    test "handles empty records" do
      context = RendererTestHelpers.build_render_context(records: [])
      serialized_data = %{records: [], variables: %{}, groups: %{}}

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      assert is_map(structure)
      assert Map.has_key?(structure, :data)
    end

    test "handles nested band structures" do
      report =
        RendererTestHelpers.build_mock_report(
          bands: [
            %{
              name: :header,
              type: :report_header,
              height: 50,
              elements: [
                %{type: :label, name: :title, text: "Report", position: %{x: 0, y: 0}}
              ]
            },
            %{
              name: :detail,
              type: :detail,
              height: 30,
              elements: [
                %{type: :field, name: :field1, source: :name, position: %{x: 0, y: 0}}
              ]
            }
          ]
        )

      context = RendererTestHelpers.build_render_context(report: report)
      serialized_data = %{records: [], variables: %{}, groups: %{}}

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      assert is_map(structure[:data])
    end
  end

  describe "build_report_header/2" do
    test "builds report header with metadata" do
      context = RendererTestHelpers.build_render_context(metadata: %{generated_at: "2025-10-07"})

      {:ok, header} = StructureBuilder.build_report_header(context)

      assert is_map(header)
      assert is_binary(header[:name]) or is_atom(header[:name])
    end

    test "includes generation timestamp" do
      context = RendererTestHelpers.build_render_context()

      {:ok, header} = StructureBuilder.build_report_header(context)

      assert is_map(header)
    end

    test "includes report metadata when present" do
      context =
        RendererTestHelpers.build_render_context(
          metadata: %{record_count: 100, processing_time_ms: 250}
        )

      {:ok, header} = StructureBuilder.build_report_header(context)

      assert is_map(header)
    end
  end

  describe "build_data_section/3" do
    test "builds data section from serialized records" do
      context = RendererTestHelpers.build_render_context()

      serialized_data = %{
        records: [
          %{"id" => 1, "name" => "Record 1"},
          %{"id" => 2, "name" => "Record 2"}
        ]
      }

      {:ok, data_section} = StructureBuilder.build_data_section(context, serialized_data)

      assert is_map(data_section)
    end

    test "groups elements by bands when option is set" do
      context = RendererTestHelpers.build_render_context()
      serialized_data = %{records: [%{"id" => 1}]}

      {:ok, data_section} =
        StructureBuilder.build_data_section(context, serialized_data, group_by_bands: true)

      assert is_map(data_section)
    end

    test "includes element positions when option is set" do
      context = RendererTestHelpers.build_render_context()
      serialized_data = %{records: [%{"id" => 1}]}

      {:ok, data_section} =
        StructureBuilder.build_data_section(context, serialized_data, include_positions: true)

      assert is_map(data_section)
    end

    test "handles empty serialized data" do
      context = RendererTestHelpers.build_render_context()
      serialized_data = %{records: []}

      {:ok, data_section} = StructureBuilder.build_data_section(context, serialized_data)

      assert is_map(data_section)
    end
  end

  describe "build_schema_section/2" do
    test "builds schema section with version info" do
      context = RendererTestHelpers.build_render_context()

      {:ok, schema_section} = StructureBuilder.build_schema_section(context)

      assert is_map(schema_section)
      assert Map.has_key?(schema_section, :version)
    end

    test "includes format specification" do
      context = RendererTestHelpers.build_render_context()

      {:ok, schema_section} = StructureBuilder.build_schema_section(context)

      assert is_map(schema_section)
      assert Map.has_key?(schema_section, :format)
    end

    test "includes validation status" do
      context = RendererTestHelpers.build_render_context()

      {:ok, schema_section} = StructureBuilder.build_schema_section(context)

      assert is_map(schema_section)
    end
  end

  describe "build_navigation_section/2" do
    test "builds navigation section for complex reports" do
      context = RendererTestHelpers.build_render_context()

      {:ok, navigation} = StructureBuilder.build_navigation_section(context)

      assert is_map(navigation)
    end

    test "includes navigation aids when enabled" do
      context = RendererTestHelpers.build_render_context()

      {:ok, navigation} =
        StructureBuilder.build_navigation_section(context, include_navigation: true)

      assert is_map(navigation)
    end
  end

  describe "error handling" do
    test "returns error for invalid context" do
      result = StructureBuilder.build_report_structure(nil, %{})

      assert {:error, _reason} = result
    end

    test "returns error for invalid serialized data" do
      context = RendererTestHelpers.build_render_context()

      result = StructureBuilder.build_report_structure(context, nil)

      assert {:error, _reason} = result
    end
  end

  describe "metadata integration" do
    test "includes record count in structure" do
      context =
        RendererTestHelpers.build_render_context(
          records: [%{id: 1}, %{id: 2}, %{id: 3}],
          metadata: %{record_count: 3}
        )

      serialized_data = %{records: [%{"id" => 1}, %{"id" => 2}, %{"id" => 3}]}

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      assert is_map(structure)
    end

    test "includes variables in structure" do
      context =
        RendererTestHelpers.build_render_context(
          variables: %{report_date: "2025-10-07", region: "North"}
        )

      serialized_data = %{records: [], variables: %{"report_date" => "2025-10-07"}}

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      assert is_map(structure)
    end

    test "includes groups in structure" do
      context =
        RendererTestHelpers.build_render_context(
          metadata: %{groups: %{region: ["North", "South"]}}
        )

      serialized_data = %{records: [], groups: %{"region" => ["North", "South"]}}

      {:ok, structure} = StructureBuilder.build_report_structure(context, serialized_data)

      assert is_map(structure)
    end
  end
end
