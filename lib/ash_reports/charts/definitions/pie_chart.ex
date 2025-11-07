defmodule AshReports.Charts.PieChart do
  @moduledoc """
  Definition struct for a pie chart.

  This module represents a standalone pie chart definition that can be
  referenced in report bands. Pie charts are ideal for showing proportions
  and percentage breakdowns of categorical data.

  ## DSL Usage

  Define a pie chart at the reports level:

      reports do
        pie_chart :market_share do
          data_source expr(get_market_distribution())
          config do
            width 500
            height 500
            title "Market Share by Region"
            data_labels true
            colours ["FF6384", "36A2EB", "FFCE56", "4BC0C0"]
          end
        end

        report :market_report do
          bands do
            band :summary do
              elements do
                pie_chart :market_share
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the chart (e.g., :market_share)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - PieChartConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to data
  in a format compatible with Contex PieChart. The expression is evaluated
  in the report's execution context with access to variables and the current
  record scope.
  """

  alias AshReports.Charts.{PieChartConfig, TransformDSL}

  @type t :: %__MODULE__{
          name: atom(),
          driving_resource: module() | nil,
          transform: TransformDSL.t() | nil,
          scope: (map() -> Ash.Query.t()) | nil,
          load_relationships: list() | nil,
          config: PieChartConfig.t() | nil
        }

  defstruct [:name, :driving_resource, :transform, :scope, :load_relationships, :config]

  @doc """
  Creates a new PieChart definition.

  ## Parameters

  - `name` - Atom identifier for the chart
  - `opts` - Keyword list with optional :data_source and :config

  ## Examples

      iex> PieChart.new(:my_chart, data_source: expr(get_data()), config: %PieChartConfig{})
      %PieChart{name: :my_chart, data_source: {:expr, [get_data()]}, config: %PieChartConfig{}}
  """
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) when is_atom(name) do
    %__MODULE__{
      name: name,
      driving_resource: Keyword.get(opts, :driving_resource),
      transform: Keyword.get(opts, :transform),
      scope: Keyword.get(opts, :scope),
      load_relationships: Keyword.get(opts, :load_relationships, []),
      config: Keyword.get(opts, :config)
    }
  end
end
