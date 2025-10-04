# Stage 4 Section 4.1: LiveView Report Builder - Planning Document

**Date**: 2025-10-04
**Status**: Planning
**Dependencies**: Stage 2 (GenStage Streaming), Stage 3 (Visualization System)
**Duration Estimate**: 2-3 weeks

---

## Problem Statement

The AshReports system currently lacks a modern, interactive web interface for report building and generation. Users need:

1. **Interactive Report Designer** - A LiveView-based UI for creating and configuring reports without writing DSL code
2. **Real-time Progress Tracking** - Live feedback during report generation with the ability to monitor, pause, and cancel long-running operations
3. **Template Management** - Visual template selection and customization interface
4. **Data Source Configuration** - Drag-and-drop or form-based data source and visualization setup
5. **Collaborative Features** - Multi-user support for shared report building and viewing

Currently, report creation requires manual DSL coding, and there's no built-in UI for monitoring report generation progress, especially for large datasets processed through the GenStage streaming pipeline.

---

## Solution Overview

Implement a comprehensive Phoenix LiveView-based report builder with two main components:

### 4.1.1 Interactive Report Designer (ReportBuilderLive)
A full-featured LiveView module providing:
- Template selection interface with visual previews
- Data source configuration with Ash resource browsing
- Drag-and-drop field and visualization configuration
- Real-time report preview with live data sampling
- Collaborative editing with Phoenix Presence

### 4.1.2 Progress Tracking System
A robust progress monitoring system featuring:
- Real-time progress bars with WebSocket updates
- Background task management using existing Task.Supervisor
- Stream control (pause, resume, cancel) integration with GenStage pipeline
- Notification system for completion/errors
- Multi-report tracking dashboard

---

## Agent Consultations Performed

### 1. Research Agent Consultation: Phoenix LiveView Best Practices

**Objective**: Research Phoenix LiveView patterns for real-time interfaces, WebSocket progress tracking, and background job management.

**Findings**:

#### Phoenix LiveView Real-Time Patterns
- **LiveView Component Architecture**: Use `Phoenix.LiveView.Component` for reusable UI components with isolated state
- **Server-side rendering**: LiveView maintains state on server, reducing client complexity
- **WebSocket Efficiency**: LiveView automatically batches updates and optimizes diff patching
- **PubSub Integration**: Use `Phoenix.PubSub` for broadcasting updates across LiveView processes

**Best Practices Identified**:
1. **Stateful Components**: Use `live_component` for complex, stateful UI sections (chart configurator, data source selector)
2. **Handle Info Pattern**: Use `handle_info/2` for async updates (progress, completion events)
3. **Assigns Pattern**: Keep assigns minimal and normalized; avoid deeply nested structures
4. **Event Batching**: Batch related events to reduce message passing overhead

**Code Pattern Example**:
```elixir
def handle_info({:report_progress, report_id, progress}, socket) do
  {:noreply,
   socket
   |> update(:reports, fn reports ->
     Map.update(reports, report_id, %{}, fn report ->
       Map.put(report, :progress, progress)
     end)
   end)
   |> push_event("update_progress_bar", %{report_id: report_id, progress: progress})}
end
```

#### Background Job Management in Phoenix

**Research Summary**: Phoenix doesn't require Oban for this use case. The existing supervision tree provides:
- `Task.Supervisor` for supervised async tasks (already in use in codebase)
- `DynamicSupervisor` for managing variable number of workers
- `Registry` for process tracking (already implemented in `StreamingPipeline.Registry`)

**Recommendation**: Leverage existing `StreamingPipeline` infrastructure instead of adding Oban:
- Use `Task.Supervisor` for report generation tasks
- Integrate with existing `StreamingPipeline.Registry` for status tracking
- Use GenStage pipeline control functions (`pause_pipeline/1`, `stop_pipeline/1`)

**Integration Pattern**:
```elixir
# Start report generation task
{:ok, task} = Task.Supervisor.start_child(AshReports.TaskSupervisor, fn ->
  # Start streaming pipeline
  {:ok, stream_id} = StreamingPipeline.start_pipeline(query, report_config, opts)

  # Monitor progress via Registry
  monitor_and_report_progress(stream_id, socket_pid)
end)
```

#### WebSocket Progress Tracking Patterns

**Phoenix LiveView Progress Patterns**:
1. **Push Events**: Use `push_event/3` for client-side JavaScript updates
2. **Assign Updates**: Server-side state changes trigger automatic re-renders
3. **Telemetry Integration**: Subscribe to telemetry events for progress metrics

**Existing Telemetry Events in Codebase**:
- `[:ash_reports, :streaming, :producer_consumer, :batch_transformed]` - batch progress
- `[:ash_reports, :charts, :generate, :stop]` - chart completion
- Custom events for report milestones

