defmodule AshReports.Layout.IR.Footer do
  @moduledoc """
  Intermediate Representation for table footers.

  Footers define repeating row sections at the bottom of tables that can
  repeat on each page.

  ## Examples

      footer = AshReports.Layout.IR.Footer.new(
        repeat: true,
        rows: [totals_row_ir]
      )
  """

  alias AshReports.Layout.IR.Row

  @type t :: %__MODULE__{
          repeat: boolean(),
          rows: [Row.t()]
        }

  defstruct [
    repeat: false,
    rows: []
  ]

  @doc """
  Creates a new FooterIR struct with the given options.

  ## Options

  - `:repeat` - Whether to repeat on each page (default: `false`)
  - `:rows` - List of RowIR for footer content

  ## Examples

      iex> AshReports.Layout.IR.Footer.new(repeat: true, rows: [row])
      %AshReports.Layout.IR.Footer{repeat: true, rows: [row], ...}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      repeat: Keyword.get(opts, :repeat, false),
      rows: Keyword.get(opts, :rows, [])
    }
  end

  @doc """
  Adds a row to the footer.
  """
  @spec add_row(t(), Row.t()) :: t()
  def add_row(%__MODULE__{} = footer, row) do
    %{footer | rows: footer.rows ++ [row]}
  end

  @doc """
  Returns the number of rows in the footer.
  """
  @spec row_count(t()) :: non_neg_integer()
  def row_count(%__MODULE__{rows: rows}), do: length(rows)
end
