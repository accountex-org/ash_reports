defmodule AshReports.Element.LineChartElement do
  @moduledoc """
  A line chart element that references a standalone line chart definition.

  Instead of defining chart configuration inline, this element references
  a line chart defined at the reports level by name.

  ## Example

      # Define chart at reports level
      reports do
        line_chart :trends_over_time do
          data_source expr(daily_metrics())
          config do
            width 800
            height 400
            smoothed true
            stroke_width "2"
          end
        end

        report :dashboard do
          bands do
            band :charts do
              elements do
                line_chart :trends_over_time
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
    type: :line_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :line_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new LineChartElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the line_chart definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :line_chart_element]
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
