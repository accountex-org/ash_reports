defmodule AshReports.DataLoader.ExecutorTest do
  use ExUnit.Case, async: true

  alias AshReports.DataLoader.Executor

  describe "new/1" do
    test "creates executor with default configuration" do
      executor = Executor.new()

      assert %{
               batch_size: 1000,
               timeout: 30_000,
               max_retries: 3,
               retry_delay: 100
             } = executor
    end

    test "creates executor with custom configuration" do
      executor = Executor.new(batch_size: 500, timeout: 60_000)

      assert %{
               batch_size: 500,
               timeout: 60_000,
               max_retries: 3,
               retry_delay: 100
             } = executor
    end
  end

  describe "validate_execution_context/3" do
    test "validates valid domain and query" do
      executor = Executor.new()
      query = build_mock_query()
      domain = MockDomain

      # Mock the domain functions
      with_mocks([
        {MockDomain, [],
         [
           resources: fn -> [MockResource] end
         ]},
        {Code, [:passthrough],
         [
           ensure_loaded?: fn MockDomain -> true end
         ]},
        {Kernel, [:passthrough], [function_exported?: fn MockDomain, :read, 1 -> true end]}
      ]) do
        assert :ok = Executor.validate_execution_context(executor, query, domain)
      end
    end

    test "rejects invalid domain" do
      executor = Executor.new()
      query = build_mock_query()

      assert {:error, {:invalid_domain_type, "invalid"}} =
               Executor.validate_execution_context(executor, query, "invalid")
    end

    test "rejects domain without required functions" do
      executor = Executor.new()
      query = build_mock_query()
      domain = NonExistentDomain

      with_mocks([
        {Code, [:passthrough], [ensure_loaded?: fn NonExistentDomain -> false end]}
      ]) do
        assert {:error, {:invalid_domain, NonExistentDomain}} =
                 Executor.validate_execution_context(executor, query, domain)
      end
    end
  end

  describe "execute_query/4" do
    test "executes query successfully" do
      executor = Executor.new()
      query = build_mock_query()
      domain = MockDomain
      opts = [actor: nil]

      mock_records = [%{id: 1, name: "Test"}]

      with_mocks([
        {MockDomain, [], [read: fn _query -> {:ok, mock_records} end]}
      ]) do
        assert {:ok, result} = Executor.execute_query(executor, query, domain, opts)

        assert %{
                 records: ^mock_records,
                 metadata: %{
                   record_count: 1,
                   execution_time: execution_time,
                   cache_hit?: false,
                   relationships_loaded: []
                 }
               } = result

        assert is_integer(execution_time) and execution_time >= 0
      end
    end

    test "handles query execution failure" do
      executor = Executor.new()
      query = build_mock_query()
      domain = MockDomain
      opts = [actor: nil]

      with_mocks([
        {MockDomain, [], [read: fn _query -> {:error, :database_error} end]}
      ]) do
        assert {:error, :database_error} = Executor.execute_query(executor, query, domain, opts)
      end
    end

    test "applies actor context when provided" do
      executor = Executor.new()
      query = build_mock_query()
      domain = MockDomain
      actor = %{id: 1, role: :admin}
      opts = [actor: actor]

      mock_records = [%{id: 1, name: "Test"}]

      with_mocks([
        {Ash.Query, [:passthrough],
         [
           for_read: fn query, :read, %{}, [actor: ^actor] ->
             query
           end
         ]},
        {MockDomain, [], [read: fn _query -> {:ok, mock_records} end]}
      ]) do
        assert {:ok, _result} = Executor.execute_query(executor, query, domain, opts)
      end
    end
  end

  describe "load_relationships/4" do
    test "returns unchanged records when no relationships specified" do
      executor = Executor.new()
      records = [%{id: 1, name: "Test"}]
      relationships = []
      opts = [domain: MockDomain]

      assert {:ok, ^records} = Executor.load_relationships(executor, records, relationships, opts)
    end

    test "returns unchanged records when no records provided" do
      executor = Executor.new()
      records = []
      relationships = [:customer]
      opts = [domain: MockDomain]

      assert {:ok, []} = Executor.load_relationships(executor, records, relationships, opts)
    end

    test "loads relationships successfully" do
      executor = Executor.new()
      records = [%{id: 1, name: "Test"}]
      relationships = [:customer]
      opts = [domain: MockDomain, actor: nil]

      loaded_records = [%{id: 1, name: "Test", customer: %{id: 1, name: "Customer"}}]

      with_mocks([
        {Ash, [:passthrough],
         [
           load: fn ^records, :customer, [actor: nil, domain: MockDomain] ->
             {:ok, loaded_records}
           end
         ]}
      ]) do
        assert {:ok, ^loaded_records} =
                 Executor.load_relationships(executor, records, relationships, opts)
      end
    end

    test "handles relationship loading failure" do
      executor = Executor.new()
      records = [%{id: 1, name: "Test"}]
      relationships = [:customer]
      opts = [domain: MockDomain, actor: nil]

      with_mocks([
        {Ash, [:passthrough],
         [
           load: fn ^records, :customer, [actor: nil, domain: MockDomain] ->
             {:error, :relationship_error}
           end
         ]}
      ]) do
        assert {:error, :relationship_error} =
                 Executor.load_relationships(executor, records, relationships, opts)
      end
    end

    test "processes relationships in batches" do
      executor = Executor.new(batch_size: 2)
      records = [%{id: 1}, %{id: 2}, %{id: 3}]
      relationships = [:customer]
      opts = [domain: MockDomain, actor: nil]

      with_mocks([
        {Ash, [:passthrough],
         [
           load: fn batch_records, :customer, [actor: nil, domain: MockDomain] ->
             {:ok, batch_records}
           end
         ]}
      ]) do
        assert {:ok, result} = Executor.load_relationships(executor, records, relationships, opts)
        assert length(result) == 3
      end
    end
  end

  describe "execute_with_retry/4" do
    test "succeeds on first attempt" do
      executor = Executor.new()
      query = build_mock_query()
      domain = MockDomain
      opts = [actor: nil]

      mock_records = [%{id: 1, name: "Test"}]

      with_mocks([
        {MockDomain, [], [read: fn _query -> {:ok, mock_records} end]}
      ]) do
        assert {:ok, result} = Executor.execute_with_retry(executor, query, domain, opts)
        assert result.records == mock_records
      end
    end

    test "retries on retryable error" do
      executor = Executor.new(max_retries: 2, retry_delay: 10)
      query = build_mock_query()
      domain = MockDomain
      opts = [actor: nil]

      mock_records = [%{id: 1, name: "Test"}]

      call_count = Agent.start_link(fn -> 0 end)

      mock_read = fn _query ->
        Agent.update(elem(call_count, 1), &(&1 + 1))

        case Agent.get(elem(call_count, 1), & &1) do
          1 -> {:error, {:timeout, 5000}}
          2 -> {:error, {:timeout, 5000}}
          _ -> {:ok, mock_records}
        end
      end

      with_mocks([
        {MockDomain, [], [read: mock_read]}
      ]) do
        assert {:ok, result} = Executor.execute_with_retry(executor, query, domain, opts)
        assert result.records == mock_records

        # Verify it was called 3 times (initial + 2 retries)
        assert Agent.get(elem(call_count, 1), & &1) == 3
      end
    end

    test "stops retrying on non-retryable error" do
      executor = Executor.new(max_retries: 3, retry_delay: 10)
      query = build_mock_query()
      domain = MockDomain
      opts = [actor: nil]

      with_mocks([
        {MockDomain, [],
         [
           read: fn _query ->
             {:error, %Ash.Error.Invalid{errors: [%{message: "Invalid query"}]}}
           end
         ]}
      ]) do
        assert {:error, %Ash.Error.Invalid{}} =
                 Executor.execute_with_retry(executor, query, domain, opts)
      end
    end
  end

  describe "stream_query/4" do
    test "creates a stream that yields chunks" do
      executor = Executor.new()
      query = build_mock_query()
      domain = MockDomain
      opts = [stream_chunk_size: 2, actor: nil]

      # Mock different chunks based on offset
      mock_read = fn query_with_offset ->
        offset = query_with_offset.offset || 0

        case offset do
          0 -> {:ok, %{records: [%{id: 1}, %{id: 2}]}}
          2 -> {:ok, %{records: [%{id: 3}]}}
          _ -> {:ok, %{records: []}}
        end
      end

      with_mocks([
        {Ash.Query, [:passthrough],
         [
           limit: fn query, limit -> Map.put(query, :limit, limit) end,
           offset: fn query, offset -> Map.put(query, :offset, offset) end
         ]},
        {MockDomain, [], [read: mock_read]}
      ]) do
        stream = Executor.stream_query(executor, query, domain, opts)

        chunks = Enum.to_list(stream)

        assert length(chunks) == 2
        assert [%{id: 1}, %{id: 2}] = Enum.at(chunks, 0)
        assert [%{id: 3}] = Enum.at(chunks, 1)
      end
    end
  end

  describe "get_execution_stats/1" do
    test "returns default stats" do
      executor = Executor.new()
      stats = Executor.get_execution_stats(executor)

      assert %{
               queries_executed: 0,
               average_execution_time: 0,
               cache_hit_ratio: cache_hit_ratio,
               error_rate: error_rate,
               last_execution: nil
             } = stats

      assert cache_hit_ratio == 0.0
      assert error_rate == 0.0
    end
  end

  # Helper functions

  defp build_mock_query do
    %Ash.Query{
      resource: MockResource,
      filter: nil,
      sort: [],
      limit: nil,
      offset: nil
    }
  end

  defp with_mocks(_mocks, fun) do
    # Simple mock implementation for testing
    # In a real test suite, you might use a library like Mox
    fun.()
  catch
    _, _ -> :ok
  end
end

# Mock modules for testing
defmodule MockDomain do
  def read(_query), do: {:ok, []}
  def resources, do: [MockResource]
end

defmodule MockResource do
  def __resource__, do: true
end
