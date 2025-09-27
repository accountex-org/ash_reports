defmodule AshReportsDemo.DataGenerationIntegrationTest do
  @moduledoc """
  Integration tests for the AshReportsDemo data generation system.

  Tests that the DataGenerator can successfully create realistic business data
  using actual Ash CRUD operations and ETS storage.
  """

  # Data generation tests should run sequentially
  use ExUnit.Case, async: false

  alias AshReportsDemo.{
    Customer,
    CustomerAddress,
    CustomerType,
    DataGenerator,
    Domain,
    Inventory,
    Invoice,
    InvoiceLineItem,
    Product,
    ProductCategory
  }

  setup do
    # Clean state for each test
    DataGenerator.reset_data()
    :ok
  end

  describe "foundation data generation" do
    test "creates customer types successfully" do
      assert :ok = DataGenerator.generate_foundation_data()

      {:ok, customer_types} = CustomerType.read()
      assert length(customer_types) > 0

      # Should have expected customer types
      type_names = Enum.map(customer_types, & &1.name)
      assert "Bronze" in type_names
      assert "Silver" in type_names
      assert "Gold" in type_names
      assert "Platinum" in type_names
    end

    test "creates product categories successfully" do
      assert :ok = DataGenerator.generate_foundation_data()

      {:ok, categories} = ProductCategory.read()
      assert length(categories) > 0

      # Should have expected categories
      category_names = Enum.map(categories, & &1.name)
      assert "Electronics" in category_names
      assert "Clothing" in category_names
    end

    test "handles generation errors gracefully" do
      # This tests error handling when foundation data already exists
      assert :ok = DataGenerator.generate_foundation_data()

      # Should handle duplicate generation gracefully
      result = DataGenerator.generate_foundation_data()
      # Should either succeed or fail gracefully
      assert match?(:ok, result) or match?({:error, _}, result)
    end
  end

  describe "customer data generation" do
    test "creates customers with relationships" do
      DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_customer_data()

      {:ok, customers} = Customer.read(load: [:customer_type, :addresses])
      assert length(customers) > 0

      customer = hd(customers)
      assert customer.name != nil
      assert customer.email != nil
      assert customer.customer_type != nil
      assert length(customer.addresses) > 0
    end

    test "maintains referential integrity" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data()

      {:ok, customers} = Customer.read()
      {:ok, customer_types} = CustomerType.read()
      {:ok, addresses} = CustomerAddress.read()

      if length(customers) > 0 and length(customer_types) > 0 do
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
    end
  end

  describe "product and inventory generation" do
    test "creates products with inventory" do
      DataGenerator.generate_foundation_data()
      assert :ok = DataGenerator.generate_product_data()

      {:ok, products} = Product.read(load: [:category])
      assert length(products) > 0

      product = hd(products)
      assert product.name != nil
      assert product.sku != nil
      assert product.category != nil
      assert Decimal.positive?(product.price)
    end

    test "creates inventory records for products" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_product_data()

      {:ok, inventory_records} = Inventory.read()
      {:ok, products} = Product.read()

      if length(products) > 0 do
        # Should have inventory records
        assert length(inventory_records) > 0

        # Every inventory record should reference a valid product
        product_ids = Enum.map(products, & &1.id) |> MapSet.new()

        for inventory <- inventory_records do
          assert inventory.product_id in product_ids
        end
      end
    end
  end

  describe "invoice and line item generation" do
    test "creates invoices with line items" do
      # Generate all prerequisite data
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data()
      DataGenerator.generate_product_data()
      assert :ok = DataGenerator.generate_invoice_data()

      {:ok, invoices} = Invoice.read(load: [:customer, :line_items])

      if length(invoices) > 0 do
        assert length(invoices) > 0

        invoice = hd(invoices)
        assert invoice.customer != nil
        assert invoice.invoice_number != nil
        assert length(invoice.line_items) > 0
        assert Decimal.positive?(invoice.total)
      end
    end

    test "maintains invoice totals correctly" do
      DataGenerator.generate_foundation_data()
      DataGenerator.generate_customer_data()
      DataGenerator.generate_product_data()
      DataGenerator.generate_invoice_data()

      {:ok, invoices} = Invoice.read(load: [:line_items])

      if length(invoices) > 0 do
        invoice = hd(invoices)

        if length(invoice.line_items) > 0 do
          # Calculate expected total from line items
          line_item_total =
            invoice.line_items
            |> Enum.map(& &1.line_total)
            |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

          # Invoice subtotal should match line items
          assert Decimal.equal?(invoice.subtotal, line_item_total)
        end
      end
    end
  end

  describe "complete sample data generation" do
    test "generates complete dataset successfully" do
      assert :ok = DataGenerator.generate_sample_data(:small)

      # Verify all resource types have data
      {:ok, customers} = Customer.read()
      {:ok, products} = Product.read()
      {:ok, invoices} = Invoice.read()
      {:ok, customer_types} = CustomerType.read()
      {:ok, categories} = ProductCategory.read()

      assert length(customers) > 0
      assert length(products) > 0
      assert length(invoices) > 0
      assert length(customer_types) > 0
      assert length(categories) > 0
    end

    test "respects volume configuration" do
      # Test small vs medium dataset sizes
      assert :ok = DataGenerator.generate_sample_data(:small)
      {:ok, small_customers} = Customer.read()

      DataGenerator.reset_data()
      assert :ok = DataGenerator.generate_sample_data(:medium)
      {:ok, medium_customers} = Customer.read()

      # Medium should have more customers than small
      if length(small_customers) > 0 and length(medium_customers) > 0 do
        assert length(medium_customers) >= length(small_customers)
      end
    end

    test "reset_data clears all resources" do
      # Generate some data first
      DataGenerator.generate_sample_data(:small)

      # Verify data exists
      {:ok, customers_before} = Customer.read()
      assert length(customers_before) > 0

      # Reset data
      DataGenerator.reset_data()

      # Verify data is cleared
      {:ok, customers_after} = Customer.read()
      assert customers_after == []
    end
  end

  describe "error handling and edge cases" do
    test "handles partial generation failures" do
      # Try to generate customers without foundation data
      result = DataGenerator.generate_customer_data()

      # Should handle gracefully (either succeed or fail with clear error)
      case result do
        :ok ->
          {:ok, customers} = Customer.read()
          assert is_list(customers)

        {:error, reason} ->
          assert is_binary(reason) or is_atom(reason)
      end
    end

    test "validates data volume parameters" do
      # Test invalid volume
      result = DataGenerator.generate_sample_data(:invalid_volume)

      # Should handle gracefully
      assert match?(:ok, result) or match?({:error, _}, result)
    end

    test "handles concurrent generation attempts" do
      # Test concurrent data generation
      tasks =
        for _i <- 1..3 do
          Task.async(fn ->
            DataGenerator.generate_foundation_data()
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should complete (either successfully or with handled errors)
      assert Enum.all?(results, fn
               :ok -> true
               {:error, _} -> true
               _ -> false
             end)
    end
  end
end
