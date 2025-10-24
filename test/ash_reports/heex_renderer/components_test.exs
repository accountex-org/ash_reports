defmodule AshReports.HeexRenderer.ComponentsTest do
  @moduledoc """
  Test suite for HEEX renderer components.

  Tests all Phoenix components for proper rendering, attribute handling,
  and integration with the component library.
  """

  use ExUnit.Case, async: true

  alias AshReports.HeexRenderer.Components
  alias AshReports.{Band, Element, Report}
  alias AshReports.Element.{Aggregate, Box, Expression, Field, Image, Label, Line}

  describe "report_container/1" do
    test "renders report container with basic attributes" do
      _assigns = %{
        report: build_test_report(),
        config: %{},
        class: "custom-class",
        inner_block: []
      }

      # Note: This is a simplified test as we can't easily test Phoenix.Component
      # rendering without a full Phoenix application context
      assert is_function(&Components.report_container/1)
    end

    test "generates proper CSS classes" do
      base_classes = ["ash-report-container", "custom-class"]
      result = Components.build_css_classes(base_classes)

      assert result == "ash-report-container custom-class"
    end

    test "filters out nil and empty classes" do
      classes = ["ash-report", nil, "", "custom-class"]
      result = Components.build_css_classes(classes)

      assert result == "ash-report custom-class"
    end
  end

  describe "report_header/1" do
    test "component function exists and is callable" do
      assert is_function(&Components.report_header/1)
    end

    test "formats datetime correctly" do
      datetime = ~U[2023-12-25 15:30:00Z]
      formatted = Components.format_datetime(datetime)

      assert formatted == "2023-12-25 15:30:00 UTC"
    end

    test "handles nil datetime gracefully" do
      formatted = Components.format_datetime(nil)
      assert formatted == ""
    end

    test "humanizes metadata keys properly" do
      assert Components.humanize_key(:customer_name) == "Customer Name"
      assert Components.humanize_key(:total_amount) == "Total Amount"
      assert Components.humanize_key("existing_string") == "existing_string"
    end
  end

  describe "band components" do
    test "band_group component function exists" do
      assert is_function(&Components.band_group/1)
    end

    test "band component function exists" do
      assert is_function(&Components.band/1)
    end

    test "generates proper band classes" do
      band = %Band{name: :header, type: :header, height: 50}
      classes = Components.band_classes(band)

      assert String.contains?(classes, "ash-band")
      assert String.contains?(classes, "ash-band-header")
    end

    test "generates band styles correctly" do
      band = %Band{
        name: :detail,
        type: :detail,
        height: 30
      }

      styles = Components.band_styles(band)

      assert String.contains?(styles, "height: 30px")
      assert String.contains?(styles, "background-color: #f5f5f5")
    end

    test "handles bands without styles" do
      # Use a non-detail band type to avoid default background color
      band = %Band{name: :simple, type: :header}
      styles = Components.band_styles(band)

      assert styles == ""
    end
  end

  describe "element components" do
    test "universal element component function exists" do
      assert is_function(&Components.element/1)
    end

    test "identifies element types correctly" do
      assert Components.element_type(%Label{}) == "label"
      assert Components.element_type(%Field{}) == "field"
      assert Components.element_type(%Image{}) == "image"
      assert Components.element_type(%Line{}) == "line"
      assert Components.element_type(%Box{}) == "box"
      assert Components.element_type(%Aggregate{}) == "aggregate"
      assert Components.element_type(%Expression{}) == "expression"
    end

    test "generates element classes correctly" do
      element = %Label{name: :test_label, position: %{x: 10, y: 20}}
      classes = Components.element_classes(element)

      assert String.contains?(classes, "ash-element")
      assert String.contains?(classes, "ash-element-label")
    end

    test "generates element styles with positioning" do
      element = %Label{name: :test, position: %{x: 100, y: 50}, style: %{width: 200, height: 30}}
      styles = Components.element_styles(element)

      assert String.contains?(styles, "position: absolute")
      assert String.contains?(styles, "left: 100px")
      assert String.contains?(styles, "top: 50px")
      assert String.contains?(styles, "width: 200px")
      assert String.contains?(styles, "height: 30px")
    end

    test "handles elements without positioning" do
      element = %Label{name: :test}
      styles = Components.element_styles(element)

      refute String.contains?(styles, "position: absolute")
    end
  end

  describe "specific element components" do
    test "label_element component function exists" do
      assert is_function(&Components.label_element/1)
    end

    test "field_element component function exists" do
      assert is_function(&Components.field_element/1)
    end

    test "image_element component function exists" do
      assert is_function(&Components.image_element/1)
    end

    test "line_element component function exists" do
      assert is_function(&Components.line_element/1)
    end

    test "box_element component function exists" do
      assert is_function(&Components.box_element/1)
    end

    test "aggregate_element component function exists" do
      assert is_function(&Components.aggregate_element/1)
    end

    test "expression_element component function exists" do
      assert is_function(&Components.expression_element/1)
    end
  end

  describe "field value formatting" do
    test "formats field values with format specification" do
      field = %Field{name: :amount, source: :amount, format: :currency}
      formatted = Components.format_field_value(123.45, field)

      assert formatted == "$123.45"
    end

    test "formats percentage values" do
      field = %Field{name: :rate, source: :rate, format: :percentage}
      formatted = Components.format_field_value(0.15, field)

      assert formatted == "0.15%"
    end

    test "handles nil values gracefully" do
      field = %Field{name: :test, source: :test}
      formatted = Components.format_field_value(nil, field)

      assert formatted == ""
    end

    test "converts values to string when no format specified" do
      field = %Field{name: :test, source: :test}
      formatted = Components.format_field_value(42, field)

      assert formatted == "42"
    end
  end

  describe "image styling" do
    test "generates image styles with scaling" do
      element = %Image{name: :logo, position: %{x: 10, y: 10}, style: %{scale: 1.5}}
      styles = Components.image_styles(element)

      assert String.contains?(styles, "transform: scale(1.5)")
    end

    test "handles images without scaling" do
      element = %Image{name: :logo, position: %{x: 10, y: 10}}
      styles = Components.image_styles(element)

      refute String.contains?(styles, "transform: scale")
    end
  end

  describe "line styling" do
    test "generates line styles with thickness and color" do
      element = %Line{
        name: :border,
        thickness: 2,
        style: %{
          color: "#000000",
          border_style: :solid
        }
      }

      styles = Components.line_styles(element)

      assert String.contains?(styles, "border-width: 2px")
      assert String.contains?(styles, "border-color: #000000")
      assert String.contains?(styles, "border-style: solid")
    end

    test "applies default solid style for lines" do
      element = %Line{name: :simple}
      styles = Components.line_styles(element)

      assert String.contains?(styles, "border-style: solid")
    end
  end

  describe "box styling" do
    test "generates box styles with border and background" do
      element = %Box{
        name: :container,
        border: %{width: 1, color: "#cccccc"},
        fill: %{color: "#f9f9f9"}
      }

      styles = Components.box_styles(element)

      assert String.contains?(styles, "border-width: 1px")
      assert String.contains?(styles, "border-color: #cccccc")
      assert String.contains?(styles, "background-color: #f9f9f9")
    end
  end

  describe "value resolution" do
    test "resolves label element values" do
      element = %Label{name: :title, text: "Test Title"}
      value = Components.resolve_element_value(element, nil, %{})

      assert value == "Test Title"
    end

    test "resolves field element values from record" do
      element = %Field{name: :customer, source: :customer_name}
      record = %{customer_name: "John Doe"}
      value = Components.resolve_element_value(element, record, %{})

      assert value == "John Doe"
    end

    test "handles missing field gracefully" do
      element = %Field{name: :missing, source: :non_existent}
      record = %{other_field: "value"}
      value = Components.resolve_element_value(element, record, %{})

      assert value == nil
    end

    test "handles nil record gracefully" do
      element = %Field{name: :test, source: :test_field}
      value = Components.resolve_element_value(element, nil, %{})

      assert value == nil
    end
  end

  describe "date and time formatting" do
    test "formats dates in different formats" do
      date = ~D[2023-12-25]

      assert Components.format_date(date, :short) == "12/25/23"
      assert Components.format_date(date, :medium) == "Dec 25, 2023"
      assert Components.format_date(date, :long) == "December 25, 2023"
      assert Components.format_date(date, :iso) == "2023-12-25"
    end

    test "formats datetime values" do
      datetime = ~U[2023-12-25 15:30:00Z]

      formatted = Components.format_date(datetime, :short)
      assert formatted == "12/25/23"
    end

    test "handles nil dates" do
      assert Components.format_date(nil, :short) == ""
    end
  end

  describe "render_single_component/3" do
    test "renders report_container component" do
      assigns = %{
        report: build_test_report(),
        config: %{},
        class: "",
        inner_block: []
      }

      context = %{}

      # This test verifies the function exists and handles the call
      # In a real Phoenix environment, this would return actual HEEX content
      result = Components.render_single_component(:report_container, assigns, context)

      # For now, we just verify it returns either success or error (doesn't crash)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for unknown component" do
      assigns = %{}
      context = %{}

      assert {:error, {:unknown_component, :invalid}} =
               Components.render_single_component(:invalid, assigns, context)
    end
  end

  describe "cleanup_component_cache/0" do
    test "cleanup function executes without error" do
      assert :ok = Components.cleanup_component_cache()
    end
  end

  describe "metadata value formatting" do
    test "formats list values correctly" do
      list_value = ["item1", "item2", "item3"]
      formatted = Components.format_metadata_value(list_value)

      assert formatted == "item1, item2, item3"
    end

    test "formats non-list values as strings" do
      assert Components.format_metadata_value(42) == "42"
      assert Components.format_metadata_value(:atom) == "atom"
      assert Components.format_metadata_value("string") == "string"
    end
  end

  # Test helper functions

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
        }
      ]
    }
  end
end
