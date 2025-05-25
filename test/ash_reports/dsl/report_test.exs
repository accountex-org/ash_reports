defmodule AshReports.Dsl.ReportTest do
  use ExUnit.Case, async: true
  
  alias AshReports.Dsl.Report
  alias AshReports.Dsl.Band
  
  describe "new/1" do
    test "creates a report with default values" do
      report = Report.new()
      
      assert report.formats == [:html]
      assert report.parameters == []
      assert report.bands == []
      assert report.page_size == :a4
      assert report.orientation == :portrait
      assert report.margins == %{top: 0.5, bottom: 0.5, left: 0.5, right: 0.5}
      assert report.generated? == false
    end
    
    test "creates a report with custom values" do
      report = Report.new(
        name: :monthly_sales,
        title: "Monthly Sales Report",
        formats: [:pdf, :html],
        page_size: :letter
      )
      
      assert report.name == :monthly_sales
      assert report.title == "Monthly Sales Report"
      assert report.formats == [:pdf, :html]
      assert report.page_size == :letter
    end
  end
  
  describe "validate/1" do
    test "validates a valid report" do
      report = Report.new(name: :test_report, title: "Test Report")
      assert {:ok, ^report} = Report.validate(report)
    end
    
    test "requires a name" do
      report = Report.new(title: "Test Report")
      assert {:error, "Report name is required"} = Report.validate(report)
    end
    
    test "requires name to be an atom" do
      report = struct(Report, name: "not_an_atom", title: "Test")
      assert {:error, "Report name must be an atom"} = Report.validate(report)
    end
    
    test "requires a title" do
      report = Report.new(name: :test_report)
      assert {:error, "Report title is required"} = Report.validate(report)
    end
    
    test "requires title to be a string" do
      report = struct(Report, name: :test, title: :not_a_string)
      assert {:error, "Report title must be a string"} = Report.validate(report)
    end
    
    test "requires at least one format" do
      report = Report.new(name: :test, title: "Test", formats: [])
      assert {:error, "At least one format is required"} = Report.validate(report)
    end
    
    test "validates format types" do
      report = Report.new(name: :test, title: "Test", formats: [:html, :invalid])
      assert {:error, message} = Report.validate(report)
      assert message =~ "Invalid formats: [:invalid]"
    end
    
    test "validates page size" do
      report = struct(Report, Report.default_values() |> Keyword.merge(name: :test, title: "Test", page_size: :invalid))
      assert {:error, "Invalid page size"} = Report.validate(report)
    end
    
    test "validates orientation" do
      report = struct(Report, Report.default_values() |> Keyword.merge(name: :test, title: "Test", orientation: :invalid))
      assert {:error, "Orientation must be :portrait or :landscape"} = Report.validate(report)
    end
  end
  
  describe "band_types/0" do
    test "returns all band types in order" do
      expected = [:title, :page_header, :column_header, :group_header, :detail, 
                  :group_footer, :column_footer, :page_footer, :summary]
      assert Report.band_types() == expected
    end
  end
  
  describe "single_occurrence_band?/1" do
    test "returns true for title and summary bands" do
      assert Report.single_occurrence_band?(:title)
      assert Report.single_occurrence_band?(:summary)
    end
    
    test "returns false for other band types" do
      refute Report.single_occurrence_band?(:page_header)
      refute Report.single_occurrence_band?(:detail)
      refute Report.single_occurrence_band?(:group_header)
    end
  end
  
  describe "get_bands_by_type/2" do
    test "returns bands of the specified type" do
      band1 = %Band{type: :title, name: :title_band}
      band2 = %Band{type: :detail, name: :detail_band1}
      band3 = %Band{type: :detail, name: :detail_band2}
      
      report = %Report{bands: [band1, band2, band3]}
      
      assert Report.get_bands_by_type(report, :detail) == [band2, band3]
      assert Report.get_bands_by_type(report, :title) == [band1]
      assert Report.get_bands_by_type(report, :summary) == []
    end
  end
  
  describe "add_band/2" do
    test "adds a band to the report" do
      report = Report.new(name: :test, title: "Test")
      band = %Band{type: :detail, name: :detail_band}
      
      assert {:ok, updated_report} = Report.add_band(report, band)
      assert updated_report.bands == [band]
    end
    
    test "prevents adding multiple title bands" do
      report = Report.new(name: :test, title: "Test")
      title_band1 = %Band{type: :title, name: :title1}
      title_band2 = %Band{type: :title, name: :title2}
      
      assert {:ok, report} = Report.add_band(report, title_band1)
      assert {:error, "Report already has a title band"} = Report.add_band(report, title_band2)
    end
    
    test "prevents adding multiple summary bands" do
      report = Report.new(name: :test, title: "Test")
      summary_band1 = %Band{type: :summary, name: :summary1}
      summary_band2 = %Band{type: :summary, name: :summary2}
      
      assert {:ok, report} = Report.add_band(report, summary_band1)
      assert {:error, "Report already has a summary band"} = Report.add_band(report, summary_band2)
    end
    
    test "allows multiple bands of other types" do
      report = Report.new(name: :test, title: "Test")
      detail_band1 = %Band{type: :detail, name: :detail1}
      detail_band2 = %Band{type: :detail, name: :detail2}
      
      assert {:ok, report} = Report.add_band(report, detail_band1)
      assert {:ok, report} = Report.add_band(report, detail_band2)
      assert length(report.bands) == 2
    end
  end
  
  describe "parameter structure" do
    test "parameters have the expected structure" do
      param = %{
        name: :date_range,
        type: :date_range,
        required?: true,
        default: nil,
        description: "Date range for the report"
      }
      
      report = Report.new(name: :test, title: "Test", parameters: [param])
      
      assert [stored_param] = report.parameters
      assert stored_param.name == :date_range
      assert stored_param.type == :date_range
      assert stored_param.required? == true
    end
  end
end