**Progress Tracking Implementation**:
```elixir
# Subscribe to telemetry in mount
:telemetry.attach(
  "report-progress-#{report_id}",
  [:ash_reports, :streaming, :producer_consumer, :batch_transformed],
  &handle_telemetry_event/4,
  %{socket_pid: self(), report_id: report_id}
)

defp handle_telemetry_event(_event, measurements, metadata, config) do
  send(config.socket_pid, {:progress_update, config.report_id, measurements})
end
```

#### Collaborative Editing Patterns

**Phoenix Presence Integration**:
- Use `Phoenix.Presence` for user tracking (already implemented in `AshReports.Presence`)
- Track cursors, selections, and active editing states
- Broadcast user actions via PubSub

**Existing Pattern in Codebase** (`lib/ash_reports/presence.ex`):
```elixir
# Already implemented:
def track_dashboard_user(socket, dashboard_id, user_info) do
  track(socket, "dashboard:#{dashboard_id}", user_info.user_id, %{
    name: user_info.name,
    joined_at: DateTime.utc_now(),
    locale: user_info.locale
  })
end
```

**Recommendation**: Extend existing `AshReports.Presence` module for report builder collaboration.

---

### 2. Elixir Expert Consultation: Phoenix LiveView & AshPhoenix Patterns

**Objective**: Understand Phoenix LiveView component architecture, AshPhoenix integration, real-time streaming, and PubSub patterns.

**Findings**:

#### Phoenix LiveView Component Architecture

**LiveView Best Practices** (from usage rules and existing codebase):

1. **Component Hierarchy**:
   - **LiveView** (top-level): Manages page lifecycle, routing, session
   - **LiveComponent**: Stateful, reusable UI sections with isolated updates
   - **Function Components**: Stateless, pure rendering functions

2. **State Management Patterns**:
   - Keep state in assigns, not process dictionary
   - Use `update/3` in LiveComponents for granular state updates
   - Avoid circular dependencies between components

3. **Existing LiveView Pattern** (from `lib/ash_reports/live_view/dashboard_live.ex`):
```elixir
# Mount pattern
def mount(_params, session, socket) do
  dashboard_config = parse_dashboard_config(params, session)

  socket =
    socket
    |> assign(:dashboard_id, dashboard_config.dashboard_id)
    |> assign(:charts, %{})
    |> assign(:real_time_enabled, dashboard_config.real_time || false)

  # Setup subscriptions
  if socket.assigns.real_time_enabled do
    :ok = setup_real_time_subscriptions(socket)
  end

  {:ok, socket}
end
```

4. **Component Communication**:
   - Parent → Child: Pass via assigns
   - Child → Parent: Use `send_update/3` or events with `phx-target`
   - Sibling: Use PubSub broadcasting

#### AshPhoenix Integration Patterns

**Research from `deps/ash_phoenix/usage-rules.md`**:

**Key Integration Points**:
1. **AshPhoenix.Form**: For form handling with Ash resources
2. **AshPhoenix.LiveView**: Helpers for resource loading in LiveView
3. **Query Building**: Use Ash.Query API for filtering, sorting, preloading

**Pattern for Resource Selection** (Report Builder data source config):
```elixir
# List available Ash resources
def list_available_resources(api) do
  api.resources()
  |> Enum.map(fn resource ->
    %{
      name: resource |> Module.split() |> List.last(),
      module: resource,
      attributes: Ash.Resource.Info.attributes(resource),
      relationships: Ash.Resource.Info.relationships(resource)
    }
  end)
end

# Build query from UI selections
def build_query_from_config(resource, config) do
  resource
  |> Ash.Query.new()
  |> apply_filters(config.filters)
  |> apply_sorting(config.sorting)
  |> Ash.Query.load(config.preloads)
end
```

**AshPhoenix.Form for Report Configuration**:
```elixir
# Create form for report config
form = AshPhoenix.Form.for_create(Report, :create,
  api: MyApp.Reports,
  forms: [
    auto?: true  # Auto-generate forms for embedded resources
  ]
)
```

#### Real-time Streaming with LiveView

**LiveView Streaming Pattern** (for incremental updates):
```elixir
# In mount - initialize stream
socket = stream(socket, :report_items, [])

# Handle streaming updates
def handle_info({:new_items, items}, socket) do
  {:noreply, stream_insert(socket, :report_items, items)}
end

# In template
<div id="report-items" phx-update="stream">
  <%= for {id, item} <- @streams.report_items do %>
    <div id={id}><%= item.name %></div>
  <% end %>
</div>
```

