defmodule AshReports.Layout.Stack do
  @moduledoc """
  A stack layout container that maps to Typst's stack() function.

  Stacks arrange elements in a single direction with configurable spacing.
  Useful for simple linear layouts.

  ## Direction Options

  - `:ttb` - Top to bottom (default, equivalent to :vertical)
  - `:btt` - Bottom to top
  - `:ltr` - Left to right (equivalent to :horizontal)
  - `:rtl` - Right to left

  ## Example

      stack :address_info do
        dir :ttb
        spacing "3pt"

        label :street do
          text "[street_address]"
        end

        label :city_state do
          text "[city], [state] [zip]"
        end

        label :country do
          text "[country]"
        end
      end

  """

  @type direction :: :ttb | :btt | :ltr | :rtl

  @type t :: %__MODULE__{
          name: atom(),
          dir: direction(),
          spacing: String.t() | nil,
          elements: [map()]
        }

  defstruct [
    :name,
    dir: :ttb,
    spacing: nil,
    elements: []
  ]
end
