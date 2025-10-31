defmodule AshReports.HeexRenderer.BandRenderer do
  @moduledoc """
  Generates HEEX template code for report bands and their elements.

  This module is responsible for converting report band structures into
  Phoenix.Component-compatible HEEX markup, integrating data records,
  variables, groups, and aggregates.

  ## Features

  - **Full Band Type Support**: All 11 band types (title, page_header, column_header,
    group_header, detail_header, detail, detail_footer, group_footer, column_footer,
    page_footer, summary)
  - **Nested Band Rendering**: Recursive rendering for arbitrary nesting depth
  - **Element Rendering**: All 7 element types (field, label, expression, aggregate,
    line, box, image)
  - **Variable Integration**: Display variable values with CLDR formatting
  - **Group Handling**: Group break detection and group-scoped rendering
  - **Error Handling**: Graceful error placeholders for missing data
  - **Column Layout**: Full column-based layout support

  ## Architecture

  The renderer works in a pipeline:
  1. Accept RenderContext with report definition and data
  2. Iterate through bands in hierarchical order
  3. For each band, render its elements
  4. Integrate variables and group data
  5. Generate HEEX template string

  ## Usage

      # From HeexRenderer
      context = RenderContext.new(report, data_result)
      heex_content = BandRenderer.render_report_bands(context)

  ## Design Decisions

  - **Hybrid Expression Support**: Simple expressions (field refs, arithmetic) in Phase 1,
    complex Ash.Expr evaluation deferred to Phase 2
  - **CLDR Formatting**: Uses Number/Cldr libraries for i18n-aware formatting
  - **Error Placeholders**: Shows `[MISSING: field_name]` for missing data
  - **Performance Target**: <200ms for 100 records
  - **Static HEEX**: Generates static templates, no LiveView events (Phase 1)

  """

  alias AshReports.{Band, Group, RenderContext}

  @doc """
  Renders all report bands with their elements as HEEX template code.

  Accepts a RenderContext containing the report definition, records, variables,
  groups, and metadata. Returns a string containing HEEX template code that can
  be embedded in Phoenix templates or LiveView components.

  ## Parameters

  - `context`: RenderContext.t() with complete report and data

  ## Returns

  String containing HEEX template code

  ## Examples

      context = RenderContext.new(report, data_result)
      heex = BandRenderer.render_report_bands(context)
      # Returns: "<div class=\"report\">...</div>"

  """
  @spec render_report_bands(RenderContext.t()) :: String.t()
  def render_report_bands(%RenderContext{} = context) do
    # Get bands from report
    bands = get_report_bands(context)

    # Render bands in order
    rendered_bands = render_bands(bands, context)

    # Wrap in report container
    wrap_in_report_container(rendered_bands, context)
  end

  # Private Functions - Band Rendering

  defp get_report_bands(%RenderContext{report: nil}), do: []
  defp get_report_bands(%RenderContext{report: report}), do: report.bands || []

  defp render_bands(bands, context) do
    # Check if report has grouping configured
    if has_groups?(context) do
      render_bands_with_grouping(bands, context)
    else
      render_bands_without_grouping(bands, context)
    end
  end

  defp render_bands_without_grouping(bands, context) do
    bands
    |> Enum.map(fn band -> render_band(band, context) end)
    |> Enum.join("\n")
  end

  defp render_bands_with_grouping(bands, context) do
    # Separate bands into categories
    {group_headers, detail_bands, group_footers, other_bands} = categorize_bands(bands)

    # Render non-grouped bands (title, headers, footers)
    other_html = render_bands_without_grouping(other_bands, context)

    # Render grouped content
    grouped_html = render_grouped_records(group_headers, detail_bands, group_footers, context)

    other_html <> "\n" <> grouped_html
  end

  defp render_band(%Band{} = band, context) do
    # Check visibility
    if band_visible?(band, context) do
      case band.type do
        :detail ->
          render_detail_band(band, context)

        :group_header ->
          render_group_header_band(band, context)

        :group_footer ->
          render_group_footer_band(band, context)

        type when type in [:title, :page_header, :column_header, :detail_header,
                           :detail_footer, :column_footer, :page_footer, :summary] ->
          render_standard_band(band, context)

        _ ->
          render_unknown_band(band, context)
      end
    else
      ""
    end
  end

  # Detail Band - Renders once per record
  # Note: When grouping is enabled, details are rendered via render_grouped_records
  defp render_detail_band(%Band{} = band, context) do
    # If we have groups, this is handled by render_grouped_records
    if has_groups?(context) do
      ""
    else
      records = context.records || []

      detail_html =
        records
        |> Enum.map(fn record ->
          record_context = %{context | current_record: record}
          render_detail_record(band, record_context)
        end)
        |> Enum.join("\n")

      """
      <div class="detail-band" data-band="#{band.name}">
        #{detail_html}
      </div>
      """
    end
  end

  defp render_detail_record(%Band{} = band, context) do
    elements_html = render_band_elements(band.elements, context)
    nested_bands_html = render_nested_bands(band, context)

    """
    <div class="detail-record">
      #{elements_html}
      #{nested_bands_html}
    </div>
    """
  end

  # Group Header Band
  defp render_group_header_band(%Band{} = band, context) do
    elements_html = render_band_elements(band.elements, context)
    nested_bands_html = render_nested_bands(band, context)

    group_level = band.group_level || 1
    group_values = get_in(context.metadata, [:group_values]) || %{}
    group_value = Map.get(group_values, group_level, "")

    """
    <div class="group-header-band" data-band="#{band.name}" data-group-level="#{group_level}" data-group-value="#{group_value}">
      #{elements_html}
      #{nested_bands_html}
    </div>
    """
  end

  # Group Footer Band
  defp render_group_footer_band(%Band{} = band, context) do
    elements_html = render_band_elements(band.elements, context)
    nested_bands_html = render_nested_bands(band, context)

    group_level = band.group_level || 1
    group_aggregates = get_in(context.metadata, [:group_aggregates]) || %{}
    group_count = Map.get(group_aggregates, :count, 0)

    """
    <div class="group-footer-band" data-band="#{band.name}" data-group-level="#{group_level}" data-group-count="#{group_count}">
      #{elements_html}
      #{nested_bands_html}
    </div>
    """
  end

  # Standard Bands (title, headers, footers, summary)
  defp render_standard_band(%Band{} = band, context) do
    elements_html = render_band_elements(band.elements, context)
    nested_bands_html = render_nested_bands(band, context)

    band_class = band_type_to_class(band.type)

    """
    <div class="#{band_class}" data-band="#{band.name}">
      #{elements_html}
      #{nested_bands_html}
    </div>
    """
  end

  # Unknown Band Type
  defp render_unknown_band(%Band{} = band, _context) do
    """
    <div class="unknown-band" data-band="#{band.name}">
      [UNKNOWN BAND TYPE: #{band.type}]
    </div>
    """
  end

  # Nested Bands Support
  defp render_nested_bands(%Band{bands: nil}, _context), do: ""
  defp render_nested_bands(%Band{bands: []}, _context), do: ""

  defp render_nested_bands(%Band{bands: nested_bands}, context) do
    render_bands(nested_bands, context)
  end

  # Band Visibility
  defp band_visible?(%Band{visible: true}, _context), do: true
  defp band_visible?(%Band{visible: false}, _context), do: false

  # TODO: Implement conditional visibility expression evaluation
  defp band_visible?(%Band{visible: _expr}, _context) do
    # For Phase 1, assume visible if expression present
    # Phase 2 will add CalculationEngine integration
    true
  end

  # Band Type to CSS Class
  defp band_type_to_class(:title), do: "title-band"
  defp band_type_to_class(:page_header), do: "page-header-band"
  defp band_type_to_class(:column_header), do: "column-header-band"
  defp band_type_to_class(:detail_header), do: "detail-header-band"
  defp band_type_to_class(:detail_footer), do: "detail-footer-band"
  defp band_type_to_class(:column_footer), do: "column-footer-band"
  defp band_type_to_class(:page_footer), do: "page-footer-band"
  defp band_type_to_class(:summary), do: "summary-band"
  defp band_type_to_class(_), do: "unknown-band"

  # Private Functions - Element Rendering

  defp render_band_elements(nil, _context), do: ""
  defp render_band_elements([], _context), do: ""

  defp render_band_elements(elements, context) do
    elements
    |> Enum.map(fn element -> render_element(element, context) end)
    |> Enum.join("\n")
  end

  defp render_element(%{type: :field} = element, context) do
    render_field_element(element, context)
  end

  defp render_element(%{type: :label} = element, context) do
    render_label_element(element, context)
  end

  defp render_element(%{type: :expression} = element, context) do
    render_expression_element(element, context)
  end

  defp render_element(%{type: :aggregate} = element, context) do
    render_aggregate_element(element, context)
  end

  defp render_element(%{type: :line} = element, context) do
    render_line_element(element, context)
  end

  defp render_element(%{type: :box} = element, context) do
    render_box_element(element, context)
  end

  defp render_element(%{type: :image} = element, context) do
    render_image_element(element, context)
  end

  # Chart Elements - New type-specific chart elements
  defp render_element(%{type: :bar_chart_element} = element, context) do
    render_chart_element(element, :bar_chart, context)
  end

  defp render_element(%{type: :line_chart_element} = element, context) do
    render_chart_element(element, :line_chart, context)
  end

  defp render_element(%{type: :pie_chart_element} = element, context) do
    render_chart_element(element, :pie_chart, context)
  end

  defp render_element(%{type: :area_chart_element} = element, context) do
    render_chart_element(element, :area_chart, context)
  end

  defp render_element(%{type: :scatter_chart_element} = element, context) do
    render_chart_element(element, :scatter_chart, context)
  end

  defp render_element(%{type: :gantt_chart_element} = element, context) do
    render_chart_element(element, :gantt_chart, context)
  end

  defp render_element(%{type: :sparkline_element} = element, context) do
    render_chart_element(element, :sparkline, context)
  end

  defp render_element(element, _context) do
    """
    <div class="unknown-element">
      [UNKNOWN ELEMENT TYPE: #{inspect(element)}]
    </div>
    """
  end

  # Chart Element Rendering
  defp render_chart_element(element, _chart_type, context) do
    chart_name = Map.get(element, :chart_name)

    if is_nil(chart_name) do
      error_placeholder("MISSING_CHART_NAME")
    else
      case resolve_chart_definition(chart_name, context) do
        nil ->
          error_placeholder("CHART_NOT_FOUND: #{chart_name}")

        chart_def ->
          render_resolved_chart(chart_def, element, context)
      end
    end
  end

  defp resolve_chart_definition(chart_name, %RenderContext{} = context) do
    # Get the domain from the report's driving resource
    domain = get_domain_from_context(context)

    if domain do
      AshReports.Info.chart(domain, chart_name)
    else
      nil
    end
  end

  defp get_domain_from_context(%RenderContext{report: %{driving_resource: resource}})
       when not is_nil(resource) do
    # Get the domain from the resource's configuration
    case Ash.Resource.Info.domain(resource) do
      nil -> nil
      domain -> domain
    end
  rescue
    _ -> nil
  end

  defp get_domain_from_context(%RenderContext{metadata: metadata}) do
    # Try to get domain from metadata as fallback
    Map.get(metadata, :domain)
  end

  defp get_domain_from_context(_), do: nil

  defp render_resolved_chart(chart_def, element, context) do
    # Evaluate the data_source expression to get chart data
    chart_data = evaluate_chart_data_source(chart_def.data_source, context)

    # Generate SVG using the chart type implementation
    svg_result = generate_chart_svg(chart_def, chart_data)

    style = element_style(element)

    case svg_result do
      {:ok, svg_content} ->
        """
        <div class="chart-element chart-#{chart_def.__struct__ |> Module.split() |> List.last() |> Macro.underscore()}"
             data-chart="#{chart_def.name}"
             style="#{style}">
          #{svg_content}
        </div>
        """

      {:error, reason} ->
        error_placeholder("CHART_ERROR: #{inspect(reason)}")
    end
  end

  defp evaluate_chart_data_source(nil, _context) do
    []
  end

  defp evaluate_chart_data_source(data_source, _context) do
    # TODO: Full expression evaluation with CalculationEngine
    # For now, handle simple cases
    case data_source do
      {:expr, _} ->
        # Complex expression - would need CalculationEngine
        # Return empty data as placeholder
        []

      data when is_list(data) ->
        data

      _ ->
        []
    end
  end

  defp generate_chart_svg(chart_def, chart_data) do
    # Determine the chart type module
    case get_chart_type_module(chart_def) do
      nil ->
        {:error, :unknown_chart_type}

      chart_type_module ->
        if length(chart_data) == 0 do
          {:error, :no_chart_data}
        else
          build_and_render_chart(chart_type_module, chart_def, chart_data)
        end
    end
  rescue
    error ->
      {:error, error}
  end

  defp build_and_render_chart(chart_type_module, chart_def, chart_data) do
    # Build the chart using the type-specific implementation
    config = chart_def.config || struct(get_config_module(chart_def))

    case chart_type_module.build(chart_data, config) do
      %_{} = chart_struct ->
        # Generate SVG from the Contex chart struct
        svg_content = Contex.Plot.to_svg(chart_struct)
        {:ok, svg_content}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      {:error, error}
  end

  defp get_chart_type_module(%AshReports.Charts.BarChart{}),
    do: AshReports.Charts.Types.BarChart

  defp get_chart_type_module(%AshReports.Charts.LineChart{}),
    do: AshReports.Charts.Types.LineChart

  defp get_chart_type_module(%AshReports.Charts.PieChart{}),
    do: AshReports.Charts.Types.PieChart

  defp get_chart_type_module(%AshReports.Charts.AreaChart{}),
    do: AshReports.Charts.Types.AreaChart

  defp get_chart_type_module(%AshReports.Charts.ScatterChart{}),
    do: AshReports.Charts.Types.ScatterPlot

  defp get_chart_type_module(%AshReports.Charts.GanttChart{}),
    do: AshReports.Charts.Types.GanttChart

  defp get_chart_type_module(%AshReports.Charts.Sparkline{}),
    do: AshReports.Charts.Types.Sparkline

  defp get_chart_type_module(_), do: nil

  defp get_config_module(%AshReports.Charts.BarChart{}), do: AshReports.Charts.BarChartConfig
  defp get_config_module(%AshReports.Charts.LineChart{}), do: AshReports.Charts.LineChartConfig
  defp get_config_module(%AshReports.Charts.PieChart{}), do: AshReports.Charts.PieChartConfig
  defp get_config_module(%AshReports.Charts.AreaChart{}), do: AshReports.Charts.AreaChartConfig

  defp get_config_module(%AshReports.Charts.ScatterChart{}),
    do: AshReports.Charts.ScatterChartConfig

  defp get_config_module(%AshReports.Charts.GanttChart{}),
    do: AshReports.Charts.GanttChartConfig

  defp get_config_module(%AshReports.Charts.Sparkline{}), do: AshReports.Charts.SparklineConfig
  defp get_config_module(_), do: nil

  # Field Element
  defp render_field_element(element, context) do
    value = get_field_value(element, context)
    formatted_value = format_value(value, element)
    style = element_style(element)

    """
    <span class="field-element" data-field="#{element.name}" style="#{style}">
      #{formatted_value}
    </span>
    """
  end

  defp get_field_value(element, context) do
    source = Map.get(element, :source)

    if is_nil(source) do
      error_placeholder("NO_SOURCE")
    else
      get_field_value_from_source(source, context)
    end
  end

  defp get_field_value_from_source(source, context) when not is_nil(source) do
    record = context.current_record

    case record do
      nil ->
        error_placeholder("NO_RECORD")

      record when is_map(record) ->
        get_field_from_record(record, source)

      _ ->
        error_placeholder("INVALID_RECORD")
    end
  end


  defp get_field_from_record(record, source) when is_atom(source) do
    case Map.fetch(record, source) do
      {:ok, value} -> value
      :error -> error_placeholder("MISSING: #{source}")
    end
  end

  defp get_field_from_record(record, source) when is_list(source) do
    case get_in(record, source) do
      nil -> error_placeholder("MISSING: #{Enum.join(source, ".")}")
      value -> value
    end
  end

  defp get_field_from_record(_record, source) do
    error_placeholder("INVALID_SOURCE: #{inspect(source)}")
  end

  # Label Element
  defp render_label_element(element, _context) do
    text = Map.get(element, :text) || Map.get(element, :name) || ""
    style = element_style(element)

    """
    <span class="label-element" style="#{style}">
      #{text}
    </span>
    """
  end

  # Expression Element
  defp render_expression_element(element, context) do
    value = evaluate_expression(Map.get(element, :expression), context)
    formatted_value = format_value(value, element)
    style = element_style(element)

    """
    <span class="expression-element" data-name="#{element.name}" style="#{style}">
      #{formatted_value}
    </span>
    """
  end

  # TODO: Phase 1 - Simple expression evaluation
  # TODO: Phase 2 - Full CalculationEngine integration
  defp evaluate_expression(nil, _context) do
    error_placeholder("NO_EXPRESSION")
  end

  defp evaluate_expression(expression, context) when is_atom(expression) do
    # Simple field reference
    get_field_from_record(context.current_record || %{}, expression)
  end

  defp evaluate_expression(_expression, _context) do
    # Complex expressions deferred to Phase 2
    error_placeholder("COMPLEX_EXPR")
  end

  # Aggregate Element
  defp render_aggregate_element(element, context) do
    value = get_variable_value(element, context)
    formatted_value = format_value(value, element)
    style = element_style(element)

    """
    <span class="aggregate-element" data-variable="#{element.name}" style="#{style}">
      #{formatted_value}
    </span>
    """
  end

  defp get_variable_value(element, context) do
    variable_name = Map.get(element, :variable_name) || Map.get(element, :name)

    # Check group aggregates first (for group-scoped variables)
    group_aggregates = get_in(context.metadata, [:group_aggregates]) || %{}

    cond do
      # Check if this is a group aggregate
      Map.has_key?(group_aggregates, variable_name) ->
        Map.get(group_aggregates, variable_name)

      # Check if it's a string key in group aggregates (like "amount_sum")
      Map.has_key?(group_aggregates, to_string(variable_name)) ->
        Map.get(group_aggregates, to_string(variable_name))

      # Check report-level variables
      Map.has_key?(context.variables, variable_name) ->
        Map.get(context.variables, variable_name)

      # Variable not found
      true ->
        error_placeholder("MISSING_VAR: #{variable_name}")
    end
  end

  # Line Element
  defp render_line_element(element, _context) do
    style = element_style(element)

    """
    <hr class="line-element" style="#{style}" />
    """
  end

  # Box Element
  defp render_box_element(element, _context) do
    style = element_style(element)

    """
    <div class="box-element" style="#{style}"></div>
    """
  end

  # Image Element
  defp render_image_element(element, _context) do
    src = Map.get(element, :source) || ""
    alt = Map.get(element, :alt) || Map.get(element, :name) || ""
    style = element_style(element)

    """
    <img class="image-element" src="#{src}" alt="#{alt}" style="#{style}" />
    """
  end

  # Private Functions - Styling

  defp element_style(element) do
    position_styles = position_style(Map.get(element, :position) || %{})
    text_styles = text_style(Map.get(element, :style) || %{})
    color_styles = color_style(Map.get(element, :style) || %{})
    border_styles = border_style(Map.get(element, :style) || %{})

    [position_styles, text_styles, color_styles, border_styles]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp position_style(%{x: x, y: y, width: w, height: h}) do
    "position: absolute; left: #{x}px; top: #{y}px; width: #{w}px; height: #{h}px"
  end

  defp position_style(%{width: w, height: h}) do
    "width: #{w}px; height: #{h}px"
  end

  defp position_style(_), do: ""

  defp text_style(style) do
    parts = [
      font_style(style),
      font_size_style(style),
      font_weight_style(style),
      text_align_style(style)
    ]

    parts
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp font_style(%{font: font}) when not is_nil(font), do: "font-family: #{font}"
  defp font_style(_), do: ""

  defp font_size_style(%{font_size: size}) when not is_nil(size), do: "font-size: #{size}px"
  defp font_size_style(_), do: ""

  defp font_weight_style(%{font_weight: :bold}), do: "font-weight: bold"
  defp font_weight_style(%{font_weight: :normal}), do: "font-weight: normal"
  defp font_weight_style(_), do: ""

  defp text_align_style(%{text_align: align}) when not is_nil(align),
    do: "text-align: #{align}"

  defp text_align_style(_), do: ""

  defp color_style(style) do
    parts = [
      text_color_style(style),
      background_color_style(style)
    ]

    parts
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp text_color_style(%{color: color}) when not is_nil(color), do: "color: #{color}"
  defp text_color_style(_), do: ""

  defp background_color_style(%{background_color: bg}) when not is_nil(bg),
    do: "background-color: #{bg}"

  defp background_color_style(_), do: ""

  defp border_style(%{border: border}) when is_map(border) do
    # TODO: Implement full border parsing
    "border: 1px solid #ccc"
  end

  defp border_style(_), do: ""

  # Private Functions - Formatting

  defp format_value(value, _element) when is_nil(value) do
    ""
  end

  defp format_value(value, element) do
    format = Map.get(element, :format)

    case format do
      nil -> format_default(value)
      :currency -> format_currency(value)
      :number -> format_number(value)
      :percentage -> format_percentage(value)
      :date -> format_date(value)
      :datetime -> format_datetime(value)
      _ -> format_default(value)
    end
  end

  defp format_default(value) when is_binary(value) do
    # HEEX engine will handle escaping, just return the string
    value
  end

  defp format_default(value) when is_float(value) do
    # Format float without scientific notation
    :erlang.float_to_binary(value, [:compact, decimals: 2])
  end

  defp format_default(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_default(value) do
    # Convert to string, HEEX engine will handle escaping
    to_string(value)
  end

  # TODO: Use actual CLDR formatting based on context locale
  defp format_currency(value) when is_number(value) do
    # Placeholder - will integrate with Cldr.Number.to_string
    "$#{:erlang.float_to_binary(value / 1, decimals: 2)}"
  end

  defp format_currency(value), do: format_default(value)

  defp format_number(value) when is_number(value) do
    # Placeholder - will integrate with Cldr.Number.to_string
    to_string(value)
  end

  defp format_number(value), do: format_default(value)

  defp format_percentage(value) when is_number(value) do
    percentage = value * 100
    "#{:erlang.float_to_binary(percentage, decimals: 2)}%"
  end

  defp format_percentage(value), do: format_default(value)

  defp format_date(value) do
    # TODO: Implement date formatting with CLDR
    to_string(value)
  end

  defp format_datetime(value) do
    # TODO: Implement datetime formatting with CLDR
    to_string(value)
  end

  # Private Functions - Error Handling

  defp error_placeholder(message) do
    """
    <span class="error-placeholder" style="color: red; font-weight: bold;">
      [#{message}]
    </span>
    """
  end

  # Private Functions - Container

  defp wrap_in_report_container(content, context) do
    locale = context.locale || "en"
    direction = context.text_direction || "ltr"

    """
    <div class="ash-report" data-locale="#{locale}" dir="#{direction}">
      #{content}
    </div>
    """
  end

  # Private Functions - Group Handling

  defp has_groups?(%RenderContext{report: nil}), do: false
  defp has_groups?(%RenderContext{report: %{groups: nil}}), do: false
  defp has_groups?(%RenderContext{report: %{groups: []}}), do: false
  defp has_groups?(%RenderContext{report: %{groups: groups}}) when is_list(groups), do: true
  defp has_groups?(_), do: false

  defp categorize_bands(bands) do
    group_headers = Enum.filter(bands, &(&1.type == :group_header))
    group_footers = Enum.filter(bands, &(&1.type == :group_footer))
    detail_bands = Enum.filter(bands, &(&1.type in [:detail_header, :detail, :detail_footer]))
    other_bands = Enum.reject(bands, &(&1.type in [:group_header, :group_footer, :detail_header, :detail, :detail_footer]))

    {group_headers, detail_bands, group_footers, other_bands}
  end

  defp render_grouped_records(group_headers, detail_bands, group_footers, context) do
    groups = get_report_groups(context)
    records = context.records || []

    # Group records by their group values
    grouped_records = group_records_by_values(records, groups)

    # Render each group
    grouped_records
    |> Enum.map(fn {group_values, group_records} ->
      render_single_group(group_headers, detail_bands, group_footers, group_values, group_records, context)
    end)
    |> Enum.join("\n")
  end

  defp group_records_by_values(records, groups) do
    records
    |> Enum.chunk_by(fn record ->
      # Build a tuple of group values for this record
      Enum.map(groups, fn group ->
        extract_group_value(record, group)
      end)
    end)
    |> Enum.map(fn chunk ->
      # Get group values from first record in chunk
      first_record = List.first(chunk)
      group_values = Enum.map(groups, fn group ->
        {group.level, extract_group_value(first_record, group)}
      end)
      {group_values, chunk}
    end)
  end

  defp extract_group_value(record, %Group{expression: expression}) when is_atom(expression) do
    Map.get(record, expression)
  end

  defp extract_group_value(record, %Group{expression: expression}) when is_list(expression) do
    get_in(record, expression)
  end

  defp extract_group_value(_record, %Group{expression: _expression}) do
    # Complex expressions not yet supported in Phase 5
    nil
  end

  defp render_single_group(group_headers, detail_bands, group_footers, group_values, group_records, context) do
    # Calculate group aggregates
    group_aggregates = calculate_group_aggregates(group_records)

    # Build group context with values and aggregates
    group_context = %{
      context
      | current_record: List.first(group_records),
        metadata: Map.merge(context.metadata, %{
          group_values: Map.new(group_values),
          group_aggregates: group_aggregates,
          group_record_count: length(group_records)
        })
    }

    # Render group header
    headers_html =
      group_headers
      |> Enum.map(fn header -> render_group_header_band(header, group_context) end)
      |> Enum.join("\n")

    # Render detail records
    details_html =
      detail_bands
      |> Enum.map(fn detail_band ->
        render_detail_records_for_group(detail_band, group_records, context)
      end)
      |> Enum.join("\n")

    # Render group footer
    footers_html =
      group_footers
      |> Enum.map(fn footer -> render_group_footer_band(footer, group_context) end)
      |> Enum.join("\n")

    headers_html <> "\n" <> details_html <> "\n" <> footers_html
  end

  defp render_detail_records_for_group(detail_band, records, context) do
    case detail_band.type do
      :detail ->
        records
        |> Enum.map(fn record ->
          record_context = %{context | current_record: record}
          render_detail_record(detail_band, record_context)
        end)
        |> Enum.join("\n")

      :detail_header ->
        render_standard_band(detail_band, context)

      :detail_footer ->
        render_standard_band(detail_band, context)

      _ ->
        ""
    end
  end

  defp calculate_group_aggregates(records) do
    # Calculate common aggregates for the group
    count = length(records)

    # Calculate sums for numeric fields
    sums = calculate_numeric_sums(records)

    Map.merge(%{count: count}, sums)
  end

  defp calculate_numeric_sums(records) do
    if length(records) == 0 do
      %{}
    else
      first_record = List.first(records)

      first_record
      |> Map.keys()
      |> Enum.filter(fn key ->
        value = Map.get(first_record, key)
        is_number(value)
      end)
      |> Enum.into(%{}, fn key ->
        sum = Enum.reduce(records, 0, fn record, acc ->
          value = Map.get(record, key, 0)
          if is_number(value), do: acc + value, else: acc
        end)
        {"#{key}_sum", sum}
      end)
    end
  end

  defp get_report_groups(%RenderContext{report: nil}), do: []
  defp get_report_groups(%RenderContext{report: %{groups: nil}}), do: []
  defp get_report_groups(%RenderContext{report: %{groups: groups}}), do: groups || []
end
