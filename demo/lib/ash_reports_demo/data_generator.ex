defmodule AshReportsDemo.DataGenerator do
  @moduledoc """
  GenServer that generates realistic test data using Faker library.

  Provides seeding functions for all demo resources with proper
  relationship integrity and configurable data volumes.
  """

  use GenServer

  require Logger

  alias AshReportsDemo.{Customer, CustomerAddress, CustomerType, Product, ProductCategory, Inventory, Invoice, InvoiceLineItem}

  @data_volumes %{
    small: %{customers: 10, products: 50, invoices: 25},
    medium: %{customers: 100, products: 200, invoices: 500},
    large: %{customers: 1000, products: 2000, invoices: 10_000}
  }

  # Public API

  @doc """
  Start the data generator GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate sample data with specified volume.
  """
  @spec generate_sample_data(atom()) :: :ok | {:error, String.t()}
  def generate_sample_data(volume \\ :medium) do
    GenServer.call(__MODULE__, {:generate_data, volume}, 30_000)
  end

  @doc """
  Reset all data to clean state.
  """
  @spec reset_data() :: :ok
  def reset_data do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  Get current data statistics.
  """
  @spec data_stats() :: map()
  def data_stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    # Initialize with clean state
    state = %{
      generation_in_progress: false,
      last_generated: nil,
      current_volume: nil
    }

    Logger.info("AshReportsDemo DataGenerator started")
    {:ok, state}
  end

  @impl true
  def handle_call({:generate_data, volume}, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      case generate_data_internal(volume) do
        :ok ->
          updated_state = %{
            state
            | generation_in_progress: false,
              last_generated: DateTime.utc_now(),
              current_volume: volume
          }

          Logger.info("Generated #{volume} dataset successfully")
          {:reply, :ok, updated_state}

        {:error, reason} ->
          updated_state = %{state | generation_in_progress: false}
          Logger.error("Data generation failed: #{reason}")
          {:reply, {:error, reason}, updated_state}
      end
    end
  end

  @impl true
  def handle_call(:reset, _from, state) do
    case reset_data_internal() do
      :ok ->
        updated_state = %{state | last_generated: nil, current_volume: nil}

        Logger.info("Data reset successfully")
        {:reply, :ok, updated_state}

      {:error, reason} ->
        Logger.error("Data reset failed: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      last_generated: state.last_generated,
      current_volume: state.current_volume,
      generation_in_progress: state.generation_in_progress,
      available_volumes: Map.keys(@data_volumes)
    }

    {:reply, stats, state}
  end

  # Private implementation

  defp generate_data_internal(volume) do
    volume_config = Map.get(@data_volumes, volume)

    if volume_config do
      Logger.info("Starting data generation for #{volume} volume: #{inspect(volume_config)}")

      # Clear existing data first
      :ok = AshReportsDemo.EtsDataLayer.clear_all_data()

      # Generate data in dependency order
      with :ok <- generate_foundation_data(volume_config),
           :ok <- generate_customer_data(volume_config),
           :ok <- generate_product_data(volume_config),
           :ok <- generate_invoice_data(volume_config) do
        Logger.info("Successfully generated #{volume} dataset")
        :ok
      else
        {:error, reason} ->
          Logger.error("Data generation failed at stage: #{reason}")
          {:error, reason}
      end
    else
      {:error,
       "Unknown volume: #{volume}. Available: #{Map.keys(@data_volumes) |> Enum.join(", ")}"}
    end
  rescue
    error ->
      {:error, Exception.message(error)}
  end

  # Phase 7.3: Data Generation Functions

  defp generate_foundation_data(volume_config) do
    # Generate foundation data (CustomerTypes and ProductCategories)
    customer_types = [
      %{name: "Premium", description: "High-value customers", discount_percentage: Decimal.new("10.00"), priority_level: 5},
      %{name: "Standard", description: "Regular customers", discount_percentage: Decimal.new("5.00"), priority_level: 3},
      %{name: "Basic", description: "New customers", discount_percentage: Decimal.new("0.00"), priority_level: 1}
    ]

    product_categories = [
      %{name: "Electronics", description: "Electronic devices and accessories", sort_order: 1},
      %{name: "Clothing", description: "Apparel and accessories", sort_order: 2},
      %{name: "Home & Garden", description: "Home improvement and gardening", sort_order: 3},
      %{name: "Books", description: "Books and educational materials", sort_order: 4},
      %{name: "Sports", description: "Sports and outdoor equipment", sort_order: 5}
    ]

    # Create customer types
    Enum.each(customer_types, fn type_attrs ->
      CustomerType.create!(type_attrs)
    end)

    # Create product categories
    Enum.each(product_categories, fn category_attrs ->
      ProductCategory.create!(category_attrs)
    end)

    Logger.info("Generated foundation data: #{length(customer_types)} customer types, #{length(product_categories)} product categories")
    :ok
  rescue
    error ->
      {:error, "Foundation data generation failed: #{Exception.message(error)}"}
  end

  defp generate_customer_data(volume_config) do
    customer_count = volume_config.customers
    Logger.info("Generating #{customer_count} customers with addresses")

    # Get available customer types
    customer_types = CustomerType.read!()

    # Generate customers
    customers = for _i <- 1..customer_count do
      customer_type = Enum.random(customer_types)
      
      customer_attrs = %{
        name: Faker.Person.name(),
        email: Faker.Internet.email(),
        phone: Faker.Phone.EnUs.phone(),
        status: Enum.random([:active, :active, :active, :inactive]),  # 75% active
        credit_limit: Decimal.new("#{:rand.uniform(50) * 1000}"),
        notes: Faker.Lorem.sentence(),
        customer_type_id: customer_type.id
      }

      customer = Customer.create!(customer_attrs)

      # Generate 1-3 addresses per customer
      address_count = :rand.uniform(3)
      
      for i <- 1..address_count do
        address_attrs = %{
          customer_id: customer.id,
          address_type: if(i == 1, do: :billing, else: Enum.random([:shipping, :mailing])),
          street: Faker.Address.street_address(),
          city: Faker.Address.city(),
          state: Faker.Address.state(),
          postal_code: Faker.Address.zip_code(),
          country: "United States",
          primary: i == 1  # First address is primary
        }

        CustomerAddress.create!(address_attrs)
      end

      customer
    end

    Logger.info("Generated #{length(customers)} customers with addresses")
    :ok
  rescue
    error ->
      {:error, "Customer data generation failed: #{Exception.message(error)}"}
  end

  defp generate_product_data(volume_config) do
    product_count = volume_config.products
    Logger.info("Generating #{product_count} products with inventory")

    # Get available product categories
    categories = ProductCategory.read!()

    # Generate products
    products = for _i <- 1..product_count do
      category = Enum.random(categories)
      
      # Generate realistic pricing with proper margins
      cost = Decimal.new("#{:rand.uniform(500) + 10}")  # $10-$510
      margin_multiplier = 1.2 + (:rand.uniform(100) / 100)  # 1.2x to 2.2x markup
      price = Decimal.mult(cost, Decimal.new("#{margin_multiplier}"))

      product_attrs = %{
        name: Faker.Commerce.product_name(),
        sku: "SKU-#{:rand.uniform(999999) |> Integer.to_string() |> String.pad_leading(6, "0")}",
        description: Faker.Lorem.sentence(10),
        price: price,
        cost: cost,
        weight: Decimal.new("#{:rand.uniform(100) / 10}"),  # 0.1 to 10.0 lbs
        category_id: category.id,
        active: Enum.random([true, true, true, false])  # 75% active
      }

      product = AshReportsDemo.Product.create!(product_attrs)

      # Generate inventory for each product
      inventory_attrs = %{
        product_id: product.id,
        current_stock: :rand.uniform(1000),
        reserved_stock: :rand.uniform(50),
        reorder_point: 10 + :rand.uniform(40),  # 10-50
        reorder_quantity: 50 + :rand.uniform(200),  # 50-250
        location: Enum.random(["Main Warehouse", "East Coast", "West Coast", "Central"]),
        last_received_date: Faker.Date.backward(:rand.uniform(90)),  # Within last 90 days
        last_received_quantity: 25 + :rand.uniform(200)
      }

      AshReportsDemo.Inventory.create!(inventory_attrs)

      product
    end

    Logger.info("Generated #{length(products)} products with inventory")
    :ok
  rescue
    error ->
      {:error, "Product data generation failed: #{Exception.message(error)}"}
  end

  defp generate_invoice_data(volume_config) do
    invoice_count = volume_config.invoices
    Logger.info("Generating #{invoice_count} invoices with line items")

    # Get available customers and products
    customers = Customer.read!()
    products = AshReportsDemo.Product.read!()

    if Enum.empty?(customers) or Enum.empty?(products) do
      {:error, "Cannot generate invoices without customers and products"}
    else
      # Generate invoices
      for i <- 1..invoice_count do
        customer = Enum.random(customers)
        
        invoice_date = Faker.Date.backward(:rand.uniform(365))  # Within last year
        due_date = Date.add(invoice_date, 30)  # 30 days payment terms

        invoice_attrs = %{
          customer_id: customer.id,
          invoice_number: "INV-#{Date.to_string(invoice_date) |> String.replace("-", "")}-#{String.pad_leading(Integer.to_string(i), 4, "0")}",
          date: invoice_date,
          due_date: due_date,
          status: Enum.random([:draft, :sent, :sent, :paid, :overdue]),  # Mixed statuses
          tax_rate: Decimal.new("8.25"),
          payment_terms: Enum.random(["Net 30", "Net 15", "Due on Receipt", "Net 45"]),
          notes: if(:rand.uniform(3) == 1, do: Faker.Lorem.sentence(), else: "")
        }

        invoice = AshReportsDemo.Invoice.create!(invoice_attrs)

        # Generate 1-10 line items per invoice
        line_item_count = 1 + :rand.uniform(9)
        subtotal = Decimal.new("0.00")

        for _j <- 1..line_item_count do
          product = Enum.random(products)
          quantity = Decimal.new("#{1 + :rand.uniform(20)}")  # 1-20 units
          
          # Use product price with potential discount
          unit_price = if :rand.uniform(4) == 1 do
            # 25% chance of discount
            discount = Decimal.mult(product.price, Decimal.new("#{:rand.uniform(20) / 100}"))
            Decimal.sub(product.price, discount)
          else
            product.price
          end

          line_total = Decimal.mult(quantity, unit_price)
          subtotal = Decimal.add(subtotal, line_total)

          line_item_attrs = %{
            invoice_id: invoice.id,
            product_id: product.id,
            quantity: quantity,
            unit_price: unit_price,
            line_total: line_total,
            description: if(:rand.uniform(3) == 1, do: Faker.Lorem.sentence(5), else: "")
          }

          AshReportsDemo.InvoiceLineItem.create!(line_item_attrs)
        end

        # Update invoice totals
        tax_amount = Decimal.mult(subtotal, Decimal.div(invoice.tax_rate, 100))
        total = Decimal.add(subtotal, tax_amount)

        AshReportsDemo.Invoice.update!(invoice, %{
          subtotal: subtotal,
          tax_amount: tax_amount,
          total: total
        })
      end

      Logger.info("Generated #{invoice_count} invoices with line items")
      :ok
    end
  rescue
    error ->
      {:error, "Invoice data generation failed: #{Exception.message(error)}"}
  end

  defp reset_data_internal do
    # Phase 7.3: Clear all ETS data
    Logger.info("Resetting demo data")
    AshReportsDemo.EtsDataLayer.clear_all_data()
  rescue
    error ->
      {:error, Exception.message(error)}
  end
end
