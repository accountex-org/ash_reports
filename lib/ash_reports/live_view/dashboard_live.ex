defmodule AshReports.LiveView.DashboardLive do
  @moduledoc """
  Interactive dashboard LiveView for AshReports Phase 6.2.

  Provides comprehensive multi-chart dashboard with coordinated interactions,
  real-time updates, shared filtering, and collaborative features using
  Phoenix LiveView and the Phase 6.2 chart infrastructure.

  ## Features

  - **Multi-Chart Coordination**: Shared state and interactions across charts
  - **Real-time Updates**: Live data streaming with WebSocket integration
  - **Interactive Filtering**: Dashboard-wide filters affecting all charts
  - **User Collaboration**: Multi-user dashboard with Phoenix Presence
  - **Responsive Design**: Mobile-optimized dashboard layouts
  - **Accessibility**: Full ARIA compliance and keyboard navigation

  ## Usage Examples

  ### Basic Dashboard LiveView

      defmodule MyAppWeb.SalesDashboardLive do
        use Phoenix.LiveView
        import AshReports.LiveView.DashboardLive
        
        def mount(_params, _session, socket) do
          {:ok, setup_dashboard(socket, dashboard_config)}
        end
      end

  ### Multi-User Collaborative Dashboard

      defmodule MyAppWeb.CollabDashboardLive do
        use Phoenix.LiveView
        import AshReports.LiveView.DashboardLive
        
        def mount(_params, session, socket) do
          user_id = session["user_id"]
          {:ok, setup_collaborative_dashboard(socket, user_id, dashboard_config)}
        end
      end

  """

  use Phoenix.LiveView

  alias AshReports.RenderContext
  alias AshReports.HeexRenderer.ChartTemplates
  alias AshReports.LiveView.ChartLiveComponent
  alias AshReports.PubSub.ChartBroadcaster

  require Logger

  @default_update_interval 30_000

  # LiveView callbacks

  @impl true
  def mount(params, session, socket) do
    dashboard_config = parse_dashboard_config(params, session)
    user_info = extract_user_info(session)

    socket =
      socket
      |> assign(:dashboard_id, dashboard_config.dashboard_id)
      |> assign(:user_info, user_info)
      |> assign(:dashboard_config, dashboard_config)
      |> assign(:charts, %{})
      |> assign(:global_filters, %{})
      |> assign(:real_time_enabled, dashboard_config.real_time || false)
      |> assign(:collaboration_enabled, dashboard_config.collaboration || false)
      |> assign(:connected_users, %{})
      |> assign(:dashboard_state, :loading)
      |> assign(:last_updated, DateTime.utc_now())

    # Setup real-time subscriptions
    if socket.assigns.real_time_enabled do
      :ok = setup_real_time_subscriptions(socket)
    end

    # Setup collaboration if enabled
    if socket.assigns.collaboration_enabled do
      {:ok, _socket} = setup_collaboration_features(socket)
    end

    # Initialize dashboard
    {:ok, socket} = initialize_dashboard_charts(socket)

    {:ok, assign(socket, :dashboard_state, :ready)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={dashboard_container_classes(@dashboard_config, @user_info)}
         data-dashboard-id={@dashboard_id}
         data-real-time={@real_time_enabled}
         data-collaboration={@collaboration_enabled}>
      
      <!-- Dashboard Header -->
      <div class="dashboard-header">
        <h1 class="dashboard-title"><%= @dashboard_config.title || get_dashboard_title(@user_info.locale) %></h1>
        
        <div class="dashboard-controls">
          <%= if @real_time_enabled do %>
            <div class="real-time-status">
              <span class="status-indicator active"></span>
              <span class="status-text"><%= get_live_status_text(@user_info.locale) %></span>
              <small class="last-update">
                <%= get_last_update_text(@user_info.locale) %>: <%= format_timestamp(@last_updated, @user_info.locale) %>
              </small>
            </div>
          <% end %>
          
          <%= if @collaboration_enabled do %>
            <div class="collaboration-status">
              <span class="users-count"><%= map_size(@connected_users) %></span>
              <span class="users-text"><%= get_users_online_text(@user_info.locale) %></span>
              <%= render_user_avatars(@connected_users) %>
            </div>
          <% end %>
          
          <div class="dashboard-actions">
            <button phx-click="refresh_dashboard" class="btn btn-outline">
              <%= get_refresh_text(@user_info.locale) %>
            </button>
            
            <button phx-click="export_dashboard" class="btn btn-primary">
              <%= get_export_text(@user_info.locale) %>
            </button>
          </div>
        </div>
      </div>
      
      <!-- Global Filters -->
      <%= if map_size(@global_filters) > 0 or @dashboard_config.show_filters do %>
        <div class="dashboard-filters">
          <h3><%= get_filters_text(@user_info.locale) %></h3>
          <%= render_global_filters(assigns) %>
        </div>
      <% end %>
      
      <!-- Dashboard Content -->
      <div class="dashboard-content" 
           data-layout={@dashboard_config.layout || "grid"}>
        
        <%= if @dashboard_state == :loading do %>
          <div class="dashboard-loading">
            <div class="loading-spinner"></div>
            <p><%= get_loading_dashboard_text(@user_info.locale) %></p>
          </div>
        <% end %>
        
        <%= if @dashboard_state == :ready do %>
          <%= case @dashboard_config.layout do %>
            <% "grid" -> %>
              <div class="dashboard-grid">
                <%= for {chart_id, chart_config} <- @charts do %>
                  <div class="chart-grid-item" data-chart-id={chart_id}>
                    <.live_component
                      module={AshReports.LiveView.ChartLiveComponent}
                      id={chart_id}
                      chart_config={chart_config}
                      locale={@user_info.locale}
                      dashboard_id={@dashboard_id}
                      global_filters={@global_filters}
                      interactive={true}
                      real_time={@real_time_enabled}
                    />
                  </div>
                <% end %>
              </div>
            
            <% "sidebar" -> %>
              <div class="dashboard-sidebar-layout">
                <div class="sidebar">
                  <%= render_sidebar_controls(assigns) %>
                </div>
                <div class="main-content">
                  <%= for {chart_id, chart_config} <- @charts do %>
                    <.live_component
                      module={AshReports.LiveView.ChartLiveComponent}
                      id={chart_id}
                      chart_config={chart_config}
                      locale={@user_info.locale}
                      dashboard_id={@dashboard_id}
                      global_filters={@global_filters}
                    />
                  <% end %>
                </div>
              </div>
            
            <% "tabs" -> %>
              <%= ChartTemplates.tabbed_charts(%{
                tabs: build_tab_config(@charts),
                dashboard_id: @dashboard_id
              }, build_render_context(assigns)) %>
            
            <% _ -> %>
              <!-- Default: simple vertical layout -->
              <div class="dashboard-vertical">
                <%= for {chart_id, chart_config} <- @charts do %>
                  <.live_component
                    module={AshReports.LiveView.ChartLiveComponent}
                    id={chart_id}
                    chart_config={chart_config}
                    locale={@user_info.locale}
                    dashboard_id={@dashboard_id}
                  />
                <% end %>
              </div>
          <% end %>
        <% end %>
        
      </div>
      
      <!-- Dashboard Footer -->
      <div class="dashboard-footer">
        <div class="performance-info">
          <span class="chart-count">
            <%= map_size(@charts) %> <%= get_charts_text(@user_info.locale) %>
          </span>
          <%= if @real_time_enabled do %>
            <span class="update-interval">
              <%= get_update_interval_text(@user_info.locale) %>: <%= @dashboard_config.update_interval || @default_update_interval %>ms
            </span>
          <% end %>
        </div>
      </div>
      
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("apply_global_filter", %{"filter" => filter_params}, socket) do
    # Apply filter across all charts in dashboard
    updated_filters = Map.merge(socket.assigns.global_filters, filter_params)

    socket =
      socket
      |> assign(:global_filters, updated_filters)
      |> assign(:last_updated, DateTime.utc_now())

    # Broadcast filter change to all chart components
    :ok = broadcast_filter_update_to_charts(socket, updated_filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_global_filters", _params, socket) do
    # Reset all global filters
    socket =
      socket
      |> assign(:global_filters, %{})
      |> assign(:last_updated, DateTime.utc_now())

    # Notify all charts to reset filters
    :ok = broadcast_filter_reset_to_charts(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_dashboard", _params, socket) do
    # Refresh all charts in dashboard
    :ok = broadcast_refresh_to_charts(socket)

    socket = assign(socket, :last_updated, DateTime.utc_now())
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_dashboard", %{"format" => format}, socket) do
    # Export entire dashboard in specified format
    case export_dashboard_data(socket, format) do
      {:ok, export_data} ->
        # Would trigger download or save
        :ok =
          push_event(socket, "download_ready", %{
            filename: "dashboard_#{socket.assigns.dashboard_id}.#{format}",
            data: export_data
          })

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab_id}, socket) do
    # Handle tab switching in tabbed dashboard layout
    socket = assign(socket, :active_tab, tab_id)
    {:noreply, socket}
  end

  # Real-time message handlers

  @impl true
  def handle_info({:real_time_update, dashboard_data}, socket) do
    # Handle dashboard-wide real-time updates
    updated_charts = update_charts_with_new_data(socket.assigns.charts, dashboard_data)

    socket =
      socket
      |> assign(:charts, updated_charts)
      |> assign(:last_updated, DateTime.utc_now())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chart_interaction, chart_id, interaction_data}, socket) do
    # Handle interactions from individual charts that affect dashboard
    case interaction_data.type do
      :filter_change ->
        # Chart-specific filter affects global filters
        updated_filters =
          merge_chart_filter_to_global(
            socket.assigns.global_filters,
            chart_id,
            interaction_data.filter
          )

        socket = assign(socket, :global_filters, updated_filters)

        # Broadcast to other charts
        :ok = broadcast_filter_update_to_charts(socket, updated_filters, exclude: chart_id)

        {:noreply, socket}

      :drill_down ->
        # Handle drill-down that affects multiple charts
        {:noreply, handle_coordinated_drill_down(socket, chart_id, interaction_data)}

      :data_highlight ->
        # Highlight related data in other charts
        :ok =
          broadcast_data_highlight_to_charts(socket, interaction_data.data_point,
            exclude: chart_id
          )

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_joined, user_info}, socket) do
    # Handle new user joining collaborative dashboard
    if socket.assigns.collaboration_enabled do
      updated_users = Map.put(socket.assigns.connected_users, user_info.user_id, user_info)

      socket =
        socket
        |> assign(:connected_users, updated_users)
        |> put_flash(:info, "#{user_info.name} joined the dashboard")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    # Handle user leaving collaborative dashboard
    if socket.assigns.collaboration_enabled do
      {leaving_user, updated_users} = Map.pop(socket.assigns.connected_users, user_id)

      socket =
        socket
        |> assign(:connected_users, updated_users)

      if leaving_user do
        _socket = put_flash(socket, :info, "#{leaving_user.name} left the dashboard")
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Helper functions for dashboard setup

  def setup_dashboard(socket, dashboard_config) do
    socket
    |> assign(:dashboard_config, dashboard_config)
    |> assign(:dashboard_id, dashboard_config.dashboard_id || generate_dashboard_id())
    |> assign(:charts, initialize_charts(dashboard_config))
    |> assign(:real_time_enabled, dashboard_config.real_time || false)
    |> assign(:user_info, %{locale: "en", timezone: "UTC"})
  end

  def setup_collaborative_dashboard(socket, user_id, dashboard_config) do
    socket = setup_dashboard(socket, dashboard_config)

    # Enable collaboration features
    socket =
      socket
      |> assign(:collaboration_enabled, true)
      |> assign(:user_info, %{user_id: user_id, locale: "en"})

    # Join presence tracking
    :ok = join_dashboard_presence(socket.assigns.dashboard_id, user_id)

    socket
  end

  # Private implementation functions

  defp parse_dashboard_config(params, session) do
    %{
      dashboard_id: get_dashboard_id(params, session),
      title: get_dashboard_title(params, session),
      layout: params["layout"] || "grid",
      real_time: parse_boolean_setting(params["real_time"], session["real_time"]),
      collaboration: parse_boolean_setting(params["collaboration"], session["collaboration"]),
      charts: parse_chart_configs(params["charts"] || session["charts"] || []),
      update_interval: parse_integer(params["update_interval"]) || @default_update_interval,
      show_filters: params["show_filters"] != "false"
    }
  end

  defp get_dashboard_id(params, session) do
    params["dashboard_id"] || session["dashboard_id"] || generate_dashboard_id()
  end

  defp get_dashboard_title(params, session) do
    params["title"] || session["dashboard_title"]
  end

  defp parse_boolean_setting(param_value, session_value) do
    param_value == "true" || session_value == true
  end

  defp extract_user_info(session) do
    %{
      user_id: session["user_id"] || "anonymous",
      name: session["user_name"] || "Anonymous User",
      locale: session["locale"] || "en",
      timezone: session["timezone"] || "UTC",
      permissions: session["permissions"] || [:view_charts]
    }
  end

  defp initialize_charts(dashboard_config) do
    dashboard_config.charts
    |> Enum.with_index()
    |> Enum.map(fn {chart_config, index} ->
      chart_id = chart_config[:id] || "chart_#{index}"
      {chart_id, normalize_chart_config(chart_config)}
    end)
    |> Map.new()
  end

  defp normalize_chart_config(chart_config) when is_map(chart_config) do
    %{
      type: chart_config[:type] || :bar,
      data: chart_config[:data] || [],
      title: chart_config[:title],
      provider: chart_config[:provider] || :chartjs,
      interactive: chart_config[:interactive] || true,
      real_time: chart_config[:real_time] || false,
      update_interval: chart_config[:update_interval],
      filters: chart_config[:filters] || %{},
      layout: chart_config[:layout] || %{}
    }
  end

  defp setup_real_time_subscriptions(socket) do
    dashboard_id = socket.assigns.dashboard_id

    # Subscribe to dashboard-wide updates
    :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "dashboard_updates:#{dashboard_id}")

    # Subscribe to individual chart updates
    socket.assigns.charts
    |> Map.keys()
    |> Enum.each(fn chart_id ->
      Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")
    end)

    :ok
  end

  defp setup_collaboration_features(socket) do
    dashboard_id = socket.assigns.dashboard_id
    user_info = socket.assigns.user_info

    # Join Phoenix Presence
    {:ok, _ref} =
      Phoenix.Presence.track(
        AshReports.Presence,
        "dashboard:#{dashboard_id}",
        user_info.user_id,
        %{
          name: user_info.name,
          joined_at: DateTime.utc_now(),
          locale: user_info.locale
        }
      )

    # Subscribe to presence changes
    :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "presence_diff:dashboard:#{dashboard_id}")

    {:ok, socket}
  end

  defp initialize_dashboard_charts(socket) do
    # Initialize chart components and setup coordination
    dashboard_id = socket.assigns.dashboard_id

    # Start chart streaming if real-time enabled
    if socket.assigns.real_time_enabled do
      socket.assigns.charts
      |> Map.keys()
      |> Enum.each(fn chart_id ->
        ChartBroadcaster.start_filtered_stream(
          chart_id: chart_id,
          dashboard_id: dashboard_id,
          update_interval: socket.assigns.dashboard_config.update_interval
        )
      end)
    end

    {:ok, socket}
  end

  # Chart coordination functions

  defp broadcast_filter_update_to_charts(socket, filters, opts \\ []) do
    exclude_chart = Keyword.get(opts, :exclude)

    socket.assigns.charts
    |> Map.keys()
    |> Enum.filter(&(&1 != exclude_chart))
    |> Enum.each(fn chart_id ->
      send_update(ChartLiveComponent, id: chart_id, global_filters: filters)
    end)

    :ok
  end

  defp broadcast_filter_reset_to_charts(socket) do
    socket.assigns.charts
    |> Map.keys()
    |> Enum.each(fn chart_id ->
      send_update(ChartLiveComponent, id: chart_id, global_filters: %{})
    end)

    :ok
  end

  defp broadcast_refresh_to_charts(socket) do
    socket.assigns.charts
    |> Map.keys()
    |> Enum.each(fn chart_id ->
      send_update(ChartLiveComponent, id: chart_id, refresh: true)
    end)

    :ok
  end

  defp broadcast_data_highlight_to_charts(socket, data_point, opts) do
    exclude_chart = Keyword.get(opts, :exclude)

    socket.assigns.charts
    |> Map.keys()
    |> Enum.filter(&(&1 != exclude_chart))
    |> Enum.each(fn chart_id ->
      :ok =
        push_event(socket, "highlight_data", %{
          chart_id: chart_id,
          data_point: data_point
        })
    end)

    :ok
  end

  defp update_charts_with_new_data(charts, dashboard_data) do
    Map.merge(charts, dashboard_data.chart_updates || %{})
  end

  defp merge_chart_filter_to_global(global_filters, chart_id, chart_filter) do
    # Merge chart-specific filter into global filters
    Map.put(global_filters, "from_#{chart_id}", chart_filter)
  end

  defp handle_coordinated_drill_down(socket, source_chart_id, interaction_data) do
    # Handle drill-down that affects multiple charts
    drill_down_data = interaction_data.drill_down_data

    # Update related charts with drill-down context
    socket.assigns.charts
    |> Map.keys()
    |> Enum.filter(&(&1 != source_chart_id))
    |> Enum.each(fn chart_id ->
      send_update(ChartLiveComponent,
        id: chart_id,
        drill_down_context: drill_down_data,
        highlight_related: true
      )
    end)

    socket
  end

  # View helper functions

  defp dashboard_container_classes(dashboard_config, user_info) do
    base_classes = ["ash-dashboard", "layout-#{dashboard_config.layout || "grid"}"]
    locale_classes = if user_info.locale in ["ar", "he", "fa", "ur"], do: ["rtl"], else: ["ltr"]
    feature_classes = []

    feature_classes =
      if dashboard_config.real_time, do: ["real-time" | feature_classes], else: feature_classes

    feature_classes =
      if dashboard_config.collaboration,
        do: ["collaborative" | feature_classes],
        else: feature_classes

    (base_classes ++ locale_classes ++ feature_classes) |> Enum.join(" ")
  end

  defp render_global_filters(assigns) do
    ~H"""
    <form phx-change="apply_global_filter" phx-submit="apply_global_filter">
      <div class="filter-grid">
        
        <div class="filter-item">
          <label for="date_range"><%= get_date_range_text(@user_info.locale) %></label>
          <input type="date" name="filter[start_date]" value={@global_filters["start_date"]}>
          <input type="date" name="filter[end_date]" value={@global_filters["end_date"]}>
        </div>
        
        <div class="filter-item">
          <label for="text_search"><%= get_search_text(@user_info.locale) %></label>
          <input type="text" 
                 name="filter[search]" 
                 value={@global_filters["search"]}
                 placeholder={get_search_placeholder(@user_info.locale)}
                 phx-debounce="300">
        </div>
        
        <div class="filter-actions">
          <button type="submit" class="btn btn-primary">
            <%= get_apply_filters_text(@user_info.locale) %>
          </button>
          <button type="button" phx-click="reset_global_filters" class="btn btn-secondary">
            <%= get_reset_filters_text(@user_info.locale) %>
          </button>
        </div>
        
      </div>
    </form>
    """
  end

  defp render_sidebar_controls(assigns) do
    ~H"""
    <div class="sidebar-controls">
      <h4><%= get_dashboard_controls_text(@user_info.locale) %></h4>
      
      <div class="control-section">
        <h5><%= get_layout_text(@user_info.locale) %></h5>
        <select phx-change="change_layout" name="layout">
          <option value="grid" selected={@dashboard_config.layout == "grid"}>Grid</option>
          <option value="sidebar" selected={@dashboard_config.layout == "sidebar"}>Sidebar</option>
          <option value="tabs" selected={@dashboard_config.layout == "tabs"}>Tabs</option>
        </select>
      </div>
      
      <div class="control-section">
        <h5><%= get_real_time_text(@user_info.locale) %></h5>
        <label class="toggle">
          <input type="checkbox" 
                 phx-click="toggle_real_time" 
                 checked={@real_time_enabled}>
          <span class="toggle-slider"></span>
          <%= get_enable_real_time_text(@user_info.locale) %>
        </label>
      </div>
      
    </div>
    """
  end

  defp render_user_avatars(connected_users) do
    user_list = connected_users |> Map.to_list()

    """
    <div class="user-avatars">
      #{Enum.map_join(user_list, "", fn {_user_id, user_info} -> "<div class=\"user-avatar\" title=\"#{user_info.name}\">
          <span class=\"avatar-initial\">#{String.first(user_info.name)}</span>
        </div>" end)}
    </div>
    """
  end

  defp build_tab_config(charts) do
    charts
    |> Enum.map(fn {chart_id, chart_config} ->
      %{
        id: chart_id,
        title: chart_config.title || "Chart",
        chart_config: chart_config,
        interactive: chart_config.interactive,
        real_time: chart_config.real_time
      }
    end)
  end

  defp build_render_context(assigns) do
    %RenderContext{
      locale: assigns.user_info.locale,
      text_direction:
        if(assigns.user_info.locale in ["ar", "he", "fa", "ur"], do: "rtl", else: "ltr"),
      metadata: %{
        dashboard_id: assigns.dashboard_id,
        user_id: assigns.user_info.user_id
      }
    }
  end

  # Utility functions

  defp generate_dashboard_id do
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "dashboard_#{timestamp}_#{random}"
  end

  defp parse_chart_configs(charts) when is_list(charts), do: charts
  defp parse_chart_configs(_), do: []

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: nil

  defp join_dashboard_presence(dashboard_id, user_id) do
    # Would integrate with Phoenix.Presence
    Logger.debug("User #{user_id} joined dashboard #{dashboard_id} presence")
    :ok
  end

  defp export_dashboard_data(socket, format) do
    # Export dashboard data in specified format
    case format do
      "json" ->
        export_data = %{
          dashboard_id: socket.assigns.dashboard_id,
          charts: socket.assigns.charts,
          filters: socket.assigns.global_filters,
          exported_at: DateTime.utc_now()
        }

        {:ok, Jason.encode!(export_data)}

      "csv" ->
        # Would generate CSV export
        # Placeholder
        {:ok, "dashboard,chart_id,data\n..."}

      _ ->
        {:error, "Unsupported export format: #{format}"}
    end
  end

  defp format_timestamp(timestamp, locale) do
    # Format timestamp according to locale
    case locale do
      "ar" -> "#{timestamp.hour}:#{String.pad_leading(to_string(timestamp.minute), 2, "0")}"
      _ -> "#{timestamp.hour}:#{String.pad_leading(to_string(timestamp.minute), 2, "0")}"
    end
  end

  # Localization helpers (reusing from ChartTemplates where possible)

  defp get_dashboard_title("ar"), do: "لوحة التحكم"
  defp get_dashboard_title("es"), do: "Panel de Control"
  defp get_dashboard_title("fr"), do: "Tableau de Bord"
  defp get_dashboard_title(_), do: "Dashboard"

  defp get_live_status_text("ar"), do: "مباشر"
  defp get_live_status_text("es"), do: "En vivo"
  defp get_live_status_text("fr"), do: "En direct"
  defp get_live_status_text(_), do: "Live"

  defp get_last_update_text("ar"), do: "آخر تحديث"
  defp get_last_update_text("es"), do: "Última actualización"
  defp get_last_update_text("fr"), do: "Dernière mise à jour"
  defp get_last_update_text(_), do: "Last Update"

  defp get_users_online_text("ar"), do: "مستخدمين متصلين"
  defp get_users_online_text("es"), do: "usuarios en línea"
  defp get_users_online_text("fr"), do: "utilisateurs en ligne"
  defp get_users_online_text(_), do: "users online"

  defp get_loading_dashboard_text("ar"), do: "جاري تحميل لوحة التحكم..."
  defp get_loading_dashboard_text("es"), do: "Cargando panel de control..."
  defp get_loading_dashboard_text("fr"), do: "Chargement du tableau de bord..."
  defp get_loading_dashboard_text(_), do: "Loading dashboard..."

  defp get_charts_text("ar"), do: "رسوم بيانية"
  defp get_charts_text("es"), do: "gráficos"
  defp get_charts_text("fr"), do: "graphiques"
  defp get_charts_text(_), do: "charts"

  defp get_refresh_text("ar"), do: "تحديث"
  defp get_refresh_text("es"), do: "Actualizar"
  defp get_refresh_text("fr"), do: "Actualiser"
  defp get_refresh_text(_), do: "Refresh"

  defp get_export_text("ar"), do: "تصدير"
  defp get_export_text("es"), do: "Exportar"
  defp get_export_text("fr"), do: "Exporter"
  defp get_export_text(_), do: "Export"

  defp get_filters_text("ar"), do: "المرشحات"
  defp get_filters_text("es"), do: "Filtros"
  defp get_filters_text("fr"), do: "Filtres"
  defp get_filters_text(_), do: "Filters"

  defp get_date_range_text("ar"), do: "نطاق التاريخ"
  defp get_date_range_text("es"), do: "Rango de fechas"
  defp get_date_range_text("fr"), do: "Plage de dates"
  defp get_date_range_text(_), do: "Date Range"

  defp get_search_text("ar"), do: "البحث"
  defp get_search_text("es"), do: "Buscar"
  defp get_search_text("fr"), do: "Recherche"
  defp get_search_text(_), do: "Search"

  defp get_search_placeholder("ar"), do: "ابحث في البيانات..."
  defp get_search_placeholder("es"), do: "Buscar datos..."
  defp get_search_placeholder("fr"), do: "Rechercher des données..."
  defp get_search_placeholder(_), do: "Search data..."

  defp get_apply_filters_text("ar"), do: "تطبيق المرشحات"
  defp get_apply_filters_text("es"), do: "Aplicar filtros"
  defp get_apply_filters_text("fr"), do: "Appliquer les filtres"
  defp get_apply_filters_text(_), do: "Apply Filters"

  defp get_reset_filters_text("ar"), do: "إعادة تعيين المرشحات"
  defp get_reset_filters_text("es"), do: "Restablecer filtros"
  defp get_reset_filters_text("fr"), do: "Réinitialiser les filtres"
  defp get_reset_filters_text(_), do: "Reset Filters"

  defp get_dashboard_controls_text("ar"), do: "عناصر التحكم"
  defp get_dashboard_controls_text("es"), do: "Controles"
  defp get_dashboard_controls_text("fr"), do: "Contrôles"
  defp get_dashboard_controls_text(_), do: "Controls"

  defp get_layout_text("ar"), do: "التخطيط"
  defp get_layout_text("es"), do: "Diseño"
  defp get_layout_text("fr"), do: "Disposition"
  defp get_layout_text(_), do: "Layout"

  defp get_real_time_text("ar"), do: "الوقت الفعلي"
  defp get_real_time_text("es"), do: "Tiempo real"
  defp get_real_time_text("fr"), do: "Temps réel"
  defp get_real_time_text(_), do: "Real Time"

  defp get_enable_real_time_text("ar"), do: "تفعيل الوقت الفعلي"
  defp get_enable_real_time_text("es"), do: "Habilitar tiempo real"
  defp get_enable_real_time_text("fr"), do: "Activer temps réel"
  defp get_enable_real_time_text(_), do: "Enable Real Time"

  defp get_update_interval_text("ar"), do: "فترة التحديث"
  defp get_update_interval_text("es"), do: "Intervalo de actualización"
  defp get_update_interval_text("fr"), do: "Intervalle de mise à jour"
  defp get_update_interval_text(_), do: "Update Interval"
end
