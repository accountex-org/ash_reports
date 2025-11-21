defmodule AshReports.Renderer.Typst.Stack do
  @moduledoc """
  Typst renderer for stack layouts.

  Generates Typst stack() function calls from StackIR with all supported properties:
  - dir (direction: ttb, btt, ltr, rtl)
  - spacing

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :stack, properties: %{dir: :ttb, spacing: "10pt"}}
      iex> AshReports.Renderer.Typst.Stack.render(ir)
      "#stack(\\n  dir: ttb,\\n  spacing: 10pt,\\n)"
  """

  alias AshReports.Layout.IR

  @doc """
  Renders a StackIR to Typst stack() markup.

  ## Parameters

  - `ir` - The StackIR struct to render
  - `opts` - Rendering options (reserved for future use)

  ## Returns

  String containing the Typst stack() function call.
  """
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: :stack} = ir, opts \\ []) do
    indent = Keyword.get(opts, :indent, 0)
    indent_str = String.duplicate("  ", indent)

    params = build_parameters(ir.properties)
    children = render_children(ir.children, indent + 1)

    if children == "" do
      "#{indent_str}#stack(\n#{params}#{indent_str})"
    else
      "#{indent_str}#stack(\n#{params}#{children}\n#{indent_str})"
    end
  end

  @doc """
  Builds the parameter list for a stack() call.
  """
  @spec build_parameters(map()) :: String.t()
  def build_parameters(properties) do
    params =
      []
      |> maybe_add_dir(properties)
      |> maybe_add_spacing(properties)
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

  defp maybe_add_dir(params, %{dir: dir}) when not is_nil(dir) do
    ["dir: #{render_direction(dir)}" | params]
  end

  defp maybe_add_dir(params, _), do: params

  defp maybe_add_spacing(params, %{spacing: spacing}) when not is_nil(spacing) do
    ["spacing: #{render_length(spacing)}" | params]
  end

  defp maybe_add_spacing(params, _), do: params

  # Direction rendering

  @doc """
  Renders a direction value to Typst syntax.

  ## Directions

  - `:ttb` / `:ltr` - Top to bottom / Left to right
  - `:btt` / `:rtl` - Bottom to top / Right to left

  ## Examples

      iex> render_direction(:ttb)
      "ttb"

      iex> render_direction("ltr")
      "ltr"
  """
  @spec render_direction(atom() | String.t()) :: String.t()
  def render_direction(dir) when is_atom(dir), do: Atom.to_string(dir)
  def render_direction(dir) when is_binary(dir), do: dir

  # Length rendering

  @doc """
  Renders a length value to Typst syntax.
  """
  @spec render_length(String.t() | number() | atom()) :: String.t()
  def render_length(:auto), do: "auto"
  def render_length("auto"), do: "auto"
  def render_length(length) when is_binary(length), do: length
  def render_length(length) when is_number(length), do: "#{length}pt"

  # Children rendering

  defp render_children([], _indent), do: ""

  defp render_children(children, indent) do
    indent_str = String.duplicate("  ", indent)

    children
    |> Enum.map(fn child -> render_child(child, indent_str, indent) end)
    |> Enum.join(",\n")
  end

  defp render_child(%IR{type: :grid} = nested_ir, _indent_str, indent) do
    # Recursively render nested grid
    AshReports.Renderer.Typst.Grid.render(nested_ir, indent: indent)
  end

  defp render_child(%IR{type: :table} = nested_ir, _indent_str, indent) do
    # Recursively render nested table
    AshReports.Renderer.Typst.Table.render(nested_ir, indent: indent)
  end

  defp render_child(%IR{type: :stack} = nested_ir, _indent_str, indent) do
    # Recursively render nested stack
    render(nested_ir, indent: indent)
  end

  defp render_child(%IR.Cell{content: content}, indent_str, _indent) do
    # Render cell content directly
    text =
      content
      |> Enum.map(&extract_text/1)
      |> Enum.join(" ")

    "#{indent_str}[#{text}]"
  end

  defp render_child(%{text: text}, indent_str, _indent) do
    # Direct label content
    "#{indent_str}[#{text}]"
  end

  defp render_child(%{value: value}, indent_str, _indent) do
    # Direct field content
    "#{indent_str}[#{value}]"
  end

  defp render_child(_, indent_str, _indent), do: "#{indent_str}[]"

  defp extract_text(%{text: text}), do: text
  defp extract_text(%{value: value}), do: to_string(value)
  defp extract_text(_), do: ""
end
