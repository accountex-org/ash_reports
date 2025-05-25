defmodule AshReports.ResourceTest do
  use ExUnit.Case, async: true
  
  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false
    
    resources do
      allow_unregistered? true
    end
  end
  
  describe "Resource extension" do
    test "can define a resource with reportable section" do
      defmodule BasicProduct do
        use Ash.Resource,
          domain: TestDomain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
          attribute :name, :string
          attribute :price, :decimal
          attribute :stock_level, :integer
        end
        
        reportable do
          reports [:inventory_report, :sales_summary]
          default_columns [:name, :price, :stock_level]
          column_labels %{
            stock_level: "In Stock",
            price: "Unit Price"
          }
          column_formats %{
            price: :currency,
            stock_level: :number
          }
          exclude_columns [:id]
        end
      end
      
      # Test reports list
      assert AshReports.Resource.list_reports(BasicProduct) == [:inventory_report, :sales_summary]
      assert AshReports.Resource.can_use_with_report?(BasicProduct, :inventory_report) == true
      assert AshReports.Resource.can_use_with_report?(BasicProduct, :other_report) == false
      
      # Test default columns
      assert AshReports.Resource.default_columns(BasicProduct) == [:name, :price, :stock_level]
      
      # Test column labels
      assert AshReports.Resource.column_labels(BasicProduct) == %{
        stock_level: "In Stock",
        price: "Unit Price"
      }
      assert AshReports.Resource.column_label(BasicProduct, :stock_level) == "In Stock"
      assert AshReports.Resource.column_label(BasicProduct, :name) == nil
      
      # Test column formats
      assert AshReports.Resource.column_formats(BasicProduct) == %{
        price: :currency,
        stock_level: :number
      }
      assert AshReports.Resource.column_format(BasicProduct, :price) == :currency
      assert AshReports.Resource.column_format(BasicProduct, :name) == nil
      
      # Test exclude columns
      assert AshReports.Resource.exclude_columns(BasicProduct) == [:id]
      assert AshReports.Resource.exclude_column?(BasicProduct, :id) == true
      assert AshReports.Resource.exclude_column?(BasicProduct, :name) == false
      
      # Test reportable columns
      reportable = AshReports.Resource.reportable_columns(BasicProduct)
      assert :name in reportable
      assert :price in reportable
      assert :stock_level in reportable
      assert :id not in reportable
    end
    
    test "resource with empty reportable section uses defaults" do
      defmodule EmptyReportableProduct do
        use Ash.Resource,
          domain: TestDomain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
          attribute :name, :string
        end
        
        reportable do
          # Empty section
        end
      end
      
      assert AshReports.Resource.list_reports(EmptyReportableProduct) == []
      assert AshReports.Resource.default_columns(EmptyReportableProduct) == nil
      assert AshReports.Resource.column_labels(EmptyReportableProduct) == %{}
      assert AshReports.Resource.column_formats(EmptyReportableProduct) == %{}
      assert AshReports.Resource.exclude_columns(EmptyReportableProduct) == []
      
      # All columns are reportable when nothing is excluded
      reportable = AshReports.Resource.reportable_columns(EmptyReportableProduct)
      assert :id in reportable
      assert :name in reportable
    end
    
    test "resource with complex configuration" do
      defmodule ComplexProduct do
        use Ash.Resource,
          domain: TestDomain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false
          attribute :description, :string
          attribute :category, :atom, constraints: [one_of: [:electronics, :clothing, :food]]
          attribute :price, :decimal, allow_nil?: false
          attribute :cost, :decimal
          attribute :stock_level, :integer, default: 0
          attribute :reorder_point, :integer, default: 10
          attribute :supplier_id, :uuid
          attribute :internal_notes, :string
          attribute :active, :boolean, default: true
          create_timestamp :created_at
          update_timestamp :updated_at
        end
        
        reportable do
          reports [:inventory_report, :pricing_report, :supplier_report, :activity_report]
          
          default_columns [:name, :category, :price, :stock_level, :active]
          
          column_labels %{
            stock_level: "Current Stock",
            reorder_point: "Reorder At",
            price: "Retail Price",
            cost: "Wholesale Cost",
            active: "Available"
          }
          
          column_formats %{
            price: :currency,
            cost: :currency,
            stock_level: :number,
            reorder_point: :number,
            created_at: :datetime,
            updated_at: :date,
            active: :boolean
          }
          
          exclude_columns [:id, :supplier_id, :internal_notes, :cost]
        end
      end
      
      # Verify configuration
      assert length(AshReports.Resource.list_reports(ComplexProduct)) == 4
      assert AshReports.Resource.can_use_with_report?(ComplexProduct, :inventory_report)
      assert AshReports.Resource.can_use_with_report?(ComplexProduct, :pricing_report)
      
      # Verify labels are properly set
      assert AshReports.Resource.column_label(ComplexProduct, :stock_level) == "Current Stock"
      assert AshReports.Resource.column_label(ComplexProduct, :active) == "Available"
      
      # Verify formats
      assert AshReports.Resource.column_format(ComplexProduct, :price) == :currency
      assert AshReports.Resource.column_format(ComplexProduct, :created_at) == :datetime
      assert AshReports.Resource.column_format(ComplexProduct, :active) == :boolean
      
      # Verify excluded columns
      excluded = AshReports.Resource.exclude_columns(ComplexProduct)
      assert :internal_notes in excluded
      assert :cost in excluded
      assert :supplier_id in excluded
      
      # Verify reportable columns don't include excluded ones
      reportable = AshReports.Resource.reportable_columns(ComplexProduct)
      assert :name in reportable
      assert :price in reportable
      assert :stock_level in reportable
      assert :internal_notes not in reportable
      assert :cost not in reportable
      assert :supplier_id not in reportable
    end
  end
end