# Integration Guide

This guide covers integrating AshReports with Phoenix, LiveView, and basic deployment scenarios.

> **Note**: This guide reflects current basic integration capabilities. For planned features like scheduled reports, webhook notifications, and advanced LiveView features, see [ROADMAP.md Phase 9](../../ROADMAP.md#phase-9-integration-enhancements).

## Table of Contents

- [Phoenix Integration](#phoenix-integration)
- [LiveView Integration](#liveview-integration)
- [API Endpoints](#api-endpoints)
- [Authentication and Authorization](#authentication-and-authorization)
- [Deployment Considerations](#deployment-considerations)
- [Troubleshooting](#troubleshooting)

## Phoenix Integration

### Basic Phoenix Setup

Add AshReports to your Phoenix application:

```elixir
# mix.exs
def deps do
  [
    {:ash_reports, "~> 0.1.0"},
    {:phoenix, "~> 1.7"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20"}  # Optional, for LiveView integration
  ]
end
```

### Phoenix Controller Integration

> **API Note**: AshReports provides two APIs for generating reports:
> - `AshReports.generate(domain, report, params, format)` - Simple API for basic use
> - `AshReports.Runner.run_report(domain, report, params, opts)` - Full API with additional options
>
> The examples below use `Runner.run_report` to show the full implementation pattern, but you can use the simpler `generate/4` function for basic cases.

Create a controller to handle report generation:

```elixir
defmodule MyAppWeb.ReportsController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    # List available reports
    reports = AshReports.Info.reports(MyApp.Domain)

    # Transform to displayable format
    reports_list = Enum.map(reports, fn report ->
      %{
        name: report.name,
        title: report.title,
        description: report.description
      }
    end)

    render(conn, :index, reports: reports_list)
  end

  def show(conn, %{"id" => report_name} = params) do
    report_name_atom = String.to_existing_atom(report_name)
    format = Map.get(params, "format", "html") |> String.to_existing_atom()

    # Extract report parameters from query string
    report_params = extract_report_params(params, report_name_atom)

    # Generate the report
    case AshReports.Runner.run_report(
      MyApp.Domain,
      report_name_atom,
      report_params,
      format: format
    ) do
      {:ok, result} ->
        send_report_response(conn, result, format, report_name)

      {:error, error} ->
        conn
        |> put_flash(:error, "Failed to generate report: #{inspect(error)}")
        |> redirect(to: ~p"/reports")
    end
  end

  defp extract_report_params(params, report_name) do
    # Get report definition to know which parameters to extract
    report = AshReports.Info.report(MyApp.Domain, report_name)

    # Build parameter map from query string
    Enum.reduce(report.parameters || [], %{}, fn param, acc ->
      param_key = Atom.to_string(param.name)

      if Map.has_key?(params, param_key) do
        Map.put(acc, param.name, parse_param_value(params[param_key], param.type))
      else
        acc
      end
    end)
  end

  defp parse_param_value(value, :date) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_param_value(value, :integer) do
    case Integer.parse(value) do
      {int, _} -> int
      _ -> nil
    end
  end

  defp parse_param_value(value, :decimal) do
    case Decimal.parse(value) do
      {dec, _} -> dec
      _ -> nil
    end
  end

  defp parse_param_value(value, :boolean) do
    value in ["true", "1", "yes"]
  end

  defp parse_param_value(value, _type), do: value

  defp send_report_response(conn, result, format, report_name) do
    case format do
      :html ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, result.content)

      :pdf ->
        filename = "#{report_name}_#{Date.utc_today()}.pdf"
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, result.content)

      :json ->
        json(conn, result.content)

      :heex ->
        # Warning: HEEX rendering is a work-in-progress feature and may be broken
        # HEEX is typically used with LiveView, not direct download
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, result.content)
    end
  end
end
```

### Router Configuration

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Report routes
    get "/reports", ReportsController, :index
    get "/reports/:id", ReportsController, :show
  end
end
```

### Report Parameter Form

Create a form for users to input report parameters:

```heex
<%# lib/my_app_web/controllers/reports_html/show_form.html.heex %>
<.header>
  Generate Report: <%= @report.title %>
</.header>

<div class="mt-4">
  <.form :let={f} for={%{}} action={~p"/reports/#{@report.name}"} method="get">
    <%= for param <- @report.parameters do %>
      <div class="mb-4">
        <.label for={param.name}><%= humanize(param.name) %></.label>
        <%= case param.type do %>
          <% :date -> %>
            <.input
              type="date"
              name={param.name}
              required={param.required}
            />
          <% :integer -> %>
            <.input
              type="number"
              name={param.name}
              required={param.required}
            />
          <% :boolean -> %>
            <.input
              type="checkbox"
              name={param.name}
            />
          <% _ -> %>
            <.input
              type="text"
              name={param.name}
              required={param.required}
            />
        <% end %>
      </div>
    <% end %>

    <div class="mb-4">
      <.label for="format">Output Format</.label>
      <.input type="select" name="format" options={[
        {"HTML", "html"},
        {"PDF", "pdf"},
        {"JSON", "json"}
      ]} />
    </div>

    <.button type="submit">Generate Report</.button>
  </.form>
</div>
```

## LiveView Integration

### Basic LiveView Report Viewer

> **Note**: Full LiveView integration with real-time updates and interactive features is planned. See [ROADMAP.md Phase 9](../../ROADMAP.md#phase-9-integration-enhancements). Current implementation provides basic rendering.

```elixir
defmodule MyAppWeb.ReportLive.Show do
  use MyAppWeb, :live_view

  @impl true
  def mount(%{"report_name" => report_name}, _session, socket) do
    report_name_atom = String.to_existing_atom(report_name)
    report = AshReports.Info.report(MyApp.Domain, report_name_atom)

    socket =
      socket
      |> assign(:report, report)
      |> assign(:report_name, report_name_atom)
      |> assign(:params, %{})
      |> assign(:result, nil)
      |> assign(:loading, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("generate", params, socket) do
    socket = assign(socket, :loading, true)

    # Parse parameters
    parsed_params = parse_report_params(params, socket.assigns.report)

    # Generate report asynchronously
    send(self(), {:generate_report, parsed_params})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_report, params}, socket) do
    case AshReports.Runner.run_report(
      MyApp.Domain,
      socket.assigns.report_name,
      params,
      format: :html
    ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:result, result)
         |> assign(:loading, false)
         |> assign(:error, nil)}

      {:error, error} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, inspect(error))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="report-viewer">
      <.header>
        <%= @report.title %>
        <:subtitle><%= @report.description %></:subtitle>
      </.header>

      <div class="mt-4">
        <.form for={%{}} phx-submit="generate">
          <%= for param <- @report.parameters do %>
            <div class="mb-4">
              <.label><%= humanize(param.name) %></.label>
              <%= render_param_input(param) %>
            </div>
          <% end %>

          <.button type="submit" disabled={@loading}>
            <%= if @loading, do: "Generating...", else: "Generate Report" %>
          </.button>
        </.form>
      </div>

      <%= if @error do %>
        <.error class="mt-4">
          <%= @error %>
        </.error>
      <% end %>

      <%= if @result do %>
        <div class="mt-8 report-content">
          <%= Phoenix.HTML.raw(@result.content) %>
        </div>

        <div class="mt-4 text-sm text-gray-600">
          Generated in <%= @result.metadata.execution_time_ms %>ms
        </div>
      <% end %>
    </div>
    """
  end

  defp render_param_input(param) do
    # Helper to render appropriate input for parameter type
    # Implementation depends on your form component library
  end

  defp parse_report_params(params, report) do
    # Parse form params into appropriate types
    # Similar to controller implementation
  end
end
```

### LiveView Router

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser

  live "/reports/:report_name", ReportLive.Show
  live "/reports/:report_name/interactive", ReportLive.Interactive  # Planned
end
```

## API Endpoints

### JSON API for Report Generation

```elixir
defmodule MyAppWeb.Api.ReportsController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    reports = AshReports.Info.reports(MyApp.Domain)

    reports_data = Enum.map(reports, fn report ->
      %{
        name: report.name,
        title: report.title,
        description: report.description,
        parameters: Enum.map(report.parameters || [], fn param ->
          %{
            name: param.name,
            type: param.type,
            required: param.required,
            default: param.default
          }
        end),
        formats: report.formats
      }
    end)

    json(conn, %{reports: reports_data})
  end

  def generate(conn, %{"report_name" => report_name, "parameters" => params} = req_params) do
    report_name_atom = String.to_existing_atom(report_name)
    format = Map.get(req_params, "format", "json") |> String.to_existing_atom()

    # Parse parameters
    parsed_params = parse_api_params(params)

    case AshReports.Runner.run_report(
      MyApp.Domain,
      report_name_atom,
      parsed_params,
      format: format
    ) do
      {:ok, result} ->
        case format do
          :json ->
            json(conn, %{
              success: true,
              data: result.content,
              metadata: result.metadata
            })

          :pdf ->
            conn
            |> put_resp_content_type("application/pdf")
            |> send_resp(200, result.content)

          :html ->
            conn
            |> put_resp_content_type("text/html")
            |> send_resp(200, result.content)
        end

      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: %{
            message: "Failed to generate report",
            details: inspect(error)
          }
        })
    end
  end

  defp parse_api_params(params) do
    # Convert string keys to atoms and parse values
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, String.to_existing_atom(key), value)
    end)
  end
end
```

### API Router

```elixir
# lib/my_app_web/router.ex
scope "/api", MyAppWeb.Api do
  pipe_through :api

  get "/reports", ReportsController, :index
  post "/reports/generate", ReportsController, :generate
end
```

### API Usage Examples

```bash
# List available reports
curl http://localhost:4000/api/reports

# Generate report
curl -X POST http://localhost:4000/api/reports/generate \
  -H "Content-Type: application/json" \
  -d '{
    "report_name": "sales_report",
    "parameters": {
      "start_date": "2024-01-01",
      "end_date": "2024-12-31",
      "region": "North"
    },
    "format": "json"
  }'

# Generate PDF report
curl -X POST http://localhost:4000/api/reports/generate \
  -H "Content-Type: application/json" \
  -d '{
    "report_name": "sales_report",
    "parameters": {
      "start_date": "2024-01-01",
      "end_date": "2024-12-31"
    },
    "format": "pdf"
  }' \
  --output report.pdf
```

## Authentication and Authorization

### Using Ash Authentication

If using `ash_authentication`, integrate report permissions:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :role, :atom, constraints: [one_of: [:admin, :manager, :viewer]]
  end

  # Define permissions
  def can_view_reports?(%__MODULE__{role: role}) do
    role in [:admin, :manager, :viewer]
  end

  def can_export_reports?(%__MODULE__{role: role}) do
    role in [:admin, :manager]
  end
end
```

### Controller Authorization

```elixir
defmodule MyAppWeb.ReportsController do
  use MyAppWeb, :controller

  plug :require_authenticated_user
  plug :require_report_permission when action in [:show, :generate]

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access reports")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp require_report_permission(conn, _opts) do
    user = conn.assigns.current_user

    if MyApp.Accounts.User.can_view_reports?(user) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> put_flash(:error, "You don't have permission to view reports")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end
```

### Report-Level Permissions

Check permissions in report definitions:

```elixir
report :financial_report do
  title "Financial Report"
  driving_resource MyApp.Financial.Transaction

  # Define required permissions
  permissions [:view_financial_reports, :view_sensitive_data]

  # ... rest of report definition
end
```

Then check in your controller:

```elixir
def show(conn, %{"id" => report_name} = params) do
  report_name_atom = String.to_existing_atom(report_name)
  report = AshReports.Info.report(MyApp.Domain, report_name_atom)
  user = conn.assigns.current_user

  # Check if user has required permissions
  if has_required_permissions?(user, report.permissions) do
    # Generate report...
  else
    conn
    |> put_status(:forbidden)
    |> put_flash(:error, "You don't have the required permissions for this report")
    |> redirect(to: ~p"/reports")
  end
end

defp has_required_permissions?(user, required_permissions) do
  Enum.all?(required_permissions, fn perm ->
    perm in user.permissions
  end)
end
```

## Deployment Considerations

### Environment Configuration

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :ash_reports,
    # PDF generation may require chrome/chromium in production
    pdf_renderer: System.get_env("PDF_RENDERER", "typst"),

    # Timeouts for report generation
    generation_timeout: String.to_integer(System.get_env("REPORT_TIMEOUT", "60000")),

    # Memory limits
    max_memory_mb: String.to_integer(System.get_env("REPORT_MAX_MEMORY", "512"))
end
```

### PDF Generation in Production

> **Note**: AshReports has recently transitioned from ChromicPDF to Typst for PDF generation. Ensure Typst is available in your deployment environment.

```dockerfile
# Dockerfile example
FROM elixir:1.16-alpine

# Install Typst for PDF generation
RUN apk add --no-cache typst

# ... rest of Dockerfile
```

### Performance Optimization

```elixir
# config/prod.exs
config :ash_reports,
  # Enable report caching (if implemented)
  cache_enabled: true,
  cache_ttl: :timer.minutes(15),

  # Async report generation
  async_generation: true,
  max_concurrent_reports: 5
```

### Monitoring

Basic monitoring setup:

```elixir
defmodule MyApp.Reports.Telemetry do
  def handle_event([:ash_reports, :generate, :start], measurements, metadata, _config) do
    # Log report generation start
    Logger.info("Starting report generation: #{metadata.report_name}")
  end

  def handle_event([:ash_reports, :generate, :stop], measurements, metadata, _config) do
    # Log report generation completion
    duration = measurements.duration
    Logger.info("Completed report generation: #{metadata.report_name} in #{duration}ms")
  end

  def handle_event([:ash_reports, :generate, :exception], measurements, metadata, _config) do
    # Log report generation errors
    Logger.error("Report generation failed: #{metadata.report_name} - #{inspect(metadata.reason)}")
  end
end
```

> **Note**: Telemetry integration is basic. Advanced monitoring and performance tracking are planned - see [ROADMAP.md Phase 6](../../ROADMAP.md#phase-6-monitoring-and-telemetry).

## Troubleshooting

### Common Integration Issues

**Reports not generating in production:**
- Check PDF renderer is properly installed (Typst)
- Verify memory limits are sufficient
- Check timeout settings
- Review logs for specific errors

**Slow report generation:**
- Add database indexes on group/sort fields
- Consider caching for frequently run reports
- Use streaming for large datasets (when available)
- Optimize queries and preloading

**LiveView disconnections:**
- Increase timeout for long-running reports
- Consider generating reports asynchronously
- Show progress indicators to users
- Handle disconnection gracefully

**Parameter parsing errors:**
- Validate parameter types match report definition
- Handle nil/empty values appropriately
- Provide clear error messages to users
- Use form validation before submission

## Planned Integration Features

The following features are planned for future releases:

### Scheduled Reports (Phase 9)
- Cron-style report scheduling
- Automated report delivery via email
- Report result caching

### Enhanced LiveView (Phase 9)
- Real-time report updates
- Interactive drill-down
- Client-side filtering and sorting
- Export from LiveView

### External Integrations (Phase 9)
- Webhook notifications
- Slack integration
- S3/cloud storage
- GraphQL API

See [ROADMAP.md Phase 9](../../ROADMAP.md#phase-9-integration-enhancements) for complete details.

## Next Steps

1. Review [Report Creation Guide](report-creation.md) to build reports
2. Check out [Advanced Features](advanced-features.md) for formatting options
3. Read [ROADMAP.md](../../ROADMAP.md) for upcoming integration features
4. See [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for current status

## See Also

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Ash Authentication](https://hexdocs.pm/ash_authentication/)
- [ROADMAP.md](../../ROADMAP.md) - Planned integration features
