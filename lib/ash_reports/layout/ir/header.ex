defmodule AshReports.Layout.IR.Header do
  @moduledoc """
  Intermediate Representation for table headers.

  Headers define repeating row sections at the top of tables that can
  repeat on each page or at group boundaries.

  ## Repeat Behavior

  - `true` - Header repeats on every page
  - `false` - Header appears only at the start
  - `:group` - Header repeats at group boundaries

  ## Examples

      header = AshReports.Layout.IR.Header.new(
        repeat: true,
        level: 1,
        rows: [row_ir1, row_ir2]
      )
  """

  alias AshReports.Layout.IR.Row

  @type repeat :: boolean() | :group

  @type t :: %__MODULE__{
          repeat: repeat(),
          level: non_neg_integer(),
          rows: [Row.t()]
        }

  defstruct [
    repeat: true,
    level: 0,
    rows: []
  ]

  @doc """
  Creates a new HeaderIR struct with the given options.

  ## Options

  - `:repeat` - Repeat behavior (default: `true`)
  - `:level` - Header level for nested headers (default: 0)
  - `:rows` - List of RowIR for header content

  ## Examples

      iex> AshReports.Layout.IR.Header.new(repeat: true, rows: [row])
      %AshReports.Layout.IR.Header{repeat: true, rows: [row], ...}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      repeat: Keyword.get(opts, :repeat, true),
      level: Keyword.get(opts, :level, 0),
      rows: Keyword.get(opts, :rows, [])
    }
  end

  @doc """
  Adds a row to the header.
  """
  @spec add_row(t(), Row.t()) :: t()
  def add_row(%__MODULE__{} = header, row) do
    %{header | rows: header.rows ++ [row]}
  end

  @doc """
  Returns the number of rows in the header.
  """
  @spec row_count(t()) :: non_neg_integer()
  def row_count(%__MODULE__{rows: rows}), do: length(rows)
end
