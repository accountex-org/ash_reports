defmodule AshReports.Verifiers.ValidateElementsTest do
  use ExUnit.Case, async: false

  describe "ValidateElements verifier" do
    test "accepts valid element definitions" do
      defmodule ValidElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :valid_elements do
            title("Valid Elements Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("title_label", text: "Report Title")
                end
              end

              band :detail do
                elements do
                  field(:name_field, source: [:name])
                  field(:email_field, source: [:email])
                  expression(:full_name, expression: expr(first_name <> " " <> last_name))
                  aggregate(:total_count, function: :count, source: [:id])
                  line(:separator_line)
                  box(:container_box)
                  image(:logo_image, source: "/path/to/logo.png")
                end
              end
            end
          end
        end
      end

      assert ValidElementsDomain
      assert ValidElementsDomain.Reports.ValidElements
    end

    test "rejects elements with duplicate names within a band" do
      assert_raise Spark.Error.DslError, ~r/Duplicate element names found in band/, fn ->
        defmodule DuplicateElementNamesDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :duplicate_elements do
              title("Duplicate Element Names")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    field(:duplicate_name, source: [:name])
                    # Duplicate name
                    field(:duplicate_name, source: [:email])
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates element types are from allowed list" do
      assert_raise Spark.Error.DslError, ~r/Invalid element type/, fn ->
        defmodule InvalidElementTypeDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_element_type do
              title("Invalid Element Type")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    element :invalid_element do
                      type :not_a_valid_type
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates label elements have text" do
      assert_raise Spark.Error.DslError, ~r/Label element .* must have text/, fn ->
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
    end

    test "validates field elements have source" do
      assert_raise Spark.Error.DslError, ~r/Field element .* must have a source/, fn ->
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
                    field :no_source_field
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates expression elements have expression" do
      assert_raise Spark.Error.DslError, ~r/Expression element .* must have an expression/, fn ->
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
                    expression(:no_expression)
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates aggregate elements have function and source" do
      assert_raise Spark.Error.DslError, ~r/Aggregate element .* must have a function/, fn ->
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

      assert_raise Spark.Error.DslError, ~r/Aggregate element .* must have a source/, fn ->
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
    end

    test "validates aggregate function is from allowed list" do
      assert_raise Spark.Error.DslError, ~r/Invalid aggregate function/, fn ->
        defmodule InvalidAggregateFunctionDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_aggregate_function do
              title("Invalid Aggregate Function")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    aggregate(:invalid_func, function: :invalid_function, source: [:id])
                  end
                end
              end
            end
          end
        end
      end
    end

    test "accepts all valid aggregate functions" do
      defmodule ValidAggregateFunctionsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :valid_aggregate_functions do
            title("Valid Aggregate Functions")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  aggregate(:sum_agg, function: :sum, source: [:amount])
                  aggregate(:count_agg, function: :count, source: [:id])
                  aggregate(:avg_agg, function: :average, source: [:amount])
                  aggregate(:min_agg, function: :min, source: [:amount])
                  aggregate(:max_agg, function: :max, source: [:amount])
                end
              end
            end
          end
        end
      end

      assert ValidAggregateFunctionsDomain
      assert ValidAggregateFunctionsDomain.Reports.ValidAggregateFunctions
    end

    test "validates image elements have source" do
      assert_raise Spark.Error.DslError, ~r/Image element .* must have a source/, fn ->
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
                    image(:no_source_image)
                  end
                end
              end
            end
          end
        end
      end
    end

    test "accepts line and box elements without additional validation" do
      defmodule LineBoxElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :line_box_elements do
            title("Line and Box Elements")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  line(:separator_line)
                  box(:container_box)
                  field(:name, source: [:name])
                end
              end
            end
          end
        end
      end

      assert LineBoxElementsDomain
      assert LineBoxElementsDomain.Reports.LineBoxElements
    end

    test "validates elements across nested band structures" do
      defmodule NestedElementValidationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :nested_element_validation do
            title("Nested Element Validation")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :group_header, group_level: 1 do
                elements do
                  label("group_label", text: "Group Header")
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      label("subgroup_label", text: "Sub Group Header")
                    end
                  end

                  band :detail do
                    elements do
                      field(:name_field, source: [:name])
                      field(:email_field, source: [:email])
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      aggregate(:subgroup_count, function: :count, source: [:id])
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate(:group_count, function: :count, source: [:id])
                end
              end
            end
          end
        end
      end

      assert NestedElementValidationDomain
      assert NestedElementValidationDomain.Reports.NestedElementValidation
    end

    test "rejects duplicate element names across nested bands within same report" do
      assert_raise Spark.Error.DslError, ~r/Duplicate element names found in band/, fn ->
        defmodule DuplicateNestedElementsDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :duplicate_nested_elements do
              title("Duplicate Nested Elements")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    field(:duplicate_name, source: [:name])
                    # Duplicate in same band
                    field(:duplicate_name, source: [:email])
                  end
                end
              end
            end
          end
        end
      end
    end

    test "allows same element names in different bands" do
      defmodule SameNameDifferentBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :same_name_different_bands do
            title("Same Name Different Bands")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("header", text: "Title Header")
                end
              end

              band :detail do
                elements do
                  # Same name, different band - OK
                  label("header", text: "Detail Header")
                  field(:name, source: [:name])
                end
              end

              band :summary do
                elements do
                  # Same name, different band - OK
                  label("header", text: "Summary Header")
                end
              end
            end
          end
        end
      end

      assert SameNameDifferentBandsDomain
      assert SameNameDifferentBandsDomain.Reports.SameNameDifferentBands
    end

    test "validates complex element configurations" do
      defmodule ComplexElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_elements do
            title("Complex Elements")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("main_title", text: "Customer Report")
                  image("company_logo", source: "/assets/logo.png")
                  line("title_separator")
                end
              end

              band :column_header do
                elements do
                  label("name_header", text: "Customer Name")
                  label("email_header", text: "Email Address")
                  label("orders_header", text: "Total Orders")
                end
              end

              band :detail do
                elements do
                  field(:customer_name, source: [:name])
                  field(:customer_email, source: [:email])
                  field(:order_count, source: [:orders, :count])
                  expression(:display_name, expression: expr(name <> " (" <> email <> ")"))
                  box("detail_container")
                end
              end

              band :summary do
                elements do
                  line("summary_separator")
                  aggregate(:total_customers, function: :count, source: [:id])
                  aggregate(:avg_orders, function: :average, source: [:orders, :count])
                  label("report_footer", text: "End of Report")
                end
              end
            end
          end
        end
      end

      assert ComplexElementsDomain
      assert ComplexElementsDomain.Reports.ComplexElements
    end

    test "error messages include proper DSL path context" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ElementErrorPathDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :element_error_path do
                title("Element Error Path")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
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

      # Error should include the DSL path
      assert error.path == [
               :reports,
               :element_error_path,
               :bands,
               :detail,
               :elements,
               :invalid_field
             ]

      assert error.module == ElementErrorPathDomain
    end

    test "validates elements in reports with multiple bands" do
      defmodule MultipleBandsElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :multiple_bands_elements do
            title("Multiple Bands Elements")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("report_title", text: "Customer Report")
                end
              end

              band :page_header do
                elements do
                  label("page_header", text: "Page Header")
                  image("header_logo", source: "/header-logo.png")
                end
              end

              band :column_header do
                elements do
                  label("col1", text: "Name")
                  label("col2", text: "Email")
                  label("col3", text: "Phone")
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  label("group_name", text: "Customer Group")
                  line("group_separator")
                end
              end

              band :detail do
                elements do
                  field(:name, source: [:name])
                  field(:email, source: [:email])
                  field(:phone, source: [:phone])
                  expression(:full_contact, expression: expr(name <> " - " <> email))
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate(:group_count, function: :count, source: [:id])
                  line("group_end")
                end
              end

              band :column_footer do
                elements do
                  aggregate(:total_count, function: :count, source: [:id])
                end
              end

              band :page_footer do
                elements do
                  label("page_footer", text: "Page Footer")
                end
              end

              band :summary do
                elements do
                  aggregate(:grand_total, function: :count, source: [:id])
                  label("end_report", text: "End of Report")
                end
              end
            end
          end
        end
      end

      assert MultipleBandsElementsDomain
      assert MultipleBandsElementsDomain.Reports.MultipleBandsElements
    end
  end

  describe "element type validation" do
    test "validates all supported element types" do
      defmodule AllElementTypesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :all_element_types do
            title("All Element Types")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  # Test each element type
                  field(:field_elem, source: [:name])
                  label("label_elem", text: "Label Text")
                  expression(:expr_elem, expression: expr(name))
                  aggregate(:agg_elem, function: :count, source: [:id])
                  line(:line_elem)
                  box(:box_elem)
                  image(:image_elem, source: "/path/to/image.png")
                end
              end
            end
          end
        end
      end

      assert AllElementTypesDomain
      assert AllElementTypesDomain.Reports.AllElementTypes
    end
  end

  describe "integration with other verifiers" do
    test "works correctly when combined with report and band validation" do
      defmodule FullIntegrationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :full_integration do
            title("Full Integration Test")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("title", text: "Integration Test Report")
                  image("logo", source: "/logo.png")
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  label("group", text: "Customer Group")
                end
              end

              band :detail do
                elements do
                  field(:name, source: [:name])
                  field(:email, source: [:email])
                  expression(:display, expression: expr(name <> " <" <> email <> ">"))
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate(:count, function: :count, source: [:id])
                end
              end

              band :summary do
                elements do
                  aggregate(:total, function: :count, source: [:id])
                  label("end", text: "Report Complete")
                end
              end
            end
          end
        end
      end

      # Should pass all validations (reports, bands, and elements)
      assert FullIntegrationDomain
      assert FullIntegrationDomain.Reports.FullIntegration
    end
  end

  describe "comprehensive element validation" do
    test "validates elements in deeply nested band structures" do
      # Test that element validation works correctly in complex nested scenarios

      defmodule DeepElementValidationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :deep_element_validation do
            title("Deep Element Validation")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :level1, type: :group_header, group_level: 1 do
                elements do
                  label("level1_label", text: "Level 1 Group")
                  line("level1_separator")
                end

                bands do
                  band :level2, type: :group_header, group_level: 2 do
                    elements do
                      label("level2_label", text: "Level 2 Group")
                      image("level2_icon", source: "/icons/level2.png")
                    end

                    bands do
                      band :level3, type: :group_header, group_level: 3 do
                        elements do
                          label("level3_label", text: "Level 3 Group")
                          box("level3_container")
                        end
                      end

                      band :detail do
                        elements do
                          field(:name_field, source: [:name])
                          field(:email_field, source: [:email])
                          expression(:full_contact, expression: expr(name <> " - " <> email))
                          aggregate(:count_in_group, function: :count, source: [:id])
                        end
                      end

                      band :level3_footer, type: :group_footer, group_level: 3 do
                        elements do
                          aggregate(:level3_total, function: :count, source: [:id])
                          label("level3_footer_label", text: "Level 3 Summary")
                        end
                      end
                    end
                  end

                  band :level2_footer, type: :group_footer, group_level: 2 do
                    elements do
                      aggregate(:level2_total, function: :sum, source: [:amount])
                      label("level2_footer_label", text: "Level 2 Summary")
                    end
                  end
                end
              end

              band :level1_footer, type: :group_footer, group_level: 1 do
                elements do
                  aggregate(:level1_total, function: :average, source: [:amount])
                  label("level1_footer_label", text: "Level 1 Summary")
                end
              end
            end
          end
        end
      end

      # Should validate all elements across all nesting levels
      assert DeepElementValidationDomain
      assert DeepElementValidationDomain.Reports.DeepElementValidation
    end

    test "catches duplicate element names in deeply nested structures" do
      # Test that duplicate element names are caught across all nesting levels

      assert_raise Spark.Error.DslError, ~r/Duplicate element names found in band/, fn ->
        defmodule DeepElementDuplicatesDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :deep_element_duplicates do
              title("Deep Element Duplicates")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :group_header, group_level: 1 do
                  elements do
                    label("duplicate_name", text: "First Label")
                    # Duplicate in same band
                    field(:duplicate_name, source: [:name])
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
          end
        end
      end
    end

    test "validates complex field source paths" do
      # Test validation of complex field source paths

      defmodule ComplexFieldSourceDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_field_source do
            title("Complex Field Source")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  field(:simple_field, source: [:name])
                  field(:nested_field, source: [:address, :city])
                  field(:deep_nested_field, source: [:orders, :items, :product, :name])
                  field(:array_access, source: [:tags, 0])
                  field(:complex_path, source: [:profile, :settings, :notifications, :email])
                end
              end
            end
          end
        end
      end

      # Should accept complex source paths
      assert ComplexFieldSourceDomain
      assert ComplexFieldSourceDomain.Reports.ComplexFieldSource
    end

    test "validates expression elements with complex expressions" do
      # Test validation of complex expression elements

      defmodule ComplexExpressionDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_expression do
            title("Complex Expression")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  # Simple expression
                  expression(:simple_expr, expression: expr(name))

                  # Complex expression with concatenation
                  expression(:concat_expr, expression: expr(first_name <> " " <> last_name))

                  # Expression with arithmetic
                  expression(:calc_expr, expression: expr(amount * 0.1))

                  # Expression with conditionals (when available)
                  expression(:conditional_expr, expression: expr(if(amount > 100, "High", "Low")))

                  # Expression with function calls
                  expression(:func_expr, expression: expr(upper(name)))
                end
              end
            end
          end
        end
      end

      # Should accept complex expressions
      assert ComplexExpressionDomain
      assert ComplexExpressionDomain.Reports.ComplexExpression
    end

    test "validates all aggregate function types with different sources" do
      # Test all aggregate functions with various source types

      defmodule AllAggregateFunctionsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :all_aggregate_functions do
            title("All Aggregate Functions")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :summary do
                elements do
                  # Test each aggregate function
                  aggregate(:sum_amount, function: :sum, source: [:amount])
                  aggregate(:count_records, function: :count, source: [:id])
                  aggregate(:avg_amount, function: :average, source: [:amount])
                  aggregate(:min_amount, function: :min, source: [:amount])
                  aggregate(:max_amount, function: :max, source: [:amount])

                  # Test with nested sources
                  aggregate(:sum_nested, function: :sum, source: [:orders, :amount])
                  aggregate(:count_nested, function: :count, source: [:orders, :id])

                  # Test with complex sources
                  aggregate(:avg_complex,
                    function: :average,
                    source: [:profile, :metrics, :score]
                  )
                end
              end
            end
          end
        end
      end

      # Should accept all aggregate functions and source types
      assert AllAggregateFunctionsDomain
      assert AllAggregateFunctionsDomain.Reports.AllAggregateFunctions
    end

    test "validates image elements with various source types" do
      # Test image elements with different source formats

      defmodule ImageSourceTypesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :image_source_types do
            title("Image Source Types")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :header do
                elements do
                  # Static image path
                  image("static_image", source: "/assets/logo.png")

                  # Dynamic image from field
                  image("dynamic_image", source: [:profile_picture])

                  # Image from nested field
                  image("nested_image", source: [:company, :logo_url])

                  # Image with URL
                  image("url_image", source: "https://example.com/image.jpg")

                  # Image with relative path
                  image("relative_image", source: "./images/banner.png")
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

      # Should accept various image source formats
      assert ImageSourceTypesDomain
      assert ImageSourceTypesDomain.Reports.ImageSourceTypes
    end

    test "element validation performance with large numbers of elements" do
      # Test verifier performance with many elements

      elements =
        for i <- 1..200 do
          type =
            case rem(i, 7) do
              0 -> :field
              1 -> :label
              2 -> :expression
              3 -> :aggregate
              4 -> :line
              5 -> :box
              6 -> :image
            end

          case type do
            :field ->
              quote do
                field(unquote(:"field_#{i}"), source: [:name])
              end

            :label ->
              quote do
                label(unquote(:"label_#{i}"), text: unquote("Label #{i}"))
              end

            :expression ->
              quote do
                expression(unquote(:"expr_#{i}"), expression: expr(name))
              end

            :aggregate ->
              func = Enum.random([:sum, :count, :average, :min, :max])

              quote do
                aggregate(unquote(:"agg_#{i}"), function: unquote(func), source: [:amount])
              end

            :line ->
              quote do
                line(unquote(:"line_#{i}"))
              end

            :box ->
              quote do
                box(unquote(:"box_#{i}"))
              end

            :image ->
              quote do
                image(unquote(:"image_#{i}"), source: unquote("/image_#{i}.png"))
              end
          end
        end

      module_ast =
        quote do
          defmodule LargeElementsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :large_elements do
                title("Large Elements Report")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      (unquote_splicing(elements))
                    end
                  end
                end
              end
            end
          end
        end

      # Should compile successfully and handle large number of elements
      {result, _binding} = Code.eval_quoted(module_ast)
      assert result == LargeElementsDomain
      assert LargeElementsDomain.Reports.LargeElements
    end

    test "validates elements with edge case names and attributes" do
      # Test elements with edge case names and attribute combinations

      defmodule EdgeCaseElementsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :edge_case_elements do
            title("Edge Case Elements")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  # Elements with underscore names
                  field(:field_with_underscores, source: [:name])
                  label("label_with_underscores", text: "Label Text")

                  # Elements with number suffixes
                  field(:field123, source: [:email])
                  label("label456", text: "Number Label")

                  # Elements with CamelCase (converted to atoms)
                  field(:CamelCaseField, source: [:phone])

                  # Elements with special characters in text/source
                  label("special_chars", text: "Text with !@#$%^&*() special chars")
                  image("unicode_image", source: "/images/café_München_北京.png")

                  # Complex nested source paths
                  field(:deeply_nested, source: [:level1, :level2, :level3, :level4, :field])

                  # Expression with complex logic
                  expression(:complex_logic,
                    expression:
                      expr(
                        if(
                          amount > 1000,
                          "High Value: " <> to_string(amount),
                          "Low Value: " <> to_string(amount)
                        )
                      )
                  )

                  # All aggregate functions
                  aggregate(:sum_test, function: :sum, source: [:amount])
                  aggregate(:count_test, function: :count, source: [:id])
                  aggregate(:avg_test, function: :average, source: [:score])
                  aggregate(:min_test, function: :min, source: [:date])
                  aggregate(:max_test, function: :max, source: [:date])
                end
              end
            end
          end
        end
      end

      # Should handle all edge cases correctly
      assert EdgeCaseElementsDomain
      assert EdgeCaseElementsDomain.Reports.EdgeCaseElements
    end

    test "validates element error messages include full DSL path" do
      # Test that element validation errors include complete DSL path context

      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule ElementPathErrorDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :element_path_error do
                title("Element Path Error")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :group_header, group_level: 1 do
                    elements do
                      label("valid_label", text: "Valid Label")
                    end

                    bands do
                      band :nested_band do
                        elements do
                          # Missing source to trigger error
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

      # Error should include complete path to the problematic element
      assert error.path == [
               :reports,
               :element_path_error,
               :bands,
               :nested_band,
               :elements,
               :invalid_field
             ]

      assert error.module == ElementPathErrorDomain
    end

    test "validates mixed element types within single band" do
      # Test that various element types can coexist in the same band

      defmodule MixedElementTypesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :mixed_element_types do
            title("Mixed Element Types")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :mixed_band do
                elements do
                  # Mix all element types in one band
                  label("header_label", text: "Customer Information")
                  line("top_separator")
                  image("customer_avatar", source: [:avatar_url])
                  field(:customer_name, source: [:name])
                  field(:customer_email, source: [:email])
                  expression(:display_name, expression: expr(name <> " (" <> email <> ")"))
                  box("info_container")
                  aggregate(:total_orders, function: :count, source: [:orders, :id])
                  aggregate(:total_spent, function: :sum, source: [:orders, :amount])
                  line("bottom_separator")
                  label("footer_label", text: "End of Customer Info")
                end
              end
            end
          end
        end
      end

      # Should successfully validate mixed element types
      assert MixedElementTypesDomain
      assert MixedElementTypesDomain.Reports.MixedElementTypes
    end

    test "validates element types that don't require additional properties" do
      # Test that line and box elements are validated correctly without additional properties

      defmodule SimpleElementTypesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :simple_element_types do
            title("Simple Element Types")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail do
                elements do
                  # Line elements (no additional properties required)
                  line(:separator1)
                  line("separator2")
                  line(:top_line)
                  line("bottom_line")

                  # Box elements (no additional properties required)
                  box(:container1)
                  box("container2")
                  box(:main_box)
                  box("side_box")

                  # Mixed with a field to make it a valid report
                  field(:name, source: [:name])
                end
              end
            end
          end
        end
      end

      # Should validate line and box elements without additional requirements
      assert SimpleElementTypesDomain
      assert SimpleElementTypesDomain.Reports.SimpleElementTypes
    end
  end

  describe "element source validation" do
    test "validates field elements reject empty or nil sources" do
      # Test that field elements must have valid sources

      assert_raise Spark.Error.DslError, ~r/Field element .* must have a source/, fn ->
        defmodule EmptyFieldSourceDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :empty_field_source do
              title("Empty Field Source")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    # Empty source array
                    field(:empty_source, source: [])
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates aggregate elements reject invalid function types" do
      # Test comprehensive validation of aggregate function types

      invalid_functions = [:invalid, :bad_func, :wrong, :not_supported, 123, "string_func"]

      for invalid_func <- invalid_functions do
        assert_raise Spark.Error.DslError, ~r/Invalid aggregate function/, fn ->
          defmodule Module.concat([InvalidAggregateFunc, invalid_func]) do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :invalid_aggregate_func do
                title("Invalid Aggregate Function")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :detail do
                    elements do
                      aggregate :invalid_agg do
                        function(invalid_func)
                        source [:amount]
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

    test "validates complex element validation edge cases" do
      # Test various edge cases in element validation

      # Test expression with nil expression
      assert_raise Spark.Error.DslError, ~r/Expression element .* must have an expression/, fn ->
        defmodule NilExpressionDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :nil_expression do
              title("Nil Expression")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    expression(:nil_expr, expression: nil)
                  end
                end
              end
            end
          end
        end
      end

      # Test label with empty text
      assert_raise Spark.Error.DslError, ~r/Label element .* must have text/, fn ->
        defmodule EmptyLabelTextDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :empty_label_text do
              title("Empty Label Text")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    # Empty string
                    label("empty_text", text: "")
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
