defmodule AshReports.Renderer.Html do
  @moduledoc """
  Main HTML renderer entry point for AshReports.

  This module provides the primary interface for rendering report IR to HTML.
  It dispatches to the appropriate layout renderer (Grid, Table, Stack) based
  on the IR type and handles multiple bands/layouts in sequence.

  ## Usage

      # Render a single layout IR
      html = AshReports.Renderer.Html.render(grid_ir, data: %{name: "Report"})

      # Render multiple layouts (bands)
      html = AshReports.Renderer.Html.render_all([header_ir, body_ir, footer_ir], data: data)

  ## Options

  - `:data` - Map of data for field interpolation
  - `:wrap` - Whether to wrap output in a container div (default: false)
  - `:class` - CSS class for the wrapper div

  ## Output Formats

  - `:html` - Raw HTML string
  - `:heex` - Phoenix.HTML safe output for LiveView
  """

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Html.{Grid, Table, Stack}

  @doc """
  Renders a single IR layout to HTML.

  ## Parameters

  - `ir` - The LayoutIR to render
  - `opts` - Rendering options including :data for interpolation

  ## Returns

  String containing the complete HTML output.

  ## Examples

      iex> ir = AshReports.Layout.IR.grid(properties: %{columns: ["1fr", "1fr"]})
      iex> AshReports.Renderer.Html.render(ir)
      ~s(<div class="ash-grid" style="display: grid; grid-template-columns: 1fr 1fr;"></div>)
  """
  @spec render(IR.t(), keyword()) :: String.t()
  def render(%IR{type: type} = ir, opts \\ []) do
    case type do
      :grid -> Grid.render(ir, opts)
      :table -> Table.render(ir, opts)
      :stack -> Stack.render(ir, opts)
    end
  end

  @doc """
  Renders multiple IR layouts (bands) to HTML.

  Use this for rendering complete reports with header, detail, and footer bands.

  ## Parameters

  - `layouts` - List of LayoutIR structs to render in sequence
  - `opts` - Rendering options

  ## Returns

  String containing all rendered HTML concatenated.

  ## Examples

      iex> layouts = [header_ir, detail_ir, footer_ir]
      iex> AshReports.Renderer.Html.render_all(layouts, data: report_data)
      "<div>...</div><div>...</div><div>...</div>"
  """
  @spec render_all([IR.t()], keyword()) :: String.t()
  def render_all(layouts, opts \\ []) when is_list(layouts) do
    wrap = Keyword.get(opts, :wrap, false)
    class = Keyword.get(opts, :class, "ash-report")

    content =
      layouts
      |> Enum.map(fn ir -> render(ir, opts) end)
      |> Enum.join("")

    if wrap do
      ~s(<div class="#{class}">#{content}</div>)
    else
      content
    end
  end

  @doc """
  Renders IR to Phoenix.HTML safe output for HEEX templates.

  This wraps the HTML output in a Phoenix.HTML.raw/1 call to mark it as safe
  for rendering in LiveView templates.

  ## Parameters

  - `ir` - The LayoutIR or list of LayoutIRs to render
  - `opts` - Rendering options

  ## Returns

  Phoenix.HTML safe tuple.

  ## Examples

      iex> ir = AshReports.Layout.IR.grid(properties: %{columns: ["1fr"]})
      iex> AshReports.Renderer.Html.render_safe(ir)
      {:safe, "<div class=\\"ash-grid\\" ...></div>"}
  """
  @spec render_safe(IR.t() | [IR.t()], keyword()) :: {:safe, String.t()}
  def render_safe(ir_or_layouts, opts \\ [])

  def render_safe(%IR{} = ir, opts) do
    {:safe, render(ir, opts)}
  end

  def render_safe(layouts, opts) when is_list(layouts) do
    {:safe, render_all(layouts, opts)}
  end

  @doc """
  Renders IR with a complete HTML document wrapper.

  Useful for generating standalone HTML files or previews.

  ## Parameters

  - `ir_or_layouts` - Single IR or list of IRs to render
  - `opts` - Rendering options

  ## Options

  - `:title` - Document title (default: "Report")
  - `:styles` - Additional CSS styles to include
  - `:data` - Data for interpolation

  ## Returns

  String containing complete HTML document.

  ## Examples

      iex> ir = AshReports.Layout.IR.grid(properties: %{columns: ["1fr"]})
      iex> AshReports.Renderer.Html.render_document(ir, title: "My Report")
      "<!DOCTYPE html>..."
  """
  @spec render_document(IR.t() | [IR.t()], keyword()) :: String.t()
  def render_document(ir_or_layouts, opts \\ []) do
    title = Keyword.get(opts, :title, "Report")
    styles = Keyword.get(opts, :styles, default_styles())

    content =
      case ir_or_layouts do
        %IR{} = ir -> render(ir, opts)
        layouts when is_list(layouts) -> render_all(layouts, Keyword.put(opts, :wrap, true))
      end

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{escape_html(title)}</title>
      <style>
    #{styles}
      </style>
    </head>
    <body>
      #{content}
    </body>
    </html>
    """
  end

  @doc """
  Returns the default CSS styles for HTML reports.

  These provide sensible defaults for the ash-* CSS classes.
  """
  @spec default_styles() :: String.t()
  def default_styles do
    """
        * {
          box-sizing: border-box;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
          margin: 0;
          padding: 20px;
        }

        .ash-report {
          max-width: 1200px;
          margin: 0 auto;
        }

        .ash-grid {
          margin-bottom: 1em;
        }

        .ash-table {
          margin-bottom: 1em;
        }

        .ash-stack {
          margin-bottom: 1em;
        }

        .ash-cell {
          padding: 4px;
        }

        .ash-header {
          background-color: #f5f5f5;
          font-weight: bold;
        }

        .ash-footer {
          background-color: #f0f0f0;
        }

        .ash-label {
          color: #666;
        }

        .ash-field {
          font-weight: 500;
        }
    """
  end

  # Helper to escape HTML in document title
  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(text), do: escape_html(to_string(text))
end
