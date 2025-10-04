defmodule AshReports.Typst.ChartPreprocessor do
  @moduledoc """
  Preprocesses chart elements in reports by generating SVG charts and embedding them into templates.

  This module bridges the gap between DSL chart definitions and Typst templates by:
  1. Extracting chart elements from report bands
  2. Evaluating data_source expressions with report data context
  3. Generating SVG charts using the Charts module
  4. Embedding SVG charts using the ChartEmbedder module
  5. Injecting chart data into the report context for template rendering

  ## Architecture

  ```
  Report DSL → ChartPreprocessor → Charts.generate → ChartEmbedder → Template Context
  ```

  ## Usage

      # Preprocess all charts in a report
      {:ok, chart_data} = ChartPreprocessor.preprocess(report, data_context)

      # chart_data can be passed to DSLGenerator context
      context = Map.put(context, :charts, chart_data)

  ## Data Context Format

  The data context should match the format used in Typst templates:

      %{
        records: [%{field: value, ...}],
        config: %{param: value, ...},
        variables: %{var: value, ...}
      }

  ## Telemetry

  Emits the following telemetry events:

    * `[:ash_reports, :chart_preprocessor, :preprocess, :start]` - Preprocessing started
    * `[:ash_reports, :chart_preprocessor, :preprocess, :stop]` - Preprocessing completed
    * `[:ash_reports, :chart_preprocessor, :preprocess, :exception]` - Preprocessing failed
    * `[:ash_reports, :chart_preprocessor, :process_chart, :start]` - Single chart processing started
    * `[:ash_reports, :chart_preprocessor, :process_chart, :stop]` - Single chart processing completed
  """

  require Logger

  alias AshReports.{Band, Charts, Report}
  alias AshReports.Element.Chart
  alias AshReports.Typst.{ChartEmbedder, ChartHelpers}

  @type data_context :: %{
          records: [map()],
          config: map(),
          variables: map()
        }

  @type chart_data :: %{
          name: atom(),
          svg: String.t(),
          embedded_code: String.t(),
          chart_type: Chart.chart_type(),
          error: term() | nil
        }

  @doc """
  Preprocesses all chart elements in a report definition.

  ## Parameters

    * `report` - The Report struct containing band and element definitions
    * `data_context` - Runtime data context with records, config, and variables

  ## Returns

    * `{:ok, chart_data}` - Map of chart name to generated chart data
    * `{:error, reason}` - Preprocessing failed

  ## Examples

      iex> report = %Report{bands: [%Band{elements: [chart_element]}]}
      iex> data = %{records: [...], config: %{}, variables: %{}}
      iex> {:ok, charts} = ChartPreprocessor.preprocess(report, data)
      iex> charts[:sales_chart].embedded_code
      "#image.decode(...)"
  """
  @spec preprocess(Report.t(), data_context(), keyword()) ::
          {:ok, %{atom() => chart_data()}} | {:error, term()}
  def preprocess(%Report{} = report, data_context, opts \\ []) do
    charts = extract_chart_elements(report)
    parallel = Keyword.get(opts, :parallel, true)

    metadata = %{
      chart_count: length(charts),
      parallel: parallel,
      report_name: Map.get(report, :name)
    }

    :telemetry.execute(
      [:ash_reports, :chart_preprocessor, :preprocess, :start],
      %{system_time: System.system_time()},
      metadata
    )

    start_time = System.monotonic_time()

    try do
      chart_data =
        if parallel and length(charts) > 1 do
          # Parallel processing for multiple charts
          charts
          |> Enum.map(fn chart ->
            Task.async(fn -> {chart.name, process_chart(chart, data_context)} end)
          end)
          |> Enum.map(&Task.await(&1, :infinity))
          |> Map.new()
        else
          # Sequential processing for single chart or when parallel disabled
          charts
          |> Enum.map(fn chart ->
            {chart.name, process_chart(chart, data_context)}
          end)
          |> Map.new()
        end

      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:ash_reports, :chart_preprocessor, :preprocess, :stop],
        %{duration: duration},
        Map.put(metadata, :success_count, map_size(chart_data))
      )

      {:ok, chart_data}
    rescue
      error ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:ash_reports, :chart_preprocessor, :preprocess, :exception],
          %{duration: duration},
          Map.merge(metadata, %{error: error, kind: :error})
        )

        Logger.debug(fn -> "Chart preprocessing failed: #{inspect(error, pretty: true)}" end)
        Logger.error("Chart preprocessing failed")
        {:error, {:preprocessing_failed, error}}
    end
  end

  @doc """
  Creates a lazy evaluator for chart preprocessing.

  Returns a function that, when called, will generate the chart. Useful for
  complex multi-chart reports where charts should only be generated if needed.

  ## Parameters

    * `report` - The Report struct
    * `data_context` - Runtime data context

  ## Returns

    * `{:ok, lazy_charts}` - Map of chart name to lazy evaluator functions

  ## Examples

      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data)

      # Generate only the charts you need
      sales_chart = lazy_charts[:sales_chart].()
  """
  @spec preprocess_lazy(Report.t(), data_context()) ::
          {:ok, %{atom() => (-> chart_data())}}
  def preprocess_lazy(%Report{} = report, data_context) do
    charts = extract_chart_elements(report)

    lazy_charts =
      charts
      |> Enum.map(fn chart ->
        lazy_fn = fn -> process_chart(chart, data_context) end
        {chart.name, lazy_fn}
      end)
      |> Map.new()

    {:ok, lazy_charts}
  end

  @doc """
  Processes a single chart element.

  ## Parameters

    * `chart` - The Chart element struct
    * `data_context` - Runtime data context

  ## Returns

    * Chart data map with svg, embedded_code, etc.
  """
  @spec process_chart(Chart.t(), data_context()) :: chart_data()
  def process_chart(%Chart{} = chart, data_context) do
    start_time = System.monotonic_time()

    metadata = %{
      chart_name: chart.name,
      chart_type: chart.chart_type
    }

    :telemetry.execute(
      [:ash_reports, :chart_preprocessor, :process_chart, :start],
      %{system_time: System.system_time()},
      metadata
    )

    result =
      with {:ok, chart_data} <- evaluate_data_source(chart.data_source, data_context),
           {:ok, chart_config} <- evaluate_config(chart.config, data_context),
           {:ok, svg} <- Charts.generate(chart.chart_type, chart_data, chart_config),
           {:ok, embedded_code} <- embed_chart(svg, chart.embed_options) do
        %{
          name: chart.name,
          svg: svg,
          embedded_code: embedded_code,
          chart_type: chart.chart_type,
          error: nil
        }
      else
        {:error, reason} ->
          Logger.debug(fn -> "Chart #{chart.name} generation failed: #{inspect(reason)}" end)
          Logger.warning("Chart #{chart.name} generation failed")

          result = ChartHelpers.generate_error_placeholder(chart.name, reason, style: :compact)
          Map.put(result, :chart_type, chart.chart_type)
      end

    duration = System.monotonic_time() - start_time
    svg_size = if is_nil(result.error), do: byte_size(result.svg), else: 0

    :telemetry.execute(
      [:ash_reports, :chart_preprocessor, :process_chart, :stop],
      %{duration: duration, svg_size: svg_size},
      Map.merge(metadata, %{success: is_nil(result.error)})
    )

    result
  end

  defp embed_chart(svg, embed_options) when is_map(embed_options) do
    # Convert map to keyword list for ChartEmbedder
    opts = Map.to_list(embed_options)
    ChartEmbedder.embed(svg, opts)
  end

  defp embed_chart(svg, embed_options) when is_list(embed_options) do
    ChartEmbedder.embed(svg, embed_options)
  end

  defp embed_chart(svg, _) do
    ChartEmbedder.embed(svg, [])
  end

  # Private Functions

  defp extract_chart_elements(%Report{bands: bands}) do
    bands
    |> Enum.flat_map(fn %Band{elements: elements} -> elements || [] end)
    |> Enum.filter(fn element -> element.__struct__ == Chart end)
  end

  defp evaluate_data_source(nil, _context) do
    {:error, :missing_data_source}
  end

  defp evaluate_data_source(data_source, context) do
    # For MVP, we support:
    # 1. Static data (list of maps)
    # 2. Simple field references via context
    # 3. Ash.Expr expressions (simplified evaluation)

    case data_source do
      # Already evaluated data
      data when is_list(data) ->
        {:ok, data}

      # Ash.Expr - evaluate with context
      %{__struct__: Ash.Expr, expression: expr} ->
        evaluate_expression(expr, context)

      # Fallback for other expression formats
      _ ->
        evaluate_expression(data_source, context)
    end
  end

  defp evaluate_config(config, _context) when is_map(config) do
    # Config is already a map - use as-is
    # In the future, we might support expressions in config values
    {:ok, config}
  end

  defp evaluate_config(%{__struct__: Ash.Expr, expression: expr}, context) do
    # Config is an expression - evaluate it
    case evaluate_expression(expr, context) do
      {:ok, result} when is_map(result) -> {:ok, result}
      {:ok, _other} -> {:error, :config_must_be_map}
      error -> error
    end
  end

  defp evaluate_config(nil, _context) do
    {:ok, %{}}
  end

  defp evaluate_config(_other, _context) do
    {:ok, %{}}
  end

  defp evaluate_expression(:records, %{records: records}) do
    {:ok, records}
  end

  defp evaluate_expression({:ref, [], field}, %{records: records}) when is_atom(field) do
    # Reference to a field - return all values
    values = Enum.map(records, &Map.get(&1, field))
    {:ok, values}
  end

  defp evaluate_expression({:get_path, _meta, path}, context) do
    # Navigate nested path in context
    result = get_in(context, path)
    {:ok, result}
  end

  defp evaluate_expression(expr, _context) when is_list(expr) do
    # Already a list - use as-is
    {:ok, expr}
  end

  defp evaluate_expression(expr, _context) do
    # Unsupported expression format
    Logger.debug(fn -> "Unsupported expression format for chart data: #{inspect(expr)}" end)
    Logger.warning("Unsupported expression format for chart data")
    {:error, {:unsupported_expression, expr}}
  end
end
