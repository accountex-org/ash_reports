defmodule AshReports.Renderer.Html.Table do
  @moduledoc """
  HTML renderer for table layouts using semantic HTML tables.

  Generates semantic HTML table elements from TableIR with:
  - table element with class="ash-table"
  - thead for header sections
  - tbody for data rows
  - tfoot for footer sections
  - tr for rows, th for headers, td for data

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :table, properties: %{columns: ["1fr", "2fr"]}}
      iex> AshReports.Renderer.Html.Table.render(ir)
      ~s(<table class="ash-table" style="border-collapse: collapse; width: 100%;"><tbody></tbody></table>)
  """

  @behaviour AshReports.Renderer.Html.Behaviour

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Html.Styling

  @default_stroke "1px solid #000"

  #############################################################################
  # Public API
  #############################################################################

  @doc """
  Renders a TableIR to semantic HTML table.

  ## Parameters

  - `ir` - The TableIR struct to render
  - `opts` - Rendering options

  ## Returns

  String containing the HTML table markup.
  """
  @impl true
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: :table} = ir, opts \\ []) do
    properties = apply_table_defaults(ir.properties)
    styles = build_styles(properties)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    # Generate colgroup for column widths
    colgroup = render_colgroup(properties)
    headers = render_headers(ir.headers, properties, opts)
    body = render_body(ir.children, properties, opts)
    footers = render_footers(ir.footers, properties, opts)

    content = colgroup <> headers <> body <> footers

    ~s(<table class="ash-table"#{style_attr}>#{content}</table>)
  end

  @doc """
  Applies table-specific defaults to properties.

  Tables have a default stroke.
  """
  @spec apply_table_defaults(map()) :: map()
  def apply_table_defaults(properties) do
    Map.put_new(properties, :stroke, @default_stroke)
  end

  @doc """
  Builds the CSS style string for a table element.
  """
  @impl true
  @spec build_styles(map()) :: String.t()
  def build_styles(properties) do
    styles =
      ["border-collapse: collapse", "width: 100%"]
      |> maybe_add_border(properties)
      |> maybe_add_fill(properties)
      |> Enum.reverse()

    Enum.join(styles, "; ")
  end

  @doc """
  Renders table headers to HTML thead element.

  ## Parameters

  - `headers` - List of HeaderIR structs
  - `properties` - Parent table properties
  - `opts` - Rendering options

  ## Returns

  String containing HTML thead markup.
  """
  @spec render_headers([IR.Header.t()], map(), keyword()) :: String.t()
  def render_headers([], _properties, _opts), do: ""

  def render_headers(headers, properties, opts) do
    rows =
      headers
      |> Enum.map(fn header -> render_header_rows(header, properties, opts) end)
      |> Enum.join("")

    if rows == "" do
      ""
    else
      ~s(<thead class="ash-header">#{rows}</thead>)
    end
  end

  @doc """
  Renders table body with tbody element.
  """
  @spec render_body([IR.Cell.t() | IR.Row.t()], map(), keyword()) :: String.t()
  def render_body([], _properties, _opts), do: "<tbody></tbody>"

  def render_body(children, properties, opts) do
    rows = render_body_rows(children, properties, opts)
    "<tbody>#{rows}</tbody>"
  end

  @doc """
  Renders table footers to HTML tfoot element.

  ## Parameters

  - `footers` - List of FooterIR structs
  - `properties` - Parent table properties
  - `opts` - Rendering options

  ## Returns

  String containing HTML tfoot markup.
  """
  @spec render_footers([IR.Footer.t()], map(), keyword()) :: String.t()
  def render_footers([], _properties, _opts), do: ""

  def render_footers(footers, properties, opts) do
    rows =
      footers
      |> Enum.map(fn footer -> render_footer_rows(footer, properties, opts) end)
      |> Enum.join("")

    if rows == "" do
      ""
    else
      ~s(<tfoot class="ash-footer">#{rows}</tfoot>)
    end
  end

  #############################################################################
  # Private Functions
  #############################################################################

  # Colgroup for column widths

  defp render_colgroup(%{columns: columns}) when is_list(columns) and columns != [] do
    cols =
      columns
      |> Enum.map(fn width -> ~s(<col style="width: #{width}">) end)
      |> Enum.join("")

    "<colgroup>#{cols}</colgroup>"
  end

  defp render_colgroup(_), do: ""

  # Style builders

  defp maybe_add_border(styles, %{stroke: stroke}) when not is_nil(stroke) and stroke != :none do
    ["border: #{Styling.render_stroke(stroke)}" | styles]
  end

  defp maybe_add_border(styles, _), do: styles

  defp maybe_add_fill(styles, %{fill: fill}) when not is_nil(fill) and fill != :none do
    ["background-color: #{Styling.render_color(fill)}" | styles]
  end

  defp maybe_add_fill(styles, _), do: styles

  # Header rendering helpers

  defp render_header_rows(%IR.Header{rows: rows}, properties, opts) do
    rows
    |> Enum.map(fn row -> render_header_row(row, properties, opts) end)
    |> Enum.join("")
  end

  defp render_header_rows(_header, _properties, _opts), do: ""

  defp render_header_row(%IR.Row{cells: cells}, properties, opts) do
    cell_html =
      cells
      |> Enum.map(fn cell -> render_header_cell(cell, properties, opts) end)
      |> Enum.join("")

    "<tr>#{cell_html}</tr>"
  end

  defp render_header_row(%{cells: cells}, properties, opts) do
    cell_html =
      cells
      |> Enum.map(fn cell -> render_header_cell(cell, properties, opts) end)
      |> Enum.join("")

    "<tr>#{cell_html}</tr>"
  end

  defp render_header_cell(%IR.Cell{} = cell, properties, opts) do
    AshReports.Renderer.Html.Cell.render(cell, Keyword.merge(opts, [
      context: :table_header,
      parent_properties: properties
    ]))
  end

  defp render_header_cell(_, _properties, _opts), do: "<th></th>"

  # Body rendering helpers

  defp render_body_rows(children, properties, opts) do
    children
    |> Enum.map(fn child -> render_body_child(child, properties, opts) end)
    |> Enum.join("")
  end

  defp render_body_child(%IR.Row{cells: cells}, properties, opts) do
    cell_html =
      cells
      |> Enum.map(fn cell -> render_body_cell(cell, properties, opts) end)
      |> Enum.join("")

    "<tr>#{cell_html}</tr>"
  end

  defp render_body_child(%IR.Cell{} = cell, properties, opts) do
    # Single cell as its own row
    cell_html = render_body_cell(cell, properties, opts)
    "<tr>#{cell_html}</tr>"
  end

  defp render_body_child(_, _properties, _opts), do: "<tr><td></td></tr>"

  defp render_body_cell(%IR.Cell{} = cell, properties, opts) do
    AshReports.Renderer.Html.Cell.render(cell, Keyword.merge(opts, [
      context: :table_body,
      parent_properties: properties
    ]))
  end

  defp render_body_cell(_, _properties, _opts), do: "<td></td>"

  # Footer rendering helpers

  defp render_footer_rows(%IR.Footer{rows: rows}, properties, opts) do
    rows
    |> Enum.map(fn row -> render_footer_row(row, properties, opts) end)
    |> Enum.join("")
  end

  defp render_footer_rows(_footer, _properties, _opts), do: ""

  defp render_footer_row(%IR.Row{cells: cells}, properties, opts) do
    cell_html =
      cells
      |> Enum.map(fn cell -> render_footer_cell(cell, properties, opts) end)
      |> Enum.join("")

    "<tr>#{cell_html}</tr>"
  end

  defp render_footer_row(%{cells: cells}, properties, opts) do
    cell_html =
      cells
      |> Enum.map(fn cell -> render_footer_cell(cell, properties, opts) end)
      |> Enum.join("")

    "<tr>#{cell_html}</tr>"
  end

  defp render_footer_cell(%IR.Cell{} = cell, properties, opts) do
    AshReports.Renderer.Html.Cell.render(cell, Keyword.merge(opts, [
      context: :table_footer,
      parent_properties: properties
    ]))
  end

  defp render_footer_cell(_, _properties, _opts), do: "<td></td>"
end
