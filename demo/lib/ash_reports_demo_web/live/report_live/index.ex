defmodule AshReportsDemoWeb.ReportLive.Index do
  use AshReportsDemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> assign(:reports, list_reports())}
  end

  def handle_event("regenerate_data", _params, socket) do
    AshReportsDemo.DataGenerator.generate_sample_data(:small)

    {:noreply,
     socket
     |> put_flash(:info, "Sample data regenerated successfully!")
     |> assign(:reports, list_reports())}
  end

  def render(assigns) do
    ~H"""
    <.header>
      Available Reports
      <:subtitle>
        Explore different report types and data visualizations available in AshReports.
      </:subtitle>
    </.header>

    <div class="mt-8 space-y-6">
      <.button phx-click="regenerate_data">
        Regenerate Sample Data
      </.button>

      <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <div :for={report <- @reports} class="group relative rounded-lg border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md">
          <div>
            <h3 class="text-base font-semibold leading-7 tracking-tight text-gray-900">
              <%= report.title %>
            </h3>
            <p class="mt-1 text-sm leading-6 text-gray-600">
              <%= report.description %>
            </p>
          </div>
          <div class="mt-4">
            <.link 
              navigate={report.path} 
              class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500"
            >
              View Report
              <span aria-hidden="true" class="ml-1">&rarr;</span>
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp list_reports do
    [
      %{
        title: "Simple Report",
        description: "Basic tabular report showing customer data with simple formatting.",
        path: "/reports/simple"
      },
      %{
        title: "Complex Report",
        description: "Advanced report with grouping, calculations, and multiple data sources.",
        path: "/reports/complex"
      },
      %{
        title: "Interactive Report",
        description: "Real-time interactive report with filtering and live updates.",
        path: "/reports/interactive"
      }
    ]
  end
end
