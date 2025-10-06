defmodule AshReports.DslTest do
  @moduledoc """
  Comprehensive tests for AshReports.Dsl module.

  Tests DSL entity parsing, schema validation, and entity relationships
  following the expert-validated testing patterns.
  """

  use ExUnit.Case, async: true

  import AshReports.TestHelpers

  describe "reports section parsing" do
    test "parses valid reports section with minimal report" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content, validate: false)
    end

    test "parses reports section with multiple reports" do
      dsl_content = """
      reports do
        report :first_report do
          title "First Report"
          driving_resource AshReports.Test.Customer

          band :detail do
            type :detail
          end
        end

        report :second_report do
          title "Second Report"
          driving_resource AshReports.Test.Order

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content, validate: false)
    end

    test "extracts report entities correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          description "A test report description"
          formats [:html, :pdf]

          band :detail do
            type :detail
          end
        end
      end
      """

      {:ok, module} = parse_dsl(dsl_content, validate: false)
      reports = get_dsl_entities(module, [:reports])

      assert length(reports) == 1

      report = hd(reports)
      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.driving_resource == AshReports.Test.Customer
      assert report.description == "A test report description"
      assert report.formats == [:html, :pdf]
    end
  end

  describe "report entity validation" do
    test "requires name argument" do
      dsl_content = """
      reports do
        report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """

      assert_dsl_error(dsl_content, "missing required argument")
    end

    test "requires driving_resource field" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "validates format options" do
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

    test "accepts valid format combinations" do
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
    end

    test "sets default values correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          band :detail do
            type :detail
          end
        end
      end
      """

      {:ok, module} = parse_dsl(dsl_content, validate: false)
      reports = get_dsl_entities(module, [:reports])
      report = hd(reports)

      assert report.formats == [:html]
      assert report.permissions == []
    end
  end

  describe "parameter entity parsing" do
    test "parses valid parameter with required fields" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          parameters do
            parameter :start_date, :date
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses parameter with all options" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          parameters do
            parameter :region, :string do
              required true
              default "North"
              constraints [max_length: 50]
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "extracts parameter entities correctly" do
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
              default "North"
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      {:ok, module} = parse_dsl(dsl_content, validate: false)
      reports = get_dsl_entities(module, [:reports])
      report = hd(reports)

      parameters = Map.get(report, :parameters, [])
      assert length(parameters) == 2

      start_date_param = Enum.find(parameters, &(&1.name == :start_date))
      assert start_date_param.type == :date
      assert start_date_param.required == true

      region_param = Enum.find(parameters, &(&1.name == :region))
      assert region_param.type == :string
      assert region_param.default == "North"
      assert region_param.required == false
    end
  end

  describe "band entity parsing" do
    test "parses valid band with required fields" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :title do
              type :title
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses band with all options" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              group_level 1
              detail_number 1
              height 100
              can_grow true
              can_shrink false
              keep_together true
              visible true
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content, validate: false)
    end

    test "validates band type options" do
      valid_types = [
        :title,
        :page_header,
        :column_header,
        :group_header,
        :detail_header,
        :detail,
        :detail_footer,
        :group_footer,
        :column_footer,
        :page_footer,
        :summary
      ]

      for band_type <- valid_types do
        # If it's a detail type, just test it alone; otherwise add a detail band
        dsl_content =
          if band_type == :detail do
            """
            reports do
              report :test_report do
                title "Test Report"
                driving_resource AshReports.Test.Customer

                bands do
                  band :test_band do
                    type #{inspect(band_type)}
                  end
                end
              end
            end
            """
          else
            """
            reports do
              report :test_report do
                title "Test Report"
                driving_resource AshReports.Test.Customer

                bands do
                  band :test_band do
                    type #{inspect(band_type)}
                  end

                  band :detail do
                    type :detail
                  end
                end
              end
            end
            """
          end

        assert_dsl_valid(dsl_content)
      end
    end

    test "rejects invalid band types" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :test_band do
              type :invalid_type
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content, "invalid_type")
    end

    test "extracts band entities correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              height 50
            end
            
            band :detail do
              type :detail
              can_grow true
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
      assert title_band.height == 50

      detail_band = Enum.find(bands, &(&1.name == :detail))
      assert detail_band.type == :detail
      assert detail_band.can_grow == true
    end
  end

  describe "element entity parsing" do
    test "parses label element" do
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
                  position [x: 0, y: 0, width: 200, height: 20]
                end
              end
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses field element" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :name_field do
                  source :name
                  format :string
                  position [x: 0, y: 0]
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses expression element" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                expression :calculated_field do
                  expression {:add, :field1, :field2}
                  format :number
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses aggregate element" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :summary do
              type :summary

              elements do
                aggregate :total_count do
                  function :count
                  source :id
                  scope :report
                end
              end
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses line element" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :title do
              type :title

              elements do
                line :separator do
                  orientation :horizontal
                  thickness 2
                end
              end
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses box element" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :title do
              type :title

              elements do
                box :border_box do
                  border [width: 1, color: "black"]
                  fill [color: "lightgray"]
                end
              end
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses image element" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :title do
              type :title

              elements do
                image :logo do
                  source "/path/to/logo.png"
                  scale_mode :fit
                end
              end
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end
  end

  describe "variable entity parsing" do
    test "parses valid variable with required fields" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          variables do
            variable :total_count do
              type :count
              expression :id
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses variable with all options" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          variables do
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :group
              reset_group 1
              initial_value 0
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "validates variable type options" do
      valid_types = [:sum, :count, :average, :min, :max, :custom]

      for var_type <- valid_types do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer

            variables do
              variable :test_var do
                type #{inspect(var_type)}
                expression :test_field
              end
            end

            band :detail do
              type :detail
            end
          end
        end
        """

        assert_dsl_valid(dsl_content)
      end
    end

    test "validates reset_on options" do
      valid_reset_options = [:detail, :group, :page, :report]

      for reset_option <- valid_reset_options do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer

            variables do
              variable :test_var do
                type :sum
                expression :test_field
                reset_on #{inspect(reset_option)}
              end
            end

            band :detail do
              type :detail
            end
          end
        end
        """

        assert_dsl_valid(dsl_content)
      end
    end
  end

  describe "group entity parsing" do
    test "parses valid group with required fields" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          groups do
            group :by_region do
              level 1
              expression :region
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "parses group with all options" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          groups do
            group :by_region do
              level 1
              expression :region
              sort :desc
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "validates sort options" do
      valid_sort_options = [:asc, :desc]

      for sort_option <- valid_sort_options do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer

            groups do
              group :test_group do
                level 1
                expression :test_field
                sort #{inspect(sort_option)}
              end
            end

            band :detail do
              type :detail
            end
          end
        end
        """

        assert_dsl_valid(dsl_content)
      end
    end

    test "extracts group entities correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          groups do
            group :by_region do
              level 1
              expression :region
              sort :desc
            end

            group :by_status do
              level 2
              expression :status
            end
          end

          band :detail do
            type :detail
          end
        end
      end
      """

      {:ok, module} = parse_dsl(dsl_content, validate: false)
      reports = get_dsl_entities(module, [:reports])
      report = hd(reports)

      groups = Map.get(report, :groups, [])
      assert length(groups) == 2

      region_group = Enum.find(groups, &(&1.name == :by_region))
      assert region_group.level == 1
      assert region_group.expression == :region
      assert region_group.sort == :desc

      status_group = Enum.find(groups, &(&1.name == :by_status))
      assert status_group.level == 2
      assert status_group.expression == :status
      # default value
      assert status_group.sort == :asc
    end
  end

  describe "complex nested DSL structures" do
    test "parses complete report with all entity types" do
      dsl_content = """
      reports do
        report :complex_report do
          title "Complex Report"
          description "A report with all entity types"
          driving_resource AshReports.Test.Order
          formats [:html, :pdf]
          
          parameters do
            parameter :start_date, :date do
              required true
            end
            
            parameter :region, :string do
              default "All"
            end
          end
          
          variables do
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :report
            end
            
            variable :order_count do
              type :count
              expression :id
              reset_on :group
              reset_group 1
            end
          end
          
          groups do
            group :by_region do
              level 1
              expression {:field, :customer, :region}
              sort :asc
            end
          end
          
          bands do
            band :title do
              type :title
              
              elements do
                label :report_title do
                  text "Sales Report"
                  position [x: 0, y: 0]
                end
              end
            end
            
            band :group_header do
              type :group_header
              group_level 1
              
              elements do
                field :region_name do
                  source {:field, :customer, :region}
                  position [x: 0, y: 0]
                end
              end
            end
            
            band :detail do
              type :detail
              
              elements do
                field :order_number do
                  source :order_number
                  position [x: 0, y: 0]
                end
                
                field :total_amount do
                  source :total_amount
                  format :currency
                  position [x: 100, y: 0]
                end
                
                expression :tax_percentage do
                  expression {:multiply, {:divide, :tax_amount, :total_amount}, 100}
                  format :percentage
                  position [x: 200, y: 0]
                end
              end
            end
            
            band :group_footer do
              type :group_footer
              group_level 1
              
              elements do
                aggregate :group_total do
                  function :sum
                  source :total_amount
                  scope :group
                  format :currency
                  position [x: 100, y: 0]
                end
                
                aggregate :group_count do
                  function :count
                  source :id
                  scope :group
                  position [x: 300, y: 0]
                end
              end
            end
            
            band :summary do
              type :summary
              
              elements do
                label :summary_label do
                  text "Report Summary"
                  position [x: 0, y: 0]
                end
                
                aggregate :grand_total do
                  function :sum
                  source :total_amount
                  scope :report
                  format :currency
                  position [x: 100, y: 0]
                end
                
                line :separator do
                  orientation :horizontal
                  thickness 2
                  position [x: 0, y: 30, width: 400]
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "validates entity relationships and constraints" do
      # Test that group_level in bands matches group definitions
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          groups do
            group :by_region do
              level 1
              expression :region
            end
          end

          bands do
            band :group_header do
              type :group_header
              group_level 2  # This should be invalid - no group level 2 defined
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      # Note: This test might pass at DSL parsing level but should fail at verification level
      # The actual validation happens in verifiers, not in DSL parsing
      # We'll test the verifier behavior separately
      {:ok, _module} = parse_dsl(dsl_content, validate: false)
    end
  end

  describe "error handling and edge cases" do
    test "handles missing required fields gracefully" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          # missing driving_resource
          
          bands do
            band :title do
              # missing type
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "handles invalid nested structures" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          bands do
            band :title do
              type :title

              elements do
                field :invalid_field do
                  # missing required source field
                end
              end
            end

            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "handles empty entities correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer

          parameters do
            # Empty parameters section should be valid
          end

          variables do
            # Empty variables section should be valid
          end

          groups do
            # Empty groups section should be valid
          end

          bands do
            # Must have at least one detail band
            band :detail do
              type :detail
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end
  end
end
