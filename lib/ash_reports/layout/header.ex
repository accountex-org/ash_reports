defmodule AshReports.Layout.Header do
  @moduledoc """
  A table header section that can repeat on each page.

  Headers are semantic table sections that can be configured to repeat when
  the table spans multiple pages, supporting accessibility requirements.

  ## Example

      table :data_table do
        columns [fr(1), fr(2), fr(1)]

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

        # Data cells follow...
      end

  Multiple header levels can be used for cascading headers:

      header repeat: true, level: 1 do
        # Primary header
      end

      header repeat: true, level: 2 do
        # Secondary header
      end

  """

  @type t :: %__MODULE__{
          name: atom() | nil,
          repeat: boolean(),
          level: pos_integer(),
          table_cells: [AshReports.Layout.TableCell.t()]
        }

  defstruct [
    :name,
    repeat: true,
    level: 1,
    table_cells: []
  ]
end
