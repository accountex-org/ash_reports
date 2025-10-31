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

  alias AshReports.{Band, Report}
  alias AshReports.Element.{
    BarChartElement,
    LineChartElement,
    PieChartElement,
    AreaChartElement,
    ScatterChartElement,
    GanttChartElement,
    SparklineElement
  }
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
          chart_type: atom(),
          error: term() | nil
        }

  @doc """
  Preprocesses all chart elements in a report definition.

  Uses parallel processing with bounded concurrency for optimal performance.

  ## Parameters

    * `report` - The Report struct containing band and element definitions
    * `data_context` - Runtime data context with records, config, and variables
    * `opts` - Options (keyword list)
      * `:parallel` - Enable parallel processing (default: `true`)
      * `:max_concurrency` - Max concurrent chart generations (default: CPU cores × 2)
      * `:timeout` - Timeout per chart in milliseconds (default: `10_000` / 10 seconds)
      * `:on_timeout` - Timeout handling (`:kill_task` or `:error`, default: `:kill_task`)

  ## Returns

    * `{:ok, chart_data}` - Map of chart name to generated chart data
    * `{:error, reason}` - Preprocessing failed

  ## Examples

      iex> report = %Report{bands: [%Band{elements: [chart_element]}]}
      iex> data = %{records: [...], config: %{}, variables: %{}}
      iex> {:ok, charts} = ChartPreprocessor.preprocess(report, data)
      iex> charts[:sales_chart].embedded_code
      "#image.decode(...)"

      # With custom concurrency
      iex> {:ok, charts} = ChartPreprocessor.preprocess(report, data, max_concurrency: 4)

      # Disable parallel processing
      iex> {:ok, charts} = ChartPreprocessor.preprocess(report, data, parallel: false)
  """
  @spec preprocess(Report.t(), data_context(), keyword()) ::
          {:ok, %{atom() => chart_data()}} | {:error, term()}
  def preprocess(%Report{} = report, data_context, opts \\ []) do
    charts = extract_chart_elements(report)
    parallel = Keyword.get(opts, :parallel, true)
    max_concurrency = Keyword.get(opts, :max_concurrency, default_concurrency())
    timeout = Keyword.get(opts, :timeout, 10_000)
    on_timeout = Keyword.get(opts, :on_timeout, :kill_task)

    metadata = %{
      chart_count: length(charts),
      parallel: parallel,
      max_concurrency: max_concurrency,
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
          # Parallel processing with Task.async_stream for bounded concurrency
          charts
          |> Task.async_stream(
            fn chart -> {chart.name, process_chart(chart, data_context)} end,
            max_concurrency: max_concurrency,
            timeout: timeout,
            on_timeout: on_timeout,
            ordered: false
          )
          |> Enum.reduce_while({:ok, %{}}, fn
            {:ok, {name, chart_data}}, {:ok, acc} ->
              {:cont, {:ok, Map.put(acc, name, chart_data)}}

            {:exit, reason}, {:ok, acc} ->
              Logger.error("Chart task exited unexpectedly: #{inspect(reason)}")
              {:cont, {:ok, acc}}

            {:error, reason}, _acc ->
              {:halt, {:error, {:task_error, reason}}}
          end)
          |> case do
            {:ok, data} -> data
            {:error, reason} -> raise reason
          end
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
        Map.merge(metadata, %{
          success_count: map_size(chart_data),
          avg_chart_duration: div(duration, max(1, map_size(chart_data)))
        })
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

    * `chart_element` - The chart element struct (BarChartElement, LineChartElement, etc.)
    * `data_context` - Runtime data context with domain information

  ## Returns

    * Chart data map with svg, embedded_code, etc.
  """
  @spec process_chart(map(), data_context()) :: chart_data()
  def process_chart(chart_element, data_context) do
    start_time = System.monotonic_time()
    chart_name = Map.get(chart_element, :chart_name)
    chart_type = get_chart_type_from_element(chart_element)

    metadata = %{
      chart_name: chart_name,
      chart_type: chart_type
    }

    :telemetry.execute(
      [:ash_reports, :chart_preprocessor, :process_chart, :start],
      %{system_time: System.system_time()},
      metadata
    )

    result =
      with {:ok, chart_def} <- resolve_chart_definition(chart_name, data_context),
           {:ok, chart_data} <- evaluate_data_source(chart_def.data_source, data_context),
           {:ok, svg} <- generate_chart_svg(chart_def, chart_data),
           {:ok, embedded_code} <- embed_chart(svg, %{}) do
        %{
          name: chart_name,
          svg: svg,
          embedded_code: embedded_code,
          chart_type: chart_type,
          error: nil
        }
      else
        {:error, reason} ->
          Logger.debug(fn -> "Chart #{chart_name} generation failed: #{inspect(reason)}" end)
          Logger.warning("Chart #{chart_name} generation failed")

          result = ChartHelpers.generate_error_placeholder(chart_name, reason, style: :compact)
          Map.put(result, :chart_type, chart_type)
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

  defp resolve_chart_definition(chart_name, data_context) do
    # Get domain from context
    domain = Map.get(data_context, :domain)

    if domain do
      case AshReports.Info.chart(domain, chart_name) do
        nil -> {:error, {:chart_not_found, chart_name}}
        chart_def -> {:ok, chart_def}
      end
    else
      {:error, :missing_domain_in_context}
    end
  end

  defp get_chart_type_from_element(%BarChartElement{}), do: :bar_chart
  defp get_chart_type_from_element(%LineChartElement{}), do: :line_chart
  defp get_chart_type_from_element(%PieChartElement{}), do: :pie_chart
  defp get_chart_type_from_element(%AreaChartElement{}), do: :area_chart
  defp get_chart_type_from_element(%ScatterChartElement{}), do: :scatter_chart
  defp get_chart_type_from_element(%GanttChartElement{}), do: :gantt_chart
  defp get_chart_type_from_element(%SparklineElement{}), do: :sparkline
  defp get_chart_type_from_element(_), do: :unknown

  defp generate_chart_svg(chart_def, chart_data) do
    # Determine the chart type module
    case get_chart_type_module(chart_def) do
      nil ->
        {:error, :unknown_chart_type}

      module ->
        build_chart_with_module(module, chart_def, chart_data)
    end
  end

  defp build_chart_with_module(module, chart_def, chart_data) do
    # Build the chart using the type-specific implementation
    config = chart_def.config || struct(get_config_module(chart_def))

    try do
      case module.build(chart_data, config) do
        %_{} = chart_struct ->
          # Generate SVG from the Contex chart struct
          svg_content = Contex.Plot.to_svg(chart_struct)
          {:ok, svg_content}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp get_chart_type_module(%AshReports.Charts.BarChart{}),
    do: AshReports.Charts.Types.BarChart

  defp get_chart_type_module(%AshReports.Charts.LineChart{}),
    do: AshReports.Charts.Types.LineChart

  defp get_chart_type_module(%AshReports.Charts.PieChart{}),
    do: AshReports.Charts.Types.PieChart

  defp get_chart_type_module(%AshReports.Charts.AreaChart{}),
    do: AshReports.Charts.Types.AreaChart

  defp get_chart_type_module(%AshReports.Charts.ScatterChart{}),
    do: AshReports.Charts.Types.ScatterPlot

  defp get_chart_type_module(%AshReports.Charts.GanttChart{}),
    do: AshReports.Charts.Types.GanttChart

  defp get_chart_type_module(%AshReports.Charts.Sparkline{}),
    do: AshReports.Charts.Types.Sparkline

  defp get_chart_type_module(_), do: nil

  defp get_config_module(%AshReports.Charts.BarChart{}), do: AshReports.Charts.BarChartConfig
  defp get_config_module(%AshReports.Charts.LineChart{}), do: AshReports.Charts.LineChartConfig
  defp get_config_module(%AshReports.Charts.PieChart{}), do: AshReports.Charts.PieChartConfig
  defp get_config_module(%AshReports.Charts.AreaChart{}), do: AshReports.Charts.AreaChartConfig

  defp get_config_module(%AshReports.Charts.ScatterChart{}),
    do: AshReports.Charts.ScatterChartConfig

  defp get_config_module(%AshReports.Charts.GanttChart{}),
    do: AshReports.Charts.GanttChartConfig

  defp get_config_module(%AshReports.Charts.Sparkline{}), do: AshReports.Charts.SparklineConfig
  defp get_config_module(_), do: nil

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
    |> Enum.flat_map(&extract_chart_elements_from_band/1)
  end

  defp extract_chart_elements_from_band(%Band{elements: elements, bands: nested_bands}) do
    # Extract chart elements from this band
    chart_elements =
      (elements || [])
      |> Enum.filter(&is_chart_element?/1)

    # Recursively extract from nested bands
    nested_chart_elements =
      (nested_bands || [])
      |> Enum.flat_map(&extract_chart_elements_from_band/1)

    chart_elements ++ nested_chart_elements
  end

  defp is_chart_element?(%BarChartElement{}), do: true
  defp is_chart_element?(%LineChartElement{}), do: true
  defp is_chart_element?(%PieChartElement{}), do: true
  defp is_chart_element?(%AreaChartElement{}), do: true
  defp is_chart_element?(%ScatterChartElement{}), do: true
  defp is_chart_element?(%GanttChartElement{}), do: true
  defp is_chart_element?(%SparklineElement{}), do: true
  defp is_chart_element?(_), do: false

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

  defp default_concurrency do
    # Default to 2x CPU cores for optimal parallelism without overwhelming the system
    System.schedulers_online() * 2
  end
end
