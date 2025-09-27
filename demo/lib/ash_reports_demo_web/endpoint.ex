defmodule AshReportsDemoWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint for AshReports demo application.

  Provides web interface to showcase AshReports functionality with
  LiveView integration, chart demonstrations, and interactive reports.
  """

  use Phoenix.Endpoint, otp_app: :ash_reports_demo

  @session_options [
    store: :cookie,
    key: "_ash_reports_demo_key",
    signing_salt: "ash_reports_demo_salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve static assets
  plug Plug.Static,
    at: "/",
    from: :ash_reports_demo,
    gzip: false,
    only: AshReportsDemoWeb.static_paths()

  # Code reloading for development
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug AshReportsDemoWeb.Router
end
