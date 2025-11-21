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

  # Require query helpers from Ash
  require Ash.Query

  # Suppress unused function warnings for helper functions intended for future use
  @compile :nowarn_unused_function

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
  - `:filter` - Keyword list of filters (e.g., [status: :active])
  - `:load` - List of relationships to load (e.g., [:invoices, :addresses])
  - `:sort` - Sort order (e.g., [name: :asc] or [:name])

  ## Examples

      customers = list_customers()
      customers = list_customers(limit: 10)
      customers = list_customers(filter: [status: :active], load: [:invoices])
      customers = list_customers(sort: [name: :asc], limit: 5)
  """
  def list_customers(opts \\ []) do
    AshReportsDemo.Customer
    |> build_query(opts)
    |> Ash.read!(domain: Domain)
  end

  @doc """
  Gets a customer by ID.

  ## Options

  - `:load` - List of relationships to load

  ## Examples

      customer = get_customer(customer_id)
      customer = get_customer(customer_id, load: [:invoices, :addresses])
  """
  def get_customer(id, opts \\ []) do
    load = Keyword.get(opts, :load, [])

    AshReportsDemo.Customer
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(load)
    |> Ash.read_one!(domain: Domain)
  end

  @doc """
  Counts total customers.

  ## Options

  - `:filter` - Keyword list of filters

  ## Examples

      count = count_customers()
      active_count = count_customers(filter: [status: :active])
  """
  def count_customers(opts \\ []) do
    query =
      AshReportsDemo.Customer
      |> Ash.Query.for_read(:read)

    query =
      case Keyword.get(opts, :filter) do
        nil -> query
        filters -> apply_filters(query, filters)
      end

    Ash.count!(query, domain: Domain)
  end

  @doc """
  Lists all invoices with optional filtering and pagination.

  ## Options

  - `:limit` - Maximum number of records to return
  - `:offset` - Number of records to skip
  - `:filter` - Keyword list of filters (e.g., [status: :paid])
  - `:load` - List of relationships to load (e.g., [:customer, :line_items])
  - `:sort` - Sort order (e.g., [date: :desc])

  ## Examples

      invoices = list_invoices()
      invoices = list_invoices(limit: 10, sort: [date: :desc])
      invoices = list_invoices(filter: [status: :paid], load: [:customer])
  """
  def list_invoices(opts \\ []) do
    AshReportsDemo.Invoice
    |> build_query(opts)
    |> Ash.read!(domain: Domain)
  end

  @doc """
  Gets an invoice by ID.

  ## Options

  - `:load` - List of relationships to load

  ## Examples

      invoice = get_invoice(invoice_id)
      invoice = get_invoice(invoice_id, load: [:customer, :line_items])
  """
  def get_invoice(id, opts \\ []) do
    load = Keyword.get(opts, :load, [])

    AshReportsDemo.Invoice
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(load)
    |> Ash.read_one!(domain: Domain)
  end

  @doc """
  Lists all products with optional filtering and pagination.

  ## Options

  - `:limit` - Maximum number of records to return
  - `:offset` - Number of records to skip
  - `:filter` - Keyword list of filters (e.g., [active: true])
  - `:load` - List of relationships to load (e.g., [:category])
  - `:sort` - Sort order (e.g., [name: :asc])

  ## Examples

      products = list_products()
      products = list_products(limit: 10)
      products = list_products(filter: [active: true], sort: [name: :asc])
  """
  def list_products(opts \\ []) do
    AshReportsDemo.Product
    |> build_query(opts)
    |> Ash.read!(domain: Domain)
  end

  @doc """
  Gets a product by ID.

  ## Options

  - `:load` - List of relationships to load

  ## Examples

      product = get_product(product_id)
      product = get_product(product_id, load: [:category])
  """
  def get_product(id, opts \\ []) do
    load = Keyword.get(opts, :load, [])

    AshReportsDemo.Product
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(load)
    |> Ash.read_one!(domain: Domain)
  end

  # Conversion Utilities - Phase 4

  @doc """
  Converts Ash resource records to simple maps for renderer testing.

  This bridges the gap between realistic Ash resources and the simple
  map format expected by some renderer tests.

  ## Options

  - `:exclude_fields` - List of fields to exclude from the map
  - `:include_relationships` - Boolean, whether to include loaded relationships (default: true)

  ## Examples

      customers = list_customers(limit: 5)
      simple_maps = to_simple_maps(customers)
      context = build_render_context(records: simple_maps)

      # Exclude certain fields
      simple_maps = to_simple_maps(customers, exclude_fields: [:__meta__, :__metadata__])

      # Don't include relationships
      simple_maps = to_simple_maps(customers, include_relationships: false)
  """
  def to_simple_maps(records, opts \\ []) when is_list(records) do
    Enum.map(records, fn record -> to_simple_map(record, opts) end)
  end

  @doc """
  Converts a single Ash resource record to a simple map.

  ## Options

  - `:exclude_fields` - List of fields to exclude from the map
  - `:include_relationships` - Boolean, whether to include loaded relationships (default: true)

  ## Examples

      customer = get_customer(customer_id)
      simple_map = to_simple_map(customer)

      # Exclude metadata fields
      simple_map = to_simple_map(customer, exclude_fields: [:__meta__, :__metadata__])
  """
  def to_simple_map(record, opts \\ [])

  def to_simple_map(nil, _opts), do: nil

  def to_simple_map(record, opts) when is_struct(record) do
    exclude_fields = Keyword.get(opts, :exclude_fields, [:__meta__, :__metadata__, :aggregates, :calculations])
    include_relationships = Keyword.get(opts, :include_relationships, true)

    # Get list of relationship names for this resource
    relationship_names = get_relationship_names(record.__struct__)

    # Convert struct to map
    record
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      cond do
        # Skip excluded fields
        key in exclude_fields ->
          acc

        # Skip unloaded relationships
        is_struct(value, Ash.NotLoaded) ->
          acc

        # Skip relationships if include_relationships is false
        key in relationship_names and not include_relationships ->
          acc

        # Handle loaded relationships
        key in relationship_names and include_relationships ->
          Map.put(acc, key, convert_relationship_value(value, opts))

        # Include regular attributes
        true ->
          Map.put(acc, key, convert_value(value))
      end
    end)
  end

  def to_simple_map(value, _opts) when is_map(value) do
    # Already a plain map
    value
  end

  # Private helper to convert relationship values
  defp convert_relationship_value(value, opts) when is_list(value) do
    Enum.map(value, fn item -> to_simple_map(item, opts) end)
  end

  defp convert_relationship_value(value, opts) when is_struct(value) do
    to_simple_map(value, opts)
  end

  defp convert_relationship_value(value, _opts), do: value

  # Private helper to convert attribute values
  defp convert_value(%Decimal{} = decimal), do: decimal
  defp convert_value(%Date{} = date), do: date
  defp convert_value(%DateTime{} = datetime), do: datetime
  defp convert_value(%NaiveDateTime{} = datetime), do: datetime
  defp convert_value(value) when is_struct(value), do: Map.from_struct(value)
  defp convert_value(value), do: value

  # Private helper to get relationship names from a module
  defp get_relationship_names(module) do
    try do
      module
      |> Ash.Resource.Info.relationships()
      |> Enum.map(& &1.name)
    rescue
      _ -> []
    end
  end

  # Private Helpers

  # Query building helper
  defp build_query(resource, opts) do
    query = Ash.Query.for_read(resource, :read)

    query
    |> apply_filters(Keyword.get(opts, :filter))
    |> apply_pagination(Keyword.get(opts, :limit), Keyword.get(opts, :offset))
    |> apply_loads(Keyword.get(opts, :load))
    |> apply_sort(Keyword.get(opts, :sort))
  end

  defp apply_filters(query, nil), do: query

  defp apply_filters(query, filters) when is_list(filters) do
    # Convert keyword list to map for Ash filter
    filter_map = Enum.into(filters, %{})
    Ash.Query.filter(query, ^filter_map)
  end

  defp apply_pagination(query, nil, nil), do: query
  defp apply_pagination(query, limit, nil), do: Ash.Query.limit(query, limit)
  defp apply_pagination(query, nil, offset), do: Ash.Query.offset(query, offset)
  defp apply_pagination(query, limit, offset) do
    query
    |> Ash.Query.limit(limit)
    |> Ash.Query.offset(offset)
  end

  defp apply_loads(query, nil), do: query
  defp apply_loads(query, []), do: query
  defp apply_loads(query, loads) when is_list(loads), do: Ash.Query.load(query, loads)

  defp apply_sort(query, nil), do: query
  defp apply_sort(query, []), do: query
  defp apply_sort(query, sort) when is_list(sort), do: Ash.Query.sort(query, sort)

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
