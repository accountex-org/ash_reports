defmodule AshReports.PdfRenderer.PageManager do
  @moduledoc """
  Phase 3.4.2 Page Manager - Headers, footers, page numbers, and intelligent page break management.

  The PageManager handles all aspects of PDF page layout including header and footer
  generation, page numbering, intelligent page break placement, and multi-page report
  coordination for professional business documents.

  ## Key Features

  - **Header Management**: Dynamic headers with report titles, dates, and custom content
  - **Footer Management**: Page numbers, document info, and custom footer content
  - **Page Break Intelligence**: Automatic page breaks that respect content boundaries
  - **Page Numbering**: Flexible page numbering schemes (numeric, roman, custom)
  - **Multi-page Coordination**: Consistent layout across all pages of large reports

  ## Integration

  The PageManager works with the Print Optimizer to ensure proper page layout CSS
  and coordinates with the PDF Generator for final page assembly.

  ## Usage

      context = RenderContext.new(report, data_result, pdf_config)
      {:ok, page_layout} = PageManager.setup_page_layout(context)
      
      # page_layout contains header/footer configurations and page break rules

  """

  alias AshReports.RenderContext

  @doc """
  Sets up comprehensive page layout configuration for PDF generation.

  Analyzes the report structure and creates page layout rules including:
  - Header and footer positioning and content
  - Page break placement strategies
  - Page numbering configuration
  - Multi-page coordination settings

  ## Examples

      context = RenderContext.new(report, data_result)
      {:ok, page_layout} = PageManager.setup_page_layout(context)

  """
  @spec setup_page_layout(RenderContext.t()) :: {:ok, map()} | {:error, term()}
  def setup_page_layout(%RenderContext{} = context) do
    with {:ok, header_config} <- configure_headers(context),
         {:ok, footer_config} <- configure_footers(context),
         {:ok, page_break_config} <- configure_page_breaks(context),
         {:ok, numbering_config} <- configure_page_numbering(context),
         {:ok, layout_rules} <- generate_layout_rules(context) do
      page_layout = %{
        headers: header_config,
        footers: footer_config,
        page_breaks: page_break_config,
        numbering: numbering_config,
        layout_rules: layout_rules,
        page_dimensions: get_page_dimensions(context),
        margins: get_page_margins(context)
      }

      {:ok, page_layout}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Configures header settings for PDF pages.

  Generates header configuration including content, positioning,
  and styling for different page types (first, odd, even, last).
  """
  @spec configure_headers(RenderContext.t()) :: {:ok, map()}
  def configure_headers(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}
    headers_config = pdf_config[:headers] || %{enabled: false}

    if headers_config[:enabled] do
      header_config = %{
        enabled: true,
        height: headers_config[:height] || 15,
        content: build_header_content(context, headers_config),
        positioning: build_header_positioning(headers_config),
        styling: build_header_styling(context, headers_config),
        page_variants: build_header_page_variants(context, headers_config)
      }

      {:ok, header_config}
    else
      {:ok, %{enabled: false}}
    end
  end

  @doc """
  Configures footer settings for PDF pages.

  Generates footer configuration including page numbers, document info,
  and custom footer content with proper positioning and styling.
  """
  @spec configure_footers(RenderContext.t()) :: {:ok, map()}
  def configure_footers(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}
    footers_config = pdf_config[:footers] || %{enabled: true, page_numbers: true}

    if footers_config[:enabled] do
      footer_config = %{
        enabled: true,
        height: footers_config[:height] || 15,
        content: build_footer_content(context, footers_config),
        positioning: build_footer_positioning(footers_config),
        styling: build_footer_styling(context, footers_config),
        page_numbers: build_page_number_config(context, footers_config)
      }

      {:ok, footer_config}
    else
      {:ok, %{enabled: false}}
    end
  end

  @doc """
  Configures intelligent page break placement.

  Analyzes report content to determine optimal page break locations
  that respect content boundaries and maintain professional appearance.
  """
  @spec configure_page_breaks(RenderContext.t()) :: {:ok, map()}
  def configure_page_breaks(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}
    break_strategy = pdf_config[:page_breaks] || :auto

    page_break_config =
      case break_strategy do
        :auto ->
          build_automatic_page_breaks(context)

        :manual ->
          build_manual_page_breaks(context)

        :intelligent ->
          build_intelligent_page_breaks(context)

        _ ->
          build_automatic_page_breaks(context)
      end

    {:ok, page_break_config}
  end

  @doc """
  Configures page numbering scheme and positioning.

  Sets up page numbering including format, starting number,
  position, and special handling for different page types.
  """
  @spec configure_page_numbering(RenderContext.t()) :: {:ok, map()}
  def configure_page_numbering(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}
    footers_config = pdf_config[:footers] || %{}

    numbering_config = %{
      enabled: footers_config[:page_numbers] || true,
      format: footers_config[:number_format] || :numeric,
      starting_number: footers_config[:start_number] || 1,
      position: footers_config[:number_position] || :bottom_center,
      show_total: footers_config[:show_total] || true,
      template: build_page_number_template(footers_config),
      first_page: footers_config[:number_first_page] || true,
      styling: build_page_number_styling(context)
    }

    {:ok, numbering_config}
  end

  @doc """
  Generates comprehensive layout rules for PDF page management.

  Creates CSS and layout rules that govern page structure, including
  margins, padding, content flow, and page break behavior.
  """
  @spec generate_layout_rules(RenderContext.t()) :: {:ok, map()}
  def generate_layout_rules(%RenderContext{} = context) do
    layout_rules = %{
      page_structure: build_page_structure_rules(context),
      content_flow: build_content_flow_rules(context),
      break_avoidance: build_break_avoidance_rules(context),
      spacing: build_spacing_rules(context),
      margins: build_margin_rules(context),
      overflow: build_overflow_rules(context)
    }

    {:ok, layout_rules}
  end

  @doc """
  Calculates estimated page count based on content analysis.

  Analyzes report content to provide accurate page count estimates
  for progress tracking and resource allocation.
  """
  @spec estimate_page_count(RenderContext.t()) :: {:ok, integer()}
  def estimate_page_count(%RenderContext{} = context) do
    with {:ok, content_metrics} <- analyze_content_metrics(context),
         {:ok, page_dimensions} <- calculate_usable_page_area(context),
         {:ok, element_sizes} <- estimate_element_sizes(context) do
      estimated_pages =
        calculate_pages_from_metrics(
          content_metrics,
          page_dimensions,
          element_sizes
        )

      {:ok, max(1, estimated_pages)}
    else
      {:error, _reason} = error -> error
    end
  end

  # Private helper functions

  defp build_header_content(%RenderContext{} = context, headers_config) do
    %{
      left: headers_config[:text_left] || "",
      center: headers_config[:text] || get_report_title(context),
      right: headers_config[:text_right] || format_current_date(),
      dynamic_content: headers_config[:dynamic] || false,
      variables: build_header_variables(context, headers_config)
    }
  end

  defp build_header_positioning(headers_config) do
    %{
      height: "#{headers_config[:height] || 15}mm",
      margin_top: "10mm",
      margin_bottom: "5mm",
      alignment: headers_config[:alignment] || :center,
      vertical_alignment: headers_config[:vertical_alignment] || :middle
    }
  end

  defp build_header_styling(%RenderContext{} = _context, headers_config) do
    %{
      font_family: headers_config[:font] || "sans-serif",
      font_size: "#{headers_config[:font_size] || 10}pt",
      font_weight: headers_config[:font_weight] || "normal",
      color: headers_config[:color] || "#000000",
      border_bottom: headers_config[:border] || "none",
      background_color: headers_config[:background] || "transparent"
    }
  end

  defp build_header_page_variants(%RenderContext{} = _context, _headers_config) do
    %{
      first_page: %{show: true, content_override: nil},
      odd_pages: %{show: true, content_override: nil},
      even_pages: %{show: true, content_override: nil},
      last_page: %{show: true, content_override: nil}
    }
  end

  defp build_footer_content(%RenderContext{} = context, footers_config) do
    %{
      left: footers_config[:text_left] || "",
      center: build_footer_center_content(context, footers_config),
      right: footers_config[:text_right] || "",
      page_numbers: footers_config[:page_numbers] || true,
      document_info: footers_config[:document_info] || false,
      variables: build_footer_variables(context, footers_config)
    }
  end

  defp build_footer_center_content(%RenderContext{} = _context, footers_config) do
    if footers_config[:page_numbers] do
      footers_config[:page_template] || "Page {{page}} of {{total}}"
    else
      footers_config[:text_center] || ""
    end
  end

  defp build_footer_positioning(footers_config) do
    %{
      height: "#{footers_config[:height] || 15}mm",
      margin_top: "5mm",
      margin_bottom: "10mm",
      alignment: footers_config[:alignment] || :center,
      vertical_alignment: footers_config[:vertical_alignment] || :middle
    }
  end

  defp build_footer_styling(%RenderContext{} = _context, footers_config) do
    %{
      font_family: footers_config[:font] || "sans-serif",
      font_size: "#{footers_config[:font_size] || 9}pt",
      font_weight: footers_config[:font_weight] || "normal",
      color: footers_config[:color] || "#666666",
      border_top: footers_config[:border] || "1pt solid #cccccc",
      background_color: footers_config[:background] || "transparent"
    }
  end

  defp build_page_number_config(%RenderContext{} = _context, footers_config) do
    %{
      enabled: footers_config[:page_numbers] || true,
      format: footers_config[:number_format] || "Page {{page}} of {{total}}",
      position: footers_config[:number_position] || :center,
      start_from: footers_config[:start_number] || 1,
      show_on_first: footers_config[:number_first_page] || true
    }
  end

  defp build_automatic_page_breaks(%RenderContext{} = context) do
    %{
      strategy: :auto,
      avoid_elements: [:table, :chart, :image, :band_header],
      orphan_control: 3,
      widow_control: 3,
      break_before: analyze_break_before_elements(context),
      break_after: analyze_break_after_elements(context),
      keep_together: identify_keep_together_elements(context)
    }
  end

  defp build_manual_page_breaks(%RenderContext{} = _context) do
    %{
      strategy: :manual,
      manual_breaks: [],
      respect_css_breaks: true,
      force_breaks: []
    }
  end

  defp build_intelligent_page_breaks(%RenderContext{} = context) do
    %{
      strategy: :intelligent,
      content_analysis: analyze_content_for_breaks(context),
      logical_sections: identify_logical_sections(context),
      priority_elements: identify_priority_elements(context),
      break_penalties: calculate_break_penalties(context),
      optimization_level: :high
    }
  end

  defp build_page_number_template(footers_config) do
    case footers_config[:number_format] do
      :numeric -> "{{page}}"
      :roman -> "{{page_roman}}"
      :alpha -> "{{page_alpha}}"
      :with_total -> "Page {{page}} of {{total}}"
      custom when is_binary(custom) -> custom
      _ -> "Page {{page}} of {{total}}"
    end
  end

  defp build_page_number_styling(%RenderContext{} = _context) do
    %{
      font_family: "sans-serif",
      font_size: "9pt",
      font_weight: "normal",
      color: "#666666",
      alignment: :center
    }
  end

  defp build_page_structure_rules(%RenderContext{} = context) do
    %{
      page_box_model: get_page_box_model(context),
      content_area: calculate_content_area(context),
      margin_boxes: define_margin_boxes(context),
      bleed_area: calculate_bleed_area(context)
    }
  end

  defp build_content_flow_rules(%RenderContext{} = _context) do
    %{
      flow_direction: :top_to_bottom,
      column_count: 1,
      column_gap: 0,
      line_break_strategy: :auto,
      hyphenation: false
    }
  end

  defp build_break_avoidance_rules(%RenderContext{} = _context) do
    %{
      avoid_break_inside: [".ash-band", ".ash-table", ".ash-chart"],
      avoid_break_after: [".ash-band-header", ".ash-section-title"],
      avoid_break_before: [".ash-band-footer"],
      keep_with_next: [".ash-label"],
      keep_with_previous: [".ash-field-continuation"]
    }
  end

  defp build_spacing_rules(%RenderContext{} = _context) do
    %{
      paragraph_spacing: "6pt",
      section_spacing: "12pt",
      element_spacing: "3pt",
      band_spacing: "18pt",
      line_height: "1.4",
      word_spacing: "normal",
      letter_spacing: "normal"
    }
  end

  defp build_margin_rules(%RenderContext{} = context) do
    margins = get_page_margins(context)

    %{
      top: "#{margins.top}mm",
      right: "#{margins.right}mm",
      bottom: "#{margins.bottom}mm",
      left: "#{margins.left}mm",
      header_margin: "#{margins.top - 5}mm",
      footer_margin: "#{margins.bottom - 5}mm"
    }
  end

  defp build_overflow_rules(%RenderContext{} = _context) do
    %{
      text_overflow: :ellipsis,
      word_wrap: :break_word,
      overflow_wrap: :break_word,
      hyphens: :auto,
      max_content_width: "100%"
    }
  end

  defp get_report_title(%RenderContext{} = context) do
    context.report.title || "Report"
  end

  defp format_current_date do
    Date.utc_today()
    |> Date.to_string()
  end

  defp build_header_variables(%RenderContext{} = context, _headers_config) do
    %{
      report_title: get_report_title(context),
      current_date: format_current_date(),
      page_number: "{{page}}",
      total_pages: "{{total}}",
      report_parameters: format_report_parameters(context)
    }
  end

  defp build_footer_variables(%RenderContext{} = context, _footers_config) do
    %{
      current_date: format_current_date(),
      current_time: format_current_time(),
      page_number: "{{page}}",
      total_pages: "{{total}}",
      document_name: get_report_title(context)
    }
  end

  defp format_current_time do
    Time.utc_now()
    |> Time.to_string()
    |> String.split(".")
    |> List.first()
  end

  defp format_report_parameters(%RenderContext{} = _context) do
    # This would format any report parameters for display
    ""
  end

  defp get_page_dimensions(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}

    case pdf_config[:page_size] do
      :a4 -> %{width: 210, height: 297, unit: :mm}
      :letter -> %{width: 216, height: 279, unit: :mm}
      :a3 -> %{width: 297, height: 420, unit: :mm}
      _ -> %{width: 210, height: 297, unit: :mm}
    end
  end

  defp get_page_margins(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}
    margins = pdf_config[:margins] || %{}

    %{
      top: margins[:top] || 20,
      right: margins[:right] || 20,
      bottom: margins[:bottom] || 20,
      left: margins[:left] || 20
    }
  end

  defp analyze_break_before_elements(%RenderContext{} = _context) do
    # Analyze which elements should have page breaks before them
    [".ash-new-section", ".ash-chapter"]
  end

  defp analyze_break_after_elements(%RenderContext{} = _context) do
    # Analyze which elements should have page breaks after them
    [".ash-section-end", ".ash-summary"]
  end

  defp identify_keep_together_elements(%RenderContext{} = _context) do
    # Identify elements that should be kept together on the same page
    [".ash-band", ".ash-table-row", ".ash-form-section"]
  end

  defp analyze_content_for_breaks(%RenderContext{} = _context) do
    # Analyze content to determine optimal break points
    %{
      content_density: :medium,
      logical_breaks: [],
      section_boundaries: [],
      content_flow: :sequential
    }
  end

  defp identify_logical_sections(%RenderContext{} = _context) do
    # Identify logical content sections
    []
  end

  defp identify_priority_elements(%RenderContext{} = _context) do
    # Identify high-priority elements that should influence page breaks
    []
  end

  defp calculate_break_penalties(%RenderContext{} = _context) do
    # Calculate penalties for different break positions
    %{
      orphan_penalty: 100,
      widow_penalty: 100,
      section_break_penalty: 50,
      table_break_penalty: 200
    }
  end

  defp get_page_box_model(%RenderContext{} = context) do
    dimensions = get_page_dimensions(context)
    margins = get_page_margins(context)

    %{
      page_width: dimensions.width,
      page_height: dimensions.height,
      content_width: dimensions.width - margins.left - margins.right,
      content_height: dimensions.height - margins.top - margins.bottom,
      unit: dimensions.unit
    }
  end

  defp calculate_content_area(%RenderContext{} = context) do
    box_model = get_page_box_model(context)

    %{
      width: box_model.content_width,
      height: box_model.content_height,
      x_offset: get_page_margins(context).left,
      y_offset: get_page_margins(context).top
    }
  end

  defp define_margin_boxes(%RenderContext{} = _context) do
    %{
      top_left: %{width: "25%", height: "15mm"},
      top_center: %{width: "50%", height: "15mm"},
      top_right: %{width: "25%", height: "15mm"},
      bottom_left: %{width: "25%", height: "15mm"},
      bottom_center: %{width: "50%", height: "15mm"},
      bottom_right: %{width: "25%", height: "15mm"}
    }
  end

  defp calculate_bleed_area(%RenderContext{} = _context) do
    # For most business reports, bleed is not needed
    %{bleed: "0mm"}
  end

  defp analyze_content_metrics(%RenderContext{} = context) do
    metrics = %{
      total_elements: count_total_elements(context),
      text_content_length: estimate_text_length(context),
      table_count: count_tables(context),
      image_count: count_images(context),
      chart_count: count_charts(context)
    }

    {:ok, metrics}
  end

  defp calculate_usable_page_area(%RenderContext{} = context) do
    content_area = calculate_content_area(context)

    usable_area = %{
      width: content_area.width,
      # Reserve space for header/footer
      height: content_area.height - 30,
      usable_area_mm2: (content_area.width - 30) * content_area.height
    }

    {:ok, usable_area}
  end

  defp estimate_element_sizes(%RenderContext{} = _context) do
    element_sizes = %{
      average_text_height_mm: 4,
      average_table_row_height_mm: 6,
      average_image_height_mm: 50,
      average_chart_height_mm: 80,
      average_spacing_mm: 3
    }

    {:ok, element_sizes}
  end

  defp calculate_pages_from_metrics(content_metrics, page_dimensions, element_sizes) do
    # Simplified page calculation
    # Assume 5 rows per table
    estimated_content_height =
      content_metrics.total_elements * element_sizes.average_text_height_mm +
        content_metrics.table_count * element_sizes.average_table_row_height_mm * 5 +
        content_metrics.image_count * element_sizes.average_image_height_mm +
        content_metrics.chart_count * element_sizes.average_chart_height_mm

    pages_needed = ceil(estimated_content_height / page_dimensions.height)
    max(1, pages_needed)
  end

  defp count_total_elements(%RenderContext{} = context) do
    context.rendered_elements
    |> length()
  rescue
    _ -> 0
  end

  defp estimate_text_length(%RenderContext{} = _context) do
    # Estimate based on records and fields
    # Placeholder
    1000
  end

  defp count_tables(%RenderContext{} = _context) do
    # Count table elements
    # Placeholder
    0
  end

  defp count_images(%RenderContext{} = _context) do
    # Count image elements
    # Placeholder
    0
  end

  defp count_charts(%RenderContext{} = _context) do
    # Count chart elements
    # Placeholder
    0
  end
end
