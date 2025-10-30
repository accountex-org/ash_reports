defmodule AshReports.Charts.ScatterChartConfig do
  @moduledoc """
  Configuration struct for scatter charts using Contex PointPlot.

  This module defines the configuration options for scatter chart generation,
  mapping to Contex PointPlot options. Scatter charts are ideal for showing
  relationships between two variables and identifying correlations or patterns.

  ## Contex Mapping

  This struct maps to Contex.PointPlot options:
  - `axis_label_rotation` → `:axis_label_rotation` (:auto, 45, 90)
  - `colours` → `:colour_palette` (list of hex colors)

  PointPlot shares the same structure as LinePlot but renders points instead
  of connected lines.

  ## DSL Usage

      scatter_chart :price_vs_sales do
        data_source expr(product_metrics())
        config do
          width 600
          height 400
          title "Price vs Sales Volume"
          axis_label_rotation :auto
          colours ["FF6384", "36A2EB", "FFCE56"]
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 600)
  - `height` - Chart height in pixels (default: 400)
  - `title` - Chart title (optional)
  - `axis_label_rotation` - X-axis label rotation: :auto, :"45", :"90" (default: :auto)
  - `colours` - List of hex color codes without # (default: [])

  ## Data Format

  Scatter charts expect data with x and y coordinates:

      [
        %{x: 10.5, y: 250},
        %{x: 15.2, y: 180},
        %{x: 20.8, y: 320}
      ]

  Multiple series can be plotted with a fill column for grouping:

      [
        %{x: 10, y: 100, category: "A"},
        %{x: 15, y: 150, category: "B"},
        %{x: 20, y: 200, category: "A"}
      ]
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :title, :string
    field :axis_label_rotation, Ecto.Enum, values: [:auto, :"45", :"90"], default: :auto
    field :colours, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          title: String.t() | nil,
          axis_label_rotation: :auto | :"45" | :"90",
          colours: [String.t()]
        }

  @doc """
  Creates a changeset for scatter chart configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `axis_label_rotation` must be one of: :auto, :"45", :"90"
  - `colours` must be a list of strings (hex codes without #)
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [:width, :height, :title, :axis_label_rotation, :colours])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_inclusion(:axis_label_rotation, [:auto, :"45", :"90"])
  end
end
