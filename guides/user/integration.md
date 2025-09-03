# Integration Guide

This guide covers integrating AshReports with Phoenix, LiveView, external systems, APIs, and deployment scenarios.

## Table of Contents

- [Phoenix Integration](#phoenix-integration)
- [LiveView Integration](#liveview-integration)
- [API Integration](#api-integration)
- [External System Integration](#external-system-integration)
- [Authentication and Authorization](#authentication-and-authorization)
- [Deployment and Production](#deployment-and-production)
- [Troubleshooting](#troubleshooting)

## Phoenix Integration

### Basic Phoenix Setup

First, add AshReports to your Phoenix application:

```elixir
# mix.exs
def deps do
  [
    {:ash_reports, "~> 0.1.0"},
    {:phoenix, "~> 1.7"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20"}
  ]
end

# config/config.exs
config :ash_reports,
  default_domain: MyAppWeb.Domain,
  renderers: %{
    html: AshReports.HtmlRenderer,
    pdf: AshReports.PdfRenderer,
    json: AshReports.JsonRenderer,
    heex: AshReports.HeexRenderer
  }
```

### Phoenix Controller Integration

```elixir
defmodule MyAppWeb.ReportsController do
  use MyAppWeb, :controller
  
  def index(conn, _params) do
    # List available reports
    reports = AshReports.Info.reports(MyApp.Domain)
    render(conn, :index, reports: reports)
  end
  
  def show(conn, %{"id" => report_name} = params) do
    report_name = String.to_existing_atom(report_name)
    format = Map.get(params, "format", "html") |> String.to_existing_atom()
    
    # Extract report parameters from query string
    report_params = extract_report_params(params)
    
    case AshReports.generate(MyApp.Domain, report_name, report_params, format) do
      {:ok, content} ->
        send_report_response(conn, content, format, report_name)
      
      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(error)})
    end
  end
  
  def preview(conn, %{"report" => report_params}) do
    # Generate report preview with limited data
    limited_params = Map.put(report_params, "limit", 10)
    report_name = String.to_existing_atom(report_params["name"])
    
    case AshReports.generate(MyApp.Domain, report_name, limited_params, :html) do
      {:ok, html_content} ->
        json(conn, %{
          success: true,
          preview: html_content,
          message: "Preview generated successfully"
        })
      
      {:error, error} ->
        json(conn, %{
          success: false,
          error: inspect(error)
        })
    end
  end
  
  defp extract_report_params(params) do
    # Extract parameters based on report definition
    params
    |> Map.drop(["id", "format", "_format"])
    |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(k), parse_param_value(v)} end)
  end
  
  defp parse_param_value(value) when is_binary(value) do
    cond do
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, value) ->
        Date.from_iso8601!(value)
      
      Regex.match?(~r/^\d+$/, value) ->
        String.to_integer(value)
      
      Regex.match?(~r/^\d+\.\d+$/, value) ->
        Decimal.new(value)
      
      value in ["true", "false"] ->
        value == "true"
      
      true ->
        value
    end
  end
  
  defp parse_param_value(value), do: value
  
  defp send_report_response(conn, content, format, report_name) do
    case format do
      :html ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, content)
      
      :pdf ->
        filename = "#{report_name}_#{Date.utc_today()}.pdf"
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_resp(200, content)
      
      :json ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, content)
      
      :csv ->
        filename = "#{report_name}_#{Date.utc_today()}.csv"
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_resp(200, content)
    end
  end
end
```

### Phoenix Router Configuration

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  
  scope "/reports", MyAppWeb do
    pipe_through :browser
    
    # Report management routes
    get "/", ReportsController, :index
    get "/preview", ReportsController, :preview
    get "/:id", ReportsController, :show
    
    # Format-specific routes
    get "/:id/pdf", ReportsController, :show, format: :pdf
    get "/:id/csv", ReportsController, :show, format: :csv
    
    # Live report routes (see LiveView section)
    live "/live/:report_name", ReportsLive.Show, :show
    live "/dashboard", ReportsLive.Dashboard, :index
  end
  
  # API routes
  scope "/api/reports", MyAppWeb do
    pipe_through :api
    
    post "/generate", Api.ReportsController, :generate
    get "/status/:job_id", Api.ReportsController, :status
    post "/schedule", Api.ReportsController, :schedule
  end
end
```

### Phoenix Templates

```heex
<!-- lib/my_app_web/controllers/reports_html/index.html.heex -->
<div class="reports-index">
  <h1>Available Reports</h1>
  
  <div class="reports-grid">
    <%= for report <- @reports do %>
      <div class="report-card">
        <h3><%= report.title || report.name %></h3>
        <p><%= report.description %></p>
        
        <div class="report-actions">
          <%= link "View HTML", to: ~p"/reports/#{report.name}", class: "btn btn-primary" %>
          <%= link "Download PDF", to: ~p"/reports/#{report.name}/pdf", class: "btn btn-secondary" %>
          <%= link "Live View", to: ~p"/reports/live/#{report.name}", class: "btn btn-live" %>
        </div>
        
        <!-- Parameter form if report has parameters -->
        <%= if length(report.parameters) > 0 do %>
          <form class="report-params" action={~p"/reports/#{report.name}"} method="get">
            <%= for param <- report.parameters do %>
              <div class="param-input">
                <label for={"param_#{param.name}"}><%= humanize(param.name) %></label>
                <%= render_param_input(param) %>
              </div>
            <% end %>
            
            <div class="format-selector">
              <label for="format">Format:</label>
              <select name="format" id="format">
                <option value="html">HTML</option>
                <option value="pdf">PDF</option>
                <option value="json">JSON</option>
                <option value="csv">CSV</option>
              </select>
            </div>
            
            <button type="submit" class="btn btn-primary">Generate Report</button>
          </form>
        <% end %>
      </div>
    <% end %>
  </div>
</div>

<script>
  // Report parameter form handling
  document.querySelectorAll('.report-params').forEach(form => {
    form.addEventListener('submit', function(e) {
      const submitBtn = form.querySelector('button[type="submit"]');
      submitBtn.disabled = true;
      submitBtn.textContent = 'Generating...';
    });
  });
</script>
```

## LiveView Integration

### Basic LiveView Report Display

```elixir
defmodule MyAppWeb.ReportsLive.Show do
  use MyAppWeb, :live_view
  
  def mount(%{"report_name" => report_name}, _session, socket) do
    report_atom = String.to_existing_atom(report_name)
    report_info = AshReports.Info.report(MyApp.Domain, report_atom)
    
    if connected?(socket) do
      # Set up real-time updates if needed
      :timer.send_interval(30_000, self(), :refresh_data)
    end
    
    socket =
      socket
      |> assign(:report_name, report_atom)
      |> assign(:report_info, report_info)
      |> assign(:parameters, initialize_parameters(report_info.parameters))
      |> assign(:report_content, nil)
      |> assign(:loading, false)
      |> assign(:error, nil)
    
    {:ok, socket}
  end
  
  def handle_event("generate_report", %{"parameters" => params}, socket) do
    socket = assign(socket, :loading, true)
    
    # Generate report asynchronously
    Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
      AshReports.generate(
        MyApp.Domain,
        socket.assigns.report_name,
        params,
        :heex
      )
    end)
    
    {:noreply, socket}
  end
  
  def handle_event("update_parameter", %{"name" => param_name, "value" => value}, socket) do
    param_atom = String.to_existing_atom(param_name)
    parsed_value = parse_parameter_value(value, param_atom, socket.assigns.report_info)
    
    updated_params = Map.put(socket.assigns.parameters, param_atom, parsed_value)
    
    {:noreply, assign(socket, :parameters, updated_params)}
  end
  
  def handle_event("export_report", %{"format" => format}, socket) do
    if socket.assigns.report_content do
      format_atom = String.to_existing_atom(format)
      
      Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
        AshReports.generate(
          MyApp.Domain,
          socket.assigns.report_name,
          socket.assigns.parameters,
          format_atom
        )
      end)
      
      {:noreply, push_event(socket, "download_preparing", %{format: format})}
    else
      {:noreply, put_flash(socket, :error, "Please generate the report first")}
    end
  end
  
  def handle_info(:refresh_data, socket) do
    # Auto-refresh report data if it's currently displayed
    if socket.assigns.report_content && not socket.assigns.loading do
      send(self(), {:generate_report, socket.assigns.parameters})
    end
    
    {:noreply, socket}
  end
  
  def handle_info({_task_ref, {:ok, report_content}}, socket) do
    socket =
      socket
      |> assign(:report_content, report_content)
      |> assign(:loading, false)
      |> assign(:error, nil)
    
    {:noreply, socket}
  end
  
  def handle_info({_task_ref, {:error, error}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error, inspect(error))
    
    {:noreply, socket}
  end
  
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task completed or crashed
    {:noreply, assign(socket, :loading, false)}
  end
  
  defp initialize_parameters(param_definitions) do
    Enum.into(param_definitions, %{}, fn param ->
      {param.name, param.default}
    end)
  end
  
  defp parse_parameter_value(value, param_name, report_info) do
    param_def = Enum.find(report_info.parameters, &(&1.name == param_name))
    
    case param_def.type do
      :date -> Date.from_iso8601!(value)
      :integer -> String.to_integer(value)
      :decimal -> Decimal.new(value)
      :boolean -> value == "true"
      _ -> value
    end
  end
end
```

### LiveView Template

```heex
<!-- lib/my_app_web/live/reports_live/show.html.heex -->
<div class="live-report-container">
  <div class="report-header">
    <h1><%= @report_info.title || @report_name %></h1>
    <p class="report-description"><%= @report_info.description %></p>
  </div>
  
  <!-- Parameter Controls -->
  <div class="report-controls">
    <h3>Report Parameters</h3>
    
    <form phx-change="update_parameter" phx-submit="generate_report">
      <%= for param <- @report_info.parameters do %>
        <div class="parameter-control">
          <label for={"param_#{param.name}"}><%= humanize(param.name) %></label>
          
          <%= case param.type do %>
            <% :date -> %>
              <input 
                type="date" 
                id={"param_#{param.name}"}
                name={"parameters[#{param.name}]"}
                value={@parameters[param.name]}
                phx-debounce="500"
              />
            
            <% :integer -> %>
              <input 
                type="number" 
                id={"param_#{param.name}"}
                name={"parameters[#{param.name}]"}
                value={@parameters[param.name]}
                phx-debounce="500"
              />
            
            <% :boolean -> %>
              <input 
                type="checkbox" 
                id={"param_#{param.name}"}
                name={"parameters[#{param.name}]"}
                checked={@parameters[param.name]}
              />
            
            <% _ -> %>
              <input 
                type="text" 
                id={"param_#{param.name}"}
                name={"parameters[#{param.name}]"}
                value={@parameters[param.name]}
                phx-debounce="500"
              />
          <% end %>
        </div>
      <% end %>
      
      <div class="control-actions">
        <button 
          type="submit" 
          class="btn btn-primary"
          disabled={@loading}
        >
          <%= if @loading, do: "Generating...", else: "Generate Report" %>
        </button>
        
        <%= if @report_content do %>
          <button 
            type="button" 
            phx-click="export_report"
            phx-value-format="pdf"
            class="btn btn-secondary"
          >
            Export PDF
          </button>
          
          <button 
            type="button" 
            phx-click="export_report"
            phx-value-format="csv"
            class="btn btn-secondary"
          >
            Export CSV
          </button>
        <% end %>
      </div>
    </form>
  </div>
  
  <!-- Loading Indicator -->
  <%= if @loading do %>
    <div class="loading-container">
      <div class="spinner"></div>
      <p>Generating report...</p>
    </div>
  <% end %>
  
  <!-- Error Display -->
  <%= if @error do %>
    <div class="error-container">
      <h3>Error Generating Report</h3>
      <pre><%= @error %></pre>
    </div>
  <% end %>
  
  <!-- Report Content -->
  <%= if @report_content do %>
    <div class="report-content">
      <%= raw(@report_content) %>
    </div>
  <% end %>
</div>

<style>
  .live-report-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
  }
  
  .report-controls {
    background: #f8f9fa;
    padding: 20px;
    border-radius: 8px;
    margin-bottom: 20px;
  }
  
  .parameter-control {
    margin-bottom: 15px;
  }
  
  .parameter-control label {
    display: block;
    font-weight: bold;
    margin-bottom: 5px;
  }
  
  .parameter-control input {
    width: 100%;
    max-width: 300px;
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 4px;
  }
  
  .control-actions {
    margin-top: 20px;
  }
  
  .control-actions button {
    margin-right: 10px;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }
  
  .btn-primary {
    background: #007bff;
    color: white;
  }
  
  .btn-secondary {
    background: #6c757d;
    color: white;
  }
  
  .loading-container {
    text-align: center;
    padding: 40px;
  }
  
  .spinner {
    border: 4px solid #f3f3f3;
    border-top: 4px solid #3498db;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 2s linear infinite;
    margin: 0 auto 20px;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .error-container {
    background: #f8d7da;
    color: #721c24;
    padding: 20px;
    border-radius: 4px;
    margin-bottom: 20px;
  }
  
  .report-content {
    background: white;
    border: 1px solid #ddd;
    border-radius: 4px;
    overflow-x: auto;
  }
</style>
```

### Interactive Dashboard LiveView

```elixir
defmodule MyAppWeb.ReportsLive.Dashboard do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(60_000, self(), :update_dashboard)  # Update every minute
    end
    
    socket =
      socket
      |> assign(:selected_filters, %{})
      |> assign(:dashboard_tiles, [])
      |> assign(:real_time_data, %{})
      |> load_dashboard_data()
    
    {:ok, socket}
  end
  
  def handle_event("filter_change", %{"filter" => filter, "value" => value}, socket) do
    updated_filters = Map.put(socket.assigns.selected_filters, filter, value)
    
    socket =
      socket
      |> assign(:selected_filters, updated_filters)
      |> load_dashboard_data()
    
    {:noreply, socket}
  end
  
  def handle_event("refresh_tile", %{"tile_id" => tile_id}, socket) do
    # Refresh specific dashboard tile
    Task.async(fn ->
      refresh_dashboard_tile(tile_id, socket.assigns.selected_filters)
    end)
    
    {:noreply, socket}
  end
  
  def handle_event("drill_down", %{"report" => report_name, "filters" => filters}, socket) do
    # Navigate to detailed report with filters
    {:noreply, 
     push_navigate(socket, 
       to: ~p"/reports/live/#{report_name}?#{URI.encode_query(filters)}")
    }
  end
  
  def handle_info(:update_dashboard, socket) do
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end
  
  def handle_info({_ref, {:tile_updated, tile_id, data}}, socket) do
    updated_tiles = 
      Enum.map(socket.assigns.dashboard_tiles, fn tile ->
        if tile.id == tile_id, do: %{tile | data: data}, else: tile
      end)
    
    {:noreply, assign(socket, :dashboard_tiles, updated_tiles)}
  end
  
  defp load_dashboard_data(socket) do
    # Generate multiple summary reports for dashboard tiles
    tiles = [
      generate_kpi_tile("revenue_summary", socket.assigns.selected_filters),
      generate_chart_tile("monthly_trend", socket.assigns.selected_filters),
      generate_table_tile("top_customers", socket.assigns.selected_filters),
      generate_gauge_tile("performance_metrics", socket.assigns.selected_filters)
    ]
    
    assign(socket, :dashboard_tiles, tiles)
  end
  
  defp generate_kpi_tile(tile_id, filters) do
    # Generate KPI summary report
    {:ok, data} = AshReports.generate(
      MyApp.Domain,
      :kpi_summary,
      filters,
      :json
    )
    
    %{
      id: tile_id,
      type: :kpi,
      title: "Revenue Summary",
      data: Jason.decode!(data),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp generate_chart_tile(tile_id, filters) do
    {:ok, chart_data} = AshReports.generate(
      MyApp.Domain,
      :monthly_trend_chart,
      filters,
      :json
    )
    
    %{
      id: tile_id,
      type: :chart,
      title: "Monthly Trend",
      data: Jason.decode!(chart_data),
      chart_config: %{
        type: :line,
        responsive: true
      },
      last_updated: DateTime.utc_now()
    }
  end
end
```

## API Integration

### REST API for Reports

```elixir
defmodule MyAppWeb.Api.ReportsController do
  use MyAppWeb, :controller
  
  def generate(conn, params) do
    with {:ok, validated_params} <- validate_generation_request(params),
         {:ok, report_content} <- generate_report(validated_params) do
      
      json(conn, %{
        success: true,
        report: %{
          name: validated_params.report_name,
          format: validated_params.format,
          generated_at: DateTime.utc_now(),
          content: report_content
        }
      })
    else
      {:error, :validation_error, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, errors: errors})
      
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: inspect(reason)})
    end
  end
  
  def generate_async(conn, params) do
    with {:ok, validated_params} <- validate_generation_request(params) do
      # Start background job
      job_id = UUID.uuid4()
      
      Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
        result = generate_report(validated_params)
        
        # Store result in cache or database
        MyApp.ReportCache.store(job_id, result)
        
        # Optionally notify via webhook
        if webhook_url = validated_params[:webhook_url] do
          notify_completion(webhook_url, job_id, result)
        end
      end)
      
      conn
      |> put_status(:accepted)
      |> json(%{
        success: true,
        job_id: job_id,
        status: "processing",
        status_url: Routes.api_reports_url(conn, :status, job_id)
      })
    else
      {:error, :validation_error, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, errors: errors})
    end
  end
  
  def status(conn, %{"job_id" => job_id}) do
    case MyApp.ReportCache.get(job_id) do
      {:ok, {:completed, result}} ->
        json(conn, %{
          status: "completed",
          result: result,
          completed_at: DateTime.utc_now()
        })
      
      {:ok, {:error, reason}} ->
        json(conn, %{
          status: "failed",
          error: inspect(reason),
          failed_at: DateTime.utc_now()
        })
      
      {:error, :not_found} ->
        # Check if job is still processing
        if MyApp.TaskRegistry.job_exists?(job_id) do
          json(conn, %{status: "processing"})
        else
          conn
          |> put_status(:not_found)
          |> json(%{error: "Job not found"})
        end
    end
  end
  
  def schedule(conn, params) do
    with {:ok, schedule_params} <- validate_schedule_request(params),
         {:ok, scheduled_job} <- MyApp.ReportScheduler.schedule_report(schedule_params) do
      
      json(conn, %{
        success: true,
        scheduled_job: %{
          id: scheduled_job.id,
          report_name: scheduled_job.report_name,
          schedule: scheduled_job.cron_expression,
          next_run: scheduled_job.next_run_at
        }
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: inspect(reason)})
    end
  end
  
  defp validate_generation_request(params) do
    required_fields = [:report_name, :format]
    
    case validate_required_fields(params, required_fields) do
      :ok ->
        {:ok, %{
          report_name: String.to_existing_atom(params["report_name"]),
          format: String.to_existing_atom(params["format"]),
          parameters: params["parameters"] || %{},
          webhook_url: params["webhook_url"]
        }}
      
      {:error, missing_fields} ->
        {:error, :validation_error, %{missing_fields: missing_fields}}
    end
  rescue
    ArgumentError ->
      {:error, :validation_error, %{invalid_report_or_format: "Unknown report name or format"}}
  end
  
  defp generate_report(%{report_name: report_name, format: format, parameters: parameters}) do
    AshReports.generate(MyApp.Domain, report_name, parameters, format)
  end
  
  defp notify_completion(webhook_url, job_id, result) do
    payload = %{
      job_id: job_id,
      status: if(match?({:ok, _}, result), do: "completed", else: "failed"),
      result: result,
      timestamp: DateTime.utc_now()
    }
    
    HTTPoison.post(webhook_url, Jason.encode!(payload), [
      {"Content-Type", "application/json"}
    ])
  end
end
```

### GraphQL Integration

```elixir
defmodule MyAppWeb.Schema.Reports do
  use Absinthe.Schema.Notation
  
  object :report_info do
    field :name, non_null(:string)
    field :title, :string
    field :description, :string
    field :parameters, list_of(:parameter_info)
    field :formats, list_of(:string)
  end
  
  object :parameter_info do
    field :name, non_null(:string)
    field :type, non_null(:string)
    field :required, non_null(:boolean)
    field :default_value, :string
  end
  
  object :report_result do
    field :success, non_null(:boolean)
    field :content, :string
    field :format, non_null(:string)
    field :generated_at, non_null(:datetime)
    field :error, :string
  end
  
  object :reports_queries do
    field :reports, list_of(:report_info) do
      description "List all available reports"
      resolve &list_reports/3
    end
    
    field :report, :report_info do
      description "Get information about a specific report"
      arg :name, non_null(:string)
      resolve &get_report_info/3
    end
    
    field :generate_report, :report_result do
      description "Generate a report with given parameters"
      arg :name, non_null(:string)
      arg :format, non_null(:string), default_value: "json"
      arg :parameters, :json
      resolve &generate_report/3
    end
  end
  
  defp list_reports(_parent, _args, _resolution) do
    reports = AshReports.Info.reports(MyApp.Domain)
    
    report_infos = 
      Enum.map(reports, fn report ->
        %{
          name: to_string(report.name),
          title: report.title,
          description: report.description,
          parameters: format_parameters(report.parameters),
          formats: Enum.map(report.formats, &to_string/1)
        }
      end)
    
    {:ok, report_infos}
  end
  
  defp get_report_info(_parent, %{name: report_name}, _resolution) do
    try do
      report_atom = String.to_existing_atom(report_name)
      report = AshReports.Info.report(MyApp.Domain, report_atom)
      
      {:ok, %{
        name: report_name,
        title: report.title,
        description: report.description,
        parameters: format_parameters(report.parameters),
        formats: Enum.map(report.formats, &to_string/1)
      }}
    rescue
      ArgumentError ->
        {:error, "Report not found: #{report_name}"}
    end
  end
  
  defp generate_report(_parent, args, _resolution) do
    try do
      report_atom = String.to_existing_atom(args.name)
      format_atom = String.to_existing_atom(args.format)
      parameters = args[:parameters] || %{}
      
      case AshReports.generate(MyApp.Domain, report_atom, parameters, format_atom) do
        {:ok, content} ->
          {:ok, %{
            success: true,
            content: content,
            format: args.format,
            generated_at: DateTime.utc_now()
          }}
        
        {:error, error} ->
          {:ok, %{
            success: false,
            error: inspect(error),
            format: args.format,
            generated_at: DateTime.utc_now()
          }}
      end
    rescue
      ArgumentError ->
        {:error, "Invalid report name or format"}
    end
  end
  
  defp format_parameters(parameters) do
    Enum.map(parameters, fn param ->
      %{
        name: to_string(param.name),
        type: to_string(param.type),
        required: param.required,
        default_value: if(param.default, do: to_string(param.default))
      }
    end)
  end
end

# Add to your main schema
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  
  import_types MyAppWeb.Schema.Reports
  
  query do
    import_fields :reports_queries
  end
end
```

## External System Integration

### Webhook Integration

```elixir
defmodule MyApp.Reports.WebhookIntegration do
  @moduledoc "Integration with external systems via webhooks"
  
  def setup_webhook_handlers do
    # Register webhook handlers for various events
    AshReports.EventBus.subscribe(:report_generated, &handle_report_generated/1)
    AshReports.EventBus.subscribe(:report_failed, &handle_report_failed/1)
  end
  
  defp handle_report_generated(event) do
    %{
      report_name: report_name,
      parameters: parameters,
      format: format,
      content: content,
      user_id: user_id
    } = event
    
    # Send to configured webhook endpoints
    webhooks = get_webhooks_for_event(:report_generated, report_name)
    
    Enum.each(webhooks, fn webhook ->
      payload = %{
        event: "report.generated",
        report: %{
          name: report_name,
          format: format,
          parameters: parameters
        },
        user_id: user_id,
        timestamp: DateTime.utc_now(),
        content_url: generate_content_url(content)
      }
      
      send_webhook(webhook.url, payload, webhook.secret)
    end)
  end
  
  defp handle_report_failed(event) do
    %{
      report_name: report_name,
      error: error,
      user_id: user_id
    } = event
    
    webhooks = get_webhooks_for_event(:report_failed, report_name)
    
    Enum.each(webhooks, fn webhook ->
      payload = %{
        event: "report.failed",
        report: %{name: report_name},
        error: inspect(error),
        user_id: user_id,
        timestamp: DateTime.utc_now()
      }
      
      send_webhook(webhook.url, payload, webhook.secret)
    end)
  end
  
  defp send_webhook(url, payload, secret) do
    headers = [
      {"Content-Type", "application/json"},
      {"X-Webhook-Signature", generate_signature(payload, secret)}
    ]
    
    Task.start(fn ->
      case HTTPoison.post(url, Jason.encode!(payload), headers, [timeout: 10_000]) do
        {:ok, %HTTPoison.Response{status_code: status}} when status in 200..299 ->
          :ok
        
        {:ok, response} ->
          Logger.warn("Webhook failed", url: url, status: response.status_code)
        
        {:error, error} ->
          Logger.error("Webhook error", url: url, error: inspect(error))
      end
    end)
  end
  
  defp generate_signature(payload, secret) do
    :crypto.mac(:hmac, :sha256, secret, Jason.encode!(payload))
    |> Base.encode16(case: :lower)
  end
end
```

### Slack Integration

```elixir
defmodule MyApp.Reports.SlackIntegration do
  @slack_webhook_url System.get_env("SLACK_WEBHOOK_URL")
  
  def send_report_notification(report_name, status, details \\ %{}) do
    message = build_slack_message(report_name, status, details)
    send_to_slack(message)
  end
  
  def send_report_summary(report_name, summary_data) do
    blocks = [
      %{
        "type" => "header",
        "text" => %{
          "type" => "plain_text",
          "text" => "📊 Report Summary: #{humanize_report_name(report_name)}"
        }
      },
      %{
        "type" => "section",
        "fields" => format_summary_fields(summary_data)
      },
      %{
        "type" => "actions",
        "elements" => [
          %{
            "type" => "button",
            "text" => %{"type" => "plain_text", "text" => "View Full Report"},
            "url" => "#{MyAppWeb.Endpoint.url()}/reports/#{report_name}"
          }
        ]
      }
    ]
    
    send_to_slack(%{"blocks" => blocks})
  end
  
  defp build_slack_message(report_name, :completed, details) do
    %{
      "text" => "✅ Report Generated Successfully",
      "attachments" => [
        %{
          "color" => "good",
          "fields" => [
            %{"title" => "Report", "value" => humanize_report_name(report_name), "short" => true},
            %{"title" => "Generated At", "value" => DateTime.utc_now() |> DateTime.to_string(), "short" => true},
            %{"title" => "Format", "value" => String.upcase(to_string(details[:format] || "HTML")), "short" => true},
            %{"title" => "Records", "value" => to_string(details[:record_count] || "N/A"), "short" => true}
          ],
          "actions" => [
            %{
              "type" => "button",
              "text" => "View Report",
              "url" => "#{MyAppWeb.Endpoint.url()}/reports/#{report_name}"
            }
          ]
        }
      ]
    }
  end
  
  defp build_slack_message(report_name, :failed, details) do
    %{
      "text" => "❌ Report Generation Failed",
      "attachments" => [
        %{
          "color" => "danger",
          "fields" => [
            %{"title" => "Report", "value" => humanize_report_name(report_name), "short" => true},
            %{"title" => "Failed At", "value" => DateTime.utc_now() |> DateTime.to_string(), "short" => true},
            %{"title" => "Error", "value" => to_string(details[:error]), "short" => false}
          ]
        }
      ]
    }
  end
  
  defp send_to_slack(payload) when is_map(payload) do
    if @slack_webhook_url do
      HTTPoison.post(@slack_webhook_url, Jason.encode!(payload), [
        {"Content-Type", "application/json"}
      ])
    else
      Logger.warn("Slack webhook URL not configured")
    end
  end
  
  defp format_summary_fields(summary_data) do
    summary_data
    |> Enum.map(fn {key, value} ->
      %{
        "type" => "mrkdwn",
        "text" => "*#{humanize_key(key)}:*\n#{format_value(value)}"
      }
    end)
  end
  
  defp humanize_report_name(report_name) do
    report_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp humanize_key(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
  
  defp format_value(value) when is_number(value), do: Number.Delimit.number_to_delimited(value)
  defp format_value(value), do: to_string(value)
end
```

## Authentication and Authorization

### Phoenix Authentication Integration

```elixir
defmodule MyApp.Reports.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_current_user(conn) do
      %{} = user ->
        conn
        |> assign(:current_user, user)
        |> assign(:report_permissions, get_user_report_permissions(user))
      
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
    end
  end
  
  defp get_current_user(conn) do
    # Integration with your authentication system
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        MyApp.Auth.verify_token(token)
      
      _ ->
        # Try session-based auth
        get_session(conn, :current_user_id)
        |> case do
          nil -> nil
          user_id -> MyApp.Accounts.get_user!(user_id)
        end
    end
  end
  
  defp get_user_report_permissions(user) do
    # Get user's report permissions from your authorization system
    MyApp.Authorization.get_user_permissions(user, :reports)
  end
end

# Authorization functions for use in reports
defmodule MyApp.Reports.Authorization do
  def can_view_report?(user, report_name) do
    user_permissions = get_user_report_permissions(user)
    
    # Check specific report permission
    "view_#{report_name}" in user_permissions or
    # Or general report viewing permission
    "view_all_reports" in user_permissions or
    # Or admin permission
    "admin" in user_permissions
  end
  
  def can_export_report?(user, report_name, format) do
    can_view_report?(user, report_name) and
    ("export_reports" in get_user_report_permissions(user) or
     "admin" in get_user_report_permissions(user))
  end
  
  def filter_report_data_for_user(query, user, report_name) do
    case get_data_access_level(user, report_name) do
      :all -> query
      :department -> filter_by_department(query, user.department_id)
      :own -> filter_by_user(query, user.id)
      :none -> exclude_all(query)
    end
  end
  
  defp get_data_access_level(user, report_name) do
    permissions = get_user_report_permissions(user)
    
    cond do
      "admin" in permissions -> :all
      "view_department_#{report_name}" in permissions -> :department
      "view_own_#{report_name}" in permissions -> :own
      true -> :none
    end
  end
end
```

## Deployment and Production

### Production Configuration

```elixir
# config/prod.exs
config :ash_reports,
  # Production renderer configuration
  renderers: %{
    html: AshReports.HtmlRenderer,
    pdf: {AshReports.PdfRenderer, [chrome_path: "/usr/bin/chromium"]},
    json: AshReports.JsonRenderer,
    heex: AshReports.HeexRenderer
  },
  
  # Performance settings
  performance: [
    max_concurrent_reports: 10,
    report_timeout: :timer.minutes(10),
    memory_limit: "2GB"
  ],
  
  # Caching configuration
  cache: [
    compiled_reports: [
      adapter: AshReports.Cache.ETS,
      ttl: :timer.hours(24),
      max_size: 1000
    ],
    generated_reports: [
      adapter: AshReports.Cache.Redis,
      url: System.get_env("REDIS_URL"),
      ttl: :timer.minutes(30),
      key_prefix: "ash_reports:"
    ]
  ],
  
  # Storage for large reports
  storage: [
    adapter: AshReports.Storage.S3,
    bucket: System.get_env("S3_BUCKET"),
    region: System.get_env("AWS_REGION"),
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")
  ],
  
  # Monitoring
  telemetry: [
    enabled: true,
    metrics_reporter: MyApp.TelemetryReporter
  ]

# Supervisor configuration
defmodule MyApp.Application do
  def start(_type, _args) do
    children = [
      # ... other children
      
      # Report task supervisor
      {Task.Supervisor, name: MyApp.ReportTaskSupervisor},
      
      # Report cache
      {AshReports.Cache, name: MyApp.ReportCache},
      
      # Report scheduler
      MyApp.ReportScheduler,
      
      # Webhook sender
      MyApp.WebhookSender
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### Docker Configuration

```dockerfile
# Dockerfile
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    npm \
    nodejs \
    python3

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application files
COPY . .

# Compile the application
RUN mix compile
RUN mix assets.deploy
RUN mix phx.digest
RUN mix release

# Production image
FROM alpine:3.18

# Install runtime dependencies including Chrome for PDF generation
RUN apk add --no-cache \
    bash \
    openssl \
    ncurses-libs \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Create app user
RUN adduser -D -s /bin/bash app
USER app
WORKDIR /home/app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/myapp ./

# Set environment
ENV HOME=/home/app
ENV CHROME_BIN=/usr/bin/chromium-browser

EXPOSE 4000

CMD ["./bin/myapp", "start"]
```

### Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ash-reports-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ash-reports-app
  template:
    metadata:
      labels:
        app: ash-reports-app
    spec:
      containers:
      - name: app
        image: myapp:latest
        ports:
        - containerPort: 4000
        env:
        - name: PORT
          value: "4000"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: redis-url
        - name: S3_BUCKET
          value: "my-reports-bucket"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 60
          periodSeconds: 30

---
apiVersion: v1
kind: Service
metadata:
  name: ash-reports-service
spec:
  selector:
    app: ash-reports-app
  ports:
  - port: 80
    targetPort: 4000
  type: LoadBalancer
```

## Troubleshooting

### Common Issues and Solutions

#### Performance Issues
```elixir
# Monitor report generation performance
defmodule MyApp.Reports.PerformanceMonitor do
  def track_slow_reports do
    :telemetry.attach(
      "slow-report-tracker",
      [:ash_reports, :report, :generation, :stop],
      fn _name, measurements, metadata, _config ->
        if measurements.duration > 30_000 do  # > 30 seconds
          Logger.warn("Slow report detected",
            report: metadata.report_name,
            duration: measurements.duration,
            parameters: metadata.parameters
          )
          
          # Store for analysis
          MyApp.Analytics.record_slow_report(metadata, measurements)
        end
      end,
      nil
    )
  end
end

# Optimize queries for better performance
report :optimized_report do
  # Use database-level aggregations
  driving_resource MyApp.Invoice
  
  # Pre-filter data
  scope expr(date >= ^Date.add(Date.utc_today(), -90))
  
  # Limit related data loading
  preload [:customer]  # Only load what's needed
  
  # Use streaming for large datasets
  streaming enabled: true, chunk_size: 1000
end
```

#### Memory Issues
```elixir
# Monitor memory usage
defmodule MyApp.Reports.MemoryMonitor do
  def setup_memory_monitoring do
    :timer.send_interval(30_000, self(), :check_memory)
  end
  
  def handle_info(:check_memory, state) do
    memory_mb = :erlang.memory(:total) / (1024 * 1024)
    
    if memory_mb > 1000 do  # > 1GB
      Logger.warn("High memory usage detected", memory_mb: memory_mb)
      :erlang.garbage_collect()
    end
    
    {:noreply, state}
  end
end

# Memory-efficient report configuration
report :memory_efficient_report do
  # Use streaming
  streaming enabled: true
  
  # Limit precision for numbers
  format_specs do
    format_spec :efficient_decimal do
      precision 2  # Limit decimal places
    end
  end
  
  # Process in smaller batches
  bands do
    band :details do
      type :detail
      batch_size 500  # Process 500 records at a time
    end
  end
end
```

#### PDF Generation Issues
```elixir
# Debug PDF generation
defmodule MyApp.Reports.PdfDebug do
  def debug_pdf_generation(report_name, params) do
    # First generate HTML version
    {:ok, html_content} = AshReports.generate(MyApp.Domain, report_name, params, :html)
    
    # Save HTML for debugging
    File.write!("/tmp/debug_report.html", html_content)
    
    # Try PDF generation with detailed error logging
    case AshReports.generate(MyApp.Domain, report_name, params, :pdf) do
      {:ok, pdf_content} ->
        Logger.info("PDF generation successful")
        {:ok, pdf_content}
      
      {:error, error} ->
        Logger.error("PDF generation failed", 
          error: inspect(error),
          html_file: "/tmp/debug_report.html"
        )
        {:error, error}
    end
  end
end

# PDF renderer configuration for debugging
config :ash_reports, AshReports.PdfRenderer,
  chrome_args: [
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--disable-gpu",
    "--remote-debugging-port=9222",  # Enable debugging
    "--enable-logging",
    "--log-level=0"
  ],
  timeout: 30_000,  # Increase timeout
  debug: true
```

This integration guide provides comprehensive examples for integrating AshReports with Phoenix applications, external systems, and production deployments, along with troubleshooting guidance for common issues.