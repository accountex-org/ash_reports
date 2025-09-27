defmodule AshReportsDemoWeb.PageController do
  use AshReportsDemoWeb, :controller

  def home(conn, _params) do
    # The home page is often custom, but here we'll just
    # render a welcome page that links to our demos
    render(conn, :home, layout: false)
  end
end
