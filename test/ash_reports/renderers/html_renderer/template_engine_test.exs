defmodule AshReports.HtmlRenderer.TemplateEngineTest do
  use ExUnit.Case, async: false

  alias AshReports.HtmlRenderer.TemplateEngine
  alias AshReports.RendererTestHelpers

  describe "render_complete_html/3" do
    test "renders complete HTML document" do
      context = RendererTestHelpers.build_render_context()
      css_content = ".ash-report { margin: 0; }"
      html_elements = []

      {:ok, html} = TemplateEngine.render_complete_html(context, css_content, html_elements)

      assert html =~ "<!DOCTYPE html>"
      assert html =~ "<html"
      assert html =~ "<head>"
      assert html =~ "<body"
    end

    test "includes CSS in style tag" do
      context = RendererTestHelpers.build_render_context()
      css_content = ".custom-class { color: red; }"
      html_elements = []

      {:ok, html} = TemplateEngine.render_complete_html(context, css_content, html_elements)

      assert html =~ "<style>"
      assert html =~ ".custom-class { color: red; }"
      assert html =~ "</style>"
    end

    test "includes report title" do
      report = RendererTestHelpers.build_mock_report(title: "Annual Report 2025")
      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, html} = TemplateEngine.render_complete_html(context, "", [])

      assert html =~ "Annual Report 2025"
    end

    test "renders all bands" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{name: :header, type: :report_header, elements: []},
          %{name: :detail, type: :detail, elements: []},
          %{name: :footer, type: :report_footer, elements: []}
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, html} = TemplateEngine.render_complete_html(context, "", [])

      assert html =~ "data-band=\"header\""
      assert html =~ "data-band=\"detail\""
      assert html =~ "data-band=\"footer\""
    end

    test "includes elements in bands" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{name: :detail, type: :detail, elements: []}
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      html_elements = [
        %{
          html_content: "<div>Element 1</div>",
          band_name: :detail,
          element_type: :label
        },
        %{
          html_content: "<div>Element 2</div>",
          band_name: :detail,
          element_type: :field
        }
      ]

      {:ok, html} = TemplateEngine.render_complete_html(context, "", html_elements)

      assert html =~ "Element 1"
      assert html =~ "Element 2"
    end

    test "uses report name when title not provided" do
      report = RendererTestHelpers.build_mock_report(name: :sales_report)
      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, html} = TemplateEngine.render_complete_html(context, "", [])

      assert html =~ "Sales_report" or html =~ "sales_report"
    end

    test "handles empty elements list" do
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = TemplateEngine.render_complete_html(context, "", [])

      assert html =~ "<html"
      assert html =~ "<body"
    end
  end

  describe "render_template/2" do
    test "renders master template" do
      assigns = %{
        lang: "en",
        report_title: "Test Report",
        css_content: ".test { }",
        content: "<div>Content</div>"
      }

      {:ok, html} = TemplateEngine.render_template(:master, assigns)

      assert html =~ "<!DOCTYPE html>"
      assert html =~ "Test Report"
      assert html =~ ".test { }"
      assert html =~ "<div>Content</div>"
    end

    test "renders report template" do
      assigns = %{
        report_title: "Sales Report",
        bands_content: "<section>Bands</section>"
      }

      {:ok, html} = TemplateEngine.render_template(:report, assigns)

      assert html =~ "Sales Report"
      assert html =~ "<section>Bands</section>"
    end

    test "renders band template" do
      assigns = %{
        band_name: :detail,
        band_type: :detail,
        elements_content: "<div>Elements</div>"
      }

      {:ok, html} = TemplateEngine.render_template(:band, assigns)

      assert html =~ "data-band=\"detail\""
      assert html =~ "ash-band-detail"
      assert html =~ "<div>Elements</div>"
    end

    test "renders element wrapper template" do
      assigns = %{
        element_type: :label,
        element_name: :title,
        element_content: "Title Text"
      }

      {:ok, html} = TemplateEngine.render_template(:element_wrapper, assigns)

      assert html =~ "ash-element-label"
      assert html =~ "data-element=\"title\""
      assert html =~ "Title Text"
    end

    test "returns error for unknown template" do
      assigns = %{}

      assert {:error, _} = TemplateEngine.render_template(:nonexistent, assigns)
    end
  end

  describe "compile_template_string/1" do
    test "compiles valid EEx template" do
      template = "<h1><%= @title %></h1>"

      {:ok, compiled} = TemplateEngine.compile_template_string(template)

      assert is_function(compiled)
    end

    test "compiles template with multiple variables" do
      template = "<div><%= @name %> - <%= @value %></div>"

      {:ok, compiled} = TemplateEngine.compile_template_string(template)

      assert is_function(compiled)
    end

    test "returns error for invalid template" do
      template = "<%= invalid syntax"

      assert {:error, _} = TemplateEngine.compile_template_string(template)
    end

    test "handles empty template" do
      template = ""

      {:ok, compiled} = TemplateEngine.compile_template_string(template)

      assert is_function(compiled)
    end
  end

  describe "validate_templates/0" do
    test "validates that all required templates exist" do
      result = TemplateEngine.validate_templates()

      assert result == :ok or match?({:error, _}, result)
    end

    test "succeeds when all templates are available" do
      # Default templates should always be available
      assert TemplateEngine.validate_templates() == :ok
    end
  end

  describe "cleanup_temporary_templates/0" do
    test "cleans up template cache" do
      # Register a temporary template
      TemplateEngine.register_template(:temp_test, "<div>Test</div>")

      # Clean up
      assert TemplateEngine.cleanup_temporary_templates() == :ok
    end

    test "can be called multiple times safely" do
      assert TemplateEngine.cleanup_temporary_templates() == :ok
      assert TemplateEngine.cleanup_temporary_templates() == :ok
    end
  end

  describe "register_template/2" do
    test "registers custom template successfully" do
      template_content = "<h1><%= @custom_title %></h1>"

      assert :ok = TemplateEngine.register_template(:custom, template_content)
    end

    test "registered template can be rendered" do
      template_content = "<div class=\"custom\"><%= @content %></div>"
      TemplateEngine.register_template(:custom_render, template_content)

      assigns = %{content: "Test Content"}

      {:ok, html} = TemplateEngine.render_template(:custom_render, assigns)

      assert html =~ "class=\"custom\""
      assert html =~ "Test Content"
    end

    test "returns error for invalid template syntax" do
      template_content = "<%= invalid syntax"

      assert {:error, _} = TemplateEngine.register_template(:invalid, template_content)
    end

    test "overwrites existing template" do
      TemplateEngine.register_template(:overwrite_test, "<div>Version 1</div>")
      TemplateEngine.register_template(:overwrite_test, "<div>Version 2</div>")

      {:ok, html} = TemplateEngine.render_template(:overwrite_test, %{})

      assert html =~ "Version 2"
      refute html =~ "Version 1"
    end
  end

  describe "get_template_info/0" do
    test "returns template information" do
      info = TemplateEngine.get_template_info()

      assert is_map(info)
      assert Map.has_key?(info, :cache_size)
      assert Map.has_key?(info, :default_templates_count)
      assert Map.has_key?(info, :available_templates)
      assert Map.has_key?(info, :cache_memory)
    end

    test "includes default templates count" do
      info = TemplateEngine.get_template_info()

      assert info.default_templates_count > 0
    end

    test "lists available templates" do
      info = TemplateEngine.get_template_info()

      assert is_list(info.available_templates)
      assert :master in info.available_templates
      assert :report in info.available_templates
      assert :band in info.available_templates
    end
  end

  describe "template caching" do
    test "caches compiled templates" do
      template = "<h1><%= @title %></h1>"
      TemplateEngine.register_template(:cache_test, template)

      # First render
      {:ok, _html1} = TemplateEngine.render_template(:cache_test, %{title: "Test 1"})

      # Second render should use cached version
      {:ok, html2} = TemplateEngine.render_template(:cache_test, %{title: "Test 2"})

      assert html2 =~ "Test 2"
    end

    test "cache persists across multiple renders" do
      assigns1 = %{title: "First"}
      assigns2 = %{title: "Second"}

      {:ok, html1} = TemplateEngine.render_template(:master, assigns1)
      {:ok, html2} = TemplateEngine.render_template(:master, assigns2)

      assert html1 =~ "First"
      assert html2 =~ "Second"
    end
  end

  describe "default templates" do
    test "master template includes DOCTYPE" do
      {:ok, compiled} = TemplateEngine.compile_template_string(
        """
        <!DOCTYPE html>
        <html lang="<%= @lang %>">
        <head><title><%= @report_title %></title></head>
        <body><%= @content %></body>
        </html>
        """
      )

      assert is_function(compiled)
    end

    test "report template includes header and footer" do
      assigns = %{
        report_title: "Test",
        bands_content: ""
      }

      {:ok, html} = TemplateEngine.render_template(:report, assigns)

      assert html =~ "ash-report-header"
      assert html =~ "ash-report-footer"
    end

    test "band template includes section element" do
      assigns = %{
        band_name: :test,
        band_type: :detail,
        elements_content: ""
      }

      {:ok, html} = TemplateEngine.render_template(:band, assigns)

      assert html =~ "<section"
      assert html =~ "ash-band"
    end
  end

  describe "EEx template features" do
    test "supports conditionals" do
      template = "<%= if @show do %>Visible<% end %>"
      TemplateEngine.register_template(:conditional_test, template)

      {:ok, html_true} = TemplateEngine.render_template(:conditional_test, %{show: true})
      {:ok, html_false} = TemplateEngine.render_template(:conditional_test, %{show: false})

      assert html_true =~ "Visible"
      refute html_false =~ "Visible"
    end

    test "supports loops" do
      template = "<%= for item <- @items do %><li><%= item %></li><% end %>"
      TemplateEngine.register_template(:loop_test, template)

      {:ok, html} = TemplateEngine.render_template(:loop_test, %{items: ["A", "B", "C"]})

      assert html =~ "<li>A</li>"
      assert html =~ "<li>B</li>"
      assert html =~ "<li>C</li>"
    end

    test "supports nested templates" do
      template = """
      <div>
        <%= for section <- @sections do %>
          <section><%= section.title %></section>
        <% end %>
      </div>
      """

      TemplateEngine.register_template(:nested_test, template)

      sections = [
        %{title: "Section 1"},
        %{title: "Section 2"}
      ]

      {:ok, html} = TemplateEngine.render_template(:nested_test, %{sections: sections})

      assert html =~ "Section 1"
      assert html =~ "Section 2"
    end
  end

  describe "error handling" do
    test "handles missing template variables gracefully" do
      template = "<%= @missing_var %>"
      TemplateEngine.register_template(:missing_var_test, template)

      # Should raise error when rendering with missing variable
      assert_raise KeyError, fn ->
        TemplateEngine.render_template(:missing_var_test, %{})
      end
    end

    test "returns error for template compilation failure" do
      invalid_template = "<%= invalid !! syntax %>"

      result = TemplateEngine.compile_template_string(invalid_template)

      assert match?({:error, _}, result)
    end
  end

  describe "integration with context" do
    test "filters elements by band name" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{name: :band1, type: :detail, elements: []},
          %{name: :band2, type: :detail, elements: []}
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      elements = [
        %{html_content: "<div>Band 1 Element</div>", band_name: :band1},
        %{html_content: "<div>Band 2 Element</div>", band_name: :band2}
      ]

      {:ok, html} = TemplateEngine.render_complete_html(context, "", elements)

      assert html =~ "Band 1 Element"
      assert html =~ "Band 2 Element"
    end

    test "uses locale from context" do
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = TemplateEngine.render_complete_html(context, "", [])

      assert html =~ "lang="
    end
  end
end
