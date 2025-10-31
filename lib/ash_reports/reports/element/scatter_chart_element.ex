defmodule AshReports.Element.ScatterChartElement do
  @moduledoc """
  A scatter chart element that references a standalone scatter chart definition.

  Instead of defining chart configuration inline, this element references
  a scatter chart defined at the reports level by name.

  ## Example

      # Define chart at reports level
      reports do
        scatter_chart :correlation_plot do
          data_source expr(xy_data_points())
          config do
            width 600
            height 600
            title "Feature Correlation"
            axis_label_rotation :"45"
          end
        end

        report :data_analysis do
          bands do
            band :visualizations do
              elements do
                scatter_chart :correlation_plot
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
    type: :scatter_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :scatter_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new ScatterChartElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the scatter_chart definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :scatter_chart_element]
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
