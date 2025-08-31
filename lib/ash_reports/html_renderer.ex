defmodule AshReports.HtmlRenderer do
  @moduledoc """
  Phase 3.2 HTML Renderer - Complete HTML output system for AshReports.

  The HtmlRenderer provides comprehensive HTML generation capabilities, implementing
  the Phase 3.1 Renderer Interface with sophisticated template processing, CSS
  generation, element building, and responsive layout support.

  ## Phase 3.2 Components

  - **HTML Template System (3.2.1)**: EEx-based template engine with layout support
  - **CSS Generation Engine (3.2.2)**: Dynamic CSS generation with responsive design
  - **HTML Element Builders (3.2.3)**: Type-specific element factories and builders
  - **Responsive Layout System (3.2.4)**: Breakpoint management and device adaptation

  ## Integration with Phase 3.1

  The HtmlRenderer seamlessly integrates with the Phase 3.1 infrastructure:

  - Uses RenderContext for state management during HTML generation
  - Leverages LayoutEngine for element positioning and CSS coordinates
  - Integrates with RenderPipeline for staged HTML assembly
  - Uses RendererIntegration for DataLoader connection

  ## Usage

  ### Basic HTML Rendering

      context = RenderContext.new(report, data_result)
      {:ok, result} = HtmlRenderer.render_with_context(context)

      # result.content contains complete HTML with embedded CSS
      File.write!("report.html", result.content)

  ### With Custom Configuration

      config = %{
        template: :modern,
        responsive: true,
        css_framework: :bootstrap,
        embed_css: true
      }

      context = RenderContext.new(report, data_result, config)
      {:ok, result} = HtmlRenderer.render_with_context(context)

  ### Streaming Support

      {:ok, stream} = RenderPipeline.execute_streaming(context, HtmlRenderer)

      stream
      |> Stream.each(&File.write!("chunk_#{:rand.uniform(1000)}.html", &1.chunk_data))
      |> Stream.run()

  ## HTML Structure

  Generated HTML follows semantic structure:

  ```html
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Report Title</title>
    <style>/* Generated CSS */</style>
  </head>
  <body>
    <div class="ash-report" data-report="report_name">
      <header class="ash-report-header">...</header>
      <main class="ash-report-content">
        <section class="ash-band" data-band="band_name">
          <div class="ash-element ash-element-label">...</div>
          <div class="ash-element ash-element-field">...</div>
        </section>
      </main>
      <footer class="ash-report-footer">...</footer>
    </div>
  </body>
  </html>
  ```

  ## Performance Features

  - **Template Compilation**: Pre-compiled EEx templates for optimal performance
  - **CSS Optimization**: Minified CSS with only required styles
  - **Streaming Support**: Memory-efficient processing of large datasets
  - **Caching**: Template and CSS caching for repeated operations

  """

  @behaviour AshReports.Renderer

  alias AshReports.{
    Cldr,
    Formatter,
    HtmlRenderer.CssGenerator,
    HtmlRenderer.ElementBuilder,
    HtmlRenderer.ResponsiveLayout,
    HtmlRenderer.TemplateEngine,
    RenderContext
  }

  @doc """
  Enhanced render callback with full Phase 3.2 HTML generation.

  Implements the Phase 3.1 Renderer behaviour with comprehensive HTML output.
  """
  @impl AshReports.Renderer
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, template_context} <- prepare_template_context(context, opts),
         {:ok, formatted_context} <- apply_locale_formatting(template_context),
         {:ok, css_content} <- generate_css(formatted_context),
         {:ok, html_elements} <- build_html_elements(formatted_context),
         {:ok, final_html} <- assemble_html(formatted_context, css_content, html_elements),
         {:ok, result_metadata} <- build_result_metadata(formatted_context, start_time) do
      result = %{
        content: final_html,
        metadata: result_metadata,
        context: formatted_context
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Whether this renderer supports streaming output.
  """
  @impl AshReports.Renderer
  def supports_streaming?, do: true

  @doc """
  The file extension for HTML format.
  """
  @impl AshReports.Renderer
  def file_extension, do: "html"

  @doc """
  The MIME content type for HTML format.
  """
  @impl AshReports.Renderer
  def content_type, do: "text/html"

  @doc """
  Validates that the renderer can handle the given context.
  """
  @impl AshReports.Renderer
  def validate_context(%RenderContext{} = context) do
    with :ok <- validate_html_requirements(context),
         :ok <- validate_template_compatibility(context),
         :ok <- validate_element_support(context) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Prepares the renderer for HTML rendering operations.
  """
  @impl AshReports.Renderer
  def prepare(%RenderContext{} = context, opts) do
    enhanced_context =
      context
      |> add_html_configuration(opts)
      |> initialize_template_state()
      |> initialize_css_state()
      |> initialize_responsive_state()

    {:ok, enhanced_context}
  end

  @doc """
  Cleans up after HTML rendering operations.
  """
  @impl AshReports.Renderer
  def cleanup(%RenderContext{} = _context, _result) do
    # Clean up any temporary resources, caches, etc.
    TemplateEngine.cleanup_temporary_templates()
    CssGenerator.cleanup_temporary_styles()
    :ok
  end

  # Legacy render callback for backward compatibility
  @impl AshReports.Renderer
  def render(report_module, data, opts) do
    # Convert to new context-based API
    config = Keyword.get(opts, :config, %{})
    context = RenderContext.new(report_module, %{records: data}, config)

    case render_with_context(context, opts) do
      {:ok, result} -> {:ok, result.content}
      {:error, _reason} = error -> error
    end
  end

  # Private implementation functions

  defp prepare_template_context(%RenderContext{} = context, opts) do
    template_config = build_template_config(context, opts)

    enhanced_context = %{
      context
      | config:
          Map.merge(context.config, %{
            html: template_config,
            template_engine: :eex,
            css_generation: true,
            responsive_layout: true
          })
    }

    {:ok, enhanced_context}
  end

  defp build_template_config(context, opts) do
    %{
      template: Keyword.get(opts, :template, :default),
      responsive: Keyword.get(opts, :responsive, true),
      css_framework: Keyword.get(opts, :css_framework, :custom),
      embed_css: Keyword.get(opts, :embed_css, true),
      include_viewport: Keyword.get(opts, :include_viewport, true),
      semantic_html: Keyword.get(opts, :semantic_html, true),
      accessibility: Keyword.get(opts, :accessibility, true),
      # Locale-aware formatting settings
      locale_formatting: Keyword.get(opts, :locale_formatting, true),
      text_direction: RenderContext.get_text_direction(context),
      locale_css_classes: RenderContext.locale_css_classes(context),
      decimal_separator: Cldr.decimal_separator(RenderContext.get_locale(context)),
      thousands_separator: Cldr.thousands_separator(RenderContext.get_locale(context))
    }
  end

  defp generate_css(%RenderContext{} = context) do
    CssGenerator.generate_stylesheet(context)
  end

  defp build_html_elements(%RenderContext{} = context) do
    ElementBuilder.build_all_elements(context)
  end

  defp assemble_html(%RenderContext{} = context, css_content, html_elements) do
    TemplateEngine.render_complete_html(context, css_content, html_elements)
  end

  defp apply_locale_formatting(%RenderContext{} = context) do
    # Apply locale-aware formatting to data records if enabled
    html_config = context.config[:html] || %{}

    if html_config[:locale_formatting] do
      locale = RenderContext.get_locale(context)

      # Format the records with locale-aware formatting
      formatted_records =
        context.records
        |> Enum.map(fn record ->
          apply_record_formatting(record, locale, context)
        end)

      # Update context with formatted records
      updated_context = %{context | records: formatted_records}

      # Add formatted metadata
      locale_metadata = RenderContext.get_locale_metadata(context)

      updated_metadata =
        Map.put(context.metadata, :locale_formatting, %{
          applied: true,
          locale: locale,
          text_direction: RenderContext.get_text_direction(context),
          formatting_metadata: locale_metadata
        })

      final_context = %{updated_context | metadata: updated_metadata}
      {:ok, final_context}
    else
      {:ok, context}
    end
  end

  defp apply_record_formatting(record, locale, _context) when is_map(record) do
    # Apply locale-specific formatting to numeric and date fields
    Enum.reduce(record, %{}, fn {key, value}, acc ->
      format_type = detect_field_format_type(key, value)
      formatted_value = format_field_by_type(value, format_type, locale)

      # Store both original and formatted values
      acc
      # Keep original for calculations
      |> Map.put(key, value)
      # Add formatted for display
      |> Map.put(String.to_atom("#{key}_formatted"), formatted_value)
    end)
  end

  defp apply_record_formatting(record, _locale, _context), do: record

  defp format_field_by_type(value, :number, locale) do
    case Formatter.format_value(value, locale: locale, type: :number) do
      {:ok, formatted} -> formatted
      {:error, _} -> value
    end
  end

  defp format_field_by_type(value, :currency, locale) do
    case Formatter.format_value(value, locale: locale, type: :currency, currency: :USD) do
      {:ok, formatted} -> formatted
      {:error, _} -> value
    end
  end

  defp format_field_by_type(value, :date, locale) do
    case Formatter.format_value(value, locale: locale, type: :date) do
      {:ok, formatted} -> formatted
      {:error, _} -> value
    end
  end

  defp format_field_by_type(value, :percentage, locale) do
    case Formatter.format_value(value, locale: locale, type: :percentage) do
      {:ok, formatted} -> formatted
      {:error, _} -> value
    end
  end

  defp format_field_by_type(value, _, _locale), do: value

  defp detect_field_format_type(key, value) do
    cond do
      currency_field?(key, value) -> :currency
      percentage_field?(key, value) -> :percentage
      date_field?(value) -> :date
      is_number(value) -> :number
      true -> :string
    end
  end

  defp currency_field?(key, value) do
    key_string = to_string(key)
    currency_keywords = ["amount", "price", "cost", "total", "salary", "wage"]
    String.contains?(key_string, currency_keywords) and is_number(value)
  end

  defp percentage_field?(key, value) do
    key_string = to_string(key)
    percentage_keywords = ["rate", "percent", "ratio", "margin"]
    String.contains?(key_string, percentage_keywords) and is_number(value)
  end

  defp date_field?(value) do
    match?(%Date{}, value) or match?(%DateTime{}, value) or match?(%NaiveDateTime{}, value)
  end

  defp build_result_metadata(%RenderContext{} = context, start_time) do
    end_time = System.monotonic_time(:microsecond)
    render_time = end_time - start_time

    metadata = %{
      format: :html,
      render_time_us: render_time,
      template_engine: :eex,
      css_generated: true,
      responsive_layout: context.config[:html][:responsive],
      element_count: length(context.rendered_elements),
      css_rules_count: get_css_rules_count(context),
      html_size_bytes: get_estimated_html_size(context),
      phase: "4.1.0",
      # Phase 4.1 CLDR Integration metadata
      locale: RenderContext.get_locale(context),
      text_direction: RenderContext.get_text_direction(context),
      locale_formatting_applied:
        get_in(context.metadata, [:locale_formatting, :applied]) || false,
      locale_css_classes: RenderContext.locale_css_classes(context),
      components_used: [
        :template_engine,
        :css_generator,
        :element_builder,
        :responsive_layout,
        # New component
        :cldr_formatter
      ]
    }

    {:ok, metadata}
  end

  defp validate_html_requirements(%RenderContext{report: nil}) do
    {:error, :missing_report}
  end

  defp validate_html_requirements(%RenderContext{records: []}) do
    {:error, :no_data_to_render}
  end

  defp validate_html_requirements(_context), do: :ok

  defp validate_template_compatibility(%RenderContext{} = _context) do
    # Validate that all required templates are available
    case TemplateEngine.validate_templates() do
      :ok -> :ok
      {:error, missing} -> {:error, {:missing_templates, missing}}
    end
  end

  defp validate_element_support(%RenderContext{} = context) do
    # Validate that all elements in the report can be rendered as HTML
    unsupported_elements =
      context.report
      |> extract_all_elements()
      |> Enum.reject(&ElementBuilder.supports_element?/1)

    if unsupported_elements == [] do
      :ok
    else
      {:error, {:unsupported_elements, unsupported_elements}}
    end
  end

  defp extract_all_elements(%{bands: bands}) when is_list(bands) do
    Enum.flat_map(bands, fn band ->
      Map.get(band, :elements, [])
    end)
  end

  defp extract_all_elements(_), do: []

  defp add_html_configuration(%RenderContext{} = context, opts) do
    html_config = build_template_config(context, opts)
    updated_config = Map.put(context.config, :html, html_config)
    %{context | config: updated_config}
  end

  defp initialize_template_state(%RenderContext{} = context) do
    template_state = %{
      templates_loaded: [],
      template_cache: %{},
      current_template: :default
    }

    updated_metadata = Map.put(context.metadata, :template_state, template_state)
    %{context | metadata: updated_metadata}
  end

  defp initialize_css_state(%RenderContext{} = context) do
    css_state = %{
      generated_rules: [],
      css_cache: %{},
      responsive_breakpoints: ResponsiveLayout.default_breakpoints()
    }

    updated_metadata = Map.put(context.metadata, :css_state, css_state)
    %{context | metadata: updated_metadata}
  end

  defp initialize_responsive_state(%RenderContext{} = context) do
    responsive_state = %{
      breakpoints: ResponsiveLayout.default_breakpoints(),
      current_breakpoint: :desktop,
      responsive_elements: []
    }

    updated_metadata = Map.put(context.metadata, :responsive_state, responsive_state)
    %{context | metadata: updated_metadata}
  end

  defp get_css_rules_count(%RenderContext{} = context) do
    context.metadata
    |> Map.get(:css_state, %{})
    |> Map.get(:generated_rules, [])
    |> length()
  end

  defp get_estimated_html_size(%RenderContext{} = _context) do
    # This would calculate the estimated HTML size
    # For now, return a placeholder
    0
  end
end
