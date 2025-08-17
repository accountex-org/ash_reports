defmodule AshReports.Verifiers.ValidateBandsTest do
  use ExUnit.Case, async: false

  describe "ValidateBands verifier" do
    test "accepts valid band definitions" do
      defmodule ValidBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :valid_bands do
            title("Valid Bands Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("Title", text: "Report Title")
                end
              end

              band :page_header do
                elements do
                  label("Header", text: "Page Header")
                end
              end

              band :detail do
                elements do
                  field(:name, source: [:name])
                end
              end

              band :summary do
                elements do
                  label("Summary", text: "Report Summary")
                end
              end
            end
          end
        end
      end

      assert ValidBandsDomain
      assert ValidBandsDomain.Reports.ValidBands
    end

    test "rejects bands with duplicate names within a report" do
      assert_raise Spark.Error.DslError, ~r/Duplicate band names found in report/, fn ->
        defmodule DuplicateBandNamesDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :duplicate_bands do
              title("Duplicate Band Names")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
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
    end

    test "validates band types are from allowed list" do
      assert_raise Spark.Error.DslError, ~r/Invalid band type/, fn ->
        defmodule InvalidBandTypeDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_band_type do
              title("Invalid Band Type")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :invalid_type do
                  type :not_a_valid_type

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
    end

    test "validates group bands have group_level" do
      assert_raise Spark.Error.DslError, ~r/Group band .* must specify a group_level/, fn ->
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
                    label("Group", text: "Group Header")
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

    test "validates group_level is positive integer" do
      assert_raise Spark.Error.DslError, ~r/must have a positive integer group_level/, fn ->
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
                band :group_header, group_level: 0 do
                  elements do
                    label("Group", text: "Group Header")
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

    test "validates detail band numbers are sequential starting from 1" do
      assert_raise Spark.Error.DslError, ~r/Detail band numbers must be sequential/, fn ->
        defmodule NonSequentialDetailDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :non_sequential_detail do
              title("Non Sequential Detail Numbers")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail, detail_number: 1 do
                  elements do
                    field(:name, source: [:name])
                  end
                end

                # Missing 2
                band :detail, detail_number: 3 do
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

    test "accepts sequential detail band numbers" do
      defmodule SequentialDetailDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :sequential_detail do
            title("Sequential Detail Numbers")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :detail, detail_number: 1 do
                elements do
                  field(:name, source: [:name])
                end
              end

              band :detail, detail_number: 2 do
                elements do
                  field(:email, source: [:email])
                end
              end

              band :detail, detail_number: 3 do
                elements do
                  field(:phone, source: [:phone])
                end
              end
            end
          end
        end
      end

      assert SequentialDetailDomain
      assert SequentialDetailDomain.Reports.SequentialDetail
    end

    test "validates band hierarchy - title must be first" do
      assert_raise Spark.Error.DslError, ~r/Title band must be the first band/, fn ->
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
                    label("Title", text: "Report Title")
                  end
                end
              end
            end
          end
        end
      end
    end

    test "validates band hierarchy - summary must be last" do
      assert_raise Spark.Error.DslError, ~r/Summary band must be the last band/, fn ->
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
                    label("Summary", text: "Report Summary")
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

    test "accepts proper band hierarchy" do
      defmodule ProperHierarchyDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :proper_hierarchy do
            title("Proper Hierarchy")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("Title", text: "Report Title")
                end
              end

              band :page_header do
                elements do
                  label("Header", text: "Page Header")
                end
              end

              band :column_header do
                elements do
                  label("Name", text: "Customer Name")
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  label("Group", text: "Customer Group")
                end
              end

              band :detail do
                elements do
                  field(:name, source: [:name])
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  label("Group Total", text: "Group Summary")
                end
              end

              band :column_footer do
                elements do
                  label("Total", text: "Total Records")
                end
              end

              band :page_footer do
                elements do
                  label("Footer", text: "Page Footer")
                end
              end

              band :summary do
                elements do
                  label("Summary", text: "Report Summary")
                end
              end
            end
          end
        end
      end

      assert ProperHierarchyDomain
      assert ProperHierarchyDomain.Reports.ProperHierarchy
    end

    test "validates nested band structures" do
      defmodule NestedBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :nested_bands do
            title("Nested Bands")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :group_header, group_level: 1 do
                elements do
                  label("Main Group", text: "Main Group Header")
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      label("Sub Group", text: "Sub Group Header")
                    end
                  end

                  band :detail do
                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      label("Sub Total", text: "Sub Group Total")
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  label("Main Total", text: "Main Group Total")
                end
              end
            end
          end
        end
      end

      assert NestedBandsDomain
      assert NestedBandsDomain.Reports.NestedBands
    end

    test "rejects duplicate band names across nested structures" do
      assert_raise Spark.Error.DslError, ~r/Duplicate band names found/, fn ->
        defmodule DuplicateNestedBandsDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :duplicate_nested do
              title("Duplicate Nested Bands")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :duplicate_name do
                  elements do
                    label("First", text: "First Band")
                  end
                end

                band :group_header, group_level: 1 do
                  elements do
                    label("Group", text: "Group Header")
                  end

                  bands do
                    # Duplicate name
                    band :duplicate_name do
                      elements do
                        field(:name, source: [:name])
                      end
                    end
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
    end

    test "validates all band types are supported" do
      defmodule AllBandTypesDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :all_band_types do
            title("All Band Types")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title_band, type: :title do
                elements do
                  label("Title", text: "Report Title")
                end
              end

              band :page_header_band, type: :page_header do
                elements do
                  label("Header", text: "Page Header")
                end
              end

              band :column_header_band, type: :column_header do
                elements do
                  label("Name", text: "Name Column")
                end
              end

              band :group_header_band, type: :group_header, group_level: 1 do
                elements do
                  label("Group", text: "Group Header")
                end
              end

              band :detail_header_band, type: :detail_header do
                elements do
                  label("Detail Header", text: "Detail Section")
                end
              end

              band :detail_band, type: :detail do
                elements do
                  field(:name, source: [:name])
                end
              end

              band :detail_footer_band, type: :detail_footer do
                elements do
                  label("Detail Footer", text: "End of Details")
                end
              end

              band :group_footer_band, type: :group_footer, group_level: 1 do
                elements do
                  label("Group Footer", text: "Group Total")
                end
              end

              band :column_footer_band, type: :column_footer do
                elements do
                  label("Column Footer", text: "Column Total")
                end
              end

              band :page_footer_band, type: :page_footer do
                elements do
                  label("Footer", text: "Page Footer")
                end
              end

              band :summary_band, type: :summary do
                elements do
                  label("Summary", text: "Report Summary")
                end
              end
            end
          end
        end
      end

      assert AllBandTypesDomain
      assert AllBandTypesDomain.Reports.AllBandTypes
    end

    test "validates multi-level group bands" do
      defmodule MultiLevelGroupsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :multi_level_groups do
            title("Multi Level Groups")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :group1_header, type: :group_header, group_level: 1 do
                elements do
                  label("Level 1", text: "Group Level 1")
                end
              end

              band :group2_header, type: :group_header, group_level: 2 do
                elements do
                  label("Level 2", text: "Group Level 2")
                end
              end

              band :group3_header, type: :group_header, group_level: 3 do
                elements do
                  label("Level 3", text: "Group Level 3")
                end
              end

              band :detail do
                elements do
                  field(:name, source: [:name])
                end
              end

              band :group3_footer, type: :group_footer, group_level: 3 do
                elements do
                  label("Level 3 Total", text: "Group Level 3 Total")
                end
              end

              band :group2_footer, type: :group_footer, group_level: 2 do
                elements do
                  label("Level 2 Total", text: "Group Level 2 Total")
                end
              end

              band :group1_footer, type: :group_footer, group_level: 1 do
                elements do
                  label("Level 1 Total", text: "Group Level 1 Total")
                end
              end
            end
          end
        end
      end

      assert MultiLevelGroupsDomain
      assert MultiLevelGroupsDomain.Reports.MultiLevelGroups
    end

    test "error messages include proper DSL path context" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule BandErrorPathDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :band_error_path do
                title("Band Error Path")
                driving_resource(AshReports.Test.Customer)

                bands do
                  band :invalid_group, type: :group_header do
                    # Missing group_level to trigger error
                    elements do
                      label("Group", text: "Group Header")
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

      # Error should include the DSL path
      assert error.path == [:reports, :band_error_path, :bands, :invalid_group]
      assert error.module == BandErrorPathDomain
    end

    test "validates complex nested band hierarchy with multiple validation errors" do
      # Test that verifier correctly handles reports with complex nested structures
      # and validates all bands, including deeply nested ones

      defmodule ComplexNestedValidationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_nested_validation do
            title("Complex Nested Validation")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("title", text: "Report Title")
                end
              end

              band :group_level1, type: :group_header, group_level: 1 do
                elements do
                  label("group1", text: "Level 1 Group")
                end

                bands do
                  band :group_level2, type: :group_header, group_level: 2 do
                    elements do
                      label("group2", text: "Level 2 Group")
                    end

                    bands do
                      band :group_level3, type: :group_header, group_level: 3 do
                        elements do
                          label("group3", text: "Level 3 Group")
                        end
                      end

                      band :detail do
                        elements do
                          field(:name, source: [:name])
                          field(:email, source: [:email])
                        end
                      end

                      band :group_level3_footer, type: :group_footer, group_level: 3 do
                        elements do
                          label("group3_footer", text: "Level 3 Footer")
                        end
                      end
                    end
                  end

                  band :group_level2_footer, type: :group_footer, group_level: 2 do
                    elements do
                      label("group2_footer", text: "Level 2 Footer")
                    end
                  end
                end
              end

              band :group_level1_footer, type: :group_footer, group_level: 1 do
                elements do
                  label("group1_footer", text: "Level 1 Footer")
                end
              end

              band :summary do
                elements do
                  label("summary", text: "Report Summary")
                end
              end
            end
          end
        end
      end

      # Should validate successfully with proper nested structure
      assert ComplexNestedValidationDomain
      assert ComplexNestedValidationDomain.Reports.ComplexNestedValidation
    end

    test "validates band types across all levels of nesting" do
      # Test that all band types are validated, including in deeply nested structures

      assert_raise Spark.Error.DslError, ~r/Invalid band type/, fn ->
        defmodule NestedInvalidTypeDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :nested_invalid_type do
              title("Nested Invalid Type")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :group_header, group_level: 1 do
                  elements do
                    label("group", text: "Group Header")
                  end

                  bands do
                    band :invalid_nested_band do
                      # Invalid type in nested structure
                      type :invalid_nested_type

                      elements do
                        field(:name, source: [:name])
                      end
                    end
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
    end

    test "validates group levels are consistent within nested structures" do
      # Test validation of group levels in complex nested scenarios

      assert_raise Spark.Error.DslError, ~r/must have a positive integer group_level/, fn ->
        defmodule InconsistentGroupLevelsDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :inconsistent_group_levels do
              title("Inconsistent Group Levels")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :group1, type: :group_header, group_level: 1 do
                  elements do
                    label("group1", text: "Group 1")
                  end

                  bands do
                    # Invalid negative level
                    band :group2, type: :group_header, group_level: -1 do
                      elements do
                        label("group2", text: "Group 2")
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
    end

    test "validates detail band numbering across complex structures" do
      # Test validation of detail band numbers in nested scenarios

      assert_raise Spark.Error.DslError, ~r/Detail band numbers must be sequential/, fn ->
        defmodule ComplexDetailNumberingDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :complex_detail_numbering do
              title("Complex Detail Numbering")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :group1, type: :group_header, group_level: 1 do
                  elements do
                    label("group1", text: "Group 1")
                  end

                  bands do
                    band :detail1, type: :detail, detail_number: 1 do
                      elements do
                        field(:name, source: [:name])
                      end
                    end

                    # Missing detail_number 2
                    band :detail3, type: :detail, detail_number: 3 do
                      elements do
                        field(:email, source: [:email])
                      end
                    end
                  end
                end

                band :detail4, type: :detail, detail_number: 4 do
                  elements do
                    field(:phone, source: [:phone])
                  end
                end
              end
            end
          end
        end
      end
    end

    test "handles empty bands lists gracefully" do
      # Test that verifier handles edge case of reports with no bands

      defmodule EmptyBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :empty_bands do
            title("Empty Bands")
            driving_resource(AshReports.Test.Customer)
            # No bands section - should be handled gracefully
          end
        end
      end

      # Should not crash, but this would be caught by ValidateReports
      # since reports must have at least one detail band
      assert_raise Spark.Error.DslError, ~r/must have at least one detail band/, fn ->
        EmptyBandsDomain
      end
    end

    test "validates band hierarchy ordering with complex structures" do
      # Test more complex hierarchy validation scenarios

      assert_raise Spark.Error.DslError, ~r/Title band must be the first band/, fn ->
        defmodule ComplexHierarchyDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :complex_hierarchy do
              title("Complex Hierarchy")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :group_header, group_level: 1 do
                  elements do
                    label("group", text: "Group Header")
                  end

                  bands do
                    # Title should not be nested
                    band :title do
                      elements do
                        label("title", text: "Nested Title")
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
    end

    test "verifier performance with large numbers of bands" do
      # Test that verifier can handle reports with many bands efficiently

      bands =
        for i <- 1..100 do
          quote do
            band unquote(:"detail_#{i}"), type: :detail, detail_number: unquote(i) do
              elements do
                field(unquote(:"field_#{i}"), source: [:name])
              end
            end
          end
        end

      module_ast =
        quote do
          defmodule LargeBandsDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :large_bands do
                title("Large Bands Report")
                driving_resource(AshReports.Test.Customer)

                bands do
                  (unquote_splicing(bands))
                end
              end
            end
          end
        end

      # Should compile successfully and handle large number of bands
      {result, _binding} = Code.eval_quoted(module_ast)
      assert result == LargeBandsDomain
      assert LargeBandsDomain.Reports.LargeBands
    end

    test "validates band name uniqueness across deeply nested structures" do
      # Test that band name uniqueness is enforced across all levels of nesting

      assert_raise Spark.Error.DslError, ~r/Duplicate band names found/, fn ->
        defmodule DeepNestingDuplicatesDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :deep_nesting_duplicates do
              title("Deep Nesting Duplicates")
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
                        band :level3, type: :group_header, group_level: 3 do
                          elements do
                            label("level3", text: "Level 3")
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

                # Duplicate name at different nesting level
                band :level1 do
                  elements do
                    label("duplicate", text: "Duplicate Level 1")
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe "detail band validation" do
    test "accepts detail bands without detail_number" do
      defmodule SingleDetailDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :single_detail do
            title("Single Detail")
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

      assert SingleDetailDomain
    end

    test "validates detail_number sequence across nested bands" do
      defmodule NestedDetailSequenceDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :nested_detail_sequence do
            title("Nested Detail Sequence")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :group_header, group_level: 1 do
                elements do
                  label("Group", text: "Group Header")
                end

                bands do
                  band :detail, detail_number: 1 do
                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  band :detail, detail_number: 2 do
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

      assert NestedDetailSequenceDomain
    end
  end
end
