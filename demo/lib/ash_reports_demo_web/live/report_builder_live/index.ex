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
     |> assign(:available_templates, list_templates())}
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

    case ReportBuilder.start_generation(config, async: true) do
      {:ok, stream_id} ->
        {:noreply,
         socket
         |> assign(:generation_status, :generating)
         |> assign(:stream_id, stream_id)
         |> put_flash(:info, "Report generation started")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Generation failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("cancel_generation", _params, socket) do
    {:noreply,
     socket
     |> assign(:generation_status, :cancelled)
     |> put_flash(:info, "Report generation cancelled")}
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
        <p class="text-sm text-gray-500">
          Data source configuration will be implemented in the next iteration
        </p>
      </div>
    </div>
    """
  end

  defp preview_step(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold text-gray-900">Preview Report</h2>
      <p class="mt-1 text-sm text-gray-600">
        Review your report configuration and preview the output
      </p>

      <div class="mt-6">
        <.button phx-click="generate_preview">
          Generate Preview
        </.button>

        <div :if={length(@preview_data) > 0} class="mt-4">
          <h3 class="text-sm font-medium text-gray-900">Preview Data</h3>
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
end
