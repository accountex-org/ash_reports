defmodule AshReports.Charts.AreaChart do
  @moduledoc """
  Definition struct for an area chart.

  This module represents a standalone area chart definition that can be
  referenced in report bands. Area charts are similar to line charts but
  with filled areas beneath the lines, ideal for showing cumulative totals
  or volume over time.

  ## DSL Usage

  Define an area chart at the reports level:

      reports do
        area_chart :cumulative_sales do
          data_source expr(get_cumulative_data())
          config do
            width 800
            height 400
            title "Cumulative Sales"
            mode :stacked
            opacity 0.7
            smooth_lines true
            colours ["36A2EB", "FF6384", "FFCE56"]
          end
        end

        report :sales_report do
          bands do
            band :trends do
              elements do
                area_chart :cumulative_sales
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the chart (e.g., :cumulative_sales)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - AreaChartConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to data
  in a format compatible with Contex LinePlot with area fill. The expression
  is evaluated in the report's execution context with access to variables
  and the current record scope.
  """

  alias AshReports.Charts.AreaChartConfig

  @type t :: %__MODULE__{
          name: atom(),
          data_source: term(),
          config: AreaChartConfig.t() | nil
        }

  defstruct [:name, :data_source, :config]

  @doc """
  Creates a new AreaChart definition.

  ## Parameters

  - `name` - Atom identifier for the chart
  - `opts` - Keyword list with optional :data_source and :config

  ## Examples

      iex> AreaChart.new(:my_chart, data_source: expr(get_data()), config: %AreaChartConfig{})
      %AreaChart{name: :my_chart, data_source: {:expr, [get_data()]}, config: %AreaChartConfig{}}
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
