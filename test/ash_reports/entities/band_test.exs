defmodule AshReports.Entities.BandTest do
  @moduledoc """
  Tests for AshReports.Band entity structure and validation.
  """
  
  use ExUnit.Case, async: true
  
  import AshReports.TestHelpers
  alias AshReports.Band
  
  describe "Band struct creation" do
    test "creates band with required fields" do
      band = %Band{
        name: :test_band,
        type: :detail
      }
      
      assert band.name == :test_band
      assert band.type == :detail
    end
    
    test "creates band with all optional fields" do
      band = %Band{
        name: :test_band,
        type: :group_header,
        group_level: 1,
        detail_number: 1,
        target_alias: {:field, :customer},
        on_entry: {:set_variable, :current_group},
        on_exit: {:reset_variable, :current_group},
        height: 100,
        can_grow: true,
        can_shrink: false,
        keep_together: true,
        visible: {:expression, :show_band},
        elements: [],
        bands: []
      }
      
      assert band.name == :test_band
      assert band.type == :group_header
      assert band.group_level == 1
      assert band.detail_number == 1
      assert band.target_alias == {:field, :customer}
      assert band.on_entry == {:set_variable, :current_group}
      assert band.on_exit == {:reset_variable, :current_group}
      assert band.height == 100
      assert band.can_grow == true
      assert band.can_shrink == false
      assert band.keep_together == true
      assert band.visible == {:expression, :show_band}
      assert band.elements == []
      assert band.bands == []
    end
  end
  
  describe "Band type validation" do
    test "validates all supported band types" do
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
    end
    
    test "rejects invalid band types" do
      invalid_types = [:invalid_type, :header, :footer, :content]
      
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
    
    test "requires type field" do
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
  end
  
  describe "Band field validation" do
    test "validates group_level is positive integer" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :test_band do
              type :group_header
              group_level 1
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
      
      # Test invalid group_level (0 or negative)
      dsl_content_invalid = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :test_band do
              type :group_header
              group_level 0
            end
          end
        end
      end
      """
      
      assert_dsl_error(dsl_content_invalid, "positive")
    end
    
    test "validates detail_number is positive integer" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :test_band do
              type :detail
              detail_number 2
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "validates height is positive integer" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :test_band do
              type :detail
              height 150
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "validates boolean fields" do
      boolean_fields = [:can_grow, :can_shrink, :keep_together]
      
      for field <- boolean_fields do
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
      end
    end
    
    test "sets default values correctly" do
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
  
  describe "Band element relationships" do
    test "can contain label elements" do
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
                
                label :subtitle_label do
                  text "Generated on: #{Date.utc_today()}"
                  position [x: 0, y: 20]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "can contain field elements" do
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
      
      assert_dsl_valid(dsl_content)
    end
    
    test "can contain expression elements" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                expression :full_name do
                  expression {:concat, :first_name, " ", :last_name}
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
    
    test "can contain aggregate elements" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :summary do
              type :summary
              
              elements do
                aggregate :total_customers do
                  function :count
                  source :id
                  scope :report
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
    
    test "can contain line elements" do
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
    
    test "can contain box elements" do
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
                  position [x: 0, y: 0, width: 100, height: 50]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "can contain image elements" do
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
                  position [x: 0, y: 0, width: 100, height: 50]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "can contain mixed element types" do
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
                  position [x: 0, y: 0]
                end
                
                label :separator_label do
                  text " - "
                  position [x: 100, y: 0]
                end
                
                field :email_field do
                  source :email
                  position [x: 120, y: 0]
                end
                
                line :bottom_line do
                  orientation :horizontal
                  position [x: 0, y: 20, width: 300]
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
  
  describe "Band recursive nesting" do
    test "supports nested bands (recursive_as: :bands)" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :group_header do
              type :group_header
              group_level 1
              
              bands do
                band :nested_header do
                  type :group_header
                  group_level 2
                  
                  elements do
                    label :nested_label do
                      text "Nested Band"
                    end
                  end
                end
              end
              
              elements do
                label :main_label do
                  text "Main Band"
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "supports multiple levels of band nesting" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :level1 do
              type :group_header
              group_level 1
              
              bands do
                band :level2 do
                  type :group_header
                  group_level 2
                  
                  bands do
                    band :level3 do
                      type :group_header
                      group_level 3
                      
                      elements do
                        label :level3_label do
                          text "Level 3"
                        end
                      end
                    end
                  end
                  
                  elements do
                    label :level2_label do
                      text "Level 2"
                    end
                  end
                end
              end
              
              elements do
                label :level1_label do
                  text "Level 1"
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "validates nested band structure" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :outer_band do
              type :group_header
              group_level 1
              
              bands do
                band :inner_band do
                  type :detail
                  
                  elements do
                    field :name_field do
                      source :name
                    end
                  end
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
      outer_band = hd(bands)
      
      nested_bands = Map.get(outer_band, :bands, [])
      assert length(nested_bands) == 1
      
      inner_band = hd(nested_bands)
      assert inner_band.name == :inner_band
      assert inner_band.type == :detail
      
      inner_elements = Map.get(inner_band, :elements, [])
      assert length(inner_elements) == 1
    end
  end
  
  describe "Band type-specific features" do
    test "group bands can specify group_level" do
      group_band_types = [:group_header, :group_footer]
      
      for band_type <- group_band_types do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :test_band do
                type #{inspect(band_type)}
                group_level 2
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "detail bands can specify detail_number" do
      detail_band_types = [:detail_header, :detail, :detail_footer]
      
      for band_type <- detail_band_types do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :test_band do
                type #{inspect(band_type)}
                detail_number 2
              end
            end
          end
        end
        """
        
        assert_dsl_valid(dsl_content)
      end
    end
    
    test "bands can have conditional visibility" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :conditional_band do
              type :detail
              visible {:expression, {:greater_than, :total_amount, 100}}
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "bands can have entry and exit expressions" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :tracked_band do
              type :group_header
              on_entry {:set_variable, :group_start_time, {:now}}
              on_exit {:calculate_variable, :group_duration}
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
  end
  
  describe "Band complex scenarios" do
    test "handles empty band (no elements)" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :empty_band do
              type :detail
              height 20
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "validates band order requirements" do
      # This test checks the logical band ordering that should be enforced
      # by verifiers. DSL parsing should allow any order, but verifiers
      # should enforce proper band type sequencing.
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail_band do
              type :detail
            end
            
            band :title_band do
              type :title
            end
            
            band :summary_band do
              type :summary
            end
            
            band :header_band do
              type :page_header
            end
          end
        end
      end
      """
      
      # This should parse successfully (DSL level)
      # but may fail at verifier level for improper ordering
      {:ok, _dsl_state} = parse_dsl(dsl_content)
    end
  end
end