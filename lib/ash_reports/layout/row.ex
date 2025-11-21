defmodule AshReports.Layout.Row do
  @moduledoc """
  An explicit row container within grid/table layouts.

  Rows allow explicit grouping of cells with shared properties like height,
  fill, stroke, and default alignment/padding that propagate to child cells.

  ## Example

      row :header_row do
        height "30pt"
        fill "#f0f0f0"
        align :center

        cell do
          label text: "Name"
        end

        cell do
          label text: "Value"
        end
      end

  """

  @type alignment :: atom() | {atom(), atom()} | nil

  @type t :: %__MODULE__{
          name: atom(),
          height: String.t() | nil,
          fill: String.t() | nil,
          stroke: String.t() | nil,
          align: alignment(),
          inset: String.t() | nil,
          elements: [map()]
        }

  defstruct [
    :name,
    :height,
    :fill,
    :stroke,
    :align,
    :inset,
    elements: []
  ]
end
