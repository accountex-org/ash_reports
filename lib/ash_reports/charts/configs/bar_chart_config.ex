defmodule AshReports.Charts.BarChartConfig do
  @moduledoc """
  Configuration struct for bar charts using Contex BarChart.

  This module defines the configuration options for bar chart generation,
  mapping to Contex BarChart options. Bar charts are ideal for comparing
  values across categories.

  ## Contex Mapping

  This struct maps to Contex.BarChart options:
  - `type` → `:type` (:simple, :grouped, :stacked)
  - `orientation` → `:orientation` (:vertical, :horizontal)
  - `data_labels` → `:data_labels` (boolean)
  - `padding` → `:padding` (integer between bars)
  - `colours` → `:colour_palette` (list of hex colors without #)

  ## DSL Usage

      bar_chart :sales_by_region do
        data_source expr(aggregate_sales_by_region())
        config do
          width 600
          height 400
          title "Sales by Region"
          type :grouped
          orientation :vertical
          data_labels true
          padding 2
          colours ["FF6384", "36A2EB", "FFCE56"]
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 600)
  - `height` - Chart height in pixels (default: 400)
  - `title` - Chart title (optional)
  - `type` - Bar chart type: :simple, :grouped, :stacked (default: :simple)
  - `orientation` - Bar orientation: :vertical, :horizontal (default: :vertical)
  - `data_labels` - Show data values on bars (default: true)
  - `padding` - Padding between bars in pixels (default: 2)
  - `colours` - List of hex color codes without # (default: [])

  ## Data Format

  Bar charts expect data with `category` and `value` fields:

      [
        %{category: "North", value: 15000},
        %{category: "South", value: 12000},
        %{category: "East", value: 18000}
      ]

  For grouped/stacked bars, use multiple value columns:

      [
        %{category: "Q1", product_a: 100, product_b: 150},
        %{category: "Q2", product_a: 120, product_b: 180}
      ]
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :title, :string
    field :type, Ecto.Enum, values: [:simple, :grouped, :stacked], default: :simple
    field :orientation, Ecto.Enum, values: [:vertical, :horizontal], default: :vertical
    field :data_labels, :boolean, default: true
    field :padding, :integer, default: 2
    field :colours, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          title: String.t() | nil,
          type: :simple | :grouped | :stacked,
          orientation: :vertical | :horizontal,
          data_labels: boolean(),
          padding: integer(),
          colours: [String.t()]
        }

  @doc """
  Creates a changeset for bar chart configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `type` must be one of: :simple, :grouped, :stacked
  - `orientation` must be one of: :vertical, :horizontal
  - `padding` must be non-negative
  - `colours` must be a list of strings (hex codes without #)
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [:width, :height, :title, :type, :orientation, :data_labels, :padding, :colours])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:padding, greater_than_or_equal_to: 0)
    |> validate_inclusion(:type, [:simple, :grouped, :stacked])
    |> validate_inclusion(:orientation, [:vertical, :horizontal])
  end
end
