defmodule AshReports.ComplexReportScenariosTest do
  @moduledoc """
  Phase 1D: Complex Report Scenarios Testing

  This test module covers comprehensive testing of complex report scenarios
  including multi-band reports with all band types, all element combinations,
  variable and grouping scenarios, and parameter validation edge cases.
  """

  use ExUnit.Case, async: false
  import AshReports.TestHelpers

  describe "multi-band reports with all band types" do
    test "creates report with complete band hierarchy" do
      defmodule CompleteBandHierarchyDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complete_band_hierarchy do
            title("Complete Band Hierarchy Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf])

            groups do
              group(:region, field: [:region], sort: :asc)
              group(:status, field: [:status], sort: :desc)
            end

            bands do
              # Title band - appears once at the beginning
              band :title do
                elements do
                  label("report_title", text: "Complete Band Hierarchy Report")
                  image("company_logo", source: "/assets/company_logo.png")
                  line("title_underline", from: [x: 0, y: 30], to: [x: 600, y: 30])
                  expression("generation_time", expression: expr("Generated: " <> now()))
                end
              end

              # Page header - appears at the top of each page
              band :page_header do
                elements do
                  label("page_title", text: "Customer Analysis")
                  expression("page_number", expression: expr("Page " <> page_number))
                  line("header_line", from: [x: 0, y: 20], to: [x: 600, y: 20])
                end
              end

              # Column header - defines column titles
              band :column_header do
                elements do
                  label("name_header", text: "Customer Name", position: [x: 0, y: 0])
                  label("email_header", text: "Email Address", position: [x: 150, y: 0])
                  label("status_header", text: "Status", position: [x: 300, y: 0])
                  label("credit_header", text: "Credit Limit", position: [x: 400, y: 0])
                  box("header_box", from: [x: 0, y: 0], to: [x: 600, y: 25])
                end
              end

              # Group header level 1 - region grouping
              band :region_group_header, type: :group_header, group_level: 1 do
                elements do
                  label("region_label", text: "Region:")
                  field(:region_value, source: [:region])

                  box("region_highlight",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 25],
                    style: [fill_color: "#e6f3ff", border_width: 1]
                  )

                  expression("region_info",
                    expression: expr("Processing region: " <> region)
                  )
                end

                bands do
                  # Group header level 2 - status grouping
                  band :status_group_header, type: :group_header, group_level: 2 do
                    elements do
                      label("status_label", text: "Status Group:")
                      field(:status_value, source: [:status])
                      line("status_line", from: [x: 20, y: 20], to: [x: 580, y: 20])
                    end

                    bands do
                      # Detail header - precedes detail records
                      band :detail_header do
                        elements do
                          label("detail_intro", text: "Customer Details:")

                          expression("detail_count_preview",
                            expression: expr("Showing customers with status: " <> status)
                          )
                        end
                      end

                      # Detail band - the main data records
                      band :detail do
                        elements do
                          field(:customer_name, source: [:name], position: [x: 0, y: 0])
                          field(:customer_email, source: [:email], position: [x: 150, y: 0])
                          field(:customer_status, source: [:status], position: [x: 300, y: 0])

                          field(:credit_limit,
                            source: [:credit_limit],
                            format: :currency,
                            position: [x: 400, y: 0]
                          )

                          expression(:full_customer_info,
                            expression: expr(name <> " (" <> email <> ") - " <> status),
                            position: [x: 0, y: 15]
                          )

                          line("detail_separator",
                            from: [x: 0, y: 25],
                            to: [x: 600, y: 25],
                            style: [color: "#cccccc", width: 1]
                          )
                        end
                      end

                      # Detail footer - follows detail records
                      band :detail_footer do
                        elements do
                          label("detail_summary", text: "Detail Summary:")
                          aggregate(:detail_record_count, function: :count, source: [:id])

                          expression("detail_info",
                            expression:
                              expr("Processed " <> detail_record_count <> " detail records")
                          )
                        end
                      end
                    end
                  end

                  # Group footer level 2 - status group summary
                  band :status_group_footer, type: :group_footer, group_level: 2 do
                    elements do
                      label("status_summary_label", text: "Status Group Summary:")
                      aggregate(:status_customer_count, function: :count, source: [:id])

                      aggregate(:status_credit_total,
                        function: :sum,
                        source: [:credit_limit],
                        format: :currency
                      )

                      aggregate(:status_credit_average,
                        function: :avg,
                        source: [:credit_limit],
                        format: :currency
                      )

                      expression(:status_summary,
                        expression:
                          expr(
                            "Status " <>
                              status <>
                              ": " <>
                              status_customer_count <>
                              " customers, " <>
                              "Total Credit: " <>
                              status_credit_total <>
                              ", " <>
                              "Average: " <> status_credit_average
                          )
                      )

                      box("status_footer_box",
                        from: [x: 20, y: 0],
                        to: [x: 580, y: 40],
                        style: [fill_color: "#fff2e6", border_width: 1]
                      )
                    end
                  end
                end
              end

              # Group footer level 1 - region summary
              band :region_group_footer, type: :group_footer, group_level: 1 do
                elements do
                  label("region_summary_label", text: "Region Summary:")
                  aggregate(:region_customer_count, function: :count, source: [:id])

                  aggregate(:region_credit_total,
                    function: :sum,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:region_credit_min,
                    function: :min,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:region_credit_max,
                    function: :max,
                    source: [:credit_limit],
                    format: :currency
                  )

                  expression(:region_summary,
                    expression:
                      expr(
                        "Region " <>
                          region <> " Totals: " <> region_customer_count <> " customers"
                      ),
                    position: [x: 0, y: 0]
                  )

                  expression(:region_credit_range,
                    expression:
                      expr("Credit range: " <> region_credit_min <> " to " <> region_credit_max),
                    position: [x: 0, y: 15]
                  )

                  box("region_footer_box",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 50],
                    style: [fill_color: "#f0f8ff", border_width: 2]
                  )

                  line("region_total_line",
                    from: [x: 0, y: 50],
                    to: [x: 600, y: 50],
                    style: [color: "#0066cc", width: 2]
                  )
                end
              end

              # Column footer - appears at the bottom of columns
              band :column_footer do
                elements do
                  label("column_totals_label", text: "Column Totals:")
                  aggregate(:total_customers, function: :count, source: [:id])

                  aggregate(:total_credit,
                    function: :sum,
                    source: [:credit_limit],
                    format: :currency
                  )

                  box("column_footer_box",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 25],
                    style: [fill_color: "#f5f5f5", border_width: 1]
                  )
                end
              end

              # Page footer - appears at the bottom of each page
              band :page_footer do
                elements do
                  expression("page_info",
                    expression: expr("Page " <> page_number <> " of " <> total_pages),
                    position: [x: 0, y: 0]
                  )

                  expression("timestamp",
                    expression: expr("Report generated on " <> format_date(now(), :long)),
                    position: [x: 200, y: 0]
                  )

                  line("footer_line", from: [x: 0, y: 15], to: [x: 600, y: 15])
                end
              end

              # Summary band - final report summary
              band :summary do
                elements do
                  label("report_summary_title", text: "Report Summary")
                  aggregate(:grand_total_customers, function: :count, source: [:id])

                  aggregate(:grand_total_credit,
                    function: :sum,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:grand_average_credit,
                    function: :avg,
                    source: [:credit_limit],
                    format: :currency
                  )

                  expression(:summary_line1,
                    expression: expr("Total Customers: " <> grand_total_customers),
                    position: [x: 0, y: 20]
                  )

                  expression(:summary_line2,
                    expression: expr("Total Credit: " <> grand_total_credit),
                    position: [x: 0, y: 35]
                  )

                  expression(:summary_line3,
                    expression: expr("Average Credit: " <> grand_average_credit),
                    position: [x: 0, y: 50]
                  )

                  box("summary_box",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 70],
                    style: [fill_color: "#e8f5e8", border_width: 2, border_color: "#4caf50"]
                  )

                  line("final_line",
                    from: [x: 0, y: 75],
                    to: [x: 600, y: 75],
                    style: [color: "#4caf50", width: 3]
                  )

                  image("summary_icon",
                    source: "/assets/summary_icon.png",
                    position: [x: 550, y: 10],
                    size: [width: 40, height: 40]
                  )
                end
              end
            end
          end
        end
      end

      # Verify domain and report compilation
      assert CompleteBandHierarchyDomain
      report_module = CompleteBandHierarchyDomain.Reports.CompleteBandHierarchy
      assert report_module

      definition = report_module.definition()

      # Verify all band types are present
      band_types = Enum.map(definition.bands, & &1.type)

      expected_types = [
        :title,
        :page_header,
        :column_header,
        :group_header,
        :group_footer,
        :column_footer,
        :page_footer,
        :summary
      ]

      for expected_type <- expected_types do
        assert expected_type in band_types,
               "Band type #{expected_type} missing from report"
      end

      # Verify band hierarchy and nesting
      # All top-level bands
      assert length(definition.bands) == 8

      # Find region group header and verify its nested structure
      region_header = Enum.find(definition.bands, &(&1.name == :region_group_header))
      assert region_header
      # status_group_header and status_group_footer
      assert length(region_header.bands) == 2

      # Find status group header and verify its nested structure
      status_header = Enum.find(region_header.bands, &(&1.name == :status_group_header))
      assert status_header
      # detail_header, detail, detail_footer
      assert length(status_header.bands) == 3

      # Verify element counts in key bands
      title_band = Enum.find(definition.bands, &(&1.type == :title))
      # label, image, line, expression
      assert length(title_band.elements) == 4

      detail_band = Enum.find(status_header.bands, &(&1.type == :detail))
      # 4 fields, 1 expression, 1 line
      assert length(detail_band.elements) == 6

      summary_band = Enum.find(definition.bands, &(&1.type == :summary))
      # 1 label, 3 aggregates, 3 expressions, 1 box, 1 line, 1 image
      assert length(summary_band.elements) == 9
    end

    test "validates band order enforcement" do
      # Test that bands must be in the correct order
      assert_raise Spark.Error.DslError, ~r/band order/, fn ->
        defmodule InvalidBandOrderDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_band_order do
              title("Invalid Band Order")
              driving_resource(AshReports.Test.Customer)

              bands do
                # This should fail - summary cannot come before detail
                band :summary do
                  elements do
                    label("summary", text: "Summary")
                  end
                end

                band :detail do
                  elements do
                    field(:name, source: [:name])
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates nested band structure rules" do
      # Test that nested bands follow proper hierarchy rules
      assert_raise Spark.Error.DslError, fn ->
        defmodule InvalidNestedBandsDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_nested_bands do
              title("Invalid Nested Bands")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    field(:name, source: [:name])
                  end

                  bands do
                    # This should fail - detail bands cannot contain other bands
                    band :nested_detail do
                      elements do
                        field(:email, source: [:email])
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe "reports with all element types and combinations" do
    test "creates report with comprehensive element types" do
      defmodule ComprehensiveElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
        end

        reports do
          report :comprehensive_elements do
            title("Comprehensive Elements Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf, :json])

            parameters do
              parameter(:region_filter, :string, required: false)
              parameter(:show_images, :boolean, required: false, default: true)
              parameter(:currency_symbol, :string, required: false, default: "$")
            end

            variables do
              variable(:element_counter, type: :count, reset_on: :report)
              variable(:section_counter, type: :count, reset_on: :group, reset_group: 1)
            end

            groups do
              group(:region, field: [:region], sort: :asc)
            end

            bands do
              band :title do
                elements do
                  # All label variations
                  label("static_label", text: "Static Label Text")
                  label("param_label", text: expr("Filter: " <> (region_filter || "All Regions")))

                  label("complex_label",
                    text:
                      expr(
                        "Report for " <>
                          (region_filter || "All") <> " - " <> format_date(now(), :short)
                      )
                  )

                  # All image variations
                  image("static_image", source: "/assets/logo.png")

                  image("conditional_image",
                    source:
                      expr(if(show_images, "/assets/full_logo.png", "/assets/text_logo.png"))
                  )

                  image("positioned_image",
                    source: "/assets/header.png",
                    position: [x: 400, y: 0],
                    size: [width: 100, height: 50]
                  )

                  # All line variations
                  line("horizontal_line", from: [x: 0, y: 60], to: [x: 600, y: 60])
                  line("vertical_line", from: [x: 300, y: 0], to: [x: 300, y: 60])
                  line("diagonal_line", from: [x: 0, y: 0], to: [x: 100, y: 60])

                  line("styled_line",
                    from: [x: 0, y: 65],
                    to: [x: 600, y: 65],
                    style: [color: "#ff6600", width: 3, dash_pattern: [5, 3]]
                  )

                  # All box variations
                  box("simple_box", from: [x: 0, y: 70], to: [x: 200, y: 120])

                  box("styled_box",
                    from: [x: 220, y: 70],
                    to: [x: 420, y: 120],
                    style: [border_width: 2, border_color: "#0066cc", fill_color: "#e6f3ff"]
                  )

                  box("complex_box",
                    from: [x: 440, y: 70],
                    to: [x: 600, y: 120],
                    style: [
                      border_width: 1,
                      border_color: "#333333",
                      fill_color: "#f9f9f9",
                      corner_radius: 5,
                      shadow: true
                    ]
                  )

                  # All expression variations
                  expression(:simple_expr, expression: expr("Current time: " <> now()))
                  expression(:math_expr, expression: expr("Counter value: " <> element_counter))

                  expression(:conditional_expr,
                    expression: expr(if(region_filter != nil, "Filtered View", "Complete View"))
                  )

                  expression(:complex_expr,
                    expression:
                      expr(
                        "Report: " <>
                          (region_filter || "All") <>
                          " | Generated: " <>
                          format_date(now(), :long) <> " | Symbol: " <> currency_symbol
                      )
                  )
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  # All field variations
                  field(:simple_field, source: [:region])
                  field(:formatted_field, source: [:credit_limit], format: :currency)
                  field(:positioned_field, source: [:name], position: [x: 200, y: 0])

                  field(:styled_field,
                    source: [:status],
                    style: [font_weight: :bold, color: "#0066cc"]
                  )

                  field(:conditional_field,
                    source: [:email],
                    visible: expr(region_filter == nil || region == region_filter)
                  )

                  # Field with complex formatting
                  field(:complex_formatted_field,
                    source: [:credit_limit],
                    format: {:currency, symbol: expr(currency_symbol), precision: 2}
                  )

                  # Expression fields
                  expression(:field_combination,
                    expression: expr(region <> " - " <> status)
                  )

                  expression(:field_calculation,
                    expression:
                      expr(
                        "Customer: " <>
                          name <> " (Credit: " <> currency_symbol <> credit_limit <> ")"
                      )
                  )

                  # Aggregate previews
                  aggregate(:region_preview_count,
                    function: :count,
                    source: [:id],
                    scope: :current_group
                  )

                  expression(:preview_info,
                    expression: expr("This region has " <> region_preview_count <> " customers")
                  )
                end

                bands do
                  band :detail do
                    elements do
                      # Complete field coverage
                      field(:customer_id, source: [:id])
                      field(:customer_name, source: [:name])
                      field(:customer_email, source: [:email])
                      field(:customer_region, source: [:region])
                      field(:customer_status, source: [:status])
                      field(:customer_credit, source: [:credit_limit], format: :currency)

                      # Date/time fields (if available)
                      field(:created_date, source: [:created_at], format: :date)
                      field(:updated_time, source: [:updated_at], format: :datetime)

                      # Boolean field
                      field(:active_status, source: [:active], format: :boolean)

                      # Numeric fields with different formats
                      field(:credit_decimal,
                        source: [:credit_limit],
                        format: {:decimal, precision: 2}
                      )

                      field(:credit_percentage,
                        source: [:credit_limit],
                        format: {:percentage, precision: 1}
                      )

                      # Complex expressions combining fields
                      expression(:full_customer_info,
                        expression: expr(id <> ": " <> name <> " (" <> email <> ")")
                      )

                      expression(:status_info,
                        expression:
                          expr(
                            region <> " | " <> status <> " | " <> currency_symbol <> credit_limit
                          )
                      )

                      expression(:conditional_status,
                        expression:
                          expr(
                            case status do
                              :active -> "✓ Active Customer"
                              :inactive -> "✗ Inactive Customer"
                              _ -> "? Unknown Status"
                            end
                          )
                      )

                      # Visual elements for detail separation
                      line("detail_separator",
                        from: [x: 0, y: 25],
                        to: [x: 600, y: 25],
                        style: [color: "#eeeeee", width: 1]
                      )

                      box("detail_highlight",
                        from: [x: 0, y: 0],
                        to: [x: 10, y: 25],
                        style: [
                          fill_color:
                            expr(
                              case status do
                                :active -> "#4caf50"
                                :inactive -> "#f44336"
                                _ -> "#ff9800"
                              end
                            )
                        ]
                      )
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  # All aggregate function types
                  aggregate(:count_agg, function: :count, source: [:id])
                  aggregate(:sum_agg, function: :sum, source: [:credit_limit], format: :currency)
                  aggregate(:avg_agg, function: :avg, source: [:credit_limit], format: :currency)
                  aggregate(:min_agg, function: :min, source: [:credit_limit], format: :currency)
                  aggregate(:max_agg, function: :max, source: [:credit_limit], format: :currency)
                  aggregate(:first_agg, function: :first, source: [:name])
                  aggregate(:last_agg, function: :last, source: [:name])

                  # Conditional aggregates
                  aggregate(:active_count,
                    function: :count_where,
                    condition: expr(status == :active)
                  )

                  aggregate(:inactive_count,
                    function: :count_where,
                    condition: expr(status == :inactive)
                  )

                  aggregate(:high_credit_sum,
                    function: :sum_where,
                    source: [:credit_limit],
                    condition: expr(credit_limit > 5000),
                    format: :currency
                  )

                  # Complex expressions using aggregates
                  expression(:summary_stats,
                    expression:
                      expr("Count: " <> count_agg <> " | Average: " <> currency_symbol <> avg_agg)
                  )

                  expression(:range_info,
                    expression:
                      expr(
                        "Range: " <>
                          currency_symbol <> min_agg <> " to " <> currency_symbol <> max_agg
                      )
                  )

                  expression(:activity_ratio,
                    expression:
                      expr(
                        "Active: " <>
                          active_count <>
                          "/" <>
                          count_agg <>
                          " (" <> (active_count / count_agg * 100) <> "%)"
                      )
                  )

                  # Visual summary elements
                  box("summary_box",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 60],
                    style: [fill_color: "#f5f5f5", border_width: 1, border_color: "#cccccc"]
                  )

                  line("summary_top_line",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 0],
                    style: [color: "#0066cc", width: 2]
                  )

                  line("summary_bottom_line",
                    from: [x: 0, y: 60],
                    to: [x: 600, y: 60],
                    style: [color: "#0066cc", width: 2]
                  )
                end
              end

              band :summary do
                elements do
                  # Grand total aggregates
                  aggregate(:grand_total_customers, function: :count, source: [:id])

                  aggregate(:grand_total_credit,
                    function: :sum,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:grand_avg_credit,
                    function: :avg,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:grand_min_credit,
                    function: :min,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:grand_max_credit,
                    function: :max,
                    source: [:credit_limit],
                    format: :currency
                  )

                  # Summary calculations
                  expression(:grand_summary_line1,
                    expression: expr("Grand Total: " <> grand_total_customers <> " customers")
                  )

                  expression(:grand_summary_line2,
                    expression: expr("Total Credit: " <> currency_symbol <> grand_total_credit)
                  )

                  expression(:grand_summary_line3,
                    expression: expr("Average Credit: " <> currency_symbol <> grand_avg_credit)
                  )

                  expression(:grand_summary_line4,
                    expression:
                      expr(
                        "Credit Range: " <>
                          currency_symbol <>
                          grand_min_credit <>
                          " to " <> currency_symbol <> grand_max_credit
                      )
                  )

                  # Final visual elements
                  box("final_summary_box",
                    from: [x: 0, y: 0],
                    to: [x: 600, y: 80],
                    style: [fill_color: "#e8f5e8", border_width: 3, border_color: "#4caf50"]
                  )

                  image("completion_icon",
                    source: "/assets/complete_icon.png",
                    position: [x: 550, y: 10],
                    size: [width: 40, height: 40]
                  )

                  line("final_line",
                    from: [x: 0, y: 85],
                    to: [x: 600, y: 85],
                    style: [color: "#4caf50", width: 4]
                  )
                end
              end
            end
          end
        end
      end

      # Verify compilation and element coverage
      assert ComprehensiveElementsDomain
      report_module = ComprehensiveElementsDomain.Reports.ComprehensiveElements
      assert report_module

      definition = report_module.definition()

      # Verify all bands are present
      # title, group_header, group_footer, summary
      assert length(definition.bands) == 4

      # Count elements by type across all bands
      all_elements =
        Enum.flat_map(definition.bands, fn band ->
          Enum.flat_map([band | extract_nested_bands(band)], & &1.elements)
        end)

      element_type_counts =
        Enum.reduce(all_elements, %{}, fn element, acc ->
          type =
            case element do
              %AshReports.Element.Field{} -> :field
              %AshReports.Element.Label{} -> :label
              %AshReports.Element.Expression{} -> :expression
              %AshReports.Element.Aggregate{} -> :aggregate
              %AshReports.Element.Line{} -> :line
              %AshReports.Element.Box{} -> :box
              %AshReports.Element.Image{} -> :image
              _ -> :unknown
            end

          Map.update(acc, type, 1, &(&1 + 1))
        end)

      # Verify we have good coverage of all element types
      assert element_type_counts[:field] >= 10, "Should have at least 10 field elements"
      assert element_type_counts[:label] >= 3, "Should have at least 3 label elements"
      assert element_type_counts[:expression] >= 15, "Should have at least 15 expression elements"
      assert element_type_counts[:aggregate] >= 10, "Should have at least 10 aggregate elements"
      assert element_type_counts[:line] >= 5, "Should have at least 5 line elements"
      assert element_type_counts[:box] >= 4, "Should have at least 4 box elements"
      assert element_type_counts[:image] >= 3, "Should have at least 3 image elements"

      IO.puts("\n=== Element Type Coverage ===")

      for {type, count} <- element_type_counts do
        IO.puts("#{type}: #{count}")
      end
    end

    test "validates element positioning and styling" do
      defmodule ElementPositioningDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :element_positioning_test do
            title("Element Positioning Test")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  # Test absolute positioning
                  field(:name, source: [:name], position: [x: 0, y: 0])
                  field(:email, source: [:email], position: [x: 200, y: 0])
                  field(:status, source: [:status], position: [x: 400, y: 0])

                  # Test element styling
                  label("styled_label",
                    text: "Styled Label",
                    style: [font_size: 12, font_weight: :bold, color: "#0066cc"]
                  )

                  # Test box with comprehensive styling
                  box("styled_box",
                    from: [x: 0, y: 20],
                    to: [x: 500, y: 40],
                    style: [
                      border_width: 2,
                      border_color: "#ff6600",
                      fill_color: "#fff3e6",
                      corner_radius: 8,
                      shadow: true,
                      opacity: 0.8
                    ]
                  )

                  # Test line with styling
                  line("styled_line",
                    from: [x: 0, y: 45],
                    to: [x: 500, y: 45],
                    style: [color: "#00cc66", width: 3, dash_pattern: [10, 5, 3, 5]]
                  )

                  # Test image with positioning and sizing
                  image("positioned_image",
                    source: "/assets/test.png",
                    position: [x: 450, y: 0],
                    size: [width: 50, height: 20]
                  )
                end
              end
            end
          end
        end
      end

      assert ElementPositioningDomain
      report_module = ElementPositioningDomain.Reports.ElementPositioningTest
      definition = report_module.definition()

      detail_band = hd(definition.bands)
      elements = detail_band.elements

      # Verify positioning information is preserved
      name_field = Enum.find(elements, &(&1.name == :name))
      assert name_field.position == [x: 0, y: 0]

      email_field = Enum.find(elements, &(&1.name == :email))
      assert email_field.position == [x: 200, y: 0]

      # Verify styling information is preserved
      styled_label = Enum.find(elements, &(&1.name == :styled_label))
      assert styled_label.style == [font_size: 12, font_weight: :bold, color: "#0066cc"]

      styled_box = Enum.find(elements, &(&1.name == :styled_box))

      expected_style = [
        border_width: 2,
        border_color: "#ff6600",
        fill_color: "#fff3e6",
        corner_radius: 8,
        shadow: true,
        opacity: 0.8
      ]

      assert styled_box.style == expected_style
    end
  end

  describe "reports with variables and grouping scenarios" do
    test "creates report with comprehensive variable types" do
      defmodule ComprehensiveVariablesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
        end

        reports do
          report :comprehensive_variables do
            title("Comprehensive Variables Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html])

            variables do
              # Count variables with different reset levels
              variable(:total_customers, type: :count, reset_on: :report)
              variable(:page_customers, type: :count, reset_on: :page)
              variable(:group_customers, type: :count, reset_on: :group, reset_group: 1)
              variable(:subgroup_customers, type: :count, reset_on: :group, reset_group: 2)

              # Sum variables
              variable(:total_credit,
                type: :sum,
                expression: expr(credit_limit),
                reset_on: :report
              )

              variable(:group_credit,
                type: :sum,
                expression: expr(credit_limit),
                reset_on: :group,
                reset_group: 1
              )

              variable(:subgroup_credit,
                type: :sum,
                expression: expr(credit_limit),
                reset_on: :group,
                reset_group: 2
              )

              # Average variables
              variable(:running_avg_credit,
                type: :avg,
                expression: expr(credit_limit),
                reset_on: :report
              )

              variable(:group_avg_credit,
                type: :avg,
                expression: expr(credit_limit),
                reset_on: :group,
                reset_group: 1
              )

              # Min/Max variables
              variable(:min_credit, type: :min, expression: expr(credit_limit), reset_on: :report)
              variable(:max_credit, type: :max, expression: expr(credit_limit), reset_on: :report)

              variable(:group_min_credit,
                type: :min,
                expression: expr(credit_limit),
                reset_on: :group,
                reset_group: 1
              )

              variable(:group_max_credit,
                type: :max,
                expression: expr(credit_limit),
                reset_on: :group,
                reset_group: 1
              )

              # Conditional count variables
              variable(:active_customers,
                type: :count_where,
                condition: expr(status == :active),
                reset_on: :report
              )

              variable(:inactive_customers,
                type: :count_where,
                condition: expr(status == :inactive),
                reset_on: :report
              )

              variable(:high_credit_customers,
                type: :count_where,
                condition: expr(credit_limit > 5000),
                reset_on: :group,
                reset_group: 1
              )

              # Conditional sum variables
              variable(:active_credit_sum,
                type: :sum_where,
                expression: expr(credit_limit),
                condition: expr(status == :active),
                reset_on: :report
              )

              variable(:high_value_sum,
                type: :sum_where,
                expression: expr(credit_limit),
                condition: expr(credit_limit > 10000),
                reset_on: :group,
                reset_group: 1
              )

              # Complex expression variables
              variable(:credit_variance,
                type: :expression,
                expression: expr((group_max_credit - group_min_credit) / group_avg_credit),
                reset_on: :group,
                reset_group: 1
              )

              variable(:activity_ratio,
                type: :expression,
                expression: expr(active_customers / total_customers * 100),
                reset_on: :report
              )

              variable(:group_percentage,
                type: :expression,
                expression: expr(group_customers / total_customers * 100),
                reset_on: :group,
                reset_group: 1
              )
            end

            groups do
              group(:region, field: [:region], sort: :asc)
              group(:status, field: [:status], sort: :desc)

              group(:credit_tier,
                field:
                  expr(
                    case do
                      credit_limit < 1000 -> "Low"
                      credit_limit < 5000 -> "Medium"
                      credit_limit < 10000 -> "High"
                      true -> "Premium"
                    end
                  ),
                sort: :asc
              )
            end

            bands do
              band :title do
                elements do
                  label("title", text: "Variable Demonstration Report")

                  expression(:report_totals,
                    expression:
                      expr("Report Scope: " <> total_customers <> " customers, $" <> total_credit)
                  )

                  expression(:activity_summary,
                    expression:
                      expr(
                        "Active: " <>
                          active_customers <>
                          " (" <>
                          activity_ratio <>
                          "%), " <>
                          "Inactive: " <> inactive_customers
                      )
                  )

                  expression(:credit_range,
                    expression: expr("Credit Range: $" <> min_credit <> " to $" <> max_credit)
                  )
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field(:region_name, source: [:region])

                  expression(:group_intro,
                    expression:
                      expr("Region: " <> region <> " (" <> group_percentage <> "% of total)")
                  )

                  expression(:group_stats,
                    expression:
                      expr("Customers: " <> group_customers <> ", Credit: $" <> group_credit)
                  )

                  expression(:group_averages,
                    expression:
                      expr(
                        "Average: $" <>
                          group_avg_credit <>
                          ", Range: $" <>
                          group_min_credit <> " to $" <> group_max_credit
                      )
                  )

                  expression(:group_variance,
                    expression: expr("Credit Variance: " <> credit_variance)
                  )
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      field(:status_name, source: [:status])

                      expression(:subgroup_info,
                        expression:
                          expr(
                            "Status: " <> status <> " - " <> subgroup_customers <> " customers"
                          )
                      )

                      expression(:subgroup_credit,
                        expression: expr("Subgroup Credit: $" <> subgroup_credit)
                      )
                    end

                    bands do
                      band :group_header, group_level: 3 do
                        elements do
                          expression(:credit_tier_name,
                            expression:
                              expr(
                                "Credit Tier: " <>
                                  case do
                                    credit_limit < 1000 -> "Low"
                                    credit_limit < 5000 -> "Medium"
                                    credit_limit < 10000 -> "High"
                                    true -> "Premium"
                                  end
                              )
                          )
                        end

                        bands do
                          band :detail do
                            elements do
                              field(:customer_name, source: [:name])
                              field(:customer_email, source: [:email])
                              field(:customer_status, source: [:status])
                              field(:customer_credit, source: [:credit_limit], format: :currency)

                              # Use variables in detail calculations
                              expression(:customer_vs_group_avg,
                                expression:
                                  expr(
                                    "vs Group Avg: " <>
                                      (credit_limit - group_avg_credit) <>
                                      " (" <>
                                      ((credit_limit - group_avg_credit) / group_avg_credit * 100) <>
                                      "%)"
                                  )
                              )

                              expression(:customer_position,
                                expression:
                                  expr("Customer #" <> group_customers <> " in " <> region)
                              )
                            end
                          end
                        end
                      end

                      band :group_footer, group_level: 3 do
                        elements do
                          expression(:tier_summary,
                            expression:
                              expr(
                                "Credit Tier Summary - Count: " <>
                                  subgroup_customers <>
                                  ", Total: $" <> subgroup_credit
                              )
                          )
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      expression(:status_summary,
                        expression:
                          expr(
                            "Status Group: " <>
                              status <>
                              " - " <>
                              subgroup_customers <>
                              " customers, $" <> subgroup_credit <> " total credit"
                          )
                      )

                      expression(:status_vs_region,
                        expression:
                          expr(
                            "Percentage of region: " <>
                              (subgroup_customers / group_customers * 100) <> "%"
                          )
                      )
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  expression(:region_final_summary,
                    expression: expr("Region " <> region <> " Summary:")
                  )

                  expression(:region_totals,
                    expression:
                      expr("Total: " <> group_customers <> " customers, $" <> group_credit)
                  )

                  expression(:region_averages,
                    expression:
                      expr(
                        "Average: $" <>
                          group_avg_credit <>
                          ", Min: $" <>
                          group_min_credit <>
                          ", Max: $" <> group_max_credit
                      )
                  )

                  expression(:region_high_value,
                    expression:
                      expr(
                        "High Credit (>$5000): " <>
                          high_credit_customers <>
                          " customers, $" <> high_value_sum <> " total"
                      )
                  )

                  expression(:region_percentage,
                    expression:
                      expr("Region represents " <> group_percentage <> "% of total report")
                  )
                end
              end

              band :summary do
                elements do
                  expression(:final_totals,
                    expression: expr("Final Report Totals:")
                  )

                  expression(:customer_totals,
                    expression:
                      expr(
                        "Customers: " <>
                          total_customers <>
                          " (Active: " <>
                          active_customers <>
                          ", Inactive: " <> inactive_customers <> ")"
                      )
                  )

                  expression(:credit_totals,
                    expression:
                      expr(
                        "Total Credit: $" <>
                          total_credit <>
                          " (Active: $" <> active_credit_sum <> ")"
                      )
                  )

                  expression(:credit_statistics,
                    expression:
                      expr(
                        "Credit Stats - Average: $" <>
                          running_avg_credit <>
                          ", Min: $" <>
                          min_credit <>
                          ", Max: $" <> max_credit
                      )
                  )

                  expression(:activity_statistics,
                    expression:
                      expr(
                        "Activity Rate: " <>
                          activity_ratio <>
                          "% (" <> active_customers <> "/" <> total_customers <> ")"
                      )
                  )
                end
              end
            end
          end
        end
      end

      # Verify comprehensive variable compilation
      assert ComprehensiveVariablesDomain
      report_module = ComprehensiveVariablesDomain.Reports.ComprehensiveVariables
      definition = report_module.definition()

      # Verify variable definitions
      # All defined variables
      assert length(definition.variables) == 21

      # Verify variable types are represented
      variable_types = Enum.map(definition.variables, & &1.type)
      assert :count in variable_types
      assert :sum in variable_types
      assert :avg in variable_types
      assert :min in variable_types
      assert :max in variable_types
      assert :count_where in variable_types
      assert :sum_where in variable_types
      assert :expression in variable_types

      # Verify reset levels are represented
      reset_levels = Enum.map(definition.variables, & &1.reset_on)
      assert :report in reset_levels
      assert :page in reset_levels
      assert :group in reset_levels

      # Verify group definitions
      # region, status, credit_tier
      assert length(definition.groups) == 3

      # Verify that variables are used in expressions throughout the report
      all_expressions = extract_all_expressions(definition.bands)
      variable_names = Enum.map(definition.variables, & &1.name)

      # Check that at least some variables are referenced in expressions
      referenced_variables =
        Enum.filter(variable_names, fn var_name ->
          var_string = to_string(var_name)

          Enum.any?(all_expressions, fn expr_text ->
            String.contains?(to_string(expr_text), var_string)
          end)
        end)

      assert length(referenced_variables) > 10,
             "Expected more variables to be referenced in expressions, got #{length(referenced_variables)}"
    end

    test "validates variable reset behavior and scope" do
      defmodule VariableResetScopeDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :variable_reset_scope_test do
            title("Variable Reset and Scope Test")
            driving_resource(AshReports.Test.Customer)

            variables do
              variable(:report_counter, type: :count, reset_on: :report)
              variable(:group1_counter, type: :count, reset_on: :group, reset_group: 1)
              variable(:group2_counter, type: :count, reset_on: :group, reset_group: 2)
              variable(:page_counter, type: :count, reset_on: :page)
            end

            groups do
              group(:region, field: [:region], sort: :asc)
              group(:status, field: [:status], sort: :asc)
            end

            bands do
              band :title do
                elements do
                  expression(:report_scope,
                    expression: expr("Report Counter: " <> report_counter)
                  )
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field(:region, source: [:region])

                  expression(:group1_scope,
                    expression:
                      expr(
                        "Group 1 Counter: " <>
                          group1_counter <>
                          " | Report Counter: " <> report_counter
                      )
                  )
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      field(:status, source: [:status])

                      expression(:group2_scope,
                        expression:
                          expr(
                            "Group 2 Counter: " <>
                              group2_counter <>
                              " | Group 1 Counter: " <>
                              group1_counter <>
                              " | Report Counter: " <> report_counter
                          )
                      )
                    end

                    bands do
                      band :detail do
                        elements do
                          field(:name, source: [:name])

                          expression(:detail_counters,
                            expression:
                              expr(
                                "Detail - G2: " <>
                                  group2_counter <>
                                  " | G1: " <>
                                  group1_counter <>
                                  " | Report: " <>
                                  report_counter <>
                                  " | Page: " <> page_counter
                              )
                          )
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      expression(:group2_footer,
                        expression: expr("End Group 2 - Counter: " <> group2_counter)
                      )
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  expression(:group1_footer,
                    expression: expr("End Group 1 - Counter: " <> group1_counter)
                  )
                end
              end

              band :summary do
                elements do
                  expression(:final_counters,
                    expression:
                      expr(
                        "Final - Report: " <>
                          report_counter <>
                          " | Page: " <> page_counter
                      )
                  )
                end
              end
            end
          end
        end
      end

      # Verify variable scoping compilation
      assert VariableResetScopeDomain
      report_module = VariableResetScopeDomain.Reports.VariableResetScopeTest
      definition = report_module.definition()

      # Verify all variables are defined with correct reset scopes
      variables_by_reset = Enum.group_by(definition.variables, & &1.reset_on)

      assert length(variables_by_reset[:report]) == 1
      assert length(variables_by_reset[:group]) == 2
      assert length(variables_by_reset[:page]) == 1

      # Verify group-level variables have correct reset_group values
      group_variables = variables_by_reset[:group]
      group1_var = Enum.find(group_variables, &(&1.name == :group1_counter))
      group2_var = Enum.find(group_variables, &(&1.name == :group2_counter))

      assert group1_var.reset_group == 1
      assert group2_var.reset_group == 2
    end
  end

  describe "parameter validation and substitution scenarios" do
    test "creates report with comprehensive parameter types and validation" do
      defmodule ComprehensiveParametersDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :comprehensive_parameters do
            title("Comprehensive Parameters Report")
            driving_resource(AshReports.Test.Customer)

            parameters do
              # String parameters with different requirements
              parameter(:region_filter, :string, required: false, default: "All")
              parameter(:customer_name_search, :string, required: false)
              parameter(:report_title, :string, required: true)

              # Numeric parameters
              parameter(:min_credit_limit, :decimal, required: false, default: Decimal.new("0"))
              parameter(:max_credit_limit, :decimal, required: false)
              parameter(:page_size, :integer, required: false, default: 50)
              parameter(:precision_digits, :integer, required: false, default: 2)

              # Date parameters
              parameter(:report_date, :date, required: true)
              parameter(:start_date, :date, required: false)
              parameter(:end_date, :date, required: false)

              # Boolean parameters
              parameter(:include_inactive, :boolean, required: false, default: false)
              parameter(:show_details, :boolean, required: false, default: true)
              parameter(:enable_grouping, :boolean, required: false, default: true)

              # Choice/enum-like parameters (using string with validation)
              parameter(:sort_order, :string, required: false, default: "asc")
              parameter(:format_style, :string, required: false, default: "standard")
              parameter(:currency_symbol, :string, required: false, default: "$")
            end

            bands do
              band :title do
                elements do
                  # Parameter substitution in labels
                  label("report_title", text: expr(report_title))

                  label("date_label",
                    text: expr("Report Date: " <> format_date(report_date, :long))
                  )

                  # Conditional parameter usage
                  label("filter_info",
                    text:
                      expr(
                        if(
                          region_filter != "All",
                          "Filtered by Region: " <> region_filter,
                          "Showing All Regions"
                        )
                      )
                  )

                  # Complex parameter combinations
                  expression(:title_summary,
                    expression:
                      expr(
                        report_title <>
                          " - " <>
                          format_date(report_date, :short) <>
                          " (Generated: " <> format_date(now(), :short) <> ")"
                      )
                  )

                  # Date range handling
                  expression(:date_range,
                    expression:
                      expr(
                        if(
                          start_date != nil && end_date != nil,
                          "Period: " <>
                            format_date(start_date, :short) <>
                            " to " <> format_date(end_date, :short),
                          "No date range specified"
                        )
                      )
                  )

                  # Numeric parameter usage
                  expression(:credit_filter_info,
                    expression:
                      expr(
                        if(
                          max_credit_limit != nil,
                          "Credit Limit: " <>
                            currency_symbol <>
                            min_credit_limit <> " to " <> currency_symbol <> max_credit_limit,
                          "Credit Limit: Above " <> currency_symbol <> min_credit_limit
                        )
                      )
                  )
                end
              end

              band :detail do
                elements do
                  # Basic fields
                  field(:customer_name, source: [:name])
                  field(:customer_email, source: [:email])
                  field(:customer_status, source: [:status])

                  # Parameter-influenced field display
                  field(:customer_region,
                    source: [:region],
                    visible: expr(region_filter == "All" || region == region_filter)
                  )

                  # Parameter-based formatting
                  field(:credit_limit,
                    source: [:credit_limit],
                    format:
                      {:currency,
                       symbol: expr(currency_symbol), precision: expr(precision_digits)}
                  )

                  # Conditional elements based on boolean parameters
                  expression(:detail_info,
                    expression:
                      expr(
                        if(
                          show_details,
                          name <> " (" <> email <> ") - " <> status <> " in " <> region,
                          name <> " - " <> status
                        )
                      ),
                    visible: expr(show_details || region_filter != "All")
                  )

                  # Search parameter usage
                  expression(:search_highlight,
                    expression:
                      expr(
                        if(
                          customer_name_search != nil &&
                            contains_ignore_case(name, customer_name_search),
                          "⭐ MATCH: " <> name,
                          name
                        )
                      ),
                    visible: expr(customer_name_search != nil)
                  )

                  # Status filtering based on boolean parameter
                  expression(:status_display,
                    expression:
                      expr(
                        case status do
                          :active -> "✓ Active"
                          :inactive -> if(include_inactive, "✗ Inactive", "")
                          _ -> "? Unknown"
                        end
                      ),
                    visible: expr(status == :active || (status == :inactive && include_inactive))
                  )

                  # Parameter-based styling
                  box("highlight_box",
                    from: [x: 0, y: 0],
                    to: [x: 500, y: 25],
                    style:
                      expr(
                        case format_style do
                          "highlight" -> [fill_color: "#ffffcc", border_width: 1]
                          "minimal" -> [border_width: 0]
                          _ -> [fill_color: "#f5f5f5", border_width: 1]
                        end
                      ),
                    visible: expr(format_style != "minimal")
                  )
                end
              end

              band :summary do
                elements do
                  # Parameter summary
                  expression(:parameter_summary,
                    expression:
                      expr(
                        "Report Parameters: Title='" <>
                          report_title <>
                          "', Date=" <>
                          format_date(report_date, :short) <>
                          ", Region=" <> region_filter
                      )
                  )

                  expression(:filter_summary,
                    expression:
                      expr(
                        "Filters Applied: " <>
                          if(
                            customer_name_search != nil,
                            "Name='" <> customer_name_search <> "' ",
                            ""
                          ) <>
                          if(region_filter != "All", "Region='" <> region_filter <> "' ", "") <>
                          if(include_inactive, "Include Inactive ", "") <>
                          "Credit: " <> currency_symbol <> min_credit_limit <> "+"
                      )
                  )

                  expression(:display_options,
                    expression:
                      expr(
                        "Display Options: Details=" <>
                          show_details <>
                          ", Grouping=" <>
                          enable_grouping <>
                          ", Style=" <>
                          format_style <>
                          ", Page Size=" <> page_size
                      )
                  )

                  # Aggregates influenced by parameters
                  aggregate(:total_count, function: :count, source: [:id])

                  aggregate(:filtered_credit_sum,
                    function: :sum_where,
                    source: [:credit_limit],
                    condition:
                      expr(
                        credit_limit >= min_credit_limit &&
                          (max_credit_limit == nil || credit_limit <= max_credit_limit)
                      ),
                    format:
                      {:currency,
                       symbol: expr(currency_symbol), precision: expr(precision_digits)}
                  )

                  expression(:completion_info,
                    expression:
                      expr(
                        "Report completed on " <>
                          format_date(now(), :long) <>
                          " with " <> total_count <> " records processed"
                      )
                  )
                end
              end
            end
          end
        end
      end

      # Verify comprehensive parameter compilation
      assert ComprehensiveParametersDomain
      report_module = ComprehensiveParametersDomain.Reports.ComprehensiveParameters
      definition = report_module.definition()

      # Verify parameter definitions
      # All defined parameters
      assert length(definition.parameters) == 13

      # Verify parameter types
      parameter_types = Enum.map(definition.parameters, & &1.type)
      assert :string in parameter_types
      assert :decimal in parameter_types
      assert :integer in parameter_types
      assert :date in parameter_types
      assert :boolean in parameter_types

      # Verify required vs optional parameters
      required_params = Enum.filter(definition.parameters, & &1.required)
      optional_params = Enum.filter(definition.parameters, &(!&1.required))

      # report_title, report_date
      assert length(required_params) == 2
      assert length(optional_params) == 11

      # Verify default values are set
      params_with_defaults = Enum.filter(definition.parameters, &(&1.default != nil))
      assert length(params_with_defaults) == 9

      # Test parameter validation
      valid_params = %{
        report_title: "Test Report",
        report_date: ~D[2024-01-01],
        region_filter: "North",
        min_credit_limit: Decimal.new("1000"),
        include_inactive: true
      }

      assert {:ok, validated} = report_module.validate_params(valid_params)
      assert validated.report_title == "Test Report"
      assert validated.region_filter == "North"
      assert validated.include_inactive == true
      # Check defaults were applied
      assert validated.currency_symbol == "$"
      assert validated.show_details == true

      # Test validation errors
      invalid_params = %{
        report_date: "not_a_date",
        min_credit_limit: "not_a_number"
      }

      assert {:error, errors} = report_module.validate_params(invalid_params)
      assert is_list(errors)
      # Missing required + type errors
      assert length(errors) >= 2
    end

    test "validates parameter usage in complex expressions" do
      defmodule ComplexParameterExpressionsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_parameter_expressions do
            title("Complex Parameter Expressions")
            driving_resource(AshReports.Test.Customer)

            parameters do
              parameter(:multiplier, :decimal, required: false, default: Decimal.new("1.0"))
              parameter(:threshold, :integer, required: false, default: 5000)
              parameter(:prefix, :string, required: false, default: "Customer")
              parameter(:enable_calculations, :boolean, required: false, default: true)
            end

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])

                  # Complex mathematical expressions with parameters
                  expression(:calculated_credit,
                    expression:
                      expr(
                        if(
                          enable_calculations,
                          credit_limit * multiplier,
                          credit_limit
                        )
                      )
                  )

                  # Conditional expressions with parameter thresholds
                  expression(:credit_category,
                    expression:
                      expr(
                        case do
                          credit_limit < threshold / 2 -> prefix <> " - Low Credit"
                          credit_limit < threshold -> prefix <> " - Medium Credit"
                          credit_limit < threshold * 2 -> prefix <> " - High Credit"
                          true -> prefix <> " - Premium Credit"
                        end
                      )
                  )

                  # String manipulation with parameters
                  expression(:formatted_name,
                    expression:
                      expr(
                        prefix <>
                          ": " <>
                          name <>
                          " (" <>
                          if(
                            enable_calculations,
                            "Calc: $" <> (credit_limit * multiplier),
                            "Base: $" <> credit_limit
                          ) <> ")"
                      )
                  )

                  # Boolean logic with parameters
                  expression(:meets_threshold,
                    expression:
                      expr(
                        if(
                          enable_calculations,
                          credit_limit * multiplier >= threshold,
                          credit_limit >= threshold
                        )
                      )
                  )

                  # Nested parameter expressions
                  expression(:complex_calculation,
                    expression:
                      expr(
                        if(
                          enable_calculations && credit_limit > 0,
                          "Adjusted: " <> (credit_limit * multiplier / threshold * 100) <> "%",
                          "Standard: " <> (credit_limit / threshold * 100) <> "%"
                        )
                      )
                  )
                end
              end
            end
          end
        end
      end

      # Verify complex parameter expression compilation
      assert ComplexParameterExpressionsDomain
      report_module = ComplexParameterExpressionsDomain.Reports.ComplexParameterExpressions
      definition = report_module.definition()

      # Verify all parameters are defined
      assert length(definition.parameters) == 4

      # Verify parameters are used in expressions
      detail_band = hd(definition.bands)

      expressions =
        Enum.filter(detail_band.elements, fn element ->
          match?(%AshReports.Element.Expression{}, element)
        end)

      assert length(expressions) == 5

      # Test parameter validation with edge cases
      edge_case_params = %{
        multiplier: Decimal.new("0"),
        threshold: 0,
        prefix: "",
        enable_calculations: false
      }

      assert {:ok, validated} = report_module.validate_params(edge_case_params)
      assert validated.multiplier == Decimal.new("0")
      assert validated.threshold == 0
      assert validated.prefix == ""
      assert validated.enable_calculations == false
    end
  end

  # Helper functions
  defp extract_nested_bands(band) do
    case band.bands do
      nil ->
        []

      bands when is_list(bands) ->
        bands ++ Enum.flat_map(bands, &extract_nested_bands/1)
    end
  end

  defp extract_all_expressions(bands) do
    Enum.flat_map(bands, &extract_band_expressions/1)
  end

  defp extract_band_expressions(band) do
    element_expressions = extract_element_expressions(band.elements)
    nested_expressions = extract_nested_expressions(band.bands)
    element_expressions ++ nested_expressions
  end

  defp extract_element_expressions(elements) do
    Enum.flat_map(elements, fn element ->
      case element do
        %AshReports.Element.Expression{expression: expr} -> [expr]
        %AshReports.Element.Label{text: expr} when is_tuple(expr) -> [expr]
        _ -> []
      end
    end)
  end

  defp extract_nested_expressions(nil), do: []
  defp extract_nested_expressions(nested_bands), do: extract_all_expressions(nested_bands)

  # Setup and cleanup
  setup do
    on_exit(fn ->
      cleanup_test_data()
    end)
  end
end
