defmodule AshReports.Layout.GridCell do
  @moduledoc """
  An individual cell within grid layouts with positioning support.

  Grid cells can be explicitly positioned using x/y coordinates and override
  parent properties like alignment, fill, stroke, and padding. They contain
  only leaf elements (no nested containers).

  ## Example

      grid_cell do
        x 0
        y 1
        align :right
        fill "#e0e0e0"

        field source: :total, format: :currency
      end

  """

  @type alignment :: atom() | {atom(), atom()} | nil

  @type t :: %__MODULE__{
          name: atom() | nil,
          x: non_neg_integer() | nil,
          y: non_neg_integer() | nil,
          align: alignment(),
          fill: String.t() | nil,
          stroke: String.t() | nil,
          inset: String.t() | nil,
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
    elements: []
  ]
end
