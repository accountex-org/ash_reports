defmodule AshReports.Layout.IR.Row do
  @moduledoc """
  Intermediate Representation for a row in a layout.

  The RowIR represents a single row containing cells with shared row-level
  properties that can be inherited by cells.

  ## Usage

      row = AshReports.Layout.IR.Row.new(
        properties: %{align: :center},
        cells: [cell1, cell2, cell3]
      )

  ## Property Inheritance

  Row properties can be inherited by cells. The inheritance chain is:
  grid/table -> row -> cell -> content
  """

  alias AshReports.Layout.IR.Cell

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          properties: map(),
          cells: [Cell.t()]
        }

  defstruct [
    index: 0,
    properties: %{},
    cells: []
  ]

  @doc """
  Creates a new RowIR struct with the given options.

  ## Options

  - `:index` - Row index (0-indexed, default: 0)
  - `:properties` - Map of row properties (align, fill, etc.)
  - `:cells` - List of CellIR items

  ## Examples

      iex> AshReports.Layout.IR.Row.new(index: 1, cells: [cell1, cell2])
      %AshReports.Layout.IR.Row{index: 1, cells: [cell1, cell2], ...}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      index: Keyword.get(opts, :index, 0),
      properties: Keyword.get(opts, :properties, %{}),
      cells: Keyword.get(opts, :cells, [])
    }
  end

  @doc """
  Adds a cell to the row.
  """
  @spec add_cell(t(), Cell.t()) :: t()
  def add_cell(%__MODULE__{} = row, cell) do
    %{row | cells: row.cells ++ [cell]}
  end

  @doc """
  Sets a property on the row.
  """
  @spec put_property(t(), atom(), any()) :: t()
  def put_property(%__MODULE__{} = row, key, value) do
    %{row | properties: Map.put(row.properties, key, value)}
  end

  @doc """
  Gets a property from the row.
  """
  @spec get_property(t(), atom(), any()) :: any()
  def get_property(%__MODULE__{} = row, key, default \\ nil) do
    Map.get(row.properties, key, default)
  end

  @doc """
  Returns the number of cells in the row.
  """
  @spec cell_count(t()) :: non_neg_integer()
  def cell_count(%__MODULE__{cells: cells}), do: length(cells)
end
