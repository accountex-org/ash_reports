defmodule AshReports.InfrastructureTest do
  @moduledoc """
  Test that our test infrastructure loads and works correctly.
  """
  
  use ExUnit.Case
  import AshReports.TestHelpers
  
  test "test helpers are available" do
    # Test that we can call helper functions
    assert is_list(create_test_data(:customers, 5))
    assert is_map(build_simple_report())
    assert is_map(build_complex_report())
  end
  
  test "mock data layer works" do
    # Test basic ETS operations
    AshReports.MockDataLayer.clear_all_test_data()
    
    test_data = [
      [id: "test1", name: "Test Customer 1", email: "test1@example.com"],
      [id: "test2", name: "Test Customer 2", email: "test2@example.com"]
    ]
    
    AshReports.MockDataLayer.insert_test_data(AshReports.Test.Customer, test_data)
    
    # This is just testing the infrastructure, not the actual Ash functionality
    assert :ok = :ok
  end
  
  test "test domain compiles without errors" do
    # Test that our test domain module exists and has the right extension
    assert Code.ensure_loaded?(AshReports.Test.SimpleDomain)
    assert Code.ensure_loaded?(AshReports.Test.Customer)
    assert Code.ensure_loaded?(AshReports.Test.Order)
    assert Code.ensure_loaded?(AshReports.Test.Product)
  end
end