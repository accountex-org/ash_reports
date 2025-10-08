defmodule AshReports.Streaming.DataLoader do
  @moduledoc """
  Shared streaming data loading interface for all AshReports renderers.

  This module provides a unified, renderer-agnostic streaming data loading API
  that supports multiple loading strategies optimized for different use cases.
  All renderers (PDF via Typst, HTML, HEEX, JSON) use this module to load data
  from Ash resources using the GenStage streaming pipeline.

  ## Architecture Integration

  ```
  AshReports DSL → Streaming.DataLoader → StreamingPipeline (GenStage)
                          ↓
                  Renderer-agnostic Data → [Renderer-specific processing]
  ```

  ## Key Features

  - **Multiple Loading Strategies**: Auto-select between in-memory, aggregation, and streaming
  - **Renderer-Agnostic**: Works with any renderer (Typst, HTML, HEEX, JSON)
  - **GenStage Streaming**: Memory-efficient processing with backpressure
  - **Customizable Transformers**: Renderer-specific data transformation via callbacks
  - **Aggregation Support**: Streaming aggregations for large datasets

  ## Loading Strategies

  ### `:auto` (default)
  Automatically selects the best strategy:
  - Reports with aggregation-based charts → `:aggregation`
  - Reports with limit ≤ 10K → `:in_memory`
  - Reports with no limit or limit > 10K → `:streaming`

  ### `:in_memory`
  Loads all records into memory.
  - **Best for**: Small to medium reports (< 10K records)
  - **Returns**: `{:ok, data}` with records

  ### `:aggregation`
  Uses streaming aggregations without loading all records.
  - **Best for**: Reports with aggregation-based charts (any dataset size)
  - **Memory**: O(groups) not O(records)
  - **Returns**: `{:ok, data}` with aggregations and optional sample records

  ### `:streaming`
  Returns a stream for manual processing.
  - **Best for**: Large datasets requiring custom processing
  - **Returns**: `{:ok, stream}` where stream yields processed records

  ## Usage Examples

  ### Basic Data Loading

      iex> {:ok, data} = Streaming.DataLoader.load(MyApp.Domain, :sales_report, %{
      ...>   start_date: ~D[2024-01-01],
      ...>   end_date: ~D[2024-01-31]
      ...> }, [])

  ### With Custom Transformer

      transformer = fn record ->
        %{
          customer: record.customer_name,
          amount: Decimal.to_float(record.amount)
        }
      end

      {:ok, data} = Streaming.DataLoader.load(MyApp.Domain, :sales_report, params,
        transformer: transformer
      )

  ### Streaming Large Datasets

      {:ok, stream} = Streaming.DataLoader.load(MyApp.Domain, :large_report, params,
        strategy: :streaming
      )

      stream
      |> Stream.chunk_every(100)
      |> Enum.each(&process_chunk/1)
  """

  alias AshReports.Report
  alias AshReports.Typst.{QueryBuilder, StreamingPipeline}

  require Logger

  @typedoc """
  Generic data structure returned by load operations.
  """
  @type data :: %{
          records: [map()],
          config: map(),
          variables: map(),
          metadata: map()
        }

  @typedoc """
  Options for data loading.
  """
  @type load_options :: [
          strategy: :auto | :in_memory | :aggregation | :streaming,
          chunk_size: pos_integer(),
          transformer: (term() -> map()),
          limit: pos_integer() | nil,
          include_sample: boolean(),
          sample_size: pos_integer()
        ]

  @typedoc """
  Loading strategy for report data.

  * `:auto` - Automatically select best strategy (default)
  * `:in_memory` - Load all records into memory
  * `:aggregation` - Use streaming aggregations
  * `:streaming` - Return a stream for manual processing
  """
  @type loading_strategy :: :auto | :in_memory | :aggregation | :streaming

  @doc """
  Loads report data with automatic strategy selection.

  This unified API automatically selects the best loading strategy based on the
  report configuration and options. You can override the strategy selection by
  passing the `:strategy` option.

  ## Parameters

    * `domain` - The Ash domain containing the report definition
    * `report_name` - Name of the report to load data for
    * `params` - Parameters for report generation
    * `opts` - Loading options

  ## Options

    * `:strategy` - Loading strategy (default: `:auto`)
    * `:transformer` - Custom record transformation function
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
      {:ok, data} = Streaming.DataLoader.load(MyApp.Domain, :sales_report, %{}, [])

      # Force in-memory strategy
      {:ok, data} = Streaming.DataLoader.load(MyApp.Domain, :sales_report, params,
        strategy: :in_memory,
        limit: 5000
      )

      # Custom transformer
      transformer = fn record -> Map.take(record, [:id, :name]) end
      {:ok, data} = Streaming.DataLoader.load(MyApp.Domain, :sales_report, params,
        transformer: transformer
      )
  """
  @spec load(module(), atom(), map(), load_options()) ::
          {:ok, data()} | {:ok, Enumerable.t()} | {:error, term()}
  def load(domain, report_name, params, opts \\ []) do
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

  @doc false
  def determine_strategy(domain, report_name, opts) do
    case Keyword.get(opts, :strategy) do
      nil ->
        auto_select_strategy(domain, report_name, opts)

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
        # Check if report has charts (may need aggregations)
        has_charts = has_chart_elements?(report)

        # Check limit option
        limit = Keyword.get(opts, :limit)

        cond do
          has_charts -> :aggregation
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
         {:ok, transformed_records} <- transform_records(records, opts),
         {:ok, data_context} <- build_data_context(report, transformed_records, params) do
      Logger.debug(fn ->
        "Successfully loaded #{length(transformed_records)} records"
      end)

      {:ok, data_context}
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
         {:ok, agg_data} <- retrieve_aggregation_state(stream_id) do
      context = %{
        aggregations: agg_data,
        config: %{
          report_name: report.name,
          title: report.title
        },
        variables: params,
        records: sample_records,
        metadata: %{
          strategy: :aggregation,
          sample_size: length(sample_records)
        }
      }

      Logger.debug(fn ->
        "Successfully loaded aggregations with #{length(sample_records)} sample records"
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

  defp transform_records(records, opts) do
    transformer = Keyword.get(opts, :transformer, &default_transformer/1)

    try do
      transformed =
        Enum.map(records, fn record ->
          transformer.(record)
        end)

      {:ok, transformed}
    rescue
      error ->
        {:error, {:transformation_failed, error}}
    end
  end

  defp default_transformer(record) when is_struct(record) do
    # Convert struct to plain map
    Map.from_struct(record)
  end

  defp default_transformer(record) when is_map(record) do
    record
  end

  defp build_data_context(report, transformed_records, params) do
    context = %{
      records: transformed_records,
      config: %{
        report_name: report.name,
        title: report.title
      },
      variables: params,
      metadata: %{
        record_count: length(transformed_records),
        loaded_at: DateTime.utc_now()
      }
    }

    {:ok, context}
  end

  defp maybe_collect_sample(stream, opts) do
    include_sample? = Keyword.get(opts, :include_sample, false)
    sample_size = Keyword.get(opts, :sample_size, 100)

    if include_sample? do
      # Collect sample while draining the entire stream
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
      Logger.debug(fn -> "Error collecting sample: #{inspect(error)}" end)
      Logger.error("Sample collection failed")
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
        {:ok,
         %{aggregations: %{}, grouped_aggregations: %{}, group_counts: %{}, total_transformed: 0}}
    end
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
    with {:ok, query} <- QueryBuilder.build_query(domain, report, params, opts) do
      # Build transformer function
      transformer = build_transformer(opts)

      # Build pipeline options
      pipeline_opts =
        build_pipeline_opts(
          domain,
          report,
          query,
          params,
          opts,
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

  defp build_pipeline_opts(domain, report, query, params, opts, transformer) do
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
      # Aggregations
      aggregations: Keyword.get(opts, :aggregations, []),
      grouped_aggregations: Keyword.get(opts, :grouped_aggregations, []),
      # Resource limits
      memory_limit: Keyword.get(opts, :memory_limit, 500_000_000),
      timeout: Keyword.get(opts, :timeout, 300_000)
    ]
  end

  defp build_transformer(opts) do
    # Use custom transformer if provided, otherwise default
    Keyword.get(opts, :transformer, &default_transformer/1)
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

  defp has_chart_elements?(report) do
    # Check if any band contains chart elements
    Enum.any?(report.bands || [], fn band ->
      Enum.any?(band.elements || [], fn element ->
        element.type == :chart
      end)
    end)
  end
end
