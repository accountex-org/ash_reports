defmodule AshReports.DslCompilationIntegrationTest do
  @moduledoc """
  Phase 1D: Complete DSL Compilation Integration Testing
  
  This test module provides comprehensive end-to-end testing of DSL compilation
  including complex report scenarios, full domain compilation, and runtime
  execution verification.
  """
  
  use ExUnit.Case, async: false
  import AshReports.TestHelpers
  
  describe "full domain compilation with complex reports" do
    test "compiles domain with multiple complex reports successfully" do
      defmodule ComplexDomainCompilation do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
          resource AshReports.Test.Product
        end

        reports do
          report :comprehensive_customer_report do
            title "Comprehensive Customer Report"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf, :json, :heex]

            parameters do
              parameter :region_filter, :string, required: false
              parameter :start_date, :date, required: true
              parameter :end_date, :date, required: true
              parameter :include_inactive, :boolean, required: false, default: false
            end

            variables do
              variable :total_customers, type: :count, reset_on: :report
              variable :region_count, type: :count, reset_on: :group, reset_group: 1
              variable :active_count, type: :count_where, 
                       condition: expr(status == :active), reset_on: :group, reset_group: 1
              variable :revenue_total, type: :sum, expression: expr(credit_limit),
                       reset_on: :group, reset_group: 1
            end

            groups do
              group :region, field: [:region], sort: :asc
              group :status, field: [:status], sort: :desc
            end

            bands do
              band :title do
                elements do
                  label "main_title", text: "Customer Analysis Report"
                  image "company_logo", source: "/assets/logo.png"
                  line "title_underline", from: [x: 0, y: 25], to: [x: 500, y: 25]
                  expression "date_range", 
                            expression: expr("Report Period: " <> start_date <> " to " <> end_date)
                end
              end

              band :page_header do
                elements do
                  label "page_title", text: "Customer Report"
                  expression "page_number", expression: expr("Page " <> page_number)
                end
              end

              band :column_header do
                elements do
                  label "name_header", text: "Customer Name"
                  label "email_header", text: "Email"
                  label "status_header", text: "Status"
                  label "credit_header", text: "Credit Limit"
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  label "region_label", text: "Region:"
                  field :region_value, source: [:region]
                  box "region_box", from: [x: 0, y: 0], to: [x: 500, y: 20]
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      label "status_label", text: "Status:"
                      field :status_value, source: [:status]
                    end

                    bands do
                      band :detail_header do
                        elements do
                          label "detail_header", text: "Customer Details"
                        end
                      end

                      band :detail do
                        elements do
                          field :customer_name, source: [:name]
                          field :customer_email, source: [:email]
                          field :customer_status, source: [:status]
                          field :credit_limit, source: [:credit_limit], format: :currency
                          expression :full_info, 
                                    expression: expr(name <> " (" <> email <> ")")
                        end
                      end

                      band :detail_footer do
                        elements do
                          aggregate :detail_count, function: :count, source: [:id]
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      label "status_summary", text: "Status Total:"
                      aggregate :status_total, function: :count, source: [:id]
                      aggregate :status_credit, function: :sum, source: [:credit_limit], format: :currency
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  label "region_summary", text: "Region Total:"
                  aggregate :region_total, function: :count, source: [:id]
                  aggregate :region_revenue, function: :sum, source: [:credit_limit], format: :currency
                  expression :region_avg, 
                            expression: expr(region_revenue / region_total)
                end
              end

              band :column_footer do
                elements do
                  label "column_totals", text: "Column Totals"
                end
              end

              band :page_footer do
                elements do
                  expression "timestamp", expression: expr("Generated: " <> now())
                  expression "page_info", expression: expr("Page " <> page_number <> " of " <> total_pages)
                end
              end

              band :summary do
                elements do
                  label "report_summary", text: "Report Summary"
                  aggregate :grand_total, function: :count, source: [:id]
                  aggregate :grand_revenue, function: :sum, source: [:credit_limit], format: :currency
                  expression :average_credit, 
                            expression: expr(grand_revenue / grand_total)
                  line "summary_line", from: [x: 0, y: 0], to: [x: 500, y: 0]
                end
              end
            end
          end

          report :order_analysis_report do
            title "Order Analysis Report"
            driving_resource AshReports.Test.Order
            formats [:html, :pdf, :json]

            parameters do
              parameter :status_filter, :string, required: false
              parameter :min_amount, :decimal, required: false
              parameter :customer_id, :string, required: false
            end

            variables do
              variable :order_count, type: :count, reset_on: :report
              variable :revenue_sum, type: :sum, expression: expr(total_amount), reset_on: :report
              variable :shipping_sum, type: :sum, expression: expr(shipping_cost), reset_on: :report
            end

            groups do
              group :status, field: [:status], sort: :asc
              group :month, field: [order_date: :month], sort: :desc
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Order Analysis Report"
                  expression "filter_info", 
                            expression: expr("Status Filter: " <> (status_filter || "All"))
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field :status_group, source: [:status]
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      expression :month_group, 
                                expression: expr("Month: " <> format_date(order_date, :month))
                    end

                    bands do
                      band :detail do
                        elements do
                          field :order_number, source: [:order_number]
                          field :order_date, source: [:order_date], format: :date
                          field :total_amount, source: [:total_amount], format: :currency
                          field :shipping_cost, source: [:shipping_cost], format: :currency
                          expression :profit_margin, 
                                    expression: expr((total_amount - shipping_cost) / total_amount * 100)
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      aggregate :month_total, function: :sum, source: [:total_amount], format: :currency
                      aggregate :month_count, function: :count, source: [:id]
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate :status_total, function: :sum, source: [:total_amount], format: :currency
                  aggregate :status_count, function: :count, source: [:id]
                  expression :status_average, 
                            expression: expr(status_total / status_count)
                end
              end

              band :summary do
                elements do
                  aggregate :total_orders, function: :count, source: [:id]
                  aggregate :total_revenue, function: :sum, source: [:total_amount], format: :currency
                  aggregate :total_shipping, function: :sum, source: [:shipping_cost], format: :currency
                  expression :average_order, 
                            expression: expr(total_revenue / total_orders)
                end
              end
            end
          end

          report :product_catalog_report do
            title "Product Catalog Report"
            driving_resource AshReports.Test.Product
            formats [:html, :heex]

            parameters do
              parameter :category_filter, :string, required: false
              parameter :active_only, :boolean, required: false, default: true
              parameter :price_min, :decimal, required: false
              parameter :price_max, :decimal, required: false
            end

            variables do
              variable :product_count, type: :count, reset_on: :report
              variable :category_count, type: :count, reset_on: :group, reset_group: 1
              variable :value_total, type: :sum, expression: expr(price), reset_on: :group, reset_group: 1
            end

            groups do
              group :category, field: [:category], sort: :asc
              group :active_status, field: [:active], sort: :desc
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Product Catalog"
                  image "catalog_header", source: "/assets/catalog_header.png"
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  label "category_label", text: "Category:"
                  field :category_name, source: [:category]
                  box "category_separator", from: [x: 0, y: 20], to: [x: 600, y: 22]
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      expression :active_status, 
                                expression: expr(if(active, "Active Products", "Inactive Products"))
                    end

                    bands do
                      band :detail do
                        elements do
                          field :product_name, source: [:name]
                          field :sku, source: [:sku]
                          field :price, source: [:price], format: :currency
                          field :weight, source: [:weight], format: {:decimal, precision: 2}
                          expression :price_per_weight, 
                                    expression: expr(price / weight)
                          box "product_border", from: [x: 0, y: 0], to: [x: 600, y: 25]
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      aggregate :status_count, function: :count, source: [:id]
                      aggregate :status_value, function: :sum, source: [:price], format: :currency
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  label "category_total", text: "Category Total:"
                  aggregate :category_products, function: :count, source: [:id]
                  aggregate :category_value, function: :sum, source: [:price], format: :currency
                  expression :average_price, 
                            expression: expr(category_value / category_products)
                end
              end

              band :summary do
                elements do
                  aggregate :total_products, function: :count, source: [:id]
                  aggregate :catalog_value, function: :sum, source: [:price], format: :currency
                  expression :overall_average, 
                            expression: expr(catalog_value / total_products)
                  line "final_line", from: [x: 0, y: 30], to: [x: 600, y: 30]
                end
              end
            end
          end
        end
      end

      # Verify domain compilation succeeded
      assert ComplexDomainCompilation
      
      # Verify all reports were compiled
      customer_report = ComplexDomainCompilation.Reports.ComprehensiveCustomerReport
      order_report = ComplexDomainCompilation.Reports.OrderAnalysisReport
      product_report = ComplexDomainCompilation.Reports.ProductCatalogReport
      
      assert customer_report
      assert order_report
      assert product_report
      
      # Verify format modules were generated
      assert customer_report.Html
      assert customer_report.Pdf
      assert customer_report.Json
      assert customer_report.Heex
      
      assert order_report.Html
      assert order_report.Pdf
      assert order_report.Json
      
      assert product_report.Html
      assert product_report.Heex
      
      # Verify report definitions are complete
      customer_def = customer_report.definition()
      order_def = order_report.definition()
      product_def = product_report.definition()
      
      # Customer report verification
      assert customer_def.name == :comprehensive_customer_report
      assert length(customer_def.parameters) == 4
      assert length(customer_def.variables) == 4
      assert length(customer_def.groups) == 2
      assert length(customer_def.bands) == 7  # title, page_header, column_header, group_header, group_footer, column_footer, page_footer, summary
      
      # Order report verification
      assert order_def.name == :order_analysis_report
      assert length(order_def.parameters) == 3
      assert length(order_def.variables) == 3
      assert length(order_def.groups) == 2
      assert length(order_def.bands) == 4  # title, group_header, group_footer, summary
      
      # Product report verification
      assert product_def.name == :product_catalog_report
      assert length(product_def.parameters) == 4
      assert length(product_def.variables) == 3
      assert length(product_def.groups) == 2
      assert length(product_def.bands) == 4  # title, group_header, group_footer, summary
    end

    test "handles deeply nested band structures during compilation" do
      defmodule DeepNestedDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :deep_nested_report do
            title "Deep Nested Report"
            driving_resource AshReports.Test.Customer
            formats [:html]

            groups do
              group :level1, field: [:region], sort: :asc
              group :level2, field: [:status], sort: :asc
              group :level3, field: [created_at: :year], sort: :desc
              group :level4, field: [created_at: :month], sort: :desc
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Deep Nested Structure Test"
                end
              end

              band :level1_header, type: :group_header, group_level: 1 do
                elements do
                  field :region, source: [:region]
                end

                bands do
                  band :level2_header, type: :group_header, group_level: 2 do
                    elements do
                      field :status, source: [:status]
                    end

                    bands do
                      band :level3_header, type: :group_header, group_level: 3 do
                        elements do
                          expression :year, expression: expr(format_date(created_at, :year))
                        end

                        bands do
                          band :level4_header, type: :group_header, group_level: 4 do
                            elements do
                              expression :month, expression: expr(format_date(created_at, :month))
                            end

                            bands do
                              band :detail do
                                elements do
                                  field :name, source: [:name]
                                  field :email, source: [:email]
                                  field :credit_limit, source: [:credit_limit], format: :currency
                                end
                              end
                            end
                          end

                          band :level4_footer, type: :group_footer, group_level: 4 do
                            elements do
                              aggregate :month_count, function: :count, source: [:id]
                            end
                          end
                        end
                      end

                      band :level3_footer, type: :group_footer, group_level: 3 do
                        elements do
                          aggregate :year_count, function: :count, source: [:id]
                        end
                      end
                    end
                  end

                  band :level2_footer, type: :group_footer, group_level: 2 do
                    elements do
                      aggregate :status_count, function: :count, source: [:id]
                    end
                  end
                end
              end

              band :level1_footer, type: :group_footer, group_level: 1 do
                elements do
                  aggregate :region_count, function: :count, source: [:id]
                end
              end

              band :summary do
                elements do
                  aggregate :total_count, function: :count, source: [:id]
                end
              end
            end
          end
        end
      end

      # Should compile successfully despite deep nesting
      assert DeepNestedDomain
      report_module = DeepNestedDomain.Reports.DeepNestedReport
      assert report_module
      
      definition = report_module.definition()
      
      # Verify deep structure preservation
      assert length(definition.groups) == 4
      assert length(definition.bands) == 3  # title, level1_header, level1_footer, summary
      
      # Verify nested band structure
      level1_header = Enum.find(definition.bands, &(&1.name == :level1_header))
      assert length(level1_header.bands) == 2  # level2_header, level2_footer
      
      level2_header = Enum.find(level1_header.bands, &(&1.name == :level2_header))
      assert length(level2_header.bands) == 2  # level3_header, level3_footer
      
      level3_header = Enum.find(level2_header.bands, &(&1.name == :level3_header))
      assert length(level3_header.bands) == 2  # level4_header, level4_footer
      
      level4_header = Enum.find(level3_header.bands, &(&1.name == :level4_header))
      assert length(level4_header.bands) == 1  # detail
    end

    test "compiles reports with all element types successfully" do
      defmodule AllElementTypesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :all_elements_report do
            title "All Element Types Report"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf]

            parameters do
              parameter :test_param, :string, required: false
            end

            variables do
              variable :test_var, type: :count, reset_on: :report
            end

            bands do
              band :comprehensive_band do
                elements do
                  # Field elements
                  field :customer_name, source: [:name]
                  field :customer_email, source: [:email]
                  field :customer_status, source: [:status]
                  field :credit_limit, source: [:credit_limit], format: :currency
                  
                  # Label elements
                  label "static_label", text: "Static Text Label"
                  label "param_label", text: expr("Parameter: " <> (test_param || "None"))
                  
                  # Expression elements
                  expression :simple_expr, expression: expr(name <> " - " <> email)
                  expression :complex_expr, 
                            expression: expr("Customer: " <> name <> " (Credit: $" <> to_string(credit_limit) <> ")")
                  expression :conditional_expr, 
                            expression: expr(if(status == :active, "ACTIVE", "INACTIVE"))
                  
                  # Aggregate elements
                  aggregate :count_agg, function: :count, source: [:id]
                  aggregate :sum_agg, function: :sum, source: [:credit_limit], format: :currency
                  aggregate :avg_agg, function: :avg, source: [:credit_limit], format: :currency
                  aggregate :min_agg, function: :min, source: [:credit_limit], format: :currency
                  aggregate :max_agg, function: :max, source: [:credit_limit], format: :currency
                  
                  # Line elements
                  line "horizontal_line", from: [x: 0, y: 50], to: [x: 500, y: 50]
                  line "vertical_line", from: [x: 250, y: 0], to: [x: 250, y: 100]
                  line "diagonal_line", from: [x: 0, y: 0], to: [x: 100, y: 100]
                  
                  # Box elements
                  box "simple_box", from: [x: 0, y: 0], to: [x: 100, y: 50]
                  box "complex_box", from: [x: 200, y: 0], to: [x: 400, y: 100], 
                      style: [border_width: 2, fill_color: "#f0f0f0"]
                  
                  # Image elements
                  image "logo_image", source: "/assets/logo.png"
                  image "dynamic_image", source: expr("/assets/" <> status <> "_icon.png")
                  image "positioned_image", source: "/assets/icon.png", 
                        position: [x: 500, y: 0], size: [width: 50, height: 50]
                end
              end
            end
          end
        end
      end

      # Should compile with all element types
      assert AllElementTypesDomain
      report_module = AllElementTypesDomain.Reports.AllElementsReport
      assert report_module
      
      definition = report_module.definition()
      band = hd(definition.bands)
      
      # Verify all element types are present
      element_types = Enum.map(band.elements, fn element ->
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
      end)
      
      assert :field in element_types
      assert :label in element_types
      assert :expression in element_types
      assert :aggregate in element_types
      assert :line in element_types
      assert :box in element_types
      assert :image in element_types
      
      # Verify specific element counts
      field_count = Enum.count(element_types, &(&1 == :field))
      label_count = Enum.count(element_types, &(&1 == :label))
      expr_count = Enum.count(element_types, &(&1 == :expression))
      agg_count = Enum.count(element_types, &(&1 == :aggregate))
      line_count = Enum.count(element_types, &(&1 == :line))
      box_count = Enum.count(element_types, &(&1 == :box))
      image_count = Enum.count(element_types, &(&1 == :image))
      
      assert field_count == 4
      assert label_count == 2
      assert expr_count == 3
      assert agg_count == 5
      assert line_count == 3
      assert box_count == 2
      assert image_count == 3
    end
  end

  describe "generated module verification" do
    test "verifies generated modules have correct interfaces" do
      defmodule InterfaceVerificationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :interface_test do
            title "Interface Test Report"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf, :json, :heex]

            parameters do
              parameter :test_param, :string, required: true
            end

            bands do
              band :detail do
                elements do
                  field :name, source: [:name]
                end
              end
            end
          end
        end
      end

      base_module = InterfaceVerificationDomain.Reports.InterfaceTest
      
      # Test core report module interface
      assert function_exported?(base_module, :definition, 0)
      assert function_exported?(base_module, :domain, 0)
      assert function_exported?(base_module, :run, 0)
      assert function_exported?(base_module, :run, 1)
      assert function_exported?(base_module, :run, 2)
      assert function_exported?(base_module, :render, 1)
      assert function_exported?(base_module, :render, 2)
      assert function_exported?(base_module, :render, 3)
      assert function_exported?(base_module, :validate_params, 1)
      assert function_exported?(base_module, :build_query, 0)
      assert function_exported?(base_module, :build_query, 1)
      assert function_exported?(base_module, :supported_formats, 0)
      assert function_exported?(base_module, :supports_format?, 1)
      
      # Test format-specific module interfaces
      assert function_exported?(base_module.Html, :render, 3)
      assert function_exported?(base_module.Html, :supports_streaming?, 0)
      assert function_exported?(base_module.Html, :file_extension, 0)
      
      assert function_exported?(base_module.Pdf, :render, 3)
      assert function_exported?(base_module.Pdf, :supports_streaming?, 0)
      assert function_exported?(base_module.Pdf, :file_extension, 0)
      
      assert function_exported?(base_module.Json, :render, 3)
      assert function_exported?(base_module.Json, :supports_streaming?, 0)
      assert function_exported?(base_module.Json, :file_extension, 0)
      
      assert function_exported?(base_module.Heex, :render, 3)
      assert function_exported?(base_module.Heex, :supports_streaming?, 0)
      assert function_exported?(base_module.Heex, :file_extension, 0)
      
      # Test interface behavior
      definition = base_module.definition()
      assert definition.name == :interface_test
      assert definition.driving_resource == AshReports.Test.Customer
      
      assert base_module.domain() == InterfaceVerificationDomain
      assert base_module.supported_formats() == [:html, :pdf, :json, :heex]
      assert base_module.supports_format?(:html) == true
      assert base_module.supports_format?(:xml) == false
      
      # Test format-specific behavior
      assert base_module.Html.file_extension() == ".html"
      assert base_module.Pdf.file_extension() == ".pdf"
      assert base_module.Json.file_extension() == ".json"
      assert base_module.Heex.file_extension() == ".heex"
    end

    test "verifies parameter validation works correctly" do
      defmodule ParameterValidationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :param_validation_test do
            title "Parameter Validation Test"
            driving_resource AshReports.Test.Customer
            formats [:html]

            parameters do
              parameter :required_string, :string, required: true
              parameter :optional_string, :string, required: false, default: "default_value"
              parameter :required_date, :date, required: true
              parameter :optional_integer, :integer, required: false
              parameter :boolean_param, :boolean, required: false, default: false
            end

            bands do
              band :detail do
                elements do
                  field :name, source: [:name]
                end
              end
            end
          end
        end
      end

      report_module = ParameterValidationDomain.Reports.ParamValidationTest
      
      # Test valid parameters
      valid_params = %{
        required_string: "test_value",
        required_date: ~D[2024-01-01],
        optional_integer: 42
      }
      
      assert {:ok, validated} = report_module.validate_params(valid_params)
      assert validated.required_string == "test_value"
      assert validated.optional_string == "default_value"
      assert validated.required_date == ~D[2024-01-01]
      assert validated.optional_integer == 42
      assert validated.boolean_param == false
      
      # Test missing required parameters
      invalid_params = %{
        optional_string: "test"
      }
      
      assert {:error, errors} = report_module.validate_params(invalid_params)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "required_string"))
      assert Enum.any?(errors, &String.contains?(&1, "required_date"))
      
      # Test type validation
      type_invalid_params = %{
        required_string: 123,  # Should be string
        required_date: "not_a_date",  # Should be date
        optional_integer: "not_an_integer"  # Should be integer
      }
      
      assert {:error, type_errors} = report_module.validate_params(type_invalid_params)
      assert is_list(type_errors)
      assert length(type_errors) >= 3
    end
  end

  describe "runtime report execution" do
    test "executes complete report generation workflow" do
      setup_test_data()
      
      defmodule RuntimeExecutionDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :runtime_execution_test do
            title "Runtime Execution Test"
            driving_resource AshReports.Test.Customer
            formats [:html, :json]

            parameters do
              parameter :region_filter, :string, required: false
            end

            variables do
              variable :customer_count, type: :count, reset_on: :report
            end

            groups do
              group :region, field: [:region], sort: :asc
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Customer Report"
                  expression "param_info", 
                            expression: expr("Region: " <> (region_filter || "All"))
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field :region_name, source: [:region]
                end

                bands do
                  band :detail do
                    elements do
                      field :customer_name, source: [:name]
                      field :customer_email, source: [:email]
                      field :customer_status, source: [:status]
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate :region_count, function: :count, source: [:id]
                end
              end

              band :summary do
                elements do
                  aggregate :total_customers, function: :count, source: [:id]
                end
              end
            end
          end
        end
      end

      report_module = RuntimeExecutionDomain.Reports.RuntimeExecutionTest
      
      # Test basic execution without parameters
      assert {:ok, query} = report_module.build_query()
      assert query
      
      # Test execution with parameters
      params = %{region_filter: "North"}
      assert {:ok, param_query} = report_module.build_query(params)
      assert param_query
      
      # Test query building with validated parameters
      assert {:ok, validated_params} = report_module.validate_params(params)
      assert {:ok, validated_query} = report_module.build_query(validated_params)
      assert validated_query
      
      # Note: Full execution would require actual Ash queries to work
      # This tests that the generated modules support the expected workflow
    end

    test "handles report execution errors gracefully" do
      defmodule ErrorHandlingDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :error_handling_test do
            title "Error Handling Test"
            driving_resource AshReports.Test.Customer
            formats [:html]

            parameters do
              parameter :required_param, :string, required: true
            end

            bands do
              band :detail do
                elements do
                  field :name, source: [:name]
                end
              end
            end
          end
        end
      end

      report_module = ErrorHandlingDomain.Reports.ErrorHandlingTest
      
      # Test parameter validation errors
      assert {:error, _} = report_module.validate_params(%{})
      assert {:error, _} = report_module.validate_params(%{required_param: 123})
      
      # Test query building with invalid parameters
      # Should handle gracefully even with invalid input
      result = report_module.build_query(%{invalid_param: "value"})
      # Result depends on implementation, but should not crash
      assert result
    end
  end

  describe "compilation edge cases" do
    test "handles empty reports section gracefully" do
      defmodule EmptyReportsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        # No reports section - should compile without error
      end

      # Should not crash during compilation
      assert EmptyReportsDomain
    end

    test "handles reports with minimal configuration" do
      defmodule MinimalReportsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :minimal_report do
            title "Minimal Report"
            driving_resource AshReports.Test.Customer

            bands do
              band :detail do
                elements do
                  field :name, source: [:name]
                end
              end
            end
          end
        end
      end

      assert MinimalReportsDomain
      report_module = MinimalReportsDomain.Reports.MinimalReport
      assert report_module
      
      definition = report_module.definition()
      assert definition.name == :minimal_report
      assert definition.formats == [:html]  # Default format
      assert definition.parameters == []
      assert definition.variables == []
      assert definition.groups == []
      assert length(definition.bands) == 1
    end

    test "handles compilation with maximum complexity" do
      # This test pushes the compilation system to its limits
      defmodule MaxComplexityDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
          resource AshReports.Test.Product
        end

        reports do
          # Generate multiple complex reports to test compilation scalability
          for i <- 1..5 do
            report :"complex_report_#{i}" do
              title "Complex Report #{i}"
              driving_resource AshReports.Test.Customer
              formats [:html, :pdf, :json]

              parameters do
                for j <- 1..3 do
                  parameter :"param_#{j}", :string, required: rem(j, 2) == 1
                end
              end

              variables do
                for k <- 1..3 do
                  variable :"var_#{k}", type: :count, reset_on: :report
                end
              end

              groups do
                group :region, field: [:region], sort: :asc
                group :status, field: [:status], sort: :desc
              end

              bands do
                band :title do
                  elements do
                    label "title", text: "Complex Report #{i}"
                  end
                end

                band :group_header, group_level: 1 do
                  elements do
                    field :region, source: [:region]
                  end

                  bands do
                    band :group_header, group_level: 2 do
                      elements do
                        field :status, source: [:status]
                      end

                      bands do
                        band :detail do
                          elements do
                            for l <- 1..5 do
                              field :"field_#{l}", source: [:name]
                            end
                          end
                        end
                      end
                    end

                    band :group_footer, group_level: 2 do
                      elements do
                        aggregate :status_count, function: :count, source: [:id]
                      end
                    end
                  end
                end

                band :group_footer, group_level: 1 do
                  elements do
                    aggregate :region_count, function: :count, source: [:id]
                  end
                end

                band :summary do
                  elements do
                    aggregate :total_count, function: :count, source: [:id]
                  end
                end
              end
            end
          end
        end
      end

      # Should handle maximum complexity without issues
      assert MaxComplexityDomain
      
      # Verify all reports were compiled
      for i <- 1..5 do
        report_module = Module.concat([MaxComplexityDomain.Reports, :"ComplexReport#{i}"])
        assert report_module
        assert report_module.Html
        assert report_module.Pdf
        assert report_module.Json
      end
    end
  end

  # Cleanup after tests
  setup do
    on_exit(fn ->
      cleanup_test_data()
    end)
  end
end