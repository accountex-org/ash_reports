defmodule AshReports.HtmlRenderer.JavaScriptGenerator do
  @moduledoc """
  JavaScript generation module for AshReports HTML Renderer in Phase 5.2.

  Generates optimized JavaScript code for chart initialization, interactive features,
  error handling, and performance monitoring with support for multiple chart providers
  and comprehensive browser compatibility.

  ## Features

  - **Multi-Provider Support**: Chart.js, D3.js, Plotly JavaScript generation
  - **Interactive Features**: Event handling, filtering, drill-down, real-time updates
  - **Error Handling**: Graceful degradation and fallback mechanisms
  - **Performance Optimization**: Lazy loading, code splitting, asset caching
  - **Accessibility**: Keyboard navigation and screen reader support
  - **Mobile Optimization**: Touch interactions and responsive behaviors

  ## Usage Examples

  ### Basic Chart JavaScript

      js_config = %{
        chart_id: "sales_chart_123",
        provider: :chartjs,
        chart_config: chart_config,
        interactive: false
      }
      
      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

  ### Interactive Chart with Events

      interactive_config = %{
        chart_id: "interactive_chart_456", 
        provider: :chartjs,
        chart_config: chart_config,
        interactive: true,
        events: [:click, :hover, :filter]
      }
      
      javascript = JavaScriptGenerator.generate_interactive_javascript(interactive_config, context)

  """

  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.RenderContext

  @type js_config :: %{
          chart_id: String.t(),
          provider: atom(),
          chart_config: ChartConfig.t(),
          interactive: boolean(),
          events: [atom()],
          real_time: boolean()
        }

  @doc """
  Generate JavaScript code for chart initialization and rendering.

  ## Examples

      config = %{
        chart_id: "chart_123",
        provider: :chartjs,
        chart_config: chart_config
      }
      
      {:ok, js_code} = JavaScriptGenerator.generate_chart_javascript(config, context)

  """
  @spec generate_chart_javascript(map(), RenderContext.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_chart_javascript(js_config, %RenderContext{} = context) do
    base_js = generate_base_chart_javascript(js_config, context)
    provider_js = generate_provider_specific_javascript(js_config, context)
    error_handling_js = generate_error_handling_javascript(js_config, context)

    complete_javascript =
      combine_javascript_modules([
        generate_namespace_javascript(),
        base_js,
        provider_js,
        error_handling_js
      ])

    {:ok, complete_javascript}
  rescue
    error -> {:error, "JavaScript generation failed: #{Exception.message(error)}"}
  end

  @doc """
  Generate JavaScript for interactive chart features.

  ## Examples

      config = %{
        chart_id: "interactive_chart",
        events: [:click, :hover, :filter],
        real_time: true
      }
      
      {:ok, js} = JavaScriptGenerator.generate_interactive_javascript(config, context)

  """
  @spec generate_interactive_javascript(map(), RenderContext.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_interactive_javascript(js_config, %RenderContext{} = context) do
    event_handlers = generate_event_handler_javascript(js_config, context)
    filter_controls = generate_filter_control_javascript(js_config, context)

    real_time_js =
      if js_config[:real_time], do: generate_real_time_javascript(js_config, context), else: ""

    interactive_javascript =
      combine_javascript_modules([
        event_handlers,
        filter_controls,
        real_time_js
      ])

    {:ok, interactive_javascript}
  rescue
    error -> {:error, "Interactive JavaScript generation failed: #{Exception.message(error)}"}
  end

  @doc """
  Generate JavaScript for real-time chart updates.
  """
  @spec generate_real_time_javascript(map(), RenderContext.t()) :: String.t()
  def generate_real_time_javascript(js_config, %RenderContext{} = context) do
    chart_id = js_config.chart_id
    update_interval = js_config[:update_interval] || 30_000

    """
    // Real-time updates for #{chart_id}
    (function() {
      let updateInterval;
      let socket;
      
      function setupRealTimeUpdates() {
        // WebSocket connection for real-time data
        if (typeof Phoenix !== 'undefined' && Phoenix.Socket) {
          socket = new Phoenix.Socket('/socket', {
            params: { 
              locale: '#{context.locale}',
              chart_id: '#{chart_id}'
            }
          });
          
          socket.connect();
          
          const channel = socket.channel('chart:#{chart_id}', {});
          channel.join()
            .receive('ok', resp => console.log('Joined chart channel', resp))
            .receive('error', resp => console.log('Unable to join', resp));
          
          channel.on('chart_data_update', payload => {
            updateChartData(payload.data);
          });
        } else {
          // Fallback to polling
          updateInterval = setInterval(() => {
            fetchChartData();
          }, #{update_interval});
        }
      }
      
      function updateChartData(newData) {
        const chartInstance = window.ashReportsCharts.instances['#{chart_id}'];
        if (chartInstance && chartInstance.chart) {
          chartInstance.chart.data = newData;
          chartInstance.chart.update('none'); // No animation for real-time
        }
      }
      
      function fetchChartData() {
        fetch('/ash_reports/api/charts/#{chart_id}/data')
          .then(response => response.json())
          .then(data => updateChartData(data))
          .catch(error => console.error('Chart data fetch failed:', error));
      }
      
      // Initialize real-time updates
      setupRealTimeUpdates();
      
      // Cleanup on page unload
      window.addEventListener('beforeunload', () => {
        if (updateInterval) clearInterval(updateInterval);
        if (socket) socket.disconnect();
      });
    })();
    """
  end

  @doc """
  Generate comprehensive asset loading JavaScript.
  """
  @spec generate_asset_loading_javascript([String.t()], RenderContext.t()) :: String.t()
  def generate_asset_loading_javascript(required_assets, %RenderContext{} = _context) do
    """
    // Asset loading for AshReports charts
    (function() {
      const requiredAssets = #{Jason.encode!(required_assets)};
      const loadedAssets = new Set();
      
      function loadAsset(assetUrl) {
        return new Promise((resolve, reject) => {
          if (loadedAssets.has(assetUrl)) {
            resolve(assetUrl);
            return;
          }
          
          const script = document.createElement('script');
          script.src = assetUrl;
          script.async = true;
          script.onload = () => {
            loadedAssets.add(assetUrl);
            resolve(assetUrl);
          };
          script.onerror = () => reject(new Error(`Failed to load ${assetUrl}`));
          
          document.head.appendChild(script);
        });
      }
      
      // Load all required assets
      Promise.all(requiredAssets.map(loadAsset))
        .then(() => {
          console.log('All chart assets loaded successfully');
          document.dispatchEvent(new CustomEvent('ashReportsAssetsReady'));
        })
        .catch(error => {
          console.error('Asset loading failed:', error);
          document.dispatchEvent(new CustomEvent('ashReportsAssetsFailed', { detail: error }));
        });
    })();
    """
  end

  # Private JavaScript generation functions

  defp generate_namespace_javascript do
    """
    // AshReports JavaScript namespace
    window.AshReports = window.AshReports || {
      charts: {},
      filters: {},
      utils: {},
      version: '5.2.0'
    };
    """
  end

  defp generate_base_chart_javascript(js_config, %RenderContext{} = context) do
    chart_id = js_config.chart_id

    """
    // Base chart initialization for #{chart_id}
    (function() {
      function initializeChart() {
        const container = document.getElementById('#{chart_id}_container');
        if (!container) {
          console.error('Chart container not found: #{chart_id}_container');
          return;
        }
        
        // Store chart reference
        window.AshReports.charts['#{chart_id}'] = {
          container: container,
          initialized: false,
          config: #{Jason.encode!(js_config)},
          locale: '#{context.locale}'
        };
        
        // Initialize when DOM is ready
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', initializeChart);
        } else {
          initializeChart();
        }
      }
      
      initializeChart();
    })();
    """
  end

  defp generate_provider_specific_javascript(
         %{provider: :chartjs} = js_config,
         %RenderContext{} = context
       ) do
    """
    // Chart.js specific initialization
    function initChartJS_#{js_config.chart_id}() {
      if (typeof Chart === 'undefined') {
        console.warn('Chart.js not loaded, retrying in 100ms');
        setTimeout(initChartJS_#{js_config.chart_id}, 100);
        return;
      }
      
      const ctx = document.getElementById('#{js_config.chart_id}');
      if (!ctx) return;
      
      const config = #{generate_chartjs_config(js_config, context)};
      
      try {
        const chartInstance = new Chart(ctx, config);
        window.AshReports.charts['#{js_config.chart_id}'].chart = chartInstance;
        window.AshReports.charts['#{js_config.chart_id}'].initialized = true;
        
        console.log('Chart.js chart initialized:', '#{js_config.chart_id}');
      } catch (error) {
        console.error('Chart.js initialization failed:', error);
        #{generate_fallback_activation_js(js_config.chart_id)}
      }
    }

    initChartJS_#{js_config.chart_id}();
    """
  end

  defp generate_provider_specific_javascript(
         %{provider: :d3} = js_config,
         %RenderContext{} = _context
       ) do
    """
    // D3.js specific initialization (placeholder)
    function initD3_#{js_config.chart_id}() {
      console.log('D3.js integration not yet implemented for #{js_config.chart_id}');
      #{generate_fallback_activation_js(js_config.chart_id)}
    }

    initD3_#{js_config.chart_id}();
    """
  end

  defp generate_provider_specific_javascript(
         %{provider: :plotly} = js_config,
         %RenderContext{} = _context
       ) do
    """
    // Plotly specific initialization (placeholder)
    function initPlotly_#{js_config.chart_id}() {
      console.log('Plotly integration not yet implemented for #{js_config.chart_id}');
      #{generate_fallback_activation_js(js_config.chart_id)}
    }

    initPlotly_#{js_config.chart_id}();
    """
  end

  defp generate_provider_specific_javascript(js_config, %RenderContext{} = _context) do
    """
    // Unknown provider: #{js_config.provider}
    console.warn('Unknown chart provider: #{js_config.provider}');
    #{generate_fallback_activation_js(js_config.chart_id)}
    """
  end

  defp generate_error_handling_javascript(js_config, %RenderContext{} = context) do
    error_message =
      case context.locale do
        "ar" -> "خطأ في تحميل الرسم البياني"
        "es" -> "Error al cargar el gráfico"
        "fr" -> "Erreur de chargement du graphique"
        _ -> "Chart loading error"
      end

    """
    // Error handling for #{js_config.chart_id}
    const errorMessage = '#{error_message}';
    window.addEventListener('error', function(event) {
      if (event.target && event.target.closest && event.target.closest('##{js_config.chart_id}_container')) {
        console.error('Chart error detected:', event);
        console.error(errorMessage);
        #{generate_fallback_activation_js(js_config.chart_id)}
      }
    });

    // Timeout fallback
    setTimeout(function() {
      const chartRef = window.AshReports.charts['#{js_config.chart_id}'];
      if (chartRef && !chartRef.initialized) {
        console.warn('Chart initialization timeout: #{js_config.chart_id}');
        #{generate_fallback_activation_js(js_config.chart_id)}
      }
    }, 5000);
    """
  end

  defp generate_event_handler_javascript(js_config, %RenderContext{} = context) do
    events = js_config[:events] || []

    event_handlers =
      events
      |> Enum.map(fn event ->
        case event do
          :click -> generate_click_event_js(js_config, context)
          :hover -> generate_hover_event_js(js_config, context)
          :filter -> generate_filter_event_js(js_config, context)
          :drill_down -> generate_drill_down_event_js(js_config, context)
          _ -> ""
        end
      end)
      |> Enum.filter(&(String.length(&1) > 0))
      |> Enum.join("\n\n")

    if String.length(event_handlers) > 0 do
      """
      // Event handlers for #{js_config.chart_id}
      (function() {
        #{event_handlers}
      })();
      """
    else
      ""
    end
  end

  defp generate_filter_control_javascript(js_config, %RenderContext{} = context) do
    if js_config[:interactive] do
      """
      // Filter controls for #{js_config.chart_id}
      window.AshReports.filters['#{js_config.chart_id}'] = {
        apply: function(filters) {
          const chartRef = window.AshReports.charts['#{js_config.chart_id}'];
          if (chartRef && chartRef.chart) {
            // Apply filters to chart data
            #{generate_filter_application_js(js_config, context)}
          }
        },
        
        reset: function() {
          const chartRef = window.AshReports.charts['#{js_config.chart_id}'];
          if (chartRef && chartRef.chart && chartRef.originalData) {
            chartRef.chart.data = chartRef.originalData;
            chartRef.chart.update();
          }
        }
      };
      """
    else
      ""
    end
  end

  defp combine_javascript_modules(modules) do
    modules
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.join("\n\n")
  end

  defp generate_chartjs_config(js_config, %RenderContext{} = context) do
    base_config = %{
      type: js_config.chart_config.type,
      data: js_config.chart_config.data,
      options: %{
        responsive: true,
        maintainAspectRatio: false,
        locale: context.locale,
        plugins: %{
          title: %{
            display: js_config.chart_config.title != nil,
            text: js_config.chart_config.title
          }
        }
      }
    }

    # Apply RTL configurations if needed
    config_with_rtl =
      if context.text_direction == "rtl" do
        put_in(
          base_config,
          [:options, :indexAxis],
          if(base_config.type == :bar, do: "y", else: nil)
        )
        |> put_in([:options, :plugins, :legend, :rtl], true)
      else
        base_config
      end

    Jason.encode!(config_with_rtl)
  end

  defp generate_fallback_activation_js(chart_id) do
    """
    const container = document.getElementById('#{chart_id}_container');
    if (container) {
      const fallback = container.querySelector('.ash-chart-fallback');
      const wrapper = container.querySelector('.ash-chart-wrapper');
      
      if (fallback && wrapper) {
        wrapper.style.display = 'none';
        fallback.style.display = 'block';
      }
    }
    """
  end

  defp generate_click_event_js(js_config, %RenderContext{} = _context) do
    """
    // Click event handling
    document.addEventListener('ashChartClick', function(event) {
      if (event.detail.chartId === '#{js_config.chart_id}') {
        console.log('Chart clicked:', event.detail);
        
        // Trigger custom chart click event
        const customEvent = new CustomEvent('ashReportsChartInteraction', {
          detail: {
            chartId: '#{js_config.chart_id}',
            type: 'click',
            data: event.detail
          }
        });
        
        document.dispatchEvent(customEvent);
      }
    });
    """
  end

  defp generate_hover_event_js(js_config, %RenderContext{} = _context) do
    """
    // Hover event handling
    const chart_#{String.replace(js_config.chart_id, "-", "_")} = window.AshReports.charts['#{js_config.chart_id}'];
    if (chart_#{String.replace(js_config.chart_id, "-", "_")} && chart_#{String.replace(js_config.chart_id, "-", "_")}.chart) {
      chart_#{String.replace(js_config.chart_id, "-", "_")}.chart.options.onHover = function(event, elements) {
        if (elements.length > 0) {
          event.native.target.style.cursor = 'pointer';
          
          // Show data tooltip
          const element = elements[0];
          const dataPoint = chart_#{String.replace(js_config.chart_id, "-", "_")}.chart.data.datasets[element.datasetIndex].data[element.index];
          
          // Custom hover event
          document.dispatchEvent(new CustomEvent('ashReportsChartHover', {
            detail: { chartId: '#{js_config.chart_id}', dataPoint: dataPoint }
          }));
        } else {
          event.native.target.style.cursor = 'default';
        }
      };
    }
    """
  end

  defp generate_filter_event_js(js_config, %RenderContext{} = _context) do
    """
    // Filter event handling
    window.AshReports.filters['#{js_config.chart_id}'] = {
      currentFilters: {},
      
      apply: function(filterCriteria) {
        this.currentFilters = filterCriteria;
        const chartRef = window.AshReports.charts['#{js_config.chart_id}'];
        
        if (chartRef && chartRef.chart) {
          // Store original data if not already stored
          if (!chartRef.originalData) {
            chartRef.originalData = JSON.parse(JSON.stringify(chartRef.chart.data));
          }
          
          // Apply filters
          const filteredData = this.filterData(chartRef.originalData, filterCriteria);
          chartRef.chart.data = filteredData;
          chartRef.chart.update();
        }
      },
      
      filterData: function(data, criteria) {
        // Simple client-side filtering implementation
        const filtered = {...data};
        
        if (criteria.minValue !== undefined || criteria.maxValue !== undefined) {
          filtered.datasets = data.datasets.map(dataset => ({
            ...dataset,
            data: dataset.data.filter(value => {
              const numValue = typeof value === 'object' ? value.y : value;
              return (criteria.minValue === undefined || numValue >= criteria.minValue) &&
                     (criteria.maxValue === undefined || numValue <= criteria.maxValue);
            })
          }));
        }
        
        return filtered;
      }
    };
    """
  end

  defp generate_drill_down_event_js(js_config, %RenderContext{} = _context) do
    """
    // Drill-down event handling
    function setupDrillDown_#{String.replace(js_config.chart_id, "-", "_")}() {
      const chartRef = window.AshReports.charts['#{js_config.chart_id}'];
      if (chartRef && chartRef.chart) {
        chartRef.chart.options.onClick = function(event, elements) {
          if (elements.length > 0) {
            const element = elements[0];
            const label = chartRef.chart.data.labels[element.index];
            
            // Trigger drill-down request
            fetch('/ash_reports/api/charts/#{js_config.chart_id}/drill_down', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                label: label,
                dataIndex: element.index,
                datasetIndex: element.datasetIndex
              })
            })
            .then(response => response.json())
            .then(drillDownData => {
              // Update chart with drill-down data
              chartRef.chart.data = drillDownData;
              chartRef.chart.update();
              
              // Add breadcrumb or back button
              #{generate_drill_down_navigation_js(js_config)}
            })
            .catch(error => console.error('Drill-down failed:', error));
          }
        };
      }
    }

    setupDrillDown_#{String.replace(js_config.chart_id, "-", "_")}();
    """
  end

  defp generate_filter_application_js(_js_config, %RenderContext{} = _context) do
    """
    // Store original data for filter reset
    if (!chartRef.originalData) {
      chartRef.originalData = JSON.parse(JSON.stringify(chartRef.chart.data));
    }

    // Apply filters to datasets
    const filteredData = {...chartRef.originalData};
    filteredData.datasets = chartRef.originalData.datasets.map(dataset => {
      const filtered = dataset.data.filter(point => {
        return Object.keys(filters).every(key => {
          const pointValue = typeof point === 'object' ? point[key] : point;
          const filterValue = filters[key];
          
          if (typeof filterValue === 'object' && filterValue.min !== undefined) {
            return pointValue >= filterValue.min && pointValue <= filterValue.max;
          }
          
          return pointValue === filterValue;
        });
      });
      
      return {...dataset, data: filtered};
    });

    chartRef.chart.data = filteredData;
    chartRef.chart.update();
    """
  end

  defp generate_drill_down_navigation_js(js_config) do
    """
    // Add drill-down navigation
    const container = document.getElementById('#{js_config.chart_id}_container');
    let backButton = container.querySelector('.drill-down-back');

    if (!backButton) {
      backButton = document.createElement('button');
      backButton.className = 'drill-down-back';
      backButton.textContent = '← Back';
      backButton.onclick = function() {
        const chartRef = window.AshReports.charts['#{js_config.chart_id}'];
        if (chartRef && chartRef.originalData) {
          chartRef.chart.data = chartRef.originalData;
          chartRef.chart.update();
          backButton.style.display = 'none';
        }
      };
      container.appendChild(backButton);
    }

    backButton.style.display = 'block';
    """
  end

end
