defmodule AshReportsDemoWeb.ReportBuilderLive.Index do
  @moduledoc """
  Interactive LiveView-based Report Builder interface.

  Provides a step-by-step wizard for creating and configuring reports without
  writing DSL code. Users can select templates, configure data sources, customize
  appearance, and generate reports with real-time progress tracking.

  ## Features

  - **5-Step Wizard**: Template → Data → Customize → Preview → Generate
  - **Form Validation**: Step-by-step validation with inline error messages
  - **Real-time Progress**: Live progress tracking during report generation
  - **Contextual Help**: Hover tooltips on each step for guidance
  - **Responsive Design**: Mobile-friendly interface with Tailwind CSS

  ## State Management

  The LiveView maintains the following assigns:

  - `:config` - Report configuration map (template, data_source, customization, visualizations)
  - `:active_step` - Current wizard step (1-5)
  - `:generation_status` - Report generation status (:idle, :generating, :completed, etc.)
  - `:progress` - Generation progress percentage (0-100)
  - `:errors` - Validation errors map
  - `:tracker_id` - Progress tracker ID for monitoring generation

  ## Usage

  Navigate to `/reports/builder` to access the interactive report builder.
  """

  use AshReportsDemoWeb, :live_view

  alias AshReports.ReportBuilder

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Report Builder")
     |> assign(:report_id, generate_report_id())
     |> assign(:config, initial_config())
     |> assign(:active_step, 1)
     |> assign(:generation_status, :idle)
     |> assign(:progress, 0)
     |> assign(:errors, %{})
     |> assign(:preview_data, [])
     |> assign(:available_templates, list_templates())
     |> assign(:steps, steps())}
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    case ReportBuilder.select_template(template) do
      {:ok, config} ->
        {:noreply,
         socket
         |> assign(:config, config)
         |> assign(:active_step, 2)
         |> put_flash(:info, "Template '#{template}' selected")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to select template: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.active_step
    config = socket.assigns.config

    case validate_step(current_step, config) do
      :ok ->
        next_step = min(current_step + 1, 5)
        {:noreply, socket |> assign(:active_step, next_step) |> assign(:errors, %{})}

      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:errors, errors)
         |> put_flash(:error, "Please fix validation errors before proceeding")}
    end
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    prev_step = max(socket.assigns.active_step - 1, 1)
    {:noreply, assign(socket, :active_step, prev_step)}
  end

  @impl true
  def handle_event("generate_preview", _params, socket) do
    config = socket.assigns.config

    case ReportBuilder.generate_preview(config, limit: 100) do
      {:ok, preview_data} ->
        {:noreply,
         socket
         |> assign(:preview_data, preview_data)
         |> put_flash(:info, "Preview generated successfully")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Preview generation failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("generate_report", _params, socket) do
    config = socket.assigns.config

    case ReportBuilder.start_generation(config, async: true, total_records: 1000) do
      {:ok, tracker_id} ->
        # Start polling for progress updates
        Process.send_after(self(), :poll_progress, 500)

        {:noreply,
         socket
         |> assign(:generation_status, :generating)
         |> assign(:tracker_id, tracker_id)
         |> assign(:progress, 0)
         |> put_flash(:info, "Report generation started")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Generation failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("cancel_generation", _params, socket) do
    if tracker_id = socket.assigns[:tracker_id] do
      AshReports.ReportBuilder.ProgressTracker.cancel(tracker_id)
    end

    {:noreply,
     socket
     |> assign(:generation_status, :cancelled)
     |> put_flash(:info, "Report generation cancelled")}
  end

  @impl true
  def handle_info(
        {AshReportsDemoWeb.ReportBuilderLive.DataSourceConfig, {:resource_selected, resource}},
        socket
      ) do
    config = socket.assigns.config

    case ReportBuilder.configure_data_source(config, %{resource: resource}) do
      {:ok, updated_config} ->
        {:noreply,
         socket
         |> assign(:config, updated_config)
         |> put_flash(:info, "Data source configured")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to configure data source: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(
        {AshReportsDemoWeb.ReportBuilderLive.DataSourceConfig, {:filters_updated, filters}},
        socket
      ) do
    config = socket.assigns.config

    # Update filters in data source config
    updated_data_source = Map.put(config.data_source || %{}, :filters, filters)
    updated_config = Map.put(config, :data_source, updated_data_source)

    {:noreply, assign(socket, :config, updated_config)}
  end

  @impl true
  def handle_info(
        {AshReportsDemoWeb.ReportBuilderLive.DataSourceConfig,
         {:relationship_toggled, _rel_name}},
        socket
      ) do
    # Handle relationship toggle - for now just acknowledge
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {AshReportsDemoWeb.ReportBuilderLive.CustomizationConfig,
         {:customization_updated, customization}},
        socket
      ) do
    config = socket.assigns.config
    updated_config = Map.put(config, :customization, customization)

    {:noreply, assign(socket, :config, updated_config)}
  end

  @impl true
  def handle_info(
        {AshReportsDemoWeb.ReportBuilderLive.VisualizationConfig,
         {:visualizations_updated, visualizations}},
        socket
      ) do
    config = socket.assigns.config
    updated_config = Map.put(config, :visualizations, visualizations)

    {:noreply, assign(socket, :config, updated_config)}
  end

  @impl true
  def handle_info(:poll_progress, socket) do
    tracker_id = socket.assigns[:tracker_id]

    case AshReports.ReportBuilder.ProgressTracker.get_status(tracker_id) do
      {:ok, status} ->
        updated_socket =
          socket
          |> assign(:progress, status.progress)
          |> assign(:generation_status, status.status)

        # Continue polling if still generating
        if status.status == :running do
          Process.send_after(self(), :poll_progress, 500)
        end

        {:noreply, updated_socket}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <.header>
        Report Builder
        <:subtitle>
          Create and configure reports interactively
        </:subtitle>
      </.header>

      <!-- Progress Steps -->
      <div class="mt-8">
        <nav aria-label="Progress">
          <ol role="list" class="flex items-center">
            <li :for={{step, idx} <- Enum.with_index(@steps, 1)} class="relative flex items-center">
              <div class={[
                "flex items-center",
                if(idx < length(@steps), do: "pr-8 sm:pr-20", else: "")
              ]}>
                <div class={[
                  "relative flex h-8 w-8 items-center justify-center rounded-full",
                  step_class(@active_step, idx)
                ]}>
                  <span class="text-sm font-medium"><%= idx %></span>
                </div>
                <span :if={idx < length(@steps)} class="ml-4 text-sm font-medium text-gray-500">
                  <%= step %>
                </span>
              </div>
            </li>
          </ol>
        </nav>
      </div>

      <!-- Step Content -->
      <div class="mt-8 rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
        <%= case @active_step do %>
          <% 1 -> %>
            <.template_selector_step
              templates={@available_templates}
              selected={@config[:template]}
            />
          <% 2 -> %>
            <.data_source_step config={@config} />
          <% 3 -> %>
            <.customization_step config={@config} errors={@errors} />
          <% 4 -> %>
            <.preview_step
              config={@config}
              preview_data={@preview_data}
            />
          <% 5 -> %>
            <.generation_step
              status={@generation_status}
              progress={@progress}
            />
        <% end %>
      </div>

      <!-- Navigation Buttons -->
      <div class="mt-6 flex justify-between">
        <.button
          :if={@active_step > 1}
          phx-click="prev_step"
          class="bg-gray-600 hover:bg-gray-700"
        >
          Previous
        </.button>
        <div></div>
        <.button
          :if={@active_step < 5}
          phx-click="next_step"
          disabled={!can_proceed?(@active_step, @config, @errors)}
          class={
            if !can_proceed?(@active_step, @config, @errors) do
              "cursor-not-allowed opacity-50"
            else
              ""
            end
          }
        >
          Next
        </.button>
        <.button
          :if={@active_step == 5}
          phx-click="generate_report"
          disabled={!can_proceed?(5, @config, @errors)}
          class={
            if !can_proceed?(5, @config, @errors) do
              "cursor-not-allowed opacity-50"
            else
              "bg-green-600 hover:bg-green-700"
            end
          }
        >
          Generate Report
        </.button>
      </div>
    </div>
    """
  end

  # Step Components
  #
  # Each step component renders the UI for a specific wizard step.
  # Components include:
  # - Info icon with hover tooltip for contextual help
  # - Inline error messages when validation fails
  # - Step-specific configuration UI

  # Renders Step 1: Template Selection.
  #
  # Displays available report templates as clickable cards. When a template is selected,
  # it automatically advances to the next step. Includes validation error display and
  # contextual help tooltip.
  defp template_selector_step(assigns) do
    ~H"""
    <div>
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Select Template</h2>
          <p class="mt-1 text-sm text-gray-600">
            Choose a report template to get started
          </p>
        </div>
        <div class="group relative">
          <svg
            class="h-5 w-5 text-gray-400 hover:text-gray-600"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
              clip-rule="evenodd"
            />
          </svg>
          <div class="invisible absolute right-0 top-6 z-10 w-64 rounded-md bg-gray-900 px-3 py-2 text-sm text-white opacity-0 shadow-lg transition-opacity group-hover:visible group-hover:opacity-100">
            Templates provide pre-configured layouts and styles for your reports. Each template includes default formatting, sections, and visualization options that you can customize in the following steps.
          </div>
        </div>
      </div>

      <%= if @errors[:template] do %>
        <div class="mt-4 rounded-md bg-red-50 p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm text-red-800"><%= @errors[:template] %></p>
            </div>
          </div>
        </div>
      <% end %>

      <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={template <- @templates}
          class={[
            "cursor-pointer rounded-lg border p-4 hover:border-blue-500",
            if(@selected == template.id, do: "border-blue-500 bg-blue-50", else: "border-gray-200")
          ]}
          phx-click="select_template"
          phx-value-template={template.id}
        >
          <h3 class="font-semibold text-gray-900"><%= template.name %></h3>
          <p class="mt-1 text-sm text-gray-600"><%= template.description %></p>
        </div>
      </div>
    </div>
    """
  end

  defp data_source_step(assigns) do
    ~H"""
    <div>
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Configure Data Source</h2>
          <p class="mt-1 text-sm text-gray-600">
            Select your data source and configure filters
          </p>
        </div>
        <div class="group relative">
          <svg
            class="h-5 w-5 text-gray-400 hover:text-gray-600"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
              clip-rule="evenodd"
            />
          </svg>
          <div class="invisible absolute right-0 top-6 z-10 w-64 rounded-md bg-gray-900 px-3 py-2 text-sm text-white opacity-0 shadow-lg transition-opacity group-hover:visible group-hover:opacity-100">
            Choose an Ash resource as your data source. You can add filters to refine the data included in your report. Relationships can be preloaded for accessing nested data.
          </div>
        </div>
      </div>

      <%= if @errors[:data_source] do %>
        <div class="mt-4 rounded-md bg-red-50 p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm text-red-800"><%= @errors[:data_source] %></p>
            </div>
          </div>
        </div>
      <% end %>

      <div class="mt-6">
        <.live_component
          module={AshReportsDemoWeb.ReportBuilderLive.DataSourceConfig}
          id="data-source-config"
          config={@config}
        />
      </div>
    </div>
    """
  end

  # Renders Step 3: Template Customization.
  #
  # Allows users to customize the appearance of their report by selecting themes
  # and customizing brand colors. Uses the CustomizationConfig LiveComponent.
  defp customization_step(assigns) do
    ~H"""
    <div>
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Customize Appearance</h2>
          <p class="mt-1 text-sm text-gray-600">
            Select a theme and customize colors to match your brand
          </p>
        </div>
        <div class="group relative">
          <svg
            class="h-5 w-5 text-gray-400 hover:text-gray-600"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
              clip-rule="evenodd"
            />
          </svg>
          <div class="invisible absolute right-0 top-6 z-10 w-64 rounded-md bg-gray-900 px-3 py-2 text-sm text-white opacity-0 shadow-lg transition-opacity group-hover:visible group-hover:opacity-100">
            Choose a theme and customize colors to match your organization's branding.
            Themes control typography, colors, and overall report appearance. You can
            override theme colors with your own brand colors.
          </div>
        </div>
      </div>

      <%= if @errors[:customization] do %>
        <div class="mt-4 rounded-md bg-red-50 p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm text-red-800"><%= @errors[:customization] %></p>
            </div>
          </div>
        </div>
      <% end %>

      <div class="mt-6">
        <.live_component
          module={AshReportsDemoWeb.ReportBuilderLive.CustomizationConfig}
          id="customization-config"
          config={@config}
        />
      </div>
    </div>
    """
  end

  defp preview_step(assigns) do
    ~H"""
    <div>
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Configure Visualizations & Preview</h2>
          <p class="mt-1 text-sm text-gray-600">
            Add charts and visualizations, then preview your report
          </p>
        </div>
        <div class="group relative">
          <svg
            class="h-5 w-5 text-gray-400 hover:text-gray-600"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1 a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
              clip-rule="evenodd"
            />
          </svg>
          <div class="invisible absolute right-0 top-6 z-10 w-64 rounded-md bg-gray-900 px-3 py-2 text-sm text-white opacity-0 shadow-lg transition-opacity group-hover:visible group-hover:opacity-100">
            Add charts to visualize your data. You can configure chart type, dimensions, themes, and other display options. Preview shows sample data - the final report will use actual data from your configured source.
          </div>
        </div>
      </div>

      <div class="mt-6 space-y-6">
        <!-- Visualization Configuration -->
        <div>
          <.live_component
            module={AshReportsDemoWeb.ReportBuilderLive.VisualizationConfig}
            id="visualization-config"
            config={@config}
          />
        </div>
        <!-- Chart Previews -->
        <div :if={has_visualizations?(@config)} class="border-t border-gray-200 pt-6">
          <h3 class="text-sm font-semibold text-gray-900">Chart Previews</h3>
          <p class="mt-1 text-xs text-gray-500">
            Sample visualizations (will use actual data in final report)
          </p>

          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <div
              :for={viz <- @config[:visualizations] || []}
              class="rounded-lg border border-gray-200 bg-white p-4"
            >
              <h4 class="text-sm font-medium text-gray-900">
                <%= viz.config.title || "Untitled Chart" %>
              </h4>
              <div class="mt-2 flex items-center justify-center bg-gray-50 p-8 rounded">
                <div class="text-center text-gray-400">
                  <svg class="mx-auto h-12 w-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                    />
                  </svg>
                  <p class="mt-2 text-sm">
                    <%= humanize_chart_type(viz.type) %> · <%= viz.config.width %>x<%= viz.config.height %>px
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Preview Data Section -->
        <div class="border-t border-gray-200 pt-6">
          <h3 class="text-sm font-semibold text-gray-900">Data Preview</h3>

          <.button phx-click="generate_preview" class="mt-3">
            Generate Preview
          </.button>

          <div :if={length(@preview_data) > 0} class="mt-4">
            <h4 class="text-sm font-medium text-gray-900">Sample Data (first 10 rows)</h4>
            <div class="mt-2 overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th :for={key <- preview_headers(@preview_data)} class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wide text-gray-500">
                      <%= key %>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr :for={row <- Enum.take(@preview_data, 10)}>
                    <td :for={{_key, value} <- row} class="whitespace-nowrap px-3 py-2 text-sm text-gray-900">
                      <%= value %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp generation_step(assigns) do
    ~H"""
    <div>
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Generate Report</h2>
          <p class="mt-1 text-sm text-gray-600">
            Review your configuration and generate the final report
          </p>
        </div>
        <div class="group relative">
          <svg
            class="h-5 w-5 text-gray-400 hover:text-gray-600"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
              clip-rule="evenodd"
            />
          </svg>
          <div class="invisible absolute right-0 top-6 z-10 w-64 rounded-md bg-gray-900 px-3 py-2 text-sm text-white opacity-0 shadow-lg transition-opacity group-hover:visible group-hover:opacity-100">
            Review your configuration summary and click "Generate Report" to start the report generation process. Progress will be tracked in real-time and you can cancel at any point.
          </div>
        </div>
      </div>
      <!-- Configuration Summary -->
      <div class="mt-6 rounded-lg border border-gray-200 bg-gray-50 p-4">
        <h3 class="text-sm font-semibold text-gray-900">Configuration Summary</h3>
        <dl class="mt-3 space-y-2 text-sm">
          <div class="flex justify-between">
            <dt class="text-gray-600">Template:</dt>
            <dd class="font-medium text-gray-900"><%= @config[:template] || "Not selected" %></dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-gray-600">Data Source:</dt>
            <dd class="font-medium text-gray-900">
              <%= if @config[:data_source], do: "Configured", else: "Not configured" %>
            </dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-gray-600">Visualizations:</dt>
            <dd class="font-medium text-gray-900">
              <%= length(@config[:visualizations] || []) %> chart(s)
            </dd>
          </div>
        </dl>
      </div>
      <!-- Generation Status -->
      <div class="mt-6">
        <%= case @generation_status do %>
          <% :idle -> %>
            <div class="text-center">
              <p class="text-sm text-gray-600">Ready to generate report</p>
              <p class="mt-2 text-xs text-gray-500">
                Click the button below to start report generation
              </p>
            </div>
          <% :generating -> %>
            <div class="space-y-4">
              <div class="flex items-center gap-3">
                <div class="h-10 w-10 animate-spin rounded-full border-4 border-blue-200 border-t-blue-600"></div>
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-900">Generating report...</p>
                  <p class="text-xs text-gray-500">This may take a few moments</p>
                </div>
              </div>

              <div class="relative pt-1">
                <div class="mb-2 flex items-center justify-between">
                  <span class="inline-flex items-center rounded-full bg-blue-100 px-3 py-1 text-xs font-semibold text-blue-800">
                    <svg
                      class="-ml-1 mr-1.5 h-4 w-4 animate-pulse"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    In Progress
                  </span>
                  <span class="text-sm font-semibold text-gray-900">
                    <%= @progress %>%
                  </span>
                </div>
                <div class="mb-4 flex h-3 overflow-hidden rounded-full bg-gray-200">
                  <div
                    style={"width: #{@progress}%"}
                    class="flex flex-col justify-center bg-gradient-to-r from-blue-500 to-blue-600 text-center text-xs text-white shadow-sm transition-all duration-500"
                  >
                  </div>
                </div>
              </div>

              <.button phx-click="cancel_generation" class="w-full bg-red-600 hover:bg-red-700">
                <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
                Cancel Generation
              </.button>
            </div>
          <% :completed -> %>
            <div class="rounded-lg bg-green-50 p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fill-rule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-green-800">Report generated successfully!</h3>
                  <div class="mt-2 text-sm text-green-700">
                    <p>Your report has been generated and is ready to download.</p>
                  </div>
                </div>
              </div>
            </div>
          <% :cancelled -> %>
            <div class="rounded-lg bg-yellow-50 p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fill-rule="evenodd"
                      d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-yellow-800">Report generation was cancelled</h3>
                  <div class="mt-2 text-sm text-yellow-700">
                    <p>You can start a new generation when ready.</p>
                  </div>
                </div>
              </div>
            </div>
          <% :failed -> %>
            <div class="rounded-lg bg-red-50 p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fill-rule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-red-800">Report generation failed</h3>
                  <div class="mt-2 text-sm text-red-700">
                    <p>An error occurred during generation. Please try again.</p>
                  </div>
                </div>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper Functions

  defp initial_config do
    %{
      template: nil,
      data_source: nil,
      field_mappings: %{},
      visualizations: [],
      metadata: %{}
    }
  end

  defp generate_report_id do
    "report_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp list_templates do
    [
      %{
        id: "sales_report",
        name: "Sales Report",
        description: "Comprehensive sales analysis with charts and summaries"
      },
      %{
        id: "customer_report",
        name: "Customer Report",
        description: "Customer analytics and demographics"
      },
      %{
        id: "inventory_report",
        name: "Inventory Report",
        description: "Stock levels and inventory tracking"
      }
    ]
  end

  defp step_class(active_step, step_number) do
    cond do
      step_number < active_step -> "bg-blue-600 text-white"
      step_number == active_step -> "bg-blue-600 text-white"
      true -> "bg-gray-200 text-gray-600"
    end
  end

  defp preview_headers([]), do: []

  defp preview_headers([first_row | _]) do
    Map.keys(first_row)
  end

  # Public for testing
  def steps do
    ["Select Template", "Configure Data", "Customize", "Preview", "Generate"]
  end

  # Validation Functions

  # Validates the current step's configuration.
  #
  # Each step has specific validation requirements:
  # - Step 1: Template must be selected
  # - Step 2: Data source must be configured with a resource
  # - Step 3: Customization is optional (no validation required)
  # - Step 4: Preview - no validation required
  # - Step 5: Full configuration validation via ReportBuilder
  #
  # Returns `:ok` if valid, or `{:error, errors_map}` with validation errors.
  # Public for testing
  def validate_step(1, config) do
    # Step 1: Template selection
    if config[:template] do
      :ok
    else
      {:error, %{template: "Please select a template to continue"}}
    end
  end

  def validate_step(2, config) do
    # Step 2: Data source configuration
    errors = %{}

    errors =
      if config[:data_source] && config[:data_source][:resource] do
        errors
      else
        Map.put(errors, :data_source, "Please select a data source")
      end

    if map_size(errors) == 0 do
      :ok
    else
      {:error, errors}
    end
  end

  def validate_step(3, _config) do
    # Step 3: Customization - optional, no validation required
    :ok
  end

  def validate_step(4, _config) do
    # Step 4: Preview - no validation required
    :ok
  end

  def validate_step(5, config) do
    # Step 5: Generation - validate complete config
    case ReportBuilder.validate_config(config) do
      {:ok, _} -> :ok
      {:error, errors} -> {:error, errors}
    end
  end

  def validate_step(_step, _config), do: :ok

  # Checks if navigation should proceed from the current step.
  #
  # Used to enable/disable the "Next" and "Generate Report" buttons.
  # Returns `true` if the step is valid and there are no pending errors.
  # Public for testing
  def can_proceed?(step, config, errors) do
    # Check if current step is valid
    case validate_step(step, config) do
      :ok -> map_size(errors) == 0
      {:error, _} -> false
    end
  end

  defp has_visualizations?(config) do
    case config[:visualizations] do
      nil -> false
      [] -> false
      _list -> true
    end
  end

  defp humanize_chart_type(type) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
