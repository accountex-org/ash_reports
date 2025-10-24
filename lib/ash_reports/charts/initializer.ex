defmodule AshReports.Charts.Initializer do
  @moduledoc """
  Initializes and registers default chart types on application startup.

  This module is responsible for registering all built-in chart types with
  the chart registry when the application starts.
  """

  alias AshReports.Charts.Registry
  alias AshReports.Charts.Types.{BarChart, LineChart, PieChart}

  require Logger

  @doc """
  Registers all default chart types.

  Called automatically on application startup. Can also be called manually
  to re-register chart types if needed.

  ## Returns

  `:ok`

  ## Chart Types Registered

  - `:bar` - Bar charts (AshReports.Charts.Types.BarChart)
  - `:line` - Line charts (AshReports.Charts.Types.LineChart)
  - `:pie` - Pie charts (AshReports.Charts.Types.PieChart)
  """
  @spec register_default_types() :: :ok
  def register_default_types do
    types = [
      {:bar, BarChart},
      {:line, LineChart},
      {:pie, PieChart}
    ]

    Enum.each(types, fn {type, module} ->
      case Registry.register(type, module) do
        :ok ->
          Logger.debug("Registered chart type: #{inspect(type)}")

        {:error, :already_registered} ->
          Logger.debug("Chart type #{inspect(type)} already registered")

        {:error, reason} ->
          Logger.error("Failed to register chart type #{inspect(type)}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
