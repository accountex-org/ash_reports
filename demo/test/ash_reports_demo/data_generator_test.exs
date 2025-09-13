defmodule AshReportsDemo.DataGeneratorTest do
  @moduledoc """
  Comprehensive unit tests for the fixed DataGenerator.
  
  Tests all aspects of data generation including transaction management,
  referential integrity, and error handling.
  """
  
  use ExUnit.Case, async: false
  
  alias AshReportsDemo.{DataGenerator, EtsDataLayer, Domain}
  alias AshReportsDemo.{Customer, CustomerType, CustomerAddress, Product, ProductCategory, Inventory, Invoice, InvoiceLineItem}
  
  setup do
    # Start the ETS data layer if not already started
    start_supervised!(EtsDataLayer)
    
    # Start the data generator
    start_supervised!(DataGenerator)
    
    # Clear any existing data
    DataGenerator.reset_data()
    
    :ok
  end

  describe "foundation data generation" do
    test "creates customer types with correct attributes" do
      assert :ok = DataGenerator.generate_foundation_data()
      
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      
      assert length(customer_types) == 4
      
      # Verify all expected customer types exist
      type_names = Enum.map(customer_types, & &1.name) |> MapSet.new()
      expected_names = MapSet.new(["Bronze", "Silver", "Gold", "Platinum"])
      assert MapSet.equal?(type_names, expected_names)
      
      # Verify attributes are set correctly
      gold_type = Enum.find(customer_types, &(&1.name == "Gold"))
      assert gold_type.priority_level == 3
      assert gold_type.discount_percentage == Decimal.new("10")
      assert gold_type.active == true
    end
    
    test "creates product categories with correct attributes" do
      assert :ok = DataGenerator.generate_foundation_data()
      
      {:ok, categories} = ProductCategory.read(domain: Domain)
      
      assert length(categories) == 5
      
      # Verify all expected categories exist
      category_names = Enum.map(categories, & &1.name) |> MapSet.new()
      expected_names = MapSet.new(["Electronics", "Clothing", "Home & Garden", "Books", "Sports"])
      assert MapSet.equal?(category_names, expected_names)
      
      # Verify sort order
      electronics = Enum.find(categories, &(&1.name == "Electronics"))
      assert electronics.sort_order == 1
      assert electronics.active == true
    end
    
    test "handles duplicate foundation data gracefully" do
      # Generate foundation data twice
      assert :ok = DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_foundation_data()
      
      # Should still only have the expected counts
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      {:ok, categories} = ProductCategory.read(domain: Domain)
      
      assert length(customer_types) == 4
      assert length(categories) == 5
    end
  end

  describe "customer data generation" do
    setup do
      DataGenerator.generate_foundation_data()
      :ok
    end
    
    test "creates customers with valid customer type references" do
      assert :ok = DataGenerator.generate_customer_data()
      
      {:ok, customers} = Customer.read(domain: Domain)
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      
      assert length(customers) > 0
      
      # Verify all customers have valid customer_type_id references
      customer_type_ids = MapSet.new(customer_types, & &1.id)
      
      invalid_customers = Enum.filter(customers, fn customer ->
        not MapSet.member?(customer_type_ids, customer.customer_type_id)
      end)
      
      assert Enum.empty?(invalid_customers), "Found customers with invalid customer_type_id"
    end
    
    test "creates addresses for customers with valid references" do
      assert :ok = DataGenerator.generate_customer_data()
      
      {:ok, customers} = Customer.read(domain: Domain)
      {:ok, addresses} = CustomerAddress.read(domain: Domain)
      
      assert length(addresses) > 0
      
      # Verify all addresses have valid customer_id references
      customer_ids = MapSet.new(customers, & &1.id)
      
      invalid_addresses = Enum.filter(addresses, fn address ->
        not MapSet.member?(customer_ids, address.customer_id)
      end)
      
      assert Enum.empty?(invalid_addresses), "Found addresses with invalid customer_id"
      
      # Verify each customer has at least one primary address
      primary_addresses = Enum.filter(addresses, & &1.primary)
      assert length(primary_addresses) > 0
    end
    
    test "generates realistic customer data" do
      assert :ok = DataGenerator.generate_customer_data()
      
      {:ok, customers} = Customer.read(domain: Domain)
      
      customer = List.first(customers)
      
      # Verify data fields are populated
      assert is_binary(customer.name) and String.length(customer.name) > 0
      assert is_binary(customer.email) and String.contains?(customer.email, "@")
      assert customer.status in [:active, :inactive, :suspended]
      assert Decimal.gt?(customer.credit_limit, Decimal.new("0"))
    end
  end

  describe "product data generation" do
    setup do
      DataGenerator.generate_foundation_data()
      :ok
    end
    
    test "creates products with valid category references" do
      assert :ok = DataGenerator.generate_product_data()
      
      {:ok, products} = Product.read(domain: Domain)
      {:ok, categories} = ProductCategory.read(domain: Domain)
      
      assert length(products) > 0
      
      # Verify all products have valid category_id references
      category_ids = MapSet.new(categories, & &1.id)
      
      invalid_products = Enum.filter(products, fn product ->
        not MapSet.member?(category_ids, product.category_id)
      end)
      
      assert Enum.empty?(invalid_products), "Found products with invalid category_id"
    end
    
    test "creates inventory for all products" do
      assert :ok = DataGenerator.generate_product_data()
      
      {:ok, products} = Product.read(domain: Domain)
      {:ok, inventory} = Inventory.read(domain: Domain)
      
      # Should have inventory record for each product
      product_ids = MapSet.new(products, & &1.id)
      inventory_product_ids = MapSet.new(inventory, & &1.product_id)
      
      assert MapSet.subset?(product_ids, inventory_product_ids)
    end
    
    test "generates realistic product pricing" do
      assert :ok = DataGenerator.generate_product_data()
      
      {:ok, products} = Product.read(domain: Domain)
      
      product = List.first(products)
      
      # Verify pricing makes sense (price > cost)
      assert Decimal.gt?(product.price, product.cost)
      assert Decimal.gt?(product.cost, Decimal.new("0"))
      assert is_binary(product.sku) and String.length(product.sku) > 0
    end
  end

  describe "invoice data generation" do
    setup do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data()
      DataGenerator.generate_product_data()
      :ok
    end
    
    test "creates invoices with valid customer references" do
      assert :ok = DataGenerator.generate_invoice_data()
      
      {:ok, invoices} = Invoice.read(domain: Domain)
      {:ok, customers} = Customer.read(domain: Domain)
      
      assert length(invoices) > 0
      
      # Verify all invoices have valid customer_id references
      customer_ids = MapSet.new(customers, & &1.id)
      
      invalid_invoices = Enum.filter(invoices, fn invoice ->
        not MapSet.member?(customer_ids, invoice.customer_id)
      end)
      
      assert Enum.empty?(invalid_invoices), "Found invoices with invalid customer_id"
    end
    
    test "creates line items with valid invoice and product references" do
      assert :ok = DataGenerator.generate_invoice_data()
      
      {:ok, line_items} = InvoiceLineItem.read(domain: Domain)
      {:ok, invoices} = Invoice.read(domain: Domain)
      {:ok, products} = Product.read(domain: Domain)
      
      assert length(line_items) > 0
      
      # Verify all line items have valid references
      invoice_ids = MapSet.new(invoices, & &1.id)
      product_ids = MapSet.new(products, & &1.id)
      
      invalid_line_items = Enum.filter(line_items, fn line_item ->
        not MapSet.member?(invoice_ids, line_item.invoice_id) or
        not MapSet.member?(product_ids, line_item.product_id)
      end)
      
      assert Enum.empty?(invalid_line_items), "Found line items with invalid references"
    end
    
    test "calculates invoice totals correctly" do
      assert :ok = DataGenerator.generate_invoice_data()
      
      {:ok, invoices} = Invoice.read(domain: Domain)
      
      invoice = Enum.find(invoices, fn inv -> 
        not is_nil(inv.subtotal) and Decimal.gt?(inv.subtotal, Decimal.new("0"))
      end)
      
      assert invoice, "Should have at least one invoice with calculated totals"
      
      # Verify total = subtotal + tax
      calculated_total = Decimal.add(invoice.subtotal, invoice.tax_amount)
      assert Decimal.equal?(calculated_total, invoice.total)
    end
  end

  describe "full data generation workflow" do
    test "small volume generates expected data counts" do
      assert :ok = DataGenerator.generate_sample_data(:small)
      
      # Verify data was created according to small volume specs
      {:ok, customers} = Customer.read(domain: Domain)
      {:ok, products} = Product.read(domain: Domain)
      {:ok, invoices} = Invoice.read(domain: Domain)
      
      # Small volume specs: 25 customers, 100 products, 75 invoices
      assert length(customers) <= 25
      assert length(products) <= 100  
      assert length(invoices) <= 75
      
      # Should have some data
      assert length(customers) > 0
      assert length(products) > 0
      assert length(invoices) > 0
    end
    
    test "validates referential integrity after generation" do
      assert :ok = DataGenerator.generate_sample_data(:small)
      
      # Should pass integrity validation
      assert {:ok, stats} = DataGenerator.validate_data_integrity()
      
      # Verify stats make sense
      assert stats.customers > 0
      assert stats.products > 0
      assert stats.invoices > 0
      assert stats.customer_types == 4
      assert stats.product_categories == 5
    end
    
    test "handles generation errors gracefully" do
      # Simulate an error condition by manually breaking data
      DataGenerator.generate_foundation_data()
      
      # Delete customer types to cause referential integrity failures
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      Enum.each(customer_types, fn ct -> 
        CustomerType.destroy!(ct, domain: Domain)
      end)
      
      # Now customer generation should fail
      assert {:error, reason} = DataGenerator.generate_customer_data()
      assert String.contains?(reason, "customer types")
    end
  end

  describe "data validation and integrity" do
    test "validate_data_integrity detects missing foundation data" do
      # Should fail with no data
      assert {:error, reason} = DataGenerator.validate_data_integrity()
      assert String.contains?(reason, "customer types")
    end
    
    test "validate_data_integrity passes with complete data" do
      DataGenerator.generate_sample_data(:small)
      
      assert {:ok, stats} = DataGenerator.validate_data_integrity()
      assert stats.customer_types >= 4
      assert stats.product_categories >= 5
    end
  end

  describe "transaction management" do
    test "cleans up on generation failure" do
      # Start generation then simulate failure by stopping required services
      DataGenerator.generate_foundation_data()
      
      # This should trigger rollback
      assert {:error, _reason} = DataGenerator.generate_sample_data(:invalid_volume)
      
      # Data should be cleared
      {:ok, customer_types} = CustomerType.read(domain: Domain)
      assert Enum.empty?(customer_types)
    end
  end

  describe "data statistics" do
    test "reports accurate statistics after generation" do
      DataGenerator.generate_sample_data(:small)
      
      stats = DataGenerator.data_stats()
      
      assert stats.last_generated
      assert stats.current_volume == :small
      assert not stats.generation_in_progress
      assert :small in stats.available_volumes
    end
  end

  describe "concurrent generation prevention" do
    test "prevents concurrent generation attempts" do
      # Start a generation in the background
      task = Task.async(fn ->
        DataGenerator.generate_sample_data(:medium)
      end)
      
      # Give it a moment to start
      :timer.sleep(10)
      
      # Try to start another generation
      assert {:error, reason} = DataGenerator.generate_sample_data(:small)
      assert String.contains?(reason, "in progress")
      
      # Wait for first generation to complete
      Task.await(task, 30_000)
    end
  end
end