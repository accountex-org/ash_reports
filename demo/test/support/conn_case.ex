defmodule AshReportsDemoWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  during the test are reverted at the end of every test.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint AshReportsDemoWeb.Endpoint

      use AshReportsDemoWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AshReportsDemoWeb.ConnCase
    end
  end

  setup _tags do
    # Ensure we have fresh test data for each test
    AshReportsDemo.DataGenerator.reset_data()
    
    # Generate some basic data for tests
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end