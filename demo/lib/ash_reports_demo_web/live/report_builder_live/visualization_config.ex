defmodule AshReportsDemoWeb.ReportBuilderLive.VisualizationConfig do
  @moduledoc """
  LiveComponent for configuring report visualizations and charts.

  Allows users to:
  - Select chart types (bar, line, pie, area, scatter)
  - Configure chart properties (title, dimensions, colors)
  - Map data fields to chart axes
  - Preview chart configuration
  - Add multiple charts to a report
  """

  use AshReportsDemoWeb, :live_component

  alias AshReports.Charts.Config, as: ChartConfig

  @chart_types [
    %{id: :bar, name: "Bar Chart", description: "Compare values across categories"},
    %{id: :line, name: "Line Chart", description: "Show trends over time"},
    %{id: :pie, name: "Pie Chart", description: "Display proportions of a whole"},
    %{id: :area, name: "Area Chart", description: "Stacked time-series data"},
    %{id: :scatter, name: "Scatter Plot", description: "Show correlation between variables"}
  ]

  @themes [:default, :corporate, :minimal, :vibrant]
  @legend_positions [:top, :bottom, :left, :right]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:visualizations, [])
     |> assign(:selected_chart_type, nil)
     |> assign(:chart_config, default_chart_config())
     |> assign(:editing_index, nil)
     |> assign(:errors, %{})}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if assigns[:config][:visualizations] do
        assign(socket, :visualizations, assigns.config.visualizations)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_chart_type", %{"type" => type}, socket) do
    chart_type = String.to_existing_atom(type)

    {:noreply,
     socket
     |> assign(:selected_chart_type, chart_type)
     |> assign(:chart_config, default_chart_config())}
  rescue
    ArgumentError ->
      {:noreply, put_flash(socket, :error, "Invalid chart type")}
  end

  @impl true
  def handle_event("update_config", %{"field" => field, "value" => value}, socket) do
    config = socket.assigns.chart_config
    field_atom = String.to_existing_atom(field)

    updated_config = update_config_field(config, field_atom, value)

    {:noreply, assign(socket, :chart_config, updated_config)}
  rescue
    ArgumentError ->
      {:noreply, put_flash(socket, :error, "Invalid configuration field")}
  end

  @impl true
  def handle_event("add_visualization", _params, socket) do
    chart_type = socket.assigns.selected_chart_type
    config = socket.assigns.chart_config

    if chart_type do
      visualization = %{
        type: chart_type,
        config: config,
        id: generate_id()
      }

      visualizations = socket.assigns.visualizations ++ [visualization]

      {:noreply,
       socket
       |> assign(:visualizations, visualizations)
       |> assign(:selected_chart_type, nil)
       |> assign(:chart_config, default_chart_config())
       |> notify_parent({:visualizations_updated, visualizations})}
    else
      {:noreply, put_flash(socket, :error, "Please select a chart type first")}
    end
  end

  @impl true
  def handle_event("edit_visualization", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    visualization = Enum.at(socket.assigns.visualizations, index)

    if visualization do
      {:noreply,
       socket
       |> assign(:editing_index, index)
       |> assign(:selected_chart_type, visualization.type)
       |> assign(:chart_config, visualization.config)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_visualization", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    visualizations = List.delete_at(socket.assigns.visualizations, index)

    {:noreply,
     socket
     |> assign(:visualizations, visualizations)
     |> notify_parent({:visualizations_updated, visualizations})}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_index, nil)
     |> assign(:selected_chart_type, nil)
     |> assign(:chart_config, default_chart_config())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"visualization-config-#{@id}"} class="space-y-6">
      <!-- Chart Type Selection -->
      <div>
        <h3 class="text-sm font-semibold text-gray-900">Add Visualization</h3>
        <p class="mt-1 text-sm text-gray-600">
          Select a chart type and configure its properties
        </p>

        <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={chart_type <- @chart_types}
            class={[
              "cursor-pointer rounded-lg border p-4 transition-all hover:border-blue-500",
              if(@selected_chart_type == chart_type.id,
                do: "border-blue-500 bg-blue-50 ring-2 ring-blue-500",
                else: "border-gray-200"
              )
            ]}
            phx-click="select_chart_type"
            phx-value-type={chart_type.id}
            phx-target={@myself}
          >
            <div class="flex items-start justify-between">
              <div>
                <h4 class="font-semibold text-gray-900"><%= chart_type.name %></h4>
                <p class="mt-1 text-sm text-gray-600"><%= chart_type.description %></p>
              </div>
              <div :if={@selected_chart_type == chart_type.id} class="text-blue-600">
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
      <!-- Chart Configuration Form -->
      <div :if={@selected_chart_type} class="rounded-lg border border-gray-200 bg-gray-50 p-4">
        <h4 class="text-sm font-semibold text-gray-900">Chart Configuration</h4>

        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <!-- Title -->
          <div class="sm:col-span-2">
            <label class="block text-sm font-medium text-gray-700">Chart Title</label>
            <input
              type="text"
              value={@chart_config.title}
              phx-change="update_config"
              phx-value-field="title"
              phx-target={@myself}
              name="value"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              placeholder="Enter chart title"
            />
          </div>
          <!-- Width -->
          <div>
            <label class="block text-sm font-medium text-gray-700">Width (px)</label>
            <input
              type="number"
              value={@chart_config.width}
              phx-change="update_config"
              phx-value-field="width"
              phx-target={@myself}
              name="value"
              min="100"
              max="5000"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>
          <!-- Height -->
          <div>
            <label class="block text-sm font-medium text-gray-700">Height (px)</label>
            <input
              type="number"
              value={@chart_config.height}
              phx-change="update_config"
              phx-value-field="height"
              phx-target={@myself}
              name="value"
              min="100"
              max="5000"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>
          <!-- Theme -->
          <div>
            <label class="block text-sm font-medium text-gray-700">Theme</label>
            <select
              phx-change="update_config"
              phx-value-field="theme_name"
              phx-target={@myself}
              name="value"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option :for={theme <- @themes} value={theme} selected={@chart_config.theme_name == theme}>
                <%= humanize_atom(theme) %>
              </option>
            </select>
          </div>
          <!-- Legend Position -->
          <div>
            <label class="block text-sm font-medium text-gray-700">Legend Position</label>
            <select
              phx-change="update_config"
              phx-value-field="legend_position"
              phx-target={@myself}
              name="value"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option
                :for={pos <- @legend_positions}
                value={pos}
                selected={@chart_config.legend_position == pos}
              >
                <%= humanize_atom(pos) %>
              </option>
            </select>
          </div>
          <!-- Show Grid -->
          <div class="flex items-center">
            <input
              type="checkbox"
              checked={@chart_config.show_grid}
              phx-click="update_config"
              phx-value-field="show_grid"
              phx-value-value={!@chart_config.show_grid}
              phx-target={@myself}
              id="show-grid"
              class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="show-grid" class="ml-2 block text-sm text-gray-700">Show Grid Lines</label>
          </div>
          <!-- Show Legend -->
          <div class="flex items-center">
            <input
              type="checkbox"
              checked={@chart_config.show_legend}
              phx-click="update_config"
              phx-value-field="show_legend"
              phx-value-value={!@chart_config.show_legend}
              phx-target={@myself}
              id="show-legend"
              class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="show-legend" class="ml-2 block text-sm text-gray-700">Show Legend</label>
          </div>
        </div>

        <div class="mt-4 flex gap-2">
          <button
            phx-click="add_visualization"
            phx-target={@myself}
            class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-500"
          >
            <%= if @editing_index, do: "Update Chart", else: "Add Chart" %>
          </button>
          <button
            :if={@editing_index}
            phx-click="cancel_edit"
            phx-target={@myself}
            class="inline-flex items-center rounded-md bg-gray-600 px-3 py-2 text-sm font-semibold text-white hover:bg-gray-500"
          >
            Cancel
          </button>
        </div>
      </div>
      <!-- Visualizations List -->
      <div :if={length(@visualizations) > 0}>
        <h4 class="text-sm font-semibold text-gray-900">Added Charts</h4>

        <div class="mt-3 space-y-2">
          <div
            :for={{viz, idx} <- Enum.with_index(@visualizations)}
            class="flex items-center justify-between rounded-lg border border-gray-200 bg-white p-3"
          >
            <div class="flex-1">
              <div class="flex items-center gap-2">
                <span class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800">
                  <%= humanize_atom(viz.type) %>
                </span>
                <span class="text-sm font-medium text-gray-900">
                  <%= viz.config.title || "Untitled Chart" %>
                </span>
              </div>
              <p class="mt-1 text-xs text-gray-500">
                <%= viz.config.width %>x<%= viz.config.height %>px · <%= humanize_atom(
                  viz.config.theme_name
                ) %> theme
              </p>
            </div>

            <div class="flex gap-2">
              <button
                phx-click="edit_visualization"
                phx-value-index={idx}
                phx-target={@myself}
                class="text-blue-600 hover:text-blue-800"
                title="Edit"
              >
                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                  />
                </svg>
              </button>
              <button
                phx-click="remove_visualization"
                phx-value-index={idx}
                phx-target={@myself}
                class="text-red-600 hover:text-red-800"
                title="Remove"
              >
                <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  />
                </svg>
              </button>
            </div>
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

  defp default_chart_config do
    %ChartConfig{
      title: "",
      width: 600,
      height: 400,
      theme_name: :default,
      show_legend: true,
      legend_position: :right,
      show_grid: true,
      show_data_labels: false,
      responsive: false
    }
  end

  defp update_config_field(config, field, value) do
    case field do
      :title -> %{config | title: value}
      :width -> %{config | width: parse_integer(value, config.width)}
      :height -> %{config | height: parse_integer(value, config.height)}
      :theme_name -> %{config | theme_name: String.to_existing_atom(value)}
      :legend_position -> %{config | legend_position: String.to_existing_atom(value)}
      :show_grid -> %{config | show_grid: parse_boolean(value)}
      :show_legend -> %{config | show_legend: parse_boolean(value)}
      :show_data_labels -> %{config | show_data_labels: parse_boolean(value)}
      :responsive -> %{config | responsive: parse_boolean(value)}
      _ -> config
    end
  end

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value

  defp parse_boolean(value) when is_binary(value) do
    value in ["true", "on", "1"]
  end

  defp parse_boolean(value) when is_boolean(value), do: value

  defp humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp chart_types, do: @chart_types
  defp themes, do: @themes
  defp legend_positions, do: @legend_positions
end
