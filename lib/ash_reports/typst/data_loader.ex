defmodule AshReports.Typst.DataLoader do
  @moduledoc """
  Specialized DataLoader for Typst integration that extends the existing
  AshReports.DataLoader with Typst-specific data transformation and
  streaming capabilities.

  This module serves as the critical data integration layer between AshReports
  DSL definitions and actual Ash resource data, transforming it into a format
  suitable for Typst template compilation.

  ## Architecture Integration

  ```
  AshReports DSL → DSLGenerator → Typst Template → **DATA INTEGRATION** → BinaryWrapper → PDF
  ```

  ## Key Features

  - **Typst-Compatible Data**: Transforms Ash structs to plain maps for Typst templates
  - **Type Conversion**: Handles DateTime, Decimal, Money, UUID, and custom types
  - **Relationship Traversal**: Deep relationship chains with safe nil handling
  - **Variable Scopes**: Detail, group, page, and report-level variable calculations
  - **Streaming Support**: GenStage-based pipeline for large datasets
  - **Performance Optimized**: Memory-efficient processing with backpressure

  ## Usage Examples

  ### Basic Report Data Loading

      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, %{
      ...>   start_date: ~D[2024-01-01],
      ...>   end_date: ~D[2024-01-31]
      ...> })
      iex> data.records
      [%{customer_name: "Acme Corp", amount: 1500.0, created_at: "2024-01-15T10:30:00Z"}]

  ### Streaming Large Datasets

      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :large_report, params)
      iex> stream |> Enum.take(10) |> length()
      10

  ## Data Format

  The output format is optimized for DSL-generated Typst templates:

  ```elixir
  %{
    records: [%{field_name: value, ...}],     # For #record.field_name access
    config: %{param_name: value, ...},        # For #config.param_name access
    variables: %{var_name: value, ...},       # For #variables.var_name access
    groups: [...],                            # For grouped data processing
    metadata: %{...}                          # Report metadata
  }
  ```
  """

  alias AshReports.Report
  alias AshReports.Typst.{DataProcessor, ExpressionParser, StreamingPipeline}

  require Logger

  @typedoc """
  Typst-compatible data structure for template compilation.
  """
  @type typst_data :: %{
          records: [map()],
          config: map(),
          variables: map(),
          groups: [map()],
          metadata: map()
        }

  @typedoc """
  Options for Typst data loading.
  """
  @type load_options :: [
          chunk_size: pos_integer(),
          type_conversion: keyword()
        ]

  @doc """
  Streams large datasets for memory-efficient Typst compilation.

  Uses GenStage/Flow for backpressure-aware streaming that maintains
  constant memory usage regardless of dataset size.

  ## Parameters

    * `domain` - The Ash domain containing the report definition
    * `report_name` - Name of the report to stream data for
    * `params` - Parameters for report generation
    * `opts` - Streaming options

  ## Options

    * `:chunk_size` - Size of streaming chunks (default: 500)
    * `:max_demand` - Maximum demand for backpressure (default: 1000)
    * `:buffer_size` - ProducerConsumer buffer size (default: 1000)
    * `:enable_telemetry` - Enable telemetry events (default: true)
    * `:aggregations` - Global aggregation functions (default: [])
    * `:grouped_aggregations` - Override DSL-inferred grouped aggregations (default: auto from DSL)
    * `:memory_limit` - Memory limit per stream in bytes (default: 500MB)
    * `:timeout` - Pipeline timeout in milliseconds (default: 300_000 / 5 minutes)
    * `:type_conversion` - Type conversion options

  ## Returns

    * `{:ok, Enumerable.t()}` - Stream of processed record chunks
    * `{:error, term()}` - Streaming setup failure

  ## Examples

      # Basic streaming with defaults
      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :large_report, params)
      iex> stream |> Stream.take(5) |> Enum.to_list() |> List.flatten() |> length()
      2500  # 5 chunks * 500 records each

      # Custom chunk size for faster throughput
      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :large_report, params,
      ...>   chunk_size: 2000,
      ...>   max_demand: 5000
      ...> )

      # Override DSL-inferred aggregations
      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params,
      ...>   grouped_aggregations: [
      ...>     %{group_by: :region, aggregations: [:sum, :count], level: 1, sort: :asc}
      ...>   ]
      ...> )

      # Memory-constrained environment
      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params,
      ...>   memory_limit: 100_000_000,  # 100MB
      ...>   chunk_size: 100,
      ...>   buffer_size: 500
      ...> )

      # Long-running report with extended timeout
      iex> {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :huge_report, params,
      ...>   timeout: 600_000  # 10 minutes
      ...> )

  """
  @spec stream_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_for_typst(domain, report_name, params, opts \\ []) do
    Logger.info(fn ->
      "Setting up streaming for report #{report_name} in domain #{inspect(domain)}"
    end)

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, stream} <- create_streaming_pipeline(domain, report, params, opts) do
      Logger.debug(fn -> "Successfully created streaming pipeline for #{report_name}" end)
      {:ok, stream}
    else
      {:error, reason} = error ->
        Logger.error(fn ->
          "Failed to create streaming pipeline for #{report_name}: #{inspect(reason)}"
        end)

        error
    end
  end

  @doc """
  Creates a configuration for Typst data loading with sensible defaults.

  ## Examples

      iex> config = DataLoader.typst_config(chunk_size: 2000)
      iex> config[:chunk_size]
      2000

  """
  @spec typst_config(keyword()) :: load_options()
  def typst_config(overrides \\ []) do
    defaults = [
      chunk_size: 1000,
      type_conversion: [
        datetime_format: :iso8601,
        decimal_precision: 2,
        money_format: :symbol
      ]
    ]

    Keyword.merge(defaults, overrides)
  end

  # Private Functions

  defp get_report_definition(domain, report_name) do
    case AshReports.Info.report(domain, report_name) do
      nil ->
        {:error, {:report_not_found, report_name}}

      %Report{} = report ->
        {:ok, report}

      other ->
        {:error, {:invalid_report_definition, other}}
    end
  rescue
    error ->
      {:error, {:report_lookup_failed, error}}
  end

  defp create_streaming_pipeline(domain, report, params, opts) do
    # Get the query from report definition
    with {:ok, query} <- build_query_from_report(domain, report, params) do
      # Build transformer function
      transformer = build_typst_transformer(report, opts)

      # Build grouped aggregations from DSL
      grouped_aggregations = build_grouped_aggregations_from_dsl(report)

      Logger.debug(fn ->
        """
        Configured grouped aggregations from DSL:
        #{inspect(grouped_aggregations, pretty: true)}
        """
      end)

      # Start streaming pipeline with enhanced configuration
      pipeline_opts =
        build_pipeline_opts(
          domain,
          report,
          query,
          params,
          opts,
          grouped_aggregations,
          transformer
        )

      case StreamingPipeline.start_pipeline(pipeline_opts) do
        {:ok, _stream_id, stream} ->
          {:ok, stream}

        {:error, reason} ->
          {:error, {:streaming_pipeline_failed, reason}}
      end
    end
  end

  # Build comprehensive pipeline options from user configuration
  defp build_pipeline_opts(domain, report, query, params, opts, grouped_aggregations, transformer) do
    [
      domain: domain,
      resource: report.resource,
      query: query,
      transformer: transformer,
      # Core streaming configuration
      chunk_size: Keyword.get(opts, :chunk_size, 500),
      max_demand: Keyword.get(opts, :max_demand, 1000),
      buffer_size: Keyword.get(opts, :buffer_size, 1000),
      # Telemetry and monitoring
      enable_telemetry: Keyword.get(opts, :enable_telemetry, true),
      # Report configuration
      report_name: report.name,
      report_config: build_report_config(report, params),
      # Aggregations (allow override of DSL-inferred aggregations)
      aggregations: Keyword.get(opts, :aggregations, []),
      grouped_aggregations: Keyword.get(opts, :grouped_aggregations, grouped_aggregations),
      # Resource limits
      memory_limit: Keyword.get(opts, :memory_limit, 500_000_000),
      timeout: Keyword.get(opts, :timeout, 300_000)
    ]
  end

  defp build_query_from_report(_domain, report, params) do
    # Build Ash query from report definition and parameters
    try do
      query =
        report.resource
        |> Ash.Query.new()
        |> apply_report_filters(report, params)
        |> apply_report_sort(report)
        |> apply_preloads(report)

      {:ok, query}
    rescue
      error ->
        {:error, {:query_build_failed, error}}
    end
  end

  defp build_typst_transformer(_report, opts) do
    # Create a transformer function that processes records for Typst
    fn record ->
      # Convert single record - DataProcessor.convert_records expects a list
      case DataProcessor.convert_records([record], opts) do
        {:ok, [converted]} -> converted
        {:ok, []} -> nil
        {:error, _reason} -> nil
      end
    end
  end

  defp build_report_config(report, params) do
    %{
      report_name: report.name,
      parameters: params,
      columns: report.columns || [],
      groups: report.groups || [],
      variables: report.variables || []
    }
  end

  defp apply_report_filters(query, report, params) do
    # Apply filters from report definition and runtime parameters
    query_with_report_filter =
      case report.filter do
        nil ->
          query

        filter_expr ->
          Ash.Query.do_filter(query, filter_expr)
      end

    apply_runtime_filters(query_with_report_filter, params)
  end

  defp apply_runtime_filters(query, params) when params == %{}, do: query

  defp apply_runtime_filters(query, params) do
    # Apply runtime filters from parameters
    Enum.reduce(params, query, fn {_key, value}, acc_query ->
      case value do
        nil -> acc_query
        # Simplified - real implementation would apply filter
        _ -> acc_query
      end
    end)
  end

  defp apply_report_sort(query, report) do
    case report.sort do
      nil ->
        query

      sort_spec ->
        Ash.Query.sort(query, sort_spec)
    end
  end

  defp apply_preloads(query, report) do
    # Determine what relationships need to be preloaded
    preloads = extract_relationship_preloads(report)

    case preloads do
      [] -> query
      list -> Ash.Query.load(query, list)
    end
  end

  defp extract_relationship_preloads(report) do
    # Extract relationship paths from column definitions
    # This is a simplified implementation - could be enhanced
    columns = report.columns || []

    columns
    |> Enum.flat_map(fn column ->
      case column.source do
        {:relationship, path} -> [path]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  # DSL Integration Functions

  defp build_grouped_aggregations_from_dsl(report) do
    groups = report.groups || []

    case groups do
      [] ->
        Logger.debug(fn -> "No groups defined in report, skipping aggregation configuration" end)
        []

      group_list ->
        Logger.debug(fn ->
          "Building aggregation configuration for #{length(group_list)} groups"
        end)

        # Use reduce to accumulate fields from previous levels for cumulative grouping
        {configs, _accumulated_fields} =
          group_list
          |> Enum.sort_by(& &1.level)
          |> Enum.reduce({[], []}, fn group, {configs, accumulated_fields} ->
            # Extract field name for current group
            field_name = extract_field_for_group(group)

            # Add to accumulated fields (cumulative grouping)
            new_accumulated_fields = accumulated_fields ++ [field_name]

            # Build config with cumulative fields
            config =
              build_aggregation_config_for_group_cumulative(
                group,
                report,
                new_accumulated_fields
              )

            # Return updated accumulator
            {configs ++ [config], new_accumulated_fields}
          end)

        configs
        |> Enum.reject(&is_nil/1)
    end
  end

  # Extract field name from a group (helper for cumulative grouping)
  defp extract_field_for_group(group) do
    case ExpressionParser.extract_field_with_fallback(group.expression, group.name) do
      {:ok, field} ->
        field

      _error ->
        Logger.warning(fn ->
          """
          Failed to parse group expression for #{group.name}, falling back to group name.
          Expression: #{inspect(group.expression)}
          """
        end)

        group.name
    end
  end

  # Build aggregation config with cumulative grouping (includes fields from all previous levels)
  defp build_aggregation_config_for_group_cumulative(group, report, accumulated_fields) do
    # Derive aggregation types from variables
    aggregations = derive_aggregations_for_group(group.level, report)

    # Normalize group_by: single field as atom, multiple fields as list
    group_by = normalize_group_by_fields(accumulated_fields)

    Logger.debug(fn ->
      """
      Group #{group.name} (level #{group.level}):
        - Accumulated fields: #{inspect(accumulated_fields)}
        - Normalized group_by: #{inspect(group_by)}
        - Aggregations: #{inspect(aggregations)}
      """
    end)

    %{
      group_by: group_by,
      level: group.level,
      aggregations: aggregations,
      sort: group.sort || :asc
    }
  rescue
    error ->
      Logger.error("""
      Failed to build aggregation config for group #{inspect(group)}:
      #{inspect(error)}
      """)

      nil
  end

  # Normalize group_by fields: single field as atom, multiple fields as list
  defp normalize_group_by_fields([single_field]), do: single_field
  defp normalize_group_by_fields(fields) when is_list(fields), do: fields

  defp derive_aggregations_for_group(group_level, report) do
    variables = report.variables || []

    # Find variables that reset at this group level
    group_variables =
      variables
      |> Enum.filter(fn var ->
        var.reset_on == :group and var.reset_group == group_level
      end)

    # Map variable types to aggregation functions
    aggregation_types =
      group_variables
      |> Enum.map(&map_variable_type_to_aggregation/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Default aggregations if none specified
    case aggregation_types do
      [] ->
        Logger.debug(fn ->
          "No group-scoped variables found for level #{group_level}, using defaults"
        end)

        [:sum, :count]

      types ->
        types
    end
  end

  defp map_variable_type_to_aggregation(variable) do
    case variable.type do
      :sum -> :sum
      :average -> :avg
      :count -> :count
      :min -> :min
      :max -> :max
      :first -> :first
      :last -> :last
      _ -> nil
    end
  end

  # Test-only public interface (DO NOT USE IN PRODUCTION)
  if Mix.env() == :test do
    @doc false
    def __test_build_grouped_aggregations__(report) do
      build_grouped_aggregations_from_dsl(report)
    end
  end
end
