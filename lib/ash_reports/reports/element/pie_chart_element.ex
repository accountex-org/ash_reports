defmodule AshReports.Element.PieChartElement do
  @moduledoc """
  A pie chart element that references a standalone pie chart definition.

  Instead of defining chart configuration inline, this element references
  a pie chart defined at the reports level by name.

  ## Example

      # Define chart at reports level
      reports do
        pie_chart :market_share do
          data_source expr(category_percentages())
          config do
            width 500
            height 500
            title "Market Share"
            data_labels true
          end
        end

        report :analysis do
          bands do
            band :breakdown do
              elements do
                pie_chart :market_share
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
    type: :pie_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :pie_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new PieChartElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the pie_chart definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :pie_chart_element]
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
