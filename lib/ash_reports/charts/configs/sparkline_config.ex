defmodule AshReports.Charts.SparklineConfig do
  @moduledoc """
  Configuration struct for sparkline charts using Contex Sparkline.

  This module defines the configuration options for sparkline generation,
  mapping to Contex Sparkline options. Sparklines are ultra-compact inline
  charts (default 100px × 20px) ideal for embedding in dashboards, tables,
  and tight spaces.

  ## Contex Mapping

  This struct maps to Contex.Sparkline options:
  - `spot_radius` → `:spot_radius` (integer for highlighted spots)
  - `spot_colour` → `:spot_colour` (CSS color string)
  - `line_width` → `:line_width` (integer)
  - `line_colour` → `:line_colour` (CSS color string)
  - `fill_colour` → `:fill_colour` (CSS color string)

  ## DSL Usage

      sparkline :trend do
        data_source expr(daily_metrics())
        config do
          width 100
          height 20
          spot_radius 2
          spot_colour "red"
          line_width 1
          line_colour "rgba(0, 200, 50, 0.7)"
          fill_colour "rgba(0, 200, 50, 0.2)"
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 100)
  - `height` - Chart height in pixels (default: 20)
  - `spot_radius` - Radius of highlighted spots (default: 2)
  - `spot_colour` - CSS color for spots (default: "red")
  - `line_width` - Line thickness in pixels (default: 1)
  - `line_colour` - CSS color for line (default: "rgba(0, 200, 50, 0.7)")
  - `fill_colour` - CSS color for fill area (default: "rgba(0, 200, 50, 0.2)")

  ## Data Format

  **Note**: Sparkline is unique - it accepts a simple list of numbers,
  not a list of maps like other chart types.

  Simple array of numbers:

      [1, 5, 10, 15, 12, 12, 15, 14, 20, 14, 10, 15, 15]

  Or map format with value key:

      [
        %{value: 10},
        %{value: 15},
        %{value: 12}
      ]

  ## Compact Sizing

  Sparklines default to compact dimensions (100×20) suitable for inline
  display. These defaults differ from other chart types (600×400).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 100
    field :height, :integer, default: 20
    field :spot_radius, :integer, default: 2
    field :spot_colour, :string, default: "red"
    field :line_width, :integer, default: 1
    field :line_colour, :string, default: "rgba(0, 200, 50, 0.7)"
    field :fill_colour, :string, default: "rgba(0, 200, 50, 0.2)"
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          spot_radius: integer(),
          spot_colour: String.t(),
          line_width: integer(),
          line_colour: String.t(),
          fill_colour: String.t()
        }

  @doc """
  Creates a changeset for sparkline configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `spot_radius` must be non-negative
  - `line_width` must be positive
  - All colour fields must be strings (CSS color values)
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [:width, :height, :spot_radius, :spot_colour, :line_width, :line_colour, :fill_colour])
    |> validate_required([:width, :height, :spot_radius, :spot_colour, :line_width, :line_colour, :fill_colour])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:spot_radius, greater_than_or_equal_to: 0)
    |> validate_number(:line_width, greater_than: 0)
  end
end
