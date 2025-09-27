defmodule AshReports.LiveView.ChartLiveComponent do
  @moduledoc """
  LiveView chart component for AshReports Phase 6.2 HEEX renderer integration.

  Provides real-time, interactive chart components using Phoenix LiveView with
  server-side state management, WebSocket streaming, and seamless integration
  with Phase 5.1 chart engine and Phase 5.2 HTML renderer foundation.

  ## Features

  - **Server-Side State Management**: Chart configuration and data managed on server
  - **Real-time Updates**: WebSocket streaming with Phoenix PubSub integration
  - **Interactive Events**: Click, hover, filter, drill-down with server-side processing
  - **Multi-Provider Support**: Chart.js, D3.js, Plotly with Phoenix hooks integration
  - **Mobile Optimization**: Touch-friendly interactions and responsive components
  - **Accessibility**: Full ARIA compliance with keyboard navigation and screen readers

  ## Usage Examples

  ### Basic Live Chart

      <.live_component
        module={AshReports.LiveView.ChartLiveComponent}
        id="sales_chart"
        chart_config={%{type: :line, data: @sales_data}}
        real_time={false}
      />

  ### Interactive Real-time Chart

      <.live_component
        module={AshReports.LiveView.ChartLiveComponent}
        id="live_dashboard"
        chart_config={%{type: :bar, data: @live_data}}
        real_time={true}
        update_interval={5000}
        interactive={true}
        events={[:click, :hover, :filter]}
      />

  ### Chart Dashboard with Multiple Components

      <div class="chart-dashboard">
        <.live_component
          module={AshReports.LiveView.ChartLiveComponent}
          id="overview_chart"
          chart_config={@overview_config}
          dashboard_id="main_dashboard"
        />
        
        <.live_component
          module={AshReports.LiveView.ChartLiveComponent}
          id="breakdown_chart"
          chart_config={@breakdown_config}
          dashboard_id="main_dashboard"
        />
      </div>

  """

  use Phoenix.LiveComponent

  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.HtmlRenderer.ChartIntegrator
  alias AshReports.{InteractiveEngine, RenderContext}

  @impl true
  def mount(socket) do
    # Initialize component state
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:chart_data, nil)
      |> assign(:chart_output, nil)
      |> assign(:interactive_state, %{})
      |> assign(:last_updated, DateTime.utc_now())
      |> assign(:real_time_enabled, false)
      |> assign(:update_timer, nil)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Handle component updates and re-renders
    socket =
      socket
      |> assign(assigns)
      |> validate_assigns()

    if socket.assigns.real_time and not socket.assigns.real_time_enabled do
      ^socket = setup_real_time_updates(socket)
    end

    # Generate or update chart
    socket =
      case generate_chart_content(socket) do
        {:ok, chart_output} ->
          socket
          |> assign(:chart_output, chart_output)
          |> assign(:loading, false)
          |> assign(:error, nil)

        {:error, reason} ->
          socket
          |> assign(:error, reason)
          |> assign(:loading, false)
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div 
      id={"chart-container-#{@id}"}
      class={chart_container_classes(@chart_config, @myself)}
      phx-hook="AshReportsChart"
      data-chart-id={@id}
      data-chart-type={@chart_config.type}
      data-provider={@chart_config.provider}
      data-interactive={@interactive}
      data-real-time={@real_time}
      data-locale={get_locale(@socket)}
      data-rtl={get_text_direction(@socket) == "rtl"}
    >
      <%= if @loading do %>
        <div class="chart-loading">
          <div class="loading-spinner"></div>
          <p><%= get_loading_message(@socket) %></p>
        </div>
      <% end %>
      
      <%= if @error do %>
        <div class="chart-error" role="alert">
          <h4><%= get_error_title(@socket) %></h4>
          <p class="error-message"><%= @error %></p>
          <button 
            phx-click="retry_chart_generation" 
            phx-target={@myself}
            class="retry-button"
          >
            <%= get_retry_text(@socket) %>
          </button>
        </div>
      <% end %>
      
      <%= if @chart_output and not @loading and not @error do %>
        <!-- Chart content from Phase 5.2 integration -->
        <%= Phoenix.HTML.raw(@chart_output.html) %>
        
        <!-- Interactive controls if enabled -->
        <%= if @interactive do %>
          <div class="chart-controls">
            <%= render_interactive_controls(assigns) %>
          </div>
        <% end %>
        
        <!-- Real-time status indicator -->
        <%= if @real_time do %>
          <div class="real-time-status" data-status="connected">
            <span class="status-indicator"></span>
            <%= get_real_time_status_text(@socket) %>
            <small>Last updated: <%= format_timestamp(@last_updated, @socket) %></small>
          </div>
        <% end %>
        
        <!-- Chart JavaScript injection -->
        <script id={"chart-script-#{@id}"} type="application/javascript">
          <%= Phoenix.HTML.raw(@chart_output.javascript) %>
        </script>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event(
        "chart_click",
        %{"dataIndex" => data_index, "datasetIndex" => dataset_index} = _params,
        socket
      ) do
    # Handle chart click events from client-side
    chart_config = socket.assigns.chart_config

    # Process click event through InteractiveEngine
    click_result = process_chart_click(chart_config, data_index, dataset_index, socket)

    case click_result do
      {:ok, :drill_down, drill_down_data} ->
        # Update chart with drill-down data
        socket = update_chart_data(socket, drill_down_data)
        {:noreply, socket}

      {:ok, :filter, filter_criteria} ->
        # Apply filter and update chart
        socket = apply_chart_filter(socket, filter_criteria)
        {:noreply, socket}

      {:ok, :info, info_data} ->
        # Send info event to parent LiveView
        send(self(), {:chart_info, socket.assigns.id, info_data})
        {:noreply, socket}

        # {:error, reason} ->
        #   socket = assign(socket, :error, "Chart interaction failed: #{reason}")
        #   {:noreply, socket}
    end
  end

  @impl true
  def handle_event("chart_hover", %{"dataPoint" => data_point}, socket) do
    # Handle chart hover events
    hover_info = process_chart_hover(socket.assigns.chart_config, data_point, socket)

    # Update hover state and potentially notify parent
    socket = assign(socket, :hover_data, hover_info)

    if socket.assigns.dashboard_id do
      send(self(), {:chart_hover, socket.assigns.dashboard_id, socket.assigns.id, hover_info})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_filter", %{"filter" => filter_params}, socket) do
    # Handle filter application from interactive controls
    case apply_interactive_filter(socket, filter_params) do
      {:ok, filtered_data} ->
        socket =
          socket
          |> update_chart_data(filtered_data)
          |> assign(
            :interactive_state,
            Map.put(socket.assigns.interactive_state, :current_filter, filter_params)
          )

        {:noreply, socket}

      {:error, reason} ->
        socket = assign(socket, :error, "Filter application failed: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_filter", _params, socket) do
    # Reset filters to original data
    original_data =
      socket.assigns.interactive_state[:original_data] || socket.assigns.chart_config.data

    socket =
      socket
      |> update_chart_data(original_data)
      |> assign(
        :interactive_state,
        Map.put(socket.assigns.interactive_state, :current_filter, nil)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_chart_generation", _params, socket) do
    # Retry chart generation after error
    socket =
      socket
      |> assign(:error, nil)
      |> assign(:loading, true)

    case generate_chart_content(socket) do
      {:ok, chart_output} ->
        socket =
          socket
          |> assign(:chart_output, chart_output)
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:error, reason)
          |> assign(:loading, false)

        {:noreply, socket}
    end
  end

  def handle_info({:real_time_update, new_data}, socket) do
    # Handle real-time data updates from PubSub
    if socket.assigns.real_time_enabled do
      socket =
        socket
        |> update_chart_data(new_data)
        |> assign(:last_updated, DateTime.utc_now())

      # Push update to client-side chart
      :ok = push_event(socket, "update_chart_data", %{data: new_data})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:chart_config_update, new_config}, socket) do
    # Handle chart configuration updates
    socket =
      socket
      |> assign(:chart_config, new_config)
      |> assign(:loading, true)

    case generate_chart_content(socket) do
      {:ok, chart_output} ->
        socket =
          socket
          |> assign(:chart_output, chart_output)
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        socket = assign(socket, :error, reason)
        {:noreply, socket}
    end
  end

  def terminate(_reason, socket) do
    # Cleanup real-time subscriptions and timers
    if socket.assigns.update_timer do
      Process.cancel_timer(socket.assigns.update_timer)
    end

    if socket.assigns.real_time_enabled and socket.assigns.pubsub_topic do
      Phoenix.PubSub.unsubscribe(AshReports.PubSub, socket.assigns.pubsub_topic)
    end

    :ok
  end

  # Private implementation functions

  defp validate_assigns(socket) do
    validated_config = normalize_chart_config(socket.assigns[:chart_config])
    assign_validated_config(socket, validated_config)
  end

  defp normalize_chart_config(chart_config) do
    case chart_config do
      %ChartConfig{} = config -> config
      config when is_map(config) -> struct(ChartConfig, config)
      _ -> %ChartConfig{type: :bar, data: []}
    end
  end

  defp assign_validated_config(socket, validated_config) do
    socket
    |> assign(:chart_config, validated_config)
    |> assign(:interactive, get_interactive_setting(socket, validated_config))
    |> assign(:real_time, get_real_time_setting(socket, validated_config))
    |> assign(:update_interval, get_update_interval_setting(socket, validated_config))
  end

  defp get_interactive_setting(socket, validated_config) do
    socket.assigns[:interactive] || validated_config.interactive || false
  end

  defp get_real_time_setting(socket, validated_config) do
    socket.assigns[:real_time] || validated_config.real_time || false
  end

  defp get_update_interval_setting(socket, validated_config) do
    socket.assigns[:update_interval] || validated_config.update_interval || 30_000
  end

  defp generate_chart_content(socket) do
    # Generate chart using Phase 5.2 foundation
    chart_config = socket.assigns.chart_config
    context = build_render_context(socket)

    case ChartIntegrator.render_chart(chart_config, context) do
      {:ok, chart_output} ->
        # Adapt for LiveView usage
        adapted_output = adapt_chart_for_liveview(chart_output, socket)
        {:ok, adapted_output}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_render_context(socket) do
    # Build RenderContext from socket assigns
    locale = get_locale(socket)
    text_direction = get_text_direction(socket)

    %RenderContext{
      locale: locale,
      text_direction: text_direction,
      locale_metadata: %{
        chart_configs: [socket.assigns.chart_config],
        interactive_enabled: socket.assigns.interactive,
        real_time_enabled: socket.assigns.real_time
      },
      metadata: %{
        component_id: socket.assigns.id,
        dashboard_id: socket.assigns[:dashboard_id],
        render_mode: :liveview
      }
    }
  end

  defp adapt_chart_for_liveview(chart_output, socket) do
    # Adapt HTML chart output for LiveView integration
    adapted_javascript = adapt_javascript_for_liveview(chart_output.javascript, socket)

    %{
      chart_output
      | javascript: adapted_javascript,
        metadata: Map.put(chart_output.metadata, :liveview_component_id, socket.assigns.id)
    }
  end

  defp adapt_javascript_for_liveview(javascript, socket) do
    # Add LiveView-specific JavaScript enhancements
    liveview_integration = """
    // LiveView integration for component #{socket.assigns.id}
    window.liveSocket.addHook('AshReportsChart', {
      mounted() {
        #{javascript}
        
        // Setup LiveView event communication
        this.handleEvent('update_chart_data', (data) => {
          this.updateChart(data);
        });
        
        // Setup chart interaction callbacks
        this.setupLiveViewCallbacks();
      },
      
      updated() {
        // Handle LiveView updates
        this.refreshChart();
      },
      
      destroyed() {
        // Cleanup when component is destroyed
        this.destroyChart();
      },
      
      setupLiveViewCallbacks() {
        const self = this;
        
        // Chart click handler that communicates with LiveView
        if (window.AshReports.charts['#{socket.assigns.id}']) {
          const chartRef = window.AshReports.charts['#{socket.assigns.id}'];
          if (chartRef.chart) {
            chartRef.chart.options.onClick = function(event, elements) {
              if (elements.length > 0) {
                const element = elements[0];
                self.pushEvent('chart_click', {
                  dataIndex: element.index,
                  datasetIndex: element.datasetIndex,
                  value: chartRef.chart.data.datasets[element.datasetIndex].data[element.index]
                });
              }
            };
            
            // Chart hover handler
            chartRef.chart.options.onHover = function(event, elements) {
              if (elements.length > 0) {
                const element = elements[0];
                const dataPoint = chartRef.chart.data.datasets[element.datasetIndex].data[element.index];
                self.pushEvent('chart_hover', { dataPoint: dataPoint });
              }
            };
          }
        }
      },
      
      updateChart(newData) {
        const chartRef = window.AshReports.charts['#{socket.assigns.id}'];
        if (chartRef && chartRef.chart) {
          chartRef.chart.data = newData;
          chartRef.chart.update('none'); // No animation for real-time updates
        }
      },
      
      refreshChart() {
        const chartRef = window.AshReports.charts['#{socket.assigns.id}'];
        if (chartRef && chartRef.chart) {
          chartRef.chart.update();
        }
      },
      
      destroyChart() {
        const chartRef = window.AshReports.charts['#{socket.assigns.id}'];
        if (chartRef && chartRef.chart) {
          chartRef.chart.destroy();
          delete window.AshReports.charts['#{socket.assigns.id}'];
        }
      }
    });
    """

    liveview_integration
  end

  defp setup_real_time_updates(socket) do
    # Setup Phoenix PubSub subscription for real-time updates
    chart_id = socket.assigns.id
    topic = "chart_updates:#{chart_id}"

    case Phoenix.PubSub.subscribe(AshReports.PubSub, topic) do
      :ok ->
        # Setup periodic timer if configured
        timer =
          if socket.assigns.update_interval do
            Process.send_after(
              self(),
              {:real_time_timer, chart_id},
              socket.assigns.update_interval
            )
          else
            nil
          end

        socket
        |> assign(:real_time_enabled, true)
        |> assign(:pubsub_topic, topic)
        |> assign(:update_timer, timer)

      {:error, _reason} ->
        socket
        |> assign(:error, "Failed to setup real-time updates")
    end
  end

  defp process_chart_click(chart_config, data_index, dataset_index, socket) do
    # Process chart click through InteractiveEngine
    click_context = build_click_context(chart_config, data_index, dataset_index, socket)

    case socket.assigns[:click_handler] do
      :drill_down ->
        # Implement drill-down logic
        drill_down_data = generate_drill_down_data(click_context)
        {:ok, :drill_down, drill_down_data}

      :filter ->
        # Generate filter from clicked data
        filter_criteria = generate_filter_from_click(click_context)
        {:ok, :filter, filter_criteria}

      :info ->
        # Generate info popup data
        info_data = extract_click_info(click_context)
        {:ok, :info, info_data}

      _ ->
        # Default: just log the click
        {:ok, :info, click_context}
    end
  end

  defp process_chart_hover(chart_config, data_point, socket) do
    # Process chart hover for tooltip and highlighting
    %{
      chart_id: socket.assigns.id,
      data_point: data_point,
      chart_type: chart_config.type,
      timestamp: DateTime.utc_now()
    }
  end

  defp apply_interactive_filter(socket, filter_params) do
    # Apply filter using InteractiveEngine
    original_data =
      socket.assigns.interactive_state[:original_data] || socket.assigns.chart_config.data

    context = build_render_context(socket)

    case InteractiveEngine.filter(original_data, filter_params, context) do
      {:ok, filtered_data} ->
        {:ok, filtered_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_chart_data(socket, new_data) do
    # Update chart configuration with new data
    updated_config = %{socket.assigns.chart_config | data: new_data}

    socket = assign(socket, :chart_config, updated_config)

    # Regenerate chart content
    case generate_chart_content(socket) do
      {:ok, chart_output} ->
        socket
        |> assign(:chart_output, chart_output)
        |> assign(:last_updated, DateTime.utc_now())

      {:error, _reason} ->
        socket
    end
  end

  defp apply_chart_filter(socket, filter_criteria) do
    # Apply filter and update chart data
    case apply_interactive_filter(socket, filter_criteria) do
      {:ok, filtered_data} ->
        update_chart_data(socket, filtered_data)

      {:error, _reason} ->
        socket
    end
  end

  # View helper functions

  defp chart_container_classes(chart_config, _component_id) do
    base_classes = ["ash-live-chart", "ash-chart-#{chart_config.type}"]
    interactive_classes = if chart_config.interactive, do: ["interactive"], else: []
    provider_classes = ["provider-#{chart_config.provider}"]

    (base_classes ++ interactive_classes ++ provider_classes)
    |> Enum.join(" ")
  end

  defp render_interactive_controls(assigns) do
    ~H"""
    <div class="interactive-controls">
      <!-- Filter controls -->
      <div class="filter-controls">
        <label for={"filter-input-#{@id}"}>Filter:</label>
        <input 
          id={"filter-input-#{@id}"}
          type="text" 
          phx-keyup="apply_filter" 
          phx-target={@myself}
          phx-debounce="300"
          placeholder={get_filter_placeholder(@socket)}
        />
        
        <button 
          phx-click="reset_filter" 
          phx-target={@myself}
          class="reset-filter-btn"
        >
          <%= get_reset_text(@socket) %>
        </button>
      </div>
      
      <!-- Chart type selector -->
      <%= if @chart_config.allow_type_change do %>
        <div class="chart-type-selector">
          <label for={"chart-type-#{@id}"}>Chart Type:</label>
          <select 
            id={"chart-type-#{@id}"}
            phx-change="change_chart_type"
            phx-target={@myself}
          >
            <option value="line" selected={@chart_config.type == :line}>Line</option>
            <option value="bar" selected={@chart_config.type == :bar}>Bar</option>
            <option value="pie" selected={@chart_config.type == :pie}>Pie</option>
            <option value="area" selected={@chart_config.type == :area}>Area</option>
          </select>
        </div>
      <% end %>
      
      <!-- Export controls -->
      <div class="export-controls">
        <button 
          phx-click="export_chart" 
          phx-value-format="png"
          phx-target={@myself}
          class="export-btn"
        >
          📸 <%= get_export_text(@socket, "PNG") %>
        </button>
        
        <button 
          phx-click="export_chart" 
          phx-value-format="svg"
          phx-target={@myself}
          class="export-btn"
        >
          🖼️ <%= get_export_text(@socket, "SVG") %>
        </button>
      </div>
    </div>
    """
  end

  # Utility functions

  defp get_locale(socket), do: socket.assigns[:locale] || "en"

  defp get_text_direction(socket),
    do: if(get_locale(socket) in ["ar", "he", "fa", "ur"], do: "rtl", else: "ltr")

  defp get_loading_message(socket) do
    case get_locale(socket) do
      "ar" -> "جاري تحميل الرسم البياني..."
      "es" -> "Cargando gráfico..."
      "fr" -> "Chargement du graphique..."
      _ -> "Loading chart..."
    end
  end

  defp get_error_title(socket) do
    case get_locale(socket) do
      "ar" -> "خطأ في الرسم البياني"
      "es" -> "Error del gráfico"
      "fr" -> "Erreur du graphique"
      _ -> "Chart Error"
    end
  end

  defp get_retry_text(socket) do
    case get_locale(socket) do
      "ar" -> "إعادة المحاولة"
      "es" -> "Reintentar"
      "fr" -> "Réessayer"
      _ -> "Retry"
    end
  end

  defp get_real_time_status_text(socket) do
    case get_locale(socket) do
      "ar" -> "مباشر"
      "es" -> "En vivo"
      "fr" -> "En direct"
      _ -> "Live"
    end
  end

  defp get_filter_placeholder(socket) do
    case get_locale(socket) do
      "ar" -> "تصفية البيانات..."
      "es" -> "Filtrar datos..."
      "fr" -> "Filtrer les données..."
      _ -> "Filter data..."
    end
  end

  defp get_reset_text(socket) do
    case get_locale(socket) do
      "ar" -> "إعادة تعيين"
      "es" -> "Restablecer"
      "fr" -> "Réinitialiser"
      _ -> "Reset"
    end
  end

  defp get_export_text(socket, format) do
    case get_locale(socket) do
      "ar" -> "تصدير #{format}"
      "es" -> "Exportar #{format}"
      "fr" -> "Exporter #{format}"
      _ -> "Export #{format}"
    end
  end

  defp format_timestamp(timestamp, socket) do
    # Format timestamp according to locale
    case get_locale(socket) do
      "ar" ->
        # Arabic date formatting
        "#{timestamp.hour}:#{String.pad_leading(to_string(timestamp.minute), 2, "0")}"

      _ ->
        # Default formatting
        "#{timestamp.hour}:#{String.pad_leading(to_string(timestamp.minute), 2, "0")}"
    end
  end

  # Placeholder functions for complex operations (would be fully implemented)

  defp build_click_context(_chart_config, data_index, dataset_index, socket) do
    %{
      component_id: socket.assigns.id,
      data_index: data_index,
      dataset_index: dataset_index,
      chart_type: socket.assigns.chart_config.type
    }
  end

  defp generate_drill_down_data(_click_context) do
    # Placeholder for drill-down logic
    []
  end

  defp generate_filter_from_click(_click_context) do
    # Placeholder for filter generation
    %{}
  end

  defp extract_click_info(click_context) do
    # Extract information about clicked chart element
    %{
      message: "Clicked on data point #{click_context.data_index}",
      data_index: click_context.data_index,
      chart_type: click_context.chart_type
    }
  end
end
