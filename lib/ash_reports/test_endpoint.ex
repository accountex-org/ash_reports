defmodule AshReports.TestEndpoint do
  @moduledoc """
  Test endpoint for Phoenix.Test compatibility.

  This endpoint is only used in the test environment to provide
  a minimal Phoenix endpoint for testing LiveView components.
  """

  use Phoenix.Endpoint, otp_app: :ash_reports

  @session_options [
    store: :cookie,
    key: "_ash_reports_test_key",
    signing_salt: "test_signing_salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug :fetch_session
  plug AshReports.TestRouter
end
