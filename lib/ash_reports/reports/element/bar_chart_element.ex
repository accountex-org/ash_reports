defmodule AshReports.Element.BarChartElement do
  @moduledoc """
  A bar chart element that references a standalone bar chart definition.

  Instead of defining chart configuration inline, this element references
  a bar chart defined at the reports level by name.

  ## Example

      # Define chart at reports level
      reports do
        bar_chart :sales_by_region do
          data_source expr(aggregate_sales_by_region())
          config do
            width 600
            height 400
            title "Sales by Region"
            type :grouped
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
  """

  defstruct [
    :name,
    :chart_name,
    :position,
    :style,
    :conditional,
    type: :bar_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :bar_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new BarChartElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the bar_chart definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :bar_chart_element]
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
