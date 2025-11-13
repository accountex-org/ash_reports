defmodule AshReports.Typst.DSLGeneratorTest do
  use ExUnit.Case, async: true

  alias AshReports.{Band, Report}
  alias AshReports.Element.{Field, Label}
  alias AshReports.Typst.{BinaryWrapper, DSLGenerator}

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

  describe "integration tests with Typst compiler" do
    test "generated template compiles to valid PDF with basic report" do
      report = %Report{
        name: :simple_report,
        title: "Simple Test Report",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{
                name: :title_label,
                text: "Test Report Title"
              }
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      # Ensure PDF is reasonable size (not empty)
      assert byte_size(pdf) > 1000
    end

    test "generated template compiles with detail bands and data" do
      report = %Report{
        name: :customer_report,
        title: "Customer Report",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{name: :title, text: "Customer List"}
            ]
          },
          %Band{
            name: :detail_band,
            type: :detail,
            elements: [
              %Field{name: :customer_name, source: {:resource, :name}},
              %Field{name: :customer_email, source: {:resource, :email}}
            ]
          }
        ]
      }

      # Mock RenderContext with sample data
      mock_context = %{
        records: [
          %{id: 1, name: "John Doe", email: "john@example.com"},
          %{id: 2, name: "Jane Smith", email: "jane@example.com"}
        ]
      }

      assert {:ok, template} =
               DSLGenerator.generate_template(report, context: mock_context)

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      assert byte_size(pdf) > 1000
    end

    test "generated template compiles with default page footer using context" do
      report = %Report{
        name: :footer_report,
        title: "Report with Default Footer",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{name: :title, text: "Footer Test"}
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)

      # Verify the context wrapper is present for counter.final()
      assert String.contains?(template, "context [Page #counter(page)")

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
    end

    test "generated template compiles with custom page header and footer" do
      report = %Report{
        name: :custom_header_footer,
        title: "Custom Headers Test",
        bands: [
          %Band{
            name: :page_header,
            type: :page_header,
            elements: [
              %Label{name: :header, text: "Company Name - Confidential"}
            ]
          },
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{name: :title, text: "Annual Report"}
            ]
          },
          %Band{
            name: :page_footer,
            type: :page_footer,
            elements: [
              %Label{name: :footer, text: "Copyright 2025"}
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      assert byte_size(pdf) > 1000
    end

    test "generated template compiles with for loop over records" do
      report = %Report{
        name: :loop_test,
        title: "Loop Test",
        bands: [
          %Band{
            name: :detail_band,
            type: :detail,
            elements: [
              %Label{name: :label, text: "Item: "},
              %Field{name: :name, source: {:resource, :name}}
            ]
          }
        ]
      }

      mock_context = %{
        records: [
          %{name: "Item 1"},
          %{name: "Item 2"},
          %{name: "Item 3"}
        ]
      }

      assert {:ok, template} =
               DSLGenerator.generate_template(report, context: mock_context)

      # Verify correct for loop syntax (no # prefix, uses {})
      assert String.contains?(template, "for record in data.records {")
      refute String.contains?(template, "#for record in data.records [")

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
    end

    test "generated template compiles with multiple band types" do
      report = %Report{
        name: :full_report,
        title: "Complete Report",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{name: :title, text: "Sales Summary"}
            ]
          },
          %Band{
            name: :detail_band,
            type: :detail,
            elements: [
              %Field{name: :product, source: {:resource, :product_name}},
              %Field{name: :amount, source: {:resource, :amount}}
            ]
          },
          %Band{
            name: :summary_band,
            type: :summary,
            elements: [
              %Label{name: :summary, text: "End of Report"}
            ]
          }
        ]
      }

      mock_context = %{
        records: [
          %{product_name: "Widget A", amount: 100},
          %{product_name: "Widget B", amount: 250}
        ]
      }

      assert {:ok, template} =
               DSLGenerator.generate_template(report, context: mock_context)

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      assert byte_size(pdf) > 1500
    end
  end
end
