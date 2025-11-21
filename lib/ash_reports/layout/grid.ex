defmodule AshReports.Layout.Grid do
  @moduledoc """
  A grid layout container that maps to Typst's grid() function.

  Grids provide flexible layout capabilities with configurable columns and rows.
  Use grids for layout/presentation purposes where the arrangement itself
  doesn't convey tabular data semantics.

  ## Example

      grid :metrics_grid do
        columns 3
        rows 2
        gutter "5pt"

        label :label1 do
          text "Revenue"
        end

        label :label2 do
          text "Costs"
        end

        label :label3 do
          text "Profit"
        end

        field :revenue do
          source :total_revenue
          format :currency
        end

        field :costs do
          source :total_costs
          format :currency
        end

        field :profit do
          source :net_profit
          format :currency
        end
      end

  """

  @type track_size :: pos_integer() | String.t() | :auto | {:fr, number()}
  @type alignment :: atom() | {atom(), atom()} | nil

  @type t :: %__MODULE__{
          name: atom(),
          columns: pos_integer() | [track_size()],
          rows: pos_integer() | [track_size()] | :auto | nil,
          gutter: String.t() | nil,
          column_gutter: String.t() | nil,
          row_gutter: String.t() | nil,
          align: alignment(),
          inset: String.t() | nil,
          fill: String.t() | (integer(), integer() -> String.t()) | nil,
          stroke: String.t() | nil,
          elements: [map()],
          row_entities: [AshReports.Layout.Row.t()],
          grid_cells: [AshReports.Layout.GridCell.t()]
        }

  defstruct [
    :name,
    :column_gutter,
    :row_gutter,
    :fill,
    columns: 1,
    rows: nil,
    gutter: nil,
    align: nil,
    inset: nil,
    stroke: :none,
    elements: [],
    row_entities: [],
    grid_cells: []
  ]
end
