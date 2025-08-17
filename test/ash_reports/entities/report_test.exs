defmodule AshReports.Entities.ReportTest do
  @moduledoc """
  Tests for AshReports.Report entity structure and validation.
  """

  use ExUnit.Case, async: true

  import AshReports.TestHelpers
  alias AshReports.Report

  describe "Report struct creation" do
    test "creates report with required fields" do
      report = %Report{
        name: :test_report,
        driving_resource: AshReports.Test.Customer
      }

      assert report.name == :test_report
      assert report.driving_resource == AshReports.Test.Customer
    end

    test "creates report with all optional fields" do
      report = %Report{
        name: :test_report,
        title: "Test Report",
        description: "A test report",
        driving_resource: AshReports.Test.Customer,
        scope: {:filter, :active},
        permissions: [:read_reports],
        formats: [:html, :pdf],
        parameters: [],
        variables: [],
        groups: [],
        bands: []
      }

      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.description == "A test report"
      assert report.driving_resource == AshReports.Test.Customer
      assert report.scope == {:filter, :active}
      assert report.permissions == [:read_reports]
      assert report.formats == [:html, :pdf]
      assert report.parameters == []
      assert report.variables == []
      assert report.groups == []
      assert report.bands == []
    end

    test "sets default values for optional fields" do
      report = %Report{
        name: :test_report,
        driving_resource: AshReports.Test.Customer
      }

      # Test that nil/empty defaults are handled properly
      assert is_nil(report.title) || report.title == ""
      assert is_nil(report.description) || report.description == ""
      assert is_list(report.parameters)
      assert is_list(report.variables)
      assert is_list(report.groups)
      assert is_list(report.bands)
    end
  end

  describe "Report field validation" do
    test "validates name is an atom" do
      # Test through DSL parsing which enforces type validation
      dsl_content = """
      reports do
        report "invalid_name" do
          title "Test Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """

      # Should fail because name must be an atom, not a string
      assert_dsl_error(dsl_content, "expected")
    end

    test "validates driving_resource is provided" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "validates title is a string when provided" do
      dsl_content = """
      reports do
        report :test_report do
          title :invalid_title_atom
          driving_resource AshReports.Test.Customer
        end
      end
      """

      assert_dsl_error(dsl_content, "expected")
    end

    test "validates description is a string when provided" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          description 123
          driving_resource AshReports.Test.Customer
        end
      end
      """

      assert_dsl_error(dsl_content, "expected")
    end

    test "validates formats is a list of valid format atoms" do
      # Valid formats
      valid_formats = [
        [:html],
        [:pdf],
        [:heex],
        [:json],
        [:html, :pdf],
        [:html, :pdf, :heex, :json]
      ]

      for formats <- valid_formats do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            formats #{inspect(formats)}
          end
        end
        """

        assert_dsl_valid(dsl_content)
      end

      # Invalid format
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          formats [:html, :invalid_format]
        end
      end
      """

      assert_dsl_error(dsl_content, "invalid_format")
    end

    test "validates permissions is a list of atoms" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          permissions [:read_reports, :admin]
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end
  end

  describe "Report entity relationships" do
    test "can contain parameters" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter :start_date, :date do
              required true
            end
            
            parameter :region, :string do
              default "All"
            end
          end
        end
      end
      """

      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)

      parameters = Map.get(report, :parameters, [])
      assert length(parameters) == 2

      start_date_param = Enum.find(parameters, &(&1.name == :start_date))
      assert start_date_param.type == :date
      assert start_date_param.required == true

      region_param = Enum.find(parameters, &(&1.name == :region))
      assert region_param.type == :string
      assert region_param.default == "All"
    end

    test "can contain variables" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :total_count do
              type :count
              expression :id
              reset_on :report
            end
            
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :group
            end
          end
        end
      end
      """

      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)

      variables = Map.get(report, :variables, [])
      assert length(variables) == 2

      count_var = Enum.find(variables, &(&1.name == :total_count))
      assert count_var.type == :count
      assert count_var.reset_on == :report

      sales_var = Enum.find(variables, &(&1.name == :total_sales))
      assert sales_var.type == :sum
      assert sales_var.reset_on == :group
    end

    test "can contain groups" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_region do
              level 1
              expression :region
              sort :asc
            end
            
            group :by_status do
              level 2
              expression :status
              sort :desc
            end
          end
        end
      end
      """

      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)

      groups = Map.get(report, :groups, [])
      assert length(groups) == 2

      region_group = Enum.find(groups, &(&1.name == :by_region))
      assert region_group.level == 1
      assert region_group.sort == :asc

      status_group = Enum.find(groups, &(&1.name == :by_status))
      assert status_group.level == 2
      assert status_group.sort == :desc
    end

    test "can contain bands with elements" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                label :title_label do
                  text "Report Title"
                  position [x: 0, y: 0]
                end
              end
            end
            
            band :detail do
              type :detail
              
              elements do
                field :name_field do
                  source :name
                  position [x: 0, y: 0]
                end
                
                field :email_field do
                  source :email
                  position [x: 100, y: 0]
                end
              end
            end
          end
        end
      end
      """

      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)

      bands = Map.get(report, :bands, [])
      assert length(bands) == 2

      title_band = Enum.find(bands, &(&1.name == :title))
      assert title_band.type == :title

      title_elements = Map.get(title_band, :elements, [])
      assert length(title_elements) == 1

      detail_band = Enum.find(bands, &(&1.name == :detail))
      assert detail_band.type == :detail

      detail_elements = Map.get(detail_band, :elements, [])
      assert length(detail_elements) == 2
    end
  end

  describe "Report complex scenarios" do
    test "handles empty report structure" do
      dsl_content = """
      reports do
        report :minimal_report do
          title "Minimal Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """

      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)

      assert report.name == :minimal_report
      assert report.title == "Minimal Report"
      assert report.driving_resource == AshReports.Test.Customer

      # Check that collections are properly initialized (empty lists or nil)
      parameters = Map.get(report, :parameters, [])
      variables = Map.get(report, :variables, [])
      groups = Map.get(report, :groups, [])
      bands = Map.get(report, :bands, [])

      assert is_list(parameters)
      assert is_list(variables)
      assert is_list(groups)
      assert is_list(bands)
    end

    test "handles report with all entity types" do
      dsl_content = """
      reports do
        report :comprehensive_report do
          title "Comprehensive Report"
          description "A report with all entity types"
          driving_resource AshReports.Test.Order
          formats [:html, :pdf, :json]
          permissions [:read_reports, :admin]
          
          parameters do
            parameter :start_date, :date do
              required true
            end
          end
          
          variables do
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :report
            end
          end
          
          groups do
            group :by_region do
              level 1
              expression {:field, :customer, :region}
            end
          end
          
          bands do
            band :title do
              type :title
              
              elements do
                label :title_label do
                  text "Sales Report"
                end
              end
            end
            
            band :detail do
              type :detail
              
              elements do
                field :order_number do
                  source :order_number
                end
              end
            end
          end
        end
      end
      """

      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)

      assert report.name == :comprehensive_report
      assert report.title == "Comprehensive Report"
      assert report.description == "A report with all entity types"
      assert report.driving_resource == AshReports.Test.Order
      assert report.formats == [:html, :pdf, :json]
      assert report.permissions == [:read_reports, :admin]

      # Verify all child entities are present
      parameters = Map.get(report, :parameters, [])
      variables = Map.get(report, :variables, [])
      groups = Map.get(report, :groups, [])
      bands = Map.get(report, :bands, [])

      assert length(parameters) == 1
      assert length(variables) == 1
      assert length(groups) == 1
      assert length(bands) == 2
    end

    test "validates unique report names within domain" do
      dsl_content = """
      reports do
        report :duplicate_name do
          title "First Report"
          driving_resource AshReports.Test.Customer
        end
        
        report :duplicate_name do
          title "Second Report"
          driving_resource AshReports.Test.Order
        end
      end
      """

      # This should pass DSL parsing but fail at verifier level
      # The actual uniqueness validation happens in verifiers
      {:ok, _dsl_state} = parse_dsl(dsl_content)
    end
  end
end
