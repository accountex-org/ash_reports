defmodule AshReports.Transformers.BuildReportModulesTest do
  use ExUnit.Case, async: false

  alias AshReports.Transformers.BuildReportModules
  alias Spark.Dsl.Transformer

  describe "BuildReportModules transformer" do
    test "transforms DSL state by generating report modules" do
      # Create a test domain with a report
      defmodule TestDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :test_report do
            title("Test Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf])

            bands do
              band :title do
                type :title

                elements do
                  label("Report Title", text: "Test Report")
                end
              end

              band :detail do
                type :detail

                elements do
                  field(:name, source: [:name])
                  field(:email, source: [:email])
                end
              end
            end
          end
        end
      end

      # Verify the report module was created
      assert TestDomain.Reports.TestReport
      assert TestDomain.Reports.Module.concat(TestReport, Html)
      assert TestDomain.Reports.Module.concat(TestReport, Pdf)

      # Test the generated module interface
      report = TestDomain.Reports.TestReport.definition()
      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.driving_resource == AshReports.Test.Customer

      assert TestDomain.Reports.TestReport.domain() == TestDomain
      assert TestDomain.Reports.TestReport.supported_formats() == [:html, :pdf]
      assert TestDomain.Reports.TestReport.supports_format?(:html) == true
      assert TestDomain.Reports.TestReport.supports_format?(:json) == false
    end

    test "generates format-specific modules with correct interfaces" do
      defmodule TestDomainFormats do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :format_test do
            title("Format Test Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf, :heex, :json])

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

      # Test HTML module
      html_module = TestDomainFormats.Reports.Module.concat(FormatTest, Html)
      assert function_exported?(html_module, :render, 3)
      assert function_exported?(html_module, :supports_streaming?, 0)
      assert function_exported?(html_module, :file_extension, 0)
      assert html_module.file_extension() == ".html"
      assert html_module.supports_streaming?() == true

      # Test PDF module
      pdf_module = TestDomainFormats.Reports.Module.concat(FormatTest, Pdf)
      assert pdf_module.file_extension() == ".pdf"
      assert pdf_module.supports_streaming?() == true

      # Test HEEX module
      heex_module = TestDomainFormats.Reports.Module.concat(FormatTest, Heex)
      assert heex_module.file_extension() == ".heex"
      assert heex_module.supports_streaming?() == true

      # Test JSON module
      json_module = TestDomainFormats.Reports.Module.concat(FormatTest, Json)
      assert json_module.file_extension() == ".json"
      # JSON needs full structure
      assert json_module.supports_streaming?() == false
    end

    test "persists report data in DSL state" do
      # Create a minimal domain to test DSL state manipulation
      dsl_state =
        Spark.Dsl.Extension.build_entity_entities(
          AshReports.Domain,
          [],
          :reports,
          :report,
          name: :state_test,
          title: "State Test Report",
          driving_resource: AshReports.Test.Customer,
          bands: [
            %AshReports.Band{
              name: :detail,
              type: :detail,
              elements: [
                %AshReports.Element.Field{
                  name: :name,
                  source: [:name]
                }
              ]
            }
          ]
        )
        |> elem(1)
        |> Transformer.persist(:module, TestModule)

      # Apply the transformer
      {:ok, transformed_state} = BuildReportModules.transform(dsl_state)

      # Verify persisted data
      reports = Transformer.get_persisted(transformed_state, :ash_reports)
      assert length(reports) == 1
      assert hd(reports).name == :state_test

      modules = Transformer.get_persisted(transformed_state, :ash_reports_modules)
      assert is_map(modules)
      assert Map.has_key?(modules, :state_test)
    end

    test "handles multiple reports in single domain" do
      defmodule MultiReportDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
        end

        reports do
          report :customer_report do
            title("Customer Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])
                end
              end
            end
          end

          report :order_report do
            title("Order Report")
            driving_resource(AshReports.Test.Order)

            bands do
              band :detail do
                elements do
                  field(:amount, source: [:amount])
                end
              end
            end
          end
        end
      end

      # Verify both report modules exist
      assert MultiReportDomain.Reports.CustomerReport
      assert MultiReportDomain.Reports.OrderReport

      # Verify they have different configurations
      customer_def = MultiReportDomain.Reports.CustomerReport.definition()
      order_def = MultiReportDomain.Reports.OrderReport.definition()

      assert customer_def.name == :customer_report
      assert order_def.name == :order_report
      assert customer_def.driving_resource == AshReports.Test.Customer
      assert order_def.driving_resource == AshReports.Test.Order
    end

    test "generates modules with correct parameter validation" do
      defmodule ParameterDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :param_test do
            title("Parameter Test Report")
            driving_resource(AshReports.Test.Customer)

            parameters do
              parameter(:start_date, :date, required: true)
              parameter(:end_date, :date, required: true)
              parameter(:category, :string, required: false)
            end

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

      report_module = ParameterDomain.Reports.ParamTest

      # Test parameter validation interface exists
      assert function_exported?(report_module, :validate_params, 1)

      # The actual validation will be tested in ParameterValidator tests
      # Here we just verify the interface is present
    end

    test "generates modules with query building capabilities" do
      defmodule QueryDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :query_test do
            title("Query Test Report")
            driving_resource(AshReports.Test.Customer)

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

      report_module = QueryDomain.Reports.QueryTest

      # Test query building interface exists
      assert function_exported?(report_module, :build_query, 0)
      assert function_exported?(report_module, :build_query, 1)

      # The actual query building will be tested in QueryBuilder tests
      # Here we just verify the interface is present
    end

    test "transformer execution order is correct" do
      # Test that BuildReportModules runs after all verifiers
      assert BuildReportModules.after?(AshReports.Verifiers.ValidateReports) == true
      assert BuildReportModules.after?(AshReports.Verifiers.ValidateBands) == true
      assert BuildReportModules.after?(AshReports.Verifiers.ValidateElements) == true
      assert BuildReportModules.before?(SomeOtherTransformer) == false
    end

    test "handles empty reports section gracefully" do
      defmodule EmptyDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        # No reports section
      end

      # Should not crash and should work with empty reports
      assert EmptyDomain.__spark_dsl_config__()
    end

    test "module generation respects naming conventions" do
      defmodule NamingDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :snake_case_report do
            title("Snake Case Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  field(:name, source: [:name])
                end
              end
            end
          end

          report :camelCaseReport do
            title("Camel Case Report")
            driving_resource(AshReports.Test.Customer)

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

      # Verify proper PascalCase module naming
      assert NamingDomain.Reports.SnakeCaseReport
      assert NamingDomain.Reports.CamelCaseReport

      # Verify the original names are preserved in definitions
      assert NamingDomain.Reports.SnakeCaseReport.definition().name == :snake_case_report
      assert NamingDomain.Reports.CamelCaseReport.definition().name == :camelCaseReport
    end
  end

  describe "format-specific module generation" do
    test "html format modules implement renderer behavior" do
      defmodule HtmlDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :html_test do
            title("HTML Test Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html])

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

      html_module = HtmlDomain.Reports.HtmlTest.Html

      # Test that it implements the AshReports.Renderer behavior
      behaviours = html_module.__info__(:attributes) |> Keyword.get(:behaviour, [])
      assert AshReports.Renderer in behaviours

      # Test required callbacks exist
      assert function_exported?(html_module, :render, 3)
      assert function_exported?(html_module, :supports_streaming?, 0)
      assert function_exported?(html_module, :file_extension, 0)
    end

    test "all format modules have consistent interfaces" do
      defmodule AllFormatsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :all_formats do
            title("All Formats Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf, :heex, :json])

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

      base_module = AllFormatsDomain.Reports.AllFormats
      formats = [:html, :pdf, :heex, :json]

      for format <- formats do
        format_module_name = format |> to_string() |> Macro.camelize()
        format_module = Module.concat(base_module, format_module_name)

        # All format modules should exist
        assert format_module

        # All should implement the same interface
        assert function_exported?(format_module, :render, 3)
        assert function_exported?(format_module, :supports_streaming?, 0)
        assert function_exported?(format_module, :file_extension, 0)

        # File extensions should be correct
        expected_extension =
          case format do
            :html -> ".html"
            :pdf -> ".pdf"
            :heex -> ".heex"
            :json -> ".json"
          end

        assert format_module.file_extension() == expected_extension
      end
    end
  end

  describe "error handling" do
    test "transformer handles invalid DSL state gracefully" do
      # Create an invalid DSL state (missing required fields)
      invalid_state =
        %Spark.Dsl.State{}
        |> Transformer.persist(:module, InvalidModule)

      # Transformer should handle this gracefully
      result = BuildReportModules.transform(invalid_state)
      assert {:ok, _} = result
    end
  end

  describe "DSL state manipulation" do
    test "transformer correctly manipulates DSL state through lifecycle" do
      # Create initial DSL state with multiple reports
      initial_reports = [
        %AshReports.Report{
          name: :first_report,
          title: "First Report",
          driving_resource: AshReports.Test.Customer,
          formats: [:html, :pdf],
          bands: [
            %AshReports.Band{
              name: :detail,
              type: :detail,
              elements: [
                %AshReports.Element.Field{
                  name: :name,
                  source: [:name]
                }
              ]
            }
          ]
        },
        %AshReports.Report{
          name: :second_report,
          title: "Second Report",
          driving_resource: AshReports.Test.Order,
          formats: [:json],
          bands: [
            %AshReports.Band{
              name: :detail,
              type: :detail,
              elements: [
                %AshReports.Element.Field{
                  name: :amount,
                  source: [:amount]
                }
              ]
            }
          ]
        }
      ]

      # Simulate DSL state after other transformers have run
      dsl_state =
        %Spark.Dsl.State{}
        |> Transformer.persist(:module, TestStateModule)
        |> Transformer.persist(:ash_reports_parsed, initial_reports)

      # Apply transformer
      {:ok, transformed_state} = BuildReportModules.transform(dsl_state)

      # Verify DSL state was correctly updated
      persisted_reports = Transformer.get_persisted(transformed_state, :ash_reports)
      assert length(persisted_reports) == 2
      assert Enum.find(persisted_reports, &(&1.name == :first_report))
      assert Enum.find(persisted_reports, &(&1.name == :second_report))

      # Verify module mapping was created
      module_map = Transformer.get_persisted(transformed_state, :ash_reports_modules)
      assert is_map(module_map)
      assert Map.has_key?(module_map, :first_report)
      assert Map.has_key?(module_map, :second_report)
    end

    test "transformer preserves existing DSL state data" do
      # Create DSL state with existing persisted data
      existing_data = %{some: "existing", data: "preserved"}

      initial_dsl_state =
        %Spark.Dsl.State{}
        |> Transformer.persist(:module, TestPreserveModule)
        |> Transformer.persist(:existing_key, existing_data)
        |> Transformer.persist(:ash_reports_parsed, [
          %AshReports.Report{
            name: :preserve_test,
            title: "Preserve Test",
            driving_resource: AshReports.Test.Customer,
            bands: [
              %AshReports.Band{name: :detail, type: :detail, elements: []}
            ]
          }
        ])

      # Apply transformer
      {:ok, final_state} = BuildReportModules.transform(initial_dsl_state)

      # Verify existing data is preserved
      preserved_data = Transformer.get_persisted(final_state, :existing_key)
      assert preserved_data == existing_data

      # Verify new data was added
      reports = Transformer.get_persisted(final_state, :ash_reports)
      assert length(reports) == 1

      modules = Transformer.get_persisted(final_state, :ash_reports_modules)
      assert is_map(modules)
    end

    test "transformer handles edge cases in module generation" do
      # Test with report names that need special handling
      edge_case_reports = [
        %AshReports.Report{
          name: :report_with_underscores,
          title: "Report With Underscores",
          driving_resource: AshReports.Test.Customer,
          bands: [%AshReports.Band{name: :detail, type: :detail, elements: []}]
        },
        %AshReports.Report{
          name: :ReportWithCamelCase,
          title: "Report With CamelCase",
          driving_resource: AshReports.Test.Customer,
          bands: [%AshReports.Band{name: :detail, type: :detail, elements: []}]
        },
        %AshReports.Report{
          name: :report123,
          title: "Report With Numbers",
          driving_resource: AshReports.Test.Customer,
          bands: [%AshReports.Band{name: :detail, type: :detail, elements: []}]
        }
      ]

      dsl_state =
        %Spark.Dsl.State{}
        |> Transformer.persist(:module, EdgeCaseModule)
        |> Transformer.persist(:ash_reports_parsed, edge_case_reports)

      {:ok, transformed_state} = BuildReportModules.transform(dsl_state)

      modules = Transformer.get_persisted(transformed_state, :ash_reports_modules)

      # Verify proper module name generation handles different naming patterns
      assert Map.has_key?(modules, :report_with_underscores)
      assert Map.has_key?(modules, :ReportWithCamelCase)
      assert Map.has_key?(modules, :report123)
    end

    test "transformer handles reports with no formats specified" do
      # Test default format handling
      no_format_report = %AshReports.Report{
        name: :no_format_report,
        title: "No Format Report",
        driving_resource: AshReports.Test.Customer,
        # No formats specified
        formats: nil,
        bands: [%AshReports.Band{name: :detail, type: :detail, elements: []}]
      }

      dsl_state =
        %Spark.Dsl.State{}
        |> Transformer.persist(:module, NoFormatModule)
        |> Transformer.persist(:ash_reports_parsed, [no_format_report])

      {:ok, transformed_state} = BuildReportModules.transform(dsl_state)

      # Should handle nil formats gracefully
      modules = Transformer.get_persisted(transformed_state, :ash_reports_modules)
      assert Map.has_key?(modules, :no_format_report)
    end

    test "transformer respects execution order dependencies" do
      # Verify transformer dependencies are correctly specified
      assert BuildReportModules.after?(AshReports.Verifiers.ValidateReports) == true
      assert BuildReportModules.after?(AshReports.Verifiers.ValidateBands) == true
      assert BuildReportModules.after?(AshReports.Verifiers.ValidateElements) == true

      # Should not run before other transformers
      assert BuildReportModules.before?(SomeOtherTransformer) == false
      assert BuildReportModules.before?(AnyTransformer) == false
    end
  end

  describe "module interface generation" do
    test "generated modules expose correct runtime interface" do
      defmodule InterfaceTestDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :interface_test do
            title("Interface Test Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf])

            parameters do
              parameter(:start_date, :date, required: true)
              parameter(:end_date, :date, required: true)
            end

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

      report_module = InterfaceTestDomain.Reports.InterfaceTest

      # Test all required interface methods exist
      assert function_exported?(report_module, :definition, 0)
      assert function_exported?(report_module, :domain, 0)
      assert function_exported?(report_module, :run, 0)
      assert function_exported?(report_module, :run, 1)
      assert function_exported?(report_module, :run, 2)
      assert function_exported?(report_module, :render, 1)
      assert function_exported?(report_module, :render, 2)
      assert function_exported?(report_module, :render, 3)
      assert function_exported?(report_module, :validate_params, 1)
      assert function_exported?(report_module, :build_query, 0)
      assert function_exported?(report_module, :build_query, 1)
      assert function_exported?(report_module, :supported_formats, 0)
      assert function_exported?(report_module, :supports_format?, 1)

      # Test interface returns correct values
      definition = report_module.definition()
      assert definition.name == :interface_test
      assert definition.title == "Interface Test Report"
      assert definition.driving_resource == AshReports.Test.Customer

      assert report_module.domain() == InterfaceTestDomain
      assert report_module.supported_formats() == [:html, :pdf]
      assert report_module.supports_format?(:html) == true
      assert report_module.supports_format?(:json) == false
    end

    test "generated format modules implement renderer behavior correctly" do
      defmodule RendererTestDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :renderer_test do
            title("Renderer Test Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf, :json, :heex])

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

      base_module = RendererTestDomain.Reports.RendererTest

      # Test each format module
      format_tests = [
        {:html, "Html", ".html", true},
        {:pdf, "Pdf", ".pdf", true},
        # JSON doesn't support streaming
        {:json, "Json", ".json", false},
        {:heex, "Heex", ".heex", true}
      ]

      for {format, module_suffix, extension, streaming} <- format_tests do
        format_module = Module.concat(base_module, module_suffix)

        # Verify module exists
        assert format_module

        # Verify behavior implementation
        behaviours = format_module.__info__(:attributes) |> Keyword.get(:behaviour, [])
        assert AshReports.Renderer in behaviours

        # Verify required callbacks
        assert function_exported?(format_module, :render, 3)
        assert function_exported?(format_module, :supports_streaming?, 0)
        assert function_exported?(format_module, :file_extension, 0)

        # Verify callback implementations
        assert format_module.file_extension() == extension
        assert format_module.supports_streaming?() == streaming

        # Verify render method returns expected structure
        {:ok, result} = format_module.render(base_module, [], [])
        assert is_binary(result)
        assert result =~ "not yet implemented"
      end
    end
  end

  describe "transformer integration" do
    test "transformer works correctly in full DSL compilation pipeline" do
      # This tests the transformer as part of the complete Spark DSL processing
      defmodule PipelineTestDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
        end

        reports do
          report :pipeline_customer_report do
            title("Pipeline Customer Report")
            driving_resource(AshReports.Test.Customer)
            formats([:html, :pdf])

            bands do
              band :title do
                elements do
                  label("title", text: "Customer Report")
                end
              end

              band :detail do
                elements do
                  field(:name, source: [:name])
                  field(:email, source: [:email])
                end
              end

              band :summary do
                elements do
                  aggregate(:count, function: :count, source: [:id])
                end
              end
            end
          end

          report :pipeline_order_report do
            title("Pipeline Order Report")
            driving_resource(AshReports.Test.Order)
            formats([:json])

            bands do
              band :detail do
                elements do
                  field(:amount, source: [:amount])
                  field(:date, source: [:date])
                end
              end
            end
          end
        end
      end

      # Verify complete pipeline worked
      assert PipelineTestDomain.Reports.PipelineCustomerReport
      assert PipelineTestDomain.Reports.PipelineOrderReport

      # Verify format modules were created
      assert PipelineTestDomain.Reports.Module.concat(PipelineCustomerReport, Html)
      assert PipelineTestDomain.Reports.Module.concat(PipelineCustomerReport, Pdf)
      assert PipelineTestDomain.Reports.Module.concat(PipelineOrderReport, Json)

      # Verify definitions are correct
      customer_def = PipelineTestDomain.Reports.PipelineCustomerReport.definition()
      order_def = PipelineTestDomain.Reports.PipelineOrderReport.definition()

      assert customer_def.name == :pipeline_customer_report
      assert order_def.name == :pipeline_order_report

      assert length(customer_def.bands) == 3
      assert length(order_def.bands) == 1

      # Verify formats are correct
      assert customer_def.formats == [:html, :pdf]
      assert order_def.formats == [:json]
    end
  end
end
