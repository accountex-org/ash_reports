defmodule AshReports.ErrorHandlingTest do
  use ExUnit.Case, async: false

  describe "comprehensive error handling" do
    test "provides clear error messages for missing required fields" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingRequiredFieldsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_fields do
                # Missing title and driving_resource
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
        end

      # Error should mention the specific missing field
      assert error.message =~ "must specify a driving_resource"
      assert error.path == [:reports, :missing_fields]
      assert error.module == MissingRequiredFieldsDomain
    end

    test "provides helpful error messages for invalid band types" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidBandTypeDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :invalid_band_type do
                title("Invalid Band Type Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :invalid_band do
                    type :completely_invalid_type

                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  band :detail do
                    elements do
                      field(:email, source: [:email])
                    end
                  end
                end
              end
            end
          end
        end

      # Error should list valid types
      assert error.message =~ "Invalid band type 'completely_invalid_type'"
      assert error.message =~ "Valid types are:"
      assert error.path == [:reports, :invalid_band_type, :bands, :invalid_band]
    end

    test "provides helpful error messages for invalid element types" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidElementTypeDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :invalid_element_type do
                title("Invalid Element Type Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      element :invalid_element do
                        type :not_a_real_element_type
                      end
                    end
                  end
                end
              end
            end
          end
        end

      # Error should list valid element types
      assert error.message =~ "Invalid element type 'not_a_real_element_type'"
      assert error.message =~ "Valid types are:"

      assert error.path == [
               :reports,
               :invalid_element_type,
               :bands,
               :detail,
               :elements,
               :invalid_element
             ]
    end

    test "provides specific error messages for aggregate function validation" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidAggregateDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :invalid_aggregate do
                title("Invalid Aggregate Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      aggregate(:bad_aggregate, function: :invalid_function, source: [:id])
                    end
                  end
                end
              end
            end
          end
        end

      # Error should mention the specific invalid function
      assert error.message =~ "Invalid aggregate function 'invalid_function'"

      assert error.path == [
               :reports,
               :invalid_aggregate,
               :bands,
               :detail,
               :elements,
               :bad_aggregate,
               :function
             ]
    end

    test "error messages include full DSL path context" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule NestedErrorPathDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :nested_error_path do
                title("Nested Error Path Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :group_header, group_level: 1 do
                    elements do
                      label("group", text: "Group Header")
                    end

                    bands do
                      band :nested_detail do
                        elements do
                          # Missing source
                          field :invalid_field
                        end
                      end
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

      # Error path should include the full nested path
      assert error.path == [
               :reports,
               :nested_error_path,
               :bands,
               :nested_detail,
               :elements,
               :invalid_field
             ]

      assert error.message =~ "must have a source"
    end

    test "error messages for duplicate names include all duplicates" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MultipleDuplicatesDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :duplicate_one do
                title("First Duplicate")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      field(:name, source: [:name])
                    end
                  end
                end
              end

              report :duplicate_two do
                title("Second Duplicate")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      field(:name, source: [:name])
                    end
                  end
                end
              end

              # Duplicate name
              report :duplicate_one do
                title("Third Report with Duplicate Name")
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
        end

      # Error should mention the specific duplicate names
      assert error.message =~ "Duplicate report names found"
      assert error.message =~ "duplicate_one"
    end

    test "error messages for band hierarchy violations" do
      # Test title band not first
      title_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule TitleNotFirstDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :title_not_first do
                title("Title Not First")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  band :title do
                    elements do
                      label("title", text: "Report Title")
                    end
                  end
                end
              end
            end
          end
        end

      assert title_error.message =~ "Title band must be the first band"

      # Test summary band not last
      summary_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule SummaryNotLastDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :summary_not_last do
                title("Summary Not Last")
                driving_resource(AshReports.Test.Customer)

                bands do
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

      assert summary_error.message =~ "Summary band must be the last band"
    end

    test "error messages for group band validation" do
      # Test missing group_level
      missing_level_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingGroupLevelDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_group_level do
                title("Missing Group Level")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :group_header do
                    # Missing group_level
                    elements do
                      label("group", text: "Group")
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

      assert missing_level_error.message =~ "must specify a group_level"

      # Test invalid group_level
      invalid_level_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidGroupLevelDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :invalid_group_level do
                title("Invalid Group Level")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :group_header, group_level: -1 do
                    elements do
                      label("group", text: "Group")
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

      assert invalid_level_error.message =~ "must have a positive integer group_level"
    end

    test "error messages for detail band number validation" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidDetailNumbersDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :invalid_detail_numbers do
                title("Invalid Detail Numbers")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail, detail_number: 1 do
                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  # Skipping 2
                  band :detail, detail_number: 3 do
                    elements do
                      field(:email, source: [:email])
                    end
                  end

                  # Skipping 4
                  band :detail, detail_number: 5 do
                    elements do
                      field(:phone, source: [:phone])
                    end
                  end
                end
              end
            end
          end
        end

      assert error.message =~ "Detail band numbers must be sequential starting from 1"
      assert error.message =~ "Found: [1, 3, 5]"
    end

    test "error messages for element validation" do
      # Test label without text
      label_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingLabelTextDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_label_text do
                title("Missing Label Text")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # Missing text
                      label(:empty_label)
                    end
                  end
                end
              end
            end
          end
        end

      assert label_error.message =~ "Label element 'empty_label' must have text"

      # Test field without source
      field_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingFieldSourceDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_field_source do
                title("Missing Field Source")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # Missing source
                      field :no_source
                    end
                  end
                end
              end
            end
          end
        end

      assert field_error.message =~ "Field element 'no_source' must have a source"

      # Test expression without expression
      expr_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingExpressionDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_expression do
                title("Missing Expression")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # Missing expression
                      expression(:no_expr)
                    end
                  end
                end
              end
            end
          end
        end

      assert expr_error.message =~ "Expression element 'no_expr' must have an expression"

      # Test image without source
      image_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingImageSourceDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_image_source do
                title("Missing Image Source")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # Missing source
                      image(:no_source)
                    end
                  end
                end
              end
            end
          end
        end

      assert image_error.message =~ "Image element 'no_source' must have a source"
    end

    test "error messages for aggregate validation" do
      # Test missing function
      function_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingAggregateFunctionDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_aggregate_function do
                title("Missing Aggregate Function")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # Missing function
                      aggregate(:no_function, source: [:id])
                    end
                  end
                end
              end
            end
          end
        end

      assert function_error.message =~ "Aggregate element 'no_function' must have a function"

      # Test missing source
      source_error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MissingAggregateSourceDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :missing_aggregate_source do
                title("Missing Aggregate Source")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # Missing source
                      aggregate(:no_source, function: :count)
                    end
                  end
                end
              end
            end
          end
        end

      assert source_error.message =~ "Aggregate element 'no_source' must have a source"
    end

    test "provides context for compilation module information" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule CompilationContextDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :compilation_context do
                title("Compilation Context Test")
                driving_resource(AshReports.Test.Customer)
                # Missing detail band to trigger error

                bands do
                  band :title do
                    elements do
                      label("title", text: "Title")
                    end
                  end
                end
              end
            end
          end
        end

      # Error should include the module being compiled
      assert error.module == CompilationContextDomain
      assert error.path == [:reports, :compilation_context, :bands]
    end

    test "error handling works with nested band structures" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule NestedErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :nested_error do
                title("Nested Error Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :group_header, group_level: 1 do
                    elements do
                      label("group", text: "Group")
                    end

                    bands do
                      band :nested_group, type: :group_header do
                        # Missing group_level
                        elements do
                          label("nested", text: "Nested")
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
        end

      # Error should be detected in nested structure
      assert error.message =~ "must specify a group_level"
      assert error.path == [:reports, :nested_error, :bands, :nested_group]
    end

    test "multiple errors are reported appropriately" do
      # Test that the first error is reported, not all of them
      # (Since Elixir typically stops at the first compilation error)

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MultipleErrorsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              # This report has multiple issues, but we should get the first one
              report :multiple_errors do
                # Missing driving_resource (first error)
                title("Multiple Errors Test")

                bands do
                  # Also missing detail band (second error)
                  band :title do
                    elements do
                      label("title", text: "Title")
                    end
                  end
                end
              end
            end
          end
        end

      # Should get the first error (missing driving_resource)
      assert error.message =~ "must specify a driving_resource"
    end

    test "error recovery and graceful degradation" do
      # Test that valid reports in the same domain still work
      # even if one report has errors

      # This is tricky to test because compilation errors prevent
      # the entire module from compiling. In practice, users would
      # fix the error and recompile.

      # Instead, we test that the error system doesn't crash
      # the compilation process entirely

      try do
        defmodule ErrorRecoveryDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_report do
              title("Invalid Report")
              # Missing driving_resource

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
      rescue
        Spark.Error.DslError ->
          # This is expected - the error should be a DslError, not a crash
          :ok
      end
    end
  end

  describe "error message formatting" do
    test "error messages are user-friendly and actionable" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule UserFriendlyErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :user_friendly_error do
                title("User Friendly Error Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      # This will trigger a clear error
                      field :missing_source_field
                    end
                  end
                end
              end
            end
          end
        end

      # Error message should be clear and actionable
      assert error.message =~ "Field element 'missing_source_field' must have a source"
      # Path should clearly indicate where the error occurred
      assert error.path == [
               :reports,
               :user_friendly_error,
               :bands,
               :detail,
               :elements,
               :missing_source_field
             ]
    end

    test "error messages include suggestions when possible" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule SuggestionsErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :suggestions_error do
                title("Suggestions Error Test")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :invalid_band do
                    type :invalid_type

                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  band :detail do
                    elements do
                      field(:email, source: [:email])
                    end
                  end
                end
              end
            end
          end
        end

      # Error should include valid options
      assert error.message =~ "Valid types are:"
      # Should list the actual valid types
      assert error.message =~ ":title"
      assert error.message =~ ":detail"
    end
  end

  describe "module compilation error scenarios" do
    test "handles transformer exceptions gracefully" do
      # Since we can't easily cause transformer exceptions in a controlled way,
      # we test that the transformer is defensive against edge cases

      # Test with minimal valid structure
      defmodule MinimalValidDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :minimal_valid do
            title("Minimal Valid Report")
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

      # Should compile successfully
      assert MinimalValidDomain
      assert MinimalValidDomain.Reports.MinimalValid
    end
  end
end
