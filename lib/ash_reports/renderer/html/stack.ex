defmodule AshReports.Renderer.Html.Stack do
  @moduledoc """
  HTML renderer for stack layouts using CSS Flexbox.

  Generates Flexbox HTML from StackIR with all supported properties:
  - dir mapped to flex-direction
  - spacing mapped to gap

  ## Direction Mapping

  - `:ttb` → `flex-direction: column` (top to bottom)
  - `:btt` → `flex-direction: column-reverse` (bottom to top)
  - `:ltr` → `flex-direction: row` (left to right)
  - `:rtl` → `flex-direction: row-reverse` (right to left)

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :stack, properties: %{dir: :ttb, spacing: "10pt"}}
      iex> AshReports.Renderer.Html.Stack.render(ir)
      ~s(<div class="ash-stack" style="display: flex; flex-direction: column; gap: 10px;"></div>)
  """

  alias AshReports.Layout.IR

  @doc """
  Renders a StackIR to HTML with CSS Flexbox.

  ## Parameters

  - `ir` - The StackIR struct to render
  - `opts` - Rendering options

  ## Returns

  String containing the HTML with Flexbox styling.
  """
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: :stack} = ir, opts \\ []) do
    styles = build_styles(ir.properties)
    children = render_children(ir.children, opts)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    if children == "" do
      ~s(<div class="ash-stack"#{style_attr}></div>)
    else
      ~s(<div class="ash-stack"#{style_attr}>#{children}</div>)
    end
  end

  @doc """
  Builds the CSS style string for a stack container.
  """
  @spec build_styles(map()) :: String.t()
  def build_styles(properties) do
    styles =
      ["display: flex"]
      |> maybe_add_direction(properties)
      |> maybe_add_spacing(properties)
      |> Enum.reverse()

    Enum.join(styles, "; ")
  end

  # Style builders

  defp maybe_add_direction(styles, %{dir: dir}) when not is_nil(dir) do
    ["flex-direction: #{render_direction(dir)}" | styles]
  end

  defp maybe_add_direction(styles, _) do
    # Default to column (top to bottom)
    ["flex-direction: column" | styles]
  end

  defp maybe_add_spacing(styles, %{spacing: spacing}) when not is_nil(spacing) do
    ["gap: #{render_length(spacing)}" | styles]
  end

  defp maybe_add_spacing(styles, _), do: styles

  # Direction rendering

  @doc """
  Renders a direction value to CSS flex-direction.

  ## Directions

  - `:ttb` - Top to bottom → column
  - `:btt` - Bottom to top → column-reverse
  - `:ltr` - Left to right → row
  - `:rtl` - Right to left → row-reverse

  ## Examples

      iex> render_direction(:ttb)
      "column"

      iex> render_direction(:ltr)
      "row"
  """
  @spec render_direction(atom() | String.t()) :: String.t()
  def render_direction(:ttb), do: "column"
  def render_direction(:btt), do: "column-reverse"
  def render_direction(:ltr), do: "row"
  def render_direction(:rtl), do: "row-reverse"
  def render_direction("ttb"), do: "column"
  def render_direction("btt"), do: "column-reverse"
  def render_direction("ltr"), do: "row"
  def render_direction("rtl"), do: "row-reverse"
  # Default to column for unknown directions
  def render_direction(_), do: "column"

  # Length rendering

  @doc """
  Renders a length value to CSS syntax.
  """
  @spec render_length(String.t() | number() | atom()) :: String.t()
  def render_length(:auto), do: "auto"
  def render_length("auto"), do: "auto"
  def render_length(length) when is_binary(length) do
    # Convert pt to px
    if String.ends_with?(length, "pt") do
      String.replace(length, "pt", "px")
    else
      length
    end
  end
  def render_length(length) when is_number(length), do: "#{length}px"

  # Children rendering

  defp render_children([], _opts), do: ""

  defp render_children(children, opts) do
    children
    |> Enum.map(fn child -> render_child(child, opts) end)
    |> Enum.join("")
  end

  defp render_child(%IR{type: :grid} = nested_ir, opts) do
    # Recursively render nested grid
    AshReports.Renderer.Html.Grid.render(nested_ir, opts)
  end

  defp render_child(%IR{type: :table} = nested_ir, opts) do
    # Recursively render nested table
    AshReports.Renderer.Html.Table.render(nested_ir, opts)
  end

  defp render_child(%IR{type: :stack} = nested_ir, opts) do
    # Recursively render nested stack
    render(nested_ir, opts)
  end

  defp render_child(%IR.Cell{} = cell, opts) do
    # Use Cell renderer for cells
    AshReports.Renderer.Html.Cell.render(cell, Keyword.merge(opts, [context: :stack]))
  end

  defp render_child(%{text: text}, _opts) do
    # Direct label content
    escaped = escape_html(text)
    ~s(<span class="ash-label">#{escaped}</span>)
  end

  defp render_child(%{value: value}, _opts) do
    # Direct field content
    escaped = escape_html(to_string(value))
    ~s(<span class="ash-field">#{escaped}</span>)
  end

  defp render_child(_, _opts) do
    ~s(<div class="ash-item"></div>)
  end

  # HTML escaping

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
