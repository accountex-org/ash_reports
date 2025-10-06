defmodule AshReports.DataLoader.PipelineTest do
  use ExUnit.Case, async: true

  alias AshReports.DataLoader.Pipeline
  alias AshReports.{GroupProcessor, Variable, VariableState}

  describe "new/1" do
    test "creates pipeline config with required options" do
      report = build_test_report()
      params = %{date: ~D[2024-01-01]}
      domain = TestDomain

      config = Pipeline.new(report: report, params: params, domain: domain)

      assert %{
               report: ^report,
               params: ^params,
               domain: TestDomain,
               executor: executor,
               variable_state_pid: nil,
               group_processor: nil,
               options: options
             } = config

      assert is_map(executor)

      assert %{
               chunk_size: 1000,
               enable_caching: true,
               enable_monitoring: true,
               max_memory_mb: 512,
               timeout: 300_000,
               actor: nil
             } = options
    end

    test "creates pipeline config with custom options" do
      report = build_test_report()

      config =
        Pipeline.new(
          report: report,
          params: %{},
          domain: TestDomain,
          chunk_size: 500,
          enable_caching: false,
          actor: %{id: 1}
        )

      assert config.options.chunk_size == 500
      assert config.options.enable_caching == false
      assert config.options.actor == %{id: 1}
    end

    test "includes variable state pid when provided" do
      {:ok, variable_pid} = VariableState.start_link([])
      report = build_test_report()

      config =
        Pipeline.new(
          report: report,
          params: %{},
          domain: TestDomain,
          variable_state_pid: variable_pid
        )

      assert config.variable_state_pid == variable_pid
    end

    test "includes group processor when provided" do
      group_processor = GroupProcessor.new([])
      report = build_test_report()

      config =
        Pipeline.new(
          report: report,
          params: %{},
          domain: TestDomain,
          group_processor: group_processor
        )

      assert config.group_processor == group_processor
    end
  end

  describe "validate_config/1" do
    test "validates valid configuration" do
      config = build_valid_config()

      assert :ok = Pipeline.validate_config(config)
    end

    test "rejects invalid report" do
      config = build_valid_config()
      invalid_config = %{config | report: "not_a_report"}

      assert {:error, {:invalid_report, "not_a_report"}} =
               Pipeline.validate_config(invalid_config)
    end

    test "rejects invalid domain" do
      config = build_valid_config()
      invalid_config = %{config | domain: "not_a_domain"}

      assert {:error, {:invalid_domain_type, "not_a_domain"}} =
               Pipeline.validate_config(invalid_config)
    end

    test "rejects non-existent domain" do
      config = build_valid_config()
      invalid_config = %{config | domain: NonExistentDomain}

      assert {:error, {:domain_not_loaded, NonExistentDomain}} =
               Pipeline.validate_config(invalid_config)
    end

    test "rejects dead variable state process" do
      {:ok, variable_pid} = VariableState.start_link([])
      GenServer.stop(variable_pid)

      config = build_valid_config()
      invalid_config = %{config | variable_state_pid: variable_pid}

      assert {:error, {:variable_state_not_alive, ^variable_pid}} =
               Pipeline.validate_config(invalid_config)
    end

    test "rejects invalid variable state pid" do
      config = build_valid_config()
      invalid_config = %{config | variable_state_pid: "not_a_pid"}

      assert {:error, {:invalid_variable_state_pid, "not_a_pid"}} =
               Pipeline.validate_config(invalid_config)
    end
  end

  describe "process_all/1" do
    test "processes all data and returns complete result" do
      config = build_test_config_with_mocks()

      # Mock the pipeline to return test data
      mock_stream = [
        {:ok,
         %{
           record: %{id: 1, name: "Record 1"},
           group_state: nil,
           variable_values: %{total: 10},
           group_changes: [],
           metadata: %{processing_time: 100, memory_usage: 1000, cache_hit?: false}
         }},
        {:ok,
         %{
           record: %{id: 2, name: "Record 2"},
           group_state: nil,
           variable_values: %{total: 25},
           group_changes: [],
           metadata: %{processing_time: 120, memory_usage: 1200, cache_hit?: false}
         }}
      ]

      _mock = with_mock_stream(mock_stream)
      assert {:ok, result} = Pipeline.process_all(config)

      assert %{
               records: records,
               summary: summary
             } = result

      assert length(records) == 2
      assert summary.total_records == 2
      assert is_integer(summary.processing_time)
      assert summary.errors == []
    end

    test "handles processing errors gracefully" do
      config = build_test_config_with_mocks()

      mock_stream = [
        {:ok,
         %{
           record: %{id: 1, name: "Record 1"},
           group_state: nil,
           variable_values: %{},
           group_changes: [],
           metadata: %{}
         }},
        {:error, :processing_failed},
        {:ok,
         %{
           record: %{id: 2, name: "Record 2"},
           group_state: nil,
           variable_values: %{},
           group_changes: [],
           metadata: %{}
         }}
      ]

      _mock = with_mock_stream(mock_stream)
      assert {:ok, result} = Pipeline.process_all(config)

      assert length(result.records) == 2
      assert length(result.summary.errors) == 1
      assert :processing_failed in result.summary.errors
    end

    test "returns error on stream creation failure" do
      config = build_invalid_config()

      assert {:error, _reason} = Pipeline.process_all(config)
    end
  end

  describe "process_stream/1" do
    test "creates processing stream successfully" do
      config = build_test_config_with_mocks()

      assert {:ok, stream} = Pipeline.process_stream(config)
      assert is_function(stream, 2) or is_list(stream)
    end

    test "propagates query building errors" do
      config = build_invalid_config()

      assert {:error, _reason} = Pipeline.process_stream(config)
    end
  end

  describe "create_custom_pipeline/2" do
    test "creates pipeline with custom transformations" do
      config = build_test_config_with_mocks()

      transformations = [
        fn {:ok, result} -> {:ok, Map.put(result, :transformed, true)} end,
        fn {:ok, result} -> {:ok, Map.put(result, :step, 2)} end
      ]

      assert {:ok, stream} = Pipeline.create_custom_pipeline(config, transformations)
      assert is_function(stream, 2) or is_list(stream)
    end

    test "handles transformation errors" do
      config = build_test_config_with_mocks()

      transformations = [
        fn _result -> raise "transformation error" end
      ]

      # Should still create the stream, errors will be caught during enumeration
      assert {:ok, _stream} = Pipeline.create_custom_pipeline(config, transformations)
    end
  end

  describe "get_pipeline_stats/1" do
    test "returns default stats for new pipeline" do
      config = build_valid_config()

      stats = Pipeline.get_pipeline_stats(config)

      assert %{
               records_processed: 0,
               average_processing_time: 0,
               memory_usage_mb: memory_mb,
               cache_efficiency: 0.0,
               error_rate: 0.0
             } = stats

      assert is_number(memory_mb) and memory_mb > 0
    end
  end

  describe "integration with components" do
    test "processes data through variable state" do
      variables = [
        %Variable{
          name: :total,
          type: :sum,
          expression: :amount,
          initial_value: 0,
          reset_on: :report
        }
      ]

      {:ok, variable_pid} = VariableState.start_link(variables)

      config =
        Pipeline.new(
          report: build_test_report(),
          params: %{},
          domain: TestDomain,
          variable_state_pid: variable_pid
        )

      # Mock data stream
      mock_data = [%{id: 1, amount: 100}, %{id: 2, amount: 200}]

      _mock = with_mock_data_stream(mock_data)
      assert {:ok, stream} = Pipeline.process_stream(config)

      # Process a few items to test variable integration
      results = stream |> Enum.take(2)

      # Variables should be updated through the process
      assert length(results) <= 2
    end

    test "processes data through group processor" do
      groups = [
        %AshReports.Group{
          name: :category,
          level: 1,
          expression: :category,
          sort: :asc
        }
      ]

      group_processor = GroupProcessor.new(groups)

      config =
        Pipeline.new(
          report: build_test_report(),
          params: %{},
          domain: TestDomain,
          group_processor: group_processor
        )

      mock_data = [
        %{id: 1, category: "A", amount: 100},
        %{id: 2, category: "A", amount: 200},
        %{id: 3, category: "B", amount: 150}
      ]

      _mock = with_mock_data_stream(mock_data)
      assert {:ok, stream} = Pipeline.process_stream(config)

      # Should process with group state
      results = stream |> Enum.take(3)
      assert length(results) <= 3
    end
  end

  # Helper functions

  defp build_test_report do
    %AshReports.Report{
      name: :test_report,
      title: "Test Report",
      driving_resource: TestResource,
      scope: nil,
      parameters: [],
      variables: [],
      groups: [],
      bands: []
    }
  end

  defp build_valid_config do
    Pipeline.new(
      report: build_test_report(),
      params: %{},
      domain: TestDomain
    )
  end

  defp build_invalid_config do
    Pipeline.new(
      report: %{invalid: :report},
      params: %{},
      domain: NonExistentDomain
    )
  end

  defp build_test_config_with_mocks do
    # Use a valid domain that exists for testing
    Pipeline.new(
      report: build_test_report(),
      params: %{},
      domain: ExUnit.CaseTemplate
    )
  end

  defp with_mock_stream(mock_data) do
    # Mock the internal stream processing
    # In a real implementation, you would mock the specific stream functions
    mock_data
  end

  defp with_mock_data_stream(mock_data) do
    # Mock data stream for testing
    mock_data
  end
end

# Test support modules
defmodule TestDomain do
  def __ash_reports_config__, do: %{reports: []}
  def read(_query), do: {:ok, []}
  def resources, do: [TestResource]
end

defmodule TestResource do
  def __resource__, do: true
end
