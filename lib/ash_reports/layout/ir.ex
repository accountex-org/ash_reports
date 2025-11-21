defmodule AshReports.Layout.IR do
  @moduledoc """
  Intermediate Representation (IR) for layout containers.

  This module defines the core IR type structures that represent layout containers
  (Grid, Table, Stack) in a normalized format suitable for all renderers. The IR
  handles cell positioning calculations, spanning logic, and provides a consistent
  data structure for Typst, HTML, and JSON output.

  ## Usage

      # Create a grid IR
      grid_ir = %AshReports.Layout.IR{
        type: :grid,
        properties: %{columns: ["1fr", "2fr"], rows: ["auto"]},
        children: [cell_ir1, cell_ir2],
        lines: []
      }

  ## Types

  The IR supports three layout types:
  - `:grid` - CSS Grid-like layout with explicit columns/rows
  - `:table` - Table with headers/footers
  - `:stack` - Flexbox-like stack layout
  """

  alias AshReports.Layout.IR.{Cell, Row, Content, Line, Header, Footer}

  @type layout_type :: :grid | :table | :stack

  @type child :: Cell.t() | Row.t() | Content.t()

  @type t :: %__MODULE__{
          type: layout_type(),
          properties: map(),
          children: [child()],
          lines: [Line.t()],
          headers: [Header.t()],
          footers: [Footer.t()]
        }

  defstruct [
    :type,
    properties: %{},
    children: [],
    lines: [],
    headers: [],
    footers: []
  ]

  @doc """
  Creates a new LayoutIR struct with the given type and options.

  ## Options

  - `:properties` - Map of normalized property values
  - `:children` - List of CellIR, RowIR, or ContentIR
  - `:lines` - List of LineIR for hline/vline
  - `:headers` - List of HeaderIR (for tables)
  - `:footers` - List of FooterIR (for tables)

  ## Examples

      iex> AshReports.Layout.IR.new(:grid, properties: %{columns: ["1fr", "1fr"]})
      %AshReports.Layout.IR{type: :grid, properties: %{columns: ["1fr", "1fr"]}, ...}
  """
  @spec new(layout_type(), Keyword.t()) :: t()
  def new(type, opts \\ []) when type in [:grid, :table, :stack] do
    %__MODULE__{
      type: type,
      properties: Keyword.get(opts, :properties, %{}),
      children: Keyword.get(opts, :children, []),
      lines: Keyword.get(opts, :lines, []),
      headers: Keyword.get(opts, :headers, []),
      footers: Keyword.get(opts, :footers, [])
    }
  end

  @doc """
  Creates a grid IR with the given properties.
  """
  @spec grid(Keyword.t()) :: t()
  def grid(opts \\ []) do
    new(:grid, opts)
  end

  @doc """
  Creates a table IR with the given properties.
  """
  @spec table(Keyword.t()) :: t()
  def table(opts \\ []) do
    new(:table, opts)
  end

  @doc """
  Creates a stack IR with the given properties.
  """
  @spec stack(Keyword.t()) :: t()
  def stack(opts \\ []) do
    new(:stack, opts)
  end

  @doc """
  Adds a child to the layout IR.
  """
  @spec add_child(t(), child()) :: t()
  def add_child(%__MODULE__{} = ir, child) do
    %{ir | children: ir.children ++ [child]}
  end

  @doc """
  Adds a line to the layout IR.
  """
  @spec add_line(t(), Line.t()) :: t()
  def add_line(%__MODULE__{} = ir, line) do
    %{ir | lines: ir.lines ++ [line]}
  end

  @doc """
  Adds a header to the layout IR (for tables).
  """
  @spec add_header(t(), Header.t()) :: t()
  def add_header(%__MODULE__{} = ir, header) do
    %{ir | headers: ir.headers ++ [header]}
  end

  @doc """
  Adds a footer to the layout IR (for tables).
  """
  @spec add_footer(t(), Footer.t()) :: t()
  def add_footer(%__MODULE__{} = ir, footer) do
    %{ir | footers: ir.footers ++ [footer]}
  end

  @doc """
  Sets a property on the layout IR.
  """
  @spec put_property(t(), atom(), any()) :: t()
  def put_property(%__MODULE__{} = ir, key, value) do
    %{ir | properties: Map.put(ir.properties, key, value)}
  end

  @doc """
  Gets a property from the layout IR.
  """
  @spec get_property(t(), atom(), any()) :: any()
  def get_property(%__MODULE__{} = ir, key, default \\ nil) do
    Map.get(ir.properties, key, default)
  end
end
