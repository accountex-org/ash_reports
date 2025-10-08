defmodule AshReports.Typst.DataLoader do
  @moduledoc """
  Specialized DataLoader for Typst integration that extends the shared
  AshReports.Streaming.DataLoader with Typst-specific data transformation
  and chart preprocessing.

  This module serves as the critical data integration layer between AshReports
  DSL definitions and actual Ash resource data, transforming it into a format
  suitable for Typst template compilation.

  ## Architecture Integration

  ```
  AshReports DSL → Typst.DataLoader → Streaming.DataLoader → StreamingPipeline
                         ↓
              Typst-Compatible Data → Typst Template → BinaryWrapper → PDF
  ```

  ## Key Features

  - **Typst-Compatible Data**: Transforms Ash structs to plain maps for Typst templates
  - **Type Conversion**: Handles DateTime, Decimal, Money, UUID, and custom types
  - **Relationship Traversal**: Deep relationship chains with safe nil handling
  - **Chart Preprocessing**: Automatic chart data generation from report elements
  - **Streaming Support**: Delegates to shared GenStage-based pipeline
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
  alias AshReports.Streaming.DataLoader, as: StreamingDataLoader

  alias AshReports.Typst.{
    AggregationConfigurator,
    ChartPreprocessor,
    DataProcessor
  }

  require Logger

  @typedoc """
  Typst-compatible data structure for template compilation.
  """
  @type typst_data :: %{
          records: [map()],
          config: map(),
          variables: map(),
          groups: [map()],
          metadata: map(),
          charts: map()
        }

  @typedoc """
  Options for Typst data loading.
  """
  @type load_options :: [
          strategy: :auto | :in_memory | :aggregation | :streaming,
          chunk_size: pos_integer(),
          type_conversion: keyword(),
          preprocess_charts: boolean()
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

  This is a thin wrapper around `AshReports.Streaming.DataLoader` that adds
  Typst-specific data transformation and chart preprocessing.

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
      {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, %{}, [])

      # Force in-memory strategy with chart preprocessing
      {:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :sales_report, params,
        strategy: :in_memory,
        preprocess_charts: true
      )

      # Get a stream for custom processing
      {:ok, stream} = DataLoader.load_for_typst(MyApp.Domain, :large_report, params,
        strategy: :streaming
      )
  """
  @spec load_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, typst_data()} | {:ok, Enumerable.t()} | {:error, term()}
  def load_for_typst(domain, report_name, params, opts \\ []) do
    # Build Typst-specific transformer
    typst_transformer = build_typst_transformer(opts)

    # Get report to check for aggregations
    with {:ok, report} <- get_report_definition(domain, report_name) do
      # Add aggregation configuration if needed
      opts_with_aggregations = maybe_add_aggregations(report, opts)

      # Merge Typst-specific options
      streaming_opts =
        opts_with_aggregations
        |> Keyword.put(:transformer, typst_transformer)

      # Delegate to shared streaming data loader
      case StreamingDataLoader.load(domain, report_name, params, streaming_opts) do
        {:ok, data} when is_map(data) ->
          # Post-process for Typst (add charts if in-memory strategy)
          postprocess_for_typst(data, report, opts)

        {:ok, stream} ->
          # Streaming strategy - return stream as-is
          {:ok, stream}

        {:error, reason} = error ->
          Logger.error(fn ->
            "Failed to load data for Typst report #{report_name}: #{inspect(reason)}"
          end)

          error
      end
    end
  end

  @deprecated "Use load_for_typst/4 with strategy: :aggregation instead"
  @doc """
  Loads report data with aggregation-based chart support.

  **DEPRECATED**: Use `load_for_typst/4` with `strategy: :aggregation` instead.
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

  @deprecated "Use load_for_typst/4 with strategy: :streaming instead"
  @doc """
  Streams large datasets for memory-efficient Typst compilation.

  **DEPRECATED**: Use `load_for_typst/4` with `strategy: :streaming` instead.
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
      ],
      preprocess_charts: true
    ]

    Keyword.merge(defaults, overrides)
  end

  # Test Helpers
  # These functions are exposed for testing integration with grouped aggregations

  @doc false
  def __test_build_grouped_aggregations__(report) do
    # Delegate to AggregationConfigurator for testing
    case AggregationConfigurator.build_aggregations(report, []) do
      {:ok, grouped_aggregations} -> grouped_aggregations
      {:error, _reason} -> []
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

  defp build_typst_transformer(opts) do
    # Create a transformer function that processes records for Typst
    type_conversion_opts = Keyword.get(opts, :type_conversion, [])

    fn record ->
      # Convert single record - DataProcessor.convert_records expects a list
      case DataProcessor.convert_records([record], type_conversion: type_conversion_opts) do
        {:ok, [converted]} -> converted
        {:ok, []} -> nil
        {:error, _reason} -> nil
      end
    end
  end

  defp maybe_add_aggregations(report, opts) do
    # Check if we need to build aggregations for charts
    strategy = Keyword.get(opts, :strategy, :auto)

    if strategy in [:aggregation, :auto] do
      case AggregationConfigurator.build_aggregations(report, opts) do
        {:ok, grouped_aggregations} ->
          Keyword.put(opts, :grouped_aggregations, grouped_aggregations)

        {:error, reason} ->
          Logger.warning(fn ->
            "Failed to build aggregations: #{inspect(reason)}. Continuing without aggregations."
          end)

          opts
      end
    else
      opts
    end
  end

  defp postprocess_for_typst(data, report, opts) do
    preprocess_charts? = Keyword.get(opts, :preprocess_charts, true)

    if preprocess_charts? && Map.has_key?(data, :records) do
      # In-memory strategy - preprocess charts from records
      case ChartPreprocessor.preprocess(report, data) do
        {:ok, chart_data} ->
          result = Map.put(data, :charts, chart_data)
          {:ok, result}

        {:error, reason} ->
          Logger.warning(fn ->
            "Chart preprocessing failed: #{inspect(reason)}. Continuing without charts."
          end)

          {:ok, Map.put(data, :charts, %{})}
      end
    else
      # Aggregation strategy or charts disabled - charts already in data
      {:ok, Map.put_new(data, :charts, %{})}
    end
  end
end
