defmodule AshReports.Layout.Row do
  @moduledoc """
  A row layout container for organizing elements horizontally within a band.

  Rows are converted to Typst grid cells, where each element in the row
  occupies a column position.

  ## Example

      row :summary_row do
        spacing "5pt"

        label :count do
          text "Count: [group_count]"
        end

        label :total do
          text "Total: [group_total]"
        end
      end

  """

  @type t :: %__MODULE__{
          name: atom(),
          spacing: String.t() | nil,
          elements: [map()]
        }

  defstruct [
    :name,
    spacing: "5pt",
    elements: []
  ]
end
