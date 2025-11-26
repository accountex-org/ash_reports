defmodule AshReports.Renderer.Typst.Table do
  @moduledoc """
  Typst renderer for table layouts.

  Generates Typst table() function calls from TableIR with all supported properties.
  Tables extend grids with:
  - table.header() sections
  - table.footer() sections
  - Default stroke of "1pt"

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :table, properties: %{columns: ["1fr", "2fr"]}}
      iex> AshReports.Renderer.Typst.Table.render(ir)
      "#table(\\n  columns: (1fr, 2fr),\\n  stroke: 1pt,\\n)"
  """

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Typst.{Cell, Grid}

  @default_stroke "1pt"

  @doc """
  Renders a TableIR to Typst table() markup.

  ## Parameters

  - `ir` - The TableIR struct to render
  - `opts` - Rendering options (reserved for future use)

  ## Returns

  String containing the Typst table() function call.
  """
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: :table} = ir, opts \\ []) do
    indent = Keyword.get(opts, :indent, 0)
    indent_str = String.duplicate("  ", indent)

    # Apply table defaults
    properties = apply_table_defaults(ir.properties)

    params = Grid.build_parameters(properties)
    headers = render_headers(ir.headers, indent + 1, opts)
    footers = render_footers(ir.footers, indent + 1, opts)
    children = render_children(ir.children, indent + 1, opts)

    content =
      [headers, children, footers]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(",\n")

    if content == "" do
      "#{indent_str}#table(\n#{params}#{indent_str})"
    else
      "#{indent_str}#table(\n#{params}#{content}\n#{indent_str})"
    end
  end

  @doc """
  Applies table-specific defaults to properties.

  Tables have a default stroke of "1pt".
  """
  @spec apply_table_defaults(map()) :: map()
  def apply_table_defaults(properties) do
    Map.put_new(properties, :stroke, @default_stroke)
  end

  # Header rendering

  @doc """
  Renders table headers to Typst table.header() calls.

  ## Parameters

  - `headers` - List of HeaderIR structs
  - `indent` - Current indentation level

  ## Returns

  String containing Typst table.header() markup.
  """
  @spec render_headers([IR.Header.t()], non_neg_integer(), keyword()) :: String.t()
  def render_headers(headers, indent, parent_opts \\ [])
  def render_headers([], _indent, _parent_opts), do: ""

  def render_headers(headers, indent, parent_opts) do
    indent_str = String.duplicate("  ", indent)

    headers
    |> Enum.map(fn header -> render_header(header, indent_str, indent, parent_opts) end)
    |> Enum.join("\n")
  end

  defp render_header(%IR.Header{repeat: repeat, rows: rows}, indent_str, indent, parent_opts) do
    repeat_param = if repeat, do: "repeat: true, ", else: ""
    cells = render_header_rows(rows, indent + 1, parent_opts)

    if cells == "" do
      "#{indent_str}table.header(#{repeat_param})"
    else
      "#{indent_str}table.header(#{repeat_param}\n#{cells}\n#{indent_str})"
    end
  end

  defp render_header(_header, indent_str, _indent, _parent_opts) do
    # Fallback for non-struct headers
    "#{indent_str}table.header()"
  end

  defp render_header_rows([], _indent, _parent_opts), do: ""

  defp render_header_rows(rows, indent, parent_opts) do
    opts = Keyword.merge(parent_opts, [indent: indent, context: :table])

    rows
    |> Enum.flat_map(fn row -> extract_row_cells(row) end)
    |> Enum.map(fn cell -> Cell.render(cell, opts) end)
    |> Enum.join(",\n")
    |> Kernel.<>(",")
  end

  # Footer rendering

  @doc """
  Renders table footers to Typst table.footer() calls.

  ## Parameters

  - `footers` - List of FooterIR structs
  - `indent` - Current indentation level

  ## Returns

  String containing Typst table.footer() markup.
  """
  @spec render_footers([IR.Footer.t()], non_neg_integer(), keyword()) :: String.t()
  def render_footers(footers, indent, parent_opts \\ [])
  def render_footers([], _indent, _parent_opts), do: ""

  def render_footers(footers, indent, parent_opts) do
    indent_str = String.duplicate("  ", indent)

    footers
    |> Enum.map(fn footer -> render_footer(footer, indent_str, indent, parent_opts) end)
    |> Enum.join("\n")
  end

  defp render_footer(%IR.Footer{repeat: repeat, rows: rows}, indent_str, indent, parent_opts) do
    repeat_param = if repeat, do: "repeat: true, ", else: ""
    cells = render_footer_rows(rows, indent + 1, parent_opts)

    if cells == "" do
      "#{indent_str}table.footer(#{repeat_param})"
    else
      "#{indent_str}table.footer(#{repeat_param}\n#{cells}\n#{indent_str})"
    end
  end

  defp render_footer(_footer, indent_str, _indent, _parent_opts) do
    # Fallback for non-struct footers
    "#{indent_str}table.footer()"
  end

  defp render_footer_rows([], _indent, _parent_opts), do: ""

  defp render_footer_rows(rows, indent, parent_opts) do
    opts = Keyword.merge(parent_opts, [indent: indent, context: :table])

    rows
    |> Enum.flat_map(fn row -> extract_row_cells(row) end)
    |> Enum.map(fn cell -> Cell.render(cell, opts) end)
    |> Enum.join(",\n")
    |> Kernel.<>(",")
  end

  # Children rendering

  defp render_children([], _indent, _parent_opts), do: ""

  defp render_children(children, indent, parent_opts) do
    opts = Keyword.merge(parent_opts, [indent: indent, context: :table])

    children
    |> Enum.map(fn child -> render_child(child, opts) end)
    |> Enum.join(",\n")
    |> Kernel.<>(",")
  end

  defp render_child(%IR.Cell{} = cell, opts) do
    Cell.render(cell, opts)
  end

  defp render_child(%IR.Row{cells: cells}, opts) do
    cells
    |> Enum.map(fn cell -> Cell.render(cell, opts) end)
    |> Enum.join(",\n")
  end

  defp render_child(_, opts) do
    indent = Keyword.get(opts, :indent, 0)
    indent_str = String.duplicate("  ", indent)
    "#{indent_str}[]"
  end

  # Helper functions

  defp extract_row_cells(%IR.Row{cells: cells}), do: cells
  defp extract_row_cells(%{cells: cells}), do: cells
  defp extract_row_cells(_), do: []
end
