defmodule AshReports.Renderer.Typst do
  @moduledoc """
  Main Typst renderer entry point.

  Generates complete Typst markup from report IR for PDF generation.
  Dispatches to specialized renderers for grids, tables, stacks, lines, etc.

  ## Examples

      iex> ir = %AshReports.Layout.IR{type: :grid, properties: %{columns: ["1fr", "1fr"]}}
      iex> AshReports.Renderer.Typst.render(ir)
      "#grid(\\n  columns: (1fr, 1fr),\\n)"

      iex> report_ir = [grid_ir, table_ir]
      iex> AshReports.Renderer.Typst.render_report(report_ir, %{title: "Report"})
      "// Generated Typst report\\n#grid(...)\\n#table(...)"
  """

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Typst.{Grid, Table, Stack, Lines}

  @doc """
  Renders a single layout IR to Typst markup.

  ## Parameters

  - `ir` - The LayoutIR to render (grid, table, or stack)
  - `opts` - Rendering options
    - `:data` - Data context for field interpolation
    - `:indent` - Current indentation level

  ## Returns

  String containing the Typst markup.
  """
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: type} = ir, opts \\ []) do
    case type do
      :grid -> render_grid(ir, opts)
      :table -> render_table(ir, opts)
      :stack -> render_stack(ir, opts)
    end
  end

  @doc """
  Renders a complete report from multiple layout IRs.

  Combines multiple bands/layouts into a single Typst document.

  ## Parameters

  - `layouts` - List of LayoutIR structs to render
  - `data` - Data context for field interpolation
  - `opts` - Rendering options
    - `:title` - Optional document title
    - `:page_size` - Page size (default: "a4")
    - `:margin` - Page margins

  ## Returns

  String containing the complete Typst document.
  """
  @spec render_report([IR.t()], map(), keyword()) :: String.t()
  def render_report(layouts, data \\ %{}, opts \\ []) when is_list(layouts) do
    render_opts = Keyword.put(opts, :data, data)

    preamble = build_preamble(opts)
    content = render_layouts(layouts, render_opts)

    if preamble == "" do
      content
    else
      "#{preamble}\n\n#{content}"
    end
  end

  @doc """
  Renders multiple layouts in sequence.

  ## Parameters

  - `layouts` - List of LayoutIR structs
  - `opts` - Rendering options

  ## Returns

  String containing all layouts rendered and joined.
  """
  @spec render_layouts([IR.t()], keyword()) :: String.t()
  def render_layouts(layouts, opts \\ []) when is_list(layouts) do
    layouts
    |> Enum.map(&render(&1, opts))
    |> Enum.join("\n\n")
  end

  # Individual layout renderers

  defp render_grid(%IR{type: :grid} = ir, opts) do
    rendered = Grid.render(ir, opts)
    lines = render_lines(ir.lines, opts, :grid)

    if lines == "" do
      rendered
    else
      # Insert lines before closing paren
      insert_lines_in_layout(rendered, lines)
    end
  end

  defp render_table(%IR{type: :table} = ir, opts) do
    rendered = Table.render(ir, opts)
    lines = render_lines(ir.lines, opts, :table)

    if lines == "" do
      rendered
    else
      insert_lines_in_layout(rendered, lines)
    end
  end

  defp render_stack(%IR{type: :stack} = ir, opts) do
    Stack.render(ir, opts)
  end

  # Line rendering

  defp render_lines([], _opts, _context), do: ""

  defp render_lines(lines, opts, context) do
    line_opts = Keyword.put(opts, :context, context)
    indent = Keyword.get(opts, :indent, 0) + 1

    lines
    |> Enum.map(fn line ->
      Lines.render(line, Keyword.put(line_opts, :indent, indent))
    end)
    |> Enum.join("\n")
  end

  # Insert lines into layout before closing paren
  defp insert_lines_in_layout(layout, lines) do
    # Find the last closing paren and insert lines before it
    case String.split(layout, "\n") |> List.last() do
      ")" ->
        parts = String.split(layout, "\n")
        init = Enum.drop(parts, -1)
        (init ++ [lines, ")"]) |> Enum.join("\n")

      _ ->
        # Fallback: just append
        layout <> "\n" <> lines
    end
  end

  # Document preamble

  defp build_preamble(opts) do
    parts = []

    parts =
      case Keyword.get(opts, :page_size) do
        nil -> parts
        size -> ["#set page(paper: \"#{size}\")" | parts]
      end

    parts =
      case Keyword.get(opts, :margin) do
        nil -> parts
        margin -> ["#set page(margin: #{margin})" | parts]
      end

    parts =
      case Keyword.get(opts, :font) do
        nil -> parts
        font -> ["#set text(font: \"#{font}\")" | parts]
      end

    parts =
      case Keyword.get(opts, :font_size) do
        nil -> parts
        size -> ["#set text(size: #{size})" | parts]
      end

    parts
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc """
  Checks if a layout type is supported.
  """
  @spec supported_type?(atom()) :: boolean()
  def supported_type?(type) when type in [:grid, :table, :stack], do: true
  def supported_type?(_), do: false
end
