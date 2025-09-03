defmodule AshReportsDemo.EtsDataLayer do
  @moduledoc """
  ETS-based data layer for AshReports Demo.
  
  Provides in-memory storage using ETS tables for demonstration purposes,
  allowing zero-configuration startup and easy data manipulation.
  """

  use GenServer

  require Logger

  @table_names [
    :demo_customers,
    :demo_customer_addresses,
    :demo_customer_types,
    :demo_products,
    :demo_product_categories,
    :demo_inventory,
    :demo_invoices,
    :demo_invoice_line_items
  ]

  # Public API

  @doc """
  Start the ETS data layer GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get ETS table name for a resource.
  Phase 7.2: Resource mappings will be added when resources are implemented.
  """
  @spec table_name(atom()) :: atom()
  def table_name(resource_module) when is_atom(resource_module) do
    # Phase 7.2: Will map actual resource modules to tables
    case to_string(resource_module) do
      "Elixir.AshReportsDemo.Customer" -> :demo_customers
      "Elixir.AshReportsDemo.CustomerAddress" -> :demo_customer_addresses
      "Elixir.AshReportsDemo.CustomerType" -> :demo_customer_types
      "Elixir.AshReportsDemo.Product" -> :demo_products
      "Elixir.AshReportsDemo.ProductCategory" -> :demo_product_categories
      "Elixir.AshReportsDemo.Inventory" -> :demo_inventory
      "Elixir.AshReportsDemo.Invoice" -> :demo_invoices
      "Elixir.AshReportsDemo.InvoiceLineItem" -> :demo_invoice_line_items
      _ -> :demo_unknown
    end
  end

  @doc """
  Clear all data from ETS tables.
  """
  @spec clear_all_data() :: :ok
  def clear_all_data do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc """
  Get table statistics.
  """
  @spec table_stats() :: map()
  def table_stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    # Create all ETS tables
    tables = Enum.map(@table_names, fn table_name ->
      table = :ets.new(table_name, [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
      
      {table_name, table}
    end)

    state = %{
      tables: Map.new(tables),
      created_at: DateTime.utc_now()
    }

    Logger.info("ETS Data Layer initialized with #{length(tables)} tables")
    {:ok, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    Enum.each(@table_names, fn table_name ->
      :ets.delete_all_objects(table_name)
    end)

    Logger.info("Cleared all ETS data tables")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = @table_names
    |> Enum.map(fn table_name ->
      size = :ets.info(table_name, :size)
      memory = :ets.info(table_name, :memory)
      {table_name, %{size: size, memory_words: memory}}
    end)
    |> Map.new()

    total_size = stats |> Map.values() |> Enum.map(& &1.size) |> Enum.sum()
    total_memory = stats |> Map.values() |> Enum.map(& &1.memory_words) |> Enum.sum()

    result = %{
      tables: stats,
      total_records: total_size,
      total_memory_words: total_memory,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.created_at, :second)
    }

    {:reply, result, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Clean up ETS tables
    Enum.each(@table_names, fn table_name ->
      try do
        :ets.delete(table_name)
      rescue
        _ -> :ok
      end
    end)

    Logger.info("ETS Data Layer terminated and cleaned up")
    :ok
  end
end