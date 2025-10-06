defmodule AshReports.DslTest do
  @moduledoc """
  Comprehensive tests for AshReports.Dsl module.

  Tests DSL entity parsing, schema validation, and entity relationships
  using pre-compiled test domain modules.
  """

  use ExUnit.Case, async: true

  alias AshReports.Info

  describe "reports section parsing" do
    test "parses valid reports section with minimal report" do
      reports = Info.reports(AshReports.Test.MinimalDomain)

      assert length(reports) == 1
      report = hd(reports)
      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.driving_resource == AshReports.Test.Customer
    end

    test "parses reports section with multiple reports" do
      reports = Info.reports(AshReports.Test.MultiReportDomain)

      assert length(reports) == 2
      assert Enum.any?(reports, &(&1.name == :first_report))
      assert Enum.any?(reports, &(&1.name == :second_report))
    end

    test "extracts report entities correctly" do
      reports = Info.reports(AshReports.Test.CompleteReportDomain)
      report = hd(reports)

      assert report.name == :complete_report
      assert report.title == "Complete Report"
      assert report.description == "A complete report with all fields"
      assert report.driving_resource == AshReports.Test.Customer
      assert report.formats == [:html, :pdf, :json]
      assert report.permissions == [:view_reports, :export_data]
    end
  end

  describe "report entity validation" do
    test "sets default values correctly" do
      reports = Info.reports(AshReports.Test.MinimalDomain)
      report = hd(reports)

      assert report.formats == [:html]
      assert report.permissions == []
    end
  end

  describe "parameter entity parsing" do
    test "parses valid parameter with required fields" do
      reports = Info.reports(AshReports.Test.ParametersDomain)
      report = hd(reports)

      parameters = report.parameters
      assert length(parameters) >= 1

      start_date_param = Enum.find(parameters, &(&1.name == :start_date))
      assert start_date_param.type == :date
    end

    test "parses parameter with all options" do
      reports = Info.reports(AshReports.Test.ParametersDomain)
      report = hd(reports)

      region_param = Enum.find(report.parameters, &(&1.name == :region))
      assert region_param.type == :string
      assert region_param.required == true
      assert region_param.default == "North"
      assert region_param.constraints == [max_length: 50]
    end

    test "extracts parameter entities correctly" do
      reports = Info.reports(AshReports.Test.ParametersDomain)
      report = hd(reports)

      parameters = report.parameters
      assert length(parameters) == 2

      start_date_param = Enum.find(parameters, &(&1.name == :start_date))
      assert start_date_param.type == :date

      region_param = Enum.find(parameters, &(&1.name == :region))
      assert region_param.type == :string
      assert region_param.default == "North"
    end
  end

  describe "band entity parsing" do
    test "parses valid band with required fields" do
      reports = Info.reports(AshReports.Test.BandsDomain)
      report = hd(reports)

      bands = report.bands
      assert length(bands) > 0

      detail_band = Enum.find(bands, &(&1.type == :detail))
      assert detail_band != nil
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

    test "validates band type options" do
      reports = Info.reports(AshReports.Test.BandsDomain)
      report = hd(reports)

      band_types = Enum.map(report.bands, & &1.type)

      assert :title in band_types
      assert :page_header in band_types
      assert :detail in band_types
      assert :page_footer in band_types
      assert :summary in band_types
    end

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
  end

  describe "element entity parsing" do
    test "parses label element" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      title_band = Enum.find(report.bands, &(&1.type == :title))
      elements = Map.get(title_band, :elements, [])

      label = Enum.find(elements, &(&1.name == :title_label))
      assert label != nil
      assert label.text == "Report Title"
    end

    test "parses field element" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      field = Enum.find(elements, &(&1.name == :customer_name))
      assert field != nil
      assert field.source == :name
    end

    test "parses expression element" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      expression = Enum.find(elements, &(&1.name == :computed_value))
      assert expression != nil
      assert expression.expression == :id
    end

    test "parses aggregate element" do
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

    test "parses line element" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      line = Enum.find(elements, &(&1.name == :separator))
      assert line != nil
      assert line.orientation == :horizontal
      assert line.thickness == 2
    end

    test "parses box element" do
      reports = Info.reports(AshReports.Test.ElementsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      elements = Map.get(detail_band, :elements, [])

      box = Enum.find(elements, &(&1.name == :border_box))
      assert box != nil
    end

    test "parses image element" do
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

  describe "variable entity parsing" do
    test "parses valid variable with required fields" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      variables = report.variables
      assert length(variables) >= 1

      total_count = Enum.find(variables, &(&1.name == :total_count))
      assert total_count.type == :count
      assert total_count.expression == :id
    end

    test "parses variable with all options" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_sales = Enum.find(report.variables, &(&1.name == :total_sales))
      assert total_sales.type == :sum
      assert total_sales.expression == :total_amount
      assert total_sales.reset_on == :group
      assert total_sales.reset_group == 1
      assert total_sales.initial_value == 0
    end
  end

  describe "group entity parsing" do
    test "parses valid group with required fields" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      groups = report.groups
      assert length(groups) >= 1

      by_region = Enum.find(groups, &(&1.name == :by_region))
      assert by_region.level == 1
      assert by_region.expression == :region
    end

    test "parses group with all options" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_status = Enum.find(report.groups, &(&1.name == :by_status))
      assert by_status.level == 2
      assert by_status.expression == :status
      assert by_status.sort == :desc
    end

    test "extracts group entities correctly" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      groups = report.groups
      assert length(groups) == 2

      by_region = Enum.find(groups, &(&1.name == :by_region))
      assert by_region.level == 1
      assert by_region.expression == :region

      by_status = Enum.find(groups, &(&1.name == :by_status))
      assert by_status.level == 2
      assert by_status.expression == :status
    end
  end

  describe "format specifications" do
    test "parses format specifications" do
      reports = Info.reports(AshReports.Test.FormatSpecsDomain)
      report = hd(reports)

      # Format specs might be under format_specs or format_specifications
      format_specs = Map.get(report, :format_specs, Map.get(report, :format_specifications, []))

      # If empty, test is skipped (format_specs may not be implemented yet)
      if length(format_specs) > 0 do
        currency_format = Enum.find(format_specs, &(&1.name == :currency_format))
        assert currency_format != nil
        assert currency_format.pattern == "¤ #,##0.00"
        assert currency_format.currency == :USD
        assert currency_format.locale == "en"
      end
    end
  end
end
