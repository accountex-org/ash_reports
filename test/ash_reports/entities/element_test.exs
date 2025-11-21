defmodule AshReports.Entities.ElementTest do
  @moduledoc """
  Tests for AshReports element entity structures and validation.

  Tests all 7 element types: label, field, expression, aggregate, line, box, image.
  """

  use ExUnit.Case, async: true

  alias AshReports.Info

  describe "Label element" do
    test "extracts label element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      title_band = Enum.find(report.bands, &(&1.type == :title))
      elements = Map.get(title_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :title_label))
      assert label != nil
      assert label.text == "Report Title"
    end
  end

  describe "Field element" do
    test "extracts field element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :customer_name))
      assert field != nil
      assert field.source == :name
    end
  end

  describe "Expression element" do
    test "extracts expression element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      expression = Enum.find(elements, &(&1.name == :computed_value))
      assert expression != nil
      assert expression.expression == :id
    end
  end

  describe "Aggregate element" do
    test "extracts aggregate element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      summary_band = Enum.find(report.bands, &(&1.type == :summary))
      elements = Map.get(summary_band, :elements, [])

      aggregate = Enum.find(elements, &(&1.name == :total_count))
      assert aggregate != nil
      assert aggregate.function == :count
      assert aggregate.source == :id
      assert aggregate.scope == :report
    end
  end

  describe "Line element" do
    test "extracts line element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      line = Enum.find(elements, &(&1.name == :separator))
      assert line != nil
      assert line.orientation == :horizontal
      assert line.thickness == 2
    end
  end

  describe "Box element" do
    test "extracts box element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      box = Enum.find(elements, &(&1.name == :border_box))
      assert box != nil
    end
  end

  describe "Image element" do
    test "extracts image element correctly" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      image = Enum.find(elements, &(&1.name == :logo))
      assert image != nil
      assert image.source == "/path/to/logo.png"
      assert image.scale_mode == :fit
    end
  end

  describe "Element extraction" do
    test "extracts all element types from report" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      # Verify we have multiple bands with elements
      assert length(report.bands) > 0

      title_band = Enum.find(report.bands, &(&1.type == :title))
      assert title_band != nil
      title_elements = Map.get(title_band, :elements, [])
      assert length(title_elements) > 0

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      assert detail_band != nil
      detail_elements = Map.get(detail_band, :elements, [])
      assert length(detail_elements) > 0

      summary_band = Enum.find(report.bands, &(&1.type == :summary))
      assert summary_band != nil
      summary_elements = Map.get(summary_band, :elements, [])
      assert length(summary_elements) > 0
    end
  end

  # Section 1.3 tests - Content Element Updates

  describe "Label element properties" do
    test "parses label with style properties" do
      reports = Info.reports(AshReports.Test.LabelPropertiesDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :styled_label))
      assert label != nil
      assert label.text == "Styled Text"
      assert label.style[:font_size] == 14
      assert label.style[:font_weight] == :bold
      assert label.style[:color] == "#333333"
      assert label.align == :center
      assert label.padding == "5pt"
      assert label.margin == "3pt"
    end

    test "parses label with position properties" do
      reports = Info.reports(AshReports.Test.LabelPropertiesDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :positioned_label))
      assert label != nil
      assert label.position[:x] == 10
      assert label.position[:y] == 20
      assert label.position[:width] == 100
      assert label.position[:height] == 30
    end

    test "parses label with variable interpolation syntax" do
      reports = Info.reports(AshReports.Test.LabelPropertiesDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :interpolated_label))
      assert label != nil
      assert label.text == "Total: [total_amount]"
    end

    test "label does not have column property" do
      reports = Info.reports(AshReports.Test.LabelPropertiesDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :styled_label))
      assert label != nil
      refute Map.has_key?(label, :column)
    end
  end

  describe "Field element formats" do
    test "parses field with currency format" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :currency_field))
      assert field != nil
      assert field.source == :total_amount
      assert field.format == :currency
      assert field.decimal_places == 2
    end

    test "parses field with number format" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :number_field))
      assert field != nil
      assert field.format == :number
      assert field.decimal_places == 0
    end

    test "parses field with date format" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :date_field))
      assert field != nil
      assert field.format == :date
    end

    test "parses field with datetime format" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :datetime_field))
      assert field != nil
      assert field.format == :datetime
    end

    test "parses field with percent format" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :percent_field))
      assert field != nil
      assert field.format == :percent
      assert field.decimal_places == 1
    end

    test "parses field with style properties" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :styled_field))
      assert field != nil
      assert field.style[:font_size] == 12
      assert field.style[:color] == "#000000"
      assert field.align == :left
    end

    test "field does not have column property" do
      reports = Info.reports(AshReports.Test.FieldFormatsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :currency_field))
      assert field != nil
      refute Map.has_key?(field, :column)
    end
  end

  describe "Short form syntax" do
    test "parses label with short form syntax" do
      reports = Info.reports(AshReports.Test.ShortFormSyntaxDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :short_label))
      assert label != nil
      assert label.text == "Quick Label"
    end

    test "parses field with short form syntax" do
      reports = Info.reports(AshReports.Test.ShortFormSyntaxDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :short_field))
      assert field != nil
      assert field.source == :name
    end
  end
end
