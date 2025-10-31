defmodule AshReports.Element.GanttChartElement do
  @moduledoc """
  A gantt chart element that references a standalone gantt chart definition.

  Instead of defining chart configuration inline, this element references
  a gantt chart defined at the reports level by name.

  ## Example

      # Define chart at reports level
      reports do
        gantt_chart :project_timeline do
          data_source expr(project_tasks())
          config do
            width 1000
            height 600
            title "Sprint Planning"
            show_task_labels true
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
  """

  defstruct [
    :name,
    :chart_name,
    :position,
    :style,
    :conditional,
    type: :gantt_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :gantt_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new GanttChartElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the gantt_chart definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :gantt_chart_element]
      |> Keyword.merge(opts)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
  end
end
