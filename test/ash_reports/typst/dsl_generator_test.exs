defmodule AshReports.Typst.DSLGeneratorTest do
  use ExUnit.Case, async: true

  alias AshReports.{Band, Report}
  alias AshReports.Element.{Field, Label}
  alias AshReports.Layout.Grid
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
            grids: [
              %Grid{
                name: :title_grid,
                columns: 1,
                elements: [
                  %Label{
                    name: :title_label,
                    text: "Simple Test Report"
                  }
                ]
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
    test "generates title band with grid content" do
      band = %Band{
        name: :title_band,
        type: :title,
        grids: [
          %Grid{
            name: :title_grid,
            columns: 1,
            elements: [
              %Label{
                name: :title_label,
                text: "Sales Report"
              }
            ]
          }
        ]
      }

      context = %{debug: false, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      assert String.contains?(section, "Sales Report")
    end

    test "generates detail band with grid containing field" do
      band = %Band{
        name: :detail_band,
        type: :detail,
        grids: [
          %Grid{
            name: :detail_grid,
            columns: 1,
            elements: [
              %Field{
                name: :customer_field,
                source: {:resource, :customer_name}
              }
            ]
          }
        ]
      }

      context = %{debug: false, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      # Grid renderer should include the field content
      assert String.contains?(section, "grid")
    end

    test "generates empty band comment when no layout primitives" do
      band = %Band{
        name: :empty_detail,
        type: :detail,
        grids: [],
        tables: [],
        stacks: []
      }

      context = %{debug: false, report: %Report{}}

      section = DSLGenerator.generate_band_section(band, context)
      assert String.contains?(section, "// Empty band: empty_detail")
    end

    test "includes debug comments when debug is enabled" do
      band = %Band{
        name: :debug_band,
        type: :title,
        grids: []
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
    test "generates report with multiple band types using grids" do
      report = %Report{
        name: :complex_report,
        title: "Complex Sales Report",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            grids: [
              %Grid{
                name: :title_grid,
                columns: 1,
                elements: [%Label{name: :title_label, text: "Sales Report"}]
              }
            ]
          },
          %Band{
            name: :detail_band,
            type: :detail,
            grids: [
              %Grid{
                name: :detail_grid,
                columns: 2,
                elements: [
                  %Field{name: :customer_field, source: {:resource, :customer_name}},
                  %Field{name: :amount_field, source: {:resource, :amount}}
                ]
              }
            ]
          },
          %Band{
            name: :summary_band,
            type: :summary,
            grids: [
              %Grid{
                name: :summary_grid,
                columns: 1,
                elements: [%Label{name: :summary_label, text: "Total Sales:"}]
              }
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
      assert String.contains?(template, "Total Sales:")
    end

    @tag :skip
    @tag :legacy_format
    test "handles report with page headers and footers" do
      # TODO: Migrate to layout primitives format
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

  # Legacy element-based tests - skipped until migrated to layout primitives
  describe "integration tests with Typst compiler" do
    @describetag :skip
    @describetag :legacy_format

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

  describe "element positioning and styling" do
    test "generates positioned label element" do
      label = %Label{
        name: :positioned_label,
        text: "Positioned Title",
        position: [x: 100, y: 50]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(dx: 100pt, dy: 50pt)")
      assert String.contains?(result, "Positioned Title")
    end

    test "generates styled label element" do
      label = %Label{
        name: :styled_label,
        text: "Styled Title",
        style: [font_size: 18, color: "#2F5597", font_weight: "bold"]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "text(")
      assert String.contains?(result, "size: 18pt")
      assert String.contains?(result, "fill: rgb(\"2F5597\")")
      assert String.contains?(result, "weight: \"bold\"")
      assert String.contains?(result, "Styled Title")
    end

    test "generates label with both position and style" do
      label = %Label{
        name: :full_label,
        text: "Full Featured",
        position: [x: 200, y: 100],
        style: [font_size: 24, color: "#FF5733", font_weight: "bold"]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      # Position wrapper should be outermost
      assert String.contains?(result, "place(dx: 200pt, dy: 100pt)")
      # Style wrapper should be inner
      assert String.contains?(result, "text(")
      assert String.contains?(result, "size: 24pt")
      assert String.contains?(result, "fill: rgb(\"FF5733\")")
      assert String.contains?(result, "Full Featured")
    end

    test "generates positioned field element" do
      field = %Field{
        name: :positioned_field,
        source: {:resource, :customer_name},
        position: [x: 50, y: 25]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(field, context)
      assert String.contains?(result, "place(dx: 50pt, dy: 25pt)")
      assert String.contains?(result, "#record.customer_name")
    end

    test "generates styled field element" do
      field = %Field{
        name: :styled_field,
        source: {:resource, :amount},
        style: [font_size: 14, color: "#10B981", alignment: :right]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(field, context)
      assert String.contains?(result, "text(")
      assert String.contains?(result, "size: 14pt")
      assert String.contains?(result, "fill: rgb(\"10B981\")")
      assert String.contains?(result, "align: right")
      assert String.contains?(result, "#record.amount")
    end

    test "generates element with no position or style (backward compatibility)" do
      label = %Label{
        name: :plain_label,
        text: "Plain Text"
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      # Should only contain the text, no wrappers
      assert result == "[Plain Text]"
      refute String.contains?(result, "place")
      refute String.contains?(result, "text(")
    end

    test "generates element with empty position list" do
      label = %Label{
        name: :empty_pos_label,
        text: "No Position",
        position: []
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert result == "[No Position]"
      refute String.contains?(result, "place")
    end

    test "generates element with empty style list" do
      label = %Label{
        name: :empty_style_label,
        text: "No Style",
        style: []
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert result == "[No Style]"
      refute String.contains?(result, "text(")
    end

    test "style with font family" do
      label = %Label{
        name: :font_label,
        text: "Custom Font",
        style: [font: "Liberation Sans"]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "font: \"Liberation Sans\"")
    end

    test "style with alignment options" do
      for {alignment, expected} <- [
            {:left, "align: left"},
            {:center, "align: center"},
            {:right, "align: right"},
            {:justify, "align: justify"}
          ] do
        label = %Label{
          name: :align_label,
          text: "Aligned",
          style: [alignment: alignment]
        }

        context = %{debug: false}

        result = DSLGenerator.generate_element(label, context)
        assert String.contains?(result, expected)
      end
    end

    test "generates element with single alignment value" do
      label = %Label{
        name: :centered_label,
        text: "Centered",
        position: [align: :center]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(center)[Centered]")
    end

    test "generates element with combined alignments (vertical + horizontal)" do
      label = %Label{
        name: :top_center_label,
        text: "Top Center",
        position: [align: [:top, :center]]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(top + center)[Top Center]")
    end

    test "generates element with horizon (vertical center) alignment" do
      label = %Label{
        name: :vcenter_label,
        text: "Vertically Centered",
        position: [align: [:horizon, :center]]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(horizon + center)[Vertically Centered]")
    end

    test "generates element with bottom-right alignment" do
      label = %Label{
        name: :bottom_right_label,
        text: "Bottom Right",
        position: [align: [:bottom, :right]]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(bottom + right)[Bottom Right]")
    end

    test "generates element with top alignment only" do
      label = %Label{
        name: :top_label,
        text: "Top",
        position: [align: :top]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(top)[Top]")
    end

    test "generates element with left alignment only" do
      label = %Label{
        name: :left_label,
        text: "Left",
        position: [align: :left]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      assert String.contains?(result, "place(left)[Left]")
    end

    test "alignment-based position works with styling" do
      label = %Label{
        name: :aligned_styled_label,
        text: "Aligned and Styled",
        position: [align: [:top, :center]],
        style: [font_size: 20, color: "#2F5597"]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      # Position wrapper should be outermost
      assert String.contains?(result, "place(top + center)")
      # Style wrapper should be inner
      assert String.contains?(result, "text(size: 20pt")
      assert String.contains?(result, "fill: rgb(\"2F5597\")")
    end

    test "ignores invalid alignment values" do
      label = %Label{
        name: :invalid_align_label,
        text: "Invalid",
        position: [align: [:invalid_value, :center]]
      }

      context = %{debug: false}

      result = DSLGenerator.generate_element(label, context)
      # Should only include valid alignment (center), invalid ones filtered out
      assert String.contains?(result, "place(center)[Invalid]")
    end

    test "supports all valid alignment atoms" do
      for alignment <- [:center, :top, :bottom, :horizon, :left, :right, :start, :end] do
        label = %Label{
          name: :test_label,
          text: "Test",
          position: [align: alignment]
        }

        context = %{debug: false}

        result = DSLGenerator.generate_element(label, context)
        typst_alignment = to_string(alignment)
        assert String.contains?(result, "place(#{typst_alignment})")
      end
    end
  end

  # Legacy element-based tests - skipped until migrated to layout primitives
  describe "integration tests with positioned and styled elements" do
    @describetag :skip
    @describetag :legacy_format

    test "generated template with positioned elements compiles to PDF" do
      report = %Report{
        name: :positioned_report,
        title: "Positioned Elements Test",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{
                name: :title_label,
                text: "Positioned Report",
                position: [x: 100, y: 50],
                style: [font_size: 20, font_weight: "bold"]
              }
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert String.contains?(template, "place(dx: 100pt, dy: 50pt)")
      assert String.contains?(template, "text(")

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      assert byte_size(pdf) > 1000
    end

    test "generated template with styled elements compiles to PDF" do
      report = %Report{
        name: :styled_report,
        title: "Styled Elements Test",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{
                name: :title_label,
                text: "Styled Report",
                style: [font_size: 22, color: "#4472C4", font_weight: "bold"]
              }
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      assert String.contains?(template, "text(")
      assert String.contains?(template, "size: 22pt")
      assert String.contains?(template, "fill: rgb(\"4472C4\")")

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      assert byte_size(pdf) > 1000
    end

    test "generated template with mixed positioned and styled elements compiles to PDF" do
      report = %Report{
        name: :mixed_report,
        title: "Mixed Features Test",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              %Label{
                name: :title_label,
                text: "Main Title",
                position: [x: 150, y: 75],
                style: [font_size: 24, color: "#2F5597", font_weight: "bold"]
              }
            ]
          },
          %Band{
            name: :detail_band,
            type: :detail,
            elements: [
              %Field{
                name: :customer_field,
                source: {:resource, :name},
                style: [font_size: 12, color: "#000000"]
              }
            ]
          }
        ]
      }

      mock_context = %{
        records: [
          %{name: "Customer A"},
          %{name: "Customer B"}
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report, context: mock_context)
      assert String.contains?(template, "place(dx: 150pt, dy: 75pt)")
      assert String.contains?(template, "text(")
      assert String.contains?(template, "size: 24pt")

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
      assert byte_size(pdf) > 1000
    end

    test "positioned and styled elements don't break existing functionality" do
      report = %Report{
        name: :compatibility_report,
        title: "Backward Compatibility Test",
        bands: [
          %Band{
            name: :title_band,
            type: :title,
            elements: [
              # Old-style element without position/style
              %Label{name: :old_label, text: "Old Style"},
              # New-style element with position
              %Label{
                name: :new_label,
                text: "New Style",
                position: [x: 200, y: 0],
                style: [font_size: 16]
              }
            ]
          }
        ]
      }

      assert {:ok, template} = DSLGenerator.generate_template(report)
      # Old style should not have wrappers
      assert String.contains?(template, "[Old Style]")
      # New style should have wrappers
      assert String.contains?(template, "place(dx: 200pt")
      assert String.contains?(template, "[New Style]")

      assert {:ok, pdf} = BinaryWrapper.compile(template, format: :pdf)
      assert is_binary(pdf)
      assert <<"%PDF", _rest::binary>> = pdf
    end
  end
end
