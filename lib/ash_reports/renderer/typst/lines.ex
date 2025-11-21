defmodule AshReports.Renderer.Typst.Lines do
  @moduledoc """
  Typst renderer for horizontal and vertical lines.

  Generates Typst grid.hline()/grid.vline() or table.hline()/table.vline()
  function calls from LineIR with support for:
  - Position (y for hline, x for vline)
  - Partial lines (start, end)
  - Stroke styling
  - Position within cell (top/bottom for hline, start/end for vline)

  ## Examples

      # Horizontal line at row 2
      iex> line = %AshReports.Layout.IR.Line{orientation: :horizontal, position: 2}
      iex> AshReports.Renderer.Typst.Lines.render(line)
      "grid.hline(y: 2)"

      # Vertical line at column 1 with stroke
      iex> line = %AshReports.Layout.IR.Line{orientation: :vertical, position: 1, stroke: "2pt"}
      iex> AshReports.Renderer.Typst.Lines.render(line, context: :table)
      "table.vline(x: 1, stroke: 2pt)"
  """

  alias AshReports.Layout.IR.Line
  alias AshReports.Renderer.Typst.Grid

  @doc """
  Renders a LineIR to Typst markup.

  ## Parameters

  - `line` - The LineIR struct to render
  - `opts` - Rendering options
    - `:indent` - Current indentation level
    - `:context` - Layout context (:grid or :table)

  ## Returns

  String containing the Typst hline/vline markup.
  """
  @spec render(Line.t(), keyword()) :: String.t()
  def render(%Line{} = line, opts \\ []) do
    indent = Keyword.get(opts, :indent, 0)
    context = Keyword.get(opts, :context, :grid)
    indent_str = String.duplicate("  ", indent)

    func_name = line_function_name(line.orientation, context)
    params = build_line_parameters(line)

    "#{indent_str}#{func_name}(#{params})"
  end

  @doc """
  Renders a horizontal line (hline) to Typst markup.
  """
  @spec render_hline(Line.t(), keyword()) :: String.t()
  def render_hline(%Line{orientation: :horizontal} = line, opts \\ []) do
    render(line, opts)
  end

  @doc """
  Renders a vertical line (vline) to Typst markup.
  """
  @spec render_vline(Line.t(), keyword()) :: String.t()
  def render_vline(%Line{orientation: :vertical} = line, opts \\ []) do
    render(line, opts)
  end

  @doc """
  Builds the parameter list for an hline/vline call.
  """
  @spec build_line_parameters(Line.t()) :: String.t()
  def build_line_parameters(%Line{} = line) do
    params =
      []
      |> add_position(line)
      |> maybe_add_start(line)
      |> maybe_add_end(line)
      |> maybe_add_stroke(line)
      |> Enum.reverse()

    Enum.join(params, ", ")
  end

  # Position parameter (always required)

  defp add_position(params, %Line{orientation: :horizontal, position: y}) do
    ["y: #{y}" | params]
  end

  defp add_position(params, %Line{orientation: :vertical, position: x}) do
    ["x: #{x}" | params]
  end

  # Optional parameters

  defp maybe_add_start(params, %Line{start: start}) when not is_nil(start) do
    ["start: #{start}" | params]
  end

  defp maybe_add_start(params, _), do: params

  defp maybe_add_end(params, %Line{end: end_pos}) when not is_nil(end_pos) do
    ["end: #{end_pos}" | params]
  end

  defp maybe_add_end(params, _), do: params

  defp maybe_add_stroke(params, %Line{stroke: stroke}) when not is_nil(stroke) do
    rendered_stroke = render_stroke_value(stroke)
    ["stroke: #{rendered_stroke}" | params]
  end

  defp maybe_add_stroke(params, _), do: params

  # Stroke value rendering

  defp render_stroke_value(stroke) when is_binary(stroke), do: stroke
  defp render_stroke_value(stroke) when is_atom(stroke), do: Atom.to_string(stroke)
  defp render_stroke_value(stroke) when is_map(stroke), do: Grid.render_stroke(stroke)

  # Function name helpers

  defp line_function_name(:horizontal, :table), do: "table.hline"
  defp line_function_name(:horizontal, _), do: "grid.hline"
  defp line_function_name(:vertical, :table), do: "table.vline"
  defp line_function_name(:vertical, _), do: "grid.vline"
end
