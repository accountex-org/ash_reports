defmodule AshReports.Charts.BarChart do
  @moduledoc """
  Definition struct for a bar chart.

  This module represents a standalone bar chart definition that can be
  referenced in report bands. Bar charts are defined at the top level of
  the reports DSL and can be reused across multiple bands.

  ## DSL Usage

  Define a bar chart at the reports level:

      reports do
        bar_chart :sales_by_region do
          data_source expr(aggregate_sales_by_region())
          config do
            width 600
            height 400
            title "Sales by Region"
            type :grouped
            orientation :vertical
            data_labels true
          end
        end

        report :monthly_report do
          bands do
            band :summary do
              elements do
                bar_chart :sales_by_region
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the chart (e.g., :sales_by_region)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - BarChartConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to data
  in a format compatible with Contex BarChart. The expression is evaluated
  in the report's execution context with access to variables and the current
  record scope.
  """

  alias AshReports.Charts.{BarChartConfig, TransformDSL}

  @type t :: %__MODULE__{
          name: atom(),
          driving_resource: module() | nil,
          transform: TransformDSL.t() | nil,
          scope: (map() -> Ash.Query.t()) | nil,
          load_relationships: list() | nil,
          config: BarChartConfig.t() | nil
        }

  defstruct [:name, :driving_resource, :transform, :scope, :load_relationships, :config]

  @doc """
  Creates a new BarChart definition.

  ## Parameters

  - `name` - Atom identifier for the chart
  - `opts` - Keyword list with optional fields

  ## Examples

      iex> BarChart.new(:my_chart, driving_resource: MyResource)
      %BarChart{name: :my_chart, driving_resource: MyResource}
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
