defmodule AshReports.HeexRendererTest do
  @moduledoc """
  Comprehensive test suite for the HEEX Renderer.

  Tests the core HEEX rendering functionality, Phoenix.Component integration,
  and LiveView compatibility following modern Phoenix testing patterns.
  """

  use ExUnit.Case, async: true

  alias AshReports.{
    Band,
    Element,
    HeexRenderer,
    RenderContext,
    Report
  }

  alias AshReports.Element.{Field, Label}

  describe "render_with_context/2" do
    test "renders basic report with HEEX components" do
      context = build_test_context()

      assert {:ok, result} = HeexRenderer.render_with_context(context)
      assert is_binary(result.content)
      assert String.contains?(result.content, "<.report_container")
      assert String.contains?(result.content, "ash-report")
    end

    test "includes all required HEEX components in output" do
      context = build_test_context()

      assert {:ok, result} = HeexRenderer.render_with_context(context)
      content = result.content

      # Check for main structural components
      assert String.contains?(content, "<.report_container")
      assert String.contains?(content, "<.report_content")
      assert String.contains?(content, "<.band_group")
      assert String.contains?(content, "<.band")
      assert String.contains?(content, "<.element")
    end

    test "generates proper HEEX template with assigns" do
      context = build_test_context()

      assert {:ok, result} = HeexRenderer.render_with_context(context)
      content = result.content

      # Check for proper assign usage
      assert String.contains?(content, "@report")
      assert String.contains?(content, "@records")
      assert String.contains?(content, "@variables")
      assert String.contains?(content, "@metadata")
    end

    test "includes component attributes and data attributes" do
      context = build_test_context()

      assert {:ok, result} = HeexRenderer.render_with_context(context)
      content = result.content

      # Check for proper attributes
      assert String.contains?(content, ~s(class="ash-report"))
      assert String.contains?(content, ~s(data-report=))
      assert String.contains?(content, ~s(data-band=))
      assert String.contains?(content, ~s(data-element=))
    end

    test "handles empty data gracefully" do
      context = build_empty_data_context()

      assert {:ok, result} = HeexRenderer.render_with_context(context)
      assert is_binary(result.content)
      assert result.metadata.element_count == 0
    end

    test "applies static optimization when enabled" do
      context = build_test_context()
      opts = [static_optimization: true]

      assert {:ok, result} = HeexRenderer.render_with_context(context, opts)

      # Optimized templates should have less whitespace
      refute String.contains?(result.content, "\n\s*\n")
    end

    test "includes proper metadata in result" do
      context = build_test_context()

      assert {:ok, result} = HeexRenderer.render_with_context(context)
      metadata = result.metadata

      assert metadata.format == :heex
      assert metadata.template_engine == :heex
      assert metadata.component_library == true
      assert metadata.liveview_compatible == true
      assert metadata.phase == "3.3.0"
      assert is_list(metadata.components_used)
      assert is_map(metadata.features)
    end

    test "supports interactive mode configuration" do
      context = build_test_context()
      opts = [interactive: true, enable_filters: true]

      assert {:ok, result} = HeexRenderer.render_with_context(context, opts)

      assert result.metadata.interactive == true
      assert result.metadata.features.filtering == true
    end

    test "supports LiveView integration configuration" do
      context = build_test_context()
      opts = [liveview_enabled: true, real_time_updates: true]

      assert {:ok, result} = HeexRenderer.render_with_context(context, opts)

      assert result.metadata.features.real_time_updates == true
      assert result.context.config.heex.liveview_enabled == true
    end
  end

  describe "render_for_liveview/2" do
    test "returns assigns and template for LiveView embedding" do
      context = build_test_context()

      assert {:ok, assigns, template} = HeexRenderer.render_for_liveview(context)

      assert is_map(assigns)
      assert is_binary(template)
      assert Map.has_key?(assigns, :report)
      assert Map.has_key?(assigns, :records)
      assert String.contains?(template, "<.report_container")
    end

    test "assigns contain all required data for components" do
      context = build_test_context()

      assert {:ok, assigns, _template} = HeexRenderer.render_for_liveview(context)

      assert assigns.report == context.report
      assert assigns.records == context.records
      assert assigns.variables == context.variables
      assert assigns.metadata == context.metadata
      assert Map.has_key?(assigns, :heex_config)
    end
  end

  describe "render_component/3" do
    test "renders individual report header component" do
      context = build_test_context()

      assert {:ok, component_heex} = HeexRenderer.render_component(context, :report_header)

      assert is_binary(component_heex)
      assert String.contains?(component_heex, "ash-report-header")
    end

    test "renders individual band component" do
      context = build_test_context()

      assert {:ok, component_heex} = HeexRenderer.render_component(context, :band)

      assert is_binary(component_heex)
      assert String.contains?(component_heex, "ash-band")
    end

    test "returns error for unknown component type" do
      context = build_test_context()

      assert {:error, {:unknown_component, :invalid_component}} =
               HeexRenderer.render_component(context, :invalid_component)
    end
  end

  describe "supports_streaming?" do
    test "returns true for streaming support" do
      assert HeexRenderer.supports_streaming?() == true
    end
  end

  describe "file_extension/0" do
    test "returns heex extension" do
      assert HeexRenderer.file_extension() == "heex"
    end
  end

  describe "content_type/0" do
    test "returns heex content type" do
      assert HeexRenderer.content_type() == "text/heex"
    end
  end

  describe "validate_context/1" do
    test "validates valid context successfully" do
      context = build_test_context()

      assert :ok = HeexRenderer.validate_context(context)
    end

    test "rejects context without report" do
      context = %RenderContext{report: nil, records: [%{}]}

      assert {:error, :missing_report} = HeexRenderer.validate_context(context)
    end

    test "rejects context without data" do
      context = %RenderContext{report: build_test_report(), records: []}

      assert {:error, :no_data_to_render} = HeexRenderer.validate_context(context)
    end

    test "validates Phoenix.Component availability" do
      context = build_test_context()

      # Phoenix.Component should be available in test environment
      assert :ok = HeexRenderer.validate_context(context)
    end
  end

  describe "prepare/2" do
    test "enhances context with HEEX configuration" do
      context = build_test_context()
      opts = [component_style: :modern, interactive: true]

      assert {:ok, enhanced_context} = HeexRenderer.prepare(context, opts)

      assert enhanced_context.config.heex.component_style == :modern
      assert enhanced_context.config.heex.interactive == true
      assert enhanced_context.config.template_engine == :heex
      assert enhanced_context.config.component_library == true
    end

    test "initializes component state in metadata" do
      context = build_test_context()

      assert {:ok, enhanced_context} = HeexRenderer.prepare(context, [])

      component_state = enhanced_context.metadata.component_state
      assert is_map(component_state)
      assert Map.has_key?(component_state, :components_loaded)
      assert Map.has_key?(component_state, :component_cache)
    end

    test "initializes LiveView state when enabled" do
      context = build_test_context()
      opts = [liveview_enabled: true]

      assert {:ok, enhanced_context} = HeexRenderer.prepare(context, opts)

      liveview_state = enhanced_context.metadata.liveview_state
      assert is_map(liveview_state)
      assert Map.has_key?(liveview_state, :subscriptions)
      assert Map.has_key?(liveview_state, :event_handlers)
    end
  end

  describe "cleanup/2" do
    test "cleans up resources successfully" do
      context = build_test_context()
      result = %{content: "", metadata: %{}}

      assert :ok = HeexRenderer.cleanup(context, result)
    end
  end

  describe "legacy render/3 compatibility" do
    test "maintains backward compatibility with legacy API" do
      report = build_test_report()
      data = [%{name: "Test", value: 100}]

      assert {:ok, content} = HeexRenderer.render(report, data, [])
      assert is_binary(content)
      assert String.contains?(content, "<.report_container")
    end
  end

  describe "error handling" do
    test "handles malformed context gracefully" do
      malformed_context = %{invalid: :context}

      assert_raise FunctionClauseError, fn ->
        HeexRenderer.render_with_context(malformed_context)
      end
    end

    test "handles missing report data" do
      context = %RenderContext{
        report: nil,
        records: [],
        config: %{},
        variables: %{},
        metadata: %{}
      }

      assert {:error, :missing_report} = HeexRenderer.validate_context(context)
    end
  end

  describe "performance and optimization" do
    test "template generation completes within reasonable time" do
      context = build_large_data_context()

      {time_microseconds, {:ok, _result}} =
        :timer.tc(fn -> HeexRenderer.render_with_context(context) end)

      # Should complete within 100ms for reasonable dataset
      assert time_microseconds < 100_000
    end

    test "memory usage remains reasonable for large datasets" do
      context = build_large_data_context()

      before_memory = :erlang.memory(:total)
      {:ok, _result} = HeexRenderer.render_with_context(context)
      after_memory = :erlang.memory(:total)

      # Memory increase should be reasonable (less than 50MB for test data)
      memory_increase = after_memory - before_memory
      assert memory_increase < 50 * 1024 * 1024
    end
  end

  # Test helper functions

  defp build_test_context do
    report = build_test_report()
    data_result = build_test_data_result()
    config = build_test_config()

    RenderContext.new(report, data_result, config)
  end

  defp build_empty_data_context do
    report = build_test_report()
    data_result = %{records: [], variables: %{}, metadata: %{}}
    config = build_test_config()

    RenderContext.new(report, data_result, config)
  end

  defp build_large_data_context do
    report = build_test_report()

    # Generate 1000 test records
    records =
      Enum.map(1..1000, fn i ->
        %{
          id: i,
          name: "Record #{i}",
          value: :rand.uniform(1000),
          status: Enum.random(["active", "inactive", "pending"]),
          created_at: DateTime.utc_now()
        }
      end)

    data_result = %{records: records, variables: %{}, metadata: %{}}
    config = build_test_config()

    RenderContext.new(report, data_result, config)
  end

  defp build_test_report do
    %Report{
      name: :test_report,
      title: "Test Report",
      bands: [
        %Band{
          name: :header,
          type: :header,
          height: 50,
          elements: [
            %Label{name: :title, text: "Test Report"}
          ]
        },
        %Band{
          name: :detail,
          type: :detail,
          height: 30,
          elements: [
            %Field{name: :name_field, field: :name},
            %Field{name: :value_field, field: :value}
          ]
        }
      ]
    }
  end

  defp build_test_data_result do
    %{
      records: [
        %{name: "Record 1", value: 100},
        %{name: "Record 2", value: 200},
        %{name: "Record 3", value: 300}
      ],
      variables: %{
        total_count: 3,
        total_value: 600
      },
      metadata: %{
        generated_at: DateTime.utc_now(),
        source: "test"
      }
    }
  end

  defp build_test_config do
    %{
      format: :heex,
      heex: %{
        component_style: :modern,
        liveview_enabled: true,
        interactive: false,
        static_optimization: true,
        accessibility: true
      }
    }
  end
end
