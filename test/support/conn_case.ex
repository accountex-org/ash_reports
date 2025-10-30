defmodule AshReports.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  This is needed for phoenix_test compatibility in the main AshReports library.
  Includes support for LiveView component testing.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint AshReports.TestEndpoint

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import PhoenixTest
      import AshReports.ConnCase
    end
  end

  setup tags do
    # Start the test endpoint if not already started
    start_supervised!(AshReports.TestEndpoint)

    conn = Phoenix.ConnTest.build_conn()

    # Add session if needed for LiveView tests
    conn =
      if tags[:with_session] do
        conn
        |> Plug.Test.init_test_session(%{})
      else
        conn
      end

    {:ok, conn: conn}
  end
end

# Note: AshReports.TestEndpoint is defined in lib/ash_reports/test_endpoint.ex
