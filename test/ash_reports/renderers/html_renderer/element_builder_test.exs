defmodule AshReports.HtmlRenderer.ElementBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.HtmlRenderer.ElementBuilder
  alias AshReports.RendererTestHelpers

  describe "build_all_elements/2" do
    test "builds HTML for all elements in context" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{
            name: :detail,
            type: :detail,
            elements: [
              %{type: :label, text: "Label 1", position: %{x: 0, y: 0}},
              %{type: :field, field: :name, position: %{x: 100, y: 0}}
            ]
          }
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, elements} = ElementBuilder.build_all_elements(context)

      assert is_list(elements)
      assert length(elements) == 2
    end

    test "filters out failed element builds" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{
            name: :detail,
            type: :detail,
            elements: [
              %{type: :label, text: "Valid", position: %{x: 0, y: 0}},
              %{type: :image, src: "", position: %{x: 0, y: 0}}
              # Missing src will cause error
            ]
          }
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, elements} = ElementBuilder.build_all_elements(context)

      assert is_list(elements)
    end

    test "includes band name in element metadata" do
      report = RendererTestHelpers.build_mock_report(
        bands: [
          %{
            name: :header,
            type: :report_header,
            elements: [
              %{type: :label, text: "Title", position: %{x: 0, y: 0}}
            ]
          }
        ]
      )

      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, elements} = ElementBuilder.build_all_elements(context)

      assert List.first(elements).band_name == :header
    end
  end

  describe "build_element/3" do
    test "builds HTML for a label element" do
      element = %{type: :label, text: "Test Label", position: %{x: 10, y: 20}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert is_map(result)
      assert result.element_type == :label
      assert result.html_content =~ "Test Label"
      assert result.html_content =~ "ash-element-label"
    end

    test "builds HTML for a field element" do
      element = %{type: :field, field: :name, position: %{x: 10, y: 20}}
      context = RendererTestHelpers.build_render_context(
        records: [%{name: "John Doe"}]
      )

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert result.element_type == :field
      assert result.html_content =~ "ash-element-field"
    end

    test "builds HTML for a line element" do
      element = %{type: :line, orientation: :horizontal, width: 200, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert result.element_type == :line
      assert result.html_content =~ "ash-element-line"
    end

    test "builds HTML for a box element" do
      element = %{type: :box, border: true, background: "#f0f0f0", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert result.element_type == :box
      assert result.html_content =~ "ash-element-box"
    end

    test "builds HTML for an image element" do
      element = %{type: :image, src: "logo.png", alt: "Logo", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert result.element_type == :image
      assert result.html_content =~ "logo.png"
      assert result.html_content =~ "Logo"
    end

    test "returns error for unsupported element type" do
      element = %{type: :custom_unsupported, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      assert {:error, {:unsupported_element_type, :custom_unsupported}} =
               ElementBuilder.build_element(element, context)
    end

    test "includes CSS classes in result" do
      element = %{type: :label, text: "Test", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert is_list(result.css_classes)
      assert "ash-element" in result.css_classes
      assert "ash-element-label" in result.css_classes
    end

    test "includes attributes in result" do
      element = %{type: :label, text: "Test", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert is_map(result.attributes)
    end
  end

  describe "build_label/3" do
    test "generates label HTML with text" do
      element = %{type: :label, text: "Customer Name", position: %{x: 10, y: 20}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      assert html =~ "Customer Name"
      assert html =~ "ash-element-label"
    end

    test "applies font styling" do
      element = %{
        type: :label,
        text: "Bold Text",
        font_weight: "bold",
        font_size: "18px",
        color: "#333",
        position: %{x: 0, y: 0}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      assert html =~ "font-weight: bold"
      assert html =~ "font-size: 18px"
      assert html =~ "color: #333"
    end

    test "applies positioning" do
      element = %{type: :label, text: "Test", position: %{x: 50, y: 75}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      assert html =~ "left: 50px"
      assert html =~ "top: 75px"
    end

    test "escapes HTML in text by default" do
      element = %{type: :label, text: "<script>alert('xss')</script>", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
    end
  end

  describe "build_field/3" do
    test "renders field value from context" do
      element = %{type: :field, field: :name, position: %{x: 0, y: 0}}

      context = RendererTestHelpers.build_render_context(
        records: [%{name: "John Doe"}]
      )

      {:ok, html} = ElementBuilder.build_field(element, context)

      assert html =~ "ash-element-field"
      assert html =~ "data-field=\"name\""
    end

    test "applies field formatting" do
      element = %{type: :field, field: :amount, format: :currency, position: %{x: 0, y: 0}}

      context = RendererTestHelpers.build_render_context(
        records: [%{amount: 1234.56}]
      )

      {:ok, html} = ElementBuilder.build_field(element, context)

      assert html =~ "$"
    end

    test "handles date formatting" do
      element = %{type: :field, field: :date, format: :date, position: %{x: 0, y: 0}}

      context = RendererTestHelpers.build_render_context(
        records: [%{date: ~D[2025-10-07]}]
      )

      {:ok, html} = ElementBuilder.build_field(element, context)

      assert html =~ "2025"
    end

    test "handles number formatting" do
      element = %{type: :field, field: :value, format: :number, position: %{x: 0, y: 0}}

      context = RendererTestHelpers.build_render_context(
        records: [%{value: 123.456}]
      )

      {:ok, html} = ElementBuilder.build_field(element, context)

      assert is_binary(html)
    end

    test "includes data attributes" do
      element = %{type: :field, field: :name, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_field(element, context)

      assert html =~ "data-field"
    end
  end

  describe "build_line/3" do
    test "generates horizontal line HTML" do
      element = %{type: :line, orientation: :horizontal, width: 2, length: 200, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_line(element, context)

      assert html =~ "<hr"
      assert html =~ "ash-line-horizontal"
    end

    test "generates vertical line HTML" do
      element = %{type: :line, orientation: :vertical, width: 2, length: 200, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_line(element, context)

      assert html =~ "<div"
      assert html =~ "ash-line-vertical"
    end

    test "applies line color" do
      element = %{type: :line, orientation: :horizontal, color: "#ff0000", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_line(element, context)

      assert html =~ "#ff0000"
    end

    test "defaults to horizontal orientation" do
      element = %{type: :line, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_line(element, context)

      assert html =~ "<hr"
    end
  end

  describe "build_box/3" do
    test "generates box HTML with border" do
      element = %{type: :box, border: true, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_box(element, context)

      assert html =~ "ash-element-box"
      assert html =~ "border:"
    end

    test "applies background color" do
      element = %{type: :box, background: "#f0f0f0", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_box(element, context)

      assert html =~ "#f0f0f0"
    end

    test "includes content if provided" do
      element = %{type: :box, content: "Box Content", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_box(element, context)

      assert html =~ "Box Content"
    end

    test "applies padding" do
      element = %{type: :box, padding: "10px", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_box(element, context)

      assert html =~ "padding:"
    end
  end

  describe "build_image/3" do
    test "generates image HTML with src" do
      element = %{type: :image, src: "logo.png", alt: "Company Logo", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_image(element, context)

      assert html =~ "<img"
      assert html =~ "logo.png"
      assert html =~ "Company Logo"
    end

    test "returns error for missing src" do
      element = %{type: :image, alt: "Logo", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      assert {:error, :missing_image_src} = ElementBuilder.build_image(element, context)
    end

    test "applies max-width styling" do
      element = %{type: :image, src: "image.jpg", max_width: "80%", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_image(element, context)

      assert html =~ "max-width:"
    end

    test "includes alt text for accessibility" do
      element = %{type: :image, src: "chart.png", alt: "Sales Chart", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_image(element, context)

      assert html =~ "alt=\"Sales Chart\""
    end
  end

  describe "supports_element?/1" do
    test "returns true for supported element types" do
      assert ElementBuilder.supports_element?(%{type: :label})
      assert ElementBuilder.supports_element?(%{type: :field})
      assert ElementBuilder.supports_element?(%{type: :line})
      assert ElementBuilder.supports_element?(%{type: :box})
      assert ElementBuilder.supports_element?(%{type: :image})
    end

    test "returns false for unsupported element types" do
      refute ElementBuilder.supports_element?(%{type: :custom_type})
      refute ElementBuilder.supports_element?(%{type: :unknown})
    end

    test "defaults to label type when type missing" do
      assert ElementBuilder.supports_element?(%{text: "No type specified"})
    end
  end

  describe "supports_element_type?/1" do
    test "returns true for all supported types" do
      assert ElementBuilder.supports_element_type?(:label)
      assert ElementBuilder.supports_element_type?(:field)
      assert ElementBuilder.supports_element_type?(:line)
      assert ElementBuilder.supports_element_type?(:box)
      assert ElementBuilder.supports_element_type?(:image)
      assert ElementBuilder.supports_element_type?(:aggregate)
      assert ElementBuilder.supports_element_type?(:expression)
    end

    test "returns false for unsupported types" do
      refute ElementBuilder.supports_element_type?(:custom)
      refute ElementBuilder.supports_element_type?(:unknown)
    end
  end

  describe "get_supported_elements/0" do
    test "returns list of supported element types" do
      supported = ElementBuilder.get_supported_elements()

      assert is_list(supported)
      assert :label in supported
      assert :field in supported
      assert :line in supported
      assert :box in supported
      assert :image in supported
    end
  end

  describe "HTML escaping" do
    test "escapes HTML special characters" do
      element = %{type: :label, text: "<>&\"'", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      assert html =~ "&lt;"
      assert html =~ "&gt;"
      assert html =~ "&amp;"
      assert html =~ "&quot;"
      assert html =~ "&#39;"
    end

    test "can disable HTML escaping with option" do
      element = %{type: :label, text: "<b>Bold</b>", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context, escape_html: false)

      assert html =~ "<b>Bold</b>"
    end
  end

  describe "data attributes" do
    test "includes data-element attribute when name is set" do
      element = %{type: :label, name: :customer_label, text: "Test", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context, include_data_attributes: true)

      assert result.attributes["data-element"] == :customer_label
    end

    test "includes data-field attribute for fields" do
      element = %{type: :field, field: :name, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_field(element, context)

      assert html =~ "data-field"
    end

    test "can disable data attributes with option" do
      element = %{type: :label, name: :label1, text: "Test", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context, include_data_attributes: false)

      refute Map.has_key?(result.attributes, "data-element")
    end
  end

  describe "accessibility attributes" do
    test "includes ARIA label for images with alt text" do
      element = %{type: :image, src: "logo.png", alt: "Company Logo", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context, accessibility: true)

      assert Map.has_key?(result.attributes, "aria-label")
    end

    test "can disable accessibility attributes" do
      element = %{type: :image, src: "logo.png", alt: "Logo", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context, accessibility: false)

      refute Map.has_key?(result.attributes, "aria-label")
    end
  end

  describe "positioning" do
    test "applies absolute positioning" do
      element = %{type: :label, text: "Test", position: %{x: 100, y: 200}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      assert html =~ "position: absolute"
      assert html =~ "left: 100px"
      assert html =~ "top: 200px"
    end

    test "includes width and height when specified" do
      element = %{type: :box, position: %{x: 0, y: 0, width: 300, height: 200}}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_box(element, context)

      assert html =~ "width: 300px"
      assert html =~ "height: 200px"
    end

    test "handles missing position gracefully" do
      element = %{type: :label, text: "Test"}
      context = RendererTestHelpers.build_render_context()

      {:ok, html} = ElementBuilder.build_label(element, context)

      assert html =~ "left: 0px"
      assert html =~ "top: 0px"
    end
  end

  describe "custom CSS classes" do
    test "includes custom CSS classes from element" do
      element = %{
        type: :label,
        text: "Test",
        css_classes: ["custom-class", "highlight"],
        position: %{x: 0, y: 0}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert "custom-class" in result.css_classes
      assert "highlight" in result.css_classes
    end
  end

  describe "aggregate elements" do
    test "renders aggregate elements as fields" do
      element = %{type: :aggregate, field: :total, position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert result.element_type == :aggregate
      assert result.html_content =~ "ash-element-field"
    end
  end

  describe "expression elements" do
    test "renders expression elements as fields" do
      element = %{type: :expression, expression: "test", position: %{x: 0, y: 0}}
      context = RendererTestHelpers.build_render_context()

      {:ok, result} = ElementBuilder.build_element(element, context)

      assert result.element_type == :expression
      assert result.html_content =~ "ash-element-field"
    end
  end
end
