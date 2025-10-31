defmodule AshReports.Charts.LineChart do
  @moduledoc """
  Definition struct for a line chart.

  This module represents a standalone line chart definition that can be
  referenced in report bands. Line charts are ideal for showing trends
  over time or continuous data.

  ## DSL Usage

  Define a line chart at the reports level:

      reports do
        line_chart :revenue_trend do
          data_source expr(get_monthly_revenue())
          config do
            width 800
            height 400
            title "Revenue Trend"
            smoothed true
            stroke_width "2"
            axis_label_rotation :auto
          end
        end

        report :financial_report do
          bands do
            band :trends do
              elements do
                line_chart :revenue_trend
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the chart (e.g., :revenue_trend)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - LineChartConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to data
  in a format compatible with Contex LinePlot. The expression is evaluated
  in the report's execution context with access to variables and the current
  record scope.
  """

  alias AshReports.Charts.LineChartConfig

  @type t :: %__MODULE__{
          name: atom(),
          data_source: term(),
          config: LineChartConfig.t() | nil
        }

  defstruct [:name, :data_source, :config]

  @doc """
  Creates a new LineChart definition.

  ## Parameters

  - `name` - Atom identifier for the chart
  - `opts` - Keyword list with optional :data_source and :config

  ## Examples

      iex> LineChart.new(:my_chart, data_source: expr(get_data()), config: %LineChartConfig{})
      %LineChart{name: :my_chart, data_source: {:expr, [get_data()]}, config: %LineChartConfig{}}
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
