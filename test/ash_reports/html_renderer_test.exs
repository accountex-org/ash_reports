defmodule AshReports.HtmlRendererBasicTest do
  use ExUnit.Case
  doctest AshReports.HtmlRenderer

  alias AshReports.{HtmlRenderer, RenderContext}

  describe "HtmlRenderer behaviour implementation" do
    test "implements all required behaviour callbacks" do
      assert function_exported?(HtmlRenderer, :render_with_context, 2)
      assert function_exported?(HtmlRenderer, :supports_streaming?, 0)
      assert function_exported?(HtmlRenderer, :file_extension, 0)
      assert function_exported?(HtmlRenderer, :content_type, 0)
    end

    test "provides correct metadata" do
      assert HtmlRenderer.supports_streaming?() == true
      assert HtmlRenderer.file_extension() == "html"
      assert HtmlRenderer.content_type() == "text/html"
    end
  end

  describe "HTML generation" do
    setup do
      # Create a simple report structure for testing using maps
      element = %{
        type: :label,
        name: :test_label,
        text: "Test Label",
        position: %{x: 10, y: 20, width: 100, height: 25}
      }

      band = %{
        name: :detail,
        type: :detail,
        height: 50,
        elements: [element]
      }

      report = %{
        name: :test_report,
        title: "Test Report",
        bands: [band]
      }

      data_result = %{
        records: [%{name: "John", age: 30}, %{name: "Jane", age: 25}],
        variables: %{total_count: 2},
        groups: %{},
        metadata: %{query_time: 100}
      }

      context = RenderContext.new(report, data_result, %{})

      %{context: context, report: report, element: element, band: band}
    end

    test "can validate context successfully", %{context: context} do
      assert HtmlRenderer.validate_context(context) == :ok
    end

    test "can prepare context for rendering", %{context: context} do
      {:ok, prepared_context} = HtmlRenderer.prepare(context, [])

      assert Map.has_key?(prepared_context.config, :html)
      assert Map.has_key?(prepared_context.metadata, :template_state)
      assert Map.has_key?(prepared_context.metadata, :css_state)
      assert Map.has_key?(prepared_context.metadata, :responsive_state)
    end

    test "generates HTML content with basic structure", %{context: context} do
      # Mock the layout state to avoid dependency issues
      layout_state = %{
        bands: %{
          detail: %{
            band: %{name: :detail, type: :detail},
            position: %{x: 0, y: 0},
            dimensions: %{width: 800, height: 50},
            elements: [
              %{
                element: %{type: :label, name: :test_label},
                position: %{x: 10, y: 20},
                dimensions: %{width: 100, height: 25}
              }
            ],
            page_number: 1,
            overflow?: false
          }
        }
      }

      context_with_layout = %{context | layout_state: layout_state}

      {:ok, result} = HtmlRenderer.render_with_context(context_with_layout)

      assert is_map(result)
      assert Map.has_key?(result, :content)
      assert Map.has_key?(result, :metadata)
      assert Map.has_key?(result, :context)

      # Check that content contains expected HTML elements
      content = result.content
      assert is_binary(content)
      assert String.contains?(content, "<!DOCTYPE html>")
      assert String.contains?(content, "<html")
      assert String.contains?(content, "</html>")
      assert String.contains?(content, "ash-report")
      assert String.contains?(content, "Test Report")
    end

    test "handles legacy render callback", %{report: report} do
      data = [%{name: "John", age: 30}]
      {:ok, html_content} = HtmlRenderer.render(report, data, [])

      assert is_binary(html_content)
      assert String.contains?(html_content, "<!DOCTYPE html>")
    end

    test "cleanup runs without error", %{context: context} do
      result = %{content: "<html></html>", metadata: %{}, context: context}
      assert HtmlRenderer.cleanup(context, result) == :ok
    end
  end

  describe "error handling" do
    test "validates context with missing report" do
      invalid_context = %RenderContext{
        report: nil,
        data_result: %{},
        config: %{},
        records: [],
        variables: %{},
        groups: %{},
        metadata: %{},
        layout_state: %{},
        current_position: %{x: 0, y: 0},
        page_dimensions: %{width: 8.5, height: 11},
        rendered_elements: [],
        pending_elements: [],
        errors: [],
        warnings: [],
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      assert HtmlRenderer.validate_context(invalid_context) == {:error, :missing_report}
    end
  end
end
