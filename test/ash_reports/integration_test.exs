defmodule AshReports.IntegrationTest do
  use ExUnit.Case, async: true
  
  @moduledoc """
  Integration tests for AshReports extensions.
  
  These tests verify that:
  - Extensions load without errors
  - DSL syntax is properly parsed
  - Spark registration works correctly
  - Domain and Resource extensions integrate properly
  """
  
  describe "extension loading" do
    test "domain extension loads successfully" do
      defmodule LoadTestDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain],
          validate_config_inclusion?: false
      end
      
      # Verify the extension is loaded
      extensions = Spark.extensions(LoadTestDomain)
      assert AshReports.Domain in extensions
    end
    
    test "resource extension loads successfully" do
      defmodule LoadTestDomain2 do
        use Ash.Domain,
          validate_config_inclusion?: false
          
        resources do
          allow_unregistered? true
        end
      end
      
      defmodule LoadTestResource do
        use Ash.Resource,
          domain: LoadTestDomain2,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
          attribute :name, :string
        end
      end
      
      # Verify the extension is loaded
      extensions = Spark.extensions(LoadTestResource)
      assert AshReports.Resource in extensions
    end
  end
  
  describe "DSL syntax parsing" do
    test "complete report DSL parses correctly" do
      defmodule CompleteDslDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain],
          validate_config_inclusion?: false
          
        reports do
          default_page_size :a4
          default_orientation :portrait
          default_locale "en"
          default_time_zone "UTC"
          
          report :complete_report do
            title "Complete Report Example"
            description "Demonstrates all DSL features"
            page_size :letter
            orientation :landscape
            locale "en-US"
            time_zone "America/New_York"
            margins %{top: 25, bottom: 25, left: 20, right: 20}
            
            # All band types
            band :title do
              height "60px"
              visible true
              
              column :report_title do
                value "Sales Report"
                align :center
                width "100%"
              end
            end
            
            band :page_header do
              split_type :prevent
              
              column :page_number do
                value fn _record, context -> context.page_number end
                align :right
              end
            end
            
            band :column_header do
              height "30px"
              
              column :product_header do
                label "Product"
                align :left
              end
              
              column :quantity_header do
                label "Qty"
                align :right
              end
              
              column :price_header do
                label "Price"
                align :right
              end
            end
            
            band :group_header do
              group_expression :category
              group_keep_together true
              
              column :category_name do
                field :category
                group_by true
              end
            end
            
            band :detail do
              column :product do
                field :name
              end
              
              column :quantity do
                field :quantity
                format :number
                align :right
              end
              
              column :price do
                field :unit_price
                format :currency
                align :right
              end
            end
            
            band :group_footer do
              group_expression :category
              
              column :subtotal_label do
                value "Category Total:"
                align :right
              end
              
              column :subtotal do
                aggregate :sum
                field :quantity
                format :number
                align :right
              end
            end
            
            band :column_footer do
              column :total_label do
                value "Report Total:"
                align :right
              end
              
              column :total_quantity do
                aggregate :sum
                field :quantity
                format :number
                align :right
              end
            end
            
            band :page_footer do
              column :timestamp do
                value fn _record, _context -> DateTime.utc_now() end
                format :datetime
                align :left
              end
            end
            
            band :summary do
              column :summary_text do
                value "End of Report"
                align :center
              end
            end
          end
        end
      end
      
      # Verify the report was parsed correctly
      reports = AshReports.Domain.list_reports(CompleteDslDomain)
      assert length(reports) == 1
      
      report = hd(reports)
      assert report.name == :complete_report
      assert report.title == "Complete Report Example"
      
      # Verify all 9 band types are present
      band_types = Enum.map(report.bands, & &1.type)
      assert :title in band_types
      assert :page_header in band_types
      assert :column_header in band_types
      assert :group_header in band_types
      assert :detail in band_types
      assert :group_footer in band_types
      assert :column_footer in band_types
      assert :page_footer in band_types
      assert :summary in band_types
      assert length(band_types) == 9
    end
    
    test "resource reportable DSL parses correctly" do
      defmodule ResourceTestDomain do
        use Ash.Domain,
          validate_config_inclusion?: false
          
        resources do
          allow_unregistered? true
        end
      end
      
      defmodule CompleteDslResource do
        use Ash.Resource,
          domain: ResourceTestDomain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
          attribute :name, :string
          attribute :category, :atom
          attribute :quantity, :integer
          attribute :unit_price, :decimal
        end
        
        reportable do
          reports [:complete_report, :inventory_report]
          default_columns [:name, :category, :quantity, :unit_price]
          
          column_labels %{
            unit_price: "Price per Unit",
            quantity: "Quantity in Stock"
          }
          
          column_formats %{
            unit_price: :currency,
            quantity: :number
          }
          
          exclude_columns [:id]
        end
      end
      
      # Verify reportable configuration
      assert AshReports.Resource.list_reports(CompleteDslResource) == [:complete_report, :inventory_report]
      assert AshReports.Resource.default_columns(CompleteDslResource) == [:name, :category, :quantity, :unit_price]
      assert AshReports.Resource.column_label(CompleteDslResource, :unit_price) == "Price per Unit"
      assert AshReports.Resource.column_format(CompleteDslResource, :quantity) == :number
      assert AshReports.Resource.exclude_column?(CompleteDslResource, :id) == true
    end
  end
  
  describe "Spark DSL structure" do
    test "domain has reports section defined" do
      # The extension should define a reports section
      defmodule SectionTestDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain],
          validate_config_inclusion?: false
          
        reports do
          # Empty reports section should work
        end
      end
      
      # If we got here without errors, the section is defined
      assert true
    end
    
    test "resource has reportable section defined" do
      defmodule SectionTestDomain2 do
        use Ash.Domain,
          validate_config_inclusion?: false
          
        resources do
          allow_unregistered? true
        end
      end
      
      defmodule SectionTestResource do
        use Ash.Resource,
          domain: SectionTestDomain2,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
        end
        
        reportable do
          # Empty reportable section should work
        end
      end
      
      # If we got here without errors, the section is defined
      assert true
    end
    
    test "verifiers run for domain extension" do
      # This test verifies that our validation runs
      assert_raise Spark.Error.DslError, ~r/Duplicate report names/, fn ->
        defmodule VerifierTestDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :duplicate do
              band :detail do
                column :test, field: :test
              end
            end
            
            report :duplicate do
              band :detail do
                column :test, field: :test
              end
            end
          end
        end
      end
    end
  end
  
  describe "domain and resource integration" do
    test "resource can reference reports defined in its domain" do
      defmodule IntegrationDomain do
        use Ash.Domain,
          extensions: [AshReports.Domain],
          validate_config_inclusion?: false
          
        resources do
          allow_unregistered? true
        end
        
        reports do
          report :user_report do
            title "User Report"
            
            band :detail do
              column :username do
                field :username
              end
              
              column :email do
                field :email
              end
            end
          end
          
          report :admin_report do
            title "Admin Report"
            
            band :detail do
              column :username do
                field :username
              end
              
              column :role do
                field :role
              end
              
              column :last_login do
                field :last_login_at
                format :datetime
              end
            end
          end
        end
      end
      
      defmodule User do
        use Ash.Resource,
          domain: IntegrationDomain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshReports.Resource]
          
        ets do
          private? true
        end
        
        attributes do
          uuid_primary_key :id
          attribute :username, :string, allow_nil?: false
          attribute :email, :string, allow_nil?: false
          attribute :role, :atom, constraints: [one_of: [:user, :admin]]
          attribute :last_login_at, :utc_datetime_usec
        end
        
        reportable do
          reports [:user_report, :admin_report]
          
          column_labels %{
            username: "User Name",
            last_login_at: "Last Login"
          }
          
          exclude_columns [:id]
        end
      end
      
      # Verify domain has the reports
      domain_reports = AshReports.Domain.list_reports(IntegrationDomain)
      assert length(domain_reports) == 2
      assert Enum.find(domain_reports, &(&1.name == :user_report))
      assert Enum.find(domain_reports, &(&1.name == :admin_report))
      
      # Verify resource references the reports
      assert AshReports.Resource.can_use_with_report?(User, :user_report)
      assert AshReports.Resource.can_use_with_report?(User, :admin_report)
      assert not AshReports.Resource.can_use_with_report?(User, :other_report)
    end
  end
  
  describe "error handling" do
    test "meaningful error when report name is missing" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingNameDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report do  # Missing name argument
              band :detail do
                column :test do
                  field :test
                end
              end
            end
          end
        end
      end
    end
    
    test "meaningful error when band type is missing" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingBandTypeDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :test_report do
              band do  # Missing type argument
                column :test do
                  field :test
                end
              end
            end
          end
        end
      end
    end
    
    test "meaningful error when column name is missing" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingColumnNameDomain do
          use Ash.Domain,
            extensions: [AshReports.Domain],
            validate_config_inclusion?: false
            
          reports do
            report :test_report do
              band :detail do
                column do  # Missing name argument
                  field :test
                end
              end
            end
          end
        end
      end
    end
  end
end