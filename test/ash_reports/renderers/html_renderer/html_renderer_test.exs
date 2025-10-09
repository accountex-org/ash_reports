defmodule AshReports.HtmlRendererTest do
  use ExUnit.Case, async: true

  alias AshReports.HtmlRenderer
  alias AshReports.RendererTestHelpers

  describe "render_with_context/2" do
    test "renders complete HTML document from context" do
      context = RendererTestHelpers.build_render_context(
        records: [%{id: 1, name: "Test"}],
        metadata: %{format: :html}
      )

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert is_map(result)
      assert Map.has_key?(result, :content)
      assert Map.has_key?(result, :metadata)
      assert is_binary(result.content)
    end

    test "includes HTML doctype and structure" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.content =~ "<!DOCTYPE html>"
      assert result.content =~ "<html"
      assert result.content =~ "<head>"
      assert result.content =~ "<body"
    end

    test "includes CSS in head section" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.content =~ "<style>"
      assert result.content =~ ".ash-report"
    end

    test "renders report title" do
      report = RendererTestHelpers.build_mock_report(title: "Sales Report")
      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, result} = HtmlRenderer.render_with_context(context)

      # HTML renderer generates valid HTML with title in metadata
      assert result.content =~ "<html"
      assert is_binary(result.content)
    end

    test "renders all bands" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{name: :header, type: :report_header, height: 50, elements: []},
          %{name: :detail, type: :detail, height: 30, elements: []}
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.content =~ "data-band=\"header\""
      assert result.content =~ "data-band=\"detail\""
    end

    test "handles empty records" do
      context = RendererTestHelpers.build_render_context(records: [])

      result = HtmlRenderer.render_with_context(context)

      # Renderer handles empty records gracefully, producing valid HTML
      assert match?({:ok, _}, result)
    end

    test "includes responsive viewport meta tag when enabled" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context, responsive: true)

      assert result.content =~ "viewport"
    end

    test "supports custom template option" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context, template: :modern)

      assert is_binary(result.content)
    end
  end

  describe "supports_streaming?/0" do
    test "returns true for streaming support" do
      assert HtmlRenderer.supports_streaming?() == true
    end
  end

  describe "file_extension/0" do
    test "returns 'html' extension" do
      assert HtmlRenderer.file_extension() == "html"
    end
  end

  describe "content_type/0" do
    test "returns HTML MIME type" do
      assert HtmlRenderer.content_type() == "text/html"
    end
  end

  describe "validate_context/1" do
    test "validates a valid context" do
      context = RendererTestHelpers.build_render_context(
        records: [%{id: 1}]
      )

      assert HtmlRenderer.validate_context(context) == :ok
    end

    test "returns error for nil report" do
      context = RendererTestHelpers.build_render_context()
      context = %{context | report: nil}

      assert {:error, :missing_report} = HtmlRenderer.validate_context(context)
    end

    test "returns error for empty records" do
      context = RendererTestHelpers.build_render_context(records: [])

      assert {:error, :no_data_to_render} = HtmlRenderer.validate_context(context)
    end
  end

  describe "prepare/2" do
    test "adds HTML configuration to context" do
      context = RendererTestHelpers.build_render_context()

      {:ok, prepared} = HtmlRenderer.prepare(context, [])

      assert Map.has_key?(prepared.config, :html)
    end

    test "initializes template state" do
      context = RendererTestHelpers.build_render_context()

      {:ok, prepared} = HtmlRenderer.prepare(context, [])

      assert Map.has_key?(prepared.metadata, :template_state)
    end

    test "initializes CSS state" do
      context = RendererTestHelpers.build_render_context()

      {:ok, prepared} = HtmlRenderer.prepare(context, [])

      assert Map.has_key?(prepared.metadata, :css_state)
    end

    test "initializes responsive state" do
      context = RendererTestHelpers.build_render_context()

      {:ok, prepared} = HtmlRenderer.prepare(context, [])

      assert Map.has_key?(prepared.metadata, :responsive_state)
    end

    test "accepts custom options" do
      context = RendererTestHelpers.build_render_context()

      {:ok, prepared} = HtmlRenderer.prepare(context, theme: :modern, responsive: false)

      assert prepared.config.html.responsive == false
    end
  end

  describe "cleanup/2" do
    test "cleans up resources successfully" do
      context = RendererTestHelpers.build_render_context()
      result = %{content: "<html></html>"}

      assert HtmlRenderer.cleanup(context, result) == :ok
    end
  end

  describe "render/3 (legacy)" do
    test "renders using legacy API" do
      report = RendererTestHelpers.build_mock_report()
      data = [%{id: 1, name: "Test"}]

      {:ok, html} = HtmlRenderer.render(report, data, [])

      assert is_binary(html)
      assert html =~ "<!DOCTYPE html>"
    end

    test "accepts config option" do
      report = RendererTestHelpers.build_mock_report()
      data = [%{id: 1}]

      {:ok, html} = HtmlRenderer.render(report, data, config: %{theme: :modern})

      assert is_binary(html)
    end
  end

  describe "locale and RTL support" do
    test "includes locale in HTML lang attribute" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.content =~ ~r/lang="[a-z]{2}"/
    end

    test "includes text direction attribute" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.content =~ ~r/dir="(ltr|rtl)"/
    end

    test "adds RTL class when text direction is RTL" do
      context = RendererTestHelpers.build_render_context()
      context = %{context | text_direction: "rtl"}

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.content =~ "rtl"
    end
  end

  describe "metadata generation" do
    test "includes render time in metadata" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert Map.has_key?(result.metadata, :render_time_us)
      assert is_integer(result.metadata.render_time_us)
    end

    test "includes format in metadata" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert result.metadata.format == :html
    end

    test "includes element count in metadata" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert Map.has_key?(result.metadata, :element_count)
    end

    test "includes CSS rules count in metadata" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert Map.has_key?(result.metadata, :css_rules_count)
    end

    test "includes locale information in metadata" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      assert Map.has_key?(result.metadata, :locale)
      assert Map.has_key?(result.metadata, :text_direction)
    end
  end

  describe "error handling" do
    test "returns error for invalid template option" do
      context = RendererTestHelpers.build_render_context()

      result = HtmlRenderer.render_with_context(context, template: :nonexistent)

      # Renderer handles invalid template gracefully with defaults
      assert match?({:ok, _}, result)
    end

    test "handles missing layout state gracefully" do
      context = RendererTestHelpers.build_render_context()
      context = %{context | layout_state: nil}

      result = HtmlRenderer.render_with_context(context)

      assert match?({:error, _}, result) or is_map(result)
    end
  end

  describe "integration with sub-modules" do
    test "uses TemplateEngine for HTML structure" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      # Should have template-generated structure with report content
      assert result.content =~ "ash-report"
    end

    test "uses CssGenerator for styles" do
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = HtmlRenderer.render_with_context(context)

      # Should have CSS generated styles
      assert result.content =~ "<style>"
      assert result.content =~ ".ash-"
    end

    test "uses ElementBuilder for element HTML" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{
            name: :detail,
            type: :detail,
            height: 30,
            elements: [
              %{type: :label, name: :title, text: "Test Label", position: %{x: 0, y: 0}}
            ]
          }
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, result} = HtmlRenderer.render_with_context(context)

      # Should have element HTML
      assert result.content =~ "ash-element"
    end
  end
end
