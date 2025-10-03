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
  """

  require Logger

  alias AshReports.{Band, Charts, Report}
  alias AshReports.Element.Chart
  alias AshReports.Typst.ChartEmbedder

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
  @spec preprocess(Report.t(), data_context()) :: {:ok, %{atom() => chart_data()}} | {:error, term()}
  def preprocess(%Report{} = report, data_context) do
    charts = extract_chart_elements(report)

    chart_data =
      charts
      |> Enum.map(fn chart ->
        {chart.name, process_chart(chart, data_context)}
      end)
      |> Map.new()

    {:ok, chart_data}
  rescue
    error ->
      Logger.error("Chart preprocessing failed: #{inspect(error)}")
      {:error, {:preprocessing_failed, error}}
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
        Logger.warning("Chart #{chart.name} generation failed: #{inspect(reason)}")

        %{
          name: chart.name,
          svg: nil,
          embedded_code: generate_error_placeholder(chart.name, reason),
          chart_type: chart.chart_type,
          error: reason
        }
    end
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
    Logger.warning("Unsupported expression format for chart data: #{inspect(expr)}")
    {:error, {:unsupported_expression, expr}}
  end

  defp generate_error_placeholder(name, reason) do
    error_msg = format_error(reason)

    """
    #block(
      width: 100%,
      fill: rgb(255, 240, 240),
      inset: 1em,
      stroke: 1pt + red,
      [
        #text(weight: "bold", fill: red)[Chart Error: #{name}]
        #linebreak()
        #text(size: 10pt)[#{error_msg}]
      ]
    )
    """
  end

  defp format_error({:unsupported_expression, _expr}), do: "Unsupported expression format"
  defp format_error(:missing_data_source), do: "No data source specified"
  defp format_error(:config_must_be_map), do: "Config must evaluate to a map"
  defp format_error({:generation_failed, reason}), do: "Chart generation failed: #{inspect(reason)}"
  defp format_error(reason), do: "Error: #{inspect(reason)}"
end
