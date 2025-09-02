defmodule AshReports.HtmlRenderer.ChartIntegrator do
  @moduledoc """
  Chart integration module for AshReports HTML Renderer in Phase 5.2.

  Integrates Phase 5.1 chart engine capabilities with the HTML renderer to provide
  interactive charts, client-side JavaScript generation, and seamless chart display
  across browsers with full accessibility and RTL support.

  ## Features

  - **Chart Container Generation**: HTML containers with accessibility attributes
  - **Chart Engine Integration**: Seamless integration with Phase 5.1 ChartEngine
  - **RTL and Locale Support**: Full internationalization for chart display
  - **JavaScript Generation**: Client-side chart initialization code
  - **Error Handling**: Graceful degradation when JavaScript is disabled
  - **Performance Optimization**: Lazy loading and efficient asset management

  ## Usage Examples

  ### Basic Chart Integration

      chart_config = %ChartConfig{
        type: :line,
        data: sales_data,
        title: "Monthly Sales Trends"
      }
      
      {html, javascript} = ChartIntegrator.render_chart(chart_config, context)

  ### Interactive Chart with Filtering

      interactive_config = %ChartConfig{
        type: :bar,
        data: filtered_data,
        interactive: true,
        interactions: [:hover, :click, :filter]
      }
      
      chart_output = ChartIntegrator.render_interactive_chart(interactive_config, context)

  ### Chart Set for Dashboard

      chart_set = %{
        overview: line_chart_config,
        breakdown: pie_chart_config,
        trends: area_chart_config
      }
      
      dashboard = ChartIntegrator.render_chart_dashboard(chart_set, context)

  """

  alias AshReports.ChartEngine
  alias AshReports.ChartEngine.{ChartConfig, ChartData}
  alias AshReports.HtmlRenderer.{JavaScriptGenerator, AssetManager}
  alias AshReports.{RenderContext, Translation}

  @type chart_output :: %{
          html: String.t(),
          javascript: String.t(),
          css: String.t(),
          assets: [String.t()],
          metadata: map()
        }

  @doc """
  Render a single chart with HTML container and JavaScript initialization.

  ## Examples

      config = %ChartConfig{type: :line, data: [[1, 10], [2, 20]], title: "Sales"}
      {html, js} = ChartIntegrator.render_chart(config, context)

  """
  @spec render_chart(ChartConfig.t(), RenderContext.t()) ::
          {:ok, chart_output()} | {:error, String.t()}
  def render_chart(%ChartConfig{} = config, %RenderContext{} = context) do
    with {:ok, chart_result} <- ChartEngine.generate(config, context),
         {:ok, html_container} <- generate_chart_container(chart_result, config, context),
         {:ok, javascript_code} <- generate_chart_javascript(chart_result, config, context),
         {:ok, css_styles} <- generate_chart_css(config, context),
         {:ok, required_assets} <- determine_required_assets(config) do
      chart_output = %{
        html: html_container,
        javascript: javascript_code,
        css: css_styles,
        assets: required_assets,
        metadata: build_chart_metadata(chart_result, config, context)
      }

      {:ok, chart_output}
    else
      {:error, reason} -> {:error, "Chart integration failed: #{reason}"}
    end
  end

  @doc """
  Render an interactive chart with client-side event handling.

  ## Examples

      config = %ChartConfig{
        type: :bar,
        interactive: true,
        interactions: [:hover, :click, :drill_down]
      }
      
      chart = ChartIntegrator.render_interactive_chart(config, context)

  """
  @spec render_interactive_chart(ChartConfig.t(), RenderContext.t()) ::
          {:ok, chart_output()} | {:error, String.t()}
  def render_interactive_chart(
        %ChartConfig{interactive: true} = config,
        %RenderContext{} = context
      ) do
    with {:ok, base_chart} <- render_chart(config, context),
         {:ok, interactive_js} <- generate_interactive_javascript(config, context),
         {:ok, event_handlers} <- generate_event_handlers(config, context) do
      enhanced_chart = %{
        base_chart
        | javascript: combine_javascript([base_chart.javascript, interactive_js, event_handlers]),
          assets: base_chart.assets ++ get_interactive_assets(),
          metadata: Map.put(base_chart.metadata, :interactive, true)
      }

      {:ok, enhanced_chart}
    else
      {:error, reason} -> {:error, "Interactive chart integration failed: #{reason}"}
    end
  end

  @doc """
  Render a dashboard with multiple charts and shared interactivity.

  ## Examples

      charts = %{
        sales_trend: %ChartConfig{type: :line, data: trend_data},
        region_breakdown: %ChartConfig{type: :pie, data: region_data},
        performance: %ChartConfig{type: :bar, data: performance_data}
      }
      
      dashboard = ChartIntegrator.render_chart_dashboard(charts, context)

  """
  @spec render_chart_dashboard(map(), RenderContext.t()) ::
          {:ok, chart_output()} | {:error, String.t()}
  def render_chart_dashboard(chart_configs, %RenderContext{} = context)
      when is_map(chart_configs) do
    chart_results =
      chart_configs
      |> Enum.map(fn {chart_id, config} ->
        case render_chart(config, context) do
          {:ok, chart_output} -> {chart_id, {:ok, chart_output}}
          {:error, reason} -> {chart_id, {:error, reason}}
        end
      end)

    errors = chart_results |> Enum.filter(fn {_, result} -> match?({_, {:error, _}}, result) end)

    if length(errors) > 0 do
      error_messages = Enum.map(errors, fn {id, {:error, reason}} -> "#{id}: #{reason}" end)
      {:error, "Dashboard generation failed: #{Enum.join(error_messages, ", ")}"}
    else
      successful_charts =
        chart_results
        |> Enum.map(fn {id, {:ok, chart}} -> {id, chart} end)
        |> Map.new()

      dashboard_output = combine_chart_outputs(successful_charts, context)
      {:ok, dashboard_output}
    end
  end

  @doc """
  Integrate a chart with an existing report band.

  Embeds chart generation directly into report band rendering for
  seamless integration with existing report layouts.

  ## Examples

      band_config = %{
        type: :chart_band,
        chart_config: %ChartConfig{type: :line, data: sales_data},
        layout: %{position: :after_detail, width: "100%"}
      }
      
      integrated = ChartIntegrator.integrate_with_band(band_config, context)

  """
  @spec integrate_with_band(map(), RenderContext.t()) :: {:ok, String.t()} | {:error, String.t()}
  def integrate_with_band(band_config, %RenderContext{} = context) do
    chart_config = band_config.chart_config
    layout_config = band_config.layout || %{}

    with {:ok, chart_output} <- render_chart(chart_config, context),
         {:ok, band_html} <- wrap_chart_in_band(chart_output, layout_config, context) do
      {:ok, band_html}
    else
      {:error, reason} -> {:error, "Band chart integration failed: #{reason}"}
    end
  end

  # Private implementation functions

  defp generate_chart_container(chart_result, %ChartConfig{} = config, %RenderContext{} = context) do
    chart_id = chart_result.metadata.chart_id

    container_attrs = %{
      id: "#{chart_id}_container",
      class: build_container_classes(config, context),
      data_chart_id: chart_id,
      data_chart_type: config.type,
      data_locale: context.locale,
      data_rtl: context.text_direction == "rtl"
    }

    accessibility_attrs = build_accessibility_attributes(config, context)
    fallback_content = generate_fallback_content(config, context)

    html = """
    <div #{format_attributes(Map.merge(container_attrs, accessibility_attrs))}>
      <div class="ash-chart-wrapper">
        #{chart_result.html}
      </div>
      <div class="ash-chart-fallback" style="display: none;">
        #{fallback_content}
      </div>
    </div>
    """

    {:ok, html}
  end

  defp generate_chart_javascript(
         chart_result,
         %ChartConfig{} = config,
         %RenderContext{} = context
       ) do
    base_javascript = chart_result.javascript

    # Add chart integration enhancements
    enhanced_javascript = """
    // Chart Integration for #{chart_result.metadata.chart_id}
    (function() {
      #{base_javascript}
      
      // Add integration enhancements
      #{generate_integration_enhancements(config, context)}
      
      // Setup error handling
      #{generate_error_handling(chart_result.metadata.chart_id, context)}
    })();
    """

    {:ok, enhanced_javascript}
  end

  defp generate_chart_css(%ChartConfig{} = config, %RenderContext{} = context) do
    base_css = """
    .ash-chart-container {
      width: 100%;
      height: 400px;
      position: relative;
      #{if context.text_direction == "rtl", do: "direction: rtl;", else: ""}
    }

    .ash-chart-wrapper {
      width: 100%;
      height: 100%;
    }

    .ash-chart-fallback {
      padding: 20px;
      text-align: center;
      background-color: #f5f5f5;
      border: 1px solid #ddd;
      border-radius: 4px;
    }

    #{generate_responsive_css(config, context)}
    #{generate_rtl_css(config, context)}
    """

    {:ok, base_css}
  end

  defp determine_required_assets(%ChartConfig{provider: provider}) do
    base_assets = AssetManager.get_provider_assets(provider)
    interactive_assets = ["ash_reports_interactive.js", "ash_reports_charts.css"]

    {:ok, base_assets ++ interactive_assets}
  end

  defp build_chart_metadata(chart_result, %ChartConfig{} = config, %RenderContext{} = context) do
    %{
      chart_id: chart_result.metadata.chart_id,
      chart_type: config.type,
      provider: config.provider,
      interactive: config.interactive,
      real_time: config.real_time,
      locale: context.locale,
      rtl_enabled: context.text_direction == "rtl",
      generated_at: DateTime.utc_now(),
      render_context: %{
        renderer: :html,
        format: :interactive_html
      }
    }
  end

  defp build_container_classes(%ChartConfig{} = config, %RenderContext{} = context) do
    base_classes = ["ash-chart-container", "ash-chart-#{config.type}"]

    locale_classes =
      case context.locale do
        locale when locale in ["ar", "he", "fa", "ur"] -> ["ash-chart-rtl"]
        _ -> ["ash-chart-ltr"]
      end

    interactive_classes =
      if config.interactive do
        ["ash-chart-interactive"]
      else
        ["ash-chart-static"]
      end

    provider_classes = ["ash-chart-provider-#{config.provider}"]

    (base_classes ++ locale_classes ++ interactive_classes ++ provider_classes)
    |> Enum.join(" ")
  end

  defp build_accessibility_attributes(%ChartConfig{} = config, %RenderContext{} = context) do
    title = config.title || "Chart"
    description = generate_chart_description(config, context)

    %{
      role: "img",
      "aria-label": title,
      "aria-describedby": "#{config.title || "chart"}_description",
      tabindex: if(config.interactive, do: "0", else: "-1")
    }
  end

  defp generate_fallback_content(%ChartConfig{} = config, %RenderContext{} = context) do
    chart_type_text = get_localized_chart_type_text(context.locale)
    fallback_message = get_localized_fallback_message(context.locale)

    """
    <div class="chart-description" id="#{config.title || "chart"}_description">
      <h4>#{config.title || "Data Visualization"}</h4>
      <p>#{chart_type_text} - #{config.type}</p>
      <p><em>#{fallback_message}</em></p>
    </div>
    """
  end

  defp get_localized_chart_type_text(locale) do
    case locale do
      "ar" -> "رسم بياني"
      "es" -> "gráfico"
      "fr" -> "graphique"
      _ -> "chart"
    end
  end

  defp get_localized_fallback_message(locale) do
    case locale do
      "ar" -> "المتصفح لا يدعم الرسوم البيانية التفاعلية"
      "es" -> "El navegador no soporta gráficos interactivos"
      "fr" -> "Le navigateur ne supporte pas les graphiques interactifs"
      _ -> "This browser does not support interactive charts"
    end
  end

  defp generate_chart_description(%ChartConfig{} = config, %RenderContext{} = context) do
    data_points =
      case config.data do
        data when is_list(data) -> length(data)
        data when is_map(data) -> data |> Map.values() |> List.flatten() |> length()
        _ -> 0
      end

    case context.locale do
      "ar" -> "#{config.type} رسم بياني يحتوي على #{data_points} نقطة بيانات"
      "es" -> "Gráfico #{config.type} con #{data_points} puntos de datos"
      "fr" -> "Graphique #{config.type} avec #{data_points} points de données"
      _ -> "#{String.capitalize(to_string(config.type))} chart with #{data_points} data points"
    end
  end

  defp generate_integration_enhancements(%ChartConfig{} = config, %RenderContext{} = context) do
    """
    // Chart integration enhancements
    if (window.ashReportsCharts) {
      window.ashReportsCharts.register('#{config.title || "chart"}', {
        type: '#{config.type}',
        locale: '#{context.locale}',
        rtl: #{context.text_direction == "rtl"},
        interactive: #{config.interactive}
      });
    }

    // Add resize handling
    window.addEventListener('resize', function() {
      if (chart && chart.resize) {
        chart.resize();
      }
    });
    """
  end

  defp generate_error_handling(chart_id, %RenderContext{} = context) do
    error_message =
      case context.locale do
        "ar" -> "فشل في تحميل الرسم البياني"
        "es" -> "Error al cargar el gráfico"
        "fr" -> "Erreur lors du chargement du graphique"
        _ -> "Chart loading failed"
      end

    """
    // Error handling for #{chart_id}
    window.addEventListener('error', function(event) {
      if (event.target && event.target.id === '#{chart_id}') {
        console.error('Chart loading failed:', event);
        const fallback = document.querySelector('##{chart_id}_container .ash-chart-fallback');
        const wrapper = document.querySelector('##{chart_id}_container .ash-chart-wrapper');
        
        if (fallback && wrapper) {
          wrapper.style.display = 'none';
          fallback.style.display = 'block';
          fallback.innerHTML = '<p class="error">#{error_message}</p>';
        }
      }
    });
    """
  end

  defp generate_responsive_css(%ChartConfig{} = _config, %RenderContext{} = _context) do
    """
    /* Responsive chart styles */
    @media (max-width: 768px) {
      .ash-chart-container {
        height: 300px;
      }
      
      .ash-chart-wrapper canvas {
        max-width: 100%;
        height: auto !important;
      }
    }

    @media (max-width: 480px) {
      .ash-chart-container {
        height: 250px;
      }
    }
    """
  end

  defp generate_rtl_css(%ChartConfig{} = _config, %RenderContext{text_direction: "rtl"}) do
    """
    /* RTL-specific chart styles */
    .ash-chart-rtl .ash-chart-container {
      direction: rtl;
    }

    .ash-chart-rtl .chart-legend {
      text-align: right;
    }

    .ash-chart-rtl .chart-controls {
      float: right;
      margin-left: 0;
      margin-right: 10px;
    }
    """
  end

  defp generate_rtl_css(_, _), do: ""

  defp generate_interactive_javascript(%ChartConfig{} = config, %RenderContext{} = context) do
    interactions = config.interactions || []

    javascript_parts =
      interactions
      |> Enum.map(fn interaction ->
        case interaction do
          :hover -> generate_hover_handlers(config, context)
          :click -> generate_click_handlers(config, context)
          :drill_down -> generate_drill_down_handlers(config, context)
          :filter -> generate_filter_handlers(config, context)
          :zoom -> generate_zoom_handlers(config, context)
          _ -> ""
        end
      end)
      |> Enum.filter(&(String.length(&1) > 0))

    {:ok, Enum.join(javascript_parts, "\n\n")}
  end

  defp generate_event_handlers(%ChartConfig{} = config, %RenderContext{} = context) do
    base_handlers = """
    // Base event handlers
    document.addEventListener('DOMContentLoaded', function() {
      #{generate_initialization_handler(config, context)}
    });

    // Cleanup handlers
    window.addEventListener('beforeunload', function() {
      #{generate_cleanup_handler(config, context)}
    });
    """

    {:ok, base_handlers}
  end

  defp combine_javascript(javascript_parts) do
    javascript_parts
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.join("\n\n")
  end

  defp get_interactive_assets do
    [
      "ash_reports_interactive.js",
      "ash_reports_charts.css",
      "ash_reports_accessibility.js"
    ]
  end

  defp combine_chart_outputs(chart_outputs, %RenderContext{} = context) do
    html_parts = chart_outputs |> Enum.map(fn {_, chart} -> chart.html end)
    javascript_parts = chart_outputs |> Enum.map(fn {_, chart} -> chart.javascript end)
    css_parts = chart_outputs |> Enum.map(fn {_, chart} -> chart.css end)

    all_assets =
      chart_outputs
      |> Enum.flat_map(fn {_, chart} -> chart.assets end)
      |> Enum.uniq()

    combined_metadata = %{
      dashboard: true,
      chart_count: map_size(chart_outputs),
      chart_ids:
        Enum.map(chart_outputs, fn {id, chart} -> {id, chart.metadata.chart_id} end) |> Map.new(),
      generated_at: DateTime.utc_now(),
      locale: context.locale
    }

    %{
      html: """
      <div class="ash-dashboard #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}">
        #{Enum.join(html_parts, "\n")}
      </div>
      """,
      javascript: combine_javascript(javascript_parts),
      css: Enum.join(css_parts, "\n"),
      assets: all_assets,
      metadata: combined_metadata
    }
  end

  defp wrap_chart_in_band(chart_output, layout_config, %RenderContext{} = context) do
    position_class =
      case layout_config.position do
        :before_detail -> "chart-before-detail"
        :after_detail -> "chart-after-detail"
        :floating -> "chart-floating"
        _ -> "chart-inline"
      end

    width_style =
      case layout_config.width do
        width when is_binary(width) -> "width: #{width};"
        width when is_number(width) -> "width: #{width}px;"
        _ -> "width: 100%;"
      end

    band_html = """
    <div class="ash-band ash-band-chart #{position_class}" style="#{width_style}">
      #{chart_output.html}
    </div>
    """

    {:ok, band_html}
  end

  defp format_attributes(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      attr_name = key |> to_string() |> String.replace("_", "-")
      "#{attr_name}=\"#{escape_html_attribute(value)}\""
    end)
    |> Enum.join(" ")
  end

  defp escape_html_attribute(value) when is_boolean(value), do: to_string(value)
  defp escape_html_attribute(value) when is_atom(value), do: to_string(value)

  defp escape_html_attribute(value) do
    value
    |> to_string()
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  # Interactive JavaScript Generators

  defp generate_hover_handlers(_config, _context) do
    """
    // Hover interaction handlers
    chart.options.onHover = function(event, elements) {
      if (elements.length > 0) {
        event.native.target.style.cursor = 'pointer';
      } else {
        event.native.target.style.cursor = 'default';
      }
    };
    """
  end

  defp generate_click_handlers(_config, _context) do
    """
    // Click interaction handlers
    chart.options.onClick = function(event, elements) {
      if (elements.length > 0) {
        const element = elements[0];
        const dataIndex = element.index;
        const datasetIndex = element.datasetIndex;
        const value = chart.data.datasets[datasetIndex].data[dataIndex];
        
        // Trigger custom event for chart click
        const customEvent = new CustomEvent('ashChartClick', {
          detail: { dataIndex, datasetIndex, value, chart: chart }
        });
        document.dispatchEvent(customEvent);
      }
    };
    """
  end

  defp generate_drill_down_handlers(_config, _context) do
    """
    // Drill-down interaction handlers
    chart.options.plugins = chart.options.plugins || {};
    chart.options.plugins.tooltip = {
      ...chart.options.plugins.tooltip,
      callbacks: {
        afterLabel: function(context) {
          return 'Click to drill down';
        }
      }
    };
    """
  end

  defp generate_filter_handlers(_config, _context) do
    """
    // Filter interaction handlers
    window.ashReportsFilters = window.ashReportsFilters || {};
    window.ashReportsFilters.applyToChart = function(chartInstance, filters) {
      // Apply filters to chart data
      const originalData = chartInstance.data.datasets[0].originalData || chartInstance.data.datasets[0].data;
      const filteredData = originalData.filter(function(item, index) {
        return Object.keys(filters).every(function(key) {
          return item[key] === filters[key];
        });
      });
      
      chartInstance.data.datasets[0].data = filteredData;
      chartInstance.update();
    };
    """
  end

  defp generate_zoom_handlers(_config, _context) do
    """
    // Zoom interaction handlers
    chart.options.scales = chart.options.scales || {};
    chart.options.scales.x = {
      ...chart.options.scales.x,
      type: 'linear',
      position: 'bottom'
    };

    chart.options.plugins = chart.options.plugins || {};
    chart.options.plugins.zoom = {
      pan: { enabled: true, mode: 'x' },
      zoom: { enabled: true, mode: 'x' }
    };
    """
  end

  defp generate_initialization_handler(%ChartConfig{} = config, %RenderContext{} = _context) do
    """
    // Initialize chart #{config.title || "chart"}
    if (typeof window.ashReportsCharts === 'undefined') {
      window.ashReportsCharts = {
        instances: {},
        register: function(name, chartConfig) {
          this.instances[name] = chartConfig;
        }
      };
    }
    """
  end

  defp generate_cleanup_handler(%ChartConfig{} = config, %RenderContext{} = _context) do
    """
    // Cleanup chart #{config.title || "chart"}
    if (window.ashReportsCharts && window.ashReportsCharts.instances['#{config.title || "chart"}']) {
      delete window.ashReportsCharts.instances['#{config.title || "chart"}'];
    }
    """
  end
end
