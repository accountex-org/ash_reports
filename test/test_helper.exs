ExUnit.start()

# Configure ExUnit
ExUnit.configure(exclude: [:performance])

# Add support directory to code path
Code.require_file("support/mock_data_layer.ex", __DIR__)
Code.require_file("support/test_resources.ex", __DIR__)
Code.require_file("support/test_helpers.ex", __DIR__)

# Note: Test helpers are imported in individual test files as needed
# import AshReports.TestHelpers

# Setup and teardown for tests
ExUnit.after_suite(fn _results ->
  AshReports.MockDataLayer.clear_all_test_data()
end)
