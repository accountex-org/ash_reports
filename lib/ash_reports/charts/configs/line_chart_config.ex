defmodule AshReports.Charts.LineChartConfig do
  @moduledoc """
  Configuration struct for line charts using Contex LinePlot.

  This module defines the configuration options for line chart generation,
  mapping to Contex LinePlot options. Line charts are ideal for showing
  trends over time or continuous data.

  ## Contex Mapping

  This struct maps to Contex.LinePlot options:
  - `smoothed` → `:smoothed` (boolean for smooth curves)
  - `stroke_width` → `:stroke_width` (string, line thickness)
  - `axis_label_rotation` → `:axis_label_rotation` (:auto, 45, 90)
  - `colours` → `:colour_palette` (list of hex colors)

  ## DSL Usage

      line_chart :sales_trend do
        data_source expr(daily_sales())
        config do
          width 800
          height 400
          title "Sales Trend"
          smoothed true
          stroke_width "3"
          axis_label_rotation :auto
          colours ["FF6384", "36A2EB"]
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 600)
  - `height` - Chart height in pixels (default: 400)
  - `title` - Chart title (optional)
  - `smoothed` - Use smooth curves instead of straight lines (default: true)
  - `stroke_width` - Line thickness as string (default: "2")
  - `axis_label_rotation` - X-axis label rotation: :auto, :"45", :"90" (default: :auto)
  - `colours` - List of hex color codes without # (default: [])

  ## Data Format

  Line charts expect data with x and y coordinates:

      [
        %{x: 1, y: 100},
        %{x: 2, y: 150},
        %{x: 3, y: 120}
      ]

  For time series with dates:

      [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150}
      ]

  Multiple lines can be plotted with multiple y columns:

      [
        %{x: 1, product_a: 100, product_b: 150},
        %{x: 2, product_a: 120, product_b: 180}
      ]
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :title, :string
    field :smoothed, :boolean, default: true
    field :stroke_width, :string, default: "2"
    field :axis_label_rotation, Ecto.Enum, values: [:auto, :"45", :"90"], default: :auto
    field :colours, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          title: String.t() | nil,
          smoothed: boolean(),
          stroke_width: String.t(),
          axis_label_rotation: :auto | :"45" | :"90",
          colours: [String.t()]
        }

  @doc """
  Creates a changeset for line chart configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `stroke_width` must be a string
  - `axis_label_rotation` must be one of: :auto, :"45", :"90"
  - `colours` must be a list of strings (hex codes without #)
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [:width, :height, :title, :smoothed, :stroke_width, :axis_label_rotation, :colours])
    |> validate_required([:width, :height, :stroke_width])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_inclusion(:axis_label_rotation, [:auto, :"45", :"90"])
  end
end
