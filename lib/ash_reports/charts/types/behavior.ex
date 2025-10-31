defmodule AshReports.Charts.Types.Behavior do
  @moduledoc """
  Behavior for chart type implementations.

  All chart types must implement this behavior to ensure a consistent interface
  for chart generation. The behavior defines callbacks for building chart
  structures and validating data.

  ## Implementing a Custom Chart

      defmodule MyApp.CustomChart do
        @behaviour AshReports.Charts.Types.Behavior

        @impl true
        def build(data, config) do
          # Build chart using Contex or custom logic
          # Return Contex chart struct
        end

        @impl true
        def validate(data) do
          # Validate data format
          if valid_data?(data) do
            :ok
          else
            {:error, "Invalid data format"}
          end
        end
      end

  ## Required Callbacks

    - `build/2` - Builds the chart structure from data and config
    - `validate/1` - Validates the data format for this chart type
  """

  @doc """
  Builds a chart structure from data and configuration.

  ## Parameters

    - `data` - List of maps containing chart data
    - `config` - Type-specific config struct (e.g., BarChartConfig, LineChartConfig)

  ## Returns

    - Chart structure (typically a Contex chart struct)
    - The structure will be passed to the renderer for SVG generation

  ## Examples

      def build(data, config) do
        dataset = Contex.Dataset.new(data)

        Contex.BarChart.new(dataset)
        |> Contex.BarChart.set_val_col_names(["value"])
        |> Contex.BarChart.colours(config.colours || [])
      end
  """
  @callback build(data :: list(map()), config :: map()) :: term()

  @doc """
  Validates data format for the chart type.

  ## Parameters

    - `data` - List of maps containing chart data

  ## Returns

    - `:ok` - Data is valid
    - `{:error, reason}` - Data is invalid

  ## Examples

      def validate(data) when is_list(data) do
        if Enum.all?(data, &Map.has_key?(&1, :value)) do
          :ok
        else
          {:error, "All data points must have a :value key"}
        end
      end

      def validate(_), do: {:error, "Data must be a list"}
  """
  @callback validate(data :: term()) :: :ok | {:error, String.t()}
end
