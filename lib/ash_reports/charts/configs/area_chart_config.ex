defmodule AshReports.Charts.AreaChartConfig do
  @moduledoc """
  Configuration struct for area charts using Contex LinePlot with area fill.

  This module defines the configuration options for area chart generation.
  Area charts are built on top of LinePlot with filled areas below the lines,
  ideal for showing cumulative trends and volume over time.

  ## Contex Mapping

  Area charts use Contex.LinePlot internally with post-processing for area fill:
  - Inherits all LinePlot options (smoothed, stroke_width, axis_label_rotation)
  - `mode` → controls stacking behavior (:simple, :stacked)
  - `opacity` → fill transparency (0.0-1.0)
  - `smooth_lines` → whether to use smooth curves

  ## DSL Usage

      area_chart :cumulative_sales do
        data_source expr(daily_cumulative())
        config do
          width 800
          height 400
          title "Cumulative Sales"
          mode :simple
          opacity 0.7
          smooth_lines true
          smoothed true
          stroke_width "2"
          colours ["FF6384", "36A2EB"]
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 600)
  - `height` - Chart height in pixels (default: 400)
  - `title` - Chart title (optional)
  - `mode` - Stacking mode: :simple, :stacked (default: :simple)
  - `opacity` - Fill opacity from 0.0 to 1.0 (default: 0.7)
  - `smooth_lines` - Use smooth curves (default: true)
  - `smoothed` - LinePlot smoothing (default: true)
  - `stroke_width` - Line thickness as string (default: "2")
  - `axis_label_rotation` - X-axis label rotation: :auto, :"45", :"90" (default: :auto)
  - `colours` - List of hex color codes without # (default: [])

  ## Data Format

  Area charts use the same format as line charts:

      [
        %{x: 1, y: 100},
        %{x: 2, y: 150},
        %{x: 3, y: 120}
      ]

  For stacked area charts with multiple series:

      [
        %{date: ~D[2024-01-01], series_a: 100, series_b: 50},
        %{date: ~D[2024-01-02], series_a: 120, series_b: 60}
      ]
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :title, :string
    field :mode, Ecto.Enum, values: [:simple, :stacked], default: :simple
    field :opacity, :float, default: 0.7
    field :smooth_lines, :boolean, default: true
    # LinePlot inherited fields
    field :smoothed, :boolean, default: true
    field :stroke_width, :string, default: "2"
    field :axis_label_rotation, Ecto.Enum, values: [:auto, :"45", :"90"], default: :auto
    field :colours, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          title: String.t() | nil,
          mode: :simple | :stacked,
          opacity: float(),
          smooth_lines: boolean(),
          smoothed: boolean(),
          stroke_width: String.t(),
          axis_label_rotation: :auto | :"45" | :"90",
          colours: [String.t()]
        }

  @doc """
  Creates a changeset for area chart configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `mode` must be one of: :simple, :stacked
  - `opacity` must be between 0.0 and 1.0
  - `stroke_width` must be a string
  - `axis_label_rotation` must be one of: :auto, :"45", :"90"
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [
      :width,
      :height,
      :title,
      :mode,
      :opacity,
      :smooth_lines,
      :smoothed,
      :stroke_width,
      :axis_label_rotation,
      :colours
    ])
    |> validate_required([:width, :height, :opacity, :stroke_width])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:opacity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_inclusion(:mode, [:simple, :stacked])
    |> validate_inclusion(:axis_label_rotation, [:auto, :"45", :"90"])
  end
end
