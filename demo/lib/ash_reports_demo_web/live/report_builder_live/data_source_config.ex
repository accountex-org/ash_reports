defmodule AshReportsDemoWeb.ReportBuilderLive.DataSourceConfig do
  @moduledoc """
  LiveComponent for configuring report data sources.

  Allows users to:
  - Browse and select Ash resources
  - Configure filters and parameters
  - Select relationships to include
  - Preview available fields
  """

  use AshReportsDemoWeb, :live_component

  alias AshReportsDemo.Domain

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:available_resources, list_available_resources())
     |> assign(:selected_resource, nil)
     |> assign(:resource_fields, [])
     |> assign(:relationships, [])
     |> assign(:filters, %{})
     |> assign(:errors, %{})}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if assigns[:config][:data_source] do
        resource = assigns.config.data_source[:resource]

        socket
        |> assign(:selected_resource, resource)
        |> assign(:resource_fields, get_resource_fields(resource))
        |> assign(:relationships, get_resource_relationships(resource))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_resource", %{"resource" => resource_name}, socket) do
    resource = String.to_existing_atom("Elixir.#{resource_name}")

    if resource in socket.assigns.available_resources do
      {:noreply,
       socket
       |> assign(:selected_resource, resource)
       |> assign(:resource_fields, get_resource_fields(resource))
       |> assign(:relationships, get_resource_relationships(resource))
       |> assign(:filters, %{})
       |> notify_parent({:resource_selected, resource})}
    else
      {:noreply, put_flash(socket, :error, "Invalid resource selected")}
    end
  rescue
    ArgumentError ->
      {:noreply, put_flash(socket, :error, "Invalid resource name")}
  end

  @impl true
  def handle_event("add_filter", %{"field" => field, "value" => value}, socket) do
    filters = Map.put(socket.assigns.filters, String.to_atom(field), value)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> notify_parent({:filters_updated, filters})}
  end

  @impl true
  def handle_event("remove_filter", %{"field" => field}, socket) do
    filters = Map.delete(socket.assigns.filters, String.to_atom(field))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> notify_parent({:filters_updated, filters})}
  end

  @impl true
  def handle_event("toggle_relationship", %{"relationship" => rel_name}, socket) do
    # This would toggle relationship preloading
    # For now, just send notification to parent
    {:noreply, notify_parent(socket, {:relationship_toggled, rel_name})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"data-source-config-#{@id}"} class="space-y-6">
      <!-- Resource Selection -->
      <div>
        <label class="block text-sm font-medium text-gray-700">
          Select Data Source
        </label>
        <p class="mt-1 text-sm text-gray-500">
          Choose an Ash resource to use as the data source for your report
        </p>

        <div class="mt-3 grid gap-3 sm:grid-cols-2">
          <div
            :for={resource <- @available_resources}
            class={[
              "cursor-pointer rounded-lg border p-4 transition-all hover:border-blue-500",
              if(@selected_resource == resource,
                do: "border-blue-500 bg-blue-50 ring-2 ring-blue-500",
                else: "border-gray-200"
              )
            ]}
            phx-click="select_resource"
            phx-value-resource={inspect(resource)}
            phx-target={@myself}
          >
            <div class="flex items-center justify-between">
              <div>
                <h3 class="font-semibold text-gray-900">
                  <%= resource_display_name(resource) %>
                </h3>
                <p class="mt-1 text-sm text-gray-600">
                  <%= resource_description(resource) %>
                </p>
              </div>
              <div :if={@selected_resource == resource} class="text-blue-600">
                <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Resource Details -->
      <div :if={@selected_resource} class="rounded-lg border border-gray-200 bg-gray-50 p-4">
        <h3 class="text-sm font-semibold text-gray-900">Resource Details</h3>

        <!-- Available Fields -->
        <div class="mt-4">
          <h4 class="text-sm font-medium text-gray-700">Available Fields</h4>
          <div class="mt-2 flex flex-wrap gap-2">
            <span
              :for={field <- @resource_fields}
              class="inline-flex items-center rounded-full bg-blue-100 px-3 py-1 text-xs font-medium text-blue-800"
            >
              <%= field.name %>
              <span class="ml-1 text-blue-600">(<%= field.type %>)</span>
            </span>
          </div>
        </div>

        <!-- Relationships -->
        <div :if={length(@relationships) > 0} class="mt-4">
          <h4 class="text-sm font-medium text-gray-700">Relationships</h4>
          <div class="mt-2 space-y-2">
            <div :for={rel <- @relationships} class="flex items-center">
              <input
                type="checkbox"
                id={"rel-#{rel.name}"}
                class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                phx-click="toggle_relationship"
                phx-value-relationship={rel.name}
                phx-target={@myself}
              />
              <label for={"rel-#{rel.name}"} class="ml-2 text-sm text-gray-700">
                <%= rel.name %> (<%= rel.type %> → <%= resource_display_name(rel.destination) %>)
              </label>
            </div>
          </div>
        </div>

        <!-- Filters -->
        <div class="mt-4">
          <h4 class="text-sm font-medium text-gray-700">Filters</h4>
          <div class="mt-2 space-y-2">
            <div :for={{field, value} <- @filters} class="flex items-center gap-2">
              <span class="text-sm text-gray-600"><%= field %>:</span>
              <span class="rounded bg-white px-2 py-1 text-sm text-gray-900"><%= value %></span>
              <button
                phx-click="remove_filter"
                phx-value-field={field}
                phx-target={@myself}
                class="text-red-600 hover:text-red-800"
              >
                <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  />
                </svg>
              </button>
            </div>

            <!-- Add Filter Form -->
            <form phx-submit="add_filter" phx-target={@myself} class="flex gap-2">
              <select
                name="field"
                class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select field...</option>
                <option :for={field <- @resource_fields} value={field.name}>
                  <%= field.name %>
                </option>
              </select>
              <input
                type="text"
                name="value"
                placeholder="Filter value"
                class="block w-1/2 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
              <button
                type="submit"
                class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
              >
                Add
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper Functions

  defp notify_parent(socket, msg) do
    send(self(), {__MODULE__, msg})
    socket
  end

  defp list_available_resources do
    Domain
    |> Ash.Domain.Info.resources()
    |> Enum.sort_by(&resource_display_name/1)
  end

  defp get_resource_fields(nil), do: []

  defp get_resource_fields(resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.map(fn attr ->
      %{
        name: attr.name,
        type: attr.type,
        description: attr.description
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp get_resource_relationships(nil), do: []

  defp get_resource_relationships(resource) do
    resource
    |> Ash.Resource.Info.relationships()
    |> Enum.map(fn rel ->
      %{
        name: rel.name,
        type: rel.type,
        destination: rel.destination
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp resource_display_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> humanize()
  end

  defp resource_description(resource) do
    case resource do
      AshReportsDemo.Customer -> "Customer records with contact and status information"
      AshReportsDemo.Invoice -> "Invoice records with line items and totals"
      AshReportsDemo.Product -> "Product catalog with pricing and categories"
      AshReportsDemo.Inventory -> "Inventory tracking and stock levels"
      _ -> "Ash resource for data management"
    end
  end

  defp humanize(string) do
    string
    |> Macro.underscore()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
