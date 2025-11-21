defmodule AshReports.Layout.Footer do
  @moduledoc """
  A table footer section that can repeat on each page.

  Footers are semantic table sections that can be configured to repeat when
  the table spans multiple pages, supporting accessibility requirements.

  ## Example

      table :data_table do
        columns [fr(1), fr(2), fr(1)]

        # Header and data cells...

        footer repeat: true do
          cell colspan: 2 do
            label text: "Total"
          end

          cell do
            field source: :grand_total, format: :currency
          end
        end
      end

  """

  @type t :: %__MODULE__{
          name: atom() | nil,
          repeat: boolean(),
          table_cells: [AshReports.Layout.TableCell.t()]
        }

  defstruct [
    :name,
    repeat: true,
    table_cells: []
  ]
end
