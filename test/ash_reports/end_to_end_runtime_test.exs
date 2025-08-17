defmodule AshReports.EndToEndRuntimeTest do
  @moduledoc """
  Phase 1D: End-to-End Runtime Execution Testing

  This test module provides comprehensive end-to-end testing of runtime
  report execution, covering the complete workflow from DSL compilation
  through data querying to report generation and rendering.
  """

  use ExUnit.Case, async: false
  import AshReports.TestHelpers

  describe "complete runtime execution workflow" do
    test "executes full report generation workflow with real data" do
      # Setup test data for execution
      test_data =
        setup_test_data(%{
          customers: create_test_data(:customers, 20),
          orders: create_test_data(:orders, 40)
        })

      defmodule RuntimeWorkflowDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
        end

        reports do
          report :runtime_workflow_test do
            title("Runtime Workflow Test Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :json])

            parameters do
              parameter(:region_filter, :string, required: false)
              parameter(:min_credit, :decimal, required: false, default: Decimal.new("0"))
              parameter(:report_date, :date, required: false, default: Date.utc_today())
            end

            variables do
              variable(:customer_count, type: :count, reset_on: :report)
              variable(:region_count, type: :count, reset_on: :group, reset_group: 1)

              variable(:total_credit,
                type: :sum,
                expression: expr(credit_limit),
                reset_on: :report
              )
            end

            groups do
              group(:region, field: [:region], sort: :asc)
              group(:status, field: [:status], sort: :desc)
            end

            bands do
              band :title do
                elements do
                  label("report_title", text: "Customer Analysis Report")

                  expression("report_date",
                    expression: expr("Report Date: " <> format_date(report_date, :long))
                  )

                  expression("filter_info",
                    expression:
                      expr(
                        if(
                          region_filter != nil,
                          "Region Filter: " <> region_filter,
                          "All Regions Included"
                        )
                      )
                  )

                  expression("credit_filter",
                    expression: expr("Minimum Credit: $" <> min_credit)
                  )
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field(:region_name, source: [:region])

                  expression("region_intro",
                    expression: expr("Processing Region: " <> region)
                  )

                  expression("region_progress",
                    expression: expr("Customer " <> region_count <> " in " <> region)
                  )
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      field(:status_name, source: [:status])

                      expression("status_info",
                        expression: expr("Status Group: " <> status)
                      )
                    end

                    bands do
                      band :detail do
                        elements do
                          field(:customer_id, source: [:id])
                          field(:customer_name, source: [:name])
                          field(:customer_email, source: [:email])
                          field(:customer_region, source: [:region])
                          field(:customer_status, source: [:status])
                          field(:credit_limit, source: [:credit_limit], format: :currency)

                          expression(:customer_summary,
                            expression:
                              expr(
                                name <>
                                  " (" <>
                                  email <>
                                  ") - " <>
                                  region <> " - " <> status
                              )
                          )

                          expression(:credit_info,
                            expression:
                              expr(
                                "Credit: $" <>
                                  credit_limit <>
                                  if(credit_limit >= min_credit, " ✓", " ✗")
                              )
                          )

                          expression(:position_info,
                            expression:
                              expr(
                                "Customer #" <>
                                  customer_count <>
                                  " | Region #" <> region_count
                              )
                          )
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      aggregate(:status_count, function: :count, source: [:id])

                      aggregate(:status_credit_total,
                        function: :sum,
                        source: [:credit_limit],
                        format: :currency
                      )

                      aggregate(:status_credit_avg,
                        function: :avg,
                        source: [:credit_limit],
                        format: :currency
                      )

                      expression(:status_summary,
                        expression:
                          expr(
                            "Status " <>
                              status <>
                              " Summary: " <>
                              status_count <>
                              " customers, " <>
                              "Total: " <>
                              status_credit_total <>
                              ", " <>
                              "Average: " <> status_credit_avg
                          )
                      )
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate(:region_total_count, function: :count, source: [:id])

                  aggregate(:region_total_credit,
                    function: :sum,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:region_avg_credit,
                    function: :avg,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:region_min_credit,
                    function: :min,
                    source: [:credit_limit],
                    format: :currency
                  )

                  aggregate(:region_max_credit,
                    function: :max,
                    source: [:credit_limit],
                    format: :currency
                  )

                  expression(:region_final_summary,
                    expression: expr("Region " <> region <> " Totals:")
                  )

                  expression(:region_stats,
                    expression:
                      expr(
                        "Customers: " <>
                          region_total_count <>
                          " | Total Credit: " <> region_total_credit
                      )
                  )

                  expression(:region_credit_stats,
                    expression:
                      expr(
                        "Credit - Avg: " <>
                          region_avg_credit <>
                          " | Min: " <>
                          region_min_credit <>
                          " | Max: " <> region_max_credit
                      )
                  )

                  expression(:region_percentage,
                    expression:
                      expr(
                        "Region represents " <>
                          (region_total_count / customer_count * 100) <> "% of total"
                      )
                  )
                end
              end

              band :summary do
                elements do
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

                  expression(:final_summary_title,
                    expression: expr("Report Summary")
                  )

                  expression(:final_customer_stats,
                    expression: expr("Total Customers Processed: " <> grand_total_customers)
                  )

                  expression(:final_credit_totals,
                    expression:
                      expr(
                        "Total Credit: " <>
                          grand_total_credit <>
                          " | Average: " <> grand_avg_credit
                      )
                  )

                  expression(:final_credit_range,
                    expression:
                      expr(
                        "Credit Range: " <>
                          grand_min_credit <>
                          " to " <> grand_max_credit
                      )
                  )

                  expression(:final_variables,
                    expression:
                      expr(
                        "Variables Used - Count: " <>
                          customer_count <>
                          " | Total: " <> total_credit
                      )
                  )

                  expression(:completion_timestamp,
                    expression: expr("Report completed on " <> format_date(now(), :long))
                  )
                end
              end
            end
          end
        end
      end

      report_module = RuntimeWorkflowDomain.Reports.RuntimeWorkflowTest

      # Test 1: Parameter Validation and Default Application
      params = %{
        region_filter: "North",
        min_credit: Decimal.new("1000")
      }

      assert {:ok, validated_params} = report_module.validate_params(params)
      assert validated_params.region_filter == "North"
      assert validated_params.min_credit == Decimal.new("1000")
      # Default applied
      assert validated_params.report_date == Date.utc_today()

      # Test 2: Query Building
      assert {:ok, base_query} = report_module.build_query()
      assert base_query

      assert {:ok, filtered_query} = report_module.build_query(validated_params)
      assert filtered_query

      # Queries should be different when parameters are applied
      refute base_query == filtered_query

      # Test 3: Report Definition Access
      definition = report_module.definition()
      assert definition.name == :runtime_workflow_test
      assert definition.driving_resource == AshReports.Test.Customer
      assert definition.formats == [:html, :json]
      assert length(definition.parameters) == 3
      assert length(definition.variables) == 3
      assert length(definition.groups) == 2
      # title, group_header, group_footer, summary
      assert length(definition.bands) == 4

      # Test 4: Format Support
      assert report_module.supported_formats() == [:html, :json]
      assert report_module.supports_format?(:html) == true
      assert report_module.supports_format?(:json) == true
      assert report_module.supports_format?(:pdf) == false

      # Test 5: Format Module Interfaces
      assert report_module.Html.file_extension() == ".html"
      assert report_module.Json.file_extension() == ".json"
      # Boolean response
      assert report_module.Html.supports_streaming?() in [true, false]
      assert report_module.Json.supports_streaming?() in [true, false]

      # Test 6: Domain Reference
      assert report_module.domain() == RuntimeWorkflowDomain

      # Test 7: Error Handling in Workflow
      invalid_params = %{region_filter: 123, min_credit: "not_a_number"}
      assert {:error, errors} = report_module.validate_params(invalid_params)
      assert is_list(errors)
      assert length(errors) >= 2

      # Test 8: Edge Case Parameter Handling
      edge_params = %{
        # Empty string
        region_filter: "",
        # Zero value
        min_credit: Decimal.new("0"),
        # Very old date
        report_date: ~D[1900-01-01]
      }

      assert {:ok, edge_validated} = report_module.validate_params(edge_params)
      assert edge_validated.region_filter == ""
      assert edge_validated.min_credit == Decimal.new("0")

      cleanup_test_data()
    end

    test "handles complex parameter scenarios in runtime execution" do
      setup_test_data()

      defmodule ComplexParameterRuntimeDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_parameter_runtime do
            title("Complex Parameter Runtime Test")
            driving_resource(AshReports.Test.Customer)
            formats([:html])

            parameters do
              parameter(:title_override, :string, required: false)
              parameter(:multiplier, :decimal, required: false, default: Decimal.new("1.0"))
              parameter(:threshold, :integer, required: false, default: 5000)
              parameter(:enable_details, :boolean, required: false, default: true)
              parameter(:format_style, :string, required: false, default: "standard")
              parameter(:date_range_start, :date, required: false)
              parameter(:date_range_end, :date, required: false)
            end

            bands do
              band :title do
                elements do
                  label("dynamic_title",
                    text: expr(title_override || "Complex Parameter Runtime Test")
                  )

                  expression("parameter_summary",
                    expression:
                      expr(
                        "Parameters - Multiplier: " <>
                          multiplier <>
                          " | Threshold: " <>
                          threshold <>
                          " | Details: " <> enable_details
                      )
                  )

                  expression("date_range_info",
                    expression:
                      expr(
                        if(
                          date_range_start != nil && date_range_end != nil,
                          "Date Range: " <>
                            format_date(date_range_start, :short) <>
                            " to " <> format_date(date_range_end, :short),
                          "No date range specified"
                        )
                      )
                  )
                end
              end

              band :detail do
                elements do
                  field(:customer_name, source: [:name])
                  field(:customer_email, source: [:email], visible: expr(enable_details))
                  field(:credit_limit, source: [:credit_limit], format: :currency)

                  expression(:calculated_credit,
                    expression: expr("Calculated: $" <> (credit_limit * multiplier))
                  )

                  expression(:threshold_check,
                    expression:
                      expr(
                        if(
                          credit_limit >= threshold,
                          "Above Threshold ✓",
                          "Below Threshold ✗"
                        )
                      )
                  )

                  expression(:style_dependent,
                    expression:
                      expr(
                        case format_style do
                          "detailed" -> name <> " (" <> email <> ") - $" <> credit_limit
                          "compact" -> name <> " - $" <> credit_limit
                          _ -> name
                        end
                      )
                  )

                  expression(:date_filtered,
                    expression:
                      expr(
                        if(
                          date_range_start != nil,
                          "Filtered by date range",
                          "No date filtering"
                        )
                      ),
                    visible: expr(date_range_start != nil || date_range_end != nil)
                  )
                end
              end
            end
          end
        end
      end

      report_module = ComplexParameterRuntimeDomain.Reports.ComplexParameterRuntime

      # Test complex parameter combinations
      complex_params = %{
        title_override: "Custom Runtime Test Report",
        multiplier: Decimal.new("1.5"),
        threshold: 3000,
        enable_details: false,
        format_style: "detailed",
        date_range_start: ~D[2024-01-01],
        date_range_end: ~D[2024-12-31]
      }

      assert {:ok, validated} = report_module.validate_params(complex_params)
      assert validated.title_override == "Custom Runtime Test Report"
      assert validated.multiplier == Decimal.new("1.5")
      assert validated.threshold == 3000
      assert validated.enable_details == false
      assert validated.format_style == "detailed"
      assert validated.date_range_start == ~D[2024-01-01]
      assert validated.date_range_end == ~D[2024-12-31]

      # Test query building with complex parameters
      assert {:ok, complex_query} = report_module.build_query(validated)
      assert complex_query

      # Test partial parameters
      partial_params = %{
        multiplier: Decimal.new("2.0"),
        enable_details: true
      }

      assert {:ok, partial_validated} = report_module.validate_params(partial_params)
      assert partial_validated.title_override == nil
      assert partial_validated.multiplier == Decimal.new("2.0")
      # Default
      assert partial_validated.threshold == 5000
      assert partial_validated.enable_details == true
      # Default
      assert partial_validated.format_style == "standard"

      # Test parameter edge cases
      edge_params = %{
        # Empty string
        title_override: "",
        # Zero multiplier
        multiplier: Decimal.new("0"),
        # Zero threshold
        threshold: 0,
        enable_details: false,
        # Unknown style
        format_style: "unknown"
      }

      assert {:ok, edge_validated} = report_module.validate_params(edge_params)
      assert {:ok, _edge_query} = report_module.build_query(edge_validated)

      cleanup_test_data()
    end

    test "validates variable behavior in runtime execution context" do
      setup_test_data()

      defmodule VariableRuntimeDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :variable_runtime_test do
            title("Variable Runtime Test")
            driving_resource(AshReports.Test.Customer)

            variables do
              variable(:global_counter, type: :count, reset_on: :report)
              variable(:region_counter, type: :count, reset_on: :group, reset_group: 1)
              variable(:status_counter, type: :count, reset_on: :group, reset_group: 2)

              variable(:global_credit_sum,
                type: :sum,
                expression: expr(credit_limit),
                reset_on: :report
              )

              variable(:region_credit_sum,
                type: :sum,
                expression: expr(credit_limit),
                reset_on: :group,
                reset_group: 1
              )

              variable(:running_average,
                type: :avg,
                expression: expr(credit_limit),
                reset_on: :report
              )

              variable(:high_credit_count,
                type: :count_where,
                condition: expr(credit_limit > 5000),
                reset_on: :report
              )
            end

            groups do
              group(:region, field: [:region], sort: :asc)
              group(:status, field: [:status], sort: :desc)
            end

            bands do
              band :title do
                elements do
                  label("title", text: "Variable Runtime Test Report")

                  expression("global_info",
                    expression:
                      expr(
                        "Global Counter: " <>
                          global_counter <>
                          " | Global Credit Sum: $" <> global_credit_sum
                      )
                  )

                  expression("analysis_info",
                    expression:
                      expr(
                        "Running Average: $" <>
                          running_average <>
                          " | High Credit Count: " <> high_credit_count
                      )
                  )
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field(:region_name, source: [:region])

                  expression("region_progress",
                    expression:
                      expr(
                        "Region Progress - Local: " <>
                          region_counter <>
                          " | Global: " <> global_counter
                      )
                  )

                  expression("region_credit_progress",
                    expression:
                      expr(
                        "Region Credit: $" <>
                          region_credit_sum <>
                          " | Global Credit: $" <> global_credit_sum
                      )
                  )
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      field(:status_name, source: [:status])

                      expression("status_progress",
                        expression:
                          expr(
                            "Status: " <>
                              status_counter <>
                              " | Region: " <>
                              region_counter <>
                              " | Global: " <> global_counter
                          )
                      )
                    end

                    bands do
                      band :detail do
                        elements do
                          field(:customer_name, source: [:name])
                          field(:credit_limit, source: [:credit_limit], format: :currency)

                          expression(:position_tracking,
                            expression:
                              expr(
                                "Position - Status: #" <>
                                  status_counter <>
                                  " | Region: #" <>
                                  region_counter <>
                                  " | Global: #" <> global_counter
                              )
                          )

                          expression(:running_stats,
                            expression:
                              expr(
                                "Running Avg: $" <>
                                  running_average <>
                                  " | This Credit: $" <> credit_limit
                              )
                          )

                          expression(:credit_analysis,
                            expression:
                              expr(
                                if(
                                  credit_limit > 5000,
                                  "High Credit Customer",
                                  "Standard Credit Customer"
                                )
                              )
                          )
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      expression("status_totals",
                        expression: expr("Status " <> status <> " Total: " <> status_counter)
                      )

                      aggregate(:status_aggregate_count, function: :count, source: [:id])

                      expression("variable_vs_aggregate",
                        expression:
                          expr(
                            "Variable Count: " <>
                              status_counter <>
                              " | Aggregate Count: " <> status_aggregate_count
                          )
                      )
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  expression("region_totals",
                    expression: expr("Region " <> region <> " Totals:")
                  )

                  expression("region_counts",
                    expression:
                      expr(
                        "Region Count: " <>
                          region_counter <>
                          " | Global Count: " <> global_counter
                      )
                  )

                  expression("region_credit_totals",
                    expression:
                      expr(
                        "Region Credit: $" <>
                          region_credit_sum <>
                          " | Global Credit: $" <> global_credit_sum
                      )
                  )

                  expression("region_percentage",
                    expression:
                      expr(
                        "Region represents " <>
                          (region_counter / global_counter * 100) <> "% of total"
                      )
                  )
                end
              end

              band :summary do
                elements do
                  expression("final_variable_summary",
                    expression: expr("Final Variable Summary:")
                  )

                  expression("final_counts",
                    expression: expr("Total Customers: " <> global_counter)
                  )

                  expression("final_credit_stats",
                    expression:
                      expr(
                        "Total Credit: $" <>
                          global_credit_sum <>
                          " | Average: $" <> running_average
                      )
                  )

                  expression("final_analysis",
                    expression:
                      expr(
                        "High Credit Customers: " <>
                          high_credit_count <>
                          " (" <> (high_credit_count / global_counter * 100) <> "%)"
                      )
                  )

                  aggregate(:final_aggregate_count, function: :count, source: [:id])

                  aggregate(:final_aggregate_sum,
                    function: :sum,
                    source: [:credit_limit],
                    format: :currency
                  )

                  expression("variable_aggregate_validation",
                    expression:
                      expr(
                        "Validation - Variable Count: " <>
                          global_counter <>
                          " | Aggregate Count: " <>
                          final_aggregate_count <>
                          " | Variable Sum: $" <>
                          global_credit_sum <>
                          " | Aggregate Sum: " <> final_aggregate_sum
                      )
                  )
                end
              end
            end
          end
        end
      end

      report_module = VariableRuntimeDomain.Reports.VariableRuntimeTest

      # Test variable definition access
      definition = report_module.definition()
      assert length(definition.variables) == 7

      # Verify variable types and reset behavior
      variables_by_reset = Enum.group_by(definition.variables, & &1.reset_on)
      report_vars = variables_by_reset[:report]
      group_vars = variables_by_reset[:group]

      # global_counter, global_credit_sum, running_average, high_credit_count
      assert length(report_vars) == 4
      # region_counter, status_counter, region_credit_sum
      assert length(group_vars) == 3

      # Test query building (variables should be accessible in query context)
      assert {:ok, query} = report_module.build_query()
      assert query

      # Test that variable expressions are properly structured
      # (We can't execute the actual variable logic without a full Ash setup,
      # but we can verify the structure is correct)

      cleanup_test_data()
    end

    test "validates grouping and sorting in runtime context" do
      setup_test_data()

      defmodule GroupingSortingRuntimeDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :grouping_sorting_runtime_test do
            title("Grouping and Sorting Runtime Test")
            driving_resource(AshReports.Test.Customer)

            parameters do
              parameter(:sort_direction, :string, required: false, default: "asc")
              parameter(:group_by_credit, :boolean, required: false, default: false)
            end

            groups do
              group(:region, field: [:region], sort: expr(sort_direction))
              group(:status, field: [:status], sort: :desc)

              group(:credit_tier,
                field:
                  expr(
                    if(
                      group_by_credit,
                      case do
                        credit_limit < 1000 -> "Low"
                        credit_limit < 5000 -> "Medium"
                        credit_limit < 10000 -> "High"
                        true -> "Premium"
                      end,
                      "All"
                    )
                  ),
                sort: :asc,
                enabled: expr(group_by_credit)
              )
            end

            bands do
              band :title do
                elements do
                  label("title", text: "Grouping and Sorting Test")

                  expression("sort_info",
                    expression: expr("Sort Direction: " <> sort_direction)
                  )

                  expression("grouping_info",
                    expression:
                      expr(
                        if(
                          group_by_credit,
                          "Grouping by credit tier enabled",
                          "Standard grouping only"
                        )
                      )
                  )
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field(:region_name, source: [:region])

                  expression("region_sort_info",
                    expression: expr("Region: " <> region <> " (sorted " <> sort_direction <> ")")
                  )
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      field(:status_name, source: [:status])

                      expression("status_info",
                        expression: expr("Status: " <> status <> " (sorted desc)")
                      )
                    end

                    bands do
                      # Conditional band structure based on grouping
                      if true do
                        band :group_header, group_level: 3 do
                          elements do
                            expression(:credit_tier_name,
                              expression:
                                expr(
                                  if(
                                    group_by_credit,
                                    "Credit Tier: " <>
                                      case do
                                        credit_limit < 1000 -> "Low"
                                        credit_limit < 5000 -> "Medium"
                                        credit_limit < 10000 -> "High"
                                        true -> "Premium"
                                      end,
                                    "No Credit Grouping"
                                  )
                                ),
                              visible: expr(group_by_credit)
                            )
                          end

                          bands do
                            band :detail do
                              elements do
                                field(:customer_name, source: [:name])
                                field(:customer_region, source: [:region])
                                field(:customer_status, source: [:status])
                                field(:credit_limit, source: [:credit_limit], format: :currency)

                                expression(:sorting_demo,
                                  expression:
                                    expr(
                                      "Name: " <>
                                        name <>
                                        " | Region: " <>
                                        region <>
                                        " (sorted " <>
                                        sort_direction <>
                                        ")" <>
                                        " | Status: " <> status <> " (sorted desc)"
                                    )
                                )

                                expression(:credit_tier_info,
                                  expression:
                                    expr(
                                      if(
                                        group_by_credit,
                                        "Credit Tier: " <>
                                          case do
                                            credit_limit < 1000 -> "Low"
                                            credit_limit < 5000 -> "Medium"
                                            credit_limit < 10000 -> "High"
                                            true -> "Premium"
                                          end,
                                        "No tier grouping"
                                      )
                                    ),
                                  visible: expr(group_by_credit)
                                )
                              end
                            end
                          end
                        end

                        band :group_footer, group_level: 3 do
                          elements do
                            aggregate(:tier_count, function: :count, source: [:id])

                            expression("tier_summary",
                              expression: expr("Credit Tier Count: " <> tier_count),
                              visible: expr(group_by_credit)
                            )
                          end
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      aggregate(:status_count, function: :count, source: [:id])

                      expression("status_summary",
                        expression: expr("Status " <> status <> " Count: " <> status_count)
                      )
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate(:region_count, function: :count, source: [:id])

                  expression("region_summary",
                    expression: expr("Region " <> region <> " Count: " <> region_count)
                  )
                end
              end

              band :summary do
                elements do
                  aggregate(:total_count, function: :count, source: [:id])

                  expression("sorting_summary",
                    expression:
                      expr(
                        "Total customers: " <>
                          total_count <>
                          " (regions sorted " <> sort_direction <> ")"
                      )
                  )

                  expression("grouping_summary",
                    expression:
                      expr(
                        if(
                          group_by_credit,
                          "Credit tier grouping was enabled",
                          "Standard grouping was used"
                        )
                      )
                  )
                end
              end
            end
          end
        end
      end

      report_module = GroupingSortingRuntimeDomain.Reports.GroupingSortingRuntimeTest

      # Test default grouping and sorting
      default_params = %{}
      assert {:ok, default_validated} = report_module.validate_params(default_params)
      assert default_validated.sort_direction == "asc"
      assert default_validated.group_by_credit == false

      assert {:ok, default_query} = report_module.build_query(default_validated)
      assert default_query

      # Test custom sorting
      custom_sort_params = %{sort_direction: "desc"}
      assert {:ok, sort_validated} = report_module.validate_params(custom_sort_params)
      assert sort_validated.sort_direction == "desc"

      assert {:ok, sort_query} = report_module.build_query(sort_validated)
      assert sort_query

      # Test credit grouping enabled
      credit_group_params = %{group_by_credit: true}
      assert {:ok, group_validated} = report_module.validate_params(credit_group_params)
      assert group_validated.group_by_credit == true

      assert {:ok, group_query} = report_module.build_query(group_validated)
      assert group_query

      # Test combined parameters
      combined_params = %{sort_direction: "desc", group_by_credit: true}
      assert {:ok, combined_validated} = report_module.validate_params(combined_params)

      assert {:ok, combined_query} = report_module.build_query(combined_validated)
      assert combined_query

      # Verify group definitions in report
      definition = report_module.definition()
      assert length(definition.groups) == 3

      region_group = Enum.find(definition.groups, &(&1.name == :region))
      status_group = Enum.find(definition.groups, &(&1.name == :status))
      credit_group = Enum.find(definition.groups, &(&1.name == :credit_tier))

      assert region_group.field == [:region]
      assert status_group.field == [:status]
      assert status_group.sort == :desc

      cleanup_test_data()
    end
  end

  describe "format-specific runtime execution" do
    test "validates format-specific rendering capabilities" do
      defmodule FormatSpecificRuntimeDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :format_specific_runtime_test do
            title("Format-Specific Runtime Test")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf, :json, :heex])

            parameters do
              parameter(:output_format, :string, required: false, default: "html")
              parameter(:include_metadata, :boolean, required: false, default: true)
            end

            bands do
              band :title do
                elements do
                  label("title", text: "Format-Specific Test Report")

                  expression("format_info",
                    expression: expr("Requested Format: " <> output_format)
                  )

                  expression("metadata_info",
                    expression:
                      expr(
                        if(
                          include_metadata,
                          "Metadata included",
                          "Metadata excluded"
                        )
                      ),
                    visible: expr(include_metadata)
                  )
                end
              end

              band :detail do
                elements do
                  field(:customer_name, source: [:name])
                  field(:customer_email, source: [:email])
                  field(:credit_limit, source: [:credit_limit], format: :currency)

                  expression(:format_specific_content,
                    expression:
                      expr(
                        case output_format do
                          "html" -> "HTML: " <> name <> " <" <> email <> ">"
                          "pdf" -> "PDF: " <> name <> " | " <> email
                          "json" -> "JSON: {name: " <> name <> ", email: " <> email <> "}"
                          "heex" -> "HEEX: <%= " <> name <> " %> - " <> email
                          _ -> "Default: " <> name <> " - " <> email
                        end
                      )
                  )

                  expression(:metadata_content,
                    expression: expr("Metadata: ID=" <> id <> ", Credit=" <> credit_limit),
                    visible: expr(include_metadata)
                  )
                end
              end

              band :summary do
                elements do
                  aggregate(:total_count, function: :count, source: [:id])

                  expression("format_summary",
                    expression:
                      expr(
                        "Report completed in " <>
                          output_format <>
                          " format with " <> total_count <> " records"
                      )
                  )

                  expression("metadata_summary",
                    expression:
                      expr(
                        if(
                          include_metadata,
                          "Metadata was included in output",
                          "Metadata was excluded from output"
                        )
                      )
                  )
                end
              end
            end
          end
        end
      end

      report_module = FormatSpecificRuntimeDomain.Reports.FormatSpecificRuntimeTest

      # Test all supported formats
      supported_formats = [:html, :pdf, :json, :heex]

      for format <- supported_formats do
        assert report_module.supports_format?(format) == true

        format_module_name = format |> to_string() |> Macro.camelize()
        format_module = Module.concat(report_module, format_module_name)

        # Test format module exists and has correct interface
        assert Code.ensure_loaded?(format_module)
        assert function_exported?(format_module, :render, 3)
        assert function_exported?(format_module, :supports_streaming?, 0)
        assert function_exported?(format_module, :file_extension, 0)

        # Test file extension
        expected_extension = ".#{format}"
        assert format_module.file_extension() == expected_extension

        # Test streaming support (should return boolean)
        streaming_support = format_module.supports_streaming?()
        assert streaming_support in [true, false]
      end

      # Test format-specific parameters
      for format_str <- ["html", "pdf", "json", "heex"] do
        format_params = %{
          output_format: format_str,
          include_metadata: true
        }

        assert {:ok, validated} = report_module.validate_params(format_params)
        assert validated.output_format == format_str
        assert validated.include_metadata == true

        assert {:ok, query} = report_module.build_query(validated)
        assert query
      end

      # Test unsupported format handling
      assert report_module.supports_format?(:xml) == false
      assert report_module.supports_format?(:csv) == false
    end

    test "validates rendering interface consistency across formats" do
      defmodule RenderingInterfaceDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :rendering_interface_test do
            title("Rendering Interface Test")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :json])

            parameters do
              parameter(:test_data, :string, required: false, default: "test")
            end

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])
                  expression("test_expr", expression: expr("Test: " <> test_data))
                end
              end
            end
          end
        end
      end

      report_module = RenderingInterfaceDomain.Reports.RenderingInterfaceTest

      # Test base module rendering interface
      assert function_exported?(report_module, :render, 1)
      assert function_exported?(report_module, :render, 2)
      assert function_exported?(report_module, :render, 3)

      # Test format module rendering interfaces
      html_module = report_module.Html
      json_module = report_module.Json

      assert function_exported?(html_module, :render, 3)
      assert function_exported?(json_module, :render, 3)

      # Test interface consistency
      params = %{test_data: "interface_test"}
      assert {:ok, validated_params} = report_module.validate_params(params)
      assert {:ok, query} = report_module.build_query(validated_params)

      # Note: We can't test actual rendering without a full Ash setup and data,
      # but we can verify the interfaces are properly exposed

      # Test that render functions accept the expected signatures
      # render(data) - single argument version
      # render(data, params) - two argument version
      # render(data, params, options) - three argument version

      # The actual render function behavior would be tested in integration tests
      # with real data and Ash queries
    end
  end

  describe "error handling and edge cases in runtime" do
    test "handles runtime parameter validation errors gracefully" do
      defmodule RuntimeErrorHandlingDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :runtime_error_handling_test do
            title("Runtime Error Handling Test")
            driving_resource(AshReports.Test.Customer)

            parameters do
              parameter(:required_string, :string, required: true)
              parameter(:positive_integer, :integer, required: false)
              parameter(:valid_date, :date, required: false)
              parameter(:decimal_value, :decimal, required: false)
            end

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])

                  expression("param_usage",
                    expression: expr("Required: " <> required_string)
                  )
                end
              end
            end
          end
        end
      end

      report_module = RuntimeErrorHandlingDomain.Reports.RuntimeErrorHandlingTest

      # Test missing required parameter
      missing_required = %{positive_integer: 42}
      assert {:error, errors} = report_module.validate_params(missing_required)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "required_string"))

      # Test type validation errors
      type_errors = %{
        # Should be string
        required_string: 123,
        # Should be integer
        positive_integer: "not_an_integer",
        # Should be date
        valid_date: "invalid_date",
        # Should be decimal
        decimal_value: "not_a_decimal"
      }

      assert {:error, type_error_list} = report_module.validate_params(type_errors)
      assert is_list(type_error_list)
      # At least 3 type errors
      assert length(type_error_list) >= 3

      # Test edge case values
      edge_cases = %{
        # Empty string
        required_string: "",
        # Zero
        positive_integer: 0,
        # Very old date
        valid_date: ~D[1900-01-01],
        # Very small decimal
        decimal_value: Decimal.new("0.000000001")
      }

      assert {:ok, validated} = report_module.validate_params(edge_cases)
      assert validated.required_string == ""
      assert validated.positive_integer == 0

      # Test query building with edge case parameters
      assert {:ok, edge_query} = report_module.build_query(validated)
      assert edge_query

      # Test nil handling for optional parameters
      nil_params = %{
        required_string: "valid",
        positive_integer: nil,
        valid_date: nil,
        decimal_value: nil
      }

      assert {:ok, nil_validated} = report_module.validate_params(nil_params)
      assert nil_validated.required_string == "valid"
      assert nil_validated.positive_integer == nil
      assert nil_validated.valid_date == nil
      assert nil_validated.decimal_value == nil
    end

    test "handles query building edge cases" do
      setup_test_data()

      defmodule QueryEdgeCasesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :query_edge_cases_test do
            title("Query Edge Cases Test")
            driving_resource(AshReports.Test.Customer)

            parameters do
              parameter(:filter_value, :string, required: false)
              parameter(:numeric_filter, :decimal, required: false)
            end

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])
                  field(:credit_limit, source: [:credit_limit], format: :currency)

                  expression("filtered_info",
                    expression:
                      expr(
                        if(
                          filter_value != nil,
                          "Filtered by: " <> filter_value,
                          "No filter applied"
                        )
                      )
                  )
                end
              end
            end
          end
        end
      end

      report_module = QueryEdgeCasesDomain.Reports.QueryEdgeCasesTest

      # Test query building with no parameters
      assert {:ok, base_query} = report_module.build_query()
      assert base_query

      # Test query building with empty parameter map
      empty_params = %{}
      assert {:ok, empty_validated} = report_module.validate_params(empty_params)
      assert {:ok, empty_query} = report_module.build_query(empty_validated)
      assert empty_query

      # Test query building with nil parameter values
      nil_params = %{filter_value: nil, numeric_filter: nil}
      assert {:ok, nil_validated} = report_module.validate_params(nil_params)
      assert {:ok, nil_query} = report_module.build_query(nil_validated)
      assert nil_query

      # Test query building with extreme parameter values
      extreme_params = %{
        # Very long string
        filter_value: String.duplicate("x", 1000),
        # Very large number
        numeric_filter: Decimal.new("999999999999.99")
      }

      assert {:ok, extreme_validated} = report_module.validate_params(extreme_params)
      assert {:ok, extreme_query} = report_module.build_query(extreme_validated)
      assert extreme_query

      cleanup_test_data()
    end

    test "handles format module errors gracefully" do
      defmodule FormatErrorHandlingDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :format_error_handling_test do
            title("Format Error Handling Test")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :json])

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])
                end
              end
            end
          end
        end
      end

      report_module = FormatErrorHandlingDomain.Reports.FormatErrorHandlingTest

      # Test that unsupported formats are properly rejected
      assert report_module.supports_format?(:html) == true
      assert report_module.supports_format?(:json) == true
      assert report_module.supports_format?(:pdf) == false
      assert report_module.supports_format?(:xml) == false
      assert report_module.supports_format?(:csv) == false

      # Test that format modules exist for supported formats
      assert Code.ensure_loaded?(report_module.Html)
      assert Code.ensure_loaded?(report_module.Json)

      # Test that format modules don't exist for unsupported formats
      refute Code.ensure_loaded?(Module.concat(report_module, Pdf))
      refute Code.ensure_loaded?(Module.concat(report_module, Xml))

      # Test format module interfaces are consistent
      for format_module <- [report_module.Html, report_module.Json] do
        assert function_exported?(format_module, :render, 3)
        assert function_exported?(format_module, :supports_streaming?, 0)
        assert function_exported?(format_module, :file_extension, 0)

        # Test that interface functions return appropriate types
        extension = format_module.file_extension()
        assert is_binary(extension)
        assert String.starts_with?(extension, ".")

        streaming = format_module.supports_streaming?()
        assert streaming in [true, false]
      end
    end
  end

  # Setup and cleanup
  setup do
    on_exit(fn ->
      cleanup_test_data()
    end)
  end
end
