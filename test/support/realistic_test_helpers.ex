defmodule AshReports.RealisticTestHelpers do
  @moduledoc """
  Realistic test helpers using real Ash resources with ETS data layer.

  This module provides utilities for creating realistic test scenarios using actual
  Ash resources (Customer, Invoice, Product, etc.) with an in-memory ETS data layer.
  It complements the existing `AshReports.RendererTestHelpers` by providing more
  realistic test data and proper Ash resource behavior.

  ## Overview

  The helpers in this module:
  - Use real Ash resources from `test/data/resources/`
  - Generate realistic test data using `AshReports.Demo.DataGenerator`
  - Store data in ETS tables for fast, isolated testing
  - Provide convenient query helpers for common operations
  - Support multiple data scenarios (empty, small, medium, large)
  - Ensure proper cleanup after each test

  ## Quick Start

  ### Basic Usage

      use ExUnit.Case
      import AshReports.RealisticTestHelpers

      setup do
        setup_realistic_test_data()
      end

      test "rendering with real data" do
        customers = list_customers(limit: 10)
        # Use customers in your test...
      end

  ### Custom Data Scenarios

      setup do
        setup_realistic_test_data(scenario: :large)
      end

  ### Manual Setup/Cleanup

      setup do
        setup_ets_tables()
        on_exit(fn -> cleanup_ets_tables() end)
        :ok
      end

  ## Data Scenarios

  The module supports different data volume scenarios:

  - `:empty` - No data (for testing edge cases)
  - `:small` - ~10 records per resource (fast, default)
  - `:medium` - ~100 records per resource (realistic)
  - `:large` - ~1000 records per resource (stress testing)

  ## Available Resources

  The following Ash resources are available:

  - `Customer` - Customer records with addresses
  - `CustomerAddress` - Customer address records
  - `CustomerType` - Customer type classifications
  - `Invoice` - Invoice headers
  - `InvoiceLineItem` - Invoice line items
  - `Product` - Product catalog
  - `ProductCategory` - Product categories
  - `Inventory` - Inventory levels

  ## Query Helpers

  Convenient functions for common queries:

      # List records
      customers = list_customers(limit: 10)

      # Get by ID
      customer = get_customer(customer_id)

      # Filter
      active_customers = list_customers(filter: [status: :active])

      # With relationships
      customers_with_invoices = list_customers(load: [:invoices])

      # Aggregates
      stats = get_customer_stats()

  ## Integration with RendererTestHelpers

  This module works seamlessly with existing `RendererTestHelpers`:

      # Use realistic data
      customers = list_customers(limit: 5)

      # Convert to renderer context
      context = build_render_context(records: customers)

      # Use with renderer
      result = Renderer.render(context)

  ## Performance Considerations

  - **Small scenarios** (<100ms): Fast, suitable for most unit tests
  - **Medium scenarios** (<1s): Good for integration tests
  - **Large scenarios** (<5s): Use sparingly, mainly for performance tests

  ## Cleanup

  ETS tables are automatically cleaned up when using `setup_realistic_test_data/1`.
  For manual setup, ensure you call `cleanup_ets_tables/0` in your test's `on_exit` callback.

  ## Examples

      # Simple test with default data
      test "lists customers" do
        customers = list_customers()
        assert length(customers) > 0
      end

      # Test with specific scenario
      test "handles large datasets", %{scenario: :large} do
        count = count_customers()
        assert count > 500
      end

      # Test with relationships
      test "loads customer invoices" do
        customer = list_customers(limit: 1, load: [:invoices]) |> List.first()
        assert length(customer.invoices) > 0
      end
  """

  alias AshReportsDemo.{DataGenerator, Domain}
  alias AshReportsDemo.EtsDataLayer

  # Import query helpers from Ash
  import Ash.Query

  @doc """
  Sets up ETS tables and generates realistic test data.

  This is the main entry point for using realistic test helpers. It handles
  ETS table creation, data generation, and cleanup registration.

  ## Options

  - `:scenario` - Data scenario (`:empty`, `:small`, `:medium`, `:large`). Default: `:small`
  - `:resources` - List of resources to populate (default: all)

  ## Returns

  A map containing:
  - `:scenario` - The data scenario used
  - `:counts` - Record counts for each resource
  - `:ets_tables` - List of created ETS table names

  ## Examples

      setup do
        setup_realistic_test_data()
      end

      setup do
        setup_realistic_test_data(scenario: :large)
      end

      setup do
        data = setup_realistic_test_data(resources: [:customers, :invoices])
        {:ok, test_data: data}
      end
  """
  def setup_realistic_test_data(opts \\ []) do
    scenario = Keyword.get(opts, :scenario, :small)

    # Ensure ETS tables are clean
    tables = setup_ets_tables()

    # Generate test data based on scenario
    data = generate_test_data(opts)

    # Register cleanup callback
    ExUnit.Callbacks.on_exit(fn ->
      cleanup_ets_tables()
    end)

    # Return context with test data info
    %{
      scenario: scenario,
      counts: get_record_counts(),
      ets_tables: tables,
      generated_data: data
    }
  end

  @doc """
  Creates ETS tables for all resources.

  This function initializes the ETS tables needed for the Ash resources.
  Call this in your test setup if you want manual control over data generation.

  ## Returns

  List of created ETS table names.

  ## Examples

      setup do
        tables = setup_ets_tables()
        on_exit(fn -> cleanup_ets_tables() end)
        {:ok, ets_tables: tables}
      end
  """
  def setup_ets_tables do
    # Clear existing data from all tables
    EtsDataLayer.clear_all_data()

    # Return list of table names
    [
      :demo_customers,
      :demo_customer_addresses,
      :demo_customer_types,
      :demo_products,
      :demo_product_categories,
      :demo_inventory,
      :demo_invoices,
      :demo_invoice_line_items
    ]
  end

  @doc """
  Cleans up all ETS tables created by the test helpers.

  This function removes all ETS tables and clears any cached data.
  It's automatically called when using `setup_realistic_test_data/1`,
  but should be manually called in `on_exit` callbacks for custom setups.

  ## Examples

      setup do
        setup_ets_tables()
        on_exit(fn -> cleanup_ets_tables() end)
      end
  """
  def cleanup_ets_tables do
    # Clear all data from ETS tables
    EtsDataLayer.clear_all_data()
    :ok
  end

  @doc """
  Generates test data for specified resources.

  ## Options

  - `:scenario` - Data scenario (`:empty`, `:small`, `:medium`, `:large`)
  - `:resources` - List of resources to populate

  ## Returns

  Map of resource name to list of created records.

  ## Examples

      data = generate_test_data(scenario: :small)
      customers = data.customers

      data = generate_test_data(resources: [:customers], scenario: :large)
  """
  def generate_test_data(opts \\ []) do
    scenario = Keyword.get(opts, :scenario, :small)

    # Handle empty scenario
    if scenario == :empty do
      %{
        customers: [],
        invoices: [],
        products: [],
        customer_addresses: [],
        customer_types: [],
        product_categories: [],
        inventory: [],
        invoice_line_items: []
      }
    else
      # Start DataGenerator if not already running
      ensure_data_generator_started()

      # Generate data using DataGenerator
      case DataGenerator.generate_sample_data(scenario) do
        :ok ->
          # Return empty maps - actual data is in ETS
          # We could load and return it, but that would defeat the purpose of ETS
          %{
            scenario: scenario,
            status: :generated,
            message: "Data generated successfully in ETS tables"
          }

        {:error, reason} ->
          raise "Failed to generate test data: #{inspect(reason)}"
      end
    end
  end

  # Query Helpers - Phase 3

  @doc """
  Lists all customers with optional filtering and pagination.

  ## Options

  - `:limit` - Maximum number of records to return
  - `:offset` - Number of records to skip
  - `:filter` - Keyword list of filters
  - `:load` - List of relationships to load
  - `:sort` - Sort order

  ## Examples

      customers = list_customers()
      customers = list_customers(limit: 10)
      customers = list_customers(filter: [status: :active], load: [:invoices])
  """
  def list_customers(opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  @doc """
  Gets a customer by ID.

  ## Examples

      customer = get_customer(customer_id)
      customer = get_customer(customer_id, load: [:invoices, :addresses])
  """
  def get_customer(id, opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  @doc """
  Counts total customers.

  ## Examples

      count = count_customers()
      active_count = count_customers(filter: [status: :active])
  """
  def count_customers(opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  @doc """
  Lists all invoices with optional filtering and pagination.
  """
  def list_invoices(opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  @doc """
  Gets an invoice by ID.
  """
  def get_invoice(id, opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  @doc """
  Lists all products with optional filtering and pagination.
  """
  def list_products(opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  @doc """
  Gets a product by ID.
  """
  def get_product(id, opts \\ []) do
    # TODO: Implement in Phase 3
    raise "Not yet implemented"
  end

  # Conversion Utilities - Phase 4

  @doc """
  Converts Ash resource records to simple maps for renderer testing.

  This bridges the gap between realistic Ash resources and the simple
  map format expected by some renderer tests.

  ## Examples

      customers = list_customers(limit: 5)
      simple_maps = to_simple_maps(customers)
      context = build_render_context(records: simple_maps)
  """
  def to_simple_maps(records) when is_list(records) do
    # TODO: Implement in Phase 4
    raise "Not yet implemented"
  end

  @doc """
  Converts a single Ash resource record to a simple map.
  """
  def to_simple_map(record) do
    # TODO: Implement in Phase 4
    raise "Not yet implemented"
  end

  # Private Helpers

  defp get_scenario_counts(:empty), do: %{customers: 0, invoices: 0, products: 0}
  defp get_scenario_counts(:small), do: %{customers: 10, invoices: 20, products: 15}
  defp get_scenario_counts(:medium), do: %{customers: 100, invoices: 200, products: 150}
  defp get_scenario_counts(:large), do: %{customers: 1000, invoices: 2000, products: 1500}

  defp get_all_resources do
    [
      :customers,
      :customer_addresses,
      :customer_types,
      :invoices,
      :invoice_line_items,
      :products,
      :product_categories,
      :inventory
    ]
  end

  defp ensure_data_generator_started do
    # DataGenerator should already be started by the application
    # But check if it's running and start if needed
    case Process.whereis(DataGenerator) do
      nil ->
        {:ok, _pid} = DataGenerator.start_link()
        :ok

      _pid ->
        :ok
    end
  end

  defp get_record_counts do
    # Get statistics from ETS data layer
    case EtsDataLayer.table_stats() do
      %{tables: tables} ->
        tables
        |> Enum.map(fn {table_name, stats} ->
          resource_name = table_name_to_resource(table_name)
          {resource_name, stats.size}
        end)
        |> Enum.into(%{})

      _ ->
        %{}
    end
  end

  defp table_name_to_resource(:demo_customers), do: :customers
  defp table_name_to_resource(:demo_customer_addresses), do: :customer_addresses
  defp table_name_to_resource(:demo_customer_types), do: :customer_types
  defp table_name_to_resource(:demo_products), do: :products
  defp table_name_to_resource(:demo_product_categories), do: :product_categories
  defp table_name_to_resource(:demo_inventory), do: :inventory
  defp table_name_to_resource(:demo_invoices), do: :invoices
  defp table_name_to_resource(:demo_invoice_line_items), do: :invoice_line_items
  defp table_name_to_resource(_), do: :unknown
end
