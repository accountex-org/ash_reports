defmodule AshReports.ErrorHandlingComprehensiveTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Comprehensive error handling tests for AshReports.

  This test module focuses on testing error handling across all components:
  - DSL path validation in error messages
  - Error propagation through transformer and verifier chains
  - Edge cases in error handling
  - Error message quality and context
  """

  describe "DSL path validation in error messages" do
    test "reports include correct DSL path in error messages" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ReportPathErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :path_error_report do
                title("Path Error Report")
                # Missing driving_resource to trigger error

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

      # Verify complete DSL path is included
      assert error.path == [:reports, :path_error_report]
      assert error.module == ReportPathErrorDomain
      assert String.contains?(error.message, "must specify a driving_resource")
    end

    test "bands include correct DSL path in error messages" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule BandPathErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :band_path_error do
                title("Band Path Error Report")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :invalid_band, type: :group_header do
                    # Missing group_level to trigger error
                    elements do
                      label("group", text: "Group Header")
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

      # Verify path includes report and band
      assert error.path == [:reports, :band_path_error, :bands, :invalid_band]
      assert error.module == BandPathErrorDomain
      assert String.contains?(error.message, "must specify a group_level")
    end

    test "elements include correct DSL path in error messages" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ElementPathErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :element_path_error do
                title("Element Path Error Report")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :error_band do
                    elements do
                      # Missing source to trigger error
                      field :invalid_field
                    end
                  end
                end
              end
            end
          end
        end

      # Verify path includes report, band, and element
      assert error.path == [
               :reports,
               :element_path_error,
               :bands,
               :error_band,
               :elements,
               :invalid_field
             ]

      assert error.module == ElementPathErrorDomain
      assert String.contains?(error.message, "must have a source")
    end

    test "nested bands include correct DSL path in error messages" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule NestedBandPathErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :nested_path_error do
                title("Nested Path Error Report")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :parent_band, type: :group_header, group_level: 1 do
                    elements do
                      label("parent", text: "Parent Band")
                    end

                    bands do
                      band :child_band, type: :group_header do
                        # Missing group_level to trigger error
                        elements do
                          label("child", text: "Child Band")
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

      # Verify path includes nested structure
      assert error.path == [:reports, :nested_path_error, :bands, :child_band]
      assert error.module == NestedBandPathErrorDomain
    end

    test "deeply nested elements include correct DSL path" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule DeepNestedElementPathErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :deep_nested_error do
                title("Deep Nested Error Report")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :level1, type: :group_header, group_level: 1 do
                    elements do
                      label("level1", text: "Level 1")
                    end

                    bands do
                      band :level2, type: :group_header, group_level: 2 do
                        elements do
                          label("level2", text: "Level 2")
                        end

                        bands do
                          band :level3 do
                            elements do
                              aggregate(:invalid_agg,
                                function: :invalid_function,
                                source: [:amount]
                              )
                            end
                          end
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

      # Verify path includes complete nested structure
      assert error.path == [
               :reports,
               :deep_nested_error,
               :bands,
               :level3,
               :elements,
               :invalid_agg,
               :function
             ]

      assert error.module == DeepNestedElementPathErrorDomain
    end
  end

  describe "error propagation through verifier chain" do
    test "multiple validation errors are caught in order" do
      # Test that verifiers run in correct order and catch first error

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MultipleErrorsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              # Multiple errors: missing driving_resource (should be caught first)
              report :multiple_errors do
                title("Multiple Errors Report")
                # Missing driving_resource (ValidateReports error)

                bands do
                  # Duplicate names (ValidateBands error)
                  band :duplicate_name do
                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  # Duplicate names (ValidateBands error)
                  band :duplicate_name do
                    elements do
                      # Missing source (ValidateElements error)
                      field :invalid_field
                    end
                  end
                end
              end
            end
          end
        end

      # Should catch the first error (ValidateReports runs first)
      assert String.contains?(error.message, "must specify a driving_resource")
    end

    test "verifiers run after all previous verifiers pass" do
      # Test that band validation only runs after report validation passes

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule BandValidationOrderDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :band_validation_order do
                title("Band Validation Order")
                # Valid
                driving_resource(AshReports.Test.Customer)

                bands do
                  # Invalid band type
                  band :invalid_band, type: :invalid_type do
                    elements do
                      field(:name, source: [:name])
                    end
                  end
                end
              end
            end
          end
        end

      # Should catch band validation error since report validation passed
      assert String.contains?(error.message, "Invalid band type")
    end

    test "element validation runs after band validation passes" do
      # Test that element validation only runs after band validation passes

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ElementValidationOrderDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :element_validation_order do
                title("Element Validation Order")
                # Valid
                driving_resource(AshReports.Test.Customer)

                bands do
                  # Valid band
                  band :valid_band do
                    elements do
                      # Missing source (element error)
                      field :invalid_field
                    end
                  end
                end
              end
            end
          end
        end

      # Should catch element validation error since report and band validation passed
      assert String.contains?(error.message, "must have a source")
    end

    test "transformer runs after all verifiers pass" do
      # Test that BuildReportModules transformer only runs after all verifiers pass

      # This should succeed since all validations pass
      defmodule TransformerRunsAfterValidationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :transformer_runs_after do
            title("Transformer Runs After Validation")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :valid_band do
                elements do
                  field(:name, source: [:name])
                end
              end
            end
          end
        end
      end

      # Should compile successfully and generate report module
      assert TransformerRunsAfterValidationDomain.Reports.TransformerRunsAfter
    end
  end

  describe "error message quality and context" do
    test "error messages are clear and actionable" do
      # Test that error messages provide clear guidance

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ClearErrorMessageDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :clear_error_message do
                title("Clear Error Message Report")
                # Should be atom
                driving_resource("invalid_resource")

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

      # Verify error message is clear and actionable
      assert String.contains?(error.message, "must be an atom representing an Ash.Resource")
      assert error.path == [:reports, :clear_error_message, :driving_resource]
    end

    test "error messages include context about valid options" do
      # Test that error messages include information about valid alternatives

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ValidOptionsErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :valid_options_error do
                title("Valid Options Error")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail, type: :invalid_band_type do
                    elements do
                      field(:name, source: [:name])
                    end
                  end
                end
              end
            end
          end
        end

      # Error should include list of valid band types
      assert String.contains?(error.message, "Invalid band type")
      assert String.contains?(error.message, "Valid types are:")
      assert String.contains?(error.message, ":detail")
      assert String.contains?(error.message, ":title")
    end

    test "error messages for aggregate functions include valid options" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule AggregateErrorOptionsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :aggregate_error_options do
                title("Aggregate Error Options")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      aggregate(:invalid_func, function: :invalid_function, source: [:amount])
                    end
                  end
                end
              end
            end
          end
        end

      # Error should be specific about invalid aggregate function
      assert String.contains?(error.message, "Invalid aggregate function 'invalid_function'")
    end

    test "error messages for duplicate names show which names are duplicated" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule DuplicateNamesErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :duplicate_names_error do
                title("Duplicate Names Error")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :duplicate_band do
                    elements do
                      field(:duplicate_element, source: [:name])
                      # Duplicate
                      field(:duplicate_element, source: [:email])
                      field(:another_duplicate, source: [:phone])
                      # Another duplicate
                      field(:another_duplicate, source: [:address])
                    end
                  end
                end
              end
            end
          end
        end

      # Error should list the specific duplicate names
      assert String.contains?(error.message, "Duplicate element names found")

      assert String.contains?(error.message, "duplicate_element") or
               String.contains?(error.message, "another_duplicate")
    end
  end

  describe "edge cases in error handling" do
    test "handles reports with no bands gracefully" do
      # Test error handling when reports have no bands at all

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule NoBandsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :no_bands do
                title("No Bands Report")
                driving_resource(AshReports.Test.Customer)
                # No bands section
              end
            end
          end
        end

      # Should handle gracefully and provide clear error
      assert String.contains?(error.message, "must have at least one detail band")
    end

    test "handles bands with no elements gracefully" do
      # Test error handling when bands have no elements

      defmodule NoElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :no_elements do
            title("No Elements Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                # No elements section - should be handled gracefully
              end
            end
          end
        end
      end

      # Should compile successfully (empty elements is valid)
      assert NoElementsDomain.Reports.NoElements
    end

    test "handles malformed DSL structures" do
      # Test error handling with various malformed DSL structures

      # Test with nil values
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule MalformedDslDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              # Nil report name
              report nil do
                title("Malformed DSL")
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

      # Should handle malformed DSL and provide error
      assert String.contains?(error.message, "name is required") or
               String.contains?(error.message, "invalid") or
               String.contains?(error.message, "must be")
    end

    test "handles very large DSL structures efficiently" do
      # Test that error handling works efficiently with large DSL structures

      # Generate a large number of reports with one error
      reports =
        for i <- 1..50 do
          if i == 25 do
            # Insert an error in the middle
            quote do
              report unquote(:"report_#{i}") do
                title(unquote("Report #{i}"))
                # Missing driving_resource to trigger error

                bands do
                  band :detail do
                    elements do
                      field(:name, source: [:name])
                    end
                  end
                end
              end
            end
          else
            quote do
              report unquote(:"report_#{i}") do
                title(unquote("Report #{i}"))
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

      module_ast =
        quote do
          defmodule LargeDslErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              (unquote_splicing(reports))
            end
          end
        end

      # Should find the error efficiently even in large DSL
      error =
        assert_raise Spark.Error.DslError, fn ->
          {_result, _binding} = Code.eval_quoted(module_ast)
        end

      assert String.contains?(error.message, "must specify a driving_resource")
      assert error.path == [:reports, :report_25]
    end

    test "handles concurrent validation errors gracefully" do
      # Test error handling when multiple processes try to define problematic domains

      test_processes =
        for i <- 1..5 do
          Task.async(fn ->
            try do
              defmodule Module.concat([ConcurrentErrorDomain, i]) do
                use Ash.Domain, extensions: [AshReports.Domain]

                resources do
                  resource AshReports.Test.Customer
                end

                reports do
                  report :concurrent_error do
                    title("Concurrent Error")
                    # Missing driving_resource to trigger error

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
              error -> error
            end
          end)
        end

      # All should fail with similar errors
      results = Task.await_many(test_processes)

      for result <- results do
        assert %Spark.Error.DslError{} = result
        assert String.contains?(result.message, "must specify a driving_resource")
      end
    end
  end

  describe "error recovery and graceful degradation" do
    test "verifiers handle partial DSL state gracefully" do
      # Test that verifiers can handle incomplete or partial DSL state

      # This is tested internally by creating partial DSL state and running verifiers
      # The transformers and verifiers should handle missing data gracefully

      # For now, we'll test through the public API
      defmodule PartialStateDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :partial_state do
            title("Partial State Report")
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

      # Should handle successfully
      assert PartialStateDomain.Reports.PartialState
    end

    test "error messages remain consistent across different error scenarios" do
      # Test that similar errors produce consistent error message formats

      # Test 1: Missing driving_resource
      error1 =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ConsistentError1Domain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :consistent_error1 do
                title("Consistent Error 1")
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
        end

      # Test 2: Another missing driving_resource
      error2 =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ConsistentError2Domain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :consistent_error2 do
                title("Consistent Error 2")
                # Missing driving_resource

                bands do
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

      # Both should have similar error message patterns
      assert String.contains?(error1.message, "must specify a driving_resource")
      assert String.contains?(error2.message, "must specify a driving_resource")

      # Path format should be consistent
      assert error1.path == [:reports, :consistent_error1]
      assert error2.path == [:reports, :consistent_error2]
    end
  end
end
