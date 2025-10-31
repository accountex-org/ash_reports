defmodule AshReports.Charts.ScatterChart do
  @moduledoc """
  Definition struct for a scatter chart.

  This module represents a standalone scatter chart definition that can be
  referenced in report bands. Scatter charts (point plots) are ideal for
  showing correlation between two variables or distribution patterns.

  ## DSL Usage

  Define a scatter chart at the reports level:

      reports do
        scatter_chart :price_vs_quantity do
          data_source expr(get_correlation_data())
          config do
            width 700
            height 500
            title "Price vs Quantity Analysis"
            axis_label_rotation :auto
            colours ["FF6384", "36A2EB"]
          end
        end

        report :analysis_report do
          bands do
            band :correlation do
              elements do
                scatter_chart :price_vs_quantity
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the chart (e.g., :price_vs_quantity)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - ScatterChartConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to data
  in a format compatible with Contex PointPlot. The expression is evaluated
  in the report's execution context with access to variables and the current
  record scope.
  """

  alias AshReports.Charts.ScatterChartConfig

  @type t :: %__MODULE__{
          name: atom(),
          data_source: term(),
          config: ScatterChartConfig.t() | nil
        }

  defstruct [:name, :data_source, :config]

  @doc """
  Creates a new ScatterChart definition.

  ## Parameters

  - `name` - Atom identifier for the chart
  - `opts` - Keyword list with optional :data_source and :config

  ## Examples

      iex> ScatterChart.new(:my_chart, data_source: expr(get_data()), config: %ScatterChartConfig{})
      %ScatterChart{name: :my_chart, data_source: {:expr, [get_data()]}, config: %ScatterChartConfig{}}
  """
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) when is_atom(name) do
    %__MODULE__{
      name: name,
      data_source: Keyword.get(opts, :data_source),
      config: Keyword.get(opts, :config)
    }
  end
end
