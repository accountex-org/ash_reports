defmodule AshReports.HtmlRenderer do
  @moduledoc """
  Phase 3.2 HTML Renderer with Phase 4.3 Locale-aware Rendering - Complete HTML output system for AshReports.

  The HtmlRenderer provides comprehensive HTML generation capabilities, implementing
  the Phase 3.1 Renderer Interface with sophisticated template processing, CSS
  generation, element building, responsive layout support, and comprehensive RTL
  (Right-to-Left) rendering for international locales.

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
    HtmlRenderer.AssetManager,
    HtmlRenderer.ChartIntegrator,
    HtmlRenderer.CssGenerator,
    HtmlRenderer.ElementBuilder,
    HtmlRenderer.JavaScriptGenerator,
    HtmlRenderer.ResponsiveLayout,
    HtmlRenderer.TemplateEngine,
    RenderContext,
    RtlLayoutEngine,
    Translation
  }

  @doc """
  Enhanced render callback with full Phase 3.2 HTML generation.

  Implements the Phase 3.1 Renderer behaviour with comprehensive HTML output.
  """
  @impl AshReports.Renderer
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, template_context} <- prepare_template_context(context, opts),
         {:ok, chart_assets} <- process_chart_requirements(template_context),
         {:ok, css_content} <- generate_css(template_context),
         {:ok, html_elements} <- build_html_elements(template_context),
         {:ok, charts_html} <- generate_charts_html(template_context),
         {:ok, javascript_code} <- generate_charts_javascript(template_context, chart_assets),
         {:ok, final_html} <-
           assemble_html_with_charts(
             template_context,
             css_content,
             html_elements,
             charts_html,
             javascript_code
           ),
         {:ok, result_metadata} <- build_result_metadata(template_context, start_time) do
      result = %{
        content: final_html,
        metadata: result_metadata,
        context: template_context
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
    rtl_config = build_rtl_config(context)

    enhanced_context = %{
      context
      | config:
          Map.merge(context.config, %{
            html: template_config,
            template_engine: :eex,
            css_generation: true,
            responsive_layout: true,
            rtl_support: rtl_config
          })
    }

    {:ok, enhanced_context}
  end

  defp build_rtl_config(%RenderContext{} = context) do
    locale = RenderContext.get_locale(context)
    text_direction = Cldr.text_direction(locale)

    %{
      locale: locale,
      text_direction: text_direction,
      rtl_enabled: RtlLayoutEngine.rtl_locale?(locale),
      rtl_layout_adaptations: text_direction == "rtl"
    }
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

  # TODO: Advanced HTML Assembly - Advanced HTML assembly with optimizations
  # Part of unfinished feature: Sophisticated HTML generation with performance optimizations
  defp assemble_html(%RenderContext{} = context, css_content, html_elements) do
    # Apply RTL layout adaptations if needed
    adapted_context = apply_rtl_layout_adaptations(context)
    adapted_elements = apply_rtl_element_adaptations(html_elements, adapted_context)

    TemplateEngine.render_complete_html(adapted_context, css_content, adapted_elements)
  end

  # TODO: RTL Language Support - Adapt layouts for RTL languages (Arabic, Hebrew, etc.)
  # Part of unfinished feature: Comprehensive RTL language support
  defp apply_rtl_layout_adaptations(%RenderContext{} = context) do
    rtl_config = context.config[:rtl_support] || %{}

    if rtl_config[:rtl_layout_adaptations] do
      # Adapt layout data for RTL if present
      case Map.get(context, :layout_state) do
        nil ->
          context

        layout_state ->
          {:ok, adapted_layout} =
            RtlLayoutEngine.adapt_container_layout(
              layout_state,
              text_direction: rtl_config[:text_direction],
              locale: rtl_config[:locale]
            )

          %{context | layout_state: adapted_layout}
      end
    else
      context
    end
  end

  # TODO: RTL Language Support - Apply RTL attributes to HTML elements
  # Part of unfinished feature: Comprehensive RTL language support
  defp apply_rtl_element_adaptations(html_elements, %RenderContext{} = context) do
    rtl_config = context.config[:rtl_support] || %{}

    if rtl_config[:rtl_enabled] do
      Enum.map(html_elements, fn element ->
        add_rtl_attributes_to_element(element, rtl_config)
      end)
    else
      html_elements
    end
  end

  # TODO: RTL Language Support - Add specific RTL styling/attributes
  # Part of unfinished feature: Comprehensive RTL language support
  defp add_rtl_attributes_to_element(element, rtl_config) when is_map(element) do
    rtl_attributes = %{
      dir: rtl_config[:text_direction],
      lang: rtl_config[:locale],
      class: "#{Map.get(element, :class, "")} rtl-element"
    }

    Map.merge(element, rtl_attributes)
  end

  defp add_rtl_attributes_to_element(element, _rtl_config), do: element

  # TODO: Advanced Locale Formatting - Apply locale-specific HTML formatting
  # Part of unfinished feature: Advanced locale-aware formatting
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

      # Apply translation enhancements
      translated_context = apply_translation_enhancements(updated_context)

      # Add formatted metadata
      locale_metadata = RenderContext.get_locale_metadata(context)

      updated_metadata =
        Map.put(translated_context.metadata, :locale_formatting, %{
          applied: true,
          locale: locale,
          text_direction: RenderContext.get_text_direction(context),
          formatting_metadata: locale_metadata,
          translations_applied: true
        })

      final_context = %{translated_context | metadata: updated_metadata}
      {:ok, final_context}
    else
      {:ok, context}
    end
  end

  # TODO: Smart Field Formatting - Apply advanced record-level formatting
  # Part of unfinished feature: Automatic intelligent formatting of report fields
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

  # TODO: Smart Field Formatting - Apply appropriate formatting based on detected type
  # Part of unfinished feature: Automatic intelligent formatting of report fields
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

  # TODO: Smart Field Formatting - Auto-detect if field is currency, percentage, date, etc.
  # Part of unfinished feature: Automatic intelligent formatting of report fields
  defp detect_field_format_type(key, value) do
    cond do
      currency_field?(key, value) -> :currency
      percentage_field?(key, value) -> :percentage
      date_field?(value) -> :date
      is_number(value) -> :number
      true -> :string
    end
  end

  # TODO: Smart Field Formatting - Detect currency fields by name/value patterns
  # Part of unfinished feature: Automatic intelligent formatting of report fields
  defp currency_field?(key, value) do
    key_string = to_string(key)
    currency_keywords = ["amount", "price", "cost", "total", "salary", "wage"]
    String.contains?(key_string, currency_keywords) and is_number(value)
  end

  # TODO: Smart Field Formatting - Detect percentage fields
  # Part of unfinished feature: Automatic intelligent formatting of report fields
  defp percentage_field?(key, value) do
    key_string = to_string(key)
    percentage_keywords = ["rate", "percent", "ratio", "margin"]
    String.contains?(key_string, percentage_keywords) and is_number(value)
  end

  # TODO: Smart Field Formatting - Detect date/datetime fields
  # Part of unfinished feature: Automatic intelligent formatting of report fields
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

  # Phase 4.3 Translation and RTL Support Functions

  # TODO: Full Internationalization - Apply locale-specific formatting and translations
  # Part of unfinished feature: Multi-language report support
  defp apply_translation_enhancements(%RenderContext{} = context) do
    locale = RenderContext.get_locale(context)

    # Add translated UI elements to context metadata
    ui_translations = %{
      field_labels: prepare_field_label_translations(context, locale),
      band_titles: prepare_band_title_translations(context, locale),
      status_messages: prepare_status_message_translations(locale)
    }

    updated_metadata = Map.put(context.metadata, :translations, ui_translations)
    %{context | metadata: updated_metadata}
  end

  # TODO: Full Internationalization - Translate field names based on locale
  # Part of unfinished feature: Multi-language report support
  defp prepare_field_label_translations(%RenderContext{} = context, locale) do
    # Extract field names from report definition and create translation map
    field_names = extract_field_names_from_report(context.report)

    Enum.reduce(field_names, %{}, fn field_name, acc ->
      translated_label = Translation.translate_field_label(field_name, locale)
      Map.put(acc, field_name, translated_label)
    end)
  end

  # TODO: Full Internationalization - Translate report section titles
  # Part of unfinished feature: Multi-language report support
  defp prepare_band_title_translations(%RenderContext{} = context, locale) do
    # Extract band names from report definition and create translation map
    band_names = extract_band_names_from_report(context.report)

    Enum.reduce(band_names, %{}, fn band_name, acc ->
      translated_title = Translation.translate_band_title(band_name, locale)
      Map.put(acc, band_name, translated_title)
    end)
  end

  # TODO: Full Internationalization - Translate UI status messages
  # Part of unfinished feature: Multi-language report support
  defp prepare_status_message_translations(locale) do
    status_keys = ["status.loading", "status.complete", "status.no_data"]

    Enum.reduce(status_keys, %{}, fn key, acc ->
      case Translation.translate_ui(key, [], locale) do
        {:ok, translated} ->
          status_name = key |> String.split(".") |> List.last()
          Map.put(acc, status_name, translated)

        {:error, _} ->
          acc
      end
    end)
  end

  # TODO: Report Analytics - Extract all field names for analysis
  # Part of unfinished feature: Report introspection and metadata extraction
  defp extract_field_names_from_report(report) do
    report.bands
    |> Enum.flat_map(fn band ->
      Map.get(band, :elements, [])
      |> Enum.filter(fn element ->
        Map.get(element, :type) == :field
      end)
      |> Enum.map(fn element ->
        Map.get(element, :source) || Map.get(element, :name)
      end)
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
  end

  # TODO: Report Analytics - Extract report section names
  # Part of unfinished feature: Report introspection and metadata extraction
  defp extract_band_names_from_report(report) do
    report.bands
    |> Enum.map(fn band -> Map.get(band, :name) end)
    |> Enum.filter(&(&1 != nil))
  end

  # Phase 5.2: Chart Integration Functions

  defp process_chart_requirements(%RenderContext{} = context) do
    # Check if report has chart configurations
    chart_configs = extract_chart_configs_from_context(context)

    if length(chart_configs) > 0 do
      required_providers = chart_configs |> Enum.map(& &1.provider) |> Enum.uniq()

      asset_requirements =
        required_providers |> Enum.flat_map(&AssetManager.get_provider_assets/1)

      {:ok,
       %{
         providers: required_providers,
         assets: asset_requirements,
         chart_configs: chart_configs,
         optimization: AssetManager.get_optimization_recommendations(required_providers, context)
       }}
    else
      {:ok, %{providers: [], assets: [], chart_configs: [], optimization: %{}}}
    end
  end

  defp generate_charts_html(%RenderContext{} = context) do
    chart_configs = extract_chart_configs_from_context(context)

    case chart_configs do
      [] -> {:ok, ""}
      configs -> process_chart_configs(configs, context)
    end
  end

  defp process_chart_configs(chart_configs, %RenderContext{} = context) do
    charts_html =
      chart_configs
      |> Enum.map(&render_single_chart(&1, context))
      |> Enum.join("\n")

    {:ok, charts_html}
  end

  defp render_single_chart(chart_config, %RenderContext{} = context) do
    case ChartIntegrator.render_chart(chart_config, context) do
      {:ok, chart_output} -> chart_output.html
      {:error, _reason} -> generate_chart_error_fallback(chart_config, context)
    end
  end

  defp generate_charts_javascript(%RenderContext{} = context, chart_assets) do
    chart_configs = extract_chart_configs_from_context(context)

    case chart_configs do
      [] -> {:ok, ""}
      configs -> build_complete_javascript(configs, chart_assets, context)
    end
  end

  defp build_complete_javascript(chart_configs, chart_assets, %RenderContext{} = context) do
    asset_loading_js =
      JavaScriptGenerator.generate_asset_loading_javascript(chart_assets.assets, context)

    chart_javascript = generate_all_chart_javascript(chart_configs, context)

    complete_javascript = """
    <script>
    #{asset_loading_js}

    #{chart_javascript}
    </script>
    """

    {:ok, complete_javascript}
  end

  defp generate_all_chart_javascript(chart_configs, %RenderContext{} = context) do
    chart_configs
    |> Enum.map(&build_chart_js_config(&1, context))
    |> Enum.map(&generate_single_chart_javascript(&1, context))
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.join("\n\n")
  end

  defp build_chart_js_config(chart_config, %RenderContext{} = context) do
    %{
      chart_id: generate_chart_id(chart_config),
      provider: chart_config.provider,
      chart_config: chart_config,
      interactive: chart_config.interactive,
      events: chart_config.interactions || []
    }
  end

  defp generate_single_chart_javascript(js_config, %RenderContext{} = context) do
    case JavaScriptGenerator.generate_chart_javascript(js_config, context) do
      {:ok, js_code} -> js_code
      {:error, _reason} -> ""
    end
  end

  defp assemble_html_with_charts(
         %RenderContext{} = context,
         css_content,
         html_elements,
         charts_html,
         javascript_code
       ) do
    # Enhanced HTML assembly with Phase 5.2 chart integration
    enhanced_html = """
    <!DOCTYPE html>
    <html lang="#{context.locale}" dir="#{context.text_direction}">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{get_page_title(context)}</title>
      
      <!-- Phase 5.2: Chart Assets -->
      #{AssetManager.generate_css_links(context)}
      
      <style>
      #{css_content}
      </style>
    </head>
    <body class="ash-reports #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}">
      <main class="ash-report-content">
        #{html_elements}
        
        <!-- Phase 5.2: Charts Section -->
        #{if String.length(charts_html) > 0, do: "<section class=\"ash-charts-section\">#{charts_html}</section>", else: ""}
      </main>
      
      <!-- Phase 5.2: Chart JavaScript -->
      #{javascript_code}
    </body>
    </html>
    """

    {:ok, enhanced_html}
  end

  # Helper functions for Phase 5.2 integration

  defp extract_chart_configs_from_context(%RenderContext{} = context) do
    # Extract chart configurations from report definition or context metadata
    # This is a placeholder - would need to be integrated with report DSL
    context.metadata[:chart_configs] || []
  end

  defp generate_chart_id(chart_config) do
    # Generate unique chart ID based on config
    chart_name = chart_config.title || "chart"
    chart_type = chart_config.type

    hash =
      :crypto.hash(:md5, "#{chart_name}_#{chart_type}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)

    "ash_chart_#{chart_type}_#{hash}"
  end

  defp generate_chart_error_fallback(chart_config, %RenderContext{} = context) do
    error_message =
      case context.locale do
        "ar" -> "فشل في عرض الرسم البياني"
        "es" -> "Error al mostrar el gráfico"
        "fr" -> "Erreur d'affichage du graphique"
        _ -> "Chart display error"
      end

    """
    <div class="ash-chart-error">
      <h4>#{chart_config.title || "Chart"}</h4>
      <p class="error">#{error_message}</p>
    </div>
    """
  end

  defp get_page_title(%RenderContext{} = context) do
    # Extract title from report or use default
    context.metadata[:title] || "AshReports Interactive Report"
  end
end
