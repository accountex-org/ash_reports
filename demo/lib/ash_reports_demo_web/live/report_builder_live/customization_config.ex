defmodule AshReportsDemoWeb.ReportBuilderLive.CustomizationConfig do
  @moduledoc """
  LiveComponent for template customization in the Report Builder.

  Provides UI for:
  - Theme selection with visual previews
  - Brand color customization
  - Logo upload (placeholder for Phase 3)
  - Typography customization
  """

  use AshReportsDemoWeb, :live_component

  alias AshReports.Customization.{Theme, Config}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:themes, Theme.list_themes())
     |> assign(:selected_theme_id, nil)
     |> assign(:customization_config, Config.new())}
  end

  @impl true
  def update(%{config: report_config} = assigns, socket) do
    # Extract customization from report config if it exists
    customization = Map.get(report_config, :customization, Config.new())

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:customization_config, customization)
     |> assign(:selected_theme_id, customization.theme_id)}
  end

  @impl true
  def handle_event("select_theme", %{"theme" => theme_id_str}, socket) do
    theme_id = String.to_existing_atom(theme_id_str)

    updated_config = Config.set_theme(socket.assigns.customization_config, theme_id)

    # Notify parent of config change
    send(self(), {__MODULE__, {:customization_updated, updated_config}})

    {:noreply,
     socket
     |> assign(:customization_config, updated_config)
     |> assign(:selected_theme_id, theme_id)}
  end

  @impl true
  def handle_event("update_brand_color", %{"color_type" => type, "value" => color}, socket) do
    color_key = String.to_existing_atom(type)
    current_config = socket.assigns.customization_config

    updated_config =
      Config.set_brand_colors(current_config, %{color_key => color})

    send(self(), {__MODULE__, {:customization_updated, updated_config}})

    {:noreply, assign(socket, :customization_config, updated_config)}
  end

  @impl true
  def handle_event("update_font", %{"font_type" => type, "value" => font}, socket) do
    font_key = String.to_existing_atom(type)
    current_config = socket.assigns.customization_config

    updated_config =
      Config.set_custom_fonts(current_config, %{font_key => font})

    send(self(), {__MODULE__, {:customization_updated, updated_config}})

    {:noreply, assign(socket, :customization_config, updated_config)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-base font-semibold text-gray-900">Customize Appearance</h3>
      <p class="mt-1 text-sm text-gray-600">
        Select a theme and customize colors to match your brand
      </p>

      <!-- Theme Selection -->
      <div class="mt-6">
        <label class="text-sm font-medium text-gray-900">Select Theme</label>
        <div class="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={theme <- @themes}
            class={[
              "cursor-pointer rounded-lg border p-4 transition-all hover:border-blue-500",
              if(@selected_theme_id == theme.id,
                do: "border-blue-500 bg-blue-50 ring-2 ring-blue-500",
                else: "border-gray-200"
              )
            ]}
            phx-click="select_theme"
            phx-value-theme={theme.id}
            phx-target={@myself}
          >
            <div class="flex items-start justify-between">
              <div>
                <h4 class="font-semibold text-gray-900"><%= theme.name %></h4>
                <p class="mt-1 text-xs text-gray-600"><%= theme.description %></p>
              </div>
              <%= if @selected_theme_id == theme.id do %>
                <svg class="h-5 w-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              <% end %>
            </div>

            <!-- Color Palette Preview -->
            <div class="mt-3 flex gap-1">
              <div
                class="h-6 w-6 rounded"
                style={"background-color: #{theme.colors.primary}"}
                title="Primary"
              >
              </div>
              <div
                class="h-6 w-6 rounded"
                style={"background-color: #{theme.colors.secondary}"}
                title="Secondary"
              >
              </div>
              <div
                class="h-6 w-6 rounded"
                style={"background-color: #{theme.colors.accent}"}
                title="Accent"
              >
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Brand Colors Customization -->
      <%= if @selected_theme_id do %>
        <div class="mt-8">
          <label class="text-sm font-medium text-gray-900">Brand Colors</label>
          <p class="mt-1 text-xs text-gray-500">
            Customize theme colors to match your brand (optional)
          </p>

          <div class="mt-4 grid gap-4 sm:grid-cols-3">
            <div>
              <label class="block text-xs font-medium text-gray-700">Primary Color</label>
              <div class="mt-1 flex items-center gap-2">
                <input
                  type="color"
                  class="h-10 w-16 cursor-pointer rounded border border-gray-300"
                  value={get_brand_color(@customization_config, :primary, get_theme_color(@themes, @selected_theme_id, :primary))}
                  phx-change="update_brand_color"
                  phx-value-color_type="primary"
                  phx-target={@myself}
                />
                <span class="text-sm text-gray-600">
                  <%= get_brand_color(@customization_config, :primary, get_theme_color(@themes, @selected_theme_id, :primary)) %>
                </span>
              </div>
            </div>

            <div>
              <label class="block text-xs font-medium text-gray-700">Secondary Color</label>
              <div class="mt-1 flex items-center gap-2">
                <input
                  type="color"
                  class="h-10 w-16 cursor-pointer rounded border border-gray-300"
                  value={get_brand_color(@customization_config, :secondary, get_theme_color(@themes, @selected_theme_id, :secondary))}
                  phx-change="update_brand_color"
                  phx-value-color_type="secondary"
                  phx-target={@myself}
                />
                <span class="text-sm text-gray-600">
                  <%= get_brand_color(@customization_config, :secondary, get_theme_color(@themes, @selected_theme_id, :secondary)) %>
                </span>
              </div>
            </div>

            <div>
              <label class="block text-xs font-medium text-gray-700">Accent Color</label>
              <div class="mt-1 flex items-center gap-2">
                <input
                  type="color"
                  class="h-10 w-16 cursor-pointer rounded border border-gray-300"
                  value={get_brand_color(@customization_config, :accent, get_theme_color(@themes, @selected_theme_id, :accent))}
                  phx-change="update_brand_color"
                  phx-value-color_type="accent"
                  phx-target={@myself}
                />
                <span class="text-sm text-gray-600">
                  <%= get_brand_color(@customization_config, :accent, get_theme_color(@themes, @selected_theme_id, :accent)) %>
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Typography Preview -->
        <div class="mt-8">
          <label class="text-sm font-medium text-gray-900">Typography</label>
          <div class="mt-3 rounded-lg border border-gray-200 bg-gray-50 p-4">
            <%!-- Show current theme typography --%>
            <% effective_theme = Config.get_effective_theme(@customization_config) %>
            <%= if effective_theme do %>
              <div class="space-y-2 text-sm">
                <p class="text-gray-600">
                  <span class="font-medium">Font Family:</span>
                  <%= effective_theme.typography.font_family %>
                </p>
                <p class="text-gray-600">
                  <span class="font-medium">Heading Size:</span>
                  <%= effective_theme.typography.heading_size %>
                </p>
                <p class="text-gray-600">
                  <span class="font-medium">Body Size:</span>
                  <%= effective_theme.typography.body_size %>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp get_brand_color(config, color_key, default) do
    Map.get(config.brand_colors, color_key, default)
  end

  defp get_theme_color(themes, theme_id, color_key) do
    theme = Enum.find(themes, fn t -> t.id == theme_id end)
    if theme, do: Map.get(theme.colors, color_key), else: "#000000"
  end
end
