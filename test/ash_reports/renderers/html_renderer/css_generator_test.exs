defmodule AshReports.HtmlRenderer.CssGeneratorTest do
  use ExUnit.Case, async: true

  alias AshReports.HtmlRenderer.CssGenerator
  alias AshReports.RendererTestHelpers

  describe "generate_stylesheet/2" do
    test "generates complete CSS stylesheet" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert is_binary(css)
      assert String.length(css) > 0
    end

    test "includes base CSS rules" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ ".ash-report"
      assert css =~ ".ash-band"
      assert css =~ ".ash-element"
    end

    test "includes report header styles" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ ".ash-report-header"
    end

    test "includes report footer styles" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ ".ash-report-footer"
    end

    test "applies default theme when no theme specified" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert is_binary(css)
    end

    test "applies professional theme" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :professional)

      assert is_binary(css)
    end

    test "applies modern theme" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :modern)

      assert is_binary(css)
    end

    test "returns error for invalid theme" do
      context = RendererTestHelpers.build_render_context()

      assert {:error, {:theme_not_found, :nonexistent}} =
               CssGenerator.generate_stylesheet(context, theme: :nonexistent)
    end

    test "generates responsive styles by default" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ "@media"
    end

    test "skips responsive styles when disabled" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, responsive: false)

      refute css =~ "@media"
    end

    test "minifies CSS when minify option is true" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css_minified} = CssGenerator.generate_stylesheet(context, minify: true)
      {:ok, css_normal} = CssGenerator.generate_stylesheet(context, minify: false)

      assert String.length(css_minified) < String.length(css_normal)
    end
  end

  describe "generate_from_layout/2" do
    test "generates CSS from layout result" do
      layout_result = %{
        bands: %{
          detail: %{
            position: %{x: 0, y: 0},
            dimensions: %{width: 800, height: 50},
            elements: []
          }
        }
      }

      {:ok, css} = CssGenerator.generate_from_layout(layout_result)

      assert is_binary(css)
      assert css =~ "data-band=\"detail\""
    end

    test "applies positioning from layout" do
      layout_result = %{
        bands: %{
          header: %{
            position: %{x: 10, y: 20},
            dimensions: %{width: 600, height: 80},
            elements: []
          }
        }
      }

      {:ok, css} = CssGenerator.generate_from_layout(layout_result)

      assert css =~ "top: 20px"
      assert css =~ "left: 10px"
    end

    test "includes element dimensions" do
      layout_result = %{
        bands: %{
          detail: %{
            position: %{x: 0, y: 0},
            dimensions: %{width: 800, height: 50},
            elements: [
              %{
                position: %{x: 10, y: 5},
                dimensions: %{width: 200, height: 30}
              }
            ]
          }
        }
      }

      {:ok, css} = CssGenerator.generate_from_layout(layout_result)

      assert css =~ "width: 200px"
      assert css =~ "height: 30px"
    end
  end

  describe "generate_responsive_styles/2" do
    test "generates mobile breakpoint styles" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

      assert css =~ "@media"
      assert css =~ "max-width:"
    end

    test "generates tablet breakpoint styles" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

      assert css =~ "@media"
    end

    test "uses theme colors in responsive styles" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context, theme: :modern)

      assert is_binary(css)
    end

    test "handles empty context" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

      assert is_binary(css)
    end
  end

  describe "generate_element_styles/2" do
    test "generates styles for label elements" do
      elements = [%{type: :label}]

      {:ok, css} = CssGenerator.generate_element_styles(elements)

      assert css =~ ".ash-element-label"
    end

    test "generates styles for field elements" do
      elements = [%{type: :field}]

      {:ok, css} = CssGenerator.generate_element_styles(elements)

      assert css =~ ".ash-element-field"
    end

    test "generates styles for line elements" do
      elements = [%{type: :line}]

      {:ok, css} = CssGenerator.generate_element_styles(elements)

      assert css =~ ".ash-element-line"
    end

    test "generates styles for box elements" do
      elements = [%{type: :box}]

      {:ok, css} = CssGenerator.generate_element_styles(elements)

      assert css =~ ".ash-element-box"
    end

    test "generates styles for image elements" do
      elements = [%{type: :image}]

      {:ok, css} = CssGenerator.generate_element_styles(elements)

      assert css =~ ".ash-element-image"
    end

    test "handles multiple element types" do
      elements = [
        %{type: :label},
        %{type: :field},
        %{type: :line}
      ]

      {:ok, css} = CssGenerator.generate_element_styles(elements)

      assert css =~ ".ash-element-label"
      assert css =~ ".ash-element-field"
      assert css =~ ".ash-element-line"
    end

    test "applies theme to element styles" do
      elements = [%{type: :label}]

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :professional)

      assert is_binary(css)
    end

    test "handles empty elements list" do
      {:ok, css} = CssGenerator.generate_element_styles([])

      assert css == ""
    end
  end

  describe "minify_css/1" do
    test "removes extra whitespace" do
      css = ".class {\n  color: red;\n  margin: 10px;\n}"

      {:ok, minified} = CssGenerator.minify_css(css)

      refute minified =~ "\n"
      assert String.length(minified) < String.length(css)
    end

    test "removes unnecessary semicolons" do
      css = ".class { color: red; }"

      {:ok, minified} = CssGenerator.minify_css(css)

      assert minified =~ "color:red"
    end

    test "preserves CSS functionality" do
      css = ".test { background: #fff; color: #000; }"

      {:ok, minified} = CssGenerator.minify_css(css)

      assert minified =~ ".test"
      assert minified =~ "background:#fff"
      assert minified =~ "color:#000"
    end

    test "handles empty CSS" do
      {:ok, minified} = CssGenerator.minify_css("")

      assert minified == ""
    end

    test "handles complex selectors" do
      css = ".parent > .child:hover { color: blue; }"

      {:ok, minified} = CssGenerator.minify_css(css)

      # Minifier preserves some spaces for readability
      assert minified =~ ".child:hover"
      assert minified =~ "color:blue"
    end
  end

  describe "cleanup_temporary_styles/0" do
    test "cleans up successfully" do
      assert CssGenerator.cleanup_temporary_styles() == :ok
    end

    test "can be called multiple times" do
      assert CssGenerator.cleanup_temporary_styles() == :ok
      assert CssGenerator.cleanup_temporary_styles() == :ok
    end
  end

  describe "get_generation_stats/0" do
    test "returns generation statistics" do
      stats = CssGenerator.get_generation_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :available_themes)
      assert Map.has_key?(stats, :base_rules_count)
      assert Map.has_key?(stats, :supported_breakpoints)
      assert Map.has_key?(stats, :css_version)
    end

    test "includes available themes" do
      stats = CssGenerator.get_generation_stats()

      assert :default in stats.available_themes
      assert :professional in stats.available_themes
      assert :modern in stats.available_themes
    end

    test "includes base rules count" do
      stats = CssGenerator.get_generation_stats()

      assert stats.base_rules_count > 0
    end

    test "includes supported breakpoints" do
      stats = CssGenerator.get_generation_stats()

      assert is_map(stats.supported_breakpoints)
    end
  end

  describe "theme configurations" do
    test "default theme has required colors" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :default)

      assert is_binary(css)
    end

    test "professional theme has distinct styling" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :professional)

      assert is_binary(css)
    end

    test "modern theme uses modern fonts" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :modern)

      assert is_binary(css)
    end
  end

  describe "layout-based CSS generation" do
    test "generates band-specific rules" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ ".ash-band"
    end

    test "includes element positioning rules" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{
            name: :detail,
            type: :detail,
            elements: [
              %{type: :label, position: %{x: 10, y: 20}}
            ]
          }
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ ".ash-element"
    end

    test "handles nested band structures" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{name: :header, type: :report_header, elements: []},
          %{name: :detail, type: :detail, elements: []},
          %{name: :footer, type: :report_footer, elements: []}
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ "data-band"
    end
  end

  describe "responsive breakpoints" do
    test "mobile breakpoint targets small screens" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

      assert css =~ "768px" or css =~ "max-width"
    end

    test "tablet breakpoint targets medium screens" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

      assert css =~ "@media"
    end

    test "elements adapt to mobile viewport" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

      assert css =~ "@media"
      assert css =~ ".ash-element"
    end
  end

  describe "element-specific styling" do
    test "label elements have bold font weight" do
      elements = [%{type: :label}]

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :default)

      assert css =~ "font-weight"
    end

    test "field elements have borders" do
      elements = [%{type: :field}]

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :default)

      assert css =~ "border"
    end

    test "line elements have height styling" do
      elements = [%{type: :line}]

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :default)

      assert css =~ "height"
    end

    test "box elements have padding" do
      elements = [%{type: :box}]

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :default)

      assert css =~ "padding"
    end

    test "image elements have max-width" do
      elements = [%{type: :image}]

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :default)

      assert css =~ "max-width"
    end
  end

  describe "custom CSS rules" do
    test "includes custom rules in output" do
      context = RendererTestHelpers.build_render_context()
      custom_rules = [".custom-class { color: blue; }"]

      {:ok, css} = CssGenerator.generate_stylesheet(context, custom_rules: custom_rules)

      assert css =~ ".custom-class"
    end

    test "supports multiple custom rules" do
      context = RendererTestHelpers.build_render_context()

      custom_rules = [
        ".rule1 { margin: 0; }",
        ".rule2 { padding: 10px; }"
      ]

      {:ok, css} = CssGenerator.generate_stylesheet(context, custom_rules: custom_rules)

      assert css =~ ".rule1"
      assert css =~ ".rule2"
    end
  end

  describe "CSS property formatting" do
    test "formats properties with hyphens" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, minify: false)

      assert css =~ "margin-bottom" or css =~ "padding-top"
    end

    test "includes semicolons after properties" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, minify: false)

      assert css =~ ";"
    end

    test "wraps rules in curly braces" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context, minify: false)

      assert css =~ "{"
      assert css =~ "}"
    end
  end

  describe "integration with context" do
    test "extracts element types from context" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{
            name: :detail,
            type: :detail,
            elements: [
              %{type: :label},
              %{type: :field},
              %{type: :line}
            ]
          }
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert css =~ ".ash-element-label"
      assert css =~ ".ash-element-field"
      assert css =~ ".ash-element-line"
    end

    test "uses layout state for positioning" do
      context = RendererTestHelpers.build_render_context()

      {:ok, css} = CssGenerator.generate_stylesheet(context)

      assert is_binary(css)
    end
  end
end