**Integration with GenStage Pipeline**:
```elixir
# Subscribe to pipeline updates
def subscribe_to_pipeline(stream_id) do
  Phoenix.PubSub.subscribe(
    AshReports.PubSub,
    "pipeline:#{stream_id}"
  )
end

# Handle pipeline events
def handle_info({:pipeline_batch, batch_data}, socket) do
  {:noreply,
   socket
   |> stream_insert(:report_items, batch_data)
   |> update(:progress, &(&1 + length(batch_data)))}
end
```

#### PubSub Patterns for Collaborative Features

**Existing PubSub Infrastructure** (`lib/ash_reports/pub_sub/chart_broadcaster.ex`):

**Broadcasting Pattern**:
```elixir
# Broadcast report builder updates
Phoenix.PubSub.broadcast(
  AshReports.PubSub,
  "report_builder:#{report_id}",
  {:config_updated, user_id, config_changes}
)

# Subscribe to updates
Phoenix.PubSub.subscribe(AshReports.PubSub, "report_builder:#{report_id}")

# Handle broadcasts
def handle_info({:config_updated, user_id, changes}, socket) do
  if user_id != socket.assigns.current_user.id do
    {:noreply,
     socket
     |> apply_remote_changes(changes)
     |> put_flash(:info, "Report updated by #{user_id}")}
  else
    {:noreply, socket}
  end
end
```

**Existing ChartBroadcaster Patterns to Leverage**:
- Batched updates with configurable delay
- Compression for large payloads
- Filtered streams for specific users

---

### 3. Senior Engineer Review: Architecture & Design Decisions

**Objective**: Validate architectural decisions for report builder, state management, separation of concerns, and testing strategies.

**Architectural Analysis**:

#### Report Builder Architecture Decisions

**Recommended Architecture**:

1. **Separation of Concerns**:
   ```
   ReportBuilderLive (Parent LiveView)
   ├── TemplateSelector (LiveComponent)
   ├── DataSourceConfig (LiveComponent)
   ├── FieldMapper (LiveComponent)
   ├── VisualizationConfig (LiveComponent)
   └── PreviewPane (LiveComponent)
   ```

2. **State Management Strategy**:
   - **LiveView Level**: Report-wide config, user info, active step
   - **Component Level**: Component-specific UI state (expanded sections, validation)
   - **GenServer Level**: Long-running operations (report generation, preview rendering)

3. **Business Logic Separation**:
   ```elixir
   # ❌ BAD - Business logic in LiveView
   def handle_event("generate_report", params, socket) do
     # Complex generation logic here...
   end

   # ✅ GOOD - Delegate to context module
   def handle_event("generate_report", params, socket) do
     case ReportBuilder.generate(params) do
       {:ok, report} -> {:noreply, assign(socket, :report, report)}
       {:error, error} -> {:noreply, put_flash(socket, :error, error)}
     end
   end
   ```

**Business Logic Context**: Create `AshReports.ReportBuilder` context:
```elixir
defmodule AshReports.ReportBuilder do
  @moduledoc "Business logic for interactive report building"

  def validate_config(config)
  def build_query_from_config(resource, config)
  def generate_preview(config, opts \\ [])
  def save_report_template(config, user_id)
  def start_generation(config, opts)
end
```

#### State Management in LiveView

**Recommendations**:

1. **Assign Normalization**:
   ```elixir
   # ✅ GOOD - Normalized, flat structure
   %{
     report_id: "123",
     config: %{template: "...", data_source: "..."},
     ui_state: %{active_step: 1, errors: %{}},
     generation_state: %{status: :idle, progress: 0}
   }

   # ❌ BAD - Deeply nested, hard to update
   %{
     report: %{
       id: "123",
       config: %{
         template: %{selected: "...", options: %{...}},
         data_source: %{...}
       }
     }
   }
   ```

2. **State Update Patterns**:
   ```elixir
   # Use update/3 for nested updates
   socket
   |> update(:config, &Map.put(&1, :template, new_template))
   |> update(:ui_state, &Map.put(&1, :active_step, 2))
   ```

3. **Temporary Assigns for Large Data**:
   ```elixir
   # Don't keep large preview data in assigns
   socket
   |> assign(:preview_data, preview_items)
   |> assign(:preview_temporary, true)  # Cleared after render
   ```

#### Separation of Concerns

**Layered Architecture**:

1. **Presentation Layer** (LiveView/Components):
   - Handle user interactions
   - Manage UI state
   - Delegate to business logic

2. **Business Logic Layer** (Context Modules):
   - `AshReports.ReportBuilder` - Report configuration and validation
   - `AshReports.Typst.DataLoader` - Data loading and transformation (existing)
   - `AshReports.Charts` - Chart generation (existing)

