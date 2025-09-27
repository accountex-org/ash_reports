defmodule AshReports.InteractiveEngine do
  @moduledoc """
  Interactive data operations engine for AshReports Phase 5.1.

  Provides advanced data manipulation capabilities including filtering, sorting,
  pivot tables, statistical analysis, and real-time data processing for
  interactive reporting and visualization.

  ## Features

  - **Dynamic Filtering**: Real-time data filtering with multiple criteria
  - **Advanced Sorting**: Multi-field sorting with custom comparators
  - **Pivot Operations**: Cross-tabulation and pivot table generation
  - **Statistical Analysis**: Correlation, regression, trend analysis using Nx
  - **Real-time Processing**: Live data updates and streaming capabilities
  - **Performance Optimization**: Efficient processing with lazy evaluation

  ## Usage Examples

  ### Basic Filtering

      filter_criteria = %{
        region: "North America",
        status: :active,
        created_after: ~D[2024-01-01]
      }
      
      filtered_data = InteractiveEngine.filter(data, filter_criteria)

  ### Pivot Table Generation

      pivot_config = %{
        rows: [:region, :status],
        columns: [:month],
        values: [:revenue],
        aggregation: :sum
      }
      
      pivot_table = InteractiveEngine.create_pivot_table(data, pivot_config)

  ### Statistical Analysis

      analysis = InteractiveEngine.analyze_correlation(data, [:revenue, :profit])
      trend = InteractiveEngine.calculate_trend(time_series_data, :linear)

  """

  alias AshReports.RenderContext
  alias AshReports.InteractiveEngine.{FilterProcessor, PivotProcessor, StatisticalAnalyzer}

  @type filter_criteria :: map()
  @type sort_spec :: {atom(), :asc | :desc}
  @type pivot_config :: map()
  @type analysis_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Apply dynamic filtering to dataset based on provided criteria.

  ## Examples

      criteria = %{
        region: "Europe", 
        amount: {:greater_than, 1000},
        date: {:between, ~D[2024-01-01], ~D[2024-12-31]}
      }
      
      filtered = InteractiveEngine.filter(data, criteria, context)

  """
  @spec filter(list(), filter_criteria(), RenderContext.t()) ::
          {:ok, list()} | {:error, String.t()}
  def filter(data, criteria, %RenderContext{} = context)
      when is_list(data) and is_map(criteria) do
    start_time = System.monotonic_time(:microsecond)

    try do
      filtered_data = FilterProcessor.apply_filters(data, criteria, context)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:filter, processing_time)

      {:ok, filtered_data}
    rescue
      error -> {:error, "Filtering failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Sort data by multiple fields with custom ordering.

  ## Examples

      sort_specs = [
        {:revenue, :desc},
        {:name, :asc},
        {:created_at, :desc}
      ]
      
      sorted = InteractiveEngine.sort(data, sort_specs, context)

  """
  @spec sort(list(), [sort_spec()], RenderContext.t()) :: {:ok, list()} | {:error, String.t()}
  def sort(data, sort_specs, %RenderContext{} = context)
      when is_list(data) and is_list(sort_specs) do
    start_time = System.monotonic_time(:microsecond)

    try do
      sorted_data =
        Enum.sort(data, fn item1, item2 ->
          compare_items(item1, item2, sort_specs, context)
        end)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:sort, processing_time)

      {:ok, sorted_data}
    rescue
      error -> {:error, "Sorting failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Create a pivot table from data with specified configuration.

  ## Examples

      config = %{
        rows: [:region, :category],
        columns: [:quarter],
        values: [:revenue, :profit],
        aggregation: :sum,
        show_totals: true
      }
      
      pivot = InteractiveEngine.create_pivot_table(data, config, context)

  """
  @spec create_pivot_table(list(), pivot_config(), RenderContext.t()) :: analysis_result()
  def create_pivot_table(data, config, %RenderContext{} = context)
      when is_list(data) and is_map(config) do
    start_time = System.monotonic_time(:microsecond)

    try do
      pivot_result = PivotProcessor.generate_pivot_table(data, config, context)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:pivot, processing_time)

      {:ok, pivot_result}
    rescue
      error -> {:error, "Pivot table generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Perform statistical analysis on dataset.

  ## Examples

      # Correlation analysis
      correlation = InteractiveEngine.analyze_correlation(data, [:x, :y], context)
      
      # Regression analysis
      regression = InteractiveEngine.calculate_regression(data, :x, :y, :linear, context)
      
      # Trend analysis
      trend = InteractiveEngine.calculate_trend(time_series_data, :polynomial, context)

  """
  @spec analyze_correlation(list(), [atom()], RenderContext.t()) :: analysis_result()
  def analyze_correlation(data, fields, %RenderContext{} = context)
      when is_list(data) and is_list(fields) do
    start_time = System.monotonic_time(:microsecond)

    try do
      correlation_result = StatisticalAnalyzer.calculate_correlation(data, fields, context)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:correlation, processing_time)

      {:ok, correlation_result}
    rescue
      error -> {:error, "Correlation analysis failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Calculate regression analysis for predictive modeling.
  """
  @spec calculate_regression(list(), atom(), atom(), atom(), RenderContext.t()) ::
          analysis_result()
  def calculate_regression(data, x_field, y_field, regression_type, %RenderContext{} = context) do
    start_time = System.monotonic_time(:microsecond)

    try do
      regression_result =
        StatisticalAnalyzer.calculate_regression(data, x_field, y_field, regression_type, context)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:regression, processing_time)

      {:ok, regression_result}
    rescue
      error -> {:error, "Regression analysis failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Calculate trend analysis for time series data.
  """
  @spec calculate_trend(list(), atom(), RenderContext.t()) :: analysis_result()
  def calculate_trend(time_series_data, trend_type, %RenderContext{} = context) do
    start_time = System.monotonic_time(:microsecond)

    try do
      trend_result = StatisticalAnalyzer.calculate_trend(time_series_data, trend_type, context)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:trend, processing_time)

      {:ok, trend_result}
    rescue
      error -> {:error, "Trend analysis failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Set up real-time data streaming for live updates.

  ## Examples

      stream_config = %{
        data_source: :database_query,
        update_interval: 5000,
        max_history: 1000,
        filters: existing_filters
      }
      
      stream = InteractiveEngine.setup_real_time_stream(stream_config, context)

  """
  @spec setup_real_time_stream(map(), RenderContext.t()) :: {:ok, pid()} | {:error, String.t()}
  def setup_real_time_stream(stream_config, %RenderContext{} = context) do
    stream_pid =
      GenServer.start_link(
        AshReports.InteractiveEngine.StreamProcessor,
        {stream_config, context},
        name: {:global, "stream_#{generate_stream_id()}"}
      )

    case stream_pid do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, "Stream setup failed: #{inspect(reason)}"}
    end
  rescue
    error -> {:error, "Real-time stream setup failed: #{Exception.message(error)}"}
  end

  @doc """
  Aggregate data with various statistical functions.

  ## Examples

      # Group by region and sum revenue
      aggregated = InteractiveEngine.aggregate(data, :region, :revenue, :sum, context)
      
      # Calculate average with multiple grouping fields
      aggregated = InteractiveEngine.aggregate(data, [:region, :category], :profit, :average, context)

  """
  @spec aggregate(list(), atom() | [atom()], atom(), atom(), RenderContext.t()) ::
          {:ok, list()} | {:error, String.t()}
  def aggregate(data, group_fields, value_field, aggregation_func, %RenderContext{} = _context) do
    start_time = System.monotonic_time(:microsecond)

    try do
      group_fields = List.wrap(group_fields)

      aggregated_data =
        data
        |> Enum.group_by(fn item ->
          Enum.map(group_fields, &Map.get(item, &1))
        end)
        |> Enum.map(fn {group_keys, group_items} ->
          process_aggregation_group(
            group_keys,
            group_items,
            group_fields,
            value_field,
            aggregation_func
          )
        end)

      processing_time = System.monotonic_time(:microsecond) - start_time
      record_operation_time(:aggregate, processing_time)

      {:ok, aggregated_data}
    rescue
      error -> {:error, "Aggregation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Get performance metrics for interactive operations.
  """
  @spec get_performance_metrics() :: map()
  def get_performance_metrics do
    %{
      operation_times: get_operation_times(),
      cache_performance: get_cache_performance(),
      memory_usage: get_memory_usage(),
      concurrent_operations: get_concurrent_operations_count()
    }
  end

  # Private utility functions

  defp compare_items(item1, item2, [{field, direction} | rest], context) do
    val1 = Map.get(item1, field)
    val2 = Map.get(item2, field)

    comparison = compare_field_values(val1, val2, direction, context)

    # If values are equal, continue with next sort field
    if val1 == val2 and length(rest) > 0 do
      compare_items(item1, item2, rest, context)
    else
      comparison
    end
  end

  defp compare_items(_, _, [], _), do: true

  defp compare_field_values(val1, val2, direction, context) do
    case {val1, val2} do
      {v1, v2} when is_number(v1) and is_number(v2) ->
        apply_numeric_sort(v1, v2, direction)

      {v1, v2} when is_binary(v1) and is_binary(v2) ->
        apply_string_sort(v1, v2, direction, context)

      {v1, v2} ->
        apply_mixed_type_sort(v1, v2, direction)
    end
  end

  defp apply_numeric_sort(v1, v2, direction) do
    case direction do
      :asc -> v1 <= v2
      :desc -> v1 >= v2
    end
  end

  defp apply_string_sort(v1, v2, direction, context) do
    case direction do
      :asc -> locale_compare(v1, v2, context.locale) <= 0
      :desc -> locale_compare(v1, v2, context.locale) >= 0
    end
  end

  defp apply_mixed_type_sort(v1, v2, direction) do
    case direction do
      :asc -> inspect(v1) <= inspect(v2)
      :desc -> inspect(v1) >= inspect(v2)
    end
  end

  defp process_aggregation_group(
         group_keys,
         group_items,
         group_fields,
         value_field,
         aggregation_func
       ) do
    values = Enum.map(group_items, &Map.get(&1, value_field)) |> Enum.filter(&is_number/1)

    aggregated_value = calculate_aggregation(values, group_items, aggregation_func)

    # Build result item with group fields and aggregated value
    group_fields
    |> Enum.zip(group_keys)
    |> Map.new()
    |> Map.put(value_field, aggregated_value)
  end

  defp calculate_aggregation(values, group_items, aggregation_func) do
    case aggregation_func do
      :sum -> Enum.sum(values)
      :average -> safe_average(values)
      :count -> length(group_items)
      :min -> safe_min(values)
      :max -> safe_max(values)
      :median -> calculate_median(values)
      :std_dev -> calculate_std_deviation(values)
    end
  end

  defp safe_average([]), do: 0
  defp safe_average(values), do: Enum.sum(values) / length(values)

  defp safe_min([]), do: 0
  defp safe_min(values), do: Enum.min(values)

  defp safe_max([]), do: 0
  defp safe_max(values), do: Enum.max(values)

  defp locale_compare(str1, str2, locale) do
    case locale do
      locale when locale in ["ar", "he"] -> enhanced_string_compare(str1, str2)
      _ -> basic_string_compare(str1, str2)
    end
  end

  defp enhanced_string_compare(str1, str2) do
    # Could be enhanced with locale-specific collation
    basic_string_compare(str1, str2)
  end

  defp basic_string_compare(str1, str2) do
    cond do
      str1 < str2 -> -1
      str1 > str2 -> 1
      true -> 0
    end
  end

  defp calculate_median([]), do: 0

  defp calculate_median(values) when is_list(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    case rem(count, 2) do
      0 ->
        mid1 = Enum.at(sorted, div(count, 2) - 1)
        mid2 = Enum.at(sorted, div(count, 2))
        (mid1 + mid2) / 2

      1 ->
        Enum.at(sorted, div(count, 2))
    end
  end

  defp calculate_std_deviation([]), do: 0

  defp calculate_std_deviation(values) when is_list(values) do
    avg = Enum.sum(values) / length(values)

    variance =
      values
      |> Enum.map(fn val -> :math.pow(val - avg, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp generate_stream_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # Performance monitoring

  defp record_operation_time(operation, time_microseconds) do
    times = :persistent_term.get(:ash_reports_interactive_times, %{})
    operation_times = Map.get(times, operation, [])

    # Keep only last 100 measurements
    updated_times = [time_microseconds | operation_times] |> Enum.take(100)
    updated_map = Map.put(times, operation, updated_times)

    :persistent_term.put(:ash_reports_interactive_times, updated_map)
  end

  defp get_operation_times do
    times = :persistent_term.get(:ash_reports_interactive_times, %{})

    times
    |> Enum.map(fn {operation, time_list} ->
      avg_time = if length(time_list) > 0, do: Enum.sum(time_list) / length(time_list), else: 0

      {operation,
       %{
         average_microseconds: avg_time,
         recent_operations: length(time_list)
       }}
    end)
    |> Map.new()
  end

  defp get_cache_performance do
    :persistent_term.get(:ash_reports_interactive_cache, %{hits: 0, misses: 0, size: 0})
  end

  defp get_memory_usage do
    {memory, _} = :erlang.process_info(self(), :memory)
    memory
  end

  defp get_concurrent_operations_count do
    # Count active GenServer processes for real-time streams
    Process.list()
    |> Enum.count(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          Keyword.get(dict, :"$initial_call") ==
            {AshReports.InteractiveEngine.StreamProcessor, :init, 1}

        _ ->
          false
      end
    end)
  end
end
