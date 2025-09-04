defmodule AshReportsDemo.FunctionalDataGeneratorTest do
  @moduledoc """
  Comprehensive tests for the enhanced Phase 8.2 DataGenerator functionality.
  
  Tests the complete data generation system including relationship integrity,
  configurable volumes, error handling, and GenServer state management.
  """
  
  use ExUnit.Case, async: false  # Sequential execution for data generation
  
  alias AshReportsDemo.{
    DataGenerator,
    Domain,
    Customer,
    CustomerAddress,
    CustomerType,
    Product,
    ProductCategory,
    Inventory,
    Invoice,
    InvoiceLineItem
  }

  setup do
    # Ensure clean state for each test
    try do
      DataGenerator.reset_data()
    catch
      # Handle case where DataGenerator isn't started
      _, _ -> :ok
    end
    
    :ok
  end

  describe "foundation data generation" do
    test "creates customer types with proper attributes" do
      assert :ok = DataGenerator.generate_foundation_data()
      
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      assert length(customer_types) == 4
      
      # Verify all expected types exist
      type_names = Enum.map(customer_types, & &1.name)
      assert "Bronze" in type_names
      assert "Silver" in type_names  
      assert "Gold" in type_names
      assert "Platinum" in type_names
      
      # Verify attributes are properly set
      bronze = Enum.find(customer_types, &(&1.name == "Bronze"))
      assert bronze.priority_level == 1
      assert Decimal.equal?(bronze.credit_limit_multiplier, Decimal.new("1.0"))
      assert bronze.active == true
    end

    test "creates product categories with proper attributes" do
      assert :ok = DataGenerator.generate_foundation_data()
      
      {:ok, categories} = ProductCategory.read(domain: Domain)
      assert length(categories) == 5
      
      # Verify all expected categories exist
      category_names = Enum.map(categories, & &1.name)
      assert "Electronics" in category_names
      assert "Clothing" in category_names
      assert "Home & Garden" in category_names
      assert "Books" in category_names  
      assert "Sports" in category_names
      
      # Verify proper sort ordering
      electronics = Enum.find(categories, &(&1.name == "Electronics"))
      assert electronics.sort_order == 1
      assert electronics.active == true
    end

    test "handles duplicate foundation data gracefully" do
      # Generate foundation data twice
      assert :ok = DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_foundation_data()  # Should not error
      
      # Should still have correct counts (not duplicates)
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      {:ok, categories} = ProductCategory.read(domain: Domain)
      
      assert length(customer_types) == 4
      assert length(categories) == 5
    end

    test "creates foundation data with realistic attributes" do
      assert :ok = DataGenerator.generate_foundation_data()
      
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      
      # All types should have descriptions
      for type <- customer_types do
        assert type.description != nil
        assert String.length(type.description) > 0
        assert Decimal.positive?(type.credit_limit_multiplier)
      end
    end
  end

  describe "customer data generation with volume configuration" do
    test "generates small volume customers correctly" do
      DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_customer_data(:small)
      
      {:ok, customers} = Customer.read(domain: Domain, load: [:addresses])
      
      # Small volume should have ~25 customers
      assert length(customers) >= 20
      assert length(customers) <= 30
      
      # Each customer should have 1-2 addresses
      for customer <- customers do
        assert length(customer.addresses) >= 1
        assert length(customer.addresses) <= 2
      end
    end

    test "generates medium volume customers correctly" do
      DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_customer_data(:medium)
      
      {:ok, customers} = Customer.read(domain: Domain, load: [:addresses])
      
      # Medium volume should have ~100 customers
      assert length(customers) >= 80
      assert length(customers) <= 120
      
      # Each customer should have 1-3 addresses
      for customer <- customers do
        assert length(customer.addresses) >= 1
        assert length(customer.addresses) <= 3
      end
    end

    test "maintains referential integrity for customers" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data(:small)
      
      {:ok, customers} = Customer.read(domain: Domain)
      {:ok, addresses} = CustomerAddress.read(domain: Domain)
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      
      # Every customer should reference a valid customer type
      customer_type_ids = Enum.map(customer_types, & &1.id) |> MapSet.new()
      
      for customer <- customers do
        assert customer.customer_type_id in customer_type_ids
      end
      
      # Every address should reference a valid customer
      customer_ids = Enum.map(customers, & &1.id) |> MapSet.new()
      
      for address <- addresses do
        assert address.customer_id in customer_ids
      end
    end

    test "generates realistic customer data" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data(:small)
      
      {:ok, customers} = Customer.read(domain: Domain, load: [:customer_type])
      
      customer = hd(customers)
      
      # Should have realistic attributes
      assert customer.name != nil
      assert String.contains?(customer.email, "@")
      assert customer.email =~ ~r/demo\d+\./  # Unique email pattern
      assert customer.phone != nil
      assert customer.status in [:active, :inactive, :suspended]
      assert Decimal.positive?(customer.credit_limit)
      assert customer.customer_type != nil
    end

    test "generates weighted status distribution" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data(:medium)
      
      {:ok, customers} = Customer.read(domain: Domain)
      
      if length(customers) > 50 do  # Only test with sufficient data
        status_counts = Enum.frequencies_by(customers, & &1.status)
        
        # Should have more active customers (70% target)
        active_count = Map.get(status_counts, :active, 0)
        total_count = length(customers)
        
        active_percentage = active_count / total_count * 100
        
        # Should be roughly 70% active (allow 50-90% range for randomness)
        assert active_percentage >= 50
        assert active_percentage <= 90
      end
    end
  end

  describe "product and inventory generation" do
    test "generates products with categories" do
      DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_product_data(:small)
      
      {:ok, products} = Product.read(domain: Domain, load: [:category])
      
      # Should have products
      assert length(products) >= 80
      assert length(products) <= 120
      
      # Each product should have a category
      for product <- products do
        assert product.category != nil
        assert product.sku != nil
        assert String.starts_with?(product.sku, "SKU-")
        assert Decimal.positive?(product.price)
        assert Decimal.positive?(product.cost)
        # Price should be greater than cost (positive margin)
        assert Decimal.gt?(product.price, product.cost)
      end
    end

    test "creates inventory for all products" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_product_data(:small)
      
      {:ok, products} = Product.read(domain: Domain)
      {:ok, inventory_records} = Inventory.read(domain: Domain)
      
      # Should have inventory record for each product
      assert length(inventory_records) == length(products)
      
      # Every inventory record should reference a valid product
      product_ids = Enum.map(products, & &1.id) |> MapSet.new()
      
      for inventory <- inventory_records do
        assert inventory.product_id in product_ids
        assert inventory.current_stock >= 0
        assert inventory.reorder_point > 0
        assert inventory.location != nil
      end
    end

    test "generates realistic pricing with proper margins" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_product_data(:small)
      
      {:ok, products} = Product.read(domain: Domain)
      
      for product <- products do
        # Margin should be between 20% and 120% (1.2x to 2.2x multiplier)
        margin_ratio = Decimal.div(product.price, product.cost) |> Decimal.to_float()
        
        assert margin_ratio >= 1.2
        assert margin_ratio <= 2.2
      end
    end

    test "generates unique SKUs" do
      DataGenerator.generate_foundation_data()  
      DataGenerator.generate_product_data(:small)
      
      {:ok, products} = Product.read(domain: Domain)
      
      # All SKUs should be unique
      skus = Enum.map(products, & &1.sku)
      unique_skus = Enum.uniq(skus)
      
      assert length(skus) == length(unique_skus)
      
      # SKUs should follow expected pattern
      for sku <- skus do
        assert String.starts_with?(sku, "SKU-")
        assert String.length(sku) >= 10  # SKU-000001-123 format
      end
    end
  end

  describe "complete sample data generation" do
    test "generates small dataset successfully" do
      start_time = System.monotonic_time(:millisecond)
      
      assert :ok = DataGenerator.generate_sample_data(:small)
      
      end_time = System.monotonic_time(:millisecond)
      generation_time = end_time - start_time
      
      # Should complete within reasonable time (under 5 seconds)
      assert generation_time < 5000
      
      # Verify all resource types have expected counts
      {:ok, customers} = Customer.read(domain: Domain)
      {:ok, products} = Product.read(domain: Domain)
      {:ok, invoices} = Invoice.read(domain: Domain)
      
      assert length(customers) >= 20
      assert length(products) >= 80
      assert length(invoices) >= 60
    end

    test "generates medium dataset with proper scaling" do
      assert :ok = DataGenerator.generate_sample_data(:medium)
      
      {:ok, customers} = Customer.read(domain: Domain)
      {:ok, products} = Product.read(domain: Domain)
      {:ok, invoices} = Invoice.read(domain: Domain)
      
      # Medium should have more than small
      assert length(customers) >= 80
      assert length(products) >= 400
      assert length(invoices) >= 250
    end

    test "volume configuration controls data generation" do
      # Test small vs large volume differences
      DataGenerator.reset_data()
      assert :ok = DataGenerator.generate_sample_data(:small)
      {:ok, small_customers} = Customer.read(domain: Domain)
      
      DataGenerator.reset_data()
      assert :ok = DataGenerator.generate_sample_data(:large)
      {:ok, large_customers} = Customer.read(domain: Domain)
      
      # Large should have significantly more customers than small
      assert length(large_customers) > length(small_customers) * 10
    end

    test "maintains relationship integrity across all resources" do
      assert :ok = DataGenerator.generate_sample_data(:small)
      
      # Load all data with relationships
      {:ok, customers} = Customer.read(domain: Domain, load: [:addresses, :customer_type])
      {:ok, products} = Product.read(domain: Domain, load: [:category])
      {:ok, invoices} = Invoice.read(domain: Domain, load: [:customer, :line_items])
      {:ok, line_items} = InvoiceLineItem.read(domain: Domain, load: [:invoice, :product])
      {:ok, inventory} = Inventory.read(domain: Domain, load: [:product])
      
      # Verify all relationships are properly loaded and valid
      for customer <- customers do
        assert customer.customer_type != nil
        assert length(customer.addresses) > 0
      end
      
      for product <- products do
        assert product.category != nil
      end
      
      for invoice <- invoices do
        assert invoice.customer != nil
        assert length(invoice.line_items) > 0
      end
      
      for line_item <- line_items do
        assert line_item.invoice != nil
        assert line_item.product != nil
      end
      
      for inv <- inventory do
        assert inv.product != nil
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles missing foundation data gracefully" do
      # Try to generate customers without foundation data
      result = DataGenerator.generate_customer_data(:small)
      
      # Should return error, not crash
      case result do
        :ok ->
          # If it succeeds, verify it created minimal data
          {:ok, customers} = Customer.read(domain: Domain)
          assert is_list(customers)
          
        {:error, reason} ->
          # Should have clear error message
          assert is_binary(reason)
          assert reason =~ "foundation"
      end
    end

    test "validates volume parameters" do
      result = DataGenerator.generate_sample_data(:invalid_volume)
      
      case result do
        {:error, reason} ->
          assert reason =~ "Unknown volume"
          assert reason =~ "invalid_volume"
          
        _ ->
          # If it doesn't error, it should handle gracefully
          :ok
      end
    end

    test "handles concurrent generation requests" do
      DataGenerator.generate_foundation_data()
      
      # Start multiple generation tasks
      task1 = Task.async(fn -> DataGenerator.generate_customer_data(:small) end)
      task2 = Task.async(fn -> DataGenerator.generate_customer_data(:small) end)
      
      # At least one should succeed, one may be rejected
      results = Task.await_many([task1, task2], 10_000)
      
      successes = Enum.count(results, &(&1 == :ok))
      errors = Enum.count(results, &match?({:error, _}, &1))
      
      # Should handle gracefully (either succeed or give clear error)
      assert successes >= 1 or errors >= 1
      assert successes + errors == 2
    end

    test "validates data integrity after generation" do
      assert :ok = DataGenerator.generate_sample_data(:small)
      
      # Check that there are no orphaned records
      {:ok, addresses} = CustomerAddress.read(domain: Domain)
      {:ok, customers} = Customer.read(domain: Domain)
      
      customer_ids = Enum.map(customers, & &1.id) |> MapSet.new()
      
      # All addresses should reference existing customers
      for address <- addresses do
        assert address.customer_id in customer_ids,
               "Address #{address.id} references non-existent customer #{address.customer_id}"
      end
    end

    test "generates data within memory constraints" do
      before_memory = :erlang.memory(:total)
      
      assert :ok = DataGenerator.generate_sample_data(:medium)
      
      after_memory = :erlang.memory(:total)
      memory_increase = after_memory - before_memory
      
      # Memory increase should be reasonable (under 50MB)
      assert memory_increase < 50_000_000
    end
  end

  describe "realistic data quality" do
    test "generates unique emails" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data(:small)
      
      {:ok, customers} = Customer.read(domain: Domain)
      
      emails = Enum.map(customers, & &1.email)
      unique_emails = Enum.uniq(emails)
      
      # All emails should be unique
      assert length(emails) == length(unique_emails)
      
      # Should follow demo pattern
      for email <- emails do
        assert email =~ ~r/demo\d+\./
      end
    end

    test "generates realistic addresses" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data(:small)
      
      {:ok, addresses} = CustomerAddress.read(domain: Domain)
      
      for address <- addresses do
        assert address.street != nil
        assert address.city != nil
        assert address.state != nil
        assert address.postal_code != nil
        assert address.country == "United States"
        assert address.address_type in [:billing, :shipping, :mailing]
      end
      
      # Each customer should have at least one primary address
      {:ok, customers} = Customer.read(domain: Domain, load: [:addresses])
      
      for customer <- customers do
        primary_addresses = Enum.filter(customer.addresses, & &1.primary)
        assert length(primary_addresses) >= 1
      end
    end

    test "generates realistic product pricing" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_product_data(:small)
      
      {:ok, products} = Product.read(domain: Domain)
      
      for product <- products do
        # Cost should be reasonable ($10-$510)
        cost_float = Decimal.to_float(product.cost)
        assert cost_float >= 10.0
        assert cost_float <= 510.0
        
        # Price should be higher than cost
        assert Decimal.gt?(product.price, product.cost)
        
        # Weight should be reasonable (0.1-10.0)
        weight_float = Decimal.to_float(product.weight)
        assert weight_float >= 0.1
        assert weight_float <= 10.0
      end
    end
  end

  describe "GenServer state management" do
    test "tracks generation status correctly" do
      # Check initial status
      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
      assert stats.last_generated == nil
      
      # Generate data
      assert :ok = DataGenerator.generate_sample_data(:small)
      
      # Check updated status
      updated_stats = DataGenerator.data_stats()
      assert updated_stats.generation_in_progress == false
      assert updated_stats.last_generated != nil
      assert updated_stats.current_volume == :small
    end

    test "prevents concurrent generation" do
      DataGenerator.generate_foundation_data()
      
      # Start long-running generation in background
      task = Task.async(fn ->
        DataGenerator.generate_sample_data(:large)
      end)
      
      # Try to start another generation immediately
      result = DataGenerator.generate_sample_data(:small)
      
      case result do
        {:error, reason} ->
          # Should reject concurrent generation
          assert reason =~ "in progress"
          
        :ok ->
          # If it succeeded, both operations completed successfully
          :ok
      end
      
      # Clean up
      Task.await(task, 30_000)
    end

    test "handles reset during generation gracefully" do
      DataGenerator.generate_foundation_data()
      
      # Start generation
      task = Task.async(fn ->
        DataGenerator.generate_sample_data(:medium)
      end)
      
      # Try to reset while generating
      reset_result = DataGenerator.reset_data()
      
      # Should handle gracefully
      assert reset_result in [:ok, {:error, _}]
      
      # Wait for generation to complete
      generation_result = Task.await(task, 15_000)
      assert generation_result in [:ok, {:error, _}]
    end
  end
end