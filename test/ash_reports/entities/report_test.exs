defmodule AshReports.Entities.ReportTest do
  @moduledoc """
  Tests for AshReports.Report entity structure and validation.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Report, Info}

  describe "Report struct creation" do
    test "creates report with required fields" do
      report = %Report{
        name: :test_report,
        driving_resource: AshReports.Test.Customer
      }

      assert report.name == :test_report
      assert report.driving_resource == AshReports.Test.Customer
    end

    test "creates report with all optional fields" do
      report = %Report{
        name: :test_report,
        title: "Test Report",
        description: "A test report",
        driving_resource: AshReports.Test.Customer,
        scope: {:filter, :active},
        permissions: [:read_reports],
        formats: [:html, :pdf],
        parameters: [],
        variables: [],
        groups: [],
        bands: []
      }

      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.description == "A test report"
      assert report.driving_resource == AshReports.Test.Customer
      assert report.scope == {:filter, :active}
      assert report.permissions == [:read_reports]
      assert report.formats == [:html, :pdf]
      assert report.parameters == []
      assert report.variables == []
      assert report.groups == []
      assert report.bands == []
    end

    test "sets default values for optional fields" do
      report = %Report{
        name: :test_report,
        driving_resource: AshReports.Test.Customer
      }

      # Test that nil/empty defaults are handled properly
      assert is_nil(report.title) || report.title == ""
      assert is_nil(report.description) || report.description == ""
      # Lists may be nil or empty by default in struct
      assert is_nil(report.parameters) || is_list(report.parameters)
      assert is_nil(report.variables) || is_list(report.variables)
      assert is_nil(report.groups) || is_list(report.groups)
      assert is_nil(report.bands) || is_list(report.bands)
    end
  end

  describe "Report field validation" do
    test "parses minimal valid report" do
      reports = Info.reports(AshReports.Test.MinimalDomain)

      assert length(reports) == 1
      report = hd(reports)
      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.driving_resource == AshReports.Test.Customer
    end

    test "parses complete report with all fields" do
      reports = Info.reports(AshReports.Test.CompleteReportDomain)
      report = hd(reports)

      assert report.name == :complete_report
      assert report.title == "Complete Report"
      assert report.description == "A complete report with all fields"
      assert report.driving_resource == AshReports.Test.Customer
      assert report.formats == [:html, :pdf, :json]
      assert report.permissions == [:view_reports, :export_data]
    end

    test "sets default values correctly" do
      reports = Info.reports(AshReports.Test.MinimalDomain)
      report = hd(reports)

      assert report.formats == [:html]
      assert report.permissions == []
    end
  end

  describe "Report entity relationships" do
    test "report contains parameters" do
      reports = Info.reports(AshReports.Test.ParametersDomain)
      report = hd(reports)

      parameters = report.parameters
      assert length(parameters) >= 1

      start_date_param = Enum.find(parameters, &(&1.name == :start_date))
      assert start_date_param.type == :date
    end

    test "report contains bands" do
      reports = Info.reports(AshReports.Test.BandsDomain)
      report = hd(reports)

      bands = report.bands
      assert length(bands) == 5

      assert Enum.any?(bands, &(&1.type == :title))
      assert Enum.any?(bands, &(&1.type == :detail))
      assert Enum.any?(bands, &(&1.type == :summary))
    end

    test "report contains variables" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      variables = report.variables
      assert length(variables) >= 1

      total_count = Enum.find(variables, &(&1.name == :total_count))
      assert total_count.type == :count
    end

    test "report contains groups" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      groups = report.groups
      assert length(groups) >= 1

      by_region = Enum.find(groups, &(&1.name == :by_region))
      assert by_region.level == 1
    end
  end

  describe "Report extraction" do
    test "extracts reports correctly" do
      reports = Info.reports(AshReports.Test.MultiReportDomain)

      assert length(reports) == 2
      assert Enum.any?(reports, &(&1.name == :first_report))
      assert Enum.any?(reports, &(&1.name == :second_report))
    end
  end
end
