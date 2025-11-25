defmodule AshReports.Renderer.Html.Grid do
  @moduledoc """
  HTML renderer for grid layouts using CSS Grid.

  Generates CSS Grid HTML from GridIR with all supported properties:
  - columns/rows track sizes via grid-template-columns/rows
  - gutter via gap, column-gap, row-gap
  - align via align-items and justify-items
  - inset applied to cells as padding
  - fill as background-color
  - stroke as border

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :grid, properties: %{columns: ["1fr", "2fr"]}}
      iex> AshReports.Renderer.Html.Grid.render(ir)
      ~s(<div class="ash-grid" style="display: grid; grid-template-columns: 1fr 2fr;"></div>)
  """

  @behaviour AshReports.Renderer.Html.Behaviour

  alias AshReports.Layout.IR

  @doc """
  Renders a GridIR to HTML with CSS Grid.

  ## Parameters

  - `ir` - The GridIR struct to render
  - `opts` - Rendering options

  ## Returns

  String containing the HTML with CSS Grid styling.
  """
  @impl true
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: :grid} = ir, opts \\ []) do
    styles = build_styles(ir.properties)
    children = render_children(ir.children, ir.properties, opts)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    if children == "" do
      ~s(<div class="ash-grid"#{style_attr}></div>)
    else
      ~s(<div class="ash-grid"#{style_attr}>#{children}</div>)
    end
  end

  @doc """
  Builds the CSS style string for a grid container.
  """
  @impl true
  @spec build_styles(map()) :: String.t()
  def build_styles(properties) do
    styles =
      ["display: grid"]
      |> maybe_add_columns(properties)
      |> maybe_add_rows(properties)
      |> maybe_add_gap(properties)
      |> maybe_add_column_gap(properties)
      |> maybe_add_row_gap(properties)
      |> maybe_add_alignment(properties)
      |> maybe_add_fill(properties)
      |> Enum.reverse()

    Enum.join(styles, "; ")
  end

  # Style builders

  defp maybe_add_columns(styles, %{columns: columns}) when not is_nil(columns) do
    [render_columns(columns) | styles]
  end

  defp maybe_add_columns(styles, _), do: styles

  defp maybe_add_rows(styles, %{rows: rows}) when not is_nil(rows) do
    [render_rows(rows) | styles]
  end

  defp maybe_add_rows(styles, _), do: styles

  defp maybe_add_gap(styles, %{gutter: gutter}) when not is_nil(gutter) do
    ["gap: #{render_length(gutter)}" | styles]
  end

  defp maybe_add_gap(styles, _), do: styles

  defp maybe_add_column_gap(styles, %{column_gutter: gutter}) when not is_nil(gutter) do
    ["column-gap: #{render_length(gutter)}" | styles]
  end

  defp maybe_add_column_gap(styles, _), do: styles

  defp maybe_add_row_gap(styles, %{row_gutter: gutter}) when not is_nil(gutter) do
    ["row-gap: #{render_length(gutter)}" | styles]
  end

  defp maybe_add_row_gap(styles, _), do: styles

  defp maybe_add_alignment(styles, %{align: align}) when not is_nil(align) do
    {h_align, v_align} = parse_alignment(align)

    styles
    |> maybe_add_justify_items(h_align)
    |> maybe_add_align_items(v_align)
  end

  defp maybe_add_alignment(styles, _), do: styles

  defp maybe_add_justify_items(styles, nil), do: styles
  defp maybe_add_justify_items(styles, align) do
    css_align = horizontal_to_css(align)
    ["justify-items: #{css_align}" | styles]
  end

  defp maybe_add_align_items(styles, nil), do: styles
  defp maybe_add_align_items(styles, align) do
    css_align = vertical_to_css(align)
    ["align-items: #{css_align}" | styles]
  end

  defp maybe_add_fill(styles, %{fill: fill}) when not is_nil(fill) and fill != :none do
    ["background-color: #{render_color(fill)}" | styles]
  end

  defp maybe_add_fill(styles, _), do: styles

  # Track size rendering

  @doc """
  Renders column track sizes to CSS grid-template-columns.

  ## Examples

      iex> render_columns(["1fr", "2fr", "auto"])
      "grid-template-columns: 1fr 2fr auto"

      iex> render_columns(3)
      "grid-template-columns: repeat(3, 1fr)"
  """
  @spec render_columns(list() | integer()) :: String.t()
  def render_columns(columns) when is_list(columns) do
    tracks = Enum.map_join(columns, " ", &render_track_size/1)
    "grid-template-columns: #{tracks}"
  end

  def render_columns(count) when is_integer(count) do
    "grid-template-columns: repeat(#{count}, 1fr)"
  end

  @doc """
  Renders row track sizes to CSS grid-template-rows.
  """
  @spec render_rows(list() | integer()) :: String.t()
  def render_rows(rows) when is_list(rows) do
    tracks = Enum.map_join(rows, " ", &render_track_size/1)
    "grid-template-rows: #{tracks}"
  end

  def render_rows(count) when is_integer(count) do
    "grid-template-rows: repeat(#{count}, auto)"
  end

  @doc """
  Renders a single track size to CSS syntax.

  ## Examples

      iex> render_track_size("1fr")
      "1fr"

      iex> render_track_size(:auto)
      "auto"

      iex> render_track_size("100pt")
      "100pt"

      iex> render_track_size({:fr, 2})
      "2fr"
  """
  @spec render_track_size(String.t() | atom() | number() | tuple()) :: String.t()
  def render_track_size(:auto), do: "auto"
  def render_track_size("auto"), do: "auto"
  def render_track_size({:fr, n}), do: "#{n}fr"
  def render_track_size(size) when is_binary(size), do: size
  def render_track_size(size) when is_number(size), do: "#{size}px"

  # Length rendering

  @doc """
  Renders a length value to CSS syntax.
  """
  @spec render_length(String.t() | number() | atom()) :: String.t()
  def render_length(:auto), do: "auto"
  def render_length("auto"), do: "auto"
  def render_length(length) when is_binary(length) do
    # Convert pt to px if needed (1pt ≈ 1.333px, but we use 1:1 for simplicity)
    if String.ends_with?(length, "pt") do
      String.replace(length, "pt", "px")
    else
      length
    end
  end
  def render_length(length) when is_number(length), do: "#{length}px"

  # Alignment helpers

  defp parse_alignment({h, v}), do: {h, v}
  defp parse_alignment(align) when align in [:left, :center, :right], do: {align, nil}
  defp parse_alignment(align) when align in [:top, :bottom], do: {nil, align}
  defp parse_alignment(_), do: {nil, nil}

  defp horizontal_to_css(:left), do: "start"
  defp horizontal_to_css(:center), do: "center"
  defp horizontal_to_css(:right), do: "end"
  defp horizontal_to_css(_), do: "start"

  defp vertical_to_css(:top), do: "start"
  defp vertical_to_css(:middle), do: "center"
  defp vertical_to_css(:bottom), do: "end"
  defp vertical_to_css(_), do: "start"

  # Color rendering

  @doc """
  Renders a color value to CSS.

  ## Examples

      iex> render_color("#ff0000")
      "#ff0000"

      iex> render_color(:red)
      "red"
  """
  @spec render_color(atom() | String.t()) :: String.t()
  def render_color(:none), do: "transparent"
  def render_color(nil), do: "transparent"
  def render_color(color) when is_binary(color), do: color
  def render_color(color) when is_atom(color), do: Atom.to_string(color)

  # Children rendering

  defp render_children(nil, _properties, _opts), do: ""
  defp render_children([], _properties, _opts), do: ""

  defp render_children(children, properties, opts) do
    cell_opts = Keyword.merge(opts, [context: :grid, parent_properties: properties])

    children
    |> Enum.map(fn child -> render_child(child, cell_opts) end)
    |> Enum.join("")
  end

  defp render_child(%IR.Cell{} = cell, opts) do
    AshReports.Renderer.Html.Cell.render(cell, opts)
  end

  defp render_child(%IR.Row{cells: cells}, opts) do
    cells
    |> Enum.map(fn cell -> render_child(cell, opts) end)
    |> Enum.join("")
  end

  defp render_child(_, _opts) do
    ~s(<div class="ash-cell"></div>)
  end
end
