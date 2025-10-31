defmodule AshReports.Charts.PieChartConfig do
  @moduledoc """
  Configuration struct for pie charts using Contex PieChart.

  This module defines the configuration options for pie chart generation,
  mapping to Contex PieChart options. Pie charts are ideal for showing
  proportions and parts of a whole.

  ## Contex Mapping

  This struct maps to Contex.PieChart options:
  - `data_labels` → `:data_labels` (boolean to show slice values)
  - `colours` → `:colour_palette` (list of hex colors without #)

  ## DSL Usage

      pie_chart :market_share do
        data_source expr(market_segments())
        config do
          width 600
          height 400
          title "Market Share by Segment"
          data_labels true
          colours ["FF6384", "36A2EB", "FFCE56", "4BC0C0"]
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 600)
  - `height` - Chart height in pixels (default: 400)
  - `title` - Chart title (optional)
  - `data_labels` - Show values on pie slices (default: true)
  - `colours` - List of hex color codes without # (default: [])

  ## Data Format

  Pie charts expect data with category and value fields:

      [
        %{category: "Product A", value: 300},
        %{category: "Product B", value: 500},
        %{category: "Product C", value: 200}
      ]

  The values will be automatically converted to percentages for display.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :title, :string
    field :data_labels, :boolean, default: true
    field :colours, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          title: String.t() | nil,
          data_labels: boolean(),
          colours: [String.t()]
        }

  @doc """
  Creates a changeset for pie chart configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `colours` must be a list of strings (hex codes without #)
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [:width, :height, :title, :data_labels, :colours])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end
end
