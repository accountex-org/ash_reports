ExUnit.start()

# Configure ExUnit for demo testing
ExUnit.configure(
  exclude: [:benchmark, :slow],
  formatters: [ExUnit.CLIFormatter]
)

# Configure PhoenixTest with the endpoint
Application.put_env(:phoenix_test, :endpoint, AshReportsDemoWeb.Endpoint)

# Start demo application for tests
{:ok, _} = Application.ensure_all_started(:ash_reports_demo)

# Start the endpoint for integration tests
Application.put_env(:ash_reports_demo, :sql_sandbox, true)

case AshReportsDemoWeb.Endpoint.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

# Reset data before each test
ExUnit.after_suite(fn _results ->
  AshReportsDemo.DataGenerator.reset_data()
end)