3. **Infrastructure Layer**:
   - `AshReports.StreamingPipeline` - Background processing (existing)
   - `AshReports.PubSub.ChartBroadcaster` - Real-time updates (existing)
   - `AshReports.Presence` - Collaboration tracking (existing)

**Integration Pattern**:
```elixir
# LiveView delegates to business logic
def handle_event("configure_data_source", params, socket) do
  case ReportBuilder.configure_data_source(params) do
    {:ok, config} ->
      # Update UI state
      {:noreply, assign(socket, :data_source_config, config)}

    {:error, changeset} ->
      # Show validation errors
      {:noreply, assign(socket, :errors, changeset.errors)}
  end
end

# Business logic coordinates services
def configure_data_source(params) do
  with {:ok, resource} <- validate_resource(params.resource),
       {:ok, query} <- build_query(resource, params.filters),
       {:ok, preview} <- generate_preview_data(query) do
    {:ok, %{resource: resource, query: query, preview: preview}}
  end
end
```

#### Testing Strategies for LiveView Components

**Test Pyramid**:

1. **Unit Tests** (Business Logic):
   ```elixir
   # test/ash_reports/report_builder_test.exs
   test "validates report configuration" do
     config = %{template: nil, data_source: "invalid"}

     assert {:error, %Ecto.Changeset{}} =
       ReportBuilder.validate_config(config)
   end
   ```

2. **Integration Tests** (LiveView):
   ```elixir
   # Use existing phoenix_test for LiveView testing
   import Phoenix.LiveViewTest

   test "updates config when template selected", %{conn: conn} do
     {:ok, view, _html} = live(conn, "/reports/builder")

     view
     |> element("#template-selector")
     |> render_click(%{template: "sales_report"})

     assert has_element?(view, "#selected-template", "sales_report")
   end
   ```

3. **Component Tests** (LiveComponents):
   ```elixir
   test "data source config validates resource selection" do
     {:ok, view, _html} = live_isolated(conn, DataSourceConfigComponent,
       session: %{config: %{}}
     )

     view
     |> form("#data-source-form", resource: "InvalidResource")
     |> render_change()

     assert has_element?(view, ".error", "Invalid resource")
   end
   ```

4. **E2E Tests** (Full User Flow):
   ```elixir
   test "complete report building flow" do
     {:ok, view, _html} = live(conn, "/reports/builder")

     # Step 1: Select template
     view |> element("#template-sales") |> render_click()

     # Step 2: Configure data source
     view
     |> form("#data-source-form", %{resource: "Sales"})
     |> render_submit()

     # Step 3: Generate report
     view |> element("#generate-btn") |> render_click()

     # Assert progress tracking
     assert has_element?(view, "#progress-bar")

     # Wait for completion
     assert_receive {:report_complete, _report_id}, 5000

     # Assert download available
     assert has_element?(view, "#download-link")
   end
   ```

**Testing Real-time Features**:
```elixir
test "receives real-time progress updates" do
  {:ok, view, _html} = live(conn, "/reports/builder")

  # Start generation
  view |> element("#generate-btn") |> render_click()

  # Simulate progress broadcast
  Phoenix.PubSub.broadcast(
    AshReports.PubSub,
    "report_progress:#{report_id}",
    {:progress, 50}
  )

  # Assert UI updates
  assert render(view) =~ "50%"
end
```

**Recommendations**:
- Use `phoenix_test` (already in deps) for LiveView testing
- Mock external services with Mimic (use `expect`, not `stub`)
- Test collaborative features with multiple LiveView connections
- Use Telemetry.Test for testing progress events

---

## Technical Details

### File Locations

**New Files to Create**:

1. **LiveView Module**:
   - `lib/ash_reports_web/live/report_builder_live.ex` (~400 lines)
   - Main LiveView for report builder interface

2. **LiveComponents**:
   - `lib/ash_reports_web/live/report_builder_live/template_selector.ex` (~150 lines)
   - `lib/ash_reports_web/live/report_builder_live/data_source_config.ex` (~200 lines)
   - `lib/ash_reports_web/live/report_builder_live/field_mapper.ex` (~150 lines)
   - `lib/ash_reports_web/live/report_builder_live/visualization_config.ex` (~180 lines)
   - `lib/ash_reports_web/live/report_builder_live/preview_pane.ex` (~120 lines)
   - `lib/ash_reports_web/live/report_builder_live/progress_tracker.ex` (~100 lines)

3. **Business Logic Context**:
   - `lib/ash_reports/report_builder.ex` (~350 lines)
   - `lib/ash_reports/report_builder/config_validator.ex` (~150 lines)
   - `lib/ash_reports/report_builder/template_manager.ex` (~120 lines)

