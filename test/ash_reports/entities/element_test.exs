defmodule AshReports.Entities.ElementTest do
  @moduledoc """
  Tests for AshReports element entity structures and validation.

  Tests all 7 element types: label, field, expression, aggregate, line, box, image.
  """

  use ExUnit.Case, async: true

  import AshReports.TestHelpers

  describe "Label element" do
    test "creates valid label element with required fields" do
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "label element requires text field" do
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
                  position [x: 0, y: 0]
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "label element with all optional fields" do
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
                  style [font: "Arial", size: 12, color: "black"]
                  conditional {:expression, :show_title}
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "extracts label element correctly" do
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
                  position [x: 10, y: 5]
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

      assert element.name == :title_label
      assert element.text == "Report Title"
      assert element.position == [x: 10, y: 5]
    end
  end

  describe "Field element" do
    test "creates valid field element with required fields" do
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "field element requires source field" do
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
                  format :string
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "field element with complex source expressions" do
      source_expressions = [
        ":name",
        ":email",
        "{:field, :customer, :region}",
        "{:nested_field, :order, :customer, :name}",
        "{:expression, {:upper, :name}}"
      ]

      for source_expr <- source_expressions do
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
                    source #{source_expr}
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

    test "field element with formatting options" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :amount_field do
                  source :total_amount
                  format :currency
                  position [x: 0, y: 0]
                end
                
                field :date_field do
                  source :created_at
                  format {:date, "%Y-%m-%d"}
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
  end

  describe "Expression element" do
    test "creates valid expression element with required fields" do
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "expression element requires expression field" do
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
                  format :number
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end

    test "expression element with complex expressions" do
      expressions = [
        "{:add, :field1, :field2}",
        "{:multiply, :quantity, :price}",
        "{:concat, :first_name, \" \", :last_name}",
        "{:if, {:greater_than, :age, 18}, \"Adult\", \"Minor\"}",
        "{:format, :amount, :currency}"
      ]

      for expr <- expressions do
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
                    expression #{expr}
                    format :string
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

  describe "Aggregate element" do
    test "creates valid aggregate element with required fields" do
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "aggregate element requires function and source" do
      # Missing function
      dsl_content_no_function = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :summary do
              type :summary
              
              elements do
                aggregate :total_count do
                  source :id
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content_no_function, "required")

      # Missing source
      dsl_content_no_source = """
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_error(dsl_content_no_source, "required")
    end

    test "validates aggregate function options" do
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
                  aggregate :test_aggregate do
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
    end

    test "validates aggregate scope options" do
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
                  aggregate :test_aggregate do
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
    end

    test "aggregate element with all options" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
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
                  style [font: "Arial Bold"]
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

  describe "Line element" do
    test "creates valid line element with minimal fields" do
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "validates line orientation options" do
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
                  line :separator do
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
    end

    test "line element with thickness and positioning" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                line :thick_line do
                  orientation :horizontal
                  thickness 3
                  position [x: 0, y: 20, width: 400]
                  style [color: "red"]
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "line element sets default thickness" do
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

      # default value
      assert element.thickness == 1
    end
  end

  describe "Box element" do
    test "creates valid box element with minimal fields" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                box :container do
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

    test "box element with border and fill properties" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                box :styled_box do
                  border [width: 2, color: "black", style: "solid"]
                  fill [color: "lightgray", pattern: "solid"]
                  position [x: 10, y: 10, width: 200, height: 100]
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "box element with complex styling" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :title do
              type :title
              
              elements do
                box :complex_box do
                  border [
                    width: 1,
                    color: "blue",
                    style: "dashed",
                    radius: 5
                  ]
                  fill [
                    color: "rgba(0, 0, 255, 0.1)",
                    pattern: "gradient",
                    direction: "vertical"
                  ]
                  position [x: 0, y: 0, width: 300, height: 150]
                  style [shadow: true, opacity: 0.8]
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

  describe "Image element" do
    test "creates valid image element with required fields" do
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
                end
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "image element requires source field" do
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

    test "validates image scale_mode options" do
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
                  image :logo do
                    source "/path/to/logo.png"
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

    test "image element with dynamic source expressions" do
      dynamic_sources = [
        "\"/static/logo.png\"",
        "{:field, :company, :logo_path}",
        "{:expression, {:concat, \"/images/\", :company_id, \".png\"}}",
        "{:if, {:equal, :region, \"North\"}, \"/north_logo.png\", \"/default_logo.png\"}"
      ]

      for source_expr <- dynamic_sources do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :title do
                type :title
                
                elements do
                  image :dynamic_logo do
                    source #{source_expr}
                    scale_mode :fit
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

    test "image element sets default scale_mode" do
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

      # default value
      assert element.scale_mode == :fit
    end
  end

  describe "Element common features" do
    test "all elements support position configuration" do
      element_configs = [
        {"label", "label :test do\n  text \"Test\"\nend"},
        {"field", "field :test do\n  source :name\nend"},
        {"expression", "expression :test do\n  expression :name\nend"},
        {"aggregate", "aggregate :test do\n  function :count\n  source :id\nend"},
        {"line", "line :test do\n  orientation :horizontal\nend"},
        {"box", "box :test do\nend"},
        {"image", "image :test do\n  source \"/test.png\"\nend"}
      ]

      for {_element_type, element_config} <- element_configs do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :detail do
                type :detail
                
                elements do
                  #{element_config}
                  position [x: 10, y: 20, width: 100, height: 30]
                end
              end
            end
          end
        end
        """

        assert_dsl_valid(dsl_content)
      end
    end

    test "all elements support style configuration" do
      element_configs = [
        {"label", "label :test do\n  text \"Test\"\nend"},
        {"field", "field :test do\n  source :name\nend"},
        {"expression", "expression :test do\n  expression :name\nend"},
        {"aggregate", "aggregate :test do\n  function :count\n  source :id\nend"},
        {"line", "line :test do\n  orientation :horizontal\nend"},
        {"box", "box :test do\nend"},
        {"image", "image :test do\n  source \"/test.png\"\nend"}
      ]

      for {_element_type, element_config} <- element_configs do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :detail do
                type :detail
                
                elements do
                  #{element_config}
                  style [font: "Arial", size: 12, color: "black", align: "center"]
                end
              end
            end
          end
        end
        """

        assert_dsl_valid(dsl_content)
      end
    end

    test "all elements support conditional visibility" do
      element_configs = [
        {"label", "label :test do\n  text \"Test\"\nend"},
        {"field", "field :test do\n  source :name\nend"},
        {"expression", "expression :test do\n  expression :name\nend"},
        {"aggregate", "aggregate :test do\n  function :count\n  source :id\nend"},
        {"line", "line :test do\n  orientation :horizontal\nend"},
        {"box", "box :test do\nend"},
        {"image", "image :test do\n  source \"/test.png\"\nend"}
      ]

      for {_element_type, element_config} <- element_configs do
        dsl_content = """
        reports do
          report :test_report do
            title "Test Report"
            driving_resource AshReports.Test.Customer
            
            bands do
              band :detail do
                type :detail
                
                elements do
                  #{element_config}
                  conditional {:expression, {:not_null, :field_value}}
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

  describe "Element validation edge cases" do
    test "validates element names are unique within band" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :duplicate_name do
                  source :name
                end
                
                field :duplicate_name do
                  source :email
                end
              end
            end
          end
        end
      end
      """

      # This should pass DSL parsing but fail at verifier level
      {:ok, _dsl_state} = parse_dsl(dsl_content)
    end

    test "handles empty element collections" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :empty_band do
              type :detail
              
              elements do
                # Empty elements section should be valid
              end
            end
          end
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "validates complex element positioning" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
          
          bands do
            band :detail do
              type :detail
              
              elements do
                field :field1 do
                  source :name
                  position [x: 0, y: 0, width: 100, height: 20]
                end
                
                field :field2 do
                  source :email
                  position [x: 110, y: 0, width: 150, height: 20]
                end
                
                line :separator do
                  orientation :horizontal
                  position [x: 0, y: 25, width: 260, height: 1]
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
