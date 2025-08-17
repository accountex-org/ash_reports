defmodule AshReports.SchemaValidationTest do
  @moduledoc """
  Comprehensive schema validation tests for all AshReports entity types.
  
  Tests schema validation, type constraints, required field enforcement,
  and default value handling across all DSL entities.
  """
  
  use ExUnit.Case, async: true
  
  import AshReports.TestHelpers
  
  describe "Report schema validation" do
    test "validates required fields" do
      # Missing name (argument)
      dsl_content = """
      reports do
        report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """
      
      assert_dsl_error(dsl_content, "missing required argument")
      
      # Missing driving_resource
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "validates field types" do
      # Invalid name type (should be atom)
      dsl_content = """
      reports do
        report "string_name" do
          title "Test Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
      
      # Invalid title type (should be string)
      dsl_content = """
      reports do
        report :test_report do
          title 123
          driving_resource AshReports.Test.Customer
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
      
      # Invalid description type (should be string)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          description [:not, :a, :string]
          driving_resource AshReports.Test.Customer
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
    end
    
    test "validates format constraints" do
      # Valid formats
      valid_format_lists = [
        [:html],
        [:pdf],
        [:heex],
        [:json],
        [:html, :pdf],
        [:html, :pdf, :heex, :json]
      ]
      
      for formats <- valid_format_lists do
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
      
      # Invalid formats
      invalid_format_lists = [
        [:invalid_format],
        [:html, :invalid],
        [:word, :excel],
        "html",  # String instead of list
        :html    # Atom instead of list
      ]
      
      for formats <- invalid_format_lists do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            formats #{inspect(formats)}
          end
        end
        """
        
        assert_dsl_error(dsl_content, ["expected", "invalid"])
      end
    end
    
    test "validates permissions constraints" do
      # Valid permissions (list of atoms)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          permissions [:read_reports, :admin, :manager]
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
      
      # Invalid permissions (not a list)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          permissions :read_reports
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
    end
    
    test "applies default values" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """
      
      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)
      
      assert report.formats == [:html]
      assert report.permissions == []
    end
  end
  
  describe "Parameter schema validation" do
    test "validates required fields" do
      # Missing name (argument)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter do
              required true
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "missing required argument")
      
      # Missing type (argument)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter :start_date do
              required true
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "missing required argument")
    end
    
    test "validates field types" do
      # Invalid name type (should be atom)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter "string_name", :string do
              required true
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
      
      # Invalid required type (should be boolean)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter :test_param, :string do
              required "yes"
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
    end
    
    test "validates constraints field" do
      # Valid constraints (keyword list)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter :region, :string do
              constraints [max_length: 50, min_length: 2]
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
      
      # Invalid constraints (not keyword list)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter :region, :string do
              constraints "invalid"
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "expected")
    end
    
    test "applies default values" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          parameters do
            parameter :test_param, :string
          end
        end
      end
      """
      
      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)
      parameters = Map.get(report, :parameters, [])
      parameter = hd(parameters)
      
      assert parameter.required == false
      assert parameter.constraints == []
    end
  end
  
  describe "Band schema validation" do
    test "validates required fields" do
      # Missing name (argument)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band do
              type :detail
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "missing required argument")
      
      # Missing type
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :test_band do
              height 100
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "validates type constraints" do
      # Valid band types
      valid_types = [
        :title, :page_header, :column_header, :group_header,
        :detail_header, :detail, :detail_footer, :group_footer,
        :column_footer, :page_footer, :summary
      ]
      
      for band_type <- valid_types do
        dsl_content = """
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
        
        assert_dsl_valid(dsl_content)
      end
      
      # Invalid band types
      invalid_types = [:invalid_type, :header, :footer, :content, :section]
      
      for invalid_type <- invalid_types do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :test_band do
                type #{inspect(invalid_type)}
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "#{invalid_type}")
      end
    end
    
    test "validates positive integer constraints" do
      positive_integer_fields = [:group_level, :detail_number, :height]
      
      for field <- positive_integer_fields do
        # Valid positive integers
        for value <- [1, 2, 10, 100] do
          dsl_content = """
          reports do
            report :test_report do
              title "Test Report"
              driving_resource AshReports.Test.Customer
              
              bands do
                band :test_band do
                  type :detail
                  #{field} #{value}
                end
              end
            end
          end
          """
          
          assert_dsl_valid(dsl_content)
        end
        
        # Invalid values (0 or negative)
        for value <- [0, -1, -5] do
          dsl_content = """
          reports do
            report :test_report do
              title "Test Report"
              driving_resource AshReports.Test.Customer
              
              bands do
                band :test_band do
                  type :detail
                  #{field} #{value}
                end
              end
            end
          end
          """
          
          assert_dsl_error(dsl_content, "positive")
        end
      end
    end
    
    test "validates boolean constraints" do
      boolean_fields = [:can_grow, :can_shrink, :keep_together]
      
      for field <- boolean_fields do
        # Valid boolean values
        for value <- [true, false] do
          dsl_content = """
          reports do
            report :test_report do
              title "Test Report"
              driving_resource AshReports.Test.Customer
              
              bands do
                band :test_band do
                  type :detail
                  #{field} #{value}
                end
              end
            end
          end
          """
          
          assert_dsl_valid(dsl_content)
        end
        
        # Invalid values (non-boolean)
        for value <- ["true", :yes, 1, 0] do
          dsl_content = """
          reports do
            report :test_report do
              title "Test Report"
              driving_resource AshReports.Test.Customer
              
              bands do
                band :test_band do
                  type :detail
                  #{field} #{inspect(value)}
                end
              end
            end
          end
          """
          
          assert_dsl_error(dsl_content, "expected")
        end
      end
    end
    
    test "applies default values" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :test_band do
              type :detail
            end
          end
        end
      end
      """
      
      {:ok, dsl_state} = parse_dsl(dsl_content)
      reports = get_dsl_entities(dsl_state, [:reports])
      report = hd(reports)
      bands = Map.get(report, :bands, [])
      band = hd(bands)
      
      assert band.can_grow == true
      assert band.can_shrink == false
      assert band.visible == true
    end
  end
  
  describe "Variable schema validation" do
    test "validates required fields" do
      # Missing name (argument)
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
      
      # Missing type
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :test_var do
              expression :total_amount
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
      
      # Missing expression
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          variables do
            variable :test_var do
              type :sum
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "validates type constraints" do
      # Valid variable types
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
      
      # Invalid variable types
      invalid_types = [:invalid_type, :total, :accumulate, :aggregate]
      
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
    
    test "validates reset_on constraints" do
      # Valid reset_on options
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
      
      # Invalid reset_on options
      invalid_reset_options = [:invalid_reset, :band, :section, :element]
      
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
    
    test "validates reset_group positive integer constraint" do
      # Valid positive integers
      for value <- [1, 2, 5, 10] do
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
                reset_group #{value}
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Invalid values (0 or negative)
      for value <- [0, -1, -5] do
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
                reset_group #{value}
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "positive")
      end
    end
    
    test "applies default values" do
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
      
      assert variable.reset_on == :report
    end
  end
  
  describe "Group schema validation" do
    test "validates required fields" do
      # Missing name (argument)
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
      
      # Missing level
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :test_group do
              expression :region
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
      
      # Missing expression
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          groups do
            group :test_group do
              level 1
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "validates level positive integer constraint" do
      # Valid positive integers
      for value <- [1, 2, 5, 10] do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level #{value}
                expression :region
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Invalid values (0 or negative)
      for value <- [0, -1, -5] do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            groups do
              group :test_group do
                level #{value}
                expression :region
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "positive")
      end
    end
    
    test "validates sort constraints" do
      # Valid sort options
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
      
      # Invalid sort options
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
    
    test "applies default values" do
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
      
      assert group.sort == :asc
    end
  end
  
  describe "Element schema validation" do
    test "validates base element schema" do
      # Position field validation (keyword list)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :test_field do
                  source :name
                  position [x: 10, y: 20, width: 100, height: 30]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
      
      # Style field validation (keyword list)
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :test_field do
                  source :name
                  style [font: "Arial", size: 12, color: "black"]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "validates element-specific required fields" do
      # Label requires text
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                label :test_label do
                  position [x: 0, y: 0]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
      
      # Field requires source
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :test_field do
                  format :string
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
      
      # Expression requires expression
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                expression :test_expr do
                  format :string
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
      
      # Aggregate requires function and source
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :summary do
              type :summary
              
              elements do
                aggregate :test_agg do
                  scope :report
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
      
      # Image requires source
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                image :test_image do
                  scale_mode :fit
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content, "required")
    end
    
    test "validates element enum constraints" do
      # Aggregate function validation
      valid_functions = [:sum, :count, :average, :min, :max]
      
      for function <- valid_functions do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :summary do
                type :summary
                
                elements do
                  aggregate :test_agg do
                    function #{inspect(function)}
                    source :total_amount
                  end
                end
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Aggregate scope validation
      valid_scopes = [:band, :group, :page, :report]
      
      for scope <- valid_scopes do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :summary do
                type :summary
                
                elements do
                  aggregate :test_agg do
                    function :sum
                    source :total_amount
                    scope #{inspect(scope)}
                  end
                end
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Line orientation validation
      valid_orientations = [:horizontal, :vertical]
      
      for orientation <- valid_orientations do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :title do
                type :title
                
                elements do
                  line :test_line do
                    orientation #{inspect(orientation)}
                  end
                end
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Image scale_mode validation
      valid_scale_modes = [:fit, :fill, :stretch, :none]
      
      for scale_mode <- valid_scale_modes do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :title do
                type :title
                
                elements do
                  image :test_image do
                    source "/test.png"
                    scale_mode #{inspect(scale_mode)}
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
    
    test "validates element positive integer constraints" do
      # Line thickness validation
      for value <- [1, 2, 5, 10] do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :title do
                type :title
                
                elements do
                  line :test_line do
                    orientation :horizontal
                    thickness #{value}
                  end
                end
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
      
      # Invalid thickness (0 or negative)
      for value <- [0, -1] do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :title do
                type :title
                
                elements do
                  line :test_line do
                    orientation :horizontal
                    thickness #{value}
                  end
                end
              end
            end
          end
        end
        """
        
        assert_dsl_error(dsl_content, "positive")
      end
    end
    
    test "applies element default values" do
      # Line thickness default
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                line :test_line do
                  orientation :horizontal
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
      band = hd(bands)
      elements = Map.get(band, :elements, [])
      element = hd(elements)
      
      assert element.thickness == 1
      
      # Aggregate scope default
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :summary do
              type :summary
              
              elements do
                aggregate :test_agg do
                  function :sum
                  source :total_amount
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
      band = hd(bands)
      elements = Map.get(band, :elements, [])
      element = hd(elements)
      
      assert element.scope == :band
      
      # Image scale_mode default
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                image :test_image do
                  source "/test.png"
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
      band = hd(bands)
      elements = Map.get(band, :elements, [])
      element = hd(elements)
      
      assert element.scale_mode == :fit
    end
  end
end