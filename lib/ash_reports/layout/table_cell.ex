defmodule AshReports.Layout.TableCell do
  @moduledoc """
  An individual cell within table layouts with spanning and positioning.

  Table cells can span multiple columns/rows and override parent properties like
  alignment, fill, stroke, and padding. They contain only leaf elements (no nested
  containers).

  ## Example

      table_cell do
        colspan 2
        rowspan 1
        align :right
        fill "#e0e0e0"

        field source: :total, format: :currency
      end

      # Explicit positioning
      table_cell x: 0, y: 1 do
        label text: "Positioned cell"
      end

  """

  @type alignment :: atom() | {atom(), atom()} | nil

  @type t :: %__MODULE__{
          name: atom() | nil,
          colspan: pos_integer(),
          rowspan: pos_integer(),
          x: non_neg_integer() | nil,
          y: non_neg_integer() | nil,
          align: alignment(),
          fill: String.t() | nil,
          stroke: String.t() | nil,
          inset: String.t() | nil,
          breakable: boolean(),
          elements: [map()]
        }

  defstruct [
    :name,
    :x,
    :y,
    :align,
    :fill,
    :stroke,
    :inset,
    colspan: 1,
    rowspan: 1,
    breakable: true,
    elements: []
  ]
end
