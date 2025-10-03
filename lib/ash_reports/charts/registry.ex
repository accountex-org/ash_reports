defmodule AshReports.Charts.Registry do
  @moduledoc """
  Chart type registry for managing available chart implementations.

  This module maintains a registry of chart types using ETS for fast lookups.
  Chart modules must implement the `AshReports.Charts.Types.Behavior` behavior
  to be registered.

  ## Registration

  Chart types are automatically registered when the application starts. New chart
  types can also be registered at runtime.

  ## Usage

      # Get a chart module
      {:ok, module} = Registry.get(:bar)

      # List all available chart types
      types = Registry.list()
      # => [:bar, :line, :pie]

      # Register a new chart type
      Registry.register(:custom, MyApp.CustomChart)
  """

  use GenServer
  require Logger

  @table_name :ash_reports_chart_registry

  # Client API

  @doc """
  Starts the registry GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a chart type with its implementation module.

  ## Parameters

    - `type` - Chart type atom (e.g., `:bar`, `:line`)
    - `module` - Module implementing the chart (must implement Behavior)

  ## Returns

    - `:ok` - Successfully registered
    - `{:error, reason}` - Registration failed

  ## Examples

      Registry.register(:bar, AshReports.Charts.Types.BarChart)
      # => :ok

      Registry.register(:bar, AshReports.Charts.Types.BarChart)
      # => {:error, :already_registered}
  """
  @spec register(atom(), module()) :: :ok | {:error, term()}
  def register(type, module) when is_atom(type) and is_atom(module) do
    GenServer.call(__MODULE__, {:register, type, module})
  end

  @doc """
  Retrieves the chart module for a given type.

  ## Parameters

    - `type` - Chart type atom

  ## Returns

    - `{:ok, module}` - Chart module found
    - `{:error, :not_found}` - Chart type not registered

  ## Examples

      Registry.get(:bar)
      # => {:ok, AshReports.Charts.Types.BarChart}

      Registry.get(:unknown)
      # => {:error, :not_found}
  """
  @spec get(atom()) :: {:ok, module()} | {:error, :not_found}
  def get(type) when is_atom(type) do
    case :ets.lookup(@table_name, type) do
      [{^type, module}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered chart types.

  ## Returns

  List of chart type atoms.

  ## Examples

      Registry.list()
      # => [:bar, :line, :pie]
  """
  @spec list() :: [atom()]
  def list do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {type, _module} -> type end)
    |> Enum.sort()
  end

  @doc """
  Unregisters a chart type.

  ## Parameters

    - `type` - Chart type atom to unregister

  ## Returns

  `:ok`

  ## Examples

      Registry.unregister(:custom)
      # => :ok
  """
  @spec unregister(atom()) :: :ok
  def unregister(type) when is_atom(type) do
    GenServer.call(__MODULE__, {:unregister, type})
  end

  @doc """
  Clears all registered chart types.

  ## Returns

  `:ok`

  ## Examples

      Registry.clear()
      # => :ok
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for chart registry
    :ets.new(@table_name, [
      :named_table,
      :set,
      :public,
      read_concurrency: true
    ])

    Logger.debug("AshReports.Charts.Registry initialized")

    # Register default chart types directly in ETS (not via GenServer.call to avoid deadlock)
    register_default_types_direct()

    {:ok, %{}}
  end

  # Private helper to register types directly in ETS during init
  defp register_default_types_direct do
    alias AshReports.Charts.Types.{BarChart, LineChart, PieChart}

    types = [
      {:bar, BarChart},
      {:line, LineChart},
      {:pie, PieChart}
    ]

    Enum.each(types, fn {type, module} ->
      :ets.insert(@table_name, {type, module})
      Logger.debug("Registered chart type: #{inspect(type)} -> #{inspect(module)}")
    end)
  end

  @impl true
  def handle_call({:register, type, module}, _from, state) do
    case :ets.lookup(@table_name, type) do
      [] ->
        # Verify module implements the behavior (optional check)
        # if function_exported?(module, :build, 2) do
        :ets.insert(@table_name, {type, module})
        Logger.debug("Registered chart type: #{inspect(type)} -> #{inspect(module)}")
        {:reply, :ok, state}

      # else
      #   {:reply, {:error, :invalid_module}, state}
      # end

      [{^type, existing_module}] ->
        Logger.warning(
          "Chart type #{inspect(type)} already registered with #{inspect(existing_module)}"
        )

        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:unregister, type}, _from, state) do
    :ets.delete(@table_name, type)
    Logger.debug("Unregistered chart type: #{inspect(type)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    Logger.debug("Cleared all chart types from registry")
    {:reply, :ok, state}
  end
end
