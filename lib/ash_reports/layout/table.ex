defmodule AshReports.Layout.Table do
  @moduledoc """
  A table layout container that maps to Typst's table() function.

  Tables are intended for tabular data where the arrangement of cells
  conveys information. Unlike grids, tables carry semantic meaning and
  are accessible to assistive technologies.

  Tables have different defaults than grids:
  - `stroke` defaults to "1pt" for visible borders
  - `inset` defaults to "5pt" for cell padding

  ## Example

      table :data_table do
        columns [fr(1), fr(2), fr(1)]
        stroke "0.5pt"
        inset "5pt"

        header repeat: true do
          cell do
            label text: "Name"
          end
          cell do
            label text: "Description"
          end
          cell do
            label text: "Value"
          end
        end

        # Data rows follow...
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
          headers: [map()],
          footers: [map()]
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
    inset: "5pt",
    stroke: "1pt",
    elements: [],
    headers: [],
    footers: []
  ]
end
