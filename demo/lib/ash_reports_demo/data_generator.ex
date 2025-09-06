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
    small: %{
      customer_types: 4,
      product_categories: 5, 
      customers: 25,
      products: 100,
      invoices: 75,
      addresses_per_customer: 1..2,
      line_items_per_invoice: 1..5
    },
    medium: %{
      customer_types: 4,
      product_categories: 5,
      customers: 100,
      products: 500,
      invoices: 300,
      addresses_per_customer: 1..3,
      line_items_per_invoice: 2..8
    },
    large: %{
      customer_types: 4,
      product_categories: 5,
      customers: 1000,
      products: 2000,
      invoices: 5000,
      addresses_per_customer: 1..4,
      line_items_per_invoice: 1..12
    }
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

  @doc """
  Generate foundation data (customer types and product categories).
  """
  @spec generate_foundation_data() :: :ok | {:error, String.t()}
  def generate_foundation_data do
    GenServer.call(__MODULE__, :generate_foundation_data, 10_000)
  end

  @doc """
  Generate customer data.
  """
  @spec generate_customer_data() :: :ok | {:error, String.t()}
  def generate_customer_data do
    GenServer.call(__MODULE__, :generate_customer_data, 15_000)
  end

  @doc """
  Generate product data.
  """
  @spec generate_product_data() :: :ok | {:error, String.t()}
  def generate_product_data do
    GenServer.call(__MODULE__, :generate_product_data, 15_000)
  end

  @doc """
  Generate invoice data.
  """
  @spec generate_invoice_data() :: :ok | {:error, String.t()}
  def generate_invoice_data do
    GenServer.call(__MODULE__, :generate_invoice_data, 20_000)
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

  @impl true
  def handle_call(:generate_foundation_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      # Use a small volume config just for foundation data
      volume_config = @data_volumes.small
      case generate_foundation_data(volume_config) do
        :ok ->
          Logger.info("Foundation data generated successfully")
          {:reply, :ok, state}
        {:error, reason} ->
          Logger.error("Foundation data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:generate_customer_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      volume_config = @data_volumes.small
      case generate_customer_data(volume_config) do
        :ok ->
          Logger.info("Customer data generated successfully")
          {:reply, :ok, state}
        {:error, reason} ->
          Logger.error("Customer data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:generate_product_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      volume_config = @data_volumes.small
      case generate_product_data(volume_config) do
        :ok ->
          Logger.info("Product data generated successfully")
          {:reply, :ok, state}
        {:error, reason} ->
          Logger.error("Product data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:generate_invoice_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      volume_config = @data_volumes.small
      case generate_invoice_data(volume_config) do
        :ok ->
          Logger.info("Invoice data generated successfully")
          {:reply, :ok, state}
        {:error, reason} ->
          Logger.error("Invoice data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
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

  defp generate_foundation_data(_volume_config) do
    Logger.info("Generating foundation data (customer types and product categories)")

    with {:ok, customer_types} <- create_customer_types(),
         {:ok, product_categories} <- create_product_categories() do
      Logger.info("Generated foundation data: #{length(customer_types)} customer types, #{length(product_categories)} product categories")
      :ok
    else
      {:error, reason} -> {:error, "Foundation data generation failed: #{reason}"}
    end
  end

  defp create_customer_types do
    customer_type_specs = [
      %{name: "Bronze", description: "Basic customer tier", 
        discount_percentage: Decimal.new("0"), active: true, priority_level: 1},
      %{name: "Silver", description: "Standard customer tier", 
        discount_percentage: Decimal.new("5"), active: true, priority_level: 2},
      %{name: "Gold", description: "Premium customer tier", 
        discount_percentage: Decimal.new("10"), active: true, priority_level: 3},
      %{name: "Platinum", description: "Elite customer tier", 
        discount_percentage: Decimal.new("15"), active: true, priority_level: 4}
    ]

    results = for type_spec <- customer_type_specs do
      # Check if customer type already exists
      case CustomerType.read() do
        {:ok, types} ->
          existing = Enum.find(types, &(&1.name == type_spec.name))
          
          if existing do
            Logger.debug("Customer type '#{type_spec.name}' already exists")
            existing
          else
            # Create new customer type
            case CustomerType.create(type_spec) do
              {:ok, customer_type} ->
                Logger.debug("Created customer type: #{customer_type.name}")
                customer_type
              {:error, error} ->
                Logger.error("Failed to create customer type #{type_spec.name}: #{inspect(error)}")
                nil
            end
          end
          
        {:error, error} ->
          Logger.error("Failed to query customer types: #{inspect(error)}")
          nil
      end
    end

    valid_types = Enum.reject(results, &is_nil/1)
    
    if length(valid_types) >= 4 do
      {:ok, valid_types}
    else
      {:error, "Failed to ensure all customer types exist"}
    end
  end

  defp create_product_categories do
    category_specs = [
      %{name: "Electronics", description: "Electronic devices and accessories", sort_order: 1, active: true},
      %{name: "Clothing", description: "Apparel and accessories", sort_order: 2, active: true},
      %{name: "Home & Garden", description: "Home improvement and gardening", sort_order: 3, active: true},
      %{name: "Books", description: "Books and educational materials", sort_order: 4, active: true},
      %{name: "Sports", description: "Sports and outdoor equipment", sort_order: 5, active: true}
    ]

    results = for category_spec <- category_specs do
      # Check if category already exists
      case ProductCategory.read() do
        {:ok, categories} ->
          existing = Enum.find(categories, &(&1.name == category_spec.name))
          
          if existing do
            Logger.debug("Product category '#{category_spec.name}' already exists")
            existing
          else
            # Create new product category
            case ProductCategory.create(category_spec) do
              {:ok, category} ->
                Logger.debug("Created product category: #{category.name}")
                category
              {:error, error} ->
                Logger.error("Failed to create category #{category_spec.name}: #{inspect(error)}")
                nil
            end
          end
          
        {:error, error} ->
          Logger.error("Failed to query product categories: #{inspect(error)}")
          nil
      end
    end

    valid_categories = Enum.reject(results, &is_nil/1)
    
    if length(valid_categories) >= 5 do
      {:ok, valid_categories}
    else
      {:error, "Failed to ensure all product categories exist"}
    end
  end

  defp generate_customer_data(volume_config) do
    customer_count = volume_config.customers
    address_range = volume_config.addresses_per_customer
    Logger.info("Generating #{customer_count} customers with addresses")

    with {:ok, customer_types} <- get_available_customer_types(),
         {:ok, customers} <- create_customers_batch(customer_types, customer_count),
         {:ok, _addresses} <- create_addresses_for_customers(customers, address_range) do
      Logger.info("Generated #{length(customers)} customers with addresses")
      :ok
    else
      {:error, reason} -> {:error, "Customer data generation failed: #{reason}"}
    end
  end

  defp generate_product_data(volume_config) do
    product_count = volume_config.products
    Logger.info("Generating #{product_count} products with inventory")

    with {:ok, categories} <- get_available_product_categories(),
         {:ok, products} <- create_products_batch(categories, product_count),
         {:ok, _inventory} <- create_inventory_for_products(products) do
      Logger.info("Generated #{length(products)} products with inventory")
      :ok
    else
      {:error, reason} -> {:error, "Product data generation failed: #{reason}"}
    end
  end

  defp get_available_customer_types do
    case CustomerType.read() do
      {:ok, []} -> {:error, "No customer types available - run foundation data first"}
      {:ok, customer_types} -> {:ok, customer_types}
      {:error, error} -> {:error, "Failed to load customer types: #{inspect(error)}"}
    end
  end

  defp get_available_product_categories do
    case ProductCategory.read() do
      {:ok, []} -> {:error, "No product categories available - run foundation data first"}
      {:ok, categories} -> {:ok, categories}
      {:error, error} -> {:error, "Failed to load product categories: #{inspect(error)}"}
    end
  end

  defp create_products_batch(categories, product_count) do
    products = for i <- 1..product_count do
      category = Enum.random(categories)
      
      # Generate realistic pricing with proper margins
      cost = Decimal.new("#{:rand.uniform(500) + 10}")  # $10-$510
      margin_multiplier = 1.2 + (:rand.uniform(100) / 100)  # 1.2x to 2.2x markup
      price = Decimal.mult(cost, Decimal.new("#{margin_multiplier}"))

      product_attrs = %{
        name: Faker.Commerce.product_name(),
        sku: generate_unique_sku(i),
        description: Faker.Lorem.sentence(10),
        price: price,
        cost: cost,
        weight: Decimal.new("#{:rand.uniform(100) / 10}"),  # 0.1 to 10.0 lbs
        category_id: category.id,
        active: Enum.random([true, true, true, false])  # 75% active
      }

      case Product.create(product_attrs) do
        {:ok, product} -> product
        {:error, error} ->
          Logger.error("Failed to create product #{i}: #{inspect(error)}")
          nil
      end
    end

    valid_products = Enum.reject(products, &is_nil/1)
    
    if length(valid_products) > 0 do
      {:ok, valid_products}
    else
      {:error, "Failed to create any products"}
    end
  end

  defp create_inventory_for_products(products) do
    inventory_records = for product <- products do
      current_stock = :rand.uniform(1000)
      # Ensure reserved_stock never exceeds current_stock
      reserved_stock = :rand.uniform(min(50, current_stock))
      
      inventory_attrs = %{
        product_id: product.id,
        current_stock: current_stock,
        reserved_stock: reserved_stock,
        reorder_point: 10 + :rand.uniform(40),  # 10-50
        reorder_quantity: 50 + :rand.uniform(200),  # 50-250
        location: Enum.random(["Main Warehouse", "East Coast", "West Coast", "Central"]),
        last_received_date: Faker.Date.backward(:rand.uniform(90)),  # Within last 90 days
        last_received_quantity: 25 + :rand.uniform(200)
      }

      case Inventory.create(inventory_attrs) do
        {:ok, inventory} -> inventory
        {:error, error} ->
          Logger.error("Failed to create inventory for product #{product.id}: #{inspect(error)}")
          nil
      end
    end

    valid_inventory = Enum.reject(inventory_records, &is_nil/1)
    {:ok, valid_inventory}
  end

  defp generate_invoice_data(volume_config) do
    invoice_count = volume_config.invoices
    Logger.info("Generating #{invoice_count} invoices with line items")

    # Get available customers and products
    customers = Customer.read!()
    products = Product.read!()

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

        invoice = Invoice.create!(invoice_attrs)

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

          InvoiceLineItem.create!(line_item_attrs)
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

  # Helper functions for enhanced data generation

  defp create_customers_batch(customer_types, customer_count) do
    customers = for i <- 1..customer_count do
      customer_type = Enum.random(customer_types)
      
      customer_attrs = %{
        name: Faker.Person.name(),
        email: generate_unique_email(i),
        phone: Faker.Phone.EnUs.phone(),
        status: weighted_random_status(),
        credit_limit: generate_realistic_credit_limit(customer_type),
        notes: if(:rand.uniform(3) == 1, do: Faker.Lorem.sentence(), else: ""),
        customer_type_id: customer_type.id
      }

      case Customer.create(customer_attrs) do
        {:ok, customer} ->
          customer
        {:error, error} ->
          Logger.error("Failed to create customer #{i}: #{inspect(error)}")
          nil
      end
    end

    valid_customers = Enum.reject(customers, &is_nil/1)
    
    if length(valid_customers) > 0 do
      {:ok, valid_customers}
    else
      {:error, "Failed to create any customers"}
    end
  end

  defp create_addresses_for_customers(customers, address_range) do
    all_addresses = for customer <- customers do
      address_count = Enum.random(address_range)
      
      for i <- 1..address_count do
        address_attrs = %{
          customer_id: customer.id,
          address_type: determine_address_type(i),
          street: Faker.Address.street_address(),
          city: Faker.Address.city(),
          state: Faker.Address.state(),
          postal_code: Faker.Address.zip_code(),
          country: "United States",
          primary: i == 1
        }

        case CustomerAddress.create(address_attrs) do
          {:ok, address} -> address
          {:error, error} ->
            Logger.error("Failed to create address for customer #{customer.id}: #{inspect(error)}")
            nil
        end
      end
    end

    valid_addresses = all_addresses |> List.flatten() |> Enum.reject(&is_nil/1)
    {:ok, valid_addresses}
  end

  # Helper functions for realistic data generation
  defp generate_unique_email(index) do
    base_email = Faker.Internet.email()
    "demo#{index}.#{base_email}"
  end

  defp weighted_random_status do
    # 70% active, 20% inactive, 10% suspended
    case :rand.uniform(10) do
      n when n <= 7 -> :active
      n when n <= 9 -> :inactive
      _ -> :suspended
    end
  end

  defp generate_realistic_credit_limit(customer_type) do
    base_amount = Decimal.new("5000")
    # Use priority_level to determine multiplier (higher priority = higher credit limit)
    multiplier = Decimal.new("#{customer_type.priority_level}")
    variation = Decimal.new("#{:rand.uniform(50) * 100}")  # $0-$5000 variation
    
    base_amount
    |> Decimal.mult(multiplier)
    |> Decimal.add(variation)
  end

  defp determine_address_type(1), do: :billing
  defp determine_address_type(_), do: Enum.random([:shipping, :mailing])

  defp generate_unique_sku(index) do
    "SKU-#{String.pad_leading(Integer.to_string(index), 6, "0")}-#{:rand.uniform(999)}"
  end
end
