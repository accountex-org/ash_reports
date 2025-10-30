defmodule AshReports.LiveView.ChartConfigurationComponent do
  @moduledoc """
  Live form component for chart configuration in AshReports Phase 6.2.

  Provides interactive form components for configuring chart properties,
  data sources, styling, and behavior with real-time preview and
  validation using Phoenix LiveView.

  ## Features

  - **Real-time Configuration**: Live chart preview as settings change
  - **Data Source Selection**: Configure database queries, API endpoints, static data
  - **Chart Type Selection**: Interactive chart type switching with preview
  - **Styling Configuration**: Colors, themes, layout customization
  - **Interactive Settings**: Enable/disable features, set update intervals
  - **Validation**: Real-time validation with error feedback

  ## Usage Examples

  ### Basic Chart Configuration

      <.live_component
        module={AshReports.LiveView.ChartConfigurationComponent}
        id="chart_config"
        chart_config={@chart_config}
        data_sources={@available_data_sources}
        on_update="chart_config_updated"
      />

  ### Advanced Configuration with Preview

      <.live_component
        module={AshReports.LiveView.ChartConfigurationComponent}
        id="advanced_config"
        chart_config={@chart_config}
        show_preview={true}
        advanced_mode={true}
        locale={@locale}
      />

  """

  use Phoenix.LiveComponent

  alias AshReports.ChartEngine
  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.RenderContext

  @chart_types [
    %{type: :line, name: "Line Chart", icon: "📈", description: "For trends and time series"},
    %{type: :bar, name: "Bar Chart", icon: "📊", description: "For categorical comparisons"},
    %{type: :pie, name: "Pie Chart", icon: "🥧", description: "For proportional data"},
    %{type: :area, name: "Area Chart", icon: "📈", description: "For cumulative data"},
    %{type: :scatter, name: "Scatter Plot", icon: "⚪", description: "For correlation analysis"},
    %{type: :histogram, name: "Histogram", icon: "📶", description: "For frequency distribution"}
  ]

  @chart_providers [
    %{provider: :chartjs, name: "Chart.js", description: "Lightweight and responsive"},
    %{provider: :d3, name: "D3.js", description: "Maximum customization"},
    %{provider: :plotly, name: "Plotly", description: "Scientific and 3D charts"}
  ]

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:chart_types, @chart_types)
      |> assign(:chart_providers, @chart_providers)
      |> assign(:form_errors, %{})
      |> assign(:preview_enabled, false)
      |> assign(:preview_chart, nil)
      |> assign(:configuration_valid, false)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Validate configuration when updated
    socket = validate_chart_configuration(socket)

    # Update preview if enabled
    socket =
      if socket.assigns.show_preview do
        update_chart_preview(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"chart-configuration-component #{if rtl_locale?(@locale), do: "rtl", else: "ltr"}"}
         data-component-id={@id}>
      
      <div class="config-header">
        <h3><%= get_chart_config_title(@locale) %></h3>
        
        <%= if @show_preview do %>
          <label class="preview-toggle">
            <input type="checkbox" 
                   phx-click="toggle_preview" 
                   phx-target={@myself}
                   checked={@preview_enabled}>
            <%= get_show_preview_text(@locale) %>
          </label>
        <% end %>
      </div>
      
      <form phx-change="update_config" phx-target={@myself} phx-submit="save_config">
        
        <!-- Basic Configuration -->
        <div class="config-section basic-config">
          <h4><%= get_basic_settings_text(@locale) %></h4>
          
          <div class="form-group">
            <label for="chart_title"><%= get_chart_title_text(@locale) %></label>
            <input type="text" 
                   id="chart_title"
                   name="config[title]" 
                   value={@chart_config[:title]}
                   placeholder={get_title_placeholder(@locale)}>
          </div>
          
          <!-- Chart Type Selection -->
          <div class="form-group chart-type-selection">
            <label><%= get_chart_type_text(@locale) %></label>
            <div class="chart-type-grid">
              <%= for chart_type <- @chart_types do %>
                <div class={"chart-type-option #{if @chart_config[:type] == chart_type.type, do: "selected", else: ""}"}>
                  <input type="radio" 
                         name="config[type]" 
                         value={chart_type.type}
                         id={"chart_type_#{chart_type.type}"}
                         checked={@chart_config[:type] == chart_type.type}>
                  <label for={"chart_type_#{chart_type.type}"}>
                    <span class="chart-icon"><%= chart_type.icon %></span>
                    <span class="chart-name"><%= chart_type.name %></span>
                    <small class="chart-description"><%= chart_type.description %></small>
                  </label>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Chart Provider -->
          <div class="form-group provider-selection">
            <label for="chart_provider"><%= get_provider_text(@locale) %></label>
            <select id="chart_provider" name="config[provider]">
              <%= for provider <- @chart_providers do %>
                <option value={provider.provider} selected={@chart_config[:provider] == provider.provider}>
                  <%= provider.name %> - <%= provider.description %>
                </option>
              <% end %>
            </select>
          </div>
        </div>
        
        <!-- Data Configuration -->
        <div class="config-section data-config">
          <h4><%= get_data_settings_text(@locale) %></h4>
          
          <div class="form-group">
            <label for="data_source_type"><%= get_data_source_text(@locale) %></label>
            <select id="data_source_type" name="config[data_source_type]">
              <option value="static" selected={@chart_config[:data_source_type] == "static"}>
                <%= get_static_data_text(@locale) %>
              </option>
              <option value="database" selected={@chart_config[:data_source_type] == "database"}>
                <%= get_database_text(@locale) %>
              </option>
              <option value="api" selected={@chart_config[:data_source_type] == "api"}>
                <%= get_api_text(@locale) %>
              </option>
            </select>
          </div>
          
          <%= if @chart_config[:data_source_type] == "database" do %>
            <div class="form-group database-config">
              <label for="database_query"><%= get_query_text(@locale) %></label>
              <textarea id="database_query" 
                        name="config[database_query]"
                        placeholder={get_query_placeholder(@locale)}
                        rows="3"><%= @chart_config[:database_query] %></textarea>
            </div>
          <% end %>
          
          <%= if @chart_config[:data_source_type] == "api" do %>
            <div class="form-group api-config">
              <label for="api_endpoint"><%= get_api_endpoint_text(@locale) %></label>
              <input type="url" 
                     id="api_endpoint"
                     name="config[api_endpoint]" 
                     value={@chart_config[:api_endpoint]}
                     placeholder="https://api.example.com/data">
            </div>
          <% end %>
        </div>
        
        <!-- Interactive Features -->
        <div class="config-section interactive-config">
          <h4><%= get_interactive_features_text(@locale) %></h4>
          
          <div class="feature-toggles">
            <label class="toggle-option">
              <input type="checkbox" 
                     name="config[interactive]" 
                     checked={@chart_config[:interactive]}
                     value="true">
              <span class="toggle-label"><%= get_enable_interactive_text(@locale) %></span>
            </label>
            
            <label class="toggle-option">
              <input type="checkbox" 
                     name="config[real_time]" 
                     checked={@chart_config[:real_time]}
                     value="true">
              <span class="toggle-label"><%= get_enable_real_time_text(@locale) %></span>
            </label>
            
            <label class="toggle-option">
              <input type="checkbox" 
                     name="config[exportable]" 
                     checked={@chart_config[:exportable]}
                     value="true">
              <span class="toggle-label"><%= get_enable_export_text(@locale) %></span>
            </label>
          </div>
          
          <%= if @chart_config[:real_time] do %>
            <div class="form-group">
              <label for="update_interval"><%= get_update_interval_text(@locale) %></label>
              <select id="update_interval" name="config[update_interval]">
                <option value="5000" selected={@chart_config[:update_interval] == 5000}>5s</option>
                <option value="10000" selected={@chart_config[:update_interval] == 10000}>10s</option>
                <option value="30000" selected={@chart_config[:update_interval] == 30000}>30s</option>
                <option value="60000" selected={@chart_config[:update_interval] == 60000}>1m</option>
              </select>
            </div>
          <% end %>
        </div>
        
        <!-- Form Actions -->
        <div class="config-actions">
          <%= if @configuration_valid do %>
            <button type="submit" class="btn btn-primary">
              <%= get_save_config_text(@locale) %>
            </button>
          <% else %>
            <button type="button" class="btn btn-disabled" disabled>
              <%= get_invalid_config_text(@locale) %>
            </button>
          <% end %>
          
          <button type="button" phx-click="reset_config" phx-target={@myself} class="btn btn-secondary">
            <%= get_reset_config_text(@locale) %>
          </button>
          
          <%= if @show_preview and @preview_enabled do %>
            <button type="button" phx-click="refresh_preview" phx-target={@myself} class="btn btn-outline">
              <%= get_refresh_preview_text(@locale) %>
            </button>
          <% end %>
        </div>
        
      </form>
      
      <!-- Configuration Errors -->
      <%= if map_size(@form_errors) > 0 do %>
        <div class="config-errors" role="alert">
          <h5><%= get_configuration_errors_text(@locale) %></h5>
          <ul>
            <%= for {field, error} <- @form_errors do %>
              <li class="error-item">
                <strong><%= humanize_field_name(field, @locale) %>:</strong> <%= error %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
      
      <!-- Live Preview -->
      <%= if @show_preview and @preview_enabled and @preview_chart do %>
        <div class="config-preview">
          <h4><%= get_preview_text(@locale) %></h4>
          <div class="preview-container">
            <%= Phoenix.HTML.raw(@preview_chart.html) %>
          </div>
        </div>
      <% end %>
      
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("update_config", %{"config" => config_params}, socket) do
    # Update chart configuration and validate
    updated_config = Map.merge(socket.assigns.chart_config, config_params)

    socket =
      socket
      |> assign(:chart_config, updated_config)
      |> validate_chart_configuration()

    # Update preview if enabled
    socket =
      if socket.assigns.preview_enabled do
        update_chart_preview(socket)
      else
        socket
      end

    # Notify parent of configuration change
    if socket.assigns.configuration_valid do
      send(self(), {:chart_config_updated, socket.assigns.id, updated_config})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    preview_enabled = not socket.assigns.preview_enabled

    socket =
      socket
      |> assign(:preview_enabled, preview_enabled)

    socket =
      if preview_enabled do
        update_chart_preview(socket)
      else
        assign(socket, :preview_chart, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_config", %{"config" => config_params}, socket) do
    if socket.assigns.configuration_valid do
      # Save configuration
      final_config = Map.merge(socket.assigns.chart_config, config_params)

      # Notify parent
      send(self(), {:chart_config_saved, socket.assigns.id, final_config})

      {:noreply, put_flash(socket, :info, get_config_saved_text(socket.assigns.locale))}
    else
      {:noreply, put_flash(socket, :error, get_invalid_config_error_text(socket.assigns.locale))}
    end
  end

  @impl true
  def handle_event("reset_config", _params, socket) do
    # Reset to default configuration
    default_config = %{
      type: :bar,
      title: "",
      provider: :chartjs,
      data_source_type: "static",
      interactive: true,
      real_time: false,
      exportable: true,
      update_interval: 30000
    }

    socket =
      socket
      |> assign(:chart_config, default_config)
      |> assign(:form_errors, %{})
      |> assign(:configuration_valid, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_preview", _params, socket) do
    socket = update_chart_preview(socket)
    {:noreply, socket}
  end

  # Private implementation functions

  defp validate_chart_configuration(socket) do
    config = socket.assigns.chart_config
    locale = socket.assigns.locale

    errors =
      %{}
      |> validate_title_field(config, locale)
      |> validate_data_source_field(config, locale)
      |> validate_update_interval_field(config, locale)

    socket
    |> assign(:form_errors, errors)
    |> assign(:configuration_valid, map_size(errors) == 0)
  end

  defp validate_title_field(errors, config, locale) do
    if is_binary(config[:title]) and String.trim(config[:title]) == "" do
      Map.put(errors, :title, get_title_required_error(locale))
    else
      errors
    end
  end

  defp validate_data_source_field(errors, config, locale) do
    case config[:data_source_type] do
      "database" -> validate_database_config(errors, config, locale)
      "api" -> validate_api_config(errors, config, locale)
      _ -> errors
    end
  end

  defp validate_database_config(errors, config, locale) do
    if is_binary(config[:database_query]) and String.trim(config[:database_query]) == "" do
      Map.put(errors, :database_query, get_query_required_error(locale))
    else
      errors
    end
  end

  defp validate_api_config(errors, config, locale) do
    if valid_url?(config[:api_endpoint]) do
      errors
    else
      Map.put(errors, :api_endpoint, get_valid_url_required_error(locale))
    end
  end

  defp validate_update_interval_field(errors, config, locale) do
    if config[:real_time] and not valid_update_interval?(config[:update_interval]) do
      Map.put(errors, :update_interval, get_valid_interval_error(locale))
    else
      errors
    end
  end

  defp update_chart_preview(socket) do
    if socket.assigns.configuration_valid do
      # Generate preview chart
      preview_config = %ChartConfig{
        type: socket.assigns.chart_config[:type] || :bar,
        title: socket.assigns.chart_config[:title],
        data: generate_preview_data(socket.assigns.chart_config[:type]),
        # Disable interactions in preview
        interactive: false,
        # Disable real-time in preview
        real_time: false
      }

      context = %RenderContext{
        locale: socket.assigns.locale || "en",
        text_direction: if(rtl_locale?(socket.assigns.locale), do: "rtl", else: "ltr")
      }

      case ChartEngine.generate(preview_config, context) do
        {:ok, chart_result} ->
          assign(socket, :preview_chart, chart_result)

        {:error, _reason} ->
          assign(socket, :preview_chart, nil)
      end
    else
      assign(socket, :preview_chart, nil)
    end
  end

  defp generate_preview_data(chart_type) do
    # Generate sample data based on chart type
    case chart_type do
      :line ->
        for i <- 1..10, do: %{x: i, y: :rand.uniform(100)}

      :bar ->
        [
          %{x: "Q1", y: 100},
          %{x: "Q2", y: 150},
          %{x: "Q3", y: 120},
          %{x: "Q4", y: 180}
        ]

      :pie ->
        [
          %{label: "A", value: 30},
          %{label: "B", value: 40},
          %{label: "C", value: 20},
          %{label: "D", value: 10}
        ]

      :scatter ->
        for _i <- 1..20, do: %{x: :rand.uniform(100), y: :rand.uniform(100)}

      _ ->
        for i <- 1..5, do: %{x: i, y: :rand.uniform(50)}
    end
  end

  # Validation helpers

  defp valid_url?(url) when is_binary(url) do
    String.starts_with?(url, ["http://", "https://"]) and String.length(url) > 10
  end

  defp valid_url?(_), do: false

  defp valid_update_interval?(interval) when is_integer(interval) do
    # Between 1 second and 5 minutes
    interval >= 1000 and interval <= 300_000
  end

  defp valid_update_interval?(interval) when is_binary(interval) do
    case Integer.parse(interval) do
      {parsed_interval, _} -> valid_update_interval?(parsed_interval)
      :error -> false
    end
  end

  defp valid_update_interval?(_), do: false

  defp rtl_locale?(locale) when is_binary(locale) do
    locale in ["ar", "he", "fa", "ur"]
  end

  defp rtl_locale?(_), do: false

  # Localization functions

  defp get_chart_config_title("ar"), do: "إعدادات الرسم البياني"
  defp get_chart_config_title("es"), do: "Configuración del gráfico"
  defp get_chart_config_title("fr"), do: "Configuration du graphique"
  defp get_chart_config_title(_), do: "Chart Configuration"

  defp get_show_preview_text("ar"), do: "إظهار المعاينة"
  defp get_show_preview_text("es"), do: "Mostrar vista previa"
  defp get_show_preview_text("fr"), do: "Afficher l'aperçu"
  defp get_show_preview_text(_), do: "Show Preview"

  defp get_basic_settings_text("ar"), do: "الإعدادات الأساسية"
  defp get_basic_settings_text("es"), do: "Configuración básica"
  defp get_basic_settings_text("fr"), do: "Configuration de base"
  defp get_basic_settings_text(_), do: "Basic Settings"

  defp get_chart_title_text("ar"), do: "عنوان الرسم البياني"
  defp get_chart_title_text("es"), do: "Título del gráfico"
  defp get_chart_title_text("fr"), do: "Titre du graphique"
  defp get_chart_title_text(_), do: "Chart Title"

  defp get_title_placeholder("ar"), do: "أدخل عنوان الرسم البياني..."
  defp get_title_placeholder("es"), do: "Ingrese el título del gráfico..."
  defp get_title_placeholder("fr"), do: "Entrez le titre du graphique..."
  defp get_title_placeholder(_), do: "Enter chart title..."

  defp get_chart_type_text("ar"), do: "نوع الرسم البياني"
  defp get_chart_type_text("es"), do: "Tipo de gráfico"
  defp get_chart_type_text("fr"), do: "Type de graphique"
  defp get_chart_type_text(_), do: "Chart Type"

  defp get_provider_text("ar"), do: "مقدم الخدمة"
  defp get_provider_text("es"), do: "Proveedor"
  defp get_provider_text("fr"), do: "Fournisseur"
  defp get_provider_text(_), do: "Provider"

  defp get_data_settings_text("ar"), do: "إعدادات البيانات"
  defp get_data_settings_text("es"), do: "Configuración de datos"
  defp get_data_settings_text("fr"), do: "Configuration des données"
  defp get_data_settings_text(_), do: "Data Settings"

  defp get_data_source_text("ar"), do: "مصدر البيانات"
  defp get_data_source_text("es"), do: "Fuente de datos"
  defp get_data_source_text("fr"), do: "Source de données"
  defp get_data_source_text(_), do: "Data Source"

  defp get_static_data_text("ar"), do: "بيانات ثابتة"
  defp get_static_data_text("es"), do: "Datos estáticos"
  defp get_static_data_text("fr"), do: "Données statiques"
  defp get_static_data_text(_), do: "Static Data"

  defp get_database_text("ar"), do: "قاعدة البيانات"
  defp get_database_text("es"), do: "Base de datos"
  defp get_database_text("fr"), do: "Base de données"
  defp get_database_text(_), do: "Database"

  defp get_api_text("ar"), do: "واجهة برمجة التطبيقات"
  defp get_api_text("es"), do: "API"
  defp get_api_text("fr"), do: "API"
  defp get_api_text(_), do: "API"

  defp get_query_text("ar"), do: "الاستعلام"
  defp get_query_text("es"), do: "Consulta"
  defp get_query_text("fr"), do: "Requête"
  defp get_query_text(_), do: "Query"

  defp get_query_placeholder("ar"), do: "SELECT * FROM table WHERE..."
  defp get_query_placeholder("es"), do: "SELECT * FROM tabla WHERE..."
  defp get_query_placeholder("fr"), do: "SELECT * FROM table WHERE..."
  defp get_query_placeholder(_), do: "SELECT * FROM table WHERE..."

  defp get_api_endpoint_text("ar"), do: "نقطة نهاية API"
  defp get_api_endpoint_text("es"), do: "Endpoint de API"
  defp get_api_endpoint_text("fr"), do: "Point de terminaison API"
  defp get_api_endpoint_text(_), do: "API Endpoint"

  defp get_interactive_features_text("ar"), do: "الميزات التفاعلية"
  defp get_interactive_features_text("es"), do: "Funciones interactivas"
  defp get_interactive_features_text("fr"), do: "Fonctionnalités interactives"
  defp get_interactive_features_text(_), do: "Interactive Features"

  defp get_enable_interactive_text("ar"), do: "تفعيل التفاعل"
  defp get_enable_interactive_text("es"), do: "Habilitar interactividad"
  defp get_enable_interactive_text("fr"), do: "Activer l'interactivité"
  defp get_enable_interactive_text(_), do: "Enable Interactive"

  defp get_enable_real_time_text("ar"), do: "تفعيل الوقت الفعلي"
  defp get_enable_real_time_text("es"), do: "Habilitar tiempo real"
  defp get_enable_real_time_text("fr"), do: "Activer temps réel"
  defp get_enable_real_time_text(_), do: "Enable Real Time"

  defp get_enable_export_text("ar"), do: "تفعيل التصدير"
  defp get_enable_export_text("es"), do: "Habilitar exportación"
  defp get_enable_export_text("fr"), do: "Activer l'exportation"
  defp get_enable_export_text(_), do: "Enable Export"

  defp get_update_interval_text("ar"), do: "فترة التحديث"
  defp get_update_interval_text("es"), do: "Intervalo de actualización"
  defp get_update_interval_text("fr"), do: "Intervalle de mise à jour"
  defp get_update_interval_text(_), do: "Update Interval"

  defp get_save_config_text("ar"), do: "حفظ الإعدادات"
  defp get_save_config_text("es"), do: "Guardar configuración"
  defp get_save_config_text("fr"), do: "Enregistrer la configuration"
  defp get_save_config_text(_), do: "Save Configuration"

  defp get_invalid_config_text("ar"), do: "إعدادات غير صالحة"
  defp get_invalid_config_text("es"), do: "Configuración inválida"
  defp get_invalid_config_text("fr"), do: "Configuration invalide"
  defp get_invalid_config_text(_), do: "Invalid Configuration"

  defp get_reset_config_text("ar"), do: "إعادة تعيين الإعدادات"
  defp get_reset_config_text("es"), do: "Restablecer configuración"
  defp get_reset_config_text("fr"), do: "Réinitialiser la configuration"
  defp get_reset_config_text(_), do: "Reset Configuration"

  defp get_refresh_preview_text("ar"), do: "تحديث المعاينة"
  defp get_refresh_preview_text("es"), do: "Actualizar vista previa"
  defp get_refresh_preview_text("fr"), do: "Actualiser l'aperçu"
  defp get_refresh_preview_text(_), do: "Refresh Preview"

  defp get_preview_text("ar"), do: "معاينة"
  defp get_preview_text("es"), do: "Vista previa"
  defp get_preview_text("fr"), do: "Aperçu"
  defp get_preview_text(_), do: "Preview"

  defp get_configuration_errors_text("ar"), do: "أخطاء في الإعدادات"
  defp get_configuration_errors_text("es"), do: "Errores de configuración"
  defp get_configuration_errors_text("fr"), do: "Erreurs de configuration"
  defp get_configuration_errors_text(_), do: "Configuration Errors"

  defp get_config_saved_text("ar"), do: "تم حفظ الإعدادات بنجاح"
  defp get_config_saved_text("es"), do: "Configuración guardada exitosamente"
  defp get_config_saved_text("fr"), do: "Configuration enregistrée avec succès"
  defp get_config_saved_text(_), do: "Configuration saved successfully"

  defp get_invalid_config_error_text("ar"), do: "يرجى إصلاح الأخطاء قبل الحفظ"
  defp get_invalid_config_error_text("es"), do: "Por favor corrija los errores antes de guardar"

  defp get_invalid_config_error_text("fr"),
    do: "Veuillez corriger les erreurs avant d'enregistrer"

  defp get_invalid_config_error_text(_), do: "Please fix errors before saving"

  # Validation error messages

  defp get_title_required_error("ar"), do: "العنوان مطلوب"
  defp get_title_required_error("es"), do: "El título es requerido"
  defp get_title_required_error("fr"), do: "Le titre est requis"
  defp get_title_required_error(_), do: "Title is required"

  defp get_query_required_error("ar"), do: "الاستعلام مطلوب"
  defp get_query_required_error("es"), do: "La consulta es requerida"
  defp get_query_required_error("fr"), do: "La requête est requise"
  defp get_query_required_error(_), do: "Query is required"

  defp get_valid_url_required_error("ar"), do: "رابط صالح مطلوب"
  defp get_valid_url_required_error("es"), do: "Se requiere una URL válida"
  defp get_valid_url_required_error("fr"), do: "Une URL valide est requise"
  defp get_valid_url_required_error(_), do: "Valid URL is required"

  defp get_valid_interval_error("ar"), do: "فترة تحديث صالحة مطلوبة (1s-5m)"
  defp get_valid_interval_error("es"), do: "Intervalo de actualización válido requerido (1s-5m)"
  defp get_valid_interval_error("fr"), do: "Intervalle de mise à jour valide requis (1s-5m)"
  defp get_valid_interval_error(_), do: "Valid update interval required (1s-5m)"

  defp humanize_field_name(:title, "ar"), do: "العنوان"
  defp humanize_field_name(:title, "es"), do: "Título"
  defp humanize_field_name(:title, "fr"), do: "Titre"
  defp humanize_field_name(:title, _), do: "Title"

  defp humanize_field_name(:database_query, "ar"), do: "استعلام قاعدة البيانات"
  defp humanize_field_name(:database_query, "es"), do: "Consulta de base de datos"
  defp humanize_field_name(:database_query, "fr"), do: "Requête de base de données"
  defp humanize_field_name(:database_query, _), do: "Database Query"

  defp humanize_field_name(:api_endpoint, "ar"), do: "نقطة نهاية API"
  defp humanize_field_name(:api_endpoint, "es"), do: "Endpoint de API"
  defp humanize_field_name(:api_endpoint, "fr"), do: "Point de terminaison API"
  defp humanize_field_name(:api_endpoint, _), do: "API Endpoint"

  defp humanize_field_name(:update_interval, "ar"), do: "فترة التحديث"
  defp humanize_field_name(:update_interval, "es"), do: "Intervalo de actualización"
  defp humanize_field_name(:update_interval, "fr"), do: "Intervalle de mise à jour"
  defp humanize_field_name(:update_interval, _), do: "Update Interval"

  defp humanize_field_name(field, _locale) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
