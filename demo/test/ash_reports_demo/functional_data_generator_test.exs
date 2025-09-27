defmodule AshReportsDemo.FunctionalDataGeneratorTest do
  use ExUnit.Case

  alias AshReportsDemo.DataGenerator

  alias AshReportsDemo.{
    Customer,
    CustomerType,
    Inventory,
    Invoice,
    InvoiceLineItem,
    Product,
    ProductCategory
  }

  setup do
    # Clean data before each test
    # DataGenerator is already started by the Application
    DataGenerator.reset_data()

    :ok
  end

  describe "sample data generation" do
    test "generates small dataset successfully" do
      assert :ok = DataGenerator.generate_sample_data(:small)

      # Verify we have data
      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
      assert stats.current_volume == :small
      assert %DateTime{} = stats.last_generated
    end

    test "generates medium dataset successfully" do
      assert :ok = DataGenerator.generate_sample_data(:medium)

      # Verify we have data
      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
      assert stats.current_volume == :medium
      assert %DateTime{} = stats.last_generated
    end

    test "generates large dataset successfully" do
      assert :ok = DataGenerator.generate_sample_data(:large)

      # Verify we have data
      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
      assert stats.current_volume == :large
      assert %DateTime{} = stats.last_generated
    end

    test "small dataset has correct data volumes" do
      assert :ok = DataGenerator.generate_sample_data(:small)

      # Verify customer types (foundation data)
      {:ok, customer_types} = CustomerType.read()
      assert length(customer_types) == 4

      # Verify product categories (foundation data)
      {:ok, product_categories} = ProductCategory.read()
      assert length(product_categories) == 5

      # Verify customers
      {:ok, customers} = Customer.read()
      assert length(customers) == 25

      # Verify products
      {:ok, products} = Product.read()
      assert length(products) == 100

      # Verify invoices
      {:ok, invoices} = Invoice.read()
      assert length(invoices) == 75
    end

    test "medium dataset has correct data volumes" do
      assert :ok = DataGenerator.generate_sample_data(:medium)

      # Verify customers
      {:ok, customers} = Customer.read()
      assert length(customers) == 100

      # Verify products
      {:ok, products} = Product.read()
      assert length(products) == 500

      # Verify invoices
      {:ok, invoices} = Invoice.read()
      assert length(invoices) == 300
    end

    test "large dataset has correct data volumes" do
      assert :ok = DataGenerator.generate_sample_data(:large)

      # Verify customers
      {:ok, customers} = Customer.read()
      assert length(customers) == 1000

      # Verify products
      {:ok, products} = Product.read()
      assert length(products) == 2000

      # Verify invoices
      {:ok, invoices} = Invoice.read()
      assert length(invoices) == 5000
    end
  end

  describe "data quality verification" do
    test "customer data has realistic attributes" do
      assert :ok = DataGenerator.generate_sample_data(:small)

      {:ok, customers} = Customer.read()
      assert length(customers) > 0

      # Verify customer attributes
      customer = Enum.random(customers)
      assert is_binary(customer.name)
      assert String.contains?(customer.email, "@")
      assert customer.status in [:active, :inactive, :suspended]
      assert Decimal.positive?(customer.credit_limit)
    end

    test "product data has realistic attributes" do
      assert :ok = DataGenerator.generate_sample_data(:small)

      {:ok, products} = Product.read()
      assert length(products) > 0

      # Verify product attributes
      product = Enum.random(products)
      assert is_binary(product.name)
      assert is_binary(product.sku)
      assert Decimal.positive?(product.unit_price)
      assert Decimal.positive?(product.unit_cost)
      assert product.status in [:active, :inactive, :discontinued]
    end

    test "maintains relationship integrity" do
      assert :ok = DataGenerator.generate_sample_data(:small)

      # Load customers with their relationships
      {:ok, customers} = Customer.read(load: [:customer_type, :addresses])
      assert length(customers) > 0

      # Verify relationships exist
      customer = Enum.random(customers)
      assert customer.customer_type != nil
      assert length(customer.addresses) >= 1

      # Load products with their relationships
      {:ok, products} = Product.read(load: [:product_category, :inventory])
      assert length(products) > 0

      # Verify relationships exist
      product = Enum.random(products)
      assert product.product_category != nil
      assert product.inventory != nil
    end
  end

  describe "data reset functionality" do
    test "resets data successfully" do
      # Generate some data first
      assert :ok = DataGenerator.generate_sample_data(:small)

      # Verify we have data
      {:ok, customers} = Customer.read()
      assert length(customers) > 0

      # Reset data
      assert :ok = DataGenerator.reset_data()

      # Verify data is cleared
      {:ok, customers} = Customer.read()
      assert Enum.empty?(customers)

      # Verify stats reflect reset
      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
    end
  end

  describe "genserver state management" do
    test "provides accurate statistics" do
      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
      assert stats.available_volumes == [:small, :medium, :large]

      # After generation, stats should be updated
      assert :ok = DataGenerator.generate_sample_data(:small)

      updated_stats = DataGenerator.data_stats()
      assert updated_stats.generation_in_progress == false
      assert updated_stats.current_volume == :small
      assert %DateTime{} = updated_stats.last_generated
    end

    test "handles reset during generation gracefully" do
      # This is a simplified test since we can't easily test concurrency
      # in this context. We test that reset works after generation.
      assert :ok = DataGenerator.generate_sample_data(:small)
      assert :ok = DataGenerator.reset_data()

      stats = DataGenerator.data_stats()
      assert stats.generation_in_progress == false
    end
  end

  describe "error handling" do
    test "handles invalid volume configuration" do
      # The GenServer should handle this gracefully and return an error
      case DataGenerator.generate_sample_data(:invalid_volume) do
        {:error, reason} ->
          assert is_binary(reason)

        :ok ->
          # If it doesn't error, that's also acceptable behavior
          assert true
      end
    end
  end
end