4. **Progress Tracking**:
   - `lib/ash_reports/progress_tracker.ex` (~200 lines)
   - GenServer for managing report generation progress

5. **Templates**:
   - `lib/ash_reports_web/live/report_builder_live.html.heex` (main template)
   - Component templates (inline or separate .heex files)

6. **Routes**:
   - Add to existing router (demo or main app)

**Files to Modify**:

1. **Application Supervisor** (`lib/ash_reports/application.ex`):
   - Add `AshReports.ProgressTracker` to supervision tree
   - Add `Task.Supervisor` for report generation (if not exists)

2. **PubSub Module** (extend existing):
   - Add report builder topics and helpers

3. **Presence Module** (`lib/ash_reports/presence.ex`):
   - Add `track_report_builder_user/3` function

### Dependencies

**Existing Dependencies** (already in mix.exs):
- `phoenix_live_view ~> 0.20` ✅
- `phoenix_test ~> 0.7.1` (for testing) ✅
- `jason ~> 1.4` ✅

**PubSub** (already configured):
- `Phoenix.PubSub` via `AshReports.PubSub` ✅

**Background Jobs**:
- Use existing `Task.Supervisor` pattern (no Oban needed)
- Integrate with `StreamingPipeline` for long-running operations

**New Dependencies** (if needed):
- None required - all functionality can be built with existing stack

### Phoenix/LiveView Integration Specifics

#### Router Configuration

```elixir
# In lib/ash_reports_demo_web/router.ex (or main app router)
scope "/reports", AshReportsDemoWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/builder", ReportBuilderLive, :index
  live "/builder/new", ReportBuilderLive, :new
  live "/builder/:id", ReportBuilderLive, :edit
  live "/builder/:id/preview", ReportBuilderLive, :preview
end
```

#### LiveView Module Structure

```elixir
defmodule AshReportsDemoWeb.ReportBuilderLive do
  use AshReportsDemoWeb, :live_view

  alias AshReports.ReportBuilder
  alias AshReports.ProgressTracker

  @impl true
  def mount(params, session, socket) do
    if connected?(socket) do
      # Subscribe to updates
      Phoenix.PubSub.subscribe(AshReports.PubSub, "report_builder:#{socket.assigns.report_id}")

      # Track presence
      AshReports.Presence.track_report_builder_user(
        socket,
        socket.assigns.report_id,
        socket.assigns.current_user
      )
    end

    {:ok,
     socket
     |> assign(:report_id, generate_id())
     |> assign(:config, %{})
     |> assign(:active_step, 1)
     |> assign(:generation_status, :idle)
     |> assign(:errors, %{})
     |> assign(:connected_users, %{})
    }
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    case ReportBuilder.select_template(template) do
      {:ok, config} ->
        {:noreply,
         socket
         |> assign(:config, config)
         |> assign(:active_step, 2)
         |> broadcast_config_change("template_selected", config)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  @impl true
  def handle_event("generate_report", _params, socket) do
    config = socket.assigns.config

    # Start background task
    Task.Supervisor.start_child(AshReports.TaskSupervisor, fn ->
      report_id = socket.assigns.report_id

      # Start streaming pipeline
      {:ok, stream_id} = ReportBuilder.start_generation(config,
        progress_callback: fn progress ->
          Phoenix.PubSub.broadcast(
            AshReports.PubSub,
            "report_builder:#{report_id}",
            {:progress, progress}
          )
        end
      )

      # Monitor completion
      case ProgressTracker.await_completion(stream_id, timeout: 300_000) do
        {:ok, report_url} ->
          Phoenix.PubSub.broadcast(
            AshReports.PubSub,
            "report_builder:#{report_id}",
            {:complete, report_url}
          )

        {:error, reason} ->
          Phoenix.PubSub.broadcast(
            AshReports.PubSub,
            "report_builder:#{report_id}",
            {:error, reason}
          )
      end
    end)

    {:noreply, assign(socket, :generation_status, :generating)}
  end

  @impl true
  def handle_info({:progress, progress}, socket) do
    {:noreply,
     socket
     |> assign(:progress, progress)
     |> push_event("update_progress", %{progress: progress})}
  end

  @impl true
  def handle_info({:complete, report_url}, socket) do
    {:noreply,
     socket
     |> assign(:generation_status, :complete)
     |> assign(:report_url, report_url)
     |> put_flash(:info, "Report generated successfully!")}
  end

  defp broadcast_config_change(socket, event, config) do
    Phoenix.PubSub.broadcast(
      AshReports.PubSub,
      "report_builder:#{socket.assigns.report_id}",
      {:config_updated, socket.assigns.current_user.id, event, config}
    )
    socket
  end
end
```

#### Progress Tracking with Telemetry

