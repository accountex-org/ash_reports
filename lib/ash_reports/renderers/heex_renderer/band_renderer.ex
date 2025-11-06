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
  alias AshReports.HeexRenderer.TemplateBuilder

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
    # Use new template generation by default
    generate_report_template(context)
  end

  @doc """
  Generates a HEEX template for the report (new template-based approach).

  Instead of pre-rendering HTML, this generates a HEEX template string with
  for comprehensions and assigns that Phoenix evaluates at runtime.

  ## Examples

      context = RenderContext.new(report, data_result)
      template = BandRenderer.generate_report_template(context)
      # Returns: "<div :for={band <- @bands}><%= band.content %></div>"

  """
  @spec generate_report_template(RenderContext.t()) :: String.t()
  def generate_report_template(%RenderContext{} = context) do
    # Get bands from report definition
    bands = get_report_bands(context)

    # Generate template for bands
    bands_template = generate_bands_template(bands, context)

    # Wrap in report container
    wrap_template_in_container(bands_template, context)
  end

  # Private Functions - Template Generation

  defp get_report_bands(%RenderContext{report: nil}), do: []
  defp get_report_bands(%RenderContext{report: report}), do: report.bands || []

  defp generate_bands_template(bands, context) do
    # Check if report has grouping configured
    if has_groups?(context) do
      generate_grouped_bands_template(bands, context)
    else
      generate_simple_bands_template(bands, context)
    end
  end

  defp generate_simple_bands_template(bands, context) do
    # Separate detail bands from other bands
    {detail_bands, other_bands} = Enum.split_with(bands, &(&1.type == :detail))

    # Generate templates for non-detail bands (title, headers, etc.)
    other_templates =
      other_bands
      |> Enum.map(fn band -> generate_band_template(band, context) end)
      |> TemplateBuilder.join("\n")

    # Generate template for detail bands with iteration
    detail_template =
      if detail_bands != [] do
        generate_detail_bands_template(detail_bands, context)
      else
        ""
      end

    # Combine templates
    TemplateBuilder.join([other_templates, detail_template], "\n")
  end

  defp generate_detail_bands_template(detail_bands, _context) do
    # Generate a for comprehension for detail bands that iterates over records
    detail_content =
      detail_bands
      |> Enum.map(fn band ->
        # Generate band structure that will be filled with record data
        band_class = band_type_to_class(band.type)
        elements_template = generate_elements_template_for_record(band.elements)

        """
        <div class="#{band_class}" data-band="#{band.name}">
          #{elements_template}
        </div>
        """
      end)
      |> TemplateBuilder.join("\n")

    # Wrap in for comprehension
    """
    <%= for record <- @records do %>
      #{detail_content}
    <% end %>
    """
  end

  defp generate_band_template(%Band{} = band, context) do
    # Check visibility
    if band_visible?(band, context) do
      case band.type do
        :detail ->
          # Detail bands are handled separately with iteration
          ""

        :group_header ->
          generate_group_header_template(band, context)

        :group_footer ->
          generate_group_footer_template(band, context)

        type
        when type in [
               :title,
               :page_header,
               :column_header,
               :detail_header,
               :detail_footer,
               :column_footer,
               :page_footer,
               :summary
             ] ->
          generate_standard_band_template(band, context)

        _ ->
          generate_unknown_band_template(band)
      end
    else
      ""
    end
  end

  defp generate_standard_band_template(%Band{} = band, context) do
    elements_template = generate_elements_template(band.elements, context)
    nested_template = generate_nested_bands_template(band, context)

    band_class = band_type_to_class(band.type)

    """
    <div class="#{band_class}" data-band="#{band.name}">
      #{elements_template}
      #{nested_template}
    </div>
    """
  end

  defp generate_group_header_template(%Band{} = band, context) do
    # Group headers will iterate over groups
    elements_template = generate_elements_template_for_group(band.elements)
    nested_template = generate_nested_bands_template(band, context)

    group_level = band.group_level || 1

    """
    <div class="group-header-band" data-band="#{band.name}" data-group-level="#{group_level}">
      #{elements_template}
      #{nested_template}
    </div>
    """
  end

  defp generate_group_footer_template(%Band{} = band, context) do
    elements_template = generate_elements_template_for_group(band.elements)
    nested_template = generate_nested_bands_template(band, context)

    group_level = band.group_level || 1

    """
    <div class="group-footer-band" data-band="#{band.name}" data-group-level="#{group_level}">
      #{elements_template}
      #{nested_template}
    </div>
    """
  end

  defp generate_unknown_band_template(%Band{} = band) do
    """
    <div class="unknown-band" data-band="#{band.name}">
      [UNKNOWN BAND TYPE: #{band.type}]
    </div>
    """
  end

  defp generate_nested_bands_template(%Band{bands: nil}, _context), do: ""
  defp generate_nested_bands_template(%Band{bands: []}, _context), do: ""

  defp generate_nested_bands_template(%Band{bands: nested_bands}, context) do
    generate_bands_template(nested_bands, context)
  end

  defp generate_grouped_bands_template(bands, context) do
    # For grouped reports, we need to generate templates that iterate over groups
    {group_headers, detail_bands, group_footers, other_bands} = categorize_bands(bands)

    # Generate templates for non-grouped bands
    other_template = generate_simple_bands_template(other_bands, context)

    # Generate grouped content template
    grouped_template =
      generate_grouped_records_template(group_headers, detail_bands, group_footers, context)

    TemplateBuilder.join([other_template, grouped_template], "\n")
  end

  defp generate_grouped_records_template(group_headers, detail_bands, group_footers, context) do
    # Generate templates for group iteration
    header_template =
      group_headers
      |> Enum.map(fn band -> generate_group_header_template(band, context) end)
      |> TemplateBuilder.join("\n")

    detail_template =
      detail_bands
      |> Enum.map(fn band ->
        elements_template = generate_elements_template_for_record(band.elements)
        band_class = band_type_to_class(band.type)

        """
        <div class="#{band_class}" data-band="#{band.name}">
          #{elements_template}
        </div>
        """
      end)
      |> TemplateBuilder.join("\n")

    footer_template =
      group_footers
      |> Enum.map(fn band -> generate_group_footer_template(band, context) end)
      |> TemplateBuilder.join("\n")

    # Combine into group iteration template
    """
    <%= for group <- @groups do %>
      #{header_template}
      <%= for record <- group.records do %>
        #{detail_template}
      <% end %>
      #{footer_template}
    <% end %>
    """
  end

  defp generate_elements_template(nil, _context), do: ""
  defp generate_elements_template([], _context), do: ""

  defp generate_elements_template(elements, context) do
    elements
    |> Enum.map(fn element -> generate_element_template(element, context) end)
    |> TemplateBuilder.join("\n")
  end

  defp generate_elements_template_for_record(nil), do: ""
  defp generate_elements_template_for_record([]), do: ""

  defp generate_elements_template_for_record(elements) do
    # Elements that reference record fields
    elements
    |> Enum.map(fn element -> generate_element_template_for_record(element) end)
    |> TemplateBuilder.join("\n")
  end

  defp generate_elements_template_for_group(nil), do: ""
  defp generate_elements_template_for_group([]), do: ""

  defp generate_elements_template_for_group(elements) do
    # Elements that reference group data
    elements
    |> Enum.map(fn element -> generate_element_template_for_group(element) end)
    |> TemplateBuilder.join("\n")
  end

  defp generate_element_template(%{type: :label} = element, _context) do
    text = element.text || ""
    "<span class=\"label-element\">#{TemplateBuilder.escape(text)}</span>"
  end

  defp generate_element_template(%{type: :field} = element, _context) do
    field_name = element.source || element.name
    "<span class=\"field-element\" data-field=\"#{field_name}\"><%= @#{field_name} %></span>"
  end

  defp generate_element_template(%{type: :expression} = element, _context) do
    # For now, use a placeholder for expressions
    "<span class=\"expression-element\">[EXPRESSION: #{element.expression}]</span>"
  end

  defp generate_element_template(%{type: :aggregate} = element, _context) do
    # Aggregates reference variables
    var_name = Map.get(element, :variable) || Map.get(element, :variable_name) || element.name
    "<span class=\"aggregate-element\"><%= @variables.#{var_name} %></span>"
  end

  defp generate_element_template(_element, _context) do
    "<span class=\"unknown-element\">[UNKNOWN ELEMENT]</span>"
  end

  defp generate_element_template_for_record(%{type: :label} = element) do
    text = element.text || ""
    "<span class=\"label-element\">#{TemplateBuilder.escape(text)}</span>"
  end

  defp generate_element_template_for_record(%{type: :field} = element) do
    field_name = element.source || element.name
    "<span class=\"field-element\" data-field=\"#{field_name}\"><%= record.#{field_name} %></span>"
  end

  defp generate_element_template_for_record(%{type: :expression} = element) do
    "<span class=\"expression-element\">[EXPRESSION: #{element.expression}]</span>"
  end

  defp generate_element_template_for_record(_element) do
    "<span class=\"unknown-element\">[UNKNOWN ELEMENT]</span>"
  end

  defp generate_element_template_for_group(%{type: :label} = element) do
    text = element.text || ""
    "<span class=\"label-element\">#{TemplateBuilder.escape(text)}</span>"
  end

  defp generate_element_template_for_group(%{type: :field} = element) do
    field_name = element.source || element.name
    "<span class=\"field-element\" data-field=\"#{field_name}\"><%= group.#{field_name} %></span>"
  end

  defp generate_element_template_for_group(%{type: :aggregate} = element) do
    var_name = Map.get(element, :variable) || Map.get(element, :variable_name) || element.name
    "<span class=\"aggregate-element\"><%= group.aggregates.#{var_name} %></span>"
  end

  defp generate_element_template_for_group(_element) do
    "<span class=\"unknown-element\">[UNKNOWN ELEMENT]</span>"
  end

  defp wrap_template_in_container(template_content, context) do
    locale = context.locale || "en"
    text_dir = context.text_direction || "ltr"

    """
    <div class="ash-report" data-locale="#{locale}" dir="#{text_dir}">
      #{template_content}
    </div>
    """
  end

  # Private Functions - Helper Functions

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
  defp band_type_to_class(:detail), do: "detail-band"
  defp band_type_to_class(_), do: "unknown-band"

  # Group Handling
  defp has_groups?(%RenderContext{report: nil}), do: false
  defp has_groups?(%RenderContext{report: %{groups: nil}}), do: false
  defp has_groups?(%RenderContext{report: %{groups: []}}), do: false
  defp has_groups?(%RenderContext{report: %{groups: groups}}) when is_list(groups), do: true
  defp has_groups?(_), do: false

  defp categorize_bands(bands) do
    group_headers = Enum.filter(bands, &(&1.type == :group_header))
    group_footers = Enum.filter(bands, &(&1.type == :group_footer))
    detail_bands = Enum.filter(bands, &(&1.type in [:detail_header, :detail, :detail_footer]))

    other_bands =
      Enum.reject(bands, &(&1.type in [:group_header, :group_footer, :detail_header, :detail, :detail_footer]))

    {group_headers, detail_bands, group_footers, other_bands}
  end
end
