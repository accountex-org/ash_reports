defmodule AshReportsDemoWeb.Router do
  use AshReportsDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AshReportsDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AshReportsDemoWeb do
    pipe_through :browser

    get "/", PageController, :home
    
    # Report demonstrations
    live "/reports", ReportLive.Index, :index
    live "/reports/simple", ReportLive.Simple, :show
    live "/reports/complex", ReportLive.Complex, :show
    live "/reports/interactive", ReportLive.Interactive, :show
    
    # Dashboard demonstrations
    live "/dashboard", DashboardLive.Index, :index
    live "/dashboard/sales", DashboardLive.Sales, :show
    live "/dashboard/analytics", DashboardLive.Analytics, :show
    
    # Chart demonstrations
    live "/charts", ChartLive.Index, :index
    live "/charts/line", ChartLive.Line, :show
    live "/charts/bar", ChartLive.Bar, :show
    live "/charts/pie", ChartLive.Pie, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", AshReportsDemoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:ash_reports_demo, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AshReportsDemoWeb.Telemetry
    end
  end
end