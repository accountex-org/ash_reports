defmodule AshReports.HeexRendererEnhanced do
  @moduledoc """
  Enhanced HEEX Renderer for AshReports Phase 6.2 with LiveView integration.

  Builds upon the existing HEEX renderer by adding comprehensive LiveView chart
  component integration, real-time streaming capabilities, and server-side
  interactive features while maintaining compatibility with existing HEEX rendering.

  ## Features

  - **LiveView Chart Integration**: Seamless chart components with real-time updates
  - **Server-Side Interactivity**: Filter, sort, drill-down handled on server
  - **Phoenix PubSub Streaming**: Live data broadcasting without page refresh
  - **Component Architecture**: Reusable chart and dashboard components
  - **Mobile Optimization**: Touch-friendly interactions and responsive design
  - **Phoenix Hooks**: Chart.js, D3.js, Plotly integration with LiveView lifecycle

  ## Integration with Phase 5.2

  The enhanced renderer leverages Phase 5.2 HTML foundation:
  - Reuses ChartIntegrator for chart generation
  - Adapts JavaScriptGenerator for LiveView hooks
  - Utilizes AssetManager for CDN and performance optimization
  - Extends existing HEEX rendering with interactive capabilities

  ## Usage Examples

  ### Basic HEEX with Chart Integration

      context = RenderContext.new(report, data_result, %{renderer: :heex_enhanced})
      {:ok, result} = HeexRendererEnhanced.render_with_context(context)
      
      # result.content contains HEEX template with embedded LiveView chart components
      
  ### Dashboard with Multiple Interactive Charts

      dashboard_config = %{
        charts: [
          %{id: "overview", type: :line, interactive: true},
          %{id: "breakdown", type: :pie, real_time: true}
        ],
        layout: :grid,
        real_time: true
      }
      
      context = RenderContext.new(report, data_result, dashboard_config)
      {:ok, result} = HeexRendererEnhanced.render_with_context(context)

  """

  @behaviour AshReports.Renderer

  alias AshReports.{
    ChartEngine,
    # Existing HEEX renderer
    HeexRenderer,
    InteractiveEngine,
    RenderContext
  }

  alias AshReports.HtmlRenderer.{AssetManager, ChartIntegrator}
  alias AshReports.LiveView.{ChartHooks, ChartLiveComponent}

  @doc """
  Enhanced HEEX rendering with LiveView chart component integration.

  Extends the existing HEEX renderer with interactive chart capabilities
  while maintaining full compatibility with existing HEEX rendering patterns.
  """
  @impl true
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    with {:ok, enhanced_context} <- prepare_enhanced_context(context, opts),
         {:ok, chart_components} <- generate_liveview_chart_components(enhanced_context),
         {:ok, base_heex} <- render_base_heex_content(enhanced_context),
         {:ok, enhanced_heex} <-
           integrate_charts_with_heex(base_heex, chart_components, enhanced_context),
         {:ok, result_metadata} <- build_enhanced_result_metadata(enhanced_context, start_time) do
      result = %{
        content: enhanced_heex,
        metadata: result_metadata,
        context: enhanced_context,
        components: chart_components
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, "Enhanced HEEX rendering failed: #{reason}"}
    end
  end

  @doc """
  Legacy render callback with enhanced features.

  Provides backward compatibility while adding LiveView chart capabilities.
  """
  @impl true
  def render(report_module, data, opts) do
    # Convert to enhanced context-based API
    config = Keyword.get(opts, :config, %{})
    enhanced_config = Map.merge(config, %{renderer: :heex_enhanced})
    context = RenderContext.new(report_module, %{records: data}, enhanced_config)

    case render_with_context(context, opts) do
      {:ok, result} -> {:ok, result.content}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate LiveView mount function for chart dashboard.

  Creates the mount/3 function needed for a LiveView that includes
  chart components with real-time capabilities.
  """
  @spec generate_liveview_mount(map()) :: String.t()
  def generate_liveview_mount(dashboard_config) do
    """
    def mount(_params, _session, socket) do
      # Initialize dashboard state
      socket = socket
      |> assign(:dashboard_config, #{inspect(dashboard_config)})
      |> assign(:charts, %{})
      |> assign(:real_time_enabled, #{dashboard_config[:real_time] || false})
      |> assign(:last_update, DateTime.utc_now())
      
      # Subscribe to real-time updates if enabled
      if socket.assigns.real_time_enabled do
        Phoenix.PubSub.subscribe(AshReports.PubSub, "dashboard_updates")
      end
      
      {:ok, socket}
    end
    """
  end

  @doc """
  Generate LiveView handle_info for real-time chart updates.

  Creates the handle_info/2 functions needed for processing real-time
  chart data updates and broadcasting to chart components.
  """
  @spec generate_liveview_handle_info() :: String.t()
  def generate_liveview_handle_info do
    """
    def handle_info({:chart_data_update, chart_id, new_data}, socket) do
      # Update specific chart component
      send_update(AshReports.LiveView.ChartLiveComponent, 
        id: chart_id,
        chart_data: new_data,
        last_updated: DateTime.utc_now()
      )
      
      {:noreply, socket}
    end

    def handle_info({:dashboard_update, dashboard_data}, socket) do
      # Update entire dashboard
      socket = assign(socket, :dashboard_data, dashboard_data)
      
      # Notify all chart components
      dashboard_data.charts
      |> Enum.each(fn {chart_id, chart_data} ->
        send_update(AshReports.LiveView.ChartLiveComponent,
          id: chart_id,
          chart_data: chart_data
        )
      end)
      
      {:noreply, socket}
    end

    def handle_info({:chart_error, chart_id, error}, socket) do
      # Handle chart-specific errors
      send_update(AshReports.LiveView.ChartLiveComponent,
        id: chart_id,
        error: error
      )
      
      {:noreply, socket}
    end
    """
  end

  # Private implementation functions

  defp prepare_enhanced_context(%RenderContext{} = context, _opts) do
    # Enhance context with LiveView-specific metadata
    liveview_metadata = %{
      renderer_type: :heex_enhanced,
      supports_real_time: true,
      supports_interactivity: true,
      component_architecture: :liveview,
      hooks_enabled: true
    }

    enhanced_context = %{
      context
      | config:
          Map.merge(context.config, %{
            enhanced_heex: true,
            liveview_integration: true,
            real_time_capable: true
          }),
        metadata: Map.merge(context.metadata, liveview_metadata)
    }

    {:ok, enhanced_context}
  end

  defp generate_liveview_chart_components(%RenderContext{} = context) do
    # Extract chart configurations and generate LiveView components
    chart_configs = extract_chart_configs_from_context(context)

    if length(chart_configs) > 0 do
      components =
        chart_configs
        |> Enum.with_index()
        |> Enum.map(fn {chart_config, index} ->
          generate_chart_component_heex(chart_config, index, context)
        end)

      {:ok,
       %{
         components: components,
         count: length(components),
         metadata: %{
           generated_at: DateTime.utc_now(),
           total_components: length(components)
         }
       }}
    else
      {:ok, %{components: [], count: 0, metadata: %{}}}
    end
  end

  defp render_base_heex_content(%RenderContext{} = context) do
    # Use existing HEEX renderer for base content
    case HeexRenderer.render_with_context(context) do
      {:ok, result} -> {:ok, result.content}
      {:error, reason} -> {:error, "Base HEEX rendering failed: #{reason}"}
    end
  end

  defp integrate_charts_with_heex(base_heex, chart_components, %RenderContext{} = context) do
    # Integrate chart components into HEEX template
    if chart_components.count > 0 do
      chart_section = """
      <!-- Phase 6.2: LiveView Chart Components -->
      <section class="ash-liveview-charts #{if context.text_direction == "rtl", do: "rtl", else: "ltr"}">
        #{Enum.join(chart_components.components, "\n")}
      </section>
      """

      # Insert chart section into base HEEX
      enhanced_heex =
        case String.contains?(base_heex, "<body") do
          true ->
            # Insert charts before closing body tag
            String.replace(base_heex, "</body>", "#{chart_section}\n</body>")

          false ->
            # Append charts to content
            "#{base_heex}\n#{chart_section}"
        end

      # Add required hooks and CSS
      final_heex = add_liveview_assets(enhanced_heex, context)
      {:ok, final_heex}
    else
      {:ok, base_heex}
    end
  end

  defp generate_chart_component_heex(chart_config, index, %RenderContext{} = context) do
    # Generate HEEX template for LiveView chart component
    component_id = "chart_#{index}"

    """
    <%= live_component(
      AshReports.LiveView.ChartLiveComponent,
      id: "#{component_id}",
      chart_config: %{
        type: #{inspect(chart_config.type)},
        data: #{inspect(chart_config.data)},
        title: #{inspect(chart_config.title)},
        provider: #{inspect(chart_config.provider || :chartjs)},
        interactive: #{chart_config.interactive || false},
        real_time: #{chart_config.real_time || false},
        interactions: #{inspect(chart_config.interactions || [])},
        update_interval: #{chart_config.update_interval || 30_000}
      },
      locale: "#{context.locale}",
      interactive: #{chart_config.interactive || false},
      real_time: #{chart_config.real_time || false},
      dashboard_id: "#{context.metadata[:dashboard_id] || "default"}"
    ) %>
    """
  end

  defp add_liveview_assets(heex_content, %RenderContext{} = context) do
    # Add required CSS and hooks for LiveView chart components
    chart_css = ChartHooks.generate_liveview_chart_css()
    hook_registration = ChartHooks.generate_hook_registration()

    assets_section = """
    <!-- Phase 6.2: LiveView Chart Assets -->
    #{AssetManager.generate_css_links(context)}

    <style>
    #{chart_css}
    </style>

    <script type="module">
    #{hook_registration}
    </script>
    """

    # Insert assets into head section or add at beginning
    case String.contains?(heex_content, "<head>") do
      true ->
        String.replace(heex_content, "</head>", "#{assets_section}\n</head>")

      false ->
        "#{assets_section}\n#{heex_content}"
    end
  end

  defp build_enhanced_result_metadata(%RenderContext{} = context, start_time) do
    processing_time = System.monotonic_time(:microsecond) - start_time

    metadata = %{
      renderer: :heex_enhanced,
      processing_time_microseconds: processing_time,
      chart_integration: true,
      liveview_components: true,
      real_time_capable: true,
      interactive_features: true,
      generated_at: DateTime.utc_now(),
      locale: context.locale,
      text_direction: context.text_direction,
      chart_count: length(extract_chart_configs_from_context(context)),
      features: %{
        phase_5_1_integration: true,
        phase_5_2_html_foundation: true,
        phase_6_2_liveview_components: true
      }
    }

    {:ok, metadata}
  end

  # Helper functions

  defp extract_chart_configs_from_context(%RenderContext{} = context) do
    # Extract chart configurations from context metadata
    context.metadata[:chart_configs] || context.config[:charts] || []
  end

  @doc """
  Returns the MIME content type for HEEX Enhanced renderer.
  """
  @impl true
  def content_type, do: "text/html"

  @doc """
  Returns the file extension for HEEX Enhanced renderer.
  """
  @impl true
  def file_extension, do: "heex"

  @doc """
  Returns whether this renderer supports streaming.
  
  HEEX Enhanced renderer supports streaming through LiveView components.
  """
  @impl true
  def supports_streaming?, do: true
end
