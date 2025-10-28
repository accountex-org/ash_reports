defmodule AshReports.TestEndpoint do
  @moduledoc """
  Test Phoenix endpoint for phoenix_test compatibility in test environment.

  This minimal endpoint is used when running tests to provide Phoenix.Endpoint
  functionality needed by some testing utilities.
  """

  use Phoenix.Endpoint, otp_app: :ash_reports

  # Required for phoenix_test compatibility
  plug Plug.Session,
    store: :cookie,
    key: "_ash_reports_test_key",
    signing_salt: "test_signing_salt"

  plug Plug.RequestId
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.Head
end
