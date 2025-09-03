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
  """
  @spec table_name(atom()) :: atom()
  def table_name(AshReportsDemo.Customer), do: :demo_customers
  def table_name(AshReportsDemo.CustomerAddress), do: :demo_customer_addresses
  def table_name(AshReportsDemo.CustomerType), do: :demo_customer_types
  def table_name(AshReportsDemo.Product), do: :demo_products
  def table_name(AshReportsDemo.ProductCategory), do: :demo_product_categories
  def table_name(AshReportsDemo.Inventory), do: :demo_inventory
  def table_name(AshReportsDemo.Invoice), do: :demo_invoices
  def table_name(AshReportsDemo.InvoiceLineItem), do: :demo_invoice_line_items
  def table_name(_), do: :demo_unknown

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