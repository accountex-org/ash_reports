defmodule AshReports.Element.SparklineElement do
  @moduledoc """
  A sparkline element that references a standalone sparkline definition.

  Instead of defining chart configuration inline, this element references
  a sparkline defined at the reports level by name.

  Sparklines are compact inline charts for showing trends at a glance.

  ## Example

      # Define sparkline at reports level
      reports do
        sparkline :weekly_trend do
          data_source expr(last_7_days())
          config do
            width 100
            height 20
            spot_radius 2
            line_colour "rgba(0, 200, 50, 0.7)"
          end
        end

        report :dashboard do
          bands do
            band :metrics do
              elements do
                label :metric_name do
                  text "Weekly Growth"
                end
                sparkline :weekly_trend
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
    type: :sparkline_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :sparkline_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new SparklineElement with the given chart name.

  ## Parameters

    - `chart_name` - The name of the sparkline definition to reference
    - `opts` - Optional keyword list with position, style, conditional fields
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :sparkline_element]
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
