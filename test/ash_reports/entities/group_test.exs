defmodule AshReports.Entities.GroupTest do
  @moduledoc """
  Tests for AshReports.Group entity structure and validation.
  """
  
  use ExUnit.Case, async: true
  
  import AshReports.TestHelpers
  alias AshReports.Group
  
  describe "Group struct creation" do
    test "creates group with required fields" do
      group = %Group{
        name: :by_region,
        level: 1,
        expression: :region
      }
      
      assert group.name == :by_region
      assert group.level == 1
      assert group.expression == :region
    end
    
    test "creates group with all optional fields" do
      group = %Group{
        name: :by_customer,
        level: 2,
        expression: {:field, :customer, :name},
        sort: :desc
      }
      
      assert group.name == :by_customer
      assert group.level == 2
      assert group.expression == {:field, :customer, :name}
      assert group.sort == :desc
    end
  end
  
  describe "Group field validation" do
    test "requires name field" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group do
              level 1
              expression :region
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "missing required argument")
    end
    
    test "requires level field" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_region do
              expression :region
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "requires expression field" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_region do
              level 1
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "validates level is positive integer" do
      # Valid levels
      valid_levels = [1, 2, 3, 5, 10]
      
      for level <- valid_levels do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level #{level}
                expression :region
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Invalid levels (0 or negative)
      invalid_levels = [0, -1, -5]
      
      for level <- invalid_levels do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level #{level}
                expression :region
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "positive")
      end
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
                expression :region
                sort #{inspect(sort_option)}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "rejects invalid sort options" do
      invalid_sort_options = [:invalid_sort, :ascending, :descending, :up, :down]
      
      for invalid_option <- invalid_sort_options do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level 1
                expression :region
                sort #{inspect(invalid_option)}
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "#{invalid_option}")
      end
    end
    
    test "sets default sort value" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :test_group do
              level 1
              expression :region
            end
          end
        end
      end
      """
      
      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)
      groups = Map.get(report, :groups, [])
      group = hd(groups)
      
      assert group.sort == :asc  # default value
    end
  end
  
  describe "Group expression types" do
    test "simple field expressions" do
      simple_expressions = [
        ":region",
        ":status",
        ":category",
        ":customer_id"
      ]
      
      for expr <- simple_expressions do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level 1
                expression #{expr}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "nested field expressions" do
      nested_expressions = [
        "{:field, :customer, :region}",
        "{:field, :order, :customer, :name}",
        "{:nested_field, :order, :customer, :company, :name}"
      ]
      
      for expr <- nested_expressions do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level 1
                expression #{expr}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "calculated expressions" do
      calculated_expressions = [
        "{:date_part, :year, :order_date}",
        "{:date_part, :month, :order_date}",
        "{:substring, :name, 1, 1}",
        "{:upper, :region}",
        "{:if, {:greater_than, :total_amount, 1000}, \"Large\", \"Small\"}"
      ]
      
      for expr <- calculated_expressions do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level 1
                expression #{expr}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "date and time grouping expressions" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_year do
              level 1
              expression {:date_part, :year, :order_date}
              sort :desc
            end
            
            group :by_month do
              level 2
              expression {:date_part, :month, :order_date}
              sort :asc
            end
            
            group :by_quarter do
              level 1
              expression {:date_part, :quarter, :order_date}
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Group level hierarchy" do
    test "single level grouping" do
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
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "multi-level grouping hierarchy" do
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
            
            group :by_customer do
              level 2
              expression {:field, :customer, :name}
              sort :asc
            end
            
            group :by_status do
              level 3
              expression :status
              sort :desc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "non-sequential group levels" do
      # Group levels don't need to be sequential (1, 2, 3...)
      # They can be 1, 3, 5, etc. - the verifier should handle validation
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
            
            group :by_quarter do
              level 5
              expression {:date_part, :quarter, :order_date}
            end
            
            group :by_customer do
              level 10
              expression {:field, :customer, :name}
            end
          end
        end
      end
      """
      
      # This should pass DSL parsing but may fail at verifier level
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Group sorting and ordering" do
    test "ascending sort groups" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_name do
              level 1
              expression {:field, :customer, :name}
              sort :asc
            end
            
            group :by_amount do
              level 2
              expression :total_amount
              sort :asc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "descending sort groups" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_sales do
              level 1
              expression {:sum, :total_amount}
              sort :desc
            end
            
            group :by_date do
              level 2
              expression :order_date
              sort :desc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "mixed sort directions" do
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
            
            group :by_total_sales do
              level 2
              expression {:sum, :total_amount}
              sort :desc
            end
            
            group :by_customer_name do
              level 3
              expression {:field, :customer, :name}
              sort :asc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Group usage scenarios" do
    test "geographic grouping" do
      dsl_content = """
      reports do
        report :sales_by_geography do
          title "Sales by Geography"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_country do
              level 1
              expression {:field, :address, :country}
              sort :asc
            end
            
            group :by_state do
              level 2
              expression {:field, :address, :state}
              sort :asc
            end
            
            group :by_city do
              level 3
              expression {:field, :address, :city}
              sort :asc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "temporal grouping" do
      dsl_content = """
      reports do
        report :sales_by_time do
          title "Sales by Time Period"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_year do
              level 1
              expression {:date_part, :year, :order_date}
              sort :desc
            end
            
            group :by_quarter do
              level 2
              expression {:date_part, :quarter, :order_date}
              sort :asc
            end
            
            group :by_month do
              level 3
              expression {:date_part, :month, :order_date}
              sort :asc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "categorical grouping" do
      dsl_content = """
      reports do
        report :sales_by_category do
          title "Sales by Product Category"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_category do
              level 1
              expression {:field, :product, :category}
              sort :asc
            end
            
            group :by_subcategory do
              level 2
              expression {:field, :product, :subcategory}
              sort :asc
            end
            
            group :by_brand do
              level 3
              expression {:field, :product, :brand}
              sort :asc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "customer hierarchy grouping" do
      dsl_content = """
      reports do
        report :sales_by_customer do
          title "Sales by Customer Hierarchy"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :by_sales_rep do
              level 1
              expression {:field, :customer, :sales_rep_id}
              sort :asc
            end
            
            group :by_customer_type do
              level 2
              expression {:field, :customer, :customer_type}
              sort :asc
            end
            
            group :by_customer do
              level 3
              expression {:field, :customer, :name}
              sort :asc
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Group validation edge cases" do
    test "validates group names are unique within report" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :duplicate_name do
              level 1
              expression :region
            end
            
            group :duplicate_name do
              level 2
              expression :status
            end
          end
        end
      end
      """
      
      # This should pass DSL parsing but fail at verifier level
      {:ok, _dsl_state} = parse_dsl(dsl_content)
    end
    
    test "validates group levels are logical" do
      # The verifier should check that group levels make sense
      # This test documents the expected behavior at DSL level
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :level5_first do
              level 5
              expression :region
            end
            
            group :level1_second do
              level 1
              expression :status
            end
          end
        end
      end
      """
      
      # This should pass DSL parsing (order doesn't matter at DSL level)
      assert_dsl_valid(dsl_content)
    end
    
    test "handles empty groups section" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            # Empty groups section should be valid
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
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
              sort :asc
            end
            
            group :by_customer do
              level 2
              expression {:field, :customer, :name}
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
      assert region_group.expression == :region
      assert region_group.sort == :asc
      
      customer_group = Enum.find(groups, &(&1.name == :by_customer))
      assert customer_group.level == 2
      assert customer_group.expression == {:field, :customer, :name}
      assert customer_group.sort == :desc
    end
  end
  
  describe "Group integration with bands" do
    test "groups work with group header and footer bands" do
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
            
            group :by_customer do
              level 2
              expression {:field, :customer, :name}
            end
          end
          
          bands do
            band :group1_header do
              type :group_header
              group_level 1
              
              elements do
                field :region_name do
                  source :region
                end
              end
            end
            
            band :group2_header do
              type :group_header
              group_level 2
              
              elements do
                field :customer_name do
                  source {:field, :customer, :name}
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
            
            band :group2_footer do
              type :group_footer
              group_level 2
              
              elements do
                aggregate :customer_total do
                  function :sum
                  source :total_amount
                  scope :group
                end
              end
            end
            
            band :group1_footer do
              type :group_footer
              group_level 1
              
              elements do
                aggregate :region_total do
                  function :sum
                  source :total_amount
                  scope :group
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
end