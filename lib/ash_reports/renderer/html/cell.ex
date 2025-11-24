defmodule AshReports.Renderer.Html.Cell do
  @moduledoc """
  HTML renderer for cells in grid and table layouts.

  Generates appropriate HTML elements based on context:
  - Grid cells → div with CSS Grid properties
  - Table header cells → th elements
  - Table body/footer cells → td elements

  ## CSS Grid Cell Properties

  - `grid-column: span N` for colspan
  - `grid-row: span N` for rowspan
  - `grid-column: X` and `grid-row: Y` for explicit positioning
  - `text-align`, `vertical-align` for alignment
  - `background-color` for fill
  - `border` for stroke
  - `padding` for inset

  ## Table Cell Properties

  - `colspan` and `rowspan` attributes
  - Inline styles for alignment, fill, stroke, inset
  """

  alias AshReports.Layout.IR

  @doc """
  Renders a CellIR to HTML.

  ## Parameters

  - `cell` - The CellIR struct to render
  - `opts` - Rendering options including :context

  ## Returns

  String containing the HTML cell markup.
  """
  @spec render(IR.Cell.t(), keyword()) :: String.t()
  def render(%IR.Cell{} = cell, opts \\ []) do
    context = Keyword.get(opts, :context, :grid)

    case context do
      :grid -> render_grid_cell(cell, opts)
      :stack -> render_grid_cell(cell, opts)
      :table_header -> render_table_header_cell(cell, opts)
      :table_body -> render_table_body_cell(cell, opts)
      :table_footer -> render_table_body_cell(cell, opts)
      _ -> render_grid_cell(cell, opts)
    end
  end

  # Grid cell rendering

  defp render_grid_cell(%IR.Cell{} = cell, _opts) do
    styles = build_grid_cell_styles(cell)
    content = render_content(cell.content)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<div class="ash-cell"#{style_attr}>#{content}</div>)
  end

  defp build_grid_cell_styles(%IR.Cell{} = cell) do
    styles = []

    styles = maybe_add_explicit_position(styles, cell)
    styles = maybe_add_colspan(styles, cell)
    styles = maybe_add_rowspan(styles, cell)
    styles = maybe_add_cell_styles(styles, cell)

    styles
    |> Enum.reverse()
    |> Enum.join("; ")
  end

  # Add explicit grid position when position is set (not at 0,0 default)
  defp maybe_add_explicit_position(styles, %IR.Cell{position: {x, y}}) when x > 0 or y > 0 do
    # CSS Grid uses 1-based indexing
    styles = if x > 0, do: ["grid-column: #{x + 1}" | styles], else: styles
    if y > 0, do: ["grid-row: #{y + 1}" | styles], else: styles
  end
  defp maybe_add_explicit_position(styles, _), do: styles

  defp maybe_add_colspan(styles, %IR.Cell{span: {colspan, _rowspan}}) when colspan > 1 do
    ["grid-column: span #{colspan}" | styles]
  end
  defp maybe_add_colspan(styles, _), do: styles

  defp maybe_add_rowspan(styles, %IR.Cell{span: {_colspan, rowspan}}) when rowspan > 1 do
    ["grid-row: span #{rowspan}" | styles]
  end
  defp maybe_add_rowspan(styles, _), do: styles

  defp maybe_add_cell_styles(styles, %IR.Cell{properties: properties}) when is_map(properties) do
    styles
    |> maybe_add_padding(properties)
    |> maybe_add_background(properties)
    |> maybe_add_border(properties)
    |> maybe_add_text_align(properties)
    |> maybe_add_vertical_align(properties)
  end
  defp maybe_add_cell_styles(styles, _), do: styles

  # Table header cell rendering

  defp render_table_header_cell(%IR.Cell{} = cell, _opts) do
    styles = build_table_cell_styles(cell)
    content = render_content(cell.content)
    attrs = build_table_cell_attrs(cell)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<th#{attrs}#{style_attr}>#{content}</th>)
  end

  # Table body cell rendering

  defp render_table_body_cell(%IR.Cell{} = cell, _opts) do
    styles = build_table_cell_styles(cell)
    content = render_content(cell.content)
    attrs = build_table_cell_attrs(cell)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<td#{attrs}#{style_attr}>#{content}</td>)
  end

  defp build_table_cell_attrs(%IR.Cell{span: {colspan, rowspan}}) do
    attrs = []

    attrs = if colspan > 1, do: [~s( colspan="#{colspan}") | attrs], else: attrs
    attrs = if rowspan > 1, do: [~s( rowspan="#{rowspan}") | attrs], else: attrs

    Enum.join(Enum.reverse(attrs), "")
  end

  defp build_table_cell_styles(%IR.Cell{properties: properties}) when is_map(properties) do
    []
    |> maybe_add_padding(properties)
    |> maybe_add_background(properties)
    |> maybe_add_border(properties)
    |> maybe_add_text_align(properties)
    |> maybe_add_vertical_align(properties)
    |> Enum.reverse()
    |> Enum.join("; ")
  end
  defp build_table_cell_styles(_), do: ""

  # Common style helpers

  defp maybe_add_padding(styles, %{inset: inset}) when not is_nil(inset) do
    ["padding: #{render_length(inset)}" | styles]
  end
  defp maybe_add_padding(styles, _), do: styles

  defp maybe_add_background(styles, %{fill: fill}) when not is_nil(fill) and fill != :none do
    ["background-color: #{render_color(fill)}" | styles]
  end
  defp maybe_add_background(styles, _), do: styles

  defp maybe_add_border(styles, %{stroke: stroke}) when not is_nil(stroke) and stroke != :none do
    ["border: #{render_stroke(stroke)}" | styles]
  end
  defp maybe_add_border(styles, _), do: styles

  defp maybe_add_text_align(styles, %{align: align}) when not is_nil(align) do
    ["text-align: #{render_text_align(align)}" | styles]
  end
  defp maybe_add_text_align(styles, _), do: styles

  defp maybe_add_vertical_align(styles, %{vertical_align: valign}) when not is_nil(valign) do
    ["vertical-align: #{render_vertical_align(valign)}" | styles]
  end
  defp maybe_add_vertical_align(styles, %{align: {_h, v}}) when not is_nil(v) do
    ["vertical-align: #{render_vertical_align(v)}" | styles]
  end
  defp maybe_add_vertical_align(styles, _), do: styles

  # Content rendering

  defp render_content(nil), do: ""
  defp render_content([]), do: ""

  defp render_content(content) when is_list(content) do
    content
    |> Enum.map(&render_content_item/1)
    |> Enum.join("")
  end

  defp render_content(content), do: render_content_item(content)

  defp render_content_item(%{text: text}) do
    escape_html(text)
  end

  defp render_content_item(%{value: value}) do
    escape_html(to_string(value))
  end

  defp render_content_item(text) when is_binary(text) do
    escape_html(text)
  end

  defp render_content_item(_), do: ""

  # Helper functions

  defp render_length(length) when is_binary(length) do
    if String.ends_with?(length, "pt") do
      String.replace(length, "pt", "px")
    else
      length
    end
  end
  defp render_length(length) when is_number(length), do: "#{length}px"

  defp render_color(:none), do: "transparent"
  defp render_color(nil), do: "transparent"
  defp render_color(color) when is_binary(color), do: color
  defp render_color(color) when is_atom(color), do: Atom.to_string(color)

  defp render_stroke(:none), do: "none"
  defp render_stroke(stroke) when is_binary(stroke), do: stroke
  defp render_stroke(%{thickness: thickness, paint: paint}) do
    "#{render_length(thickness)} solid #{render_color(paint)}"
  end
  defp render_stroke(%{thickness: thickness}), do: "#{render_length(thickness)} solid currentColor"
  defp render_stroke(_), do: "1px solid currentColor"

  defp render_text_align(:left), do: "left"
  defp render_text_align(:center), do: "center"
  defp render_text_align(:right), do: "right"
  defp render_text_align({h, _v}), do: render_text_align(h)
  defp render_text_align(align) when is_binary(align), do: align
  defp render_text_align(_), do: "left"

  defp render_vertical_align(:top), do: "top"
  defp render_vertical_align(:middle), do: "middle"
  defp render_vertical_align(:bottom), do: "bottom"
  defp render_vertical_align(valign) when is_binary(valign), do: valign
  defp render_vertical_align(_), do: "middle"

  @doc """
  Escapes HTML special characters to prevent XSS.
  """
  @spec escape_html(String.t()) :: String.t()
  def escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def escape_html(text), do: escape_html(to_string(text))
end
