defmodule AshReports.DomainTest do
  use ExUnit.Case, async: true
  
  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false
    
    resources do
      allow_unregistered? true
    end
  end
  
  defmodule Product do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets
      
    ets do
      private? true
    end
    
    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false
      attribute :price, :decimal, allow_nil?: false
      attribute :category, :string, allow_nil?: false
      attribute :stock_level, :integer, default: 0
    end
    
    actions do
      defaults [:read]
    end
  end
  
  describe "Domain extension" do
    test "can define a domain with reports section" do
      defmodule BasicDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain],
          validate_config_inclusion?: false
          
        resources do
          resource Product
        end
        
        reports do
          default_page_size :letter
          default_orientation :landscape
          default_locale "en-US"
          default_time_zone "America/New_York"
          
          report :simple_report do
            title "Simple Report"
            
            band :detail do
              column :name do
                field :name
              end
            end
          end
        end
      end
      
      # Verify domain functions
      assert AshReports.Domain.default_page_size(BasicDomain) == :letter
      assert AshReports.Domain.default_orientation(BasicDomain) == :landscape
      assert AshReports.Domain.default_locale(BasicDomain) == "en-US"
      assert AshReports.Domain.default_time_zone(BasicDomain) == "America/New_York"
      
      # Verify reports
      reports = AshReports.Domain.list_reports(BasicDomain)
      assert length(reports) == 1
      
      report = hd(reports)
      assert report.name == :simple_report
      assert report.title == "Simple Report"
      
      # Verify report lookup
      assert AshReports.Domain.get_report(BasicDomain, :simple_report) == report
      assert AshReports.Domain.get_report(BasicDomain, :nonexistent) == nil
    end
    
    test "validates unique report names" do
      assert_raise Spark.Error.DslError, ~r/Duplicate report names found/, fn ->
        defmodule DuplicateReportDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :duplicate_name do
              band :detail do
                column :test do
                  field :name
                end
              end
            end
            
            report :duplicate_name do
              band :detail do
                column :test do
                  field :name
                end
              end
            end
          end
        end
      end
    end
    
    test "validates report must have at least one detail band" do
      assert_raise Spark.Error.DslError, ~r/Report should have at least one detail band/, fn ->
        defmodule NoDetailBandDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :no_detail do
              band :title do
                column :title do
                  value "Title Only"
                end
              end
            end
          end
        end
      end
    end
    
    test "validates group bands must come in pairs" do
      assert_raise Spark.Error.DslError, ~r/Group header and footer bands must come in matching pairs/, fn ->
        defmodule UnpairedGroupDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :unpaired_groups do
              band :group_header do
                group_expression :category
                column :category do
                  field :category
                end
              end
              
              band :detail do
                column :name do
                  field :name
                end
              end
              
              # Missing group_footer
            end
          end
        end
      end
    end
    
    test "validates group bands must have group_expression" do
      assert_raise Spark.Error.DslError, ~r/Group bands must have a group_expression/, fn ->
        defmodule NoGroupExpressionDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :no_group_expr do
              band :group_header do
                # Missing group_expression
                column :category do
                  field :category
                end
              end
              
              band :detail do
                column :name do
                  field :name
                end
              end
              
              band :group_footer do
                group_expression :category
                column :count do
                  value "Count"
                end
              end
            end
          end
        end
      end
    end
    
    test "validates non-group bands cannot have group_expression" do
      assert_raise Spark.Error.DslError, ~r/Only group bands can have a group_expression/, fn ->
        defmodule InvalidGroupExpressionDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :invalid_group_expr do
              band :detail do
                group_expression :category  # Invalid for detail band
                column :name do
                  field :name
                end
              end
            end
          end
        end
      end
    end
    
    test "supports complex report with multiple bands" do
      defmodule ComplexDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain],
          validate_config_inclusion?: false
        
        reports do
          report :inventory_report do
            title "Inventory Report"
            description "Complete inventory listing by category"
            page_size :letter
            orientation :landscape
            margins %{top: 30, bottom: 30, left: 20, right: 20}
            
            band :title do
              height "50px"
              column :title do
                value "Inventory Report"
                align :center
              end
            end
            
            band :page_header do
              column :date do
                value fn _record, _context -> Date.utc_today() end
                format :date
                align :right
              end
            end
            
            band :column_header do
              column :category_header do
                label "Category"
              end
              column :name_header do
                label "Product"
              end
              column :stock_header do
                label "Stock"
                align :right
              end
              column :price_header do
                label "Price"
                align :right
              end
            end
            
            band :group_header do
              group_expression :category
              column :category do
                field :category
                group_by true
              end
            end
            
            band :detail do
              column :name do
                field :name
              end
              column :stock do
                field :stock_level
                format :number
                align :right
              end
              column :price do
                field :price
                format :currency
                align :right
              end
            end
            
            band :group_footer do
              group_expression :category
              column :subtotal_label do
                value "Subtotal:"
                align :right
              end
              column :subtotal_stock do
                field :stock_level
                aggregate :sum
                format :number
                align :right
              end
              column :subtotal_value do
                value fn records, _context ->
                  Enum.reduce(records, 0, fn r, acc ->
                    acc + (r.stock_level * r.price)
                  end)
                end
                format :currency
                align :right
              end
            end
            
            band :summary do
              column :total_label do
                value "Grand Total:"
                align :right
              end
              column :total_items do
                aggregate :count
                format :number
                align :right
              end
            end
          end
        end
      end
      
      reports = AshReports.Domain.list_reports(ComplexDomain)
      assert length(reports) == 1
      
      report = hd(reports)
      assert report.name == :inventory_report
      assert report.title == "Inventory Report"
      assert report.description == "Complete inventory listing by category"
      assert report.page_size == :letter
      assert report.orientation == :landscape
      assert report.margins == %{top: 30, bottom: 30, left: 20, right: 20}
      
      # Verify bands
      assert length(report.bands) == 7
      band_types = Enum.map(report.bands, & &1.type)
      assert :title in band_types
      assert :page_header in band_types
      assert :column_header in band_types
      assert :group_header in band_types
      assert :detail in band_types
      assert :group_footer in band_types
      assert :summary in band_types
    end
    
  end
end