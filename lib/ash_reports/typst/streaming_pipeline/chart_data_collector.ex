defmodule AshReports.Typst.StreamingPipeline.ChartDataCollector do
  @moduledoc """
  Collects and transforms aggregation data for chart generation during streaming.

  This module converts streaming aggregation results into chart-ready data formats,
  enabling chart generation without loading all records into memory.

  ## Architecture

  ```
  ProducerConsumer (aggregations) → ChartDataCollector → Chart Data → ChartPreprocessor
  ```

  ## Supported Chart Strategies

  ### 1. Aggregation-Based Charts
  Charts that visualize grouped aggregation results:

      chart :sales_by_region do
        chart_type :bar
        data_source expr(aggregation(:region, :sum, :amount))
      end

  Converts aggregation state:
  ```
  %{[:region] => %{"North" => %{sum: %{amount: 15000}}}}
  ```

  To chart data:
  ```
  [%{category: "North", value: 15000}]
  ```

  ### 2. Full-Record Charts (Not Implemented)
  Requires `load_for_typst/4` instead of streaming.

  ## Usage

      # Extract chart configs from report
      chart_configs = extract_chart_configs(report)

      # After streaming completes, convert aggregations to chart data
      chart_data = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        chart_configs
      )
  """

  require Logger

  alias AshReports.{Charts, Report}
  alias AshReports.Element.Chart
  alias AshReports.Typst.ChartEmbedder

  @type aggregation_ref :: %{
          group_by: atom() | [atom()],
          aggregation_type: :sum | :count | :avg | :min | :max,
          field: atom() | nil
        }

  @type chart_config :: %{
          name: atom(),
          chart_type: Chart.chart_type(),
          aggregation_ref: aggregation_ref(),
          chart_config: map(),
          embed_options: map()
        }

  @doc """
  Extracts chart configurations from a report that use aggregation data sources.

  Analyzes chart elements to identify those that reference aggregations rather than
  raw records.

  ## Parameters

    * `report` - The Report struct

  ## Returns

    * List of chart configs for aggregation-based charts

  ## Examples

      iex> report = %Report{bands: [%Band{elements: [chart_element]}]}
      iex> configs = ChartDataCollector.extract_chart_configs(report)
      [%{name: :sales_chart, aggregation_ref: %{...}}]
  """
  @spec extract_chart_configs(Report.t()) :: [chart_config()]
  def extract_chart_configs(%Report{} = report) do
    report.bands
    |> Enum.flat_map(fn band -> band.elements || [] end)
    |> Enum.filter(&is_chart_element?/1)
    |> Enum.map(&parse_chart_config/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Converts grouped aggregation state to chart-ready data.

  Takes the final aggregation state from ProducerConsumer and transforms it into
  the data format expected by each chart type.

  ## Parameters

    * `grouped_aggregation_state` - Final state from ProducerConsumer
    * `chart_configs` - List of chart configurations

  ## Returns

    * Map of chart name to chart data struct (same format as ChartPreprocessor)

  ## Examples

      iex> state = %{[:region] => %{"North" => %{sum: %{amount: 15000}}}}
      iex> configs = [%{name: :sales, aggregation_ref: %{group_by: :region, ...}}]
      iex> ChartDataCollector.convert_aggregations_to_charts(state, configs)
      %{sales: %{name: :sales, svg: "...", embedded_code: "...", ...}}
  """
  @spec convert_aggregations_to_charts(map(), [chart_config()]) :: %{atom() => map()}
  def convert_aggregations_to_charts(grouped_aggregation_state, chart_configs) do
    chart_configs
    |> Enum.map(fn config ->
      {config.name, generate_chart_from_aggregation(grouped_aggregation_state, config)}
    end)
    |> Map.new()
  end

  # Private Functions

  defp is_chart_element?(%Chart{}), do: true
  defp is_chart_element?(_), do: false

  defp parse_chart_config(%Chart{} = chart) do
    case parse_data_source(chart.data_source) do
      {:aggregation, aggregation_ref} ->
        %{
          name: chart.name,
          chart_type: chart.chart_type,
          aggregation_ref: aggregation_ref,
          chart_config: chart.config || %{},
          embed_options: chart.embed_options || %{}
        }

      :records ->
        # Full-record chart - not compatible with streaming
        nil

      :unknown ->
        # Unknown data source format
        Logger.warning("Chart #{chart.name} has unknown data source format, skipping")
        nil
    end
  end

  # Parse data_source to determine if it's an aggregation reference
  defp parse_data_source(data_source) do
    # Check if data_source is an Ash.Expr struct
    case data_source do
      %{__struct__: Ash.Expr, expression: expr} ->
        parse_expression(expr)

      # Static data or list - not aggregation
      data when is_list(data) ->
        :records

      # Tuple format (from test): {:aggregation, nil, [...]}
      data when is_tuple(data) ->
        parse_expression(data)

      # Map could be aggregation call
      data when is_map(data) ->
        parse_expression(data)

      _ ->
        :unknown
    end
  end

  # Parse expression to extract aggregation reference
  # Format: aggregation(:region, :sum, :amount)
  defp parse_expression({:aggregation, _, [group_by, agg_type, field]}) do
    {:aggregation,
     %{
       group_by: group_by,
       aggregation_type: agg_type,
       field: field
     }}
  end

  # Format: aggregation(:region, :count)
  defp parse_expression({:aggregation, _, [group_by, agg_type]}) do
    {:aggregation,
     %{
       group_by: group_by,
       aggregation_type: agg_type,
       field: nil
     }}
  end

  # :records reference
  defp parse_expression(:records), do: :records

  # Other expressions
  defp parse_expression(_), do: :unknown

  defp generate_chart_from_aggregation(grouped_aggregation_state, config) do
    # Extract aggregation data
    group_key = normalize_group_key(config.aggregation_ref.group_by)

    # Use with clause for clean error handling
    with {:get_data, group_data} when not is_nil(group_data) <-
           {:get_data, Map.get(grouped_aggregation_state, group_key)},
         chart_data <- convert_to_chart_format(group_data, config),
         {:ok, svg} <- Charts.generate(config.chart_type, chart_data, config.chart_config),
         embed_opts = Map.to_list(config.embed_options),
         {:ok, embedded_code} <- ChartEmbedder.embed(svg, embed_opts) do
      %{
        name: config.name,
        chart_type: config.chart_type,
        svg: svg,
        embedded_code: embedded_code,
        error: nil
      }
    else
      {:get_data, nil} ->
        Logger.debug("Aggregation not found for chart #{config.name}")
        generate_error_placeholder(config.name, :aggregation_not_found)

      {:error, reason} ->
        Logger.debug("Chart processing failed for #{config.name}: #{inspect(reason)}")
        Logger.error("Chart processing failed for chart: #{config.name}")
        generate_error_placeholder(config.name, reason)

      unexpected ->
        Logger.debug("Unexpected result in chart generation for #{config.name}: #{inspect(unexpected)}")
        Logger.error("Unexpected result in chart generation for chart: #{config.name}")
        generate_error_placeholder(config.name, {:unexpected_result, unexpected})
    end
  end

  defp normalize_group_key(group_by) when is_list(group_by), do: group_by
  defp normalize_group_key(group_by) when is_atom(group_by), do: [group_by]

  defp convert_to_chart_format(group_data, config) do
    %{
      group_by: group_key,
      aggregation_type: agg_type,
      field: field
    } = config.aggregation_ref

    # Convert map of {group_value => aggregation_state} to list of chart data points
    group_data
    |> Enum.map(fn {group_value, agg_state} ->
      # Extract the specific aggregation value
      value = extract_aggregation_value(agg_state, agg_type, field)

      # Format based on chart type
      format_chart_data_point(group_value, value, config.chart_type, group_key)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&sort_key/1)
  end

  defp extract_aggregation_value(agg_state, :sum, field) do
    get_in(agg_state, [:sum, field]) || 0
  end

  defp extract_aggregation_value(agg_state, :count, _field) do
    Map.get(agg_state, :count, 0)
  end

  defp extract_aggregation_value(agg_state, :avg, field) do
    # Compute average from sum and count
    sum = get_in(agg_state, [:avg, :sum, field]) || 0
    count = get_in(agg_state, [:avg, :count]) || 1
    if count > 0, do: sum / count, else: 0
  end

  defp extract_aggregation_value(agg_state, :min, field) do
    get_in(agg_state, [:min, field])
  end

  defp extract_aggregation_value(agg_state, :max, field) do
    get_in(agg_state, [:max, field])
  end

  defp extract_aggregation_value(_agg_state, _type, _field), do: 0

  # Format data point based on chart type
  defp format_chart_data_point(group_value, value, :bar, _group_key) do
    %{category: format_group_value(group_value), value: value}
  end

  defp format_chart_data_point(group_value, value, :pie, _group_key) do
    %{label: format_group_value(group_value), value: value}
  end

  defp format_chart_data_point(group_value, value, :line, _group_key) do
    %{x: format_group_value(group_value), y: value}
  end

  defp format_chart_data_point(group_value, value, :area, _group_key) do
    %{x: format_group_value(group_value), y: value}
  end

  defp format_chart_data_point(_group_value, _value, :scatter, _group_key) do
    # Scatter plots need x,y pairs - not suitable for single-value aggregations
    nil
  end

  # Convert group value to string for chart labels
  defp format_group_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&to_string/1)
    |> Enum.join(" - ")
  end

  defp format_group_value(value), do: to_string(value)

  # Sort key for consistent ordering
  defp sort_key(%{category: cat}), do: cat
  defp sort_key(%{label: label}), do: label
  defp sort_key(%{x: x}), do: x
  defp sort_key(_), do: ""

  defp generate_error_placeholder(chart_name, error) do
    error_text = "Chart Error: #{chart_name}\n\nAggregation data not available"

    embedded_code = """
    #block(
      width: 100%,
      height: 200pt,
      fill: rgb(255, 230, 230),
      stroke: 1pt + rgb(200, 0, 0),
      radius: 4pt,
      inset: 10pt
    )[
      #text(size: 12pt, weight: "bold", fill: rgb(150, 0, 0))[#{error_text}]
    ]
    """

    %{
      name: chart_name,
      chart_type: :bar,
      svg: nil,
      embedded_code: embedded_code,
      error: error
    }
  end
end
