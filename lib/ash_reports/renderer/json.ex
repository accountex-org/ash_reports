defmodule AshReports.Renderer.Json do
  @moduledoc """
  JSON renderer for AshReports Layout IR.

  Serializes the Layout Intermediate Representation to JSON-compatible maps
  for client-side rendering or API responses. This enables JavaScript-based
  rendering engines to consume report structures.

  ## Usage

      # Serialize a single IR
      json_map = AshReports.Renderer.Json.render(ir)
      json_string = Jason.encode!(json_map)

      # Serialize with data
      json_map = AshReports.Renderer.Json.render(ir, data: %{name: "Report"})

      # Serialize multiple layouts
      json_map = AshReports.Renderer.Json.render_all([header_ir, body_ir])

  ## Output Format

  The renderer produces nested maps suitable for JSON encoding:

      %{
        type: "grid",
        properties: %{columns: ["1fr", "1fr"], gap: "10px"},
        children: [
          %{
            type: "cell",
            position: [0, 0],
            span: [1, 1],
            content: [%{type: "label", text: "Name"}]
          }
        ]
      }

  ## Data Resolution

  When `:data` option is provided, field values are resolved and included
  in the output, making the JSON self-contained for rendering.
  """

  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.{Cell, Row, Content, Line, Header, Footer, Style}

  @doc """
  Renders a single IR layout to a JSON-compatible map.

  ## Parameters

  - `ir` - The LayoutIR to render
  - `opts` - Rendering options including :data for field resolution

  ## Options

  - `:data` - Map of data for resolving field values

  ## Returns

  Map suitable for JSON encoding.

  ## Examples

      iex> ir = AshReports.Layout.IR.grid(properties: %{columns: ["1fr", "1fr"]})
      iex> AshReports.Renderer.Json.render(ir)
      %{type: "grid", properties: %{columns: ["1fr", "1fr"]}, children: [], ...}
  """
  @spec render(IR.t(), keyword()) :: map()
  def render(%IR{} = ir, opts \\ []) do
    serialize_layout(ir, opts)
  end

  @doc """
  Renders multiple IR layouts (bands) to a JSON-compatible structure.

  ## Parameters

  - `layouts` - List of LayoutIR structs
  - `opts` - Rendering options

  ## Returns

  Map containing a "layouts" key with array of serialized layouts.

  ## Examples

      iex> layouts = [header_ir, body_ir, footer_ir]
      iex> AshReports.Renderer.Json.render_all(layouts)
      %{layouts: [%{type: "grid", ...}, %{type: "table", ...}, ...]}
  """
  @spec render_all([IR.t()], keyword()) :: map()
  def render_all(layouts, opts \\ []) when is_list(layouts) do
    serialized = Enum.map(layouts, fn ir -> serialize_layout(ir, opts) end)
    %{layouts: serialized}
  end

  @doc """
  Renders IR to a JSON string.

  Convenience function that encodes to JSON string directly.

  ## Parameters

  - `ir_or_layouts` - Single IR or list of IRs
  - `opts` - Rendering options

  ## Returns

  JSON string.

  ## Examples

      iex> ir = AshReports.Layout.IR.grid(properties: %{columns: ["1fr"]})
      iex> AshReports.Renderer.Json.render_json(ir)
      ~s({"type":"grid","properties":{"columns":["1fr"]},...})
  """
  @spec render_json(IR.t() | [IR.t()], keyword()) :: String.t()
  def render_json(ir_or_layouts, opts \\ [])

  def render_json(%IR{} = ir, opts) do
    ir
    |> render(opts)
    |> Jason.encode!()
  end

  def render_json(layouts, opts) when is_list(layouts) do
    layouts
    |> render_all(opts)
    |> Jason.encode!()
  end

  # Layout serialization

  defp serialize_layout(%IR{} = ir, opts) do
    %{
      type: Atom.to_string(ir.type),
      properties: serialize_properties(ir.properties),
      children: serialize_children(ir.children, opts),
      lines: serialize_lines(ir.lines),
      headers: serialize_headers(ir.headers, opts),
      footers: serialize_footers(ir.footers, opts)
    }
  end

  # Properties serialization

  defp serialize_properties(properties) when is_map(properties) do
    properties
    |> Enum.map(fn {key, value} -> {key, serialize_property_value(value)} end)
    |> Map.new()
  end

  defp serialize_property_value(value) when is_atom(value) and not is_nil(value) and not is_boolean(value) do
    Atom.to_string(value)
  end

  defp serialize_property_value({a, b}) when is_number(a) and is_number(b) do
    [a, b]
  end

  defp serialize_property_value(value) when is_tuple(value) do
    Tuple.to_list(value)
  end

  defp serialize_property_value(value) when is_function(value) do
    # Functions can't be serialized; return a placeholder
    "__function__"
  end

  defp serialize_property_value(value), do: value

  # Children serialization

  defp serialize_children(children, opts) when is_list(children) do
    Enum.map(children, fn child -> serialize_child(child, opts) end)
  end

  defp serialize_child(%Cell{} = cell, opts), do: serialize_cell(cell, opts)
  defp serialize_child(%Row{} = row, opts), do: serialize_row(row, opts)
  defp serialize_child(other, _opts) when is_map(other), do: serialize_map_content(other)
  defp serialize_child(_, _opts), do: nil

  # Cell serialization

  defp serialize_cell(%Cell{} = cell, opts) do
    {x, y} = cell.position
    {colspan, rowspan} = cell.span

    %{
      type: "cell",
      position: [x, y],
      span: [colspan, rowspan],
      properties: serialize_properties(cell.properties),
      content: serialize_content_list(cell.content, opts)
    }
  end

  # Row serialization

  defp serialize_row(%Row{} = row, opts) do
    %{
      type: "row",
      index: row.index,
      properties: serialize_properties(row.properties),
      cells: Enum.map(row.cells, fn cell -> serialize_cell(cell, opts) end)
    }
  end

  # Content serialization

  defp serialize_content_list(content, opts) when is_list(content) do
    Enum.map(content, fn item -> serialize_content(item, opts) end)
  end

  defp serialize_content(%Content.Label{} = label, _opts) do
    result = %{
      type: "label",
      text: label.text
    }

    maybe_add_style(result, label.style)
  end

  defp serialize_content(%Content.Field{} = field, opts) do
    data = Keyword.get(opts, :data, %{})
    value = resolve_field_value(field.source, data)

    result = %{
      type: "field",
      source: serialize_source(field.source),
      value: value
    }

    result = if field.format, do: Map.put(result, :format, Atom.to_string(field.format)), else: result
    result = if field.decimal_places, do: Map.put(result, :decimal_places, field.decimal_places), else: result

    maybe_add_style(result, field.style)
  end

  defp serialize_content(%Content.NestedLayout{layout: layout}, opts) do
    %{
      type: "nested_layout",
      layout: serialize_layout(layout, opts)
    }
  end

  # Handle simple map content (from tests)
  defp serialize_content(%{text: text}, _opts) do
    %{type: "label", text: text}
  end

  defp serialize_content(%{value: value}, _opts) do
    %{type: "field", value: value}
  end

  defp serialize_content(_, _opts), do: nil

  defp serialize_map_content(%{text: text}) do
    %{type: "label", text: text}
  end

  defp serialize_map_content(%{value: value}) do
    %{type: "field", value: value}
  end

  defp serialize_map_content(_), do: nil

  defp serialize_source(source) when is_atom(source), do: Atom.to_string(source)
  defp serialize_source(source) when is_list(source) do
    Enum.map(source, fn s -> if is_atom(s), do: Atom.to_string(s), else: s end)
  end
  defp serialize_source(source), do: source

  defp maybe_add_style(result, nil), do: result
  defp maybe_add_style(result, %Style{} = style) do
    Map.put(result, :style, serialize_style(style))
  end
  defp maybe_add_style(result, style) when is_map(style) do
    Map.put(result, :style, serialize_properties(style))
  end

  # Style serialization

  defp serialize_style(%Style{} = style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {k, serialize_property_value(v)} end)
    |> Map.new()
  end

  # Line serialization

  defp serialize_lines(lines) when is_list(lines) do
    Enum.map(lines, &serialize_line/1)
  end

  defp serialize_line(%Line{} = line) do
    result = %{
      orientation: Atom.to_string(line.orientation),
      position: line.position
    }

    result = if line.start, do: Map.put(result, :start, line.start), else: result
    result = if line.end, do: Map.put(result, :end, line.end), else: result
    if line.stroke, do: Map.put(result, :stroke, line.stroke), else: result
  end

  defp serialize_line(_), do: nil

  # Header serialization

  defp serialize_headers(headers, opts) when is_list(headers) do
    Enum.map(headers, fn header -> serialize_header(header, opts) end)
  end

  defp serialize_header(%Header{} = header, opts) do
    %{
      type: "header",
      repeat: header.repeat,
      rows: Enum.map(header.rows, fn row -> serialize_row_or_map(row, opts) end)
    }
  end

  defp serialize_header(_, _opts), do: nil

  # Footer serialization

  defp serialize_footers(footers, opts) when is_list(footers) do
    Enum.map(footers, fn footer -> serialize_footer(footer, opts) end)
  end

  defp serialize_footer(%Footer{} = footer, opts) do
    %{
      type: "footer",
      repeat: footer.repeat,
      rows: Enum.map(footer.rows, fn row -> serialize_row_or_map(row, opts) end)
    }
  end

  defp serialize_footer(_, _opts), do: nil

  # Helper for rows in headers/footers which might be Row structs or maps
  defp serialize_row_or_map(%Row{} = row, opts), do: serialize_row(row, opts)
  defp serialize_row_or_map(%{cells: cells} = row, opts) do
    %{
      type: "row",
      index: Map.get(row, :index, 0),
      properties: serialize_properties(Map.get(row, :properties, %{})),
      cells: Enum.map(cells, fn cell -> serialize_cell_or_map(cell, opts) end)
    }
  end
  defp serialize_row_or_map(_, _opts), do: nil

  defp serialize_cell_or_map(%Cell{} = cell, opts), do: serialize_cell(cell, opts)
  defp serialize_cell_or_map(cell, opts) when is_map(cell) do
    position = Map.get(cell, :position, {0, 0})
    span = Map.get(cell, :span, {1, 1})
    {x, y} = if is_tuple(position), do: position, else: {0, 0}
    {colspan, rowspan} = if is_tuple(span), do: span, else: {1, 1}

    %{
      type: "cell",
      position: [x, y],
      span: [colspan, rowspan],
      properties: serialize_properties(Map.get(cell, :properties, %{})),
      content: serialize_content_list(Map.get(cell, :content, []), opts)
    }
  end

  # Field value resolution

  defp resolve_field_value(source, data) when is_atom(source) do
    # Try atom key first, then string key
    Map.get(data, source) || Map.get(data, Atom.to_string(source))
  end

  defp resolve_field_value(source, data) when is_list(source) do
    # Navigate nested path
    Enum.reduce_while(source, data, fn key, acc ->
      key_atom = if is_atom(key), do: key, else: String.to_existing_atom(key)
      key_string = if is_atom(key), do: Atom.to_string(key), else: key

      case acc do
        %{} = map ->
          value = Map.get(map, key_atom) || Map.get(map, key_string)
          if value, do: {:cont, value}, else: {:halt, nil}
        _ ->
          {:halt, nil}
      end
    end)
  rescue
    ArgumentError -> nil
  end

  defp resolve_field_value(_, _), do: nil
end
