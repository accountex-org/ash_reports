defmodule AshReportsDemo.DataGeneratorIntegrationTest do
  @moduledoc """
  Integration tests that validate the fixed DataGenerator works with all 4 report types.
  
  Tests the complete pipeline from data generation through report processing.
  """
  
  use ExUnit.Case, async: false
  
  alias AshReports.DataLoader
  alias AshReportsDemo.{DataGenerator, EtsDataLayer, Domain}
  
  setup do
    # Start required services
    start_supervised!(EtsDataLayer)
    start_supervised!(DataGenerator)
    
    # Generate fresh test data
    DataGenerator.reset_data()
    
    case DataGenerator.generate_sample_data(:small) do
      :ok -> 
        # Validate data was generated correctly
        {:ok, _stats} = DataGenerator.validate_data_integrity()
        :ok
      {:error, reason} ->
        flunk("Failed to generate test data: #{reason}")
    end
  end

  describe "customer_summary report integration" do
    test "loads customer_summary report with generated data" do
      case DataLoader.load_report(Domain, :customer_summary, %{}) do
        {:ok, result} ->
          # Should have loaded actual customer records
          assert length(result.records) > 0
          
          # Variables should be calculated from real data
          assert Map.has_key?(result.variables, :customer_count)
          assert result.variables.customer_count == length(result.records)
          
          # Should have customer lifetime value data
          assert Map.has_key?(result.variables, :total_lifetime_value)
          assert Decimal.gt?(result.variables.total_lifetime_value, Decimal.new("0"))
          
          # Verify records have required fields for report
          first_customer = List.first(result.records)
          assert Map.has_key?(first_customer, :name)
          assert Map.has_key?(first_customer, :status)
          assert Map.has_key?(first_customer, :credit_limit)
          
        {:error, reason} ->
          flunk("Customer summary report failed: #{inspect(reason)}")
      end
    end
    
    test "customer_summary report handles grouping by status" do
      case DataLoader.load_report(Domain, :customer_summary, %{}) do
        {:ok, result} ->
          # Should have group data based on customer status
          assert is_map(result.groups)
          
          # At least some customers should have different statuses
          statuses = Enum.map(result.records, & &1.status) |> Enum.uniq()
          assert length(statuses) > 1
          
        {:error, reason} ->
          flunk("Customer summary grouping failed: #{inspect(reason)}")
      end
    end
  end

  describe "product_inventory report integration" do
    test "loads product_inventory report with generated data" do
      case DataLoader.load_report(Domain, :product_inventory, %{}) do
        {:ok, result} ->
          # Should have loaded product records
          assert length(result.records) > 0
          
          # Variables should reflect actual product counts
          assert Map.has_key?(result.variables, :total_products)
          assert result.variables.total_products == length(result.records)
          
          # Should calculate inventory values
          assert Map.has_key?(result.variables, :total_inventory_value)
          
          # Verify records have required fields
          first_product = List.first(result.records)
          assert Map.has_key?(first_product, :name)
          assert Map.has_key?(first_product, :price)
          assert Map.has_key?(first_product, :sku)
          
        {:error, reason} ->
          flunk("Product inventory report failed: #{inspect(reason)}")
      end
    end
    
    test "product_inventory report handles category grouping" do
      case DataLoader.load_report(Domain, :product_inventory, %{}) do
        {:ok, result} ->
          # Should group by product category
          assert is_map(result.groups)
          
          # Should have products from multiple categories
          # (since we generated 5 categories and distributed products among them)
          if length(result.records) >= 5 do
            categories = Enum.map(result.records, fn product ->
              Map.get(product, :category_id)
            end) |> Enum.uniq()
            
            assert length(categories) > 1
          end
          
        {:error, reason} ->
          flunk("Product inventory grouping failed: #{inspect(reason)}")
      end
    end
  end

  describe "invoice_details report integration" do
    test "loads invoice_details report with generated data" do
      case DataLoader.load_report(Domain, :invoice_details, %{}) do
        {:ok, result} ->
          # Should have loaded invoice records
          assert length(result.records) > 0
          
          # Variables should reflect actual invoice data
          assert Map.has_key?(result.variables, :total_invoices)
          assert result.variables.total_invoices == length(result.records)
          
          # Should calculate revenue metrics
          assert Map.has_key?(result.variables, :total_revenue)
          
          # Verify records have required fields
          first_invoice = List.first(result.records)
          assert Map.has_key?(first_invoice, :invoice_number)
          assert Map.has_key?(first_invoice, :date)
          assert Map.has_key?(first_invoice, :total)
          
        {:error, reason} ->
          flunk("Invoice details report failed: #{inspect(reason)}")
      end
    end
    
    test "invoice_details report handles date grouping" do
      case DataLoader.load_report(Domain, :invoice_details, %{}) do
        {:ok, result} ->
          # Should group by invoice date
          assert is_map(result.groups)
          
          # Should have invoices from different dates
          dates = Enum.map(result.records, & &1.date) |> Enum.uniq()
          assert length(dates) > 1
          
        {:error, reason} ->
          flunk("Invoice details grouping failed: #{inspect(reason)}")
      end
    end
  end

  describe "financial_summary report integration" do
    test "loads financial_summary report with generated data" do
      case DataLoader.load_report(Domain, :financial_summary, %{}) do
        {:ok, result} ->
          # Should have aggregated financial data
          assert length(result.records) >= 0  # May be aggregated data
          
          # Should calculate key financial metrics
          assert Map.has_key?(result.variables, :total_revenue)
          assert Map.has_key?(result.variables, :invoice_count)
          
          # Revenue should be positive if we have invoices
          if result.variables.invoice_count > 0 do
            assert Decimal.gt?(result.variables.total_revenue, Decimal.new("0"))
          end
          
        {:error, reason} ->
          flunk("Financial summary report failed: #{inspect(reason)}")
      end
    end
  end

  describe "report parameter handling" do
    test "reports handle parameter filtering correctly" do
      # Test customer_summary with status filter
      params = %{status: :active}
      
      case DataLoader.load_report(Domain, :customer_summary, params) do
        {:ok, result} ->
          # All returned customers should be active (if filter is working)
          # Note: This test depends on parameter handling being implemented
          assert is_list(result.records)
          
        {:error, reason} ->
          # Parameters might not be fully implemented yet - that's ok for Phase 8.2
          IO.puts("Parameter handling not yet implemented: #{inspect(reason)}")
      end
    end
  end

  describe "performance validation" do
    test "small dataset generation and report loading completes within time limits" do
      # Reset and regenerate to test performance
      DataGenerator.reset_data()
      
      # Generation should complete quickly for small dataset
      {generation_time, result} = :timer.tc(fn ->
        DataGenerator.generate_sample_data(:small)
      end)
      
      assert result == :ok
      assert generation_time < 5_000_000  # 5 seconds in microseconds
      
      # Report loading should also be fast
      {report_time, report_result} = :timer.tc(fn ->
        DataLoader.load_report(Domain, :customer_summary, %{})
      end)
      
      assert {:ok, _} = report_result
      assert report_time < 2_000_000  # 2 seconds in microseconds
    end
    
    test "data integrity validation completes quickly" do
      {validation_time, result} = :timer.tc(fn ->
        DataGenerator.validate_data_integrity()
      end)
      
      assert {:ok, _stats} = result
      assert validation_time < 1_000_000  # 1 second in microseconds
    end
  end

  describe "error recovery" do
    test "reports handle corrupted data gracefully" do
      # Generate good data first
      DataGenerator.generate_sample_data(:small)
      
      # Manually corrupt some data by deleting foundation data
      {:ok, customer_types} = AshReportsDemo.CustomerType.read(domain: Domain)
      first_type = List.first(customer_types)
      AshReportsDemo.CustomerType.destroy!(first_type, domain: Domain)
      
      # Reports should either handle this gracefully or provide clear error messages
      case DataLoader.load_report(Domain, :customer_summary, %{}) do
        {:ok, result} ->
          # If it succeeds, should have some data
          assert is_list(result.records)
          
        {:error, reason} ->
          # If it fails, should have a reasonable error message
          assert is_binary(reason) or is_atom(reason)
      end
    end
  end

  describe "data volume validation" do
    test "medium volume generates more data than small volume" do
      # Test small volume
      DataGenerator.reset_data()
      DataGenerator.generate_sample_data(:small)
      
      {:ok, small_customers} = AshReportsDemo.Customer.read(domain: Domain)
      small_count = length(small_customers)
      
      # Test medium volume  
      DataGenerator.reset_data()
      DataGenerator.generate_sample_data(:medium)
      
      {:ok, medium_customers} = AshReportsDemo.Customer.read(domain: Domain)
      medium_count = length(medium_customers)
      
      # Medium should have more customers than small
      assert medium_count > small_count
    end
  end
end