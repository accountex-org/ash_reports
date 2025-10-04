defmodule AshReports.TestRouter do
  @moduledoc """
  Test router for Phoenix.Test compatibility.

  This router is only used in the test environment and provides
  minimal routing for testing purposes.
  """

  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", AshReports do
    pipe_through :browser

    # Minimal routes for testing
  end
end
