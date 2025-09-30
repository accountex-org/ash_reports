defmodule AshReports.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  This is needed for phoenix_test compatibility in the main AshReports library.
  """

  use ExUnit.CaseTemplate

  # Set the endpoint for PhoenixTest compatibility
  @endpoint AshReports.TestEndpoint

  using do
    quote do
      # The default endpoint for testing
      @endpoint AshReports.TestEndpoint

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PhoenixTest
      import AshReports.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

defmodule AshReports.TestEndpoint do
  @moduledoc """
  A test endpoint for AshReports library testing.
  This satisfies phoenix_test dependency requirements.
  """
  use Phoenix.Endpoint, otp_app: :ash_reports

  # Minimal endpoint configuration for testing
  @session_options [
    store: :cookie,
    key: "_ash_reports_test_key",
    signing_salt: "test_salt"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]
  )

  plug(Plug.Session, @session_options)
  plug(:fetch_session)

  def init(opts), do: opts
  def call(conn, _opts), do: conn
end