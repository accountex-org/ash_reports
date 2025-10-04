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

  alias AshReports.Typst.{
    AggregationConfigurator,
    ChartPreprocessor,
    DataProcessor,
    QueryBuilder,
    StreamingPipeline
  }

  alias AshReports.Typst.StreamingPipeline.ChartDataCollector

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
          strategy: :auto | :in_memory | :aggregation | :streaming,
          chunk_size: pos_integer(),
          type_conversion: keyword()
        ]

  @typedoc """
  Loading strategy for report data.

  * `:auto` - Automatically select best strategy (default)
  * `:in_memory` - Load all records into memory with chart preprocessing
  * `:aggregation` - Use streaming aggregations for chart generation
  * `:streaming` - Return a stream for manual processing
  """
  @type loading_strategy :: :auto | :in_memory | :aggregation | :streaming

  @doc """
  Loads report data for Typst compilation with automatic strategy selection.

  This unified API automatically selects the best loading strategy based on the
  report configuration and options. You can override the strategy selection by
  passing the `:strategy` option.

  ## Loading Strategies

  ### `:auto` (default)
  Automatically selects the best strategy:
  - Reports with aggregation-based charts → `:aggregation`
  - Reports with record-based charts and limit ≤ 10K → `:in_memory`
  - Reports with no limit or limit > 10K → `:streaming`

  ### `:in_memory`
  Loads all records into memory and preprocesses charts.
  - **Best for**: Small to medium reports (< 10K records) with charts
  - **Returns**: `{:ok, data}` with records and preprocessed charts

  ### `:aggregation`
  Uses streaming aggregations to generate charts without loading all records.
  - **Best for**: Reports with aggregation-based charts (any dataset size)
  - **Memory**: O(groups) not O(records)
  - **Returns**: `{:ok, data}` with aggregations, charts, and optional sample records

  ### `:streaming`
  Returns a stream for manual processing.
  - **Best for**: Large datasets requiring custom processing
  - **Returns**: `{:ok, stream}` where stream yields processed records

  ## Parameters

    * `domain` - The Ash domain containing the report definition
    * `report_name` - Name of the report to load data for
    * `params` - Parameters for report generation
    * `opts` - Loading options

  ## Options

    * `:strategy` - Loading strategy (default: `:auto`)
    * `:preprocess_charts` - Enable/disable chart preprocessing (default: true)
    * `:type_conversion` - Type conversion options for DataProcessor
    * `:limit` - Maximum number of records to load
    * `:chunk_size` - Size of streaming chunks (default: 500)
    * `:max_demand` - Maximum demand for backpressure (default: 1000)
    * `:include_sample` - Include sample records with aggregation strategy (default: false)
    * `:sample_size` - Number of sample records (default: 100)

  ## Returns

    * `{:ok, data}` - Loaded data (for `:in_memory` and `:aggregation` strategies)
    * `{:ok, stream}` - Data stream (for `:streaming` strategy)
    * `{:error, term()}` - Loading failure

  ## Examples

      # Automatic strategy selection
      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, %{
      ...>   start_date: ~D[2024-01-01],
      ...>   end_date: ~D[2024-01-31]
      ...> }, [])

      # Force in-memory strategy
      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, params,
      ...>   strategy: :in_memory,
      ...>   limit: 5000
      ...> )

      # Use aggregation strategy for charts
      iex> {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, params,
      ...>   strategy: :aggregation,
      ...>   include_sample: true
      ...> )

      # Get a stream for custom processing
      iex> {:ok, stream} = DataLoader.load_for_typst(MyApp.Domain, :large_report, params,
      ...>   strategy: :streaming
      ...> )
      iex> stream |> Enum.take(10) |> length()
      10

  """
  @spec load_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, typst_data()} | {:ok, Enumerable.t()} | {:error, term()}
  def load_for_typst(domain, report_name, params, opts) do
    strategy = determine_strategy(domain, report_name, opts)

    Logger.info(fn ->
      "Loading data for report #{report_name} using strategy: #{strategy}"
    end)

    case strategy do
      :in_memory -> load_in_memory(domain, report_name, params, opts)
      :aggregation -> load_with_aggregations(domain, report_name, params, opts)
      :streaming -> load_as_stream(domain, report_name, params, opts)
    end
  end

  # Strategy Selection

  defp determine_strategy(domain, report_name, opts) do
    case Keyword.get(opts, :strategy) do
      nil -> auto_select_strategy(domain, report_name, opts)
      strategy when strategy in [:auto, :in_memory, :aggregation, :streaming] ->
        if strategy == :auto do
          auto_select_strategy(domain, report_name, opts)
        else
          strategy
        end
      invalid ->
        Logger.warning("Invalid strategy #{inspect(invalid)}, using :auto")
        auto_select_strategy(domain, report_name, opts)
    end
  end

  defp auto_select_strategy(domain, report_name, opts) do
    case get_report_definition(domain, report_name) do
      {:ok, report} ->
        # Check if report has aggregation-based charts
        chart_configs = ChartDataCollector.extract_chart_configs(report)
        has_aggregation_charts = chart_configs != []

        # Check limit option
        limit = Keyword.get(opts, :limit)

        cond do
          has_aggregation_charts -> :aggregation
          limit != nil and limit <= 10_000 -> :in_memory
          limit == nil -> :streaming
          limit > 10_000 -> :streaming
        end

      {:error, _} ->
        # Default to in-memory if we can't get report definition
        :in_memory
    end
  end

  # Strategy Implementations

  defp load_in_memory(domain, report_name, params, opts) do
    Logger.debug("Using in-memory loading strategy")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, records} <- load_report_records(domain, report, params, opts),
         {:ok, converted_records} <- convert_records(records, opts),
         {:ok, data_context} <- build_data_context(report, converted_records, params),
         {:ok, chart_data} <- maybe_preprocess_charts(report, data_context, opts) do
      result = Map.put(data_context, :charts, chart_data)

      Logger.debug(fn ->
        "Successfully loaded #{length(converted_records)} records with #{map_size(chart_data)} charts"
      end)

      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.error(fn ->
          "Failed to load data for #{report_name}: #{inspect(reason)}"
        end)

        error
    end
  end

  defp load_with_aggregations(domain, report_name, params, opts) do
    Logger.debug("Using aggregation loading strategy")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, stream_id, stream} <- create_streaming_pipeline(domain, report, params, opts),
         {:ok, sample_records} <- maybe_collect_sample(stream, opts),
         {:ok, agg_data} <- retrieve_aggregation_state(stream_id),
         {:ok, chart_data} <- maybe_generate_charts(report, agg_data, opts) do
      context = %{
        aggregations: agg_data,
        charts: chart_data,
        config: %{
          report_name: report.name,
          title: report.title
        },
        variables: params,
        records: sample_records
      }

      Logger.debug(fn ->
        "Successfully loaded aggregations with #{map_size(chart_data)} charts and #{length(sample_records)} sample records"
      end)

      {:ok, context}
    else
      {:error, reason} = error ->
        Logger.error(fn ->
          "Failed to load aggregation data for #{report_name}: #{inspect(reason)}"
        end)

        error
    end
  end

  defp load_as_stream(domain, report_name, params, opts) do
    Logger.debug("Using streaming loading strategy")

    with {:ok, report} <- get_report_definition(domain, report_name),
         {:ok, _stream_id, stream} <- create_streaming_pipeline(domain, report, params, opts) do
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

  # Helper Functions

  defp load_report_records(domain, report, params, opts) do
    case QueryBuilder.build_query(domain, report, params, opts) do
      {:ok, query} ->
        case Ash.read(query, domain: domain) do
          {:ok, records} -> {:ok, records}
          {:error, reason} -> {:error, {:query_failed, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_records(records, opts) do
    case DataProcessor.convert_records(records, opts) do
      {:ok, converted} -> {:ok, converted}
      {:error, reason} -> {:error, {:conversion_failed, reason}}
    end
  end

  defp build_data_context(report, converted_records, params) do
    context = %{
      records: converted_records,
      config: %{
        report_name: report.name,
        title: report.title
      },
      variables: params
    }

    {:ok, context}
  end

  defp maybe_preprocess_charts(report, data_context, opts) do
    preprocess? = Keyword.get(opts, :preprocess_charts, true)

    if preprocess? do
      case ChartPreprocessor.preprocess(report, data_context) do
        {:ok, chart_data} ->
          {:ok, chart_data}

        {:error, reason} ->
          Logger.warning(fn ->
            "Chart preprocessing failed: #{inspect(reason)}. Continuing without charts."
          end)

          # Don't fail the entire load - just return empty chart data
          {:ok, %{}}
      end
    else
      {:ok, %{}}
    end
  end

  @deprecated "Use load_for_typst/4 with strategy: :aggregation instead"
  @doc """
  Loads report data with aggregation-based chart support.

  **DEPRECATED**: Use `load_for_typst/4` with `strategy: :aggregation` instead.

  This function is maintained for backward compatibility but will be removed in a future version.

  ## Migration

      # Old (deprecated)
      {:ok, data} = DataLoader.load_with_aggregations_for_typst(domain, report, params, opts)

      # New (recommended)
      {:ok, data} = DataLoader.load_for_typst(domain, report, params, Keyword.put(opts, :strategy, :aggregation))

  """
  @spec load_with_aggregations_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, typst_data()} | {:error, term()}
  def load_with_aggregations_for_typst(domain, report_name, params, opts) do
    Logger.warning("""
    load_with_aggregations_for_typst/4 is deprecated.
    Use load_for_typst/4 with strategy: :aggregation instead.
    """)

    load_for_typst(domain, report_name, params, Keyword.put(opts, :strategy, :aggregation))
  end

  # Helper Functions for load_with_aggregations_for_typst/4

  defp maybe_collect_sample(stream, opts) do
    include_sample? = Keyword.get(opts, :include_sample, false)
    sample_size = Keyword.get(opts, :sample_size, 100)

    if include_sample? do
      # Collect sample while draining the entire stream
      # Use reduce to process stream once, collecting first N records
      {sample, _count} =
        stream
        |> Enum.reduce({[], 0}, fn item, {acc, count} ->
          if count < sample_size do
            {[item | acc], count + 1}
          else
            # Still process but don't collect (drains the stream)
            {acc, count + 1}
          end
        end)

      {:ok, Enum.reverse(sample)}
    else
      # Just drain the stream without collecting records
      Stream.run(stream)
      {:ok, []}
    end
  rescue
    error ->
      Logger.error("Error collecting sample: #{inspect(error)}")
      {:error, {:sample_collection_failed, error}}
  end

  defp retrieve_aggregation_state(stream_id) do
    case StreamingPipeline.get_aggregation_state(stream_id) do
      {:ok, agg_data} ->
        {:ok, agg_data}

      {:error, reason} ->
        Logger.warning(fn ->
          "Failed to retrieve aggregation state: #{inspect(reason)}. Continuing with empty aggregations."
        end)

        # Don't fail - return empty aggregations
        {:ok, %{aggregations: %{}, grouped_aggregations: %{}, group_counts: %{}, total_transformed: 0}}
    end
  end

  defp maybe_generate_charts(report, agg_data, opts) do
    preprocess? = Keyword.get(opts, :preprocess_charts, true)

    if preprocess? do
      # Extract chart configurations from report
      chart_configs = ChartDataCollector.extract_chart_configs(report)

      if chart_configs == [] do
        {:ok, %{}}
      else
        # Generate charts from aggregations
        case ChartDataCollector.convert_aggregations_to_charts(
               agg_data.grouped_aggregations,
               chart_configs
             ) do
          chart_data when is_map(chart_data) ->
            {:ok, chart_data}

          error ->
            Logger.warning(fn ->
              "Chart generation failed: #{inspect(error)}. Continuing without charts."
            end)

            {:ok, %{}}
        end
      end
    else
      {:ok, %{}}
    end
  rescue
    error ->
      Logger.error("Error generating charts: #{inspect(error)}")
      {:ok, %{}}
  end

  @deprecated "Use load_for_typst/4 with strategy: :streaming instead"
  @doc """
  Streams large datasets for memory-efficient Typst compilation.

  **DEPRECATED**: Use `load_for_typst/4` with `strategy: :streaming` instead.

  This function is maintained for backward compatibility but will be removed in a future version.

  ## Migration

      # Old (deprecated)
      {:ok, stream} = DataLoader.stream_for_typst(domain, report, params, opts)

      # New (recommended)
      {:ok, stream} = DataLoader.load_for_typst(domain, report, params, Keyword.put(opts, :strategy, :streaming))

  """
  @spec stream_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream_for_typst(domain, report_name, params, opts \\ []) do
    Logger.warning("""
    stream_for_typst/4 is deprecated.
    Use load_for_typst/4 with strategy: :streaming instead.
    """)

    load_for_typst(domain, report_name, params, Keyword.put(opts, :strategy, :streaming))
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
    with {:ok, query} <- QueryBuilder.build_query(domain, report, params, opts),
         {:ok, grouped_aggregations} <- AggregationConfigurator.build_aggregations(report, opts) do
      # Build transformer function
      transformer = build_typst_transformer(report, opts)

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
        {:ok, stream_id, stream} ->
          {:ok, stream_id, stream}

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

end
