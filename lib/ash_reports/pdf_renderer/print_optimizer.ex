defmodule AshReports.PdfRenderer.PrintOptimizer do
  @moduledoc """
  Phase 3.4.1 Print Optimizer - CSS generation with print media queries and typography optimization.

  The PrintOptimizer generates print-optimized CSS rules specifically designed for PDF output,
  including @media print queries, professional typography, print-safe colors, and proper
  margins for business reports.

  ## Key Features

  - **Print Media Queries**: @media print rules for PDF-specific styling
  - **Typography Optimization**: Professional fonts, line heights, and spacing
  - **Print-Safe Colors**: CMYK-friendly color palette for professional printing
  - **Layout Optimization**: Page break management and print-specific layouts
  - **Performance**: Minimal CSS footprint optimized for PDF generation

  ## Integration

  The PrintOptimizer extends the existing CssGenerator from Phase 3.2 HtmlRenderer,
  adding print-specific optimizations while reusing the core CSS infrastructure.

  ## Usage

      context = RenderContext.new(report, data_result, pdf_config)
      {:ok, print_css} = PrintOptimizer.generate_print_css(context)
      
      # print_css contains optimized CSS for PDF generation

  """

  alias AshReports.RenderContext

  @doc """
  Generates comprehensive print-optimized CSS for PDF rendering.

  Produces CSS specifically designed for print media, including:
  - @media print queries for PDF-specific styles
  - Typography optimization for readability
  - Print-safe color palette
  - Page break management
  - Professional layout adjustments

  ## Examples

      context = RenderContext.new(report, data_result)
      {:ok, print_css} = PrintOptimizer.generate_print_css(context)

  """
  @spec generate_print_css(RenderContext.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_print_css(%RenderContext{} = context) do
    with {:ok, base_css} <- generate_base_print_css(),
         {:ok, typography_css} <- generate_typography_css(context),
         {:ok, layout_css} <- generate_layout_css(context),
         {:ok, color_css} <- generate_print_safe_colors(context),
         {:ok, page_css} <- generate_page_rules(context),
         {:ok, element_css} <- generate_element_specific_css(context) do
      combined_css =
        combine_css_sections([
          base_css,
          typography_css,
          layout_css,
          color_css,
          page_css,
          element_css
        ])

      {:ok, combined_css}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Generates base print CSS with fundamental print media queries.

  Provides the foundation print styles that apply to all PDF reports.
  """
  @spec generate_base_print_css() :: {:ok, String.t()}
  def generate_base_print_css do
    css = """
    /* Phase 3.4.1 Print Optimizer - Base Print Styles */
    @media print {
      /* Reset margins and padding for print */
      * {
        box-sizing: border-box;
      }
      
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        font-size: 12pt;
        line-height: 1.4;
        color: #000000;
        background: #ffffff;
      }
      
      /* Hide non-printable elements */
      .no-print,
      .screen-only,
      button,
      input[type="submit"],
      input[type="button"] {
        display: none !important;
      }
      
      /* Show print-only elements */
      .print-only {
        display: block !important;
      }
      
      /* Page break management */
      .page-break-before {
        page-break-before: always;
      }
      
      .page-break-after {
        page-break-after: always;
      }
      
      .page-break-avoid {
        page-break-inside: avoid;
      }
      
      /* Prevent orphans and widows */
      p, h1, h2, h3, h4, h5, h6 {
        orphans: 3;
        widows: 3;
      }
      
      /* Table print optimization */
      table {
        page-break-inside: avoid;
      }
      
      tr {
        page-break-inside: avoid;
      }
      
      /* Image print optimization */
      img {
        max-width: 100% !important;
        height: auto !important;
      }
    }
    """

    {:ok, css}
  end

  @doc """
  Generates typography CSS optimized for print readability.

  Provides professional typography settings including font families,
  sizes, weights, and spacing optimized for PDF output.
  """
  @spec generate_typography_css(RenderContext.t()) :: {:ok, String.t()}
  def generate_typography_css(%RenderContext{} = context) do
    font_config = get_font_configuration(context)

    css = """
    /* Typography Optimization for Print */
    @media print {
      /* Professional font stack */
      body, .ash-report {
        font-family: #{font_config.body_font};
        font-size: #{font_config.base_size};
        font-weight: #{font_config.body_weight};
        line-height: #{font_config.line_height};
        text-rendering: optimizeLegibility;
      }
      
      /* Heading typography */
      h1, .ash-report-title {
        font-family: #{font_config.heading_font};
        font-size: #{font_config.h1_size};
        font-weight: #{font_config.heading_weight};
        margin: #{font_config.h1_margin};
        page-break-after: avoid;
      }
      
      h2, .ash-band-title {
        font-family: #{font_config.heading_font};
        font-size: #{font_config.h2_size};
        font-weight: #{font_config.heading_weight};
        margin: #{font_config.h2_margin};
        page-break-after: avoid;
      }
      
      h3, .ash-section-title {
        font-family: #{font_config.heading_font};
        font-size: #{font_config.h3_size};
        font-weight: #{font_config.heading_weight};
        margin: #{font_config.h3_margin};
        page-break-after: avoid;
      }
      
      h4, h5, h6 {
        font-family: #{font_config.heading_font};
        font-weight: #{font_config.heading_weight};
        page-break-after: avoid;
      }
      
      /* Text elements */
      p, .ash-text {
        margin: #{font_config.paragraph_margin};
        line-height: #{font_config.line_height};
      }
      
      /* Table typography */
      table, .ash-table {
        font-size: #{font_config.table_size};
        line-height: #{font_config.table_line_height};
      }
      
      th, .ash-table-header {
        font-weight: #{font_config.table_header_weight};
        font-size: #{font_config.table_header_size};
      }
      
      td, .ash-table-cell {
        font-size: #{font_config.table_cell_size};
      }
      
      /* Code and monospace */
      code, pre, .ash-code {
        font-family: #{font_config.mono_font};
        font-size: #{font_config.mono_size};
        line-height: #{font_config.mono_line_height};
      }
      
      /* Small text */
      small, .ash-small-text {
        font-size: #{font_config.small_size};
      }
      
      /* Strong emphasis */
      strong, b, .ash-strong {
        font-weight: #{font_config.strong_weight};
      }
      
      /* Italic emphasis */
      em, i, .ash-emphasis {
        font-style: italic;
      }
    }
    """

    {:ok, css}
  end

  @doc """
  Generates layout CSS optimized for print dimensions and spacing.
  """
  @spec generate_layout_css(RenderContext.t()) :: {:ok, String.t()}
  def generate_layout_css(%RenderContext{} = context) do
    layout_config = get_layout_configuration(context)

    css = """
    /* Layout Optimization for Print */
    @media print {
      /* Main report container */
      .ash-report {
        max-width: 100%;
        margin: #{layout_config.report_margin};
        padding: #{layout_config.report_padding};
      }
      
      /* Header layout */
      .ash-report-header {
        margin-bottom: #{layout_config.header_spacing};
        padding-bottom: #{layout_config.header_padding};
        border-bottom: #{layout_config.header_border};
      }
      
      /* Footer layout */
      .ash-report-footer {
        margin-top: #{layout_config.footer_spacing};
        padding-top: #{layout_config.footer_padding};
        border-top: #{layout_config.footer_border};
      }
      
      /* Band layout */
      .ash-band {
        margin-bottom: #{layout_config.band_spacing};
        page-break-inside: avoid;
      }
      
      .ash-band-header {
        margin-bottom: #{layout_config.band_header_spacing};
        page-break-after: avoid;
      }
      
      /* Element layout */
      .ash-element {
        margin-bottom: #{layout_config.element_spacing};
      }
      
      .ash-element-label {
        margin-bottom: #{layout_config.label_spacing};
        font-weight: #{layout_config.label_weight};
      }
      
      .ash-element-field {
        margin-bottom: #{layout_config.field_spacing};
      }
      
      /* Table layout */
      .ash-table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: #{layout_config.table_spacing};
        page-break-inside: avoid;
      }
      
      .ash-table th,
      .ash-table td {
        padding: #{layout_config.table_cell_padding};
        border: #{layout_config.table_border};
        text-align: left;
        vertical-align: top;
      }
      
      .ash-table thead tr {
        page-break-after: avoid;
      }
      
      /* Grid layout for elements */
      .ash-grid-container {
        display: block;
      }
      
      .ash-grid-row {
        display: block;
        margin-bottom: #{layout_config.grid_row_spacing};
      }
      
      .ash-grid-col {
        display: block;
        width: 100%;
        margin-bottom: #{layout_config.grid_col_spacing};
      }
      
      /* Spacing utilities */
      .ash-spacing-small {
        margin-bottom: #{layout_config.spacing_small};
      }
      
      .ash-spacing-medium {
        margin-bottom: #{layout_config.spacing_medium};
      }
      
      .ash-spacing-large {
        margin-bottom: #{layout_config.spacing_large};
      }
    }
    """

    {:ok, css}
  end

  @doc """
  Generates print-safe color CSS using CMYK-friendly color palette.
  """
  @spec generate_print_safe_colors(RenderContext.t()) :: {:ok, String.t()}
  def generate_print_safe_colors(%RenderContext{} = context) do
    color_config = get_color_configuration(context)

    css = """
    /* Print-Safe Color Palette */
    @media print {
      /* Text colors */
      .ash-report {
        color: #{color_config.text_primary};
      }
      
      .ash-text-secondary {
        color: #{color_config.text_secondary};
      }
      
      .ash-text-muted {
        color: #{color_config.text_muted};
      }
      
      /* Background colors */
      .ash-bg-light {
        background-color: #{color_config.bg_light} !important;
      }
      
      .ash-bg-medium {
        background-color: #{color_config.bg_medium} !important;
      }
      
      /* Border colors */
      .ash-border-light {
        border-color: #{color_config.border_light};
      }
      
      .ash-border-medium {
        border-color: #{color_config.border_medium};
      }
      
      .ash-border-dark {
        border-color: #{color_config.border_dark};
      }
      
      /* Table colors */
      .ash-table th {
        background-color: #{color_config.table_header_bg} !important;
        color: #{color_config.table_header_text};
      }
      
      .ash-table tr:nth-child(even) {
        background-color: #{color_config.table_stripe_bg} !important;
      }
      
      /* Status colors (print-safe alternatives) */
      .ash-success {
        color: #{color_config.success_text};
        background-color: #{color_config.success_bg} !important;
      }
      
      .ash-warning {
        color: #{color_config.warning_text};
        background-color: #{color_config.warning_bg} !important;
      }
      
      .ash-error {
        color: #{color_config.error_text};
        background-color: #{color_config.error_bg} !important;
      }
      
      /* Remove shadows and effects that don't print well */
      * {
        box-shadow: none !important;
        text-shadow: none !important;
      }
    }
    """

    {:ok, css}
  end

  @doc """
  Generates @page rules for PDF page configuration.
  """
  @spec generate_page_rules(RenderContext.t()) :: {:ok, String.t()}
  def generate_page_rules(%RenderContext{} = context) do
    page_config = get_page_configuration(context)

    css = """
    /* @page rules for PDF generation */
    @page {
      size: #{page_config.size} #{page_config.orientation};
      margin: #{page_config.margins};
      
      /* Page header */
      @top-left {
        content: "#{page_config.header_left}";
        font-size: #{page_config.header_font_size};
        font-family: #{page_config.header_font};
      }
      
      @top-center {
        content: "#{page_config.header_center}";
        font-size: #{page_config.header_font_size};
        font-family: #{page_config.header_font};
      }
      
      @top-right {
        content: "#{page_config.header_right}";
        font-size: #{page_config.header_font_size};
        font-family: #{page_config.header_font};
      }
      
      /* Page footer */
      @bottom-left {
        content: "#{page_config.footer_left}";
        font-size: #{page_config.footer_font_size};
        font-family: #{page_config.footer_font};
      }
      
      @bottom-center {
        content: "#{page_config.footer_center}";
        font-size: #{page_config.footer_font_size};
        font-family: #{page_config.footer_font};
      }
      
      @bottom-right {
        content: "#{page_config.footer_right}";
        font-size: #{page_config.footer_font_size};
        font-family: #{page_config.footer_font};
      }
    }

    /* First page special rules */
    @page :first {
      margin-top: #{page_config.first_page_margin_top};
      
      @top-center {
        content: "#{page_config.first_page_header}";
        font-size: #{page_config.title_font_size};
        font-weight: bold;
      }
    }

    /* Page break controls */
    @media print {
      .ash-page-break-before {
        page-break-before: always;
      }
      
      .ash-page-break-after {
        page-break-after: always;
      }
      
      .ash-page-break-avoid {
        page-break-inside: avoid;
      }
    }
    """

    {:ok, css}
  end

  @doc """
  Generates element-specific CSS for AshReports elements optimized for print.
  """
  @spec generate_element_specific_css(RenderContext.t()) :: {:ok, String.t()}
  def generate_element_specific_css(%RenderContext{} = context) do
    with {:ok, label_css} <- generate_label_element_css(context),
         {:ok, field_css} <- generate_field_element_css(context),
         {:ok, table_css} <- generate_table_element_css(context),
         {:ok, image_css} <- generate_image_element_css(context),
         {:ok, chart_css} <- generate_chart_element_css(context) do
      combined_css =
        combine_css_sections([
          label_css,
          field_css,
          table_css,
          image_css,
          chart_css
        ])

      {:ok, combined_css}
    else
      {:error, _reason} = error -> error
    end
  end

  # Private helper functions

  defp get_font_configuration(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}

    %{
      body_font: "serif",
      heading_font: "sans-serif",
      mono_font: "monospace",
      base_size: "12pt",
      body_weight: "normal",
      heading_weight: "bold",
      strong_weight: "bold",
      line_height: "1.4",
      h1_size: "18pt",
      h1_margin: "0 0 12pt 0",
      h2_size: "16pt",
      h2_margin: "12pt 0 8pt 0",
      h3_size: "14pt",
      h3_margin: "8pt 0 6pt 0",
      paragraph_margin: "0 0 6pt 0",
      table_size: "11pt",
      table_line_height: "1.3",
      table_header_size: "11pt",
      table_header_weight: "bold",
      table_cell_size: "11pt",
      mono_size: "10pt",
      mono_line_height: "1.2",
      small_size: "10pt"
    }
    |> Map.merge(pdf_config[:fonts] || %{})
  end

  defp get_layout_configuration(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}

    %{
      report_margin: "0",
      report_padding: "0",
      header_spacing: "12pt",
      header_padding: "6pt",
      header_border: "1pt solid #cccccc",
      footer_spacing: "12pt",
      footer_padding: "6pt",
      footer_border: "1pt solid #cccccc",
      band_spacing: "18pt",
      band_header_spacing: "6pt",
      element_spacing: "6pt",
      label_spacing: "3pt",
      label_weight: "bold",
      field_spacing: "6pt",
      table_spacing: "12pt",
      table_cell_padding: "4pt 6pt",
      table_border: "1pt solid #cccccc",
      grid_row_spacing: "6pt",
      grid_col_spacing: "3pt",
      spacing_small: "3pt",
      spacing_medium: "6pt",
      spacing_large: "12pt"
    }
    |> Map.merge(pdf_config[:layout] || %{})
  end

  defp get_color_configuration(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}

    %{
      text_primary: "#000000",
      text_secondary: "#333333",
      text_muted: "#666666",
      bg_light: "#f8f9fa",
      bg_medium: "#e9ecef",
      border_light: "#dee2e6",
      border_medium: "#adb5bd",
      border_dark: "#6c757d",
      table_header_bg: "#f8f9fa",
      table_header_text: "#000000",
      table_stripe_bg: "#f8f9fa",
      success_text: "#155724",
      success_bg: "#d4edda",
      warning_text: "#856404",
      warning_bg: "#fff3cd",
      error_text: "#721c24",
      error_bg: "#f8d7da"
    }
    |> Map.merge(pdf_config[:colors] || %{})
  end

  defp get_page_configuration(%RenderContext{} = context) do
    pdf_config = context.config[:pdf] || %{}

    %{
      size: pdf_config[:page_size] || "A4",
      orientation: pdf_config[:orientation] || "portrait",
      margins: "20mm 15mm",
      header_left: "",
      header_center: pdf_config[:headers][:text] || "",
      header_right: "",
      header_font: "sans-serif",
      header_font_size: "10pt",
      footer_left: "",
      footer_center: if(pdf_config[:footers][:page_numbers], do: "counter(page)", else: ""),
      footer_right: "",
      footer_font: "sans-serif",
      footer_font_size: "10pt",
      first_page_margin_top: "30mm",
      first_page_header: context.report[:title] || "Report",
      title_font_size: "16pt"
    }
    |> Map.merge(pdf_config[:page] || %{})
  end

  defp generate_label_element_css(_context) do
    css = """
    /* Label Element Print Styles */
    @media print {
      .ash-element-label {
        display: block;
        font-weight: bold;
        margin-bottom: 3pt;
        page-break-after: avoid;
      }
      
      .ash-label-required::after {
        content: " *";
        color: #721c24;
      }
    }
    """

    {:ok, css}
  end

  defp generate_field_element_css(_context) do
    css = """
    /* Field Element Print Styles */
    @media print {
      .ash-element-field {
        display: block;
        margin-bottom: 6pt;
      }
      
      .ash-field-value {
        padding: 2pt 4pt;
        border-bottom: 1pt solid #dee2e6;
        min-height: 14pt;
      }
      
      .ash-field-empty {
        border-bottom: 1pt dotted #adb5bd;
        color: #6c757d;
      }
    }
    """

    {:ok, css}
  end

  defp generate_table_element_css(_context) do
    css = """
    /* Table Element Print Styles */
    @media print {
      .ash-element-table {
        page-break-inside: avoid;
        margin-bottom: 12pt;
      }
      
      .ash-table {
        width: 100%;
        border-collapse: collapse;
      }
      
      .ash-table-header {
        background-color: #f8f9fa !important;
        page-break-after: avoid;
      }
      
      .ash-table-row {
        page-break-inside: avoid;
      }
      
      .ash-table-cell {
        vertical-align: top;
        word-wrap: break-word;
      }
    }
    """

    {:ok, css}
  end

  defp generate_image_element_css(_context) do
    css = """
    /* Image Element Print Styles */
    @media print {
      .ash-element-image {
        page-break-inside: avoid;
        text-align: center;
        margin-bottom: 12pt;
      }
      
      .ash-image {
        max-width: 100%;
        height: auto;
        border: 1pt solid #dee2e6;
      }
      
      .ash-image-caption {
        font-size: 10pt;
        color: #6c757d;
        margin-top: 6pt;
        text-align: center;
      }
    }
    """

    {:ok, css}
  end

  defp generate_chart_element_css(_context) do
    css = """
    /* Chart Element Print Styles */
    @media print {
      .ash-element-chart {
        page-break-inside: avoid;
        margin-bottom: 12pt;
      }
      
      .ash-chart-container {
        width: 100%;
        text-align: center;
      }
      
      .ash-chart-title {
        font-weight: bold;
        margin-bottom: 6pt;
      }
      
      .ash-chart-legend {
        font-size: 10pt;
        margin-top: 6pt;
      }
    }
    """

    {:ok, css}
  end

  defp combine_css_sections(sections) do
    sections
    |> Enum.join("\n\n")
    |> String.trim()
  end
end
