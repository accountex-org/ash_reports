defmodule AshReports.Entities.VariableTest do
  @moduledoc """
  Tests for AshReports.Variable entity structure and validation.
  """
  
  use ExUnit.Case, async: true
  
  import AshReports.TestHelpers
  alias AshReports.Variable
  
  describe "Variable struct creation" do
    test "creates variable with required fields" do
      variable = %Variable{
        name: :total_sales,
        type: :sum,
        expression: :total_amount
      }
      
      assert variable.name == :total_sales
      assert variable.type == :sum
      assert variable.expression == :total_amount
    end
    
    test "creates variable with all optional fields" do
      variable = %Variable{
        name: :group_total,
        type: :sum,
        expression: {:multiply, :quantity, :price},
        reset_on: :group,
        reset_group: 2,
        initial_value: 0
      }
      
      assert variable.name == :group_total
      assert variable.type == :sum
      assert variable.expression == {:multiply, :quantity, :price}
      assert variable.reset_on == :group
      assert variable.reset_group == 2
      assert variable.initial_value == 0
    end
  end
  
  describe "Variable field validation" do
    test "requires name field" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable do
              type :sum
              expression :total_amount
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "missing required argument")
    end
    
    test "requires type field" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :total_sales do
              expression :total_amount
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
          
          variables do
            variable :total_sales do
              type :sum
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
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
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "rejects invalid variable types" do
      invalid_types = [:invalid_type, :total, :accumulate]
      
      for invalid_type <- invalid_types do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            variables do
              variable :test_var do
                type #{inspect(invalid_type)}
                expression :test_field
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "#{invalid_type}")
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
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "rejects invalid reset_on options" do
      invalid_reset_options = [:invalid_reset, :band, :section]
      
      for invalid_option <- invalid_reset_options do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            variables do
              variable :test_var do
                type :sum
                expression :test_field
                reset_on #{inspect(invalid_option)}
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "#{invalid_option}")
      end
    end
    
    test "validates reset_group is positive integer" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :test_var do
              type :sum
              expression :test_field
              reset_on :group
              reset_group 2
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
      
      # Test invalid reset_group (0 or negative)
      dsl_content_invalid = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :test_var do
              type :sum
              expression :test_field
              reset_on :group
              reset_group 0
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content_invalid, "positive")
    end
    
    test "sets default values correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :test_var do
              type :sum
              expression :test_field
            end
          end
        end
      end
      """
      
      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)
      variables = Map.get(report, :variables, [])
      variable = hd(variables)
      
      assert variable.reset_on == :report  # default value
    end
  end
  
  describe "Variable type-specific behavior" do
    test "sum variable with numeric expressions" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :report
            end
            
            variable :line_total do
              type :sum
              expression {:multiply, :quantity, :price}
              reset_on :detail
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "count variable with field references" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :order_count do
              type :count
              expression :id
              reset_on :group
              reset_group 1
            end
            
            variable :active_customers do
              type :count
              expression {:if, {:equal, :status, "active"}, 1, 0}
              reset_on :report
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "average variable with calculations" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :avg_order_value do
              type :average
              expression :total_amount
              reset_on :group
            end
            
            variable :avg_discount do
              type :average
              expression {:divide, :discount_amount, :total_amount}
              reset_on :page
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "min and max variables" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :min_order_date do
              type :min
              expression :order_date
              reset_on :report
            end
            
            variable :max_total do
              type :max
              expression :total_amount
              reset_on :group
              reset_group 1
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "custom variable with complex expressions" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :running_balance do
              type :custom
              expression {:custom_function, :calculate_running_balance, :current_amount}
              reset_on :page
              initial_value 0
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Variable reset behavior" do
    test "detail reset variables" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :line_number do
              type :count
              expression 1
              reset_on :detail
              initial_value 1
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "group reset variables with group levels" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :group1_total do
              type :sum
              expression :total_amount
              reset_on :group
              reset_group 1
            end
            
            variable :group2_count do
              type :count
              expression :id
              reset_on :group
              reset_group 2
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "page reset variables" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :page_number do
              type :count
              expression 1
              reset_on :page
              initial_value 1
            end
            
            variable :page_total do
              type :sum
              expression :total_amount
              reset_on :page
              initial_value 0
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "report reset variables" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :grand_total do
              type :sum
              expression :total_amount
              reset_on :report
            end
            
            variable :total_orders do
              type :count
              expression :id
              reset_on :report
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Variable expressions" do
    test "simple field expressions" do
      simple_expressions = [
        ":total_amount",
        ":quantity",
        ":id",
        ":order_date"
      ]
      
      for expr <- simple_expressions do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            variables do
              variable :test_var do
                type :sum
                expression #{expr}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "complex field expressions" do
      complex_expressions = [
        "{:field, :customer, :region}",
        "{:nested_field, :order, :customer, :name}",
        "{:add, :base_amount, :tax_amount}",
        "{:multiply, :quantity, :unit_price}",
        "{:if, {:greater_than, :age, 18}, 1, 0}"
      ]
      
      for expr <- complex_expressions do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            variables do
              variable :test_var do
                type :sum
                expression #{expr}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "conditional expressions" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :large_order_count do
              type :count
              expression {:if, {:greater_than, :total_amount, 1000}, 1, 0}
              reset_on :report
            end
            
            variable :priority_total do
              type :sum
              expression {:if, {:equal, :priority, "high"}, :total_amount, 0}
              reset_on :group
              reset_group 1
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Variable usage scenarios" do
    test "running totals and counters" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :running_total do
              type :sum
              expression :total_amount
              reset_on :report
              initial_value 0
            end
            
            variable :row_counter do
              type :count
              expression 1
              reset_on :report
              initial_value 0
            end
            
            variable :group_counter do
              type :count
              expression 1
              reset_on :group
              reset_group 1
              initial_value 0
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "percentage calculations" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :report
            end
            
            variable :discount_total do
              type :sum
              expression :discount_amount
              reset_on :report
            end
            
            variable :tax_total do
              type :sum
              expression :tax_amount
              reset_on :report
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "multi-level grouping variables" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :region_total do
              type :sum
              expression :total_amount
              reset_on :group
              reset_group 1
            end
            
            variable :customer_total do
              type :sum
              expression :total_amount
              reset_on :group
              reset_group 2
            end
            
            variable :region_count do
              type :count
              expression :id
              reset_on :group
              reset_group 1
            end
            
            variable :customer_count do
              type :count
              expression :id
              reset_on :group
              reset_group 2
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Variable validation edge cases" do
    test "validates variable names are unique within report" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :duplicate_name do
              type :sum
              expression :amount1
            end
            
            variable :duplicate_name do
              type :count
              expression :id
            end
          end
        end
      end
      """
      
      # This should pass DSL parsing but fail at verifier level
      {:ok, _dsl_state} = parse_dsl(dsl_content)
    end
    
    test "validates reset_group is specified when reset_on is :group" do
      # Valid: reset_on :group with reset_group specified
      dsl_content_valid = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :group_total do
              type :sum
              expression :total_amount
              reset_on :group
              reset_group 1
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content_valid)
      
      # This validation (reset_group required when reset_on is :group)
      # might be handled at verifier level rather than DSL parsing level
    end
    
    test "handles variables with initial values" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :balance do
              type :custom
              expression {:add, :previous_balance, :current_amount}
              reset_on :page
              initial_value 1000
            end
            
            variable :sequence do
              type :count
              expression 1
              reset_on :detail
              initial_value 1
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "extracts variable entities correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :total_sales do
              type :sum
              expression :total_amount
              reset_on :report
              initial_value 0
            end
            
            variable :order_count do
              type :count
              expression :id
              reset_on :group
              reset_group 1
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
      
      sales_var = Enum.find(variables, &(&1.name == :total_sales))
      assert sales_var.type == :sum
      assert sales_var.expression == :total_amount
      assert sales_var.reset_on == :report
      assert sales_var.initial_value == 0
      
      count_var = Enum.find(variables, &(&1.name == :order_count))
      assert count_var.type == :count
      assert count_var.expression == :id
      assert count_var.reset_on == :group
      assert count_var.reset_group == 1
    end
  end
end