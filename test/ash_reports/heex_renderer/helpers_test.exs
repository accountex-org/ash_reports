defmodule AshReports.HeexRenderer.HelpersTest do
  @moduledoc """
  Test suite for HEEX renderer helper functions.

  Tests layout helpers, style generators, formatting utilities,
  and other helper functions used in HEEX templates.
  """

  use ExUnit.Case, async: true

  alias AshReports.HeexRenderer.Helpers
  alias AshReports.{Band, Element, Report}
  alias AshReports.Element.{Box, Field, Image, Label, Line}

  describe "element_classes/2" do
    test "generates basic element classes" do
      element = %Label{name: :test_label, x: 10, y: 20}
      classes = Helpers.element_classes(element)

      assert String.contains?(classes, "ash-element")
      assert String.contains?(classes, "ash-element-label")
      assert String.contains?(classes, "position-absolute")
    end

    test "includes additional classes when provided" do
      element = %Label{name: :test_label}
      classes = Helpers.element_classes(element, "custom-class")

      assert String.contains?(classes, "ash-element")
      assert String.contains?(classes, "custom-class")
    end

    test "handles different element types correctly" do
      field_element = %Field{name: :test_field}
      field_classes = Helpers.element_classes(field_element)
      assert String.contains?(field_classes, "ash-element-field")

      image_element = %Image{name: :test_image}
      image_classes = Helpers.element_classes(image_element)
      assert String.contains?(image_classes, "ash-element-image")
    end

    test "applies positioning classes based on coordinates" do
      positioned_element = %Label{name: :positioned, x: 100, y: 200}
      positioned_classes = Helpers.element_classes(positioned_element)
      assert String.contains?(positioned_classes, "position-absolute")

      relative_element = %Label{name: :relative}
      relative_classes = Helpers.element_classes(relative_element)
      assert String.contains?(relative_classes, "position-relative")
    end

    test "applies sizing classes based on dimensions" do
      fixed_size = %Label{name: :fixed, width: 100, height: 50}
      fixed_classes = Helpers.element_classes(fixed_size)
      assert String.contains?(fixed_classes, "sized-fixed")

      width_only = %Label{name: :width_only, width: 100}
      width_classes = Helpers.element_classes(width_only)
      assert String.contains?(width_classes, "sized-width")

      auto_size = %Label{name: :auto}
      auto_classes = Helpers.element_classes(auto_size)
      assert String.contains?(auto_classes, "sized-auto")
    end
  end

  describe "band_classes/2" do
    test "generates basic band classes" do
      band = %Band{name: :header, type: :header}
      classes = Helpers.band_classes(band)

      assert String.contains?(classes, "ash-band")
      assert String.contains?(classes, "ash-band-header")
      assert String.contains?(classes, "layout-horizontal")
    end

    test "handles different band types" do
      detail_band = %Band{name: :detail, type: :detail}
      detail_classes = Helpers.band_classes(detail_band)
      assert String.contains?(detail_classes, "ash-band-detail")

      footer_band = %Band{name: :footer, type: :footer}
      footer_classes = Helpers.band_classes(footer_band)
      assert String.contains?(footer_classes, "ash-band-footer")
    end

    test "applies layout classes based on band layout" do
      vertical_band = %Band{name: :vertical, type: :detail, layout: :vertical}
      vertical_classes = Helpers.band_classes(vertical_band)
      assert String.contains?(vertical_classes, "layout-vertical")

      grid_band = %Band{name: :grid, type: :detail, layout: :grid}
      grid_classes = Helpers.band_classes(grid_band)
      assert String.contains?(grid_classes, "layout-grid")
    end

    test "applies height classes based on band height" do
      fixed_height = %Band{name: :fixed, type: :detail, height: 50}
      fixed_classes = Helpers.band_classes(fixed_height)
      assert String.contains?(fixed_classes, "height-fixed")

      auto_height = %Band{name: :auto, type: :detail}
      auto_classes = Helpers.band_classes(auto_height)
      assert String.contains?(auto_classes, "height-auto")
    end
  end

  describe "report_classes/3" do
    test "generates basic report classes" do
      report = build_test_report()
      config = %{}
      classes = Helpers.report_classes(report, config)

      assert String.contains?(classes, "ash-report")
      assert String.contains?(classes, "theme-default")
    end

    test "applies theme classes from configuration" do
      report = build_test_report()

      modern_config = %{theme: :modern}
      modern_classes = Helpers.report_classes(report, modern_config)
      assert String.contains?(modern_classes, "theme-modern")

      classic_config = %{theme: :classic}
      classic_classes = Helpers.report_classes(report, classic_config)
      assert String.contains?(classic_classes, "theme-classic")
    end

    test "applies responsive classes" do
      report = build_test_report()

      responsive_config = %{responsive: true}
      responsive_classes = Helpers.report_classes(report, responsive_config)
      assert String.contains?(responsive_classes, "responsive")

      fixed_config = %{responsive: false}
      fixed_classes = Helpers.report_classes(report, fixed_config)
      assert String.contains?(fixed_classes, "fixed-layout")
    end

    test "applies layout mode classes" do
      report = build_test_report()

      fluid_config = %{layout_mode: :fluid}
      fluid_classes = Helpers.report_classes(report, fluid_config)
      assert String.contains?(fluid_classes, "layout-fluid")
    end
  end

  describe "build_css_classes/1" do
    test "joins valid classes with spaces" do
      classes = ["class1", "class2", "class3"]
      result = Helpers.build_css_classes(classes)

      assert result == "class1 class2 class3"
    end

    test "filters out nil values" do
      classes = ["class1", nil, "class2"]
      result = Helpers.build_css_classes(classes)

      assert result == "class1 class2"
    end

    test "filters out empty strings" do
      classes = ["class1", "", "class2"]
      result = Helpers.build_css_classes(classes)

      assert result == "class1 class2"
    end

    test "trims whitespace from classes" do
      classes = ["  class1  ", " class2 "]
      result = Helpers.build_css_classes(classes)

      assert result == "class1 class2"
    end

    test "handles empty list" do
      result = Helpers.build_css_classes([])
      assert result == ""
    end

    test "handles non-list input" do
      result = Helpers.build_css_classes("not a list")
      assert result == ""
    end
  end

  describe "element_styles/1" do
    test "generates position styles for positioned elements" do
      element = %Label{name: :positioned, x: 100, y: 50}
      styles = Helpers.element_styles(element)

      assert String.contains?(styles, "position: absolute;")
      assert String.contains?(styles, "left: 100px;")
      assert String.contains?(styles, "top: 50px;")
    end

    test "generates dimension styles" do
      element = %Label{name: :sized, width: 200, height: 100}
      styles = Helpers.element_styles(element)

      assert String.contains?(styles, "width: 200px;")
      assert String.contains?(styles, "height: 100px;")
    end

    test "generates appearance styles" do
      element = %Label{
        name: :styled,
        color: "#ff0000",
        background_color: "#f0f0f0",
        font_size: 14
      }

      styles = Helpers.element_styles(element)

      assert String.contains?(styles, "color: #ff0000;")
      assert String.contains?(styles, "background-color: #f0f0f0;")
      assert String.contains?(styles, "font-size: 14px;")
    end

    test "handles elements without styles" do
      element = %Label{name: :plain}
      styles = Helpers.element_styles(element)

      assert styles == ""
    end
  end

  describe "band_styles/1" do
    test "generates height styles" do
      band = %Band{name: :sized, type: :detail, height: 50}
      styles = Helpers.band_styles(band)

      assert String.contains?(styles, "height: 50px;")
    end

    test "generates background color styles" do
      band = %Band{name: :colored, type: :detail, background_color: "#f5f5f5"}
      styles = Helpers.band_styles(band)

      assert String.contains?(styles, "background-color: #f5f5f5;")
    end

    test "generates padding styles" do
      band = %Band{name: :padded, type: :detail, padding: 10}
      styles = Helpers.band_styles(band)

      assert String.contains?(styles, "padding: 10px;")
    end

    test "handles bands without styles" do
      band = %Band{name: :plain, type: :detail}
      styles = Helpers.band_styles(band)

      assert styles == ""
    end
  end

  describe "build_style_string/1" do
    test "joins styles with semicolons" do
      styles = ["color: red", "font-size: 14px"]
      result = Helpers.build_style_string(styles)

      assert result == "color: red; font-size: 14px;"
    end

    test "filters out nil and empty styles" do
      styles = ["color: red", nil, "", "font-size: 14px"]
      result = Helpers.build_style_string(styles)

      assert result == "color: red; font-size: 14px;"
    end

    test "trims whitespace from styles" do
      styles = ["  color: red  ", " font-size: 14px "]
      result = Helpers.build_style_string(styles)

      assert result == "color: red; font-size: 14px;"
    end

    test "handles empty list" do
      result = Helpers.build_style_string([])
      assert result == ""
    end

    test "handles non-list input" do
      result = Helpers.build_style_string("not a list")
      assert result == ""
    end
  end

  describe "format_currency/2" do
    test "formats currency with default dollar symbol" do
      result = Helpers.format_currency(1234.56)
      assert result == "$1,234.56"
    end

    test "formats currency with custom symbol" do
      result = Helpers.format_currency(1234.56, "€")
      assert result == "€1,234.56"
    end

    test "handles integer values" do
      result = Helpers.format_currency(1000)
      assert result == "$1,000.00"
    end

    test "handles zero values" do
      result = Helpers.format_currency(0)
      assert result == "$0.00"
    end

    test "handles negative values" do
      result = Helpers.format_currency(-123.45)
      assert result == "$-123.45"
    end

    test "handles non-numeric values" do
      result = Helpers.format_currency("not a number")
      assert result == ""
    end
  end

  describe "format_percentage/2" do
    test "formats percentage with default precision" do
      result = Helpers.format_percentage(0.1234)
      assert result == "12.34%"
    end

    test "formats percentage with custom precision" do
      result = Helpers.format_percentage(0.1234, 1)
      assert result == "12.3%"
    end

    test "handles zero values" do
      result = Helpers.format_percentage(0)
      assert result == "0.00%"
    end

    test "handles values over 100%" do
      result = Helpers.format_percentage(1.5)
      assert result == "150.00%"
    end

    test "handles non-numeric values" do
      result = Helpers.format_percentage("not a number")
      assert result == ""
    end
  end

  describe "format_date/2" do
    test "formats date with default format" do
      date = ~D[2023-12-25]
      result = Helpers.format_date(date)

      assert result == "2023-12-25"
    end

    test "formats date with short format" do
      date = ~D[2023-12-25]
      result = Helpers.format_date(date, :short)

      assert result == "12/25/23"
    end

    test "formats date with medium format" do
      date = ~D[2023-12-25]
      result = Helpers.format_date(date, :medium)

      assert result == "Dec 25, 2023"
    end

    test "formats date with long format" do
      date = ~D[2023-12-25]
      result = Helpers.format_date(date, :long)

      assert result == "December 25, 2023"
    end

    test "formats DateTime as date" do
      datetime = ~U[2023-12-25 15:30:00Z]
      result = Helpers.format_date(datetime, :short)

      assert result == "12/25/23"
    end

    test "handles nil dates" do
      result = Helpers.format_date(nil, :short)
      assert result == ""
    end

    test "handles invalid input" do
      result = Helpers.format_date("not a date", :short)
      assert result == ""
    end
  end

  describe "format_datetime/2" do
    test "formats datetime with default format" do
      datetime = ~U[2023-12-25 15:30:00Z]
      result = Helpers.format_datetime(datetime)

      assert result == "2023-12-25 15:30:00 UTC"
    end

    test "formats datetime with short format" do
      datetime = ~U[2023-12-25 15:30:00Z]
      result = Helpers.format_datetime(datetime, :short)

      assert result == "12/25/23 3:30 PM"
    end

    test "handles nil datetime" do
      result = Helpers.format_datetime(nil, :short)
      assert result == ""
    end
  end

  describe "format_number/2" do
    test "formats integer with thousands separators" do
      result = Helpers.format_number(1_234_567)
      assert result == "1,234,567"
    end

    test "formats float with precision" do
      result = Helpers.format_number(1234.5678, 2)
      assert result == "1,234.57"
    end

    test "handles zero precision" do
      result = Helpers.format_number(1234.99, 0)
      assert result == "1,234"
    end

    test "handles non-numeric values" do
      result = Helpers.format_number("not a number")
      assert result == ""
    end
  end

  describe "get_field_value/3" do
    test "retrieves field value from record" do
      record = %{name: "John", age: 30}
      result = Helpers.get_field_value(record, :name)

      assert result == "John"
    end

    test "returns default for missing field" do
      record = %{name: "John"}
      result = Helpers.get_field_value(record, :age, "Unknown")

      assert result == "Unknown"
    end

    test "handles nil record" do
      result = Helpers.get_field_value(nil, :name, "Default")
      assert result == "Default"
    end

    test "handles non-map record" do
      result = Helpers.get_field_value("not a map", :field, "Default")
      assert result == "Default"
    end
  end

  describe "get_nested_field/3" do
    test "retrieves nested field value" do
      record = %{
        customer: %{
          address: %{
            city: "New York"
          }
        }
      }

      result = Helpers.get_nested_field(record, [:customer, :address, :city])
      assert result == "New York"
    end

    test "returns default for missing nested field" do
      record = %{customer: %{name: "John"}}
      result = Helpers.get_nested_field(record, [:customer, :address, :city], "Unknown")

      assert result == "Unknown"
    end

    test "handles nil record" do
      result = Helpers.get_nested_field(nil, [:customer, :name], "Default")
      assert result == "Default"
    end

    test "handles empty path" do
      record = %{name: "John"}
      result = Helpers.get_nested_field(record, [], "Default")

      assert result == record
    end
  end

  describe "element_id/1" do
    test "generates unique ID for element" do
      element = %Label{name: :customer_name}
      id = Helpers.element_id(element)

      assert String.starts_with?(id, "ash-element-customer_name-")
      # Should include timestamp
      assert String.length(id) > 20
    end

    test "generates different IDs for multiple calls" do
      element = %Label{name: :test}

      id1 = Helpers.element_id(element)
      # Ensure different timestamp
      Process.sleep(1)
      id2 = Helpers.element_id(element)

      assert id1 != id2
    end
  end

  describe "band_id/1" do
    test "generates unique ID for band" do
      band = %Band{name: :header, type: :header}
      id = Helpers.band_id(band)

      assert String.starts_with?(id, "ash-band-header-")
      assert String.length(id) > 15
    end
  end

  describe "element_visible?/3" do
    test "returns true when no visibility condition" do
      element = %Label{name: :always_visible}
      result = Helpers.element_visible?(element, %{}, %{})

      assert result == true
    end

    test "evaluates visibility condition when present" do
      element = %Label{name: :conditional, visible_when: "status == 'active'"}

      # This is a placeholder test as we haven't implemented condition evaluation
      result = Helpers.element_visible?(element, %{status: "active"}, %{})
      assert result == true
    end
  end

  describe "responsive_classes/1" do
    test "generates responsive classes when enabled" do
      config = %{responsive: true}
      classes = Helpers.responsive_classes(config)

      assert String.contains?(classes, "responsive")
    end

    test "generates mobile-first classes when enabled" do
      config = %{responsive: true, mobile_first: true}
      classes = Helpers.responsive_classes(config)

      assert String.contains?(classes, "mobile-first")
    end

    test "handles empty configuration" do
      classes = Helpers.responsive_classes(%{})
      assert classes == ""
    end
  end

  describe "accessibility_attrs/1" do
    test "generates role attributes for different element types" do
      label_element = %Label{name: :test_label}
      label_attrs = Helpers.accessibility_attrs(label_element)
      assert label_attrs.role == "text"

      image_element = %Image{name: :test_image}
      image_attrs = Helpers.accessibility_attrs(image_element)
      assert image_attrs.role == "img"
    end

    test "includes aria-label when description present" do
      element = %Label{name: :test, description: "Test Label"}
      attrs = Helpers.accessibility_attrs(element)

      assert attrs["aria-label"] == "Test Label"
    end

    test "handles elements without description" do
      element = %Label{name: :test}
      attrs = Helpers.accessibility_attrs(element)

      refute Map.has_key?(attrs, "aria-label")
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
          elements: [
            %Label{name: :title, text: "Test Report"}
          ]
        }
      ]
    }
  end
end
