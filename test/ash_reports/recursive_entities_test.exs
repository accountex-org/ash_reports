defmodule AshReports.RecursiveEntitiesTest do
  @moduledoc """
  Tests for recursive entity structures in AshReports DSL.
  
  Tests band nesting (recursive_as: :bands) and complex element hierarchies
  within bands and nested bands.
  """
  
  use ExUnit.Case, async: true
  
  import AshReports.TestHelpers
  
  describe "Band recursive nesting (recursive_as: :bands)" do
    test "supports simple band nesting" do
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
              
              elements do
                label :group_label do
                  text "Group Header"
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
                      type :detail
                      
                      elements do
                        field :deepest_field do
                          source :name
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
    
    test "supports multiple nested bands at the same level" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :parent_band do
              type :group_header
              group_level 1
              
              bands do
                band :child1 do
                  type :detail
                  detail_number 1
                  
                  elements do
                    field :field1 do
                      source :name
                    end
                  end
                end
                
                band :child2 do
                  type :detail
                  detail_number 2
                  
                  elements do
                    field :field2 do
                      source :email
                    end
                  end
                end
                
                band :child3 do
                  type :detail_footer
                  
                  elements do
                    aggregate :total do
                      function :count
                      source :id
                    end
                  end
                end
              end
              
              elements do
                label :parent_label do
                  text "Parent Band"
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "validates nested band structure and extracts correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :outer do
              type :group_header
              group_level 1
              
              bands do
                band :middle do
                  type :group_header
                  group_level 2
                  
                  bands do
                    band :inner do
                      type :detail
                      
                      elements do
                        field :inner_field do
                          source :name
                        end
                      end
                    end
                  end
                  
                  elements do
                    field :middle_field do
                      source :region
                    end
                  end
                end
              end
              
              elements do
                label :outer_label do
                  text "Outer Band"
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
      assert length(bands) == 1
      
      outer_band = hd(bands)
      assert outer_band.name == :outer
      assert outer_band.type == :group_header
      assert outer_band.group_level == 1
      
      # Check outer band elements
      outer_elements = Map.get(outer_band, :elements, [])
      assert length(outer_elements) == 1
      outer_label = hd(outer_elements)
      assert outer_label.name == :outer_label
      
      # Check nested bands
      nested_bands = Map.get(outer_band, :bands, [])
      assert length(nested_bands) == 1
      
      middle_band = hd(nested_bands)
      assert middle_band.name == :middle
      assert middle_band.type == :group_header
      assert middle_band.group_level == 2
      
      # Check middle band elements
      middle_elements = Map.get(middle_band, :elements, [])
      assert length(middle_elements) == 1
      middle_field = hd(middle_elements)
      assert middle_field.name == :middle_field
      
      # Check deeply nested bands
      deep_nested_bands = Map.get(middle_band, :bands, [])
      assert length(deep_nested_bands) == 1
      
      inner_band = hd(deep_nested_bands)
      assert inner_band.name == :inner
      assert inner_band.type == :detail
      
      # Check inner band elements
      inner_elements = Map.get(inner_band, :elements, [])
      assert length(inner_elements) == 1
      inner_field = hd(inner_elements)
      assert inner_field.name == :inner_field
    end
  end
  
  describe "Complex band hierarchy patterns" do
    test "group header with nested detail bands" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :region_group do
              type :group_header
              group_level 1
              
              bands do
                band :customer_detail do
                  type :detail
                  
                  elements do
                    field :customer_name do
                      source :name
                    end
                    
                    field :customer_email do
                      source :email
                    end
                  end
                end
                
                band :order_detail do
                  type :detail
                  detail_number 2
                  
                  elements do
                    field :order_number do
                      source :order_number
                    end
                    
                    field :order_total do
                      source :total_amount
                      format :currency
                    end
                  end
                end
              end
              
              elements do
                field :region_name do
                  source :region
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "nested group headers with their own footers" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :level1_group do
              type :group_header
              group_level 1
              
              bands do
                band :level2_group do
                  type :group_header
                  group_level 2
                  
                  bands do
                    band :detail_data do
                      type :detail
                      
                      elements do
                        field :data_field do
                          source :name
                        end
                      end
                    end
                    
                    band :level2_footer do
                      type :group_footer
                      group_level 2
                      
                      elements do
                        aggregate :level2_total do
                          function :sum
                          source :total_amount
                          scope :group
                        end
                      end
                    end
                  end
                  
                  elements do
                    label :level2_header do
                      text "Level 2 Group"
                    end
                  end
                end
                
                band :level1_footer do
                  type :group_footer
                  group_level 1
                  
                  elements do
                    aggregate :level1_total do
                      function :sum
                      source :total_amount
                      scope :group
                    end
                  end
                end
              end
              
              elements do
                label :level1_header do
                  text "Level 1 Group"
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "band with conditional nested bands" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :conditional_parent do
              type :group_header
              group_level 1
              visible {:expression, {:not_null, :region}}
              
              bands do
                band :detail_when_active do
                  type :detail
                  visible {:expression, {:equal, :status, "active"}}
                  
                  elements do
                    field :active_customer do
                      source :name
                    end
                  end
                end
                
                band :detail_when_inactive do
                  type :detail
                  visible {:expression, {:equal, :status, "inactive"}}
                  
                  elements do
                    field :inactive_customer do
                      source :name
                      style [color: "gray"]
                    end
                  end
                end
              end
              
              elements do
                field :region_header do
                  source :region
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
  
  describe "Element hierarchy within bands" do
    test "band with complex element arrangements" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detailed_band do
              type :detail
              
              elements do
                # Header row
                label :header_label do
                  text "Customer Information"
                  position [x: 0, y: 0, width: 400, height: 20]
                  style [font: "Arial Bold", size: 14]
                end
                
                line :header_underline do
                  orientation :horizontal
                  position [x: 0, y: 22, width: 400, height: 2]
                  thickness 2
                end
                
                # Customer details
                label :name_label do
                  text "Name:"
                  position [x: 0, y: 30, width: 80, height: 15]
                end
                
                field :customer_name do
                  source :name
                  position [x: 85, y: 30, width: 200, height: 15]
                end
                
                label :email_label do
                  text "Email:"
                  position [x: 0, y: 50, width: 80, height: 15]
                end
                
                field :customer_email do
                  source :email
                  position [x: 85, y: 50, width: 200, height: 15]
                end
                
                # Status with conditional formatting
                label :status_label do
                  text "Status:"
                  position [x: 0, y: 70, width: 80, height: 15]
                end
                
                field :status_field do
                  source :status
                  position [x: 85, y: 70, width: 100, height: 15]
                  conditional {:expression, {:not_null, :status}}
                  style [
                    color: {:if, {:equal, :status, "active"}, "green", "red"}
                  ]
                end
                
                # Total with expression
                label :total_label do
                  text "Total Orders:"
                  position [x: 300, y: 30, width: 80, height: 15]
                end
                
                aggregate :order_total do
                  function :sum
                  source {:field, :orders, :total_amount}
                  scope :band
                  format :currency
                  position [x: 385, y: 30, width: 100, height: 15]
                end
                
                # Calculated field
                expression :order_average do
                  expression {
                    :divide,
                    {:aggregate, :sum, {:field, :orders, :total_amount}},
                    {:aggregate, :count, {:field, :orders, :id}}
                  }
                  format :currency
                  position [x: 385, y: 50, width: 100, height: 15]
                end
                
                # Bottom border
                line :bottom_border do
                  orientation :horizontal
                  position [x: 0, y: 90, width: 500, height: 1]
                  thickness 1
                  style [color: "lightgray"]
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "nested bands with different element types" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :main_section do
              type :group_header
              group_level 1
              
              bands do
                band :data_section do
                  type :detail
                  
                  elements do
                    field :basic_field do
                      source :name
                      position [x: 0, y: 0]
                    end
                    
                    expression :calculated_field do
                      expression {:upper, :name}
                      position [x: 100, y: 0]
                    end
                  end
                end
                
                band :visual_section do
                  type :detail_footer
                  
                  elements do
                    box :background_box do
                      fill [color: "lightblue"]
                      position [x: 0, y: 0, width: 500, height: 30]
                    end
                    
                    image :icon do
                      source "/icons/customer.png"
                      scale_mode :fit
                      position [x: 10, y: 5, width: 20, height: 20]
                    end
                    
                    label :summary_text do
                      text "Customer Summary"
                      position [x: 40, y: 8]
                      style [font: "Arial Bold"]
                    end
                    
                    line :separator do
                      orientation :vertical
                      position [x: 200, y: 5, height: 20]
                      thickness 2
                    end
                    
                    aggregate :customer_count do
                      function :count
                      source :id
                      scope :group
                      position [x: 220, y: 8]
                    end
                  end
                end
              end
              
              elements do
                label :section_title do
                  text "Customer Group"
                  style [font: "Arial Bold", size: 16]
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
  
  describe "Deep nesting validation" do
    test "supports very deep band nesting" do
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
                      
                      bands do
                        band :level4 do
                          type :detail
                          
                          bands do
                            band :level5 do
                              type :detail_footer
                              
                              elements do
                                label :deepest_label do
                                  text "Level 5"
                                end
                              end
                            end
                          end
                          
                          elements do
                            label :level4_label do
                              text "Level 4"
                            end
                          end
                        end
                      end
                      
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
    
    test "validates complex mixed hierarchy" do
      dsl_content = """
      reports do
        report :complex_hierarchy do
          title "Complex Hierarchy Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title_section do
              type :title
              
              elements do
                label :main_title do
                  text "Complex Report"
                  style [font: "Arial Bold", size: 18]
                end
                
                line :title_underline do
                  orientation :horizontal
                  thickness 2
                end
              end
            end
            
            band :region_group do
              type :group_header
              group_level 1
              
              bands do
                band :customer_group do
                  type :group_header
                  group_level 2
                  
                  bands do
                    band :order_detail do
                      type :detail
                      
                      bands do
                        band :line_item_detail do
                          type :detail
                          detail_number 2
                          
                          elements do
                            field :product_name do
                              source {:field, :line_items, :product, :name}
                            end
                            
                            field :quantity do
                              source {:field, :line_items, :quantity}
                              format :number
                            end
                            
                            expression :line_total do
                              expression {
                                :multiply,
                                {:field, :line_items, :quantity},
                                {:field, :line_items, :unit_price}
                              }
                              format :currency
                            end
                          end
                        end
                      end
                      
                      elements do
                        field :order_number do
                          source :order_number
                        end
                        
                        field :order_date do
                          source :order_date
                          format :date
                        end
                      end
                    end
                    
                    band :customer_footer do
                      type :group_footer
                      group_level 2
                      
                      elements do
                        label :customer_total_label do
                          text "Customer Total:"
                        end
                        
                        aggregate :customer_total do
                          function :sum
                          source :total_amount
                          scope :group
                          format :currency
                        end
                      end
                    end
                  end
                  
                  elements do
                    field :customer_name do
                      source :name
                      style [font: "Arial Bold"]
                    end
                  end
                end
                
                band :region_footer do
                  type :group_footer
                  group_level 1
                  
                  elements do
                    box :footer_background do
                      fill [color: "lightgray"]
                      position [x: 0, y: 0, width: 500, height: 25]
                    end
                    
                    label :region_total_label do
                      text "Region Total:"
                      position [x: 10, y: 5]
                      style [font: "Arial Bold"]
                    end
                    
                    aggregate :region_total do
                      function :sum
                      source :total_amount
                      scope :group
                      format :currency
                      position [x: 400, y: 5]
                      style [font: "Arial Bold"]
                    end
                  end
                end
              end
              
              elements do
                field :region_name do
                  source :region
                  style [font: "Arial Bold", size: 14]
                end
                
                line :region_separator do
                  orientation :horizontal
                  thickness 1
                end
              end
            end
            
            band :grand_total do
              type :summary
              
              elements do
                box :summary_box do
                  border [width: 2, color: "black"]
                  fill [color: "yellow"]
                  position [x: 0, y: 0, width: 500, height: 40]
                end
                
                label :grand_total_label do
                  text "GRAND TOTAL:"
                  position [x: 10, y: 10]
                  style [font: "Arial Bold", size: 16]
                end
                
                aggregate :grand_total_amount do
                  function :sum
                  source :total_amount
                  scope :report
                  format :currency
                  position [x: 400, y: 10]
                  style [font: "Arial Bold", size: 16]
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
  
  describe "Recursive structure edge cases" do
    test "handles empty nested bands sections" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :parent_band do
              type :group_header
              group_level 1
              
              bands do
                # Empty nested bands section
              end
              
              elements do
                label :parent_label do
                  text "Parent"
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "handles band with only nested bands (no direct elements)" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :container_band do
              type :group_header
              group_level 1
              
              bands do
                band :content_band do
                  type :detail
                  
                  elements do
                    field :content_field do
                      source :name
                    end
                  end
                end
              end
              
              # No direct elements in container_band
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "handles band with both nested bands and elements" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :mixed_band do
              type :group_header
              group_level 1
              
              bands do
                band :nested_detail do
                  type :detail
                  
                  elements do
                    field :nested_field do
                      source :name
                    end
                  end
                end
              end
              
              elements do
                label :direct_label do
                  text "Direct Element"
                end
                
                field :direct_field do
                  source :region
                end
              end
            end
          end
        end
      end
      """
      
      assert_dsl_valid(dsl_content)
    end
    
    test "extracts complex recursive structure correctly" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :root do
              type :group_header
              group_level 1
              
              bands do
                band :child1 do
                  type :detail
                  
                  elements do
                    field :child1_field do
                      source :name
                    end
                  end
                end
                
                band :child2 do
                  type :detail_footer
                  
                  bands do
                    band :grandchild do
                      type :detail
                      detail_number 2
                      
                      elements do
                        field :grandchild_field do
                          source :email
                        end
                      end
                    end
                  end
                  
                  elements do
                    aggregate :child2_total do
                      function :count
                      source :id
                    end
                  end
                end
              end
              
              elements do
                label :root_label do
                  text "Root Band"
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
      assert length(bands) == 1
      
      root_band = hd(bands)
      assert root_band.name == :root
      
      # Check root band elements
      root_elements = Map.get(root_band, :elements, [])
      assert length(root_elements) == 1
      assert hd(root_elements).name == :root_label
      
      # Check root band children
      child_bands = Map.get(root_band, :bands, [])
      assert length(child_bands) == 2
      
      child1 = Enum.find(child_bands, &(&1.name == :child1))
      assert child1.type == :detail
      child1_elements = Map.get(child1, :elements, [])
      assert length(child1_elements) == 1
      assert hd(child1_elements).name == :child1_field
      
      child2 = Enum.find(child_bands, &(&1.name == :child2))
      assert child2.type == :detail_footer
      child2_elements = Map.get(child2, :elements, [])
      assert length(child2_elements) == 1
      assert hd(child2_elements).name == :child2_total
      
      # Check grandchild
      grandchild_bands = Map.get(child2, :bands, [])
      assert length(grandchild_bands) == 1
      
      grandchild = hd(grandchild_bands)
      assert grandchild.name == :grandchild
      assert grandchild.type == :detail
      assert grandchild.detail_number == 2
      
      grandchild_elements = Map.get(grandchild, :elements, [])
      assert length(grandchild_elements) == 1
      assert hd(grandchild_elements).name == :grandchild_field
    end
  end
end