defmodule AshReports.Element.Chart do
  @moduledoc """
  A chart element for embedding visualizations in reports.

  Supports all chart types from the Charts module: bar, line, pie, area, scatter,
  sparkline, and gantt.

  Charts can bind data from report queries, use dynamic configuration via expressions,
  and support conditional rendering.

  ## Examples

      chart :sales_by_region do
        chart_type :bar
        data_source expr(
          records
          |> Enum.group_by(& &1.region)
          |> Enum.map(fn {region, sales} ->
            %{category: region, value: Enum.sum(Enum.map(sales, & &1.amount))}
          end)
        )
        config %{width: 600, height: 400, title: "Sales by Region"}
        caption "Regional sales breakdown"
      end

      chart :trend_sparkline do
        chart_type :sparkline
        data_source expr(daily_metrics)
        config %{width: 100, height: 20}
      end

      chart :project_timeline do
        chart_type :gantt
        data_source expr(project_tasks)
        config %{width: 1000, height: 600, title: "Sprint Planning"}
      end
  """

  defstruct [
    :name,
    :chart_type,
    :data_source,
    :config,
    :embed_options,
    :caption,
    :title,
    :conditional,
    type: :chart
  ]

  @type chart_type :: :bar | :line | :pie | :area | :scatter | :sparkline | :gantt

  @type t :: %__MODULE__{
          name: atom(),
          type: :chart,
          chart_type: chart_type(),
          data_source: Ash.Expr.t(),
          config: map() | Ash.Expr.t(),
          embed_options: map(),
          caption: String.t() | Ash.Expr.t() | nil,
          title: String.t() | Ash.Expr.t() | nil,
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Chart element with the given name and options.

  ## Options

    - `:chart_type` - Type of chart (:bar, :line, :pie, :area, :scatter)
    - `:data_source` - Expression that evaluates to chart data (list of maps)
    - `:config` - Chart configuration (map or expression)
    - `:embed_options` - Options for ChartEmbedder (width, height, etc.)
    - `:caption` - Caption text below chart (string or expression)
    - `:title` - Title text above chart (string or expression)
    - `:conditional` - Expression to determine if chart should render
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :chart]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:chart_type, :bar)
      |> Keyword.put_new(:embed_options, %{})
    )
  end
end
