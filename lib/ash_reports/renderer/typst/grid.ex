defmodule AshReports.Renderer.Typst.Grid do
  @moduledoc """
  Typst renderer for grid layouts.

  Generates Typst grid() function calls from GridIR with all supported properties:
  - columns/rows track sizes
  - gutter (column-gutter, row-gutter)
  - align
  - inset
  - fill (static or function)
  - stroke

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :grid, properties: %{columns: ["1fr", "2fr"]}}
      iex> AshReports.Renderer.Typst.Grid.render(ir)
      "#grid(\\n  columns: (1fr, 2fr),\\n)"
  """

  alias AshReports.Layout.IR

  @doc """
  Renders a GridIR to Typst grid() markup.

  ## Parameters

  - `ir` - The GridIR struct to render
  - `opts` - Rendering options (reserved for future use)

  ## Returns

  String containing the Typst grid() function call.
  """
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: :grid} = ir, opts \\ []) do
    indent = Keyword.get(opts, :indent, 0)
    indent_str = String.duplicate("  ", indent)

    params = build_parameters(ir.properties)
    children = render_children(ir.children, indent + 1)

    if children == "" do
      "#{indent_str}#grid(\n#{params}#{indent_str})"
    else
      "#{indent_str}#grid(\n#{params}#{children}\n#{indent_str})"
    end
  end

  @doc """
  Builds the parameter list for a grid() call.
  """
  @spec build_parameters(map()) :: String.t()
  def build_parameters(properties) do
    params =
      []
      |> maybe_add_columns(properties)
      |> maybe_add_rows(properties)
      |> maybe_add_gutter(properties)
      |> maybe_add_column_gutter(properties)
      |> maybe_add_row_gutter(properties)
      |> maybe_add_align(properties)
      |> maybe_add_inset(properties)
      |> maybe_add_fill(properties)
      |> maybe_add_stroke(properties)
      |> Enum.reverse()

    if params == [] do
      ""
    else
      params
      |> Enum.map(fn param -> "  #{param}" end)
      |> Enum.join(",\n")
      |> Kernel.<>(",\n")
    end
  end

  # Parameter builders

  defp maybe_add_columns(params, %{columns: columns}) when not is_nil(columns) do
    [render_columns(columns) | params]
  end

  defp maybe_add_columns(params, _), do: params

  defp maybe_add_rows(params, %{rows: rows}) when not is_nil(rows) do
    [render_rows(rows) | params]
  end

  defp maybe_add_rows(params, _), do: params

  defp maybe_add_gutter(params, %{gutter: gutter}) when not is_nil(gutter) do
    ["gutter: #{render_length(gutter)}" | params]
  end

  defp maybe_add_gutter(params, _), do: params

  defp maybe_add_column_gutter(params, %{column_gutter: gutter}) when not is_nil(gutter) do
    ["column-gutter: #{render_length(gutter)}" | params]
  end

  defp maybe_add_column_gutter(params, _), do: params

  defp maybe_add_row_gutter(params, %{row_gutter: gutter}) when not is_nil(gutter) do
    ["row-gutter: #{render_length(gutter)}" | params]
  end

  defp maybe_add_row_gutter(params, _), do: params

  defp maybe_add_align(params, %{align: align}) when not is_nil(align) do
    ["align: #{render_alignment(align)}" | params]
  end

  defp maybe_add_align(params, _), do: params

  defp maybe_add_inset(params, %{inset: inset}) when not is_nil(inset) do
    ["inset: #{render_length(inset)}" | params]
  end

  defp maybe_add_inset(params, _), do: params

  defp maybe_add_fill(params, %{fill: fill}) when not is_nil(fill) do
    ["fill: #{render_fill(fill)}" | params]
  end

  defp maybe_add_fill(params, _), do: params

  defp maybe_add_stroke(params, %{stroke: stroke}) when not is_nil(stroke) do
    ["stroke: #{render_stroke(stroke)}" | params]
  end

  defp maybe_add_stroke(params, _), do: params

  # Track size rendering

  @doc """
  Renders column track sizes to Typst syntax.

  ## Examples

      iex> render_columns(["1fr", "2fr", "auto"])
      "columns: (1fr, 2fr, auto)"

      iex> render_columns(3)
      "columns: 3"
  """
  @spec render_columns(list() | integer()) :: String.t()
  def render_columns(columns) when is_list(columns) do
    tracks = Enum.map_join(columns, ", ", &render_track_size/1)
    "columns: (#{tracks})"
  end

  def render_columns(count) when is_integer(count) do
    "columns: #{count}"
  end

  @doc """
  Renders row track sizes to Typst syntax.
  """
  @spec render_rows(list() | integer()) :: String.t()
  def render_rows(rows) when is_list(rows) do
    tracks = Enum.map_join(rows, ", ", &render_track_size/1)
    "rows: (#{tracks})"
  end

  def render_rows(count) when is_integer(count) do
    "rows: #{count}"
  end

  @doc """
  Renders a single track size to Typst syntax.

  ## Examples

      iex> render_track_size("1fr")
      "1fr"

      iex> render_track_size(:auto)
      "auto"

      iex> render_track_size("100pt")
      "100pt"
  """
  @spec render_track_size(String.t() | atom() | number()) :: String.t()
  def render_track_size(:auto), do: "auto"
  def render_track_size("auto"), do: "auto"
  def render_track_size(size) when is_binary(size), do: size
  def render_track_size(size) when is_number(size), do: "#{size}pt"

  # Length rendering

  @doc """
  Renders a length value to Typst syntax.
  """
  @spec render_length(String.t() | number() | atom()) :: String.t()
  def render_length(:auto), do: "auto"
  def render_length("auto"), do: "auto"
  def render_length(length) when is_binary(length), do: length
  def render_length(length) when is_number(length), do: "#{length}pt"

  # Alignment rendering

  @doc """
  Renders an alignment value to Typst syntax.

  ## Examples

      iex> render_alignment(:center)
      "center"

      iex> render_alignment({:left, :top})
      "left + top"

      iex> render_alignment("center")
      "center"
  """
  @spec render_alignment(atom() | tuple() | String.t()) :: String.t()
  def render_alignment({h, v}), do: "#{h} + #{v}"
  def render_alignment(align) when is_atom(align), do: Atom.to_string(align)
  def render_alignment(align) when is_binary(align), do: align

  # Fill rendering

  @doc """
  Renders a fill value to Typst syntax.

  ## Examples

      iex> render_fill(:none)
      "none"

      iex> render_fill("red")
      "red"

      iex> render_fill("#ff0000")
      "rgb(\"#ff0000\")"
  """
  @spec render_fill(atom() | String.t() | function()) :: String.t()
  def render_fill(:none), do: "none"
  def render_fill(nil), do: "none"

  def render_fill(color) when is_binary(color) do
    if String.starts_with?(color, "#") do
      "rgb(\"#{color}\")"
    else
      color
    end
  end

  def render_fill(color) when is_atom(color), do: Atom.to_string(color)

  def render_fill(func) when is_function(func) do
    # Function fills will be handled in later phases
    # For now, render as a placeholder
    "(x, y) => none"
  end

  # Stroke rendering

  @doc """
  Renders a stroke value to Typst syntax.

  ## Examples

      iex> render_stroke(:none)
      "none"

      iex> render_stroke("1pt")
      "1pt"
  """
  @spec render_stroke(atom() | String.t()) :: String.t()
  def render_stroke(:none), do: "none"
  def render_stroke(nil), do: "none"
  def render_stroke(stroke) when is_binary(stroke), do: stroke
  def render_stroke(stroke) when is_atom(stroke), do: Atom.to_string(stroke)

  # Children rendering (placeholder for phase 3.2)

  defp render_children([], _indent), do: ""

  defp render_children(children, indent) do
    indent_str = String.duplicate("  ", indent)

    children
    |> Enum.map(fn child -> render_child(child, indent_str) end)
    |> Enum.join("\n")
  end

  defp render_child(%IR.Cell{content: content}, indent_str) do
    # Simple placeholder - will be expanded in phase 3.2
    text =
      content
      |> Enum.map(&extract_text/1)
      |> Enum.join(" ")

    "#{indent_str}[#{text}]"
  end

  defp render_child(%IR.Row{cells: cells}, indent_str) do
    cells
    |> Enum.map(fn cell -> render_child(cell, indent_str) end)
    |> Enum.join("\n")
  end

  defp render_child(_, indent_str), do: "#{indent_str}[]"

  defp extract_text(%{text: text}), do: text
  defp extract_text(%{value: value}), do: to_string(value)
  defp extract_text(_), do: ""
end
