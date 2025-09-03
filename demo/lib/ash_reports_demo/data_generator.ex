defmodule AshReportsDemo.DataGenerator do
  @moduledoc """
  GenServer that generates realistic test data using Faker library.
  
  Provides seeding functions for all demo resources with proper
  relationship integrity and configurable data volumes.
  """

  use GenServer

  require Logger

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
          updated_state = %{state |
            generation_in_progress: false,
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
        updated_state = %{state |
          last_generated: nil,
          current_volume: nil
        }
        
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
      try do
        # Phase 7.1: Basic structure setup - actual data generation in Phase 7.3
        Logger.info("Data generation for #{volume} volume: #{inspect(volume_config)}")
        
        # Placeholder for actual data generation
        # Will be implemented in Phase 7.3 with Faker integration
        :ok
      rescue
        error ->
          {:error, Exception.message(error)}
      end
    else
      {:error, "Unknown volume: #{volume}. Available: #{Map.keys(@data_volumes) |> Enum.join(", ")}"}
    end
  end

  defp reset_data_internal do
    try do
      # Phase 7.1: Basic structure - actual reset logic in Phase 7.3
      Logger.info("Resetting demo data")
      :ok
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end
end