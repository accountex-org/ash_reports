defmodule AshReportsDemoWeb.ReportLive.Simple do
  use AshReportsDemoWeb, :live_view

  alias AshReportsDemo.Domain
  alias AshReportsDemo.Resources.Customer

  def mount(_params, _session, socket) do
    customers = load_customers()

    {:ok,
     socket
     |> assign(:page_title, "Simple Report")
     |> assign(:customers, customers)
     |> assign(:total_customers, length(customers))}
  end

  def handle_event("refresh", _params, socket) do
    customers = load_customers()

    {:noreply,
     socket
     |> put_flash(:info, "Report refreshed!")
     |> assign(:customers, customers)
     |> assign(:total_customers, length(customers))}
  end

  def render(assigns) do
    ~H"""
    <div class="mb-4">
      <.link navigate="/reports" class="text-sm font-medium text-blue-600 hover:text-blue-500">
        ← Back to Reports
      </.link>
    </div>

    <.header>
      Simple Customer Report
      <:subtitle>
        Basic customer listing with contact information. Total customers: <%= @total_customers %>
      </:subtitle>
    </.header>

    <div class="mt-8">
      <div class="mb-4">
        <.button phx-click="refresh">
          Refresh Report
        </.button>
      </div>

      <div class="overflow-hidden bg-white shadow ring-1 ring-gray-900/5 rounded-lg">
        <table class="min-w-full divide-y divide-gray-300">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Name
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Email
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Phone
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Type
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr :for={customer <- @customers} class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                <%= customer.first_name %> <%= customer.last_name %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <%= customer.email %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <%= customer.phone || "N/A" %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <span class={[
                  "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                  customer_type_class(customer.customer_type)
                ]}>
                  <%= customer.customer_type %>
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@total_customers == 0} class="text-center py-12">
        <p class="text-sm text-gray-500">No customers found. Try generating some sample data first.</p>
      </div>
    </div>
    """
  end

  defp load_customers do
    try do
      Ash.read!(Customer, domain: Domain, query: Ash.Query.limit(Customer, 50))
    rescue
      _ -> []
    end
  end

  defp customer_type_class(type) do
    case type do
      :premium -> "bg-yellow-100 text-yellow-800"
      :business -> "bg-blue-100 text-blue-800"
      :individual -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
