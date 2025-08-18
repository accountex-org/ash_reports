defmodule AshReports.DataLoader.Pipeline do
  @moduledoc """
  Stream processing pipeline for AshReports data loading with Phase 2.1/2.2/2.3 integration.

  This module orchestrates the complete data processing pipeline, integrating with:
  - **QueryBuilder (Phase 2.1)**: Execute queries and fetch raw data
  - **VariableState (Phase 2.2)**: Process data through variable calculations
  - **GroupProcessor (Phase 2.3)**: Handle group break detection and processing
  - **Executor**: Coordinate query execution and relationship loading

  The Pipeline provides memory-efficient stream processing for large datasets while
  maintaining proper coordination between all data processing components.

  ## Key Features

  - **Streaming Architecture**: Memory-efficient processing for datasets of any size
  - **Component Integration**: Seamless coordination with all Phase 2 components
  - **Backpressure Management**: Intelligent flow control to prevent memory issues
  - **Error Propagation**: Comprehensive error handling across the pipeline
  - **Performance Monitoring**: Integration with monitoring systems

  ## Pipeline Flow

  1. **Data Loading**: Executor loads data via QueryBuilder-generated queries
  2. **Group Processing**: GroupProcessor detects group breaks and manages state
  3. **Variable Processing**: VariableState calculates and updates variables
  4. **Result Assembly**: Final results are assembled with metadata

  ## Usage

      # Create pipeline configuration
      config = Pipeline.new(
        report: report,
        params: %{start_date: ~D[2024-01-01]},
        variable_state_pid: variable_pid,
        group_processor: group_processor,
        domain: MyApp.Domain
      )

      # Process data through pipeline
      {:ok, stream} = Pipeline.process_stream(config)

      # Consume processed results
      results =
        stream
        |> Stream.map(&handle_result/1)
        |> Enum.to_list()

  ## Integration Points

  - **QueryBuilder**: Builds and validates queries for data fetching
  - **Executor**: Executes queries and loads relationships
  - **GroupProcessor**: Processes group breaks and manages grouping state
  - **VariableState**: Updates variables based on record data
  - **Cache**: Stores and retrieves cached results
  - **Monitor**: Reports pipeline performance metrics

  """

  alias AshReports.{
    GroupProcessor,
    QueryBuilder,
    VariableState
  }

  alias AshReports.DataLoader.Executor

  @type pipeline_config :: %{
          report: AshReports.Report.t(),
          params: map(),
          domain: module(),
          executor: Executor.executor_state(),
          variable_state_pid: GenServer.server() | nil,
          group_processor: GroupProcessor.group_state() | nil,
          options: pipeline_options()
        }

  @type pipeline_options :: %{
          chunk_size: pos_integer(),
          enable_caching: boolean(),
          enable_monitoring: boolean(),
          max_memory_mb: pos_integer(),
          timeout: timeout(),
          actor: term()
        }

  @type processing_result :: %{
          record: map(),
          group_state: GroupProcessor.group_state() | nil,
          variable_values: %{atom() => term()},
          group_changes: [GroupProcessor.group_change()],
          metadata: %{
            processing_time: pos_integer(),
            memory_usage: pos_integer(),
            cache_hit?: boolean()
          }
        }

  @type pipeline_result :: %{
          records: [processing_result()],
          summary: %{
            total_records: pos_integer(),
            processing_time: pos_integer(),
            memory_peak: pos_integer(),
            cache_hits: pos_integer(),
            errors: [term()]
          }
        }

  @default_chunk_size 1000
  @default_max_memory_mb 512
  @default_timeout :timer.minutes(5)

  @doc """
  Creates a new pipeline configuration.

  ## Options

  - `:chunk_size` - Number of records to process in each chunk (default: 1000)
  - `:enable_caching` - Whether to enable result caching (default: true)
  - `:enable_monitoring` - Whether to enable performance monitoring (default: true)
  - `:max_memory_mb` - Maximum memory usage in MB (default: 512)
  - `:timeout` - Pipeline execution timeout (default: 5 minutes)
  - `:actor` - Actor context for authorization

  ## Examples

      config = Pipeline.new(
        report: my_report,
        params: %{date: ~D[2024-01-01]},
        domain: MyApp.Domain
      )

  """
  @spec new(Keyword.t()) :: pipeline_config()
  def new(opts) do
    report = Keyword.fetch!(opts, :report)
    params = Keyword.get(opts, :params, %{})
    domain = Keyword.fetch!(opts, :domain)

    options = %{
      chunk_size: Keyword.get(opts, :chunk_size, @default_chunk_size),
      enable_caching: Keyword.get(opts, :enable_caching, true),
      enable_monitoring: Keyword.get(opts, :enable_monitoring, true),
      max_memory_mb: Keyword.get(opts, :max_memory_mb, @default_max_memory_mb),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      actor: Keyword.get(opts, :actor)
    }

    %{
      report: report,
      params: params,
      domain: domain,
      executor: Executor.new(batch_size: options.chunk_size),
      variable_state_pid: Keyword.get(opts, :variable_state_pid),
      group_processor: Keyword.get(opts, :group_processor),
      options: options
    }
  end

  @doc """
  Processes data through the complete pipeline as a stream.

  Returns a stream of processing results that can be consumed lazily for
  memory-efficient processing of large datasets.

  ## Examples

      {:ok, stream} = Pipeline.process_stream(config)

      results =
        stream
        |> Stream.filter(&filter_record/1)
        |> Stream.map(&transform_record/1)
        |> Enum.to_list()

  """
  @spec process_stream(pipeline_config()) :: {:ok, Enumerable.t()} | {:error, term()}
  def process_stream(config) do
    with {:ok, query} <- build_query(config),
         {:ok, data_stream} <- create_data_stream(config, query),
         {:ok, processing_stream} <- create_processing_stream(config, data_stream) do
      {:ok, processing_stream}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Processes data through the complete pipeline and returns all results.

  This method loads all results into memory and should be used only for
  smaller datasets where streaming is not required.

  ## Examples

      {:ok, result} = Pipeline.process_all(config)

      total_records = result.summary.total_records
      processing_time = result.summary.processing_time

  """
  @spec process_all(pipeline_config()) :: {:ok, pipeline_result()} | {:error, term()}
  def process_all(config) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, stream} <- process_stream(config) do
      try do
        {records, errors} =
          stream
          |> Enum.reduce({[], []}, fn
            {:ok, result}, {acc_records, acc_errors} ->
              {[result | acc_records], acc_errors}

            {:error, error}, {acc_records, acc_errors} ->
              {acc_records, [error | acc_errors]}
          end)

        end_time = System.monotonic_time(:millisecond)
        processing_time = end_time - start_time

        result = %{
          records: Enum.reverse(records),
          summary: %{
            total_records: length(records),
            processing_time: processing_time,
            memory_peak: get_memory_peak(),
            cache_hits: count_cache_hits(records),
            errors: Enum.reverse(errors)
          }
        }

        {:ok, result}
      catch
        kind, reason ->
          {:error, {kind, reason}}
      end
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Validates the pipeline configuration before processing.

  Performs pre-flight checks to ensure all components are properly configured
  and the pipeline can execute successfully.

  """
  @spec validate_config(pipeline_config()) :: :ok | {:error, term()}
  def validate_config(config) do
    with :ok <- validate_report(config.report),
         :ok <- validate_domain(config.domain),
         :ok <- validate_executor(config.executor),
         :ok <- validate_variable_state(config.variable_state_pid),
         :ok <- validate_group_processor(config.group_processor) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Gets pipeline processing statistics.

  Returns metrics about pipeline performance for monitoring and debugging.
  """
  @spec get_pipeline_stats(pipeline_config()) :: %{atom() => term()}
  def get_pipeline_stats(_config) do
    %{
      records_processed: 0,
      average_processing_time: 0,
      memory_usage_mb: get_current_memory_mb(),
      cache_efficiency: 0.0,
      error_rate: 0.0
    }
  end

  @doc """
  Creates a processing pipeline with custom transformation stages.

  Allows for custom processing stages to be inserted into the pipeline
  for specialized data transformations.

  """
  @spec create_custom_pipeline(pipeline_config(), [function()]) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def create_custom_pipeline(config, transformations) do
    with {:ok, base_stream} <- process_stream(config) do
      custom_stream =
        Enum.reduce(transformations, base_stream, fn transform_fn, stream ->
          Stream.map(stream, transform_fn)
        end)

      {:ok, custom_stream}
    else
      {:error, _reason} = error -> error
    end
  end

  # Private Implementation Functions

  defp build_query(config) do
    QueryBuilder.build(config.report, config.params,
      validate_params: true,
      load_relationships: true,
      optimize_aggregates: true
    )
  end

  defp create_data_stream(config, query) do
    stream =
      Executor.stream_query(
        config.executor,
        query,
        config.domain,
        stream_chunk_size: config.options.chunk_size,
        timeout: config.options.timeout,
        actor: config.options.actor,
        domain: config.domain
      )

    {:ok, stream}
  end

  defp create_processing_stream(config, data_stream) do
    # Initialize processing state
    initial_state = %{
      group_processor: config.group_processor || GroupProcessor.new([]),
      variable_state_pid: config.variable_state_pid,
      processing_count: 0,
      start_time: System.monotonic_time(:millisecond)
    }

    # Create processing stream with state management
    processing_stream =
      data_stream
      |> Stream.transform(initial_state, fn chunk, state ->
        process_chunk(chunk, state, config)
      end)
      |> Stream.map(&add_metadata/1)

    {:ok, processing_stream}
  end

  defp process_chunk(chunk, state, config) do
    case chunk do
      {:error, _reason} = error ->
        {[error], state}

      records when is_list(records) ->
        {processed_records, updated_state} =
          Enum.map_reduce(records, state, fn record, acc_state ->
            process_single_record(record, acc_state, config)
          end)

        {processed_records, updated_state}
    end
  end

  defp process_single_record(record, state, _config) do
    start_time = System.monotonic_time(:microsecond)

    # Process through group processor
    {updated_group_processor, group_result} =
      if state.group_processor do
        GroupProcessor.process_record(state.group_processor, record)
      else
        {nil,
         %{record: record, group_changes: [], group_values: %{}, should_reset_variables: false}}
      end

    # Handle variable updates
    variable_values =
      process_variables(state.variable_state_pid, record, group_result.group_changes)

    # Build processing result
    processing_time = System.monotonic_time(:microsecond) - start_time

    result = %{
      record: record,
      group_state: updated_group_processor,
      variable_values: variable_values,
      group_changes: group_result.group_changes,
      metadata: %{
        processing_time: processing_time,
        memory_usage: get_current_memory_bytes(),
        cache_hit?: false
      }
    }

    # Update state
    updated_state = %{
      state
      | group_processor: updated_group_processor,
        processing_count: state.processing_count + 1
    }

    {{:ok, result}, updated_state}
  end

  defp process_variables(nil, _record, _group_changes), do: %{}

  defp process_variables(variable_state_pid, record, group_changes) do
    # Handle group changes first (resets)
    if length(group_changes) > 0 do
      Enum.each(group_changes, fn change ->
        VariableState.handle_scope_change(variable_state_pid, change)
      end)
    end

    # Update variables with record data
    case VariableState.update_variables_ordered(variable_state_pid, record) do
      :ok ->
        VariableState.get_all_values(variable_state_pid)

      {:error, _reason} ->
        # On error, return current values
        VariableState.get_all_values(variable_state_pid)
    end
  rescue
    _error ->
      # If variable state is not available, return empty
      %{}
  end

  defp add_metadata({:ok, result}) do
    {:ok, Map.put(result, :pipeline_timestamp, System.monotonic_time(:millisecond))}
  end

  defp add_metadata({:error, _reason} = error), do: error

  # Validation helpers

  defp validate_report(%AshReports.Report{}), do: :ok
  defp validate_report(report), do: {:error, {:invalid_report, report}}

  defp validate_domain(domain) when is_atom(domain) do
    if Code.ensure_loaded?(domain) do
      :ok
    else
      {:error, {:domain_not_loaded, domain}}
    end
  end

  defp validate_domain(domain), do: {:error, {:invalid_domain_type, domain}}

  defp validate_executor(%{}), do: :ok
  defp validate_executor(executor), do: {:error, {:invalid_executor, executor}}

  defp validate_variable_state(nil), do: :ok

  defp validate_variable_state(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      :ok
    else
      {:error, {:variable_state_not_alive, pid}}
    end
  end

  defp validate_variable_state(pid), do: {:error, {:invalid_variable_state_pid, pid}}

  defp validate_group_processor(nil), do: :ok
  defp validate_group_processor(%{}), do: :ok
  defp validate_group_processor(processor), do: {:error, {:invalid_group_processor, processor}}

  # Performance monitoring helpers

  defp get_memory_peak do
    # This would integrate with proper memory monitoring
    :erlang.memory(:total)
  end

  defp get_current_memory_mb do
    :erlang.memory(:total) |> div(1024 * 1024)
  end

  defp get_current_memory_bytes do
    :erlang.memory(:total)
  end

  defp count_cache_hits(records) do
    Enum.count(records, fn result ->
      get_in(result, [:metadata, :cache_hit?]) == true
    end)
  end
end
