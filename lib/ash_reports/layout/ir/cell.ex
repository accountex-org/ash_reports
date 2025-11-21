defmodule AshReports.Layout.IR.Cell do
  @moduledoc """
  Intermediate Representation for a cell in a layout.

  The CellIR represents a single cell with its calculated position,
  span information, properties, and content.

  ## Position

  Position is represented as a `{x, y}` tuple where:
  - `x` is the column index (0-indexed)
  - `y` is the row index (0-indexed)

  ## Span

  Span is represented as a `{colspan, rowspan}` tuple where:
  - `colspan` is the number of columns the cell spans (default: 1)
  - `rowspan` is the number of rows the cell spans (default: 1)

  ## Examples

      # Cell at position (0, 0) with default span
      cell = AshReports.Layout.IR.Cell.new(
        position: {0, 0},
        content: [label_ir]
      )

      # Cell with colspan of 2
      cell = AshReports.Layout.IR.Cell.new(
        position: {1, 0},
        span: {2, 1},
        content: [field_ir]
      )
  """

  alias AshReports.Layout.IR.Content

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type span :: {pos_integer(), pos_integer()}

  @type t :: %__MODULE__{
          position: position(),
          span: span(),
          properties: map(),
          content: [Content.t()]
        }

  defstruct [
    position: {0, 0},
    span: {1, 1},
    properties: %{},
    content: []
  ]

  @doc """
  Creates a new CellIR struct with the given options.

  ## Options

  - `:position` - `{x, y}` tuple for cell position (default: `{0, 0}`)
  - `:span` - `{colspan, rowspan}` tuple (default: `{1, 1}`)
  - `:properties` - Map of cell properties (align, inset, fill, etc.)
  - `:content` - List of ContentIR items

  ## Examples

      iex> AshReports.Layout.IR.Cell.new(position: {1, 2}, span: {2, 1})
      %AshReports.Layout.IR.Cell{position: {1, 2}, span: {2, 1}, ...}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      position: Keyword.get(opts, :position, {0, 0}),
      span: Keyword.get(opts, :span, {1, 1}),
      properties: Keyword.get(opts, :properties, %{}),
      content: Keyword.get(opts, :content, [])
    }
  end

  @doc """
  Returns the x (column) coordinate of the cell.
  """
  @spec x(t()) :: non_neg_integer()
  def x(%__MODULE__{position: {x, _y}}), do: x

  @doc """
  Returns the y (row) coordinate of the cell.
  """
  @spec y(t()) :: non_neg_integer()
  def y(%__MODULE__{position: {_x, y}}), do: y

  @doc """
  Returns the colspan of the cell.
  """
  @spec colspan(t()) :: pos_integer()
  def colspan(%__MODULE__{span: {colspan, _rowspan}}), do: colspan

  @doc """
  Returns the rowspan of the cell.
  """
  @spec rowspan(t()) :: pos_integer()
  def rowspan(%__MODULE__{span: {_colspan, rowspan}}), do: rowspan

  @doc """
  Returns all positions occupied by this cell (including spans).

  ## Examples

      iex> cell = AshReports.Layout.IR.Cell.new(position: {1, 0}, span: {2, 2})
      iex> AshReports.Layout.IR.Cell.occupied_positions(cell)
      [{1, 0}, {2, 0}, {1, 1}, {2, 1}]
  """
  @spec occupied_positions(t()) :: [position()]
  def occupied_positions(%__MODULE__{position: {x, y}, span: {colspan, rowspan}}) do
    for dx <- 0..(colspan - 1),
        dy <- 0..(rowspan - 1),
        do: {x + dx, y + dy}
  end

  @doc """
  Adds content to the cell.
  """
  @spec add_content(t(), Content.t()) :: t()
  def add_content(%__MODULE__{} = cell, content) do
    %{cell | content: cell.content ++ [content]}
  end

  @doc """
  Sets a property on the cell.
  """
  @spec put_property(t(), atom(), any()) :: t()
  def put_property(%__MODULE__{} = cell, key, value) do
    %{cell | properties: Map.put(cell.properties, key, value)}
  end

  @doc """
  Gets a property from the cell.
  """
  @spec get_property(t(), atom(), any()) :: any()
  def get_property(%__MODULE__{} = cell, key, default \\ nil) do
    Map.get(cell.properties, key, default)
  end
end
