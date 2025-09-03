ExUnit.start()

# Configure ExUnit for demo testing
ExUnit.configure(
  exclude: [:benchmark, :slow],
  formatters: [ExUnit.CLIFormatter]
)

# Start demo application for tests
{:ok, _} = Application.ensure_all_started(:ash_reports_demo)

# Reset data before each test
ExUnit.after_suite(fn _results ->
  AshReportsDemo.DataGenerator.reset_data()
end)
