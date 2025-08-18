defmodule AshReports.DataLoader.Executor do
  @moduledoc """
  Query execution and relationship loading coordination for AshReports.

  This module provides the core query execution functionality for the DataLoader system,
  handling:
  - Ash query execution with proper error handling
  - Relationship loading coordination and optimization
  - Batch loading for performance optimization
  - Resource loading with proper domain context
  - Memory-efficient streaming for large datasets

  The Executor integrates with QueryBuilder to execute the generated queries and
  coordinates with other DataLoader components for caching and monitoring.

  ## Key Features

  - **Query Execution**: Safe execution of Ash queries with comprehensive error handling
  - **Relationship Loading**: Intelligent loading of required relationships
  - **Batch Processing**: Optimized batch operations for better performance
  - **Streaming Support**: Memory-efficient processing for large datasets
  - **Error Recovery**: Graceful handling of query failures and resource errors

  ## Usage

      executor = Executor.new()
      
      # Execute a query
      {:ok, records} = Executor.execute_query(executor, query, domain)
      
      # Load relationships in batch
      {:ok, loaded_records} = Executor.load_relationships(executor, records, [:customer, :items])
      
      # Stream large datasets
      stream = Executor.stream_query(executor, query, domain, chunk_size: 1000)

  ## Integration Points

  - **QueryBuilder**: Executes queries built by the QueryBuilder
  - **Cache**: Coordinates with Cache for result storage and retrieval
  - **Monitor**: Reports execution metrics to Monitor for performance tracking
  - **Pipeline**: Provides data to Pipeline for stream processing

  """

  @type executor_state :: %{
          batch_size: pos_integer(),
          timeout: timeout(),
          max_retries: non_neg_integer(),
          retry_delay: pos_integer()
        }

  @type execution_options :: [
          domain: module(),
          timeout: timeout(),
          batch_size: pos_integer(),
          stream_chunk_size: pos_integer(),
          load_relationships: boolean(),
          cache_key: term(),
          actor: term()
        ]

  @type execution_result :: %{
          records: [map()],
          metadata: %{
            record_count: pos_integer(),
            execution_time: pos_integer(),
            cache_hit?: boolean(),
            relationships_loaded: [atom()]
          }
        }

  @default_batch_size 1000
  @default_timeout :timer.seconds(30)
  @default_max_retries 3
  @default_retry_delay 100

  @doc """
  Creates a new Executor with default configuration.

  ## Options

  - `:batch_size` - Number of records to process in each batch (default: 1000)
  - `:timeout` - Query execution timeout in milliseconds (default: 30 seconds)
  - `:max_retries` - Maximum number of retry attempts (default: 3)
  - `:retry_delay` - Delay between retries in milliseconds (default: 100)

  ## Examples

      executor = Executor.new()
      
      executor = Executor.new(batch_size: 500, timeout: :timer.minutes(2))

  """
  @spec new(Keyword.t()) :: executor_state()
  def new(opts \\ []) do
    %{
      batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      retry_delay: Keyword.get(opts, :retry_delay, @default_retry_delay)
    }
  end

  @doc """
  Executes an Ash query and returns the results.

  This is the primary execution method that coordinates with caching,
  monitoring, and error handling systems.

  ## Examples

      query = Ash.Query.new(MyApp.Order)
      {:ok, result} = Executor.execute_query(executor, query, MyApp.Domain)

  ## Error Handling

  Returns `{:error, reason}` for:
  - Query execution failures
  - Timeout conditions
  - Resource access errors
  - Domain validation failures

  """
  @spec execute_query(executor_state(), Ash.Query.t(), module(), execution_options()) ::
          {:ok, execution_result()} | {:error, term()}
  def execute_query(executor, query, domain, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, records} <- do_execute_query(executor, query, domain, opts),
         {:ok, loaded_records} <- maybe_load_relationships(executor, records, opts),
         {:ok, final_records} <- post_process_records(loaded_records, opts) do
      execution_time = System.monotonic_time(:millisecond) - start_time

      result = %{
        records: final_records,
        metadata: %{
          record_count: length(final_records),
          execution_time: execution_time,
          cache_hit?: Keyword.get(opts, :cache_hit?, false),
          relationships_loaded: extract_loaded_relationships(opts)
        }
      }

      {:ok, result}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Executes a query and returns a stream for large datasets.

  This method provides memory-efficient processing for large datasets by
  streaming results in configurable chunks.

  ## Examples

      query = Ash.Query.new(MyApp.Order)
      stream = Executor.stream_query(executor, query, domain, chunk_size: 500)
      
      results = 
        stream
        |> Stream.map(&process_chunk/1)
        |> Enum.to_list()

  """
  @spec stream_query(executor_state(), Ash.Query.t(), module(), execution_options()) ::
          Enumerable.t()
  def stream_query(executor, query, domain, opts \\ []) do
    chunk_size = Keyword.get(opts, :stream_chunk_size, executor.batch_size)

    Stream.resource(
      fn -> initialize_stream(query, domain, opts) end,
      fn state -> fetch_next_chunk(state, chunk_size, executor, opts) end,
      fn state -> cleanup_stream(state) end
    )
  end

  @doc """
  Loads relationships for a collection of records in optimized batches.

  This method intelligently batches relationship loading to minimize
  database queries while respecting memory constraints.

  ## Examples

      records = [%Order{id: 1}, %Order{id: 2}]
      {:ok, loaded} = Executor.load_relationships(executor, records, [:customer, :items])

  """
  @spec load_relationships(executor_state(), [map()], [atom()], execution_options()) ::
          {:ok, [map()]} | {:error, term()}
  def load_relationships(executor, records, relationships, opts \\ [])
  def load_relationships(_executor, [], _relationships, _opts), do: {:ok, []}
  def load_relationships(_executor, records, [], _opts), do: {:ok, records}

  def load_relationships(executor, records, relationships, opts) do
    domain = Keyword.fetch!(opts, :domain)
    actor = Keyword.get(opts, :actor)

    # Process in batches to avoid memory issues
    records
    |> Enum.chunk_every(executor.batch_size)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
      case load_batch_relationships(batch, relationships, domain, actor) do
        {:ok, loaded_batch} -> {:cont, {:ok, acc ++ loaded_batch}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Executes a query with built-in retry logic for transient failures.

  Automatically retries failed queries with exponential backoff for
  better resilience against temporary database issues.

  """
  @spec execute_with_retry(executor_state(), Ash.Query.t(), module(), execution_options()) ::
          {:ok, execution_result()} | {:error, term()}
  def execute_with_retry(executor, query, domain, opts \\ []) do
    retry_count = executor.max_retries

    do_execute_with_retry(executor, query, domain, opts, retry_count)
  end

  @doc """
  Validates that the executor can access the given domain and resource.

  Performs pre-flight checks to ensure the execution environment is properly
  configured before attempting query execution.

  """
  @spec validate_execution_context(executor_state(), Ash.Query.t(), module()) ::
          :ok | {:error, term()}
  def validate_execution_context(_executor, query, domain) do
    with :ok <- validate_domain(domain),
         :ok <- validate_resource_in_domain(query.resource, domain),
         :ok <- validate_query_structure(query) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Gets execution statistics for monitoring and debugging.

  Returns metrics about recent query executions for performance analysis.
  """
  @spec get_execution_stats(executor_state()) :: %{atom() => term()}
  def get_execution_stats(_executor) do
    # This would integrate with the Monitor module when implemented
    %{
      queries_executed: 0,
      average_execution_time: 0,
      cache_hit_ratio: 0.0,
      error_rate: 0.0,
      last_execution: nil
    }
  end

  # Private Implementation Functions

  defp do_execute_query(executor, query, domain, opts) do
    timeout = Keyword.get(opts, :timeout, executor.timeout)
    actor = Keyword.get(opts, :actor)

    try do
      # Apply actor context if provided
      query_with_context =
        if actor do
          Ash.Query.for_read(query, :read, %{}, actor: actor)
        else
          query
        end

      # Execute the query through the domain
      case apply(domain, :read, [query_with_context]) do
        {:ok, records} when is_list(records) ->
          {:ok, records}

        {:ok, %{results: records}} ->
          {:ok, records}

        {:error, _reason} = error ->
          error

        unexpected ->
          {:error, {:unexpected_result, unexpected}}
      end
    catch
      :exit, {:timeout, _} ->
        {:error, {:timeout, timeout}}

      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  defp maybe_load_relationships(executor, records, opts) do
    if Keyword.get(opts, :load_relationships, true) do
      relationships = extract_required_relationships(opts)

      if relationships != [] do
        load_relationships(executor, records, relationships, opts)
      else
        {:ok, records}
      end
    else
      {:ok, records}
    end
  end

  defp extract_required_relationships(opts) do
    # Extract relationships from the report structure
    # This would integrate with the report definition
    Keyword.get(opts, :relationships, [])
  end

  defp extract_loaded_relationships(opts) do
    if Keyword.get(opts, :load_relationships, true) do
      extract_required_relationships(opts)
    else
      []
    end
  end

  defp post_process_records(records, _opts) do
    # Apply any post-processing transformations
    # This could include data formatting, filtering, etc.
    {:ok, records}
  end

  defp load_batch_relationships(batch, relationships, domain, actor) do
    try do
      # Load each relationship for the batch
      loaded_batch =
        Enum.reduce_while(relationships, batch, fn relationship, acc_records ->
          case Ash.load(acc_records, relationship, actor: actor, domain: domain) do
            {:ok, loaded} ->
              {:cont, loaded}

            loaded when is_list(loaded) ->
              {:cont, loaded}

            {:error, _reason} = error ->
              {:halt, error}
          end
        end)

      case loaded_batch do
        {:error, _reason} = error -> error
        loaded when is_list(loaded) -> {:ok, loaded}
      end
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  defp do_execute_with_retry(executor, query, domain, opts, 0) do
    # Final attempt without retry
    execute_query(executor, query, domain, opts)
  end

  defp do_execute_with_retry(executor, query, domain, opts, retries_left) do
    case execute_query(executor, query, domain, opts) do
      {:ok, _result} = success ->
        success

      {:error, reason} when retries_left > 0 ->
        if retryable_error?(reason) do
          Process.sleep(executor.retry_delay * (executor.max_retries - retries_left + 1))
          do_execute_with_retry(executor, query, domain, opts, retries_left - 1)
        else
          {:error, reason}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp retryable_error?({:timeout, _}), do: true
  defp retryable_error?({:exit, _}), do: true
  defp retryable_error?(%Ash.Error.Framework{}), do: false
  defp retryable_error?(%Ash.Error.Invalid{}), do: false
  defp retryable_error?(%Ash.Error.Forbidden{}), do: false
  defp retryable_error?(_), do: true

  defp validate_domain(domain) when is_atom(domain) do
    if Code.ensure_loaded?(domain) and function_exported?(domain, :read, 1) do
      :ok
    else
      {:error, {:invalid_domain, domain}}
    end
  end

  defp validate_domain(domain) do
    {:error, {:invalid_domain_type, domain}}
  end

  defp validate_resource_in_domain(resource, domain) do
    try do
      case apply(domain, :resources, []) do
        resources when is_list(resources) ->
          if resource in resources do
            :ok
          else
            {:error, {:resource_not_in_domain, resource, domain}}
          end

        _ ->
          {:error, {:domain_resources_unavailable, domain}}
      end
    catch
      _kind, _reason ->
        {:error, {:domain_validation_failed, domain}}
    end
  end

  defp validate_query_structure(%Ash.Query{resource: resource}) when is_atom(resource) do
    :ok
  end

  defp validate_query_structure(query) do
    {:error, {:invalid_query_structure, query}}
  end

  # Stream processing helpers

  defp initialize_stream(query, domain, opts) do
    %{
      query: query,
      domain: domain,
      opts: opts,
      offset: 0,
      finished?: false
    }
  end

  defp fetch_next_chunk(%{finished?: true}, _chunk_size, _executor, _opts) do
    {:halt, nil}
  end

  defp fetch_next_chunk(state, chunk_size, executor, opts) do
    query_with_limit =
      state.query
      |> Ash.Query.limit(chunk_size)
      |> Ash.Query.offset(state.offset)

    case execute_query(executor, query_with_limit, state.domain, opts) do
      {:ok, %{records: records}} when length(records) < chunk_size ->
        # Last chunk
        updated_state = %{state | finished?: true}
        {[records], updated_state}

      {:ok, %{records: records}} ->
        # More chunks available
        updated_state = %{state | offset: state.offset + chunk_size}
        {[records], updated_state}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp cleanup_stream(_state) do
    # Cleanup any resources if needed
    :ok
  end
end
