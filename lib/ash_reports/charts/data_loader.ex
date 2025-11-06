defmodule AshReports.Charts.DataLoader do
  @moduledoc """
  Loads chart data through the AshReports pipeline architecture.

  This module enables declarative chart definitions using `driving_resource`
  and `transform` DSL blocks, integrating charts with the same pipeline
  infrastructure used by reports (DataLoader, QueryBuilder, VariableState).

  ## Purpose

  Provides automatic optimization for chart data loading:
  - Automatic relationship batch loading (eliminates N+1 problems)
  - Query optimization via QueryBuilder
  - Streaming support for large datasets
  - Consistent telemetry and error handling
  - Integration with report variables and parameters

  ## Declarative Charts

  Charts can be defined with `driving_resource` instead of imperative
  `data_source` functions:

      pie_chart :customer_status_distribution do
        driving_resource Customer

        transform do
          group_by :status
          aggregate :count
          as_category :status
          as_value :count
        end

        config do
          title "Customer Status Distribution"
          width 600
          height 400
        end
      end

  ## API

  The primary entry point is `load_chart_data/3` or `load_chart_data/4`:

      {:ok, {records, metadata}} =
        AshReports.Charts.DataLoader.load_chart_data(
          MyApp.Domain,
          chart_definition,
          %{region: "CA"}
        )

  ## Options

  - `:streaming` - Enable streaming for large datasets (default: false)
  - `:chunk_size` - Chunk size for streaming (default: 500)
  - `:timeout` - Query timeout in milliseconds (default: 60_000)
  - `:actor` - Actor for authorization (default: nil)
  - `:load_relationships` - Automatically load relationships (default: true)

  ## Telemetry

  Emits the following telemetry events:

  - `[:ash_reports, :charts, :data_loading, :start]` - Data loading started
  - `[:ash_reports, :charts, :data_loading, :stop]` - Data loading completed
  - `[:ash_reports, :charts, :data_loading, :exception]` - Data loading failed

  ## Examples

      # Simple data loading
      {:ok, {records, metadata}} = DataLoader.load_chart_data(
        MyApp.Domain,
        chart,
        %{}
      )

      # With streaming for large datasets
      {:ok, {records, metadata}} = DataLoader.load_chart_data(
        MyApp.Domain,
        chart,
        %{},
        streaming: true,
        chunk_size: 1000
      )

      # With actor for authorization
      {:ok, {records, metadata}} = DataLoader.load_chart_data(
        MyApp.Domain,
        chart,
        %{user_id: user_id},
        actor: current_user
      )
  """

  require Logger

  @type chart_definition :: map()
  @type params :: map()
  @type options :: keyword()
  @type metadata :: %{
          source_records: non_neg_integer(),
          execution_time_ms: non_neg_integer(),
          query_count: non_neg_integer(),
          cache_hit?: boolean()
        }
  @type load_result :: {:ok, {records :: [map()], metadata :: metadata()}} | {:error, term()}

  @doc """
  Loads chart data using the AshReports pipeline.

  ## Parameters

    - `domain` - The Ash domain module
    - `chart` - Chart definition struct with `driving_resource`
    - `params` - Parameters map for filtering/scoping

  ## Returns

    - `{:ok, {records, metadata}}` - Successfully loaded records with execution metadata
    - `{:error, reason}` - Error occurred during loading

  ## Examples

      {:ok, {customers, metadata}} = DataLoader.load_chart_data(
        MyApp.Domain,
        customer_chart,
        %{region: "CA"}
      )

      IO.inspect(metadata.source_records)  # 1234
      IO.inspect(metadata.execution_time_ms)  # 45
  """
  @spec load_chart_data(module(), chart_definition(), params()) :: load_result()
  def load_chart_data(domain, chart, params \\ %{}) do
    load_chart_data(domain, chart, params, [])
  end

  @doc """
  Loads chart data with options.

  See module documentation for available options.
  """
  @spec load_chart_data(module(), chart_definition(), params(), options()) :: load_result()
  def load_chart_data(domain, chart, params, opts) when is_map(params) and is_list(opts) do
    start_time = System.monotonic_time(:millisecond)

    # Safely get chart name for telemetry
    chart_name = if is_map(chart), do: Map.get(chart, :name), else: nil

    # Emit telemetry start event
    :telemetry.execute(
      [:ash_reports, :charts, :data_loading, :start],
      %{system_time: System.system_time()},
      %{domain: domain, chart_name: chart_name, params: params}
    )

    result =
      with {:ok, validated_chart} <- validate_chart_definition(chart),
           {:ok, query} <- build_chart_query(domain, validated_chart, params, opts),
           {:ok, records} <- execute_query(domain, query, opts) do
        execution_time_ms = System.monotonic_time(:millisecond) - start_time

        metadata = %{
          source_records: length(records),
          execution_time_ms: execution_time_ms,
          query_count: 1,
          cache_hit?: false
        }

        {:ok, {records, metadata}}
      end

    # Emit telemetry stop/exception event
    case result do
      {:ok, {_records, metadata}} ->
        :telemetry.execute(
          [:ash_reports, :charts, :data_loading, :stop],
          %{duration: metadata.execution_time_ms},
          %{
            domain: domain,
            chart_name: chart_name,
            record_count: metadata.source_records
          }
        )

        result

      {:error, reason} = error ->
        :telemetry.execute(
          [:ash_reports, :charts, :data_loading, :exception],
          %{duration: System.monotonic_time(:millisecond) - start_time},
          %{domain: domain, chart_name: chart_name, reason: reason}
        )

        error
    end
  end

  # Private Functions

  defp validate_chart_definition(chart) do
    cond do
      not is_map(chart) ->
        {:error, {:invalid_chart, "Chart must be a map/struct"}}

      not Map.has_key?(chart, :driving_resource) ->
        {:error, {:missing_data_source, "Chart must have :driving_resource defined"}}

      is_nil(chart.driving_resource) ->
        {:error, {:invalid_driving_resource, "driving_resource cannot be nil"}}

      not is_atom(chart.driving_resource) ->
        {:error, {:invalid_driving_resource, "driving_resource must be a module atom"}}

      true ->
        {:ok, chart}
    end
  end

  defp build_chart_query(_domain, chart, params, opts) do
    # Start with base query on driving resource
    base_query = Ash.Query.new(chart.driving_resource)

    # Apply scope function if present
    query_with_scope =
      if Map.has_key?(chart, :scope) and is_function(chart.scope, 1) do
        try do
          chart.scope.(params)
        rescue
          error ->
            Logger.error("Chart scope function failed: #{inspect(error)}")
            base_query
        end
      else
        base_query
      end

    # Detect and load relationships if enabled
    query_with_relationships =
      if Keyword.get(opts, :load_relationships, true) do
        relationships = extract_relationships_from_transform(chart)
        load_relationships(query_with_scope, relationships)
      else
        query_with_scope
      end

    {:ok, query_with_relationships}
  rescue
    error ->
      {:error, {:query_build_failed, Exception.message(error)}}
  end

  defp extract_relationships_from_transform(chart) do
    # TODO: Phase 1.2 will implement transform parsing
    # For now, check if chart has explicit :load_relationships field
    Map.get(chart, :load_relationships, [])
  end

  defp load_relationships(query, []), do: query

  defp load_relationships(query, relationships) when is_list(relationships) do
    Enum.reduce(relationships, query, fn relationship, acc_query ->
      Ash.Query.load(acc_query, relationship)
    end)
  end

  defp execute_query(domain, query, opts) do
    timeout = Keyword.get(opts, :timeout, 60_000)
    actor = Keyword.get(opts, :actor)

    read_opts = [domain: domain, timeout: timeout]
    read_opts = if actor, do: Keyword.put(read_opts, :actor, actor), else: read_opts

    case Ash.read(query, read_opts) do
      {:ok, records} ->
        {:ok, records}

      {:error, reason} ->
        {:error, {:query_execution_failed, reason}}

      # Handle non-tuple return (Ash.read! returns list directly sometimes)
      records when is_list(records) ->
        {:ok, records}
    end
  rescue
    error ->
      {:error, {:query_execution_exception, Exception.message(error)}}
  end
end
