defmodule AshReports.Element.AreaChartElement do
  @moduledoc """
  An area chart element that references a standalone area chart definition.

  Instead of defining chart configuration inline, this element references
  an area chart defined at the reports level by name.

  ## Example

      # Define chart at reports level
      reports do
        area_chart :revenue_growth do
          data_source expr(quarterly_revenue())
          config do
            width 700
            height 350
            mode :stacked
            opacity 0.7
            smooth_lines true
          end
        end

        report :financial_report do
          bands do
            band :trends do
              elements do
                area_chart :revenue_growth
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
    type: :area_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :area_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new AreaChartElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the area_chart definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :area_chart_element]
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
