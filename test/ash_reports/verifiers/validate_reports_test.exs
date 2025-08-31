defmodule AshReports.Verifiers.ValidateReportsTest do
  use ExUnit.Case, async: false

  alias DslError

  describe "ValidateReports verifier" do
    test "accepts valid report definitions" do
      # This should compile without errors
      defmodule ValidDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :valid_report do
            title("Valid Report")
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

      # If we get here, validation passed
      assert ValidDomain
      assert ValidDomain.Reports.ValidReport.definition().name == :valid_report
    end

    test "rejects reports with duplicate names" do
      assert_raise DslError, ~r/Duplicate report names found/, fn ->
        defmodule DuplicateNamesDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :duplicate_name do
              title("First Report")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :detail do
                  elements do
                    field(:name, source: [:name])
                  end
                end
              end
            end

            report :duplicate_name do
              title("Second Report")
              driving_resource(AshReports.Test.Customer)

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
    end

    test "rejects reports without driving_resource" do
      assert_raise DslError, ~r/must specify a driving_resource/, fn ->
        defmodule NoDrivingResourceDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :no_driving_resource do
              title("Report Without Driving Resource")
              # missing driving_resource

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

    test "rejects reports without detail bands" do
      assert_raise DslError, ~r/must have at least one detail band/, fn ->
        defmodule NoDetailBandDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :no_detail_band do
              title("Report Without Detail Band")
              driving_resource(AshReports.Test.Customer)

              bands do
                band :title do
                  elements do
                    label("Title", text: "Report Title")
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
      end
    end

    test "validates driving_resource is an atom" do
      assert_raise DslError, ~r/must be an atom representing an Ash\.Resource/, fn ->
        defmodule InvalidDrivingResourceDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :invalid_driving_resource do
              title("Invalid Driving Resource")
              driving_resource("not_an_atom")

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

    test "accepts multiple valid reports" do
      defmodule MultipleValidReportsDomain do
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

          report :summary_report do
            title("Summary Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("Summary", text: "Customer Summary")
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
                  label("Total", text: "Total Customers")
                end
              end
            end
          end
        end
      end

      # All reports should be valid
      assert MultipleValidReportsDomain
      assert MultipleValidReportsDomain.Reports.CustomerReport
      assert MultipleValidReportsDomain.Reports.OrderReport
      assert MultipleValidReportsDomain.Reports.SummaryReport
    end

    test "validates report with complex band structure" do
      defmodule ComplexBandDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :complex_report do
            title("Complex Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("Title", text: "Customer Report")
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
                  label("Email", text: "Email Address")
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
                  field(:email, source: [:email])
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  label("Group Total", text: "Group Summary")
                end
              end

              band :column_footer do
                elements do
                  label("Total", text: "Total Customers")
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

      # Complex structure should be valid as long as it has detail band
      assert ComplexBandDomain
      assert ComplexBandDomain.Reports.ComplexReport
    end

    test "validates reports with multiple detail bands" do
      defmodule MultipleDetailBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :multiple_details do
            title("Multiple Detail Bands Report")
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

      # Multiple detail bands should be valid
      assert MultipleDetailBandsDomain
      assert MultipleDetailBandsDomain.Reports.MultipleDetails
    end

    test "error messages include proper DSL path context" do
      error =
        assert_raise DslError, fn ->
          defmodule DslPathTestDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :path_test do
                title("Path Test Report")
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

      # Error should include the DSL path
      assert error.path == [:reports, :path_test]
      assert error.module == DslPathTestDomain
    end

    test "validates nested band structures with detail bands" do
      defmodule NestedBandsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :nested_bands do
            title("Nested Bands Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :group_header, group_level: 1 do
                elements do
                  label("Group", text: "Main Group")
                end

                bands do
                  band :group_header, group_level: 2 do
                    elements do
                      label("Subgroup", text: "Sub Group")
                    end
                  end

                  band :detail do
                    elements do
                      field(:name, source: [:name])
                    end
                  end

                  band :group_footer, group_level: 2 do
                    elements do
                      label("Subgroup Total", text: "Sub Group Total")
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  label("Group Total", text: "Main Group Total")
                end
              end
            end
          end
        end
      end

      # Nested structure with detail band should be valid
      assert NestedBandsDomain
      assert NestedBandsDomain.Reports.NestedBands
    end
  end

  describe "required fields validation" do
    test "accepts reports with all required fields" do
      defmodule AllRequiredFieldsDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :all_required_fields do
            title("Complete Report")
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

      assert AllRequiredFieldsDomain
    end
  end

  describe "integration with other verifiers" do
    test "works correctly when combined with band and element validation" do
      defmodule IntegratedValidationDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :integrated_report do
            title("Integrated Validation Report")
            driving_resource(AshReports.Test.Customer)

            bands do
              band :title do
                elements do
                  label("Title", text: "Report Title")
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
        end
      end

      # Should pass all validations
      assert IntegratedValidationDomain
      assert IntegratedValidationDomain.Reports.IntegratedReport
    end
  end
end
