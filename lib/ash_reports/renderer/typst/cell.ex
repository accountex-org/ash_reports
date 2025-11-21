defmodule AshReports.Renderer.Typst.Cell do
  @moduledoc """
  Typst renderer for cell elements.

  Generates Typst grid.cell() or table.cell() function calls from CellIR with
  support for:
  - colspan and rowspan
  - align, fill, inset overrides
  - breakable parameter
  - Simple bracket syntax for cells without overrides

  ## Examples

      # Simple cell renders as bracketed content
      iex> cell = %AshReports.Layout.IR.Cell{content: [%{text: "Hello"}]}
      iex> AshReports.Renderer.Typst.Cell.render(cell)
      "[Hello]"

      # Cell with colspan uses grid.cell()
      iex> cell = %AshReports.Layout.IR.Cell{span: {2, 1}, content: [%{text: "Wide"}]}
      iex> AshReports.Renderer.Typst.Cell.render(cell)
      "grid.cell(colspan: 2)[Wide]"
  """

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Typst.{Content, Grid}

  @doc """
  Renders a CellIR to Typst markup.

  ## Parameters

  - `cell` - The CellIR struct to render
  - `opts` - Rendering options
    - `:indent` - Current indentation level
    - `:context` - Layout context (:grid or :table)
    - `:data` - Data context for field interpolation

  ## Returns

  String containing the Typst cell markup.
  """
  @spec render(IR.Cell.t(), keyword()) :: String.t()
  def render(%IR.Cell{} = cell, opts \\ []) do
    indent = Keyword.get(opts, :indent, 0)
    context = Keyword.get(opts, :context, :grid)
    indent_str = String.duplicate("  ", indent)

    content = render_cell_content(cell.content, opts)
    params = build_cell_parameters(cell, context)

    if params == "" do
      # Simple bracket syntax for cells without parameters
      "#{indent_str}[#{content}]"
    else
      # Full cell() syntax with parameters
      prefix = cell_prefix(context)
      "#{indent_str}#{prefix}(#{params})[#{content}]"
    end
  end

  @doc """
  Builds the parameter list for a cell() call.

  Returns empty string if no parameters are needed (simple bracket syntax).
  """
  @spec build_cell_parameters(IR.Cell.t(), atom()) :: String.t()
  def build_cell_parameters(%IR.Cell{} = cell, _context) do
    params =
      []
      |> maybe_add_colspan(cell)
      |> maybe_add_rowspan(cell)
      |> maybe_add_align(cell)
      |> maybe_add_fill(cell)
      |> maybe_add_inset(cell)
      |> maybe_add_breakable(cell)
      |> Enum.reverse()

    Enum.join(params, ", ")
  end

  # Parameter builders

  defp maybe_add_colspan(params, %IR.Cell{span: {colspan, _rowspan}}) when colspan > 1 do
    ["colspan: #{colspan}" | params]
  end

  defp maybe_add_colspan(params, _), do: params

  defp maybe_add_rowspan(params, %IR.Cell{span: {_colspan, rowspan}}) when rowspan > 1 do
    ["rowspan: #{rowspan}" | params]
  end

  defp maybe_add_rowspan(params, _), do: params

  defp maybe_add_align(params, %IR.Cell{properties: %{align: align}}) when not is_nil(align) do
    ["align: #{Grid.render_alignment(align)}" | params]
  end

  defp maybe_add_align(params, _), do: params

  defp maybe_add_fill(params, %IR.Cell{properties: %{fill: fill}}) when not is_nil(fill) do
    ["fill: #{Grid.render_fill(fill)}" | params]
  end

  defp maybe_add_fill(params, _), do: params

  defp maybe_add_inset(params, %IR.Cell{properties: %{inset: inset}}) when not is_nil(inset) do
    ["inset: #{Grid.render_length(inset)}" | params]
  end

  defp maybe_add_inset(params, _), do: params

  defp maybe_add_breakable(params, %IR.Cell{properties: %{breakable: false}}) do
    ["breakable: false" | params]
  end

  defp maybe_add_breakable(params, _), do: params

  # Content rendering

  defp render_cell_content([], _opts), do: ""

  defp render_cell_content(content, opts) do
    content
    |> Enum.map(fn item -> Content.render(item, opts) end)
    |> Enum.join(" ")
  end

  # Context helpers

  defp cell_prefix(:table), do: "table.cell"
  defp cell_prefix(_), do: "grid.cell"

  @doc """
  Checks if a cell needs the full cell() syntax or can use simple brackets.

  Returns true if the cell has any parameters that require the full syntax.
  """
  @spec needs_cell_syntax?(IR.Cell.t()) :: boolean()
  def needs_cell_syntax?(%IR.Cell{span: {colspan, rowspan}, properties: properties}) do
    colspan > 1 or
      rowspan > 1 or
      Map.has_key?(properties, :align) or
      Map.has_key?(properties, :fill) or
      Map.has_key?(properties, :inset) or
      Map.get(properties, :breakable) == false
  end
end