```elixir
defmodule AshReports.ProgressTracker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def track_progress(report_id, stream_id) do
    GenServer.call(__MODULE__, {:track, report_id, stream_id})
  end

  def await_completion(stream_id, opts \\ []) do
    timeout = opts[:timeout] || 300_000
    GenServer.call(__MODULE__, {:await, stream_id}, timeout)
  end

  def init(_opts) do
    # Attach to streaming pipeline telemetry
    :telemetry.attach_many(
      "progress-tracker",
      [
        [:ash_reports, :streaming, :producer_consumer, :batch_transformed],
        [:ash_reports, :streaming, :pipeline, :complete]
      ],
      &handle_telemetry/4,
      %{}
    )

    {:ok, %{tracked_reports: %{}}}
  end

  def handle_call({:track, report_id, stream_id}, {from_pid, _}, state) do
    # Register tracking
    ref = Process.monitor(from_pid)

    updated = Map.put(state.tracked_reports, stream_id, %{
      report_id: report_id,
      caller: from_pid,
      ref: ref,
      progress: 0,
      status: :running
    })

    {:reply, :ok, %{state | tracked_reports: updated}}
  end

  defp handle_telemetry(_event, measurements, metadata, _config) do
    # Calculate progress percentage
    progress = calculate_progress(measurements, metadata)

    # Broadcast to report builder LiveView
    Phoenix.PubSub.broadcast(
      AshReports.PubSub,
      "report_builder:#{metadata.report_id}",
      {:progress, progress}
    )
  end
end
```

#### Client-side JavaScript Hooks

```javascript
// assets/js/hooks/progress_bar.js
export const ProgressBar = {
  mounted() {
    this.handleEvent("update_progress", ({progress}) => {
      const bar = this.el.querySelector('.progress-fill')
      bar.style.width = `${progress}%`
      bar.setAttribute('aria-valuenow', progress)
    })
  }
}

// assets/js/hooks/collaborative_cursor.js
export const CollaborativeCursor = {
  mounted() {
    this.handleEvent("user_cursor_move", ({user_id, position}) => {
      this.updateCursor(user_id, position)
    })
  },

  updateCursor(user_id, position) {
    let cursor = document.getElementById(`cursor-${user_id}`)
    if (!cursor) {
      cursor = this.createCursor(user_id)
    }
    cursor.style.left = `${position.x}px`
    cursor.style.top = `${position.y}px`
  }
}
```

---

## Success Criteria

### Functional Requirements

1. **Interactive Report Designer**:
   - [ ] Users can select from available report templates
   - [ ] Users can configure data sources using Ash resources
   - [ ] Users can map fields and configure visualizations
   - [ ] Real-time preview updates as configuration changes
   - [ ] Save and load report configurations
   - [ ] Export report configurations as DSL code

2. **Progress Tracking System**:
   - [ ] Real-time progress bars during report generation
   - [ ] Ability to pause/resume long-running reports
   - [ ] Ability to cancel report generation
   - [ ] Notification on completion or error
   - [ ] Support for multiple concurrent report generations
   - [ ] Progress persistence across page refreshes

3. **Collaborative Features**:
   - [ ] Display connected users working on same report
   - [ ] Real-time config updates from other users
   - [ ] User presence indicators
   - [ ] Conflict resolution for simultaneous edits

### Technical Requirements

1. **Performance**:
   - [ ] LiveView mounts in <500ms
   - [ ] UI updates in <100ms for local changes
   - [ ] Preview generation in <2s for sample data
   - [ ] Support 10+ concurrent users per report
   - [ ] Handle reports with 100K+ records via streaming

2. **Integration**:
   - [ ] Seamless integration with existing Ash resources
   - [ ] Uses StreamingPipeline for large datasets
   - [ ] Integrates with Charts module for visualizations
   - [ ] Compatible with existing authentication system

3. **Testing**:
   - [ ] >90% test coverage for business logic
   - [ ] E2E tests for complete user flows
   - [ ] Real-time feature tests with multiple connections
   - [ ] Performance tests for large datasets

---

## Implementation Plan

### Phase 1: Foundation (Week 1, Days 1-3) ✅ **COMPLETED**

**Objective**: Set up core LiveView infrastructure and business logic

**Status**: ✅ Complete (2025-10-04)

1. **Day 1: Project Setup** ✅
   - ✅ Create LiveView module structure (`demo/lib/ash_reports_demo_web/live/report_builder_live/index.ex`)
   - ✅ Set up router configuration (added `/reports/builder` route)
   - ✅ Create base ReportBuilderLive module (340 lines, 4-step wizard)
   - ⏭️  Add to supervision tree (not required for LiveView)

