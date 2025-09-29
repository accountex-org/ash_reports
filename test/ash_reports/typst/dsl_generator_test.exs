defmodule AshReports.Typst.DSLGeneratorTest do
  use ExUnit.Case, async: true

  alias AshReports.{Report, Band}
  alias AshReports.Typst.DSLGenerator
  alias AshReports.Element.{Field, Label}

  describe "generate_template/2" do
    test "generates a basic template for a simple report" do
      report = %Report{
        name: :test_report,
        title: "Test Report",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{
                name: :title_label,
                text: "Simple Test Report"
              }
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert is_binary(template)
      assert String.contains?(template, "#let test_report(data, config: (:)) = {")
      assert String.contains?(template, "Simple Test Report")
    end

    test "handles empty report with minimal structure" do
      report = %Report{
        name: :empty_report,
        title: "Empty Report",
        bands: []
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert String.contains?(template, "#let empty_report(data, config: (:)) = {")
      assert String.contains?(template, "Empty Report")
    end

    test "includes debug information when debug option is enabled" do
      report = %Report{
        name: :debug_report,
        title: "Debug Test",
        driving_resource: TestResource,
        bands: []
      }

      assert {:ok, template} = DSLGenerator.generate_template(report, debug: true)
      assert String.contains?(template, "// Report Debug Information")
      assert String.contains?(template, "// Name: debug_report")
      assert String.contains?(template, "// Driving Resource: TestResource")
    end

    test "handles invalid report gracefully" do
      invalid_report = nil

      assert {:error, {:generation_failed, _}} = DSLGenerator.generate_template(invalid_report)
    end
  end

  describe "generate_band_section/2" do
    test "generates title band content" do
      band = %Band{
        name: :title_band,
        type: :title,
        elements: [
          %Label{
            name: :title_label,
            text: "Sales Report"
          }
        ]
      }

      context = %{debug: false, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      assert String.contains?(section, "Sales Report")
    end

    test "generates detail band with field element" do
      band = %Band{
        name: :detail_band,
        type: :detail,
        elements: [
          %Field{
            name: :customer_field,
            source: {:resource, :customer_name}
          }
        ]
      }

      context = %{debug: false, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      assert String.contains?(section, "#record.customer_name")
    end

    test "generates empty band with default content" do
      band = %Band{
        name: :empty_detail,
        type: :detail,
        elements: []
      }

      context = %{debug: false, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      assert String.contains?(section, "[Record: #record]")
    end

    test "includes debug comments when debug is enabled" do
      band = %Band{
        name: :debug_band,
        type: :title,
        elements: []
      }

      context = %{debug: true, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      assert String.contains?(section, "// title band: debug_band")
    end
  end

  describe "generate_element/2" do
    test "generates field element with resource source" do
      element = %Field{
        name: :test_field,
        source: {:resource, :customer_name}
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(element, context)
      assert result == "[#record.customer_name]"
    end

    test "generates field element with parameter source" do
      element = %Field{
        name: :param_field,
        source: {:parameter, :start_date}
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(element, context)
      assert result == "[#config.start_date]"
    end

    test "generates label element with static text" do
      element = %Label{
        name: :test_label,
        text: "Customer Information"
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(element, context)
      assert result == "[Customer Information]"
    end

    test "handles unknown element type gracefully" do
      # Create a mock element struct that doesn't match known types
      element = %{__struct__: Some.Unknown.Element, name: :unknown}
      context = %{debug: false}

      result = DSLGenerator.generate_element(element, context)
      assert String.contains?(result, "// Unknown element:")
    end
  end

  describe "complex report generation" do
    test "generates report with multiple band types" do
      report = %Report{
        name: :complex_report,
        title: "Complex Sales Report",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{name: :title_label, text: "Sales Report"}
            ]
          },
          %Band{
            name: :detail_band,
            type: :detail,
            elements: [
              %Field{name: :customer_field, source: {:resource, :customer_name}},
              %Field{name: :amount_field, source: {:resource, :amount}}
            ]
          },
          %Band{
            name: :summary_band,
            type: :summary,
            elements: [
              %Label{name: :summary_label, text: "Total Sales:"}
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)

      # Check that all major sections are present
      assert String.contains?(template, "#let complex_report(data, config: (:)) = {")
      assert String.contains?(template, "// Title Section")
      assert String.contains?(template, "// Data Processing Section")
      assert String.contains?(template, "// Summary Section")
      assert String.contains?(template, "Sales Report")
      assert String.contains?(template, "#record.customer_name")
      assert String.contains?(template, "#record.amount")
      assert String.contains?(template, "Total Sales:")
    end

    test "handles report with page headers and footers" do
      report = %Report{
        name: :page_report,
        title: "Report with Headers",
        bands: [
          %Band{
            name: :page_header,
            type: :page_header,
            elements: [
              %Label{name: :header_label, text: "Company Header"}
            ]
          },
          %Band{
            name: :detail_band,
            type: :detail,
            elements: []
          },
          %Band{
            name: :page_footer,
            type: :page_footer,
            elements: [
              %Label{name: :footer_label, text: "Page Footer"}
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert String.contains?(template, "header: [")
      assert String.contains?(template, "Company Header")
      assert String.contains?(template, "footer: [")
      assert String.contains?(template, "Page Footer")
    end
  end
end