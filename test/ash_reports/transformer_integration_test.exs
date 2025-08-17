defmodule AshReports.TransformerIntegrationTest do
  use ExUnit.Case, async: false

  alias AshReports.Transformers.BuildReportModules
  alias AshReports.Verifiers.{ValidateReports, ValidateBands, ValidateElements}
  alias Spark.Dsl.Transformer

  describe "transformer integration and execution order" do
    test "verifiers run before transformers" do
      # This test ensures that validation happens before module generation
      
      # Invalid report should fail at verification stage, not transformation
      assert_raise Spark.Error.DslError, ~r/must have at least one detail band/, fn ->
        defmodule InvalidBeforeTransformDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_report do
              title "Invalid Report"
              driving_resource AshReports.Test.Customer
              # No detail band - should fail validation
              
              bands do
                band :title do
                  elements do
                    label "title", text: "Title"
                  end
                end
              end
            end
          end
        end
      end
    end

    test "transformers can access validated DSL state" do
      defmodule ValidatedStateDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :validated_state do
            title "Validated State Report"
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

      # If we get here, validation passed and transformer succeeded
      assert ValidatedStateDomain
      report_module = ValidatedStateDomain.Reports.ValidatedState
      assert report_module
      
      # Verify transformer had access to validated state
      definition = report_module.definition()
      assert definition.name == :validated_state
      assert definition.driving_resource == AshReports.Test.Customer
    end

    test "DSL state persistence across transformers" do
      # Create a test that verifies data can be persisted and retrieved
      # This simulates how transformers can share data
      
      defmodule PersistenceTestDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :persistence_test do
            title "Persistence Test Report"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf, :json]

            bands do
              band :title do
                elements do
                  label "title", text: "Test Report"
                end
              end

              band :detail do
                elements do
                  field :name, source: [:name]
                  field :email, source: [:email]
                end
              end
            end
          end
        end
      end

      # Verify that the transformer persisted data correctly
      report_module = PersistenceTestDomain.Reports.PersistenceTest
      definition = report_module.definition()
      
      # The transformer should have persisted the report data
      assert definition.formats == [:html, :pdf, :json]
      assert length(definition.bands) == 2
      
      # Format-specific modules should exist
      assert PersistenceTestDomain.Reports.PersistenceTest.Html
      assert PersistenceTestDomain.Reports.PersistenceTest.Pdf
      assert PersistenceTestDomain.Reports.PersistenceTest.Json
    end

    test "cross-transformer data sharing" do
      # Test that multiple transformers can work together by sharing persisted data
      
      defmodule CrossTransformerDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :cross_transformer do
            title "Cross Transformer Test"
            driving_resource AshReports.Test.Customer

            parameters do
              parameter :start_date, :date, required: true
              parameter :end_date, :date, required: true
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

      report_module = CrossTransformerDomain.Reports.CrossTransformer
      definition = report_module.definition()
      
      # Verify that parameter information was preserved
      assert length(definition.parameters) == 2
      assert Enum.any?(definition.parameters, &(&1.name == :start_date))
      assert Enum.any?(definition.parameters, &(&1.name == :end_date))
    end

    test "transformer handles multiple reports correctly" do
      defmodule MultipleReportsTransformerDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
          resource AshReports.Test.Order
        end

        reports do
          report :customer_report do
            title "Customer Report"
            driving_resource AshReports.Test.Customer
            formats [:html]

            bands do
              band :detail do
                elements do
                  field :name, source: [:name]
                end
              end
            end
          end

          report :order_report do
            title "Order Report"
            driving_resource AshReports.Test.Order
            formats [:html, :pdf]

            bands do
              band :detail do
                elements do
                  field :amount, source: [:amount]
                end
              end
            end
          end

          report :summary_report do
            title "Summary Report"
            driving_resource AshReports.Test.Customer
            formats [:json]

            bands do
              band :detail do
                elements do
                  aggregate :count, function: :count, source: [:id]
                end
              end
            end
          end
        end
      end

      # All reports should be transformed correctly
      assert MultipleReportsTransformerDomain.Reports.CustomerReport
      assert MultipleReportsTransformerDomain.Reports.OrderReport
      assert MultipleReportsTransformerDomain.Reports.SummaryReport

      # Each should have correct format modules
      assert MultipleReportsTransformerDomain.Reports.CustomerReport.Html
      assert MultipleReportsTransformerDomain.Reports.OrderReport.Html
      assert MultipleReportsTransformerDomain.Reports.OrderReport.Pdf
      assert MultipleReportsTransformerDomain.Reports.SummaryReport.Json

      # Each should have correct definitions
      customer_def = MultipleReportsTransformerDomain.Reports.CustomerReport.definition()
      order_def = MultipleReportsTransformerDomain.Reports.OrderReport.definition()
      summary_def = MultipleReportsTransformerDomain.Reports.SummaryReport.definition()

      assert customer_def.driving_resource == AshReports.Test.Customer
      assert order_def.driving_resource == AshReports.Test.Order
      assert summary_def.driving_resource == AshReports.Test.Customer
    end

    test "transformer execution order respects dependencies" do
      # Test that BuildReportModules runs after all verifiers
      
      # We can't directly test execution order, but we can verify
      # that the transformer declares its dependencies correctly
      assert BuildReportModules.after?(ValidateReports) == true
      assert BuildReportModules.after?(ValidateBands) == true
      assert BuildReportModules.after?(ValidateElements) == true
      
      # And that it doesn't claim to run before anything it shouldn't
      assert BuildReportModules.before?(ValidateReports) == false
      assert BuildReportModules.before?(ValidateBands) == false
      assert BuildReportModules.before?(ValidateElements) == false
    end

    test "complex report structure transforms correctly" do
      defmodule ComplexStructureDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_structure do
            title "Complex Structure Report"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf]

            parameters do
              parameter :region, :string, required: false
              parameter :start_date, :date, required: true
            end

            groups do
              group :region, field: [:region], sort: :asc
              group :status, field: [:status], sort: :desc
            end

            variables do
              variable :total_count, type: :count, reset_on: :report
              variable :group_count, type: :count, reset_on: :group, reset_group: 1
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Customer Report"
                  image "logo", source: "/logo.png"
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  label "region", text: "Region Header"
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      label "status", text: "Status Header"
                    end
                  end

                  band :detail do
                    elements do
                      field :name, source: [:name]
                      field :email, source: [:email]
                      expression :full_name, expression: expr(first_name <> " " <> last_name)
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
                  aggregate :total, function: :count, source: [:id]
                  label "end", text: "End of Report"
                end
              end
            end
          end
        end
      end

      # Complex structure should be handled correctly
      assert ComplexStructureDomain
      report_module = ComplexStructureDomain.Reports.ComplexStructure
      assert report_module

      definition = report_module.definition()
      
      # Verify all complex elements are preserved
      assert length(definition.parameters) == 2
      assert length(definition.groups) == 2
      assert length(definition.variables) == 2
      assert length(definition.bands) == 4  # title, group_header, group_footer, summary

      # Verify nested bands are handled
      group_header = Enum.find(definition.bands, &(&1.type == :group_header && &1.group_level == 1))
      assert length(group_header.bands) == 3  # nested group_header, detail, group_footer

      # Format modules should exist
      assert report_module.Html
      assert report_module.Pdf
    end
  end

  describe "error handling during transformation" do
    test "transformer handles empty reports gracefully" do
      defmodule EmptyReportsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        # No reports section
      end

      # Should not crash during transformation
      assert EmptyReportsDomain
    end

    test "transformer handles malformed DSL state gracefully" do
      # This test ensures the transformer is robust against edge cases
      
      # We can't easily create malformed DSL state at the module level,
      # but we can test the transformer directly
      empty_state = %Spark.Dsl.State{} |> Transformer.persist(:module, TestModule)
      
      # Should not crash
      result = BuildReportModules.transform(empty_state)
      assert {:ok, _} = result
    end

    test "compilation errors are properly reported" do
      # Test that compilation errors include proper context
      
      assert_raise Spark.Error.DslError, fn ->
        defmodule CompilationErrorDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :compilation_error do
              title "Compilation Error Test"
              # This will trigger a validation error before transformation
              driving_resource NonExistentResource

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
      end
    end
  end

  describe "DSL state manipulation" do
    test "transformers preserve DSL entity relationships" do
      defmodule PreserveRelationshipsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :preserve_relationships do
            title "Preserve Relationships"
            driving_resource AshReports.Test.Customer

            bands do
              band :group_header, group_level: 1 do
                elements do
                  label "group", text: "Group Header"
                end

                bands do
                  band :detail do
                    elements do
                      field :name, source: [:name]
                      field :email, source: [:email]
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate :count, function: :count, source: [:id]
                end
              end
            end
          end
        end
      end

      report_module = PreserveRelationshipsDomain.Reports.PreserveRelationships
      definition = report_module.definition()

      # Verify nested band relationships are preserved
      group_header = Enum.find(definition.bands, &(&1.type == :group_header))
      assert length(group_header.bands) == 1
      
      detail_band = hd(group_header.bands)
      assert detail_band.type == :detail
      assert length(detail_band.elements) == 2
    end

    test "transformers handle recursive band structures" do
      defmodule RecursiveBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :recursive_bands do
            title "Recursive Bands"
            driving_resource AshReports.Test.Customer

            bands do
              band :level1, type: :group_header, group_level: 1 do
                elements do
                  label "level1", text: "Level 1"
                end

                bands do
                  band :level2, type: :group_header, group_level: 2 do
                    elements do
                      label "level2", text: "Level 2"
                    end

                    bands do
                      band :level3, type: :group_header, group_level: 3 do
                        elements do
                          label "level3", text: "Level 3"
                        end

                        bands do
                          band :detail do
                            elements do
                              field :name, source: [:name]
                            end
                          end
                        end
                      end

                      band :level3_footer, type: :group_footer, group_level: 3 do
                        elements do
                          aggregate :level3_count, function: :count, source: [:id]
                        end
                      end
                    end
                  end

                  band :level2_footer, type: :group_footer, group_level: 2 do
                    elements do
                      aggregate :level2_count, function: :count, source: [:id]
                    end
                  end
                end
              end

              band :level1_footer, type: :group_footer, group_level: 1 do
                elements do
                  aggregate :level1_count, function: :count, source: [:id]
                end
              end
            end
          end
        end
      end

      # Deep recursive structure should be handled correctly
      assert RecursiveBandsDomain
      report_module = RecursiveBandsDomain.Reports.RecursiveBands
      definition = report_module.definition()

      # Verify deep nesting is preserved
      level1 = Enum.find(definition.bands, &(&1.name == :level1))
      assert level1
      
      level2 = Enum.find(level1.bands, &(&1.name == :level2))
      assert level2
      
      level3 = Enum.find(level2.bands, &(&1.name == :level3))
      assert level3
      
      detail = Enum.find(level3.bands, &(&1.type == :detail))
      assert detail
    end
  end

  describe "generated module interfaces" do
    test "all generated modules have consistent interfaces" do
      defmodule ConsistentInterfacesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :consistent_interfaces do
            title "Consistent Interfaces"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf, :heex, :json]

            parameters do
              parameter :test_param, :string, required: false
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

      base_module = ConsistentInterfacesDomain.Reports.ConsistentInterfaces

      # Test base module interface
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

      # Test format-specific modules
      formats = [:html, :pdf, :heex, :json]
      for format <- formats do
        format_module_name = format |> to_string() |> Macro.camelize()
        format_module = Module.concat(base_module, format_module_name)
        
        assert function_exported?(format_module, :render, 3)
        assert function_exported?(format_module, :supports_streaming?, 0)
        assert function_exported?(format_module, :file_extension, 0)
      end
    end
  end
end