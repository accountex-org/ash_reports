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

  alias AshReports.{DataLoader, Report}
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
          enable_streaming: boolean(),
          type_conversion: keyword(),
          variable_scopes: [atom()],
          preload_strategy: :auto | :explicit | [atom()]
        ]

  @doc """
  Loads report data optimized for Typst template compilation.

  Returns data in a format directly compatible with DSL-generated
  Typst templates, including proper type conversion and relationship
  flattening.

  ## Parameters

    * `domain` - The Ash domain containing the report definition
    * `report_name` - Name of the report to load data for
    * `params` - Parameters for report generation (filters, date ranges, etc.)
    * `opts` - Loading options for customization

  ## Options

    * `:chunk_size` - Size of data chunks for processing (default: 1000)
    * `:enable_streaming` - Use streaming for large datasets (default: false)
    * `:type_conversion` - Custom type conversion options
    * `:variable_scopes` - Variable scopes to calculate (default: all)
    * `:preload_strategy` - Relationship preloading strategy (default: :auto)

  ## Returns

    * `{:ok, typst_data()}` - Successfully loaded and formatted data
    * `{:error, term()}` - Loading or transformation failure

  ## Examples

      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, %{
      ...>   customer_id: 123,
      ...>   date_range: {~D[2024-01-01], ~D[2024-01-31]}
      ...> })
      iex> length(data.records)
      42
      iex> data.records |> List.first() |> Map.keys()
      [:id, :customer_name, :amount, :created_at, :customer_address]

  """
  @spec load_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, typst_data()} | {:error, term()}
  def load_for_typst(domain, report_name, params, opts \\ []) do
    Logger.debug("Loading Typst data for report #{report_name} in domain #{inspect(domain)}")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, raw_data} <- load_raw_data(domain, report, params, opts),
         {:ok, processed_data} <- process_for_typst(raw_data, report, opts) do
      Logger.debug("Successfully loaded #{length(processed_data.records)} records for Typst")
      {:ok, processed_data}
    else
      {:error, reason} = error ->
        Logger.error("Failed to load Typst data for #{report_name}: #{inspect(reason)}")
        error
    end
  end

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
    * `:timeout` - Pipeline timeout in milliseconds (default: :infinity)
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

  """
  @spec stream_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_for_typst(domain, report_name, params, opts \\ []) do
    Logger.info("Setting up streaming for report #{report_name} in domain #{inspect(domain)}")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, stream} <- create_streaming_pipeline(domain, report, params, opts) do
      Logger.debug("Successfully created streaming pipeline for #{report_name}")
      {:ok, stream}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create streaming pipeline for #{report_name}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Loads report data with automatic batch vs. streaming mode selection.

  Automatically chooses the most efficient loading strategy:
  - Small datasets (< threshold): Batch loading via `load_for_typst/4`
  - Large datasets (>= threshold): Streaming via `stream_for_typst/4`

  The threshold can be customized or disabled for manual control.

  ## Options

    * `:mode` - Force mode (`:auto | :batch | :streaming`, default: `:auto`)
    * `:streaming_threshold` - Record count threshold (default: 10,000)
    * `:estimate_count` - Pre-count records for mode selection (default: false)
    * All options from `load_for_typst/4` and `stream_for_typst/4` apply

  When `:mode` is `:auto` and `:estimate_count` is `false`, streaming is used
  for safety (cannot know size without counting). Set `:estimate_count` to `true`
  to enable intelligent mode selection, but be aware this adds overhead.

  ## Returns

    * `{:ok, data}` - Batch mode returns list of records
    * `{:ok, stream}` - Streaming mode returns Enumerable.t()
    * `{:error, term()}` - Loading failure

  ## Examples

      # Automatic mode selection (defaults to streaming for safety)
      iex> {:ok, result} = DataLoader.load_report_data(MyApp.Domain, :report, params)

      # Force batch mode
      iex> {:ok, data} = DataLoader.load_report_data(MyApp.Domain, :small_report, params, mode: :batch)
      iex> is_list(data)
      true

      # Force streaming mode
      iex> {:ok, stream} = DataLoader.load_report_data(MyApp.Domain, :large_report, params, mode: :streaming)

      # Automatic with intelligent size detection (adds overhead)
      iex> {:ok, result} = DataLoader.load_report_data(MyApp.Domain, :report, params,
      ...>   estimate_count: true,
      ...>   streaming_threshold: 5000
      ...> )

  """
  @spec load_report_data(module(), atom(), map(), load_options()) ::
          {:ok, list() | Enumerable.t()} | {:error, term()}
  def load_report_data(domain, report_name, params, opts \\ []) do
    mode = Keyword.get(opts, :mode, :auto)

    case mode do
      :batch ->
        load_for_typst(domain, report_name, params, opts)

      :streaming ->
        stream_for_typst(domain, report_name, params, opts)

      :auto ->
        select_and_load(domain, report_name, params, opts)

      _ ->
        {:error, {:invalid_mode, mode}}
    end
  end

  # Automatically select batch or streaming mode
  defp select_and_load(domain, report_name, params, opts) do
    estimate_count? = Keyword.get(opts, :estimate_count, false)
    threshold = Keyword.get(opts, :streaming_threshold, 10_000)

    if estimate_count? do
      # Estimate record count and choose mode intelligently
      with {:ok, report} <- get_report_definition(domain, report_name),
           {:ok, query} <- build_query_from_report(domain, report, params),
           {:ok, count} <- estimate_record_count(domain, query) do
        if count < threshold do
          Logger.debug("Auto-selecting batch mode (#{count} records < #{threshold} threshold)")
          load_for_typst(domain, report_name, params, opts)
        else
          Logger.debug(
            "Auto-selecting streaming mode (#{count} records >= #{threshold} threshold)"
          )

          stream_for_typst(domain, report_name, params, opts)
        end
      else
        # On error estimating, fall back to streaming for safety
        {:error, reason} ->
          Logger.warning(
            "Failed to estimate count (#{inspect(reason)}), falling back to streaming mode"
          )

          stream_for_typst(domain, report_name, params, opts)
      end
    else
      # Default to streaming when we can't estimate size
      Logger.debug("Auto-selecting streaming mode (no size estimation)")
      stream_for_typst(domain, report_name, params, opts)
    end
  end

  # Estimate the number of records that would be returned by a query
  defp estimate_record_count(domain, query) do
    try do
      count = Ash.count!(query, domain: domain)
      {:ok, count}
    rescue
      error ->
        {:error, {:count_failed, error}}
    end
  end

  @doc """
  Creates a configuration for Typst data loading with sensible defaults.

  ## Examples

      iex> config = DataLoader.typst_config(chunk_size: 2000, enable_streaming: true)
      iex> config[:chunk_size]
      2000

  """
  @spec typst_config(keyword()) :: load_options()
  def typst_config(overrides \\ []) do
    defaults = [
      chunk_size: 1000,
      enable_streaming: false,
      type_conversion: [
        datetime_format: :iso8601,
        decimal_precision: 2,
        money_format: :symbol
      ],
      variable_scopes: [:detail, :group, :page, :report],
      preload_strategy: :auto
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

  defp load_raw_data(domain, report, params, opts) do
    # Use existing DataLoader for basic data loading
    DataLoader.load_report(domain, report.name, params, build_loader_opts(opts))
  rescue
    error ->
      {:error, {:data_loading_failed, error}}
  end

  defp process_for_typst(raw_data, report, opts) do
    with {:ok, converted_records} <- DataProcessor.convert_records(raw_data.records, opts),
         {:ok, variables} <-
           DataProcessor.calculate_variable_scopes(converted_records, report.variables || []),
         {:ok, groups} <- DataProcessor.process_groups(converted_records, report.groups || []) do
      typst_data = %{
        records: converted_records,
        config: Map.new(raw_data.parameters || %{}),
        variables: variables,
        groups: groups,
        metadata: %{
          total_records: length(converted_records),
          report_name: report.name,
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      {:ok, typst_data}
    end
  end

  defp create_streaming_pipeline(domain, report, params, opts) do
    # Get the query from report definition
    with {:ok, query} <- build_query_from_report(domain, report, params) do
      # Build transformer function
      transformer = build_typst_transformer(report, opts)

      # Build grouped aggregations from DSL
      grouped_aggregations = build_grouped_aggregations_from_dsl(report)

      Logger.debug("""
      Configured grouped aggregations from DSL:
      #{inspect(grouped_aggregations, pretty: true)}
      """)

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
      timeout: Keyword.get(opts, :timeout, :infinity)
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

  defp build_loader_opts(typst_opts) do
    # Convert Typst-specific options to DataLoader options
    chunk_size = Keyword.get(typst_opts, :chunk_size, 1000)
    enable_caching = Keyword.get(typst_opts, :enable_caching, true)

    [
      chunk_size: chunk_size,
      enable_caching: enable_caching,
      load_relationships: true
    ]
  end

  # DSL Integration Functions

  defp build_grouped_aggregations_from_dsl(report) do
    groups = report.groups || []

    case groups do
      [] ->
        Logger.debug("No groups defined in report, skipping aggregation configuration")
        []

      group_list ->
        Logger.debug("Building aggregation configuration for #{length(group_list)} groups")

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
        Logger.warning("""
        Failed to parse group expression for #{group.name}, falling back to group name.
        Expression: #{inspect(group.expression)}
        """)

        group.name
    end
  end

  # Build aggregation config with cumulative grouping (includes fields from all previous levels)
  defp build_aggregation_config_for_group_cumulative(group, report, accumulated_fields) do
    # Derive aggregation types from variables
    aggregations = derive_aggregations_for_group(group.level, report)

    # Normalize group_by: single field as atom, multiple fields as list
    group_by = normalize_group_by_fields(accumulated_fields)

    Logger.debug("""
    Group #{group.name} (level #{group.level}):
      - Accumulated fields: #{inspect(accumulated_fields)}
      - Normalized group_by: #{inspect(group_by)}
      - Aggregations: #{inspect(aggregations)}
    """)

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
        Logger.debug("No group-scoped variables found for level #{group_level}, using defaults")
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