2. **Day 2: Business Logic Context** ✅
   - ✅ Implement `AshReports.ReportBuilder` context (330 lines, 8 public functions)
   - ✅ Create config validation module (`validate_config/1`)
   - ✅ Implement template management (`select_template/1`)
   - ✅ Add unit tests for business logic (23 comprehensive tests)

3. **Day 3: Basic UI & Routing** ✅
   - ✅ Create main LiveView template (4-step wizard interface)
   - ✅ Implement template selector component (3 templates available)
   - ✅ Add step navigation (Next/Previous buttons)
   - ✅ Wire up basic event handlers (select_template, next_step, prev_step, etc.)

**Deliverables**: ✅ **All Complete**
- ✅ Working LiveView that loads
- ✅ Template selection functional
- ✅ Step-based navigation
- ✅ Business logic tested (90%+ coverage)

**Additional Achievements**:
- Preview generation UI implemented
- Progress bar UI implemented
- Flash message notifications
- Responsive design with Tailwind CSS
- Clean architecture with separation of concerns

**Files Created**:
1. `lib/ash_reports/report_builder.ex` (330 lines)
2. `demo/lib/ash_reports_demo_web/live/report_builder_live/index.ex` (340 lines)
3. `test/ash_reports/report_builder_test.exs` (220 lines)

**Files Modified**:
1. `demo/lib/ash_reports_demo_web/router.ex` (added route)

**Total New Code**: ~890 lines

### Phase 2: Data Configuration (Week 1, Days 4-5)

**Objective**: Implement data source configuration interface

1. **Day 4: Data Source Component**
   - Create DataSourceConfig LiveComponent
   - Implement Ash resource browsing
   - Add filter configuration UI
   - Implement relationship selection

2. **Day 5: Field Mapping**
   - Create FieldMapper LiveComponent
   - Implement drag-and-drop field selection
   - Add field formatting options
   - Wire up preview data loading

**Deliverables**:
- Functional data source configuration
- Field mapping interface
- Preview data display
- Integration tests

### Phase 3: Visualization & Preview (Week 2, Days 1-3)

**Objective**: Add visualization configuration and real-time preview

1. **Day 6: Visualization Config**
   - Create VisualizationConfig LiveComponent
   - Integrate with Charts module
   - Add chart type selection
   - Implement chart configuration UI

2. **Day 7: Preview System**
   - Create PreviewPane LiveComponent
   - Implement real-time preview rendering
   - Add preview data sampling
   - Optimize preview performance

3. **Day 8: Preview Integration**
   - Wire up config changes to preview updates
   - Implement preview caching
   - Add preview error handling
   - Create preview loading states

**Deliverables**:
- Working visualization configuration
- Real-time preview system
- Performance optimized preview
- Component tests

### Phase 4: Progress Tracking (Week 2, Days 4-5)

**Objective**: Implement comprehensive progress tracking system

1. **Day 9: Progress Infrastructure**
   - Create ProgressTracker GenServer
   - Integrate with StreamingPipeline
   - Set up Telemetry subscriptions
   - Implement progress calculation logic

2. **Day 10: Progress UI**
   - Create ProgressTracker LiveComponent
   - Add progress bars and status indicators
   - Implement pause/resume/cancel controls
   - Add notification system

**Deliverables**:
- Functional progress tracking
- Stream control (pause/resume/cancel)
- Real-time status updates
- Progress persistence

### Phase 5: Collaborative Features (Week 3, Days 1-2)

**Objective**: Add multi-user collaboration support

1. **Day 11: Presence Integration**
   - Extend AshReports.Presence for report builder
   - Implement user tracking
   - Add presence indicators to UI
   - Create user activity broadcasts

2. **Day 12: Real-time Updates**
   - Implement config change broadcasting
   - Add conflict resolution logic
   - Create collaborative cursor tracking
   - Add user action indicators

**Deliverables**:
- User presence tracking
- Real-time collaborative updates
- Conflict resolution
- Integration tests for collaboration

### Phase 6: Testing & Polish (Week 3, Days 3-5)

**Objective**: Comprehensive testing and UI/UX refinement

1. **Day 13: Integration Testing**
   - Create E2E test suite
   - Test complete user flows
   - Test collaborative features
   - Test error scenarios

2. **Day 14: Performance Testing**
   - Benchmark LiveView performance
   - Test with large datasets
   - Test concurrent user scenarios
   - Optimize bottlenecks

3. **Day 15: UI/UX Polish**
   - Refine user interface
   - Improve loading states
   - Add helpful tooltips/guidance
   - Accessibility improvements

**Deliverables**:
- Complete test suite (>90% coverage)
- Performance benchmarks passing
- Polished user interface
- Documentation

---

## Notes and Considerations

### Technical Debt & Future Enhancements

