defmodule AshReports.Entities.BandTest do
  @moduledoc """
  Tests for AshReports.Band entity structure and validation.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Band, Info}

  describe "Band struct creation" do
    test "creates band with required fields" do
      band = %Band{
        name: :test_band,
        type: :detail
      }

      assert band.name == :test_band
      assert band.type == :detail
    end

    test "creates band with all optional fields" do
      band = %Band{
        name: :test_band,
        type: :group_header,
        group_level: 1,
        detail_number: 1,
        target_alias: {:field, :customer},
        on_entry: {:set_variable, :current_group},
        on_exit: {:reset_variable, :current_group},
        height: 100,
        can_grow: true,
        can_shrink: false,
        keep_together: true,
        visible: {:expression, :show_band},
        elements: [],
        bands: []
      }

      assert band.name == :test_band
      assert band.type == :group_header
      assert band.group_level == 1
      assert band.detail_number == 1
      assert band.target_alias == {:field, :customer}
      assert band.on_entry == {:set_variable, :current_group}
      assert band.on_exit == {:reset_variable, :current_group}
      assert band.height == 100
      assert band.can_grow == true
      assert band.can_shrink == false
      assert band.keep_together == true
      assert band.visible == {:expression, :show_band}
      assert band.elements == []
      assert band.bands == []
    end
  end

  describe "Band type validation" do
    test "validates all supported band types" do
      reports = Info.reports(AshReports.Test.BandsDomain)
      report = hd(reports)

      band_types = Enum.map(report.bands, & &1.type)

      # All valid band types should be present
      assert :title in band_types
      assert :page_header in band_types
      assert :detail in band_types
      assert :page_footer in band_types
      assert :summary in band_types
    end

    test "parses band with all options" do
      reports = Info.reports(AshReports.Test.BandOptionsDomain)
      report = hd(reports)

      band = hd(report.bands)
      assert band.type == :detail
      assert band.group_level == 1
      assert band.detail_number == 1
      assert band.height == 100
      assert band.can_grow == true
      assert band.can_shrink == false
      assert band.keep_together == true
      assert band.visible == true
    end
  end

  describe "Band element relationships" do
    test "can contain label elements" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      title_band = Enum.find(report.bands, &(&1.type == :title))
      elements = Map.get(title_band, :elements, [])

      assert length(elements) > 0

      label = Enum.find(elements, &(&1.name == :title_label))
      assert label != nil
      assert label.text == "Report Title"
    end

    test "can contain field elements" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :customer_name))
      assert field != nil
      assert field.source == :name
    end

    test "can contain expression elements" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      expression = Enum.find(elements, &(&1.name == :computed_value))
      assert expression != nil
      assert expression.expression == :id
    end

    test "can contain aggregate elements" do
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

    test "can contain line elements" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      line = Enum.find(elements, &(&1.name == :separator))
      assert line != nil
      assert line.orientation == :horizontal
      assert line.thickness == 2
    end

    test "can contain box elements" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      box = Enum.find(elements, &(&1.name == :border_box))
      assert box != nil
    end

    test "can contain image elements" do
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

  describe "Band extraction" do
    test "extracts band entities correctly" do
      reports = Info.reports(AshReports.Test.BandsDomain)
      report = hd(reports)

      bands = report.bands
      assert length(bands) == 5

      title_band = Enum.find(bands, &(&1.type == :title))
      assert title_band != nil

      detail_band = Enum.find(bands, &(&1.type == :detail))
      assert detail_band != nil
    end

    test "sets default values correctly" do
      reports = Info.reports(AshReports.Test.MinimalDomain)
      report = hd(reports)

      band = hd(report.bands)
      # Default values from DSL definition
      assert band.can_grow == true
      assert band.can_shrink == false
      assert band.visible == true
    end
  end
end
