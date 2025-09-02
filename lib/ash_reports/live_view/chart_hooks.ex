defmodule AshReports.LiveView.ChartHooks do
  @moduledoc """
  Phoenix LiveView hooks for AshReports Phase 6.2 chart integration.

  Provides client-side JavaScript hooks that bridge Chart.js, D3.js, and Plotly
  with Phoenix LiveView components for seamless real-time chart interactions
  and server-side state management.

  ## Features

  - **Multi-Provider Hooks**: Unified interface for Chart.js, D3.js, Plotly
  - **LiveView Integration**: Seamless client-server communication
  - **Real-time Updates**: Efficient chart updates without full re-render
  - **Event Handling**: Chart interactions communicated to LiveView server
  - **Lifecycle Management**: Proper chart creation, updates, and cleanup
  - **Error Recovery**: Automatic retry and fallback mechanisms

  ## Hook Usage in LiveView

      # In your LiveView template
      <div 
        id="my-chart"
        phx-hook="AshReportsChart"
        data-chart-config={Jason.encode!(@chart_config)}
        data-chart-provider="chartjs"
      >
      </div>

  ## JavaScript Integration

  The hooks generate JavaScript that integrates with the LiveView socket:

      // Automatically added to your app.js
      import { AshReportsChartHooks } from "./ash_reports_chart_hooks"
      
      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: AshReportsChartHooks
      })

  """

  @doc """
  Generate JavaScript hooks for Phoenix LiveView chart integration.

  Returns JavaScript code that should be included in the client-side
  application to enable chart-LiveView communication.
  """
  @spec generate_hooks_javascript() :: String.t()
  def generate_hooks_javascript do
    """
    // AshReports Chart Hooks for Phoenix LiveView
    export const AshReportsChartHooks = {
      AshReportsChart: {
        mounted() {
          console.log('AshReports Chart hook mounted:', this.el.id);
          this.initializeChart();
        },
        
        updated() {
          console.log('AshReports Chart hook updated:', this.el.id);
          this.updateChart();
        },
        
        destroyed() {
          console.log('AshReports Chart hook destroyed:', this.el.id);
          this.destroyChart();
        },
        
        // Chart initialization based on provider
        initializeChart() {
          const chartId = this.el.dataset.chartId;
          const provider = this.el.dataset.chartProvider;
          const config = JSON.parse(this.el.dataset.chartConfig || '{}');
          
          this.chartId = chartId;
          this.provider = provider;
          this.config = config;
          
          // Initialize based on provider
          switch(provider) {
            case 'chartjs':
              this.initChartJS();
              break;
            case 'd3':
              this.initD3();
              break;
            case 'plotly':
              this.initPlotly();
              break;
            default:
              console.error('Unknown chart provider:', provider);
              this.showError('Unknown chart provider: ' + provider);
          }
        },
        
        // Chart.js initialization
        initChartJS() {
          if (typeof Chart === 'undefined') {
            console.warn('Chart.js not loaded, retrying...');
            setTimeout(() => this.initChartJS(), 100);
            return;
          }
          
          const canvas = this.el.querySelector('canvas');
          if (!canvas) {
            console.error('Canvas element not found');
            this.showError('Chart canvas not found');
            return;
          }
          
          try {
            const ctx = canvas.getContext('2d');
            this.chart = new Chart(ctx, {
              ...this.config,
              options: {
                ...this.config.options,
                onClick: (event, elements) => {
                  this.handleChartClick(event, elements);
                },
                onHover: (event, elements) => {
                  this.handleChartHover(event, elements);
                }
              }
            });
            
            console.log('Chart.js chart initialized:', this.chartId);
            this.pushEvent('chart_ready', { chartId: this.chartId });
            
          } catch (error) {
            console.error('Chart.js initialization failed:', error);
            this.showError('Chart initialization failed: ' + error.message);
          }
        },
        
        // D3.js initialization (placeholder)
        initD3() {
          console.log('D3.js chart initialization - placeholder');
          this.showError('D3.js integration not yet implemented');
        },
        
        // Plotly initialization (placeholder)  
        initPlotly() {
          console.log('Plotly chart initialization - placeholder');
          this.showError('Plotly integration not yet implemented');
        },
        
        // Chart update handling
        updateChart() {
          if (!this.chart) {
            this.initializeChart();
            return;
          }
          
          // Get updated config from element data
          const newConfig = JSON.parse(this.el.dataset.chartConfig || '{}');
          
          if (this.provider === 'chartjs' && this.chart) {
            // Update Chart.js data
            this.chart.data = newConfig.data || this.chart.data;
            this.chart.options = { ...this.chart.options, ...(newConfig.options || {}) };
            this.chart.update('none'); // No animation for LiveView updates
          }
        },
        
        // Chart cleanup
        destroyChart() {
          if (this.chart) {
            if (this.provider === 'chartjs') {
              this.chart.destroy();
            }
            this.chart = null;
          }
        },
        
        // Event handling
        handleChartClick(event, elements) {
          if (elements.length > 0) {
            const element = elements[0];
            const clickData = {
              dataIndex: element.index,
              datasetIndex: element.datasetIndex,
              chartId: this.chartId
            };
            
            if (this.chart && this.chart.data.datasets[element.datasetIndex]) {
              clickData.value = this.chart.data.datasets[element.datasetIndex].data[element.index];
              clickData.label = this.chart.data.labels[element.index];
            }
            
            console.log('Chart clicked:', clickData);
            this.pushEvent('chart_click', clickData);
          }
        },
        
        handleChartHover(event, elements) {
          if (elements.length > 0) {
            const element = elements[0];
            const hoverData = {
              dataIndex: element.index,
              datasetIndex: element.datasetIndex,
              chartId: this.chartId
            };
            
            if (this.chart && this.chart.data.datasets[element.datasetIndex]) {
              hoverData.value = this.chart.data.datasets[element.datasetIndex].data[element.index];
              hoverData.label = this.chart.data.labels[element.index];
            }
            
            this.pushEvent('chart_hover', hoverData);
          }
        },
        
        // Handle events from LiveView server
        handleEvent(event, payload) {
          switch(event) {
            case 'update_chart_data':
              this.updateChartData(payload);
              break;
            case 'refresh_chart':
              this.updateChart();
              break;
            case 'highlight_data':
              this.highlightChartData(payload);
              break;
            default:
              console.log('Unhandled chart event:', event, payload);
          }
        },
        
        // Update chart data from server
        updateChartData(payload) {
          if (this.chart && payload.data) {
            this.chart.data = payload.data;
            this.chart.update(payload.animation || 'none');
            console.log('Chart data updated via LiveView:', this.chartId);
          }
        },
        
        // Highlight specific data points
        highlightChartData(payload) {
          if (this.chart && payload.dataIndex !== undefined) {
            // Temporarily highlight data point
            const originalColors = [...this.chart.data.datasets[0].backgroundColor];
            this.chart.data.datasets[0].backgroundColor = originalColors.map((color, index) => 
              index === payload.dataIndex ? '#ff6b6b' : color
            );
            this.chart.update();
            
            // Restore original colors after delay
            setTimeout(() => {
              this.chart.data.datasets[0].backgroundColor = originalColors;
              this.chart.update();
            }, 2000);
          }
        },
        
        // Error handling
        showError(message) {
          const errorDiv = document.createElement('div');
          errorDiv.className = 'chart-error';
          errorDiv.innerHTML = `
            <div class="error-content">
              <h4>Chart Error</h4>
              <p>${message}</p>
              <button onclick="location.reload()">Reload Page</button>
            </div>
          `;
          
          // Replace chart content with error message
          this.el.innerHTML = '';
          this.el.appendChild(errorDiv);
          
          // Notify LiveView of error
          this.pushEvent('chart_error', { 
            chartId: this.chartId, 
            error: message 
          });
        }
      }
    };

    // Auto-register hooks if LiveSocket is available
    if (typeof window !== 'undefined' && window.liveSocket) {
      Object.assign(window.liveSocket.hooks || {}, AshReportsChartHooks);
    }
    """
  end

  @doc """
  Generate CSS for LiveView chart components.

  Returns CSS styles specifically designed for LiveView chart components
  with responsive design and RTL support.
  """
  @spec generate_liveview_chart_css() :: String.t()
  def generate_liveview_chart_css do
    """
    /* AshReports LiveView Chart Component Styles */

    .ash-live-chart {
      position: relative;
      width: 100%;
      min-height: 400px;
      background: #fff;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
      overflow: hidden;
    }

    .ash-live-chart.rtl {
      direction: rtl;
    }

    /* Loading states */
    .chart-loading {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 300px;
      color: #666;
    }

    .loading-spinner {
      width: 40px;
      height: 40px;
      border: 4px solid #f3f3f3;
      border-top: 4px solid #3498db;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin-bottom: 16px;
    }

    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    /* Error states */
    .chart-error {
      padding: 20px;
      text-align: center;
      background-color: #fee;
      border: 1px solid #fcc;
      border-radius: 4px;
      margin: 10px;
    }

    .chart-error h4 {
      color: #c33;
      margin: 0 0 10px 0;
    }

    .error-message {
      color: #666;
      margin-bottom: 15px;
    }

    .retry-button {
      background: #3498db;
      color: white;
      border: none;
      padding: 8px 16px;
      border-radius: 4px;
      cursor: pointer;
    }

    .retry-button:hover {
      background: #2980b9;
    }

    /* Interactive controls */
    .interactive-controls {
      padding: 15px;
      background: #f8f9fa;
      border-top: 1px solid #dee2e6;
      display: flex;
      gap: 15px;
      align-items: center;
      flex-wrap: wrap;
    }

    .filter-controls {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .filter-controls input {
      padding: 6px 12px;
      border: 1px solid #ccc;
      border-radius: 4px;
      font-size: 14px;
    }

    .reset-filter-btn, .export-btn {
      padding: 6px 12px;
      background: #fff;
      border: 1px solid #ccc;
      border-radius: 4px;
      cursor: pointer;
      font-size: 14px;
    }

    .reset-filter-btn:hover, .export-btn:hover {
      background: #f8f9fa;
    }

    .chart-type-selector select {
      padding: 6px 12px;
      border: 1px solid #ccc;
      border-radius: 4px;
      background: white;
    }

    /* Real-time status */
    .real-time-status {
      position: absolute;
      top: 10px;
      right: 10px;
      background: rgba(255, 255, 255, 0.9);
      padding: 8px 12px;
      border-radius: 4px;
      font-size: 12px;
      border: 1px solid #ddd;
    }

    .real-time-status.rtl {
      right: auto;
      left: 10px;
    }

    .status-indicator {
      display: inline-block;
      width: 8px;
      height: 8px;
      background: #28a745;
      border-radius: 50%;
      margin-right: 6px;
      animation: pulse 2s infinite;
    }

    .rtl .status-indicator {
      margin-right: 0;
      margin-left: 6px;
    }

    @keyframes pulse {
      0% { opacity: 1; }
      50% { opacity: 0.5; }
      100% { opacity: 1; }
    }

    /* Mobile responsiveness */
    @media (max-width: 768px) {
      .ash-live-chart {
        min-height: 300px;
      }
      
      .interactive-controls {
        flex-direction: column;
        align-items: stretch;
        gap: 10px;
      }
      
      .filter-controls {
        flex-direction: column;
        align-items: stretch;
        gap: 8px;
      }
      
      .real-time-status {
        position: static;
        margin-bottom: 10px;
      }
    }

    @media (max-width: 480px) {
      .ash-live-chart {
        min-height: 250px;
      }
      
      .export-controls {
        display: flex;
        gap: 8px;
      }
      
      .export-btn {
        flex: 1;
        text-align: center;
      }
    }

    /* Accessibility improvements */
    .ash-live-chart:focus-within {
      outline: 2px solid #3498db;
      outline-offset: 2px;
    }

    .chart-loading[aria-live="polite"] {
      /* Screen reader announcements for loading states */
    }

    .chart-error[role="alert"] {
      /* Screen reader announcements for errors */
    }

    /* Dark mode support (if enabled) */
    @media (prefers-color-scheme: dark) {
      .ash-live-chart {
        background: #2c3e50;
        color: #ecf0f1;
      }
      
      .interactive-controls {
        background: #34495e;
        border-color: #4a5d6a;
      }
      
      .filter-controls input, 
      .chart-type-selector select,
      .reset-filter-btn,
      .export-btn {
        background: #2c3e50;
        border-color: #4a5d6a;
        color: #ecf0f1;
      }
    }
    """
  end

  @doc """
  Generate hook registration JavaScript for app.js integration.

  Returns the JavaScript code needed to register AshReports hooks
  with the Phoenix LiveSocket.
  """
  @spec generate_hook_registration() :: String.t()
  def generate_hook_registration do
    """
    // AshReports Chart Hook Registration
    // Add this to your app.js file

    import { AshReportsChartHooks } from "./lib/ash_reports_chart_hooks"

    // Register hooks with LiveSocket
    let Hooks = {}
    Object.assign(Hooks, AshReportsChartHooks)

    // Your existing LiveSocket configuration
    let liveSocket = new LiveSocket("/live", Socket, {
      params: {_csrf_token: csrfToken},
      hooks: Hooks
    })
    """
  end

  @doc """
  Generate provider-specific hook configurations.

  Returns JavaScript configurations for different chart providers
  optimized for LiveView integration.
  """
  @spec generate_provider_configs() :: map()
  def generate_provider_configs do
    %{
      chartjs: %{
        cdn_url: "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js",
        hook_name: "ChartJSHook",
        initialization: """
        if (typeof Chart === 'undefined') {
          this.loadScript('https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js').then(() => this.initChartJS());
        } else {
          this.initChartJS();
        }
        """,
        update_method: "chart.update('none')",
        destroy_method: "chart.destroy()"
      },
      d3: %{
        cdn_url: "https://cdn.jsdelivr.net/npm/d3@7.8.0/dist/d3.min.js",
        hook_name: "D3Hook",
        initialization: """
        if (typeof d3 === 'undefined') {
          this.loadScript('https://cdn.jsdelivr.net/npm/d3@7.8.0/dist/d3.min.js').then(() => this.initD3());
        } else {
          this.initD3();
        }
        """,
        update_method: "d3.select(this.el).datum(newData).call(this.chart)",
        destroy_method: "d3.select(this.el).selectAll('*').remove()"
      },
      plotly: %{
        cdn_url: "https://cdn.plot.ly/plotly-2.26.0.min.js",
        hook_name: "PlotlyHook",
        initialization: """
        if (typeof Plotly === 'undefined') {
          this.loadScript('https://cdn.plot.ly/plotly-2.26.0.min.js').then(() => this.initPlotly());
        } else {
          this.initPlotly();
        }
        """,
        update_method: "Plotly.redraw(this.el)",
        destroy_method: "Plotly.purge(this.el)"
      }
    }
  end

  @doc """
  Generate comprehensive hook system with utilities.

  Returns complete JavaScript hook system with utility functions,
  error handling, and performance optimization.
  """
  @spec generate_complete_hook_system() :: String.t()
  def generate_complete_hook_system do
    """
    // Complete AshReports Chart Hook System for Phoenix LiveView

    const AshReportsChartUtils = {
      // Script loading utility
      loadScript(url) {
        return new Promise((resolve, reject) => {
          if (document.querySelector(`script[src="${url}"]`)) {
            resolve(); // Already loaded
            return;
          }
          
          const script = document.createElement('script');
          script.src = url;
          script.async = true;
          script.onload = resolve;
          script.onerror = () => reject(new Error(`Failed to load ${url}`));
          document.head.appendChild(script);
        });
      },
      
      // Chart data validation
      validateChartData(data) {
        if (!data || (!Array.isArray(data) && typeof data !== 'object')) {
          throw new Error('Invalid chart data format');
        }
        return true;
      },
      
      // Performance monitoring
      performance: {
        startTime: null,
        
        start() {
          this.startTime = performance.now();
        },
        
        end(operation) {
          if (this.startTime) {
            const duration = performance.now() - this.startTime;
            console.log(`AshReports ${operation} took ${duration.toFixed(2)}ms`);
            this.startTime = null;
            return duration;
          }
        }
      },
      
      // Error reporting
      reportError(componentId, operation, error) {
        console.error(`AshReports Chart Error [${componentId}] ${operation}:`, error);
        
        // Could integrate with error reporting service
        if (window.AshReports && window.AshReports.errorReporting) {
          window.AshReports.errorReporting.report({
            component: 'ChartLiveComponent',
            componentId: componentId,
            operation: operation,
            error: error.message || error,
            timestamp: new Date().toISOString()
          });
        }
      }
    };

    #{generate_hooks_javascript()}

    // Extend hooks with utilities
    Object.keys(AshReportsChartHooks).forEach(hookName => {
      const hook = AshReportsChartHooks[hookName];
      
      // Add utility methods to each hook
      hook.loadScript = AshReportsChartUtils.loadScript;
      hook.validateData = AshReportsChartUtils.validateChartData;
      hook.reportError = (operation, error) => 
        AshReportsChartUtils.reportError(hook.chartId || 'unknown', operation, error);
      
      // Add performance monitoring
      const originalMounted = hook.mounted;
      hook.mounted = function() {
        AshReportsChartUtils.performance.start();
        const result = originalMounted.call(this);
        AshReportsChartUtils.performance.end('mount');
        return result;
      };
    });

    // Export for use in app.js
    export { AshReportsChartHooks };
    """
  end
end
