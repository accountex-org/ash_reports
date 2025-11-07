defmodule AshReports.Charts.GanttChart do
  @moduledoc """
  Definition struct for a Gantt chart.

  This module represents a standalone Gantt chart definition that can be
  referenced in report bands. Gantt charts are ideal for visualizing project
  timelines, task schedules, and time-based dependencies.

  ## DSL Usage

  Define a Gantt chart at the reports level:

      reports do
        gantt_chart :project_timeline do
          data_source expr(get_project_tasks())
          config do
            width 900
            height 400
            title "Project Timeline"
            show_task_labels true
            padding 2
            colours ["36A2EB", "FF6384", "FFCE56"]
          end
        end

        report :project_report do
          bands do
            band :schedule do
              elements do
                gantt_chart :project_timeline
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the chart (e.g., :project_timeline)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - GanttChartConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to data
  in a format compatible with Contex Gantt chart. The data must include
  DateTime values for task start and end times. The expression is evaluated
  in the report's execution context with access to variables and the current
  record scope.

  ## Important Note

  Gantt charts require DateTime fields for task scheduling. Ensure your
  data source provides proper DateTime values for start_date and end_date.
  """

  alias AshReports.Charts.{GanttChartConfig, TransformDSL}

  @type t :: %__MODULE__{
          name: atom(),
          driving_resource: module() | nil,
          transform: TransformDSL.t() | nil,
          scope: (map() -> Ash.Query.t()) | nil,
          load_relationships: list() | nil,
          config: GanttChartConfig.t() | nil
        }

  defstruct [:name, :driving_resource, :transform, :scope, :load_relationships, :config]

  @doc """
  Creates a new GanttChart definition.

  ## Parameters

  - `name` - Atom identifier for the chart
  - `opts` - Keyword list with optional :data_source and :config

  ## Examples

      iex> GanttChart.new(:my_chart, data_source: expr(get_data()), config: %GanttChartConfig{})
      %GanttChart{name: :my_chart, data_source: {:expr, [get_data()]}, config: %GanttChartConfig{}}
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
