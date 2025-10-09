defmodule AshReports.Typst.DataLoader do
  @moduledoc """
  Typst-specific wrapper around `AshReports.Streaming.DataLoader` that adds
  Typst data transformation and chart preprocessing.

  Delegates core streaming to `AshReports.Streaming.DataLoader` while providing:
  - Type conversion via `DataProcessor` (DateTime, Decimal, Money, UUID)
  - Chart preprocessing via `ChartPreprocessor`
  - Aggregation configuration for streaming charts

  See `AshReports.Streaming.DataLoader` for strategy details (:auto, :in_memory, :aggregation, :streaming).

  ## Examples

      # Automatic strategy selection
      {:ok, data} = DataLoader.load_for_typst(MyDomain, :sales_report, %{})

      # Force in-memory with chart preprocessing
      {:ok, data} = DataLoader.load_for_typst(MyDomain, :sales_report, params,
        strategy: :in_memory,
        preprocess_charts: true
      )

      # Streaming for large datasets
      {:ok, stream} = DataLoader.load_for_typst(MyDomain, :large_report, params,
        strategy: :streaming
      )
  """

  alias AshReports.Report
  alias AshReports.Streaming.DataLoader, as: StreamingDataLoader
  alias AshReports.Typst.{AggregationConfigurator, ChartPreprocessor, DataProcessor}

  require Logger

  @type typst_data :: %{
          records: [map()],
          config: map(),
          variables: map(),
          groups: [map()],
          metadata: map(),
          charts: map()
        }

  @type load_options :: [
          strategy: :auto | :in_memory | :aggregation | :streaming,
          chunk_size: pos_integer(),
          type_conversion: keyword(),
          preprocess_charts: boolean()
        ]

  @doc """
  Loads report data for Typst compilation.

  Wraps `Streaming.DataLoader.load/4` with Typst-specific transformation and chart preprocessing.

  ## Options

    * `:strategy` - `:auto` (default), `:in_memory`, `:aggregation`, `:streaming`
    * `:preprocess_charts` - Enable chart preprocessing (default: true)
    * `:type_conversion` - Options for DataProcessor
    * Other options: See `AshReports.Streaming.DataLoader.load/4`

  ## Returns

    * `{:ok, data}` - Loaded data (in-memory/aggregation)
    * `{:ok, stream}` - Data stream (streaming)
    * `{:error, term()}` - Failure
  """
  @spec load_for_typst(module(), atom(), map(), load_options()) ::
          {:ok, typst_data()} | {:ok, Enumerable.t()} | {:error, term()}
  def load_for_typst(domain, report_name, params, opts \\ []) do
    with {:ok, report} <- get_report(domain, report_name),
         opts_with_transformer <- add_typst_transformer(opts),
         opts_with_aggs <- maybe_add_aggregations(report, opts_with_transformer) do
      case StreamingDataLoader.load(domain, report_name, params, opts_with_aggs) do
        {:ok, data} when is_map(data) -> postprocess_for_typst(data, report, opts)
        {:ok, stream} -> {:ok, stream}
        {:error, _} = error -> error
      end
    end
  end

  @deprecated "Use load_for_typst/4 with strategy: :aggregation"
  def load_with_aggregations_for_typst(domain, report_name, params, opts) do
    load_for_typst(domain, report_name, params, Keyword.put(opts, :strategy, :aggregation))
  end

  @deprecated "Use load_for_typst/4 with strategy: :streaming"
  def stream_for_typst(domain, report_name, params, opts \\ []) do
    load_for_typst(domain, report_name, params, Keyword.put(opts, :strategy, :streaming))
  end

  @doc """
  Creates Typst data loading configuration with sensible defaults.

  ## Examples

      config = DataLoader.typst_config(chunk_size: 2000)
  """
  @spec typst_config(keyword()) :: load_options()
  def typst_config(overrides \\ []) do
    Keyword.merge(
      [
        chunk_size: 1000,
        type_conversion: [datetime_format: :iso8601, decimal_precision: 2, money_format: :symbol],
        preprocess_charts: true
      ],
      overrides
    )
  end

  # Test helper for aggregation integration tests
  @doc false
  def __test_build_grouped_aggregations__(report) do
    case AggregationConfigurator.build_aggregations(report, []) do
      {:ok, grouped_aggregations} -> grouped_aggregations
      {:error, _} -> []
    end
  end

  # Private Functions

  defp get_report(domain, report_name) do
    case AshReports.Info.report(domain, report_name) do
      nil -> {:error, {:report_not_found, report_name}}
      %Report{} = report -> {:ok, report}
      other -> {:error, {:invalid_report_definition, other}}
    end
  rescue
    error -> {:error, {:report_lookup_failed, error}}
  end

  defp add_typst_transformer(opts) do
    type_conversion_opts = Keyword.get(opts, :type_conversion, [])

    transformer = fn record ->
      case DataProcessor.convert_records([record], type_conversion: type_conversion_opts) do
        {:ok, [converted]} -> converted
        _ -> nil
      end
    end

    Keyword.put(opts, :transformer, transformer)
  end

  defp maybe_add_aggregations(report, opts) do
    strategy = Keyword.get(opts, :strategy, :auto)

    if strategy in [:aggregation, :auto] do
      case AggregationConfigurator.build_aggregations(report, opts) do
        {:ok, grouped_aggregations} ->
          Keyword.put(opts, :grouped_aggregations, grouped_aggregations)

        {:error, reason} ->
          Logger.warning(fn ->
            "Failed to build aggregations: #{inspect(reason)}. Continuing without."
          end)

          opts
      end
    else
      opts
    end
  end

  defp postprocess_for_typst(data, report, opts) do
    if Keyword.get(opts, :preprocess_charts, true) && Map.has_key?(data, :records) do
      case ChartPreprocessor.preprocess(report, data) do
        {:ok, chart_data} ->
          {:ok, Map.put(data, :charts, chart_data)}

        {:error, reason} ->
          Logger.warning(fn -> "Chart preprocessing failed: #{inspect(reason)}" end)
          {:ok, Map.put(data, :charts, %{})}
      end
    else
      {:ok, Map.put_new(data, :charts, %{})}
    end
  end
end
