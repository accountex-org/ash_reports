defmodule AshReportsDemoWeb.ReportBuilderLive.Index do
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
    next_step = min(socket.assigns.active_step + 1, 4)
    {:noreply, assign(socket, :active_step, next_step)}
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
            <.preview_step
              config={@config}
              preview_data={@preview_data}
            />
          <% 4 -> %>
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
          :if={@active_step < 4}
          phx-click="next_step"
        >
          Next
        </.button>
        <.button
          :if={@active_step == 4}
          phx-click="generate_report"
          class="bg-green-600 hover:bg-green-700"
        >
          Generate Report
        </.button>
      </div>
    </div>
    """
  end

  # Step Components

  defp template_selector_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold text-gray-900">Select Template</h2>
      <p class="mt-1 text-sm text-gray-600">
        Choose a report template to get started
      </p>

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
      <h2 class="text-lg font-semibold text-gray-900">Configure Data Source</h2>
      <p class="mt-1 text-sm text-gray-600">
        Select your data source and configure filters
      </p>

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

  defp preview_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold text-gray-900">Configure Visualizations & Preview</h2>
      <p class="mt-1 text-sm text-gray-600">
        Add charts and visualizations, then preview your report
      </p>

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
      <h2 class="text-lg font-semibold text-gray-900">Generate Report</h2>
      <p class="mt-1 text-sm text-gray-600">
        Review and generate your final report
      </p>

      <div class="mt-6">
        <%= case @status do %>
          <% :idle -> %>
            <p class="text-sm text-gray-600">Ready to generate report</p>
          <% :generating -> %>
            <div class="space-y-4">
              <p class="text-sm text-gray-900">Generating report...</p>
              <div class="relative pt-1">
                <div class="mb-2 flex items-center justify-between">
                  <span class="inline-block rounded-full bg-blue-200 px-2 py-1 text-xs font-semibold uppercase text-blue-600">
                    In Progress
                  </span>
                  <span class="text-xs font-semibold text-gray-700">
                    <%= @progress %>%
                  </span>
                </div>
                <div class="mb-4 flex h-2 overflow-hidden rounded bg-blue-200 text-xs">
                  <div
                    style={"width: #{@progress}%"}
                    class="flex flex-col justify-center whitespace-nowrap bg-blue-500 text-center text-white shadow-none"
                  >
                  </div>
                </div>
              </div>
              <.button phx-click="cancel_generation" class="bg-red-600 hover:bg-red-700">
                Cancel
              </.button>
            </div>
          <% :completed -> %>
            <p class="text-sm text-green-600">Report generated successfully!</p>
          <% :cancelled -> %>
            <p class="text-sm text-gray-600">Report generation was cancelled</p>
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

  defp steps do
    ["Select Template", "Configure Data", "Preview", "Generate"]
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
