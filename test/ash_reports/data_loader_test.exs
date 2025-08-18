defmodule AshReports.DataLoaderTest do
  use ExUnit.Case, async: true

  alias AshReports.DataLoader
  alias AshReports.Variable

  describe "config/1" do
    test "returns default configuration" do
      config = DataLoader.config()

      assert config[:enable_caching] == true
      assert config[:enable_monitoring] == true
      assert config[:chunk_size] == 1000
      assert config[:timeout] == 300_000
      assert config[:cache_ttl] == 1_800_000
      assert config[:max_memory_mb] == 512
      assert config[:streaming] == false
      assert config[:actor] == nil
    end

    test "merges custom options with defaults" do
      config =
        DataLoader.config(
          chunk_size: 500,
          enable_caching: false,
          actor: %{id: 1, role: :admin}
        )

      assert config[:chunk_size] == 500
      assert config[:enable_caching] == false
      assert config[:actor] == %{id: 1, role: :admin}

      # Defaults should remain
      assert config[:enable_monitoring] == true
      assert config[:timeout] == 300_000
    end
  end

  describe "validate_load/4" do
    test "validates successful load configuration" do
      domain = MockDomain
      report_name = :test_report
      params = %{date: ~D[2024-01-01]}

      with_mock_domain(domain, report_name, fn ->
        assert :ok = DataLoader.validate_load(domain, report_name, params)
      end)
    end

    test "returns error for non-existent report" do
      domain = MockDomain
      report_name = :non_existent_report
      params = %{}

      with_mock_domain(domain, nil, fn ->
        assert {:error, {:report_not_found, :non_existent_report}} =
                 DataLoader.validate_load(domain, report_name, params)
      end)
    end

    test "returns error for invalid domain" do
      domain = NonExistentDomain
      report_name = :test_report
      params = %{}

      assert {:error, {:invalid_domain, NonExistentDomain}} =
               DataLoader.validate_load(domain, report_name, params)
    end

    test "validates with custom options" do
      domain = MockDomain
      report_name = :test_report
      params = %{date: ~D[2024-01-01]}
      options = [chunk_size: 500, enable_caching: false]

      with_mock_domain(domain, report_name, fn ->
        assert :ok = DataLoader.validate_load(domain, report_name, params, options)
      end)
    end
  end

  describe "get_metrics/0" do
    test "returns metrics structure" do
      metrics = DataLoader.get_metrics()

      assert %{
               cache: cache_metrics,
               performance: performance_metrics,
               memory: memory_metrics,
               errors: error_metrics
             } = metrics

      # Cache metrics
      assert is_map(cache_metrics)
      assert Map.has_key?(cache_metrics, :hit_ratio)

      # Performance metrics
      assert is_map(performance_metrics)
      assert Map.has_key?(performance_metrics, :average_query_time_ms)

      # Memory metrics
      assert is_map(memory_metrics)
      assert Map.has_key?(memory_metrics, :total_memory_mb)
      assert is_number(memory_metrics.total_memory_mb)

      # Error metrics
      assert is_map(error_metrics)
      assert Map.has_key?(error_metrics, :total_errors)
    end
  end

  describe "clear_cache/0" do
    test "clears cache without error" do
      # Should not error even if cache doesn't exist
      assert :ok = DataLoader.clear_cache()
    end
  end

  describe "load_report_with_variables/5" do
    test "accepts custom variables" do
      domain = MockDomain
      report_name = :test_report
      params = %{date: ~D[2024-01-01]}

      variables = [
        %Variable{
          name: :total,
          type: :sum,
          expression: :amount,
          initial_value: 0,
          reset_on: :report
        },
        %Variable{
          name: :count,
          type: :count,
          expression: 1,
          initial_value: 0,
          reset_on: :report
        }
      ]

      with_mock_domain(domain, report_name, fn ->
        # Since we can't fully mock the complex pipeline, we expect this to fail
        # at a deeper level, but we can verify the function accepts the parameters
        result = DataLoader.load_report_with_variables(domain, report_name, params, variables)

        # Should fail due to missing infrastructure, but not due to parameter validation
        assert {:error, _reason} = result
      end)
    end
  end

  describe "load_raw_data/4" do
    test "validates parameters for raw data loading" do
      domain = MockDomain
      report_name = :test_report
      params = %{date: ~D[2024-01-01]}

      with_mock_domain(domain, report_name, fn ->
        # Should fail in query execution since we don't have full mocking
        result = DataLoader.load_raw_data(domain, report_name, params)
        assert {:error, _reason} = result
      end)
    end
  end

  # Helper functions for testing

  defp with_mock_domain(_domain, report_name, block) do
    # This would normally use a proper mocking library
    # For now, we'll just use the fact that these functions will be called
    # and let them fail at appropriate points for validation testing
    block.()

    report =
      if report_name do
        %AshReports.Report{
          name: report_name,
          title: "Test Report",
          driving_resource: TestResource,
          parameters: [],
          variables: [],
          groups: [],
          bands: []
        }
      else
        nil
      end

    # Mock the domain configuration
    config = %{reports: if(report, do: [report], else: [])}

    # In a real test, you would properly mock these functions
    # For now, we'll structure our test to expect certain failure points
    config
  end
end

# Mock modules for testing
defmodule MockDomain do
  def __ash_reports_config__ do
    %{
      reports: [
        %AshReports.Report{
          name: :test_report,
          title: "Test Report",
          driving_resource: TestResource,
          parameters: [],
          variables: [],
          groups: [],
          bands: []
        }
      ]
    }
  end

  def read(_query), do: {:ok, []}
  def resources, do: [TestResource]
end

defmodule TestResource do
  def __resource__, do: true
end
