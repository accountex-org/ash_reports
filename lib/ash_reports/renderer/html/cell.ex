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
  alias AshReports.Renderer.Html.{Interpolation, Styling}

  #############################################################################
  # Public API
  #############################################################################

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

  #############################################################################
  # Private Functions
  #############################################################################

  # Grid cell rendering
  #
  # Renders a cell as a CSS Grid item using a div with grid positioning styles.
  # Supports colspan/rowspan via grid-column/grid-row span properties.
  defp render_grid_cell(%IR.Cell{} = cell, opts) do
    styles = build_grid_cell_styles(cell)
    content = render_content(cell.content, opts)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<div class="ash-cell"#{style_attr}>#{content}</div>)
  end

  # Builds the CSS style string for a grid cell by combining:
  # - Explicit position (grid-column/grid-row for non-default positions)
  # - Span styles (grid-column/grid-row span for colspan/rowspan > 1)
  # - Common cell styles (padding, background, border, alignment)
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

  # Adds explicit grid position when cell is not at default (0,0).
  # CSS Grid uses 1-based indexing, so we add 1 to the 0-based position.
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

  defp render_table_header_cell(%IR.Cell{} = cell, opts) do
    styles = build_table_cell_styles(cell)
    content = render_content(cell.content, opts)
    attrs = build_table_cell_attrs(cell)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<th#{attrs}#{style_attr}>#{content}</th>)
  end

  # Table body cell rendering

  defp render_table_body_cell(%IR.Cell{} = cell, opts) do
    styles = build_table_cell_styles(cell)
    content = render_content(cell.content, opts)
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
    ["padding: #{Styling.render_length(inset)}" | styles]
  end
  defp maybe_add_padding(styles, _), do: styles

  defp maybe_add_background(styles, %{fill: fill}) when not is_nil(fill) and fill != :none do
    ["background-color: #{Styling.render_color(fill)}" | styles]
  end
  defp maybe_add_background(styles, _), do: styles

  defp maybe_add_border(styles, %{stroke: stroke}) when not is_nil(stroke) and stroke != :none do
    ["border: #{Styling.render_stroke(stroke)}" | styles]
  end
  defp maybe_add_border(styles, _), do: styles

  defp maybe_add_text_align(styles, %{align: align}) when not is_nil(align) do
    ["text-align: #{Styling.render_text_align(align)}" | styles]
  end
  defp maybe_add_text_align(styles, _), do: styles

  defp maybe_add_vertical_align(styles, %{vertical_align: valign}) when not is_nil(valign) do
    ["vertical-align: #{Styling.render_vertical_align(valign)}" | styles]
  end
  defp maybe_add_vertical_align(styles, %{align: {_h, v}}) when not is_nil(v) do
    ["vertical-align: #{Styling.render_vertical_align(v)}" | styles]
  end
  defp maybe_add_vertical_align(styles, _), do: styles

  # Content rendering

  defp render_content(nil, _opts), do: ""
  defp render_content([], _opts), do: ""

  defp render_content(content, opts) when is_list(content) do
    content
    |> Enum.map(&render_content_item(&1, opts))
    |> Enum.join("")
  end

  defp render_content(content, opts), do: render_content_item(content, opts)

  # Handle Label structs from IR Content
  defp render_content_item(%AshReports.Layout.IR.Content.Label{text: text, style: style}, opts) do
    data = Keyword.get(opts, :data, %{})
    # First escape the literal text, then interpolate variables (which also escapes their values)
    content =
      text
      |> Styling.escape_html()
      |> Interpolation.interpolate(data)

    # Apply styles if present
    styles = build_content_styles(style)
    if styles == "" do
      content
    else
      ~s(<span style="#{styles}">#{content}</span>)
    end
  end

  # Handle Field structs from IR Content
  defp render_content_item(%AshReports.Layout.IR.Content.Field{source: source, format: format, decimal_places: decimal_places, style: style}, opts) do
    data = Keyword.get(opts, :data, %{})
    value = get_field_value(data, source)
    formatted = Interpolation.format_value(value, format, decimal_places)
    content = Styling.escape_html(formatted)

    # Apply styles if present
    styles = build_content_styles(style)
    if styles == "" do
      content
    else
      ~s(<span style="#{styles}">#{content}</span>)
    end
  end

  # Build CSS styles from IR.Style struct
  defp build_content_styles(nil), do: ""
  defp build_content_styles(%IR.Style{} = style) do
    []
    |> maybe_add_style("font-weight", style.font_weight)
    |> maybe_add_style("font-size", style.font_size, &Styling.render_length/1)
    |> maybe_add_style("font-style", style.font_style)
    |> maybe_add_style("color", style.color)
    |> maybe_add_style("background-color", style.background_color)
    |> maybe_add_style("font-family", style.font_family)
    |> maybe_add_style("text-align", style.text_align)
    |> Enum.reverse()
    |> Enum.join("; ")
  end
  defp build_content_styles(_), do: ""

  defp maybe_add_style(styles, _prop, nil), do: styles
  defp maybe_add_style(styles, prop, value) do
    ["#{prop}: #{value}" | styles]
  end
  defp maybe_add_style(styles, _prop, nil, _formatter), do: styles
  defp maybe_add_style(styles, prop, value, formatter) do
    ["#{prop}: #{formatter.(value)}" | styles]
  end

  defp render_content_item(%{text: text}, opts) do
    data = Keyword.get(opts, :data, %{})
    # First escape the literal text, then interpolate variables (which also escapes their values)
    text
    |> Styling.escape_html()
    |> Interpolation.interpolate(data)
  end

  defp render_content_item(%{value: value}, _opts) do
    Styling.escape_html(to_string(value))
  end

  defp render_content_item(text, opts) when is_binary(text) do
    data = Keyword.get(opts, :data, %{})
    # First escape the literal text, then interpolate variables (which also escapes their values)
    text
    |> Styling.escape_html()
    |> Interpolation.interpolate(data)
  end

  defp render_content_item(_, _opts), do: ""

  # Field value retrieval helpers for IR Content.Field structs
  defp get_field_value(data, source) when is_atom(source) do
    Map.get(data, source) || Map.get(data, to_string(source))
  end

  defp get_field_value(data, source) when is_list(source) do
    Enum.reduce_while(source, data, fn key, acc ->
      case acc do
        %{} ->
          value = Map.get(acc, key) || Map.get(acc, to_string(key))
          if value, do: {:cont, value}, else: {:halt, nil}
        _ ->
          {:halt, nil}
      end
    end)
  end

  defp get_field_value(_data, _source), do: nil
end