1. **Template System**:
   - Current implementation uses in-memory templates
   - Future: Persistent template storage in database
   - Future: Template versioning and rollback

2. **Collaboration**:
   - Basic presence and updates implemented
   - Future: Operational transformation for complex edits
   - Future: Change history and audit log

3. **Preview System**:
   - Current: Sample data preview
   - Future: Full report preview with pagination
   - Future: Preview caching strategy

4. **Progress Tracking**:
   - Current: In-memory progress tracking
   - Future: Persistent progress for long reports
   - Future: Email notifications on completion

### Security Considerations

1. **Authentication & Authorization**:
   - Require authenticated user for report builder
   - Validate user permissions for resource access
   - Implement row-level security for sensitive data

2. **Resource Access**:
   - Validate Ash resource access permissions
   - Prevent unauthorized data queries
   - Audit report generation activities

3. **WebSocket Security**:
   - Validate all PubSub messages
   - Prevent message injection attacks
   - Rate limit WebSocket updates

### Performance Optimization

1. **LiveView Optimization**:
   - Use temporary assigns for large preview data
   - Implement debouncing for config changes
   - Optimize render cycles with `@socket.assigns`

2. **Preview Performance**:
   - Sample data for preview (max 1000 records)
   - Cache preview results with TTL
   - Use streaming for large previews

3. **Progress Tracking**:
   - Batch progress updates (every 100ms max)
   - Use Telemetry sampling for high-frequency events
   - Optimize PubSub message size

### Alternative Approaches Considered

1. **Oban vs Task.Supervisor**:
   - **Chosen**: Task.Supervisor (simpler, already in use)
   - **Rejected**: Oban (overkill for this use case, additional dependency)
   - **Reasoning**: Existing StreamingPipeline provides needed functionality

2. **Client-side vs Server-side Preview**:
   - **Chosen**: Server-side preview rendering
   - **Alternative**: Client-side preview with API
   - **Reasoning**: Leverage existing server-side rendering, simpler architecture

3. **Component Structure**:
   - **Chosen**: LiveComponents for each major section
   - **Alternative**: Single monolithic LiveView
   - **Reasoning**: Better separation of concerns, easier testing, reusability

### Integration Points

**With Existing Systems**:

1. **StreamingPipeline** (Stage 2):
   - Use for large dataset processing
   - Integrate pipeline control functions
   - Subscribe to pipeline telemetry events

2. **Charts Module** (Stage 3):
   - Use for visualization generation
   - Integrate chart configuration UI
   - Preview chart rendering

3. **Typst DSL Generator** (Stage 1):
   - Export report config as DSL code
   - Validate config against DSL schema
   - Generate Typst templates

4. **PubSub/Presence** (Existing):
   - Use for real-time collaboration
   - Track user presence
   - Broadcast config updates

### Testing Strategy Details

**Test Categories**:

1. **Unit Tests** (Business Logic):
   - ReportBuilder context functions
   - Config validation logic
   - Template management
   - Progress calculation

2. **Component Tests** (LiveComponents):
   - Template selector
   - Data source config
   - Field mapper
   - Progress tracker

3. **Integration Tests** (LiveView):
   - Full user flows
   - PubSub messaging
   - Presence tracking
   - Progress updates

4. **E2E Tests** (Full Stack):
   - Report creation flow
   - Collaborative editing
   - Report generation
   - Error scenarios

**Test Tools**:
- `phoenix_test` for LiveView testing
- `Mimic` for mocking (use `expect`, not `stub`)
- `Telemetry.Test` for telemetry testing
- `StreamData` for property-based tests

---

## Appendix: Research Sources

### Phoenix LiveView Documentation
- Phoenix LiveView Official Docs: Component architecture, state management, event handling
- Phoenix PubSub Docs: Broadcasting patterns, topic management
- Phoenix Presence Docs: User tracking, collaborative features

### Existing Codebase Patterns
- `lib/ash_reports/live_view/dashboard_live.ex` - LiveView patterns, PubSub integration
- `lib/ash_reports/presence.ex` - Presence tracking implementation
- `lib/ash_reports/pub_sub/chart_broadcaster.ex` - Broadcasting patterns, batching
- `lib/ash_reports/typst/streaming_pipeline.ex` - Pipeline control, telemetry

### Ash Framework
- Ash Resource API: Resource introspection, query building
- AshPhoenix: Form handling, LiveView integration
- Ash Query: Filtering, sorting, preloading

### Background Processing
- Elixir Task.Supervisor: Supervised async tasks
- GenStage: Backpressure, streaming
- Telemetry: Event instrumentation, progress tracking

---

**Document Status**: ✅ Complete - Ready for Implementation
**Next Steps**: Review with Pascal, then begin Phase 1 implementation
