defmodule AshReports.IrHtmlRenderer do
  @moduledoc """
  Modern IR-based HTML Renderer using CSS Grid layouts.

  This renderer implements the Renderer behaviour to generate HTML output
  by converting report bands through the Layout IR system and rendering
  with CSS Grid-based HTML components.

  ## Architecture

  The HTML generation follows this pipeline:
  1. Report Definition (Bands with grids/tables/stacks) -> Layout IR
  2. Layout IR -> HTML with CSS Grid (via Html.Grid, Html.Table, Html.Stack)
  3. Assemble complete HTML document with styles

  ## Benefits over Legacy Renderer

  - **CSS Grid Layout**: Elements flow naturally without absolute positioning
  - **Responsive**: Works across screen sizes
  - **Semantic HTML**: Uses proper table/div structures
  - **No coordinate calculation**: No need for x/y positioning

  ## Usage

      context = RenderContext.new(report, data_result)
      {:ok, result} = IrHtmlRenderer.render_with_context(context)

      # result.content contains complete HTML
      File.write!("report.html", result.content)

  """

  @behaviour AshReports.Renderer

  require Logger

  alias AshReports.{Band, RenderContext}
  alias AshReports.Layout.Transformer.{Grid, Table, Stack}
  alias AshReports.Renderer.Html

  @doc """
  Renders a report to HTML format using IR-based CSS Grid layout.

  Implements the Renderer behaviour's main rendering function.
  """
  @impl AshReports.Renderer
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, html_context} <- prepare_html_context(context, opts),
         {:ok, html_content} <- generate_html_content(html_context),
         {:ok, final_html} <- wrap_in_document(html_content, html_context),
         {:ok, metadata} <- build_html_metadata(html_context, start_time) do
      result = %{
        content: final_html,
        metadata: metadata,
        context: html_context
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  HTML renderer supports streaming for large datasets.
  """
  @impl AshReports.Renderer
  def supports_streaming?, do: true

  @doc """
  Returns the file extension for HTML format.
  """
  @impl AshReports.Renderer
  def file_extension, do: "html"

  @doc """
  Returns the MIME content type for HTML format.
  """
  @impl AshReports.Renderer
  def content_type, do: "text/html"

  @doc """
  Validates that the context is suitable for HTML rendering.
  """
  @impl AshReports.Renderer
  def validate_context(%RenderContext{} = context) do
    with :ok <- validate_report_exists(context),
         :ok <- validate_data_exists(context) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Prepares the renderer for HTML generation.
  """
  @impl AshReports.Renderer
  def prepare(%RenderContext{} = context, opts) do
    html_config = build_html_config(opts)
    updated_config = Map.put(context.config, :html, html_config)
    enhanced_context = %{context | config: updated_config}

    {:ok, enhanced_context}
  end

  @doc """
  Cleans up after HTML rendering.
  """
  @impl AshReports.Renderer
  def cleanup(%RenderContext{} = _context, _result) do
    :ok
  end

  @doc """
  Legacy render callback for backward compatibility.
  """
  @impl AshReports.Renderer
  def render(report_module, data, opts) do
    config = Keyword.get(opts, :config, %{})
    context = RenderContext.new(report_module, %{records: data}, config)

    case render_with_context(context, opts) do
      {:ok, result} -> {:ok, result.content}
      {:error, _reason} = error -> error
    end
  end

  # Private implementation functions

  defp prepare_html_context(%RenderContext{} = context, opts) do
    with {:ok, prepared} <- prepare(context, opts) do
      {:ok, prepared}
    end
  end

  defp generate_html_content(%RenderContext{} = context) do
    report = context.report
    bands = report.bands || []

    # Separate bands by type
    {title_bands, other_bands} = Enum.split_with(bands, &(&1.type == :title))
    {column_header_bands, other_bands} = Enum.split_with(other_bands, &(&1.type == :column_header))
    {group_header_bands, other_bands} = Enum.split_with(other_bands, &(&1.type == :group_header))
    {detail_bands, other_bands} = Enum.split_with(other_bands, &(&1.type == :detail))
    {group_footer_bands, other_bands} = Enum.split_with(other_bands, &(&1.type == :group_footer))
    {_footer_bands, summary_bands} = Enum.split_with(other_bands, &(&1.type in [:page_footer, :column_footer]))

    # All bands have access to report-level variables for label interpolation
    report_variables = context.variables || %{}

    # Build the HTML sections
    title_html = render_bands_section(title_bands, context, report_variables)
    column_header_html = render_bands_section(column_header_bands, context, report_variables)

    # Handle grouped or ungrouped data
    data_html =
      if has_groups?(context) do
        render_grouped_data(context, group_header_bands, detail_bands, group_footer_bands)
      else
        render_ungrouped_data(context, detail_bands)
      end

    # Summary bands also use report-level variables
    summary_html = render_bands_section(summary_bands, context, report_variables)

    content = [
      title_html,
      column_header_html,
      data_html,
      summary_html
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")

    {:ok, content}
  rescue
    error ->
      Logger.error("HTML generation failed: #{inspect(error)}")
      {:error, {:html_generation_failed, error}}
  end

  defp has_groups?(%RenderContext{groups: groups}) do
    cond do
      is_list(groups) and length(groups) > 0 -> true
      is_map(groups) and map_size(groups) > 0 -> true
      true -> false
    end
  end

  defp render_grouped_data(context, group_header_bands, detail_bands, group_footer_bands) do
    context.groups
    |> Enum.map(fn group ->
      group_data = build_group_data(group, context)

      # Group header
      header_html =
        group_header_bands
        |> Enum.map(fn band -> render_band(band, context, group_data) end)
        |> Enum.join("\n")

      # Detail records for this group
      detail_html =
        group.records
        |> Enum.map(fn record ->
          record_data = Map.merge(group_data, record)
          detail_bands
          |> Enum.map(fn band -> render_band(band, context, record_data) end)
          |> Enum.join("\n")
        end)
        |> Enum.join("\n")

      # Group footer
      footer_html =
        group_footer_bands
        |> Enum.map(fn band -> render_band(band, context, group_data) end)
        |> Enum.join("\n")

      [header_html, detail_html, footer_html]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end)
    |> Enum.join("\n")
  end

  defp render_ungrouped_data(context, detail_bands) do
    context.records
    |> Enum.map(fn record ->
      data = build_record_data(record, context)
      detail_bands
      |> Enum.map(fn band -> render_band(band, context, data) end)
      |> Enum.join("\n")
    end)
    |> Enum.join("\n")
  end

  defp render_bands_section(bands, context, data) do
    bands
    |> Enum.map(fn band -> render_band(band, context, data) end)
    |> Enum.join("\n")
  end

  defp render_band(%Band{} = band, context, data) do
    grids = band.grids || []
    tables = band.tables || []
    stacks = band.stacks || []

    opts = [data: data, variables: context.variables]

    rendered_grids = Enum.map(grids, &render_grid(&1, opts))
    rendered_tables = Enum.map(tables, &render_table(&1, opts))
    rendered_stacks = Enum.map(stacks, &render_stack(&1, opts))

    all_content = rendered_grids ++ rendered_tables ++ rendered_stacks

    if Enum.empty?(all_content) do
      ""
    else
      content = Enum.join(all_content, "\n")
      # Wrap band in a section for styling
      band_class = band_class_name(band.type)
      ~s(<section class="ash-band #{band_class}">#{content}</section>)
    end
  end

  defp render_grid(grid, opts) do
    case Grid.transform(grid) do
      {:ok, ir} ->
        # Merge data into opts for field interpolation
        Html.Grid.render(ir, opts)

      {:error, reason} ->
        Logger.warning("Failed to transform grid #{grid.name}: #{inspect(reason)}")
        "<!-- Grid transformation failed: #{grid.name} -->"
    end
  end

  defp render_table(table, opts) do
    case Table.transform(table) do
      {:ok, ir} ->
        Html.Table.render(ir, opts)

      {:error, reason} ->
        Logger.warning("Failed to transform table #{table.name}: #{inspect(reason)}")
        "<!-- Table transformation failed: #{table.name} -->"
    end
  end

  defp render_stack(stack, opts) do
    case Stack.transform(stack) do
      {:ok, ir} ->
        Html.Stack.render(ir, opts)

      {:error, reason} ->
        Logger.warning("Failed to transform stack #{stack.name}: #{inspect(reason)}")
        "<!-- Stack transformation failed: #{stack.name} -->"
    end
  end

  defp build_group_data(group, context) do
    # Start with context variables
    base_data = context.variables || %{}

    # Calculate group-level aggregates from the group's records
    # Variables with reset_on: :group need to be computed per-group
    group_variables = get_group_variables(context.report)
    calculated_aggregates = calculate_group_aggregates(group.records, group_variables)

    # Add group value and record count
    base_data
    |> Map.merge(calculated_aggregates)
    |> Map.put(:group_value, group.group_value)
    |> Map.put(:group_record_count, group.record_count)
    |> Map.put(:group_customer_count, group.record_count)
  end

  # Extract variables that are scoped to groups
  defp get_group_variables(report) do
    (report.variables || [])
    |> Enum.filter(fn var -> var.reset_on == :group end)
  end

  # Calculate aggregates for a group from its records
  defp calculate_group_aggregates(records, variables) do
    Enum.reduce(variables, %{}, fn var, acc ->
      value = calculate_variable_value(records, var)
      Map.put(acc, var.name, value)
    end)
  end

  # Calculate the value of a variable from records
  defp calculate_variable_value(records, %{type: :count}) do
    length(records)
  end

  defp calculate_variable_value(records, %{type: :sum, expression: expr}) do
    records
    |> Enum.map(&get_expression_value(&1, expr))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(0, fn val, acc ->
      numeric_val = to_number(val)
      acc + numeric_val
    end)
  end

  defp calculate_variable_value(records, %{type: :average, expression: expr}) do
    values =
      records
      |> Enum.map(&get_expression_value(&1, expr))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_number/1)

    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0
    end
  end

  defp calculate_variable_value(_records, _var), do: nil

  # Get value from a record using an expression (field name)
  defp get_expression_value(record, expr) when is_atom(expr) do
    Map.get(record, expr)
  end

  defp get_expression_value(record, %Ash.Query.Ref{attribute: attr}) when is_atom(attr) do
    Map.get(record, attr)
  end

  defp get_expression_value(record, %Ash.Query.Ref{attribute: %{name: name}}) do
    Map.get(record, name)
  end

  defp get_expression_value(_record, _expr), do: nil

  # Convert various numeric types to a number
  defp to_number(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_number(n) when is_number(n), do: n
  defp to_number(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0
    end
  end
  defp to_number(_), do: 0

  defp build_record_data(record, context) do
    # Merge context variables with record data
    variables = context.variables || %{}
    Map.merge(variables, record)
  end

  defp band_class_name(:title), do: "ash-band-title"
  defp band_class_name(:page_header), do: "ash-band-page-header"
  defp band_class_name(:column_header), do: "ash-band-column-header"
  defp band_class_name(:group_header), do: "ash-band-group-header"
  defp band_class_name(:detail), do: "ash-band-detail"
  defp band_class_name(:group_footer), do: "ash-band-group-footer"
  defp band_class_name(:page_footer), do: "ash-band-page-footer"
  defp band_class_name(:summary), do: "ash-band-summary"
  defp band_class_name(_), do: "ash-band-unknown"

  defp wrap_in_document(content, %RenderContext{} = context) do
    title = get_report_title(context)
    styles = default_styles()

    html = """
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
      <main class="ash-report">
        #{content}
      </main>
    </body>
    </html>
    """

    {:ok, html}
  end

  defp get_report_title(%RenderContext{report: report}) do
    report.title || to_string(report.name) |> String.replace("_", " ") |> String.capitalize()
  end

  defp default_styles do
    """
        * {
          box-sizing: border-box;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
          margin: 0;
          padding: 20px;
          background-color: #f9fafb;
        }

        .ash-report {
          max-width: 1200px;
          margin: 0 auto;
          background: white;
          padding: 20px;
          border-radius: 8px;
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        }

        .ash-band {
          margin-bottom: 1em;
        }

        .ash-band-title {
          margin-bottom: 1.5em;
        }

        .ash-band-column-header {
          font-weight: bold;
          background-color: #f3f4f6;
          padding: 8px;
          border-radius: 4px;
        }

        .ash-band-group-header {
          background-color: #e5e7eb;
          padding: 8px;
          margin-top: 1em;
          border-radius: 4px;
          font-weight: 600;
        }

        .ash-band-group-footer {
          background-color: #f9fafb;
          padding: 8px;
          border-top: 1px solid #e5e7eb;
          font-weight: 500;
        }

        .ash-band-summary {
          background-color: #f3f4f6;
          padding: 12px;
          margin-top: 1em;
          border-radius: 4px;
          font-weight: bold;
        }

        .ash-grid {
          margin-bottom: 0.5em;
        }

        .ash-table {
          width: 100%;
          margin-bottom: 0.5em;
        }

        .ash-table th,
        .ash-table td {
          padding: 8px 12px;
          text-align: left;
          border-bottom: 1px solid #e5e7eb;
        }

        .ash-table th {
          background-color: #f9fafb;
          font-weight: 600;
        }

        .ash-table tbody tr:hover {
          background-color: #f9fafb;
        }

        .ash-header {
          background-color: #f3f4f6;
        }

        .ash-footer {
          background-color: #f9fafb;
          font-weight: 500;
        }

        .ash-cell {
          padding: 4px 8px;
        }

        .ash-label {
          color: #6b7280;
        }

        .ash-field {
          font-weight: 500;
        }

        .ash-stack {
          display: flex;
          flex-direction: column;
          gap: 4px;
        }
    """
  end

  defp build_html_metadata(%RenderContext{} = context, start_time) do
    end_time = System.monotonic_time(:microsecond)
    render_time = end_time - start_time

    metadata = %{
      format: :html,
      render_time_us: render_time,
      html_engine: :ir_css_grid,
      record_count: length(context.records),
      variable_count: map_size(context.variables),
      group_count: group_count(context.groups),
      renderer_version: "2.0.0-ir"
    }

    {:ok, metadata}
  end

  defp group_count(groups) when is_list(groups), do: length(groups)
  defp group_count(groups) when is_map(groups), do: map_size(groups)
  defp group_count(_), do: 0

  defp validate_report_exists(%RenderContext{report: nil}), do: {:error, :missing_report}
  defp validate_report_exists(_context), do: :ok

  defp validate_data_exists(%RenderContext{records: []}), do: {:error, :no_data_to_render}
  defp validate_data_exists(_context), do: :ok

  defp build_html_config(opts) do
    %{
      responsive: Keyword.get(opts, :responsive, true),
      include_styles: Keyword.get(opts, :include_styles, true),
      theme: Keyword.get(opts, :theme, :default)
    }
  end

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(text), do: escape_html(to_string(text))
end
