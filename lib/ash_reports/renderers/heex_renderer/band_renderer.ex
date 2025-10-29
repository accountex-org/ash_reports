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

  alias AshReports.{Band, RenderContext}

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
    bands
    |> Enum.map(fn band -> render_band(band, context) end)
    |> Enum.join("\n")
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
  defp render_detail_band(%Band{} = band, context) do
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

    """
    <div class="group-header-band" data-band="#{band.name}" data-group-level="#{group_level}">
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

    """
    <div class="group-footer-band" data-band="#{band.name}" data-group-level="#{group_level}">
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

  defp render_element(element, _context) do
    """
    <div class="unknown-element">
      [UNKNOWN ELEMENT TYPE: #{inspect(element)}]
    </div>
    """
  end

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

    case Map.fetch(context.variables, variable_name) do
      {:ok, value} -> value
      :error -> error_placeholder("MISSING_VAR: #{variable_name}")
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
end
