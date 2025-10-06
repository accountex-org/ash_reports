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
end
