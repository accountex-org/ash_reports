defmodule AshReports.HeexRenderer.ChartTemplates do
  @moduledoc """
  Reusable HEEX templates for chart components in AshReports Phase 6.2.
  
  Provides optimized, reusable HEEX templates for common chart layouts,
  dashboard patterns, and interactive components with LiveView integration
  and performance optimization.
  
  ## Template Categories
  
  ### Chart Layout Templates
  - **Single Chart**: Simple chart with optional controls
  - **Dashboard Grid**: Multi-chart grid layout with coordination
  - **Sidebar Dashboard**: Chart with sidebar filters and controls
  - **Tabbed Charts**: Multiple charts in tabbed interface
  
  ### Interactive Templates
  - **Filter Dashboard**: Charts with live filtering controls
  - **Real-time Dashboard**: Live updating charts with status indicators
  - **Drill-down Charts**: Charts with hierarchical drill-down capability
  - **Comparison Dashboard**: Side-by-side chart comparisons
  
  """
  
  alias AshReports.{RenderContext}
  
  @doc """
  Generate a single chart template with optional interactive controls.
  
  ## Examples
  
      template = ChartTemplates.single_chart(%{
        chart_id: "sales_chart",
        title: "Monthly Sales",
        show_controls: true,
        real_time: true
      }, context)
  
  """
  @spec single_chart(map(), RenderContext.t()) :: String.t()
  def single_chart(config, %RenderContext{} = context) do
    chart_id = config[:chart_id] || "chart"
    show_controls = config[:show_controls] || false
    real_time = config[:real_time] || false
    
    """
    <div class="ash-single-chart-container #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}"
         data-chart-id="#{chart_id}">
      
      <%= if "#{config[:title]}" do %>
        <div class="chart-header">
          <h3 class="chart-title">#{config[:title]}</h3>
          
          <%= if #{real_time} do %>
            <div class="real-time-indicator">
              <span class="status-dot"></span>
              <span class="status-text">#{get_live_text(context.locale)}</span>
            </div>
          <% end %>
        </div>
      <% end %>
      
      <div class="chart-main-content">
        <.live_component
          module={AshReports.LiveView.ChartLiveComponent}
          id={#{inspect(chart_id)}}
          chart_config={@chart_config}
          locale="#{context.locale}"
          interactive={#{config[:interactive] || false}}
          real_time={#{real_time}}
        />
      </div>
      
      <%= if #{show_controls} do %>
        <div class="chart-controls">
          <%= render_chart_controls(assigns) %>
        </div>
      <% end %>
      
    </div>
    """
  end
  
  @doc """
  Generate a dashboard grid template for multiple charts.
  
  ## Examples
  
      template = ChartTemplates.dashboard_grid(%{
        charts: [
          %{id: "chart1", type: :line, cols: 6},
          %{id: "chart2", type: :pie, cols: 6}
        ],
        grid_columns: 12,
        real_time: true
      }, context)
  
  """
  @spec dashboard_grid(map(), RenderContext.t()) :: String.t()
  def dashboard_grid(config, %RenderContext{} = context) do
    charts = config[:charts] || []
    grid_columns = config[:grid_columns] || 12
    dashboard_id = config[:dashboard_id] || "dashboard"
    real_time = config[:real_time] || false
    
    chart_components = charts
    |> Enum.map(&generate_grid_chart_component(&1, context))
    |> Enum.join("\n")
    
    """
    <div class="ash-dashboard-grid #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}"
         data-dashboard-id="#{dashboard_id}"
         data-grid-columns="#{grid_columns}">
      
      <div class="dashboard-header">
        <h2 class="dashboard-title">#{config[:title] || get_dashboard_text(context.locale)}</h2>
        
        <%= if #{real_time} do %>
          <div class="dashboard-controls">
            <div class="real-time-status">
              <span class="status-indicator active"></span>
              <span>#{get_live_updates_text(context.locale)}</span>
            </div>
          </div>
        <% end %>
      </div>
      
      <div class="dashboard-grid" style="grid-template-columns: repeat(#{grid_columns}, 1fr);">
        #{chart_components}
      </div>
      
    </div>
    """
  end
  
  @doc """
  Generate a filter dashboard template with sidebar controls.
  
  ## Examples
  
      template = ChartTemplates.filter_dashboard(%{
        main_chart: %{id: "main", type: :line},
        filters: [:date_range, :region, :category],
        sidebar_position: :left
      }, context)
  
  """
  @spec filter_dashboard(map(), RenderContext.t()) :: String.t()
  def filter_dashboard(config, %RenderContext{} = context) do
    main_chart = config[:main_chart] || %{}
    filters = config[:filters] || []
    sidebar_position = config[:sidebar_position] || :left
    
    filter_controls = generate_filter_controls(filters, context)
    
    sidebar_class = case sidebar_position do
      :left -> "sidebar-left"
      :right -> "sidebar-right"
      _ -> "sidebar-left"
    end
    
    """
    <div class="ash-filter-dashboard #{sidebar_class} #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}">
      
      <div class="dashboard-sidebar">
        <h4 class="sidebar-title">#{get_filters_text(context.locale)}</h4>
        <div class="filter-controls">
          #{filter_controls}
        </div>
        
        <div class="filter-actions">
          <button phx-click="apply_filters" class="btn btn-primary">
            #{get_apply_text(context.locale)}
          </button>
          <button phx-click="reset_filters" class="btn btn-secondary">
            #{get_reset_text(context.locale)}
          </button>
        </div>
      </div>
      
      <div class="dashboard-main">
        <.live_component
          module={AshReports.LiveView.ChartLiveComponent}
          id={#{inspect(main_chart[:id] || "main_chart")}}
          chart_config={@main_chart_config}
          locale="#{context.locale}"
          interactive={true}
          real_time={#{config[:real_time] || false}}
        />
      </div>
      
    </div>
    """
  end
  
  @doc """
  Generate a real-time dashboard template with live indicators.
  
  ## Examples
  
      template = ChartTemplates.realtime_dashboard(%{
        charts: [overview_chart, metrics_chart],
        update_interval: 5000,
        show_metrics: true
      }, context)
  
  """
  @spec realtime_dashboard(map(), RenderContext.t()) :: String.t()
  def realtime_dashboard(config, %RenderContext{} = context) do
    charts = config[:charts] || []
    update_interval = config[:update_interval] || 30000
    show_metrics = config[:show_metrics] || false
    
    chart_components = charts
    |> Enum.map(&generate_realtime_chart_component(&1, context))
    |> Enum.join("\n")
    
    """
    <div class="ash-realtime-dashboard #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}"
         data-update-interval="#{update_interval}">
      
      <div class="dashboard-status-bar">
        <div class="connection-status">
          <span class="status-indicator" id="connection-status"></span>
          <span class="status-text">#{get_connected_text(context.locale)}</span>
        </div>
        
        <%= if #{show_metrics} do %>
          <div class="performance-metrics">
            <span class="metric">
              <span class="metric-label">#{get_latency_text(context.locale)}:</span>
              <span class="metric-value" id="latency-display">--ms</span>
            </span>
            <span class="metric">
              <span class="metric-label">#{get_updates_text(context.locale)}:</span>
              <span class="metric-value" id="updates-display">0</span>
            </span>
          </div>
        <% end %>
        
        <div class="last-update">
          #{get_last_update_text(context.locale)}: <span id="last-update-time">--</span>
        </div>
      </div>
      
      <div class="dashboard-charts">
        #{chart_components}
      </div>
      
    </div>
    """
  end
  
  @doc """
  Generate tabbed charts template for organizing multiple visualizations.
  """
  @spec tabbed_charts(map(), RenderContext.t()) :: String.t()
  def tabbed_charts(config, %RenderContext{} = context) do
    tabs = config[:tabs] || []
    
    tab_headers = tabs
    |> Enum.with_index()
    |> Enum.map(fn {tab, index} ->
      active_class = if index == 0, do: "active", else: ""
      
      """
      <button class="tab-header #{active_class}" 
              phx-click="switch_tab" 
              phx-value-tab="#{tab[:id]}"
              data-tab-index="#{index}">
        #{tab[:title] || "Chart #{index + 1}"}
      </button>
      """
    end)
    |> Enum.join("\n")
    
    tab_contents = tabs
    |> Enum.with_index()
    |> Enum.map(fn {tab, index} ->
      active_class = if index == 0, do: "active", else: ""
      
      """
      <div class="tab-content #{active_class}" data-tab="#{tab[:id]}">
        <.live_component
          module={AshReports.LiveView.ChartLiveComponent}
          id="#{tab[:id]}"
          chart_config={#{inspect(tab[:chart_config] || %{})}}
          locale="#{context.locale}"
          interactive={#{tab[:interactive] || false}}
          real_time={#{tab[:real_time] || false}}
        />
      </div>
      """
    end)
    |> Enum.join("\n")
    
    """
    <div class="ash-tabbed-charts #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}">
      
      <div class="tabs-header">
        #{tab_headers}
      </div>
      
      <div class="tabs-content">
        #{tab_contents}
      </div>
      
    </div>
    """
  end
  
  # Helper functions for generating template components
  
  defp generate_grid_chart_component(chart_config, %RenderContext{} = context) do
    cols = chart_config[:cols] || 6
    
    """
    <div class="grid-chart-item" style="grid-column: span #{cols};">
      <.live_component
        module={AshReports.LiveView.ChartLiveComponent}
        id="#{chart_config[:id]}"
        chart_config={#{inspect(chart_config)}}
        locale="#{context.locale}"
        interactive={#{chart_config[:interactive] || false}}
        real_time={#{chart_config[:real_time] || false}}
      />
    </div>
    """
  end
  
  defp generate_realtime_chart_component(chart_config, %RenderContext{} = context) do
    """
    <div class="realtime-chart-wrapper">
      <.live_component
        module={AshReports.LiveView.ChartLiveComponent}
        id="#{chart_config[:id]}"
        chart_config={#{inspect(chart_config)}}
        locale="#{context.locale}"
        interactive={#{chart_config[:interactive] || true}}
        real_time={true}
        update_interval={#{chart_config[:update_interval] || 5000}}
      />
    </div>
    """
  end
  
  defp generate_filter_controls(filters, %RenderContext{} = context) do
    filters
    |> Enum.map(&generate_single_filter_control(&1, context))
    |> Enum.join("\n")
  end
  
  defp generate_single_filter_control(filter_type, %RenderContext{} = context) do
    case filter_type do
      :date_range ->
        """
        <div class="filter-control date-range">
          <label>#{get_date_range_text(context.locale)}</label>
          <input type="date" name="start_date" phx-change="update_filter">
          <input type="date" name="end_date" phx-change="update_filter">
        </div>
        """
      
      :region ->
        """
        <div class="filter-control region">
          <label>#{get_region_text(context.locale)}</label>
          <select name="region" phx-change="update_filter">
            <option value="">#{get_all_regions_text(context.locale)}</option>
            <option value="north">#{get_north_text(context.locale)}</option>
            <option value="south">#{get_south_text(context.locale)}</option>
            <option value="east">#{get_east_text(context.locale)}</option>
            <option value="west">#{get_west_text(context.locale)}</option>
          </select>
        </div>
        """
      
      :category ->
        """
        <div class="filter-control category">
          <label>#{get_category_text(context.locale)}</label>
          <select name="category" phx-change="update_filter" multiple>
            <option value="sales">#{get_sales_text(context.locale)}</option>
            <option value="marketing">#{get_marketing_text(context.locale)}</option>
            <option value="support">#{get_support_text(context.locale)}</option>
          </select>
        </div>
        """
      
      :text_search ->
        """
        <div class="filter-control text-search">
          <label>#{get_search_text(context.locale)}</label>
          <input type="text" 
                 name="search" 
                 placeholder="#{get_search_placeholder_text(context.locale)}"
                 phx-change="update_filter"
                 phx-debounce="300">
        </div>
        """
      
      _ ->
        """
        <div class="filter-control unknown">
          <span>Unknown filter: #{filter_type}</span>
        </div>
        """
    end
  end
  
  # Localization helper functions
  
  defp get_live_text("ar"), do: "مباشر"
  defp get_live_text("es"), do: "En vivo"
  defp get_live_text("fr"), do: "En direct"
  defp get_live_text(_), do: "Live"
  
  defp get_dashboard_text("ar"), do: "لوحة التحكم"
  defp get_dashboard_text("es"), do: "Panel de control"
  defp get_dashboard_text("fr"), do: "Tableau de bord"
  defp get_dashboard_text(_), do: "Dashboard"
  
  defp get_live_updates_text("ar"), do: "التحديثات المباشرة"
  defp get_live_updates_text("es"), do: "Actualizaciones en vivo"
  defp get_live_updates_text("fr"), do: "Mises à jour en direct"
  defp get_live_updates_text(_), do: "Live Updates"
  
  defp get_filters_text("ar"), do: "المرشحات"
  defp get_filters_text("es"), do: "Filtros"
  defp get_filters_text("fr"), do: "Filtres"
  defp get_filters_text(_), do: "Filters"
  
  defp get_apply_text("ar"), do: "تطبيق"
  defp get_apply_text("es"), do: "Aplicar"
  defp get_apply_text("fr"), do: "Appliquer"
  defp get_apply_text(_), do: "Apply"
  
  defp get_reset_text("ar"), do: "إعادة تعيين"
  defp get_reset_text("es"), do: "Restablecer"
  defp get_reset_text("fr"), do: "Réinitialiser"
  defp get_reset_text(_), do: "Reset"
  
  defp get_connected_text("ar"), do: "متصل"
  defp get_connected_text("es"), do: "Conectado"
  defp get_connected_text("fr"), do: "Connecté"
  defp get_connected_text(_), do: "Connected"
  
  defp get_latency_text("ar"), do: "زمن الاستجابة"
  defp get_latency_text("es"), do: "Latencia"
  defp get_latency_text("fr"), do: "Latence"
  defp get_latency_text(_), do: "Latency"
  
  defp get_updates_text("ar"), do: "التحديثات"
  defp get_updates_text("es"), do: "Actualizaciones"
  defp get_updates_text("fr"), do: "Mises à jour"
  defp get_updates_text(_), do: "Updates"
  
  defp get_last_update_text("ar"), do: "آخر تحديث"
  defp get_last_update_text("es"), do: "Última actualización"
  defp get_last_update_text("fr"), do: "Dernière mise à jour"
  defp get_last_update_text(_), do: "Last Update"
  
  defp get_date_range_text("ar"), do: "نطاق التاريخ"
  defp get_date_range_text("es"), do: "Rango de fechas"
  defp get_date_range_text("fr"), do: "Plage de dates"
  defp get_date_range_text(_), do: "Date Range"
  
  defp get_region_text("ar"), do: "المنطقة"
  defp get_region_text("es"), do: "Región"
  defp get_region_text("fr"), do: "Région"
  defp get_region_text(_), do: "Region"
  
  defp get_category_text("ar"), do: "الفئة"
  defp get_category_text("es"), do: "Categoría"
  defp get_category_text("fr"), do: "Catégorie"
  defp get_category_text(_), do: "Category"
  
  defp get_search_text("ar"), do: "البحث"
  defp get_search_text("es"), do: "Buscar"
  defp get_search_text("fr"), do: "Recherche"
  defp get_search_text(_), do: "Search"
  
  defp get_all_regions_text("ar"), do: "جميع المناطق"
  defp get_all_regions_text("es"), do: "Todas las regiones"
  defp get_all_regions_text("fr"), do: "Toutes les régions"
  defp get_all_regions_text(_), do: "All Regions"
  
  defp get_north_text("ar"), do: "الشمال"
  defp get_north_text("es"), do: "Norte"
  defp get_north_text("fr"), do: "Nord"
  defp get_north_text(_), do: "North"
  
  defp get_south_text("ar"), do: "الجنوب"
  defp get_south_text("es"), do: "Sur"
  defp get_south_text("fr"), do: "Sud"
  defp get_south_text(_), do: "South"
  
  defp get_east_text("ar"), do: "الشرق"
  defp get_east_text("es"), do: "Este"
  defp get_east_text("fr"), do: "Est"
  defp get_east_text(_), do: "East"
  
  defp get_west_text("ar"), do: "الغرب"
  defp get_west_text("es"), do: "Oeste"
  defp get_west_text("fr"), do: "Ouest"
  defp get_west_text(_), do: "West"
  
  defp get_sales_text("ar"), do: "المبيعات"
  defp get_sales_text("es"), do: "Ventas"
  defp get_sales_text("fr"), do: "Ventes"
  defp get_sales_text(_), do: "Sales"
  
  defp get_marketing_text("ar"), do: "التسويق"
  defp get_marketing_text("es"), do: "Marketing"
  defp get_marketing_text("fr"), do: "Marketing"
  defp get_marketing_text(_), do: "Marketing"
  
  defp get_support_text("ar"), do: "الدعم"
  defp get_support_text("es"), do: "Soporte"
  defp get_support_text("fr"), do: "Support"
  defp get_support_text(_), do: "Support"
  
  defp get_search_placeholder_text("ar"), do: "ابحث في البيانات..."
  defp get_search_placeholder_text("es"), do: "Buscar en los datos..."
  defp get_search_placeholder_text("fr"), do: "Rechercher dans les données..."
  defp get_search_placeholder_text(_), do: "Search data..."
end