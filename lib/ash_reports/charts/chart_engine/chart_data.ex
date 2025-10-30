defmodule AshReports.ChartEngine.ChartData do
  @moduledoc """
  Data structure for processed chart data in AshReports Phase 5.1.

  Represents chart data in a normalized format suitable for various chart
  providers while maintaining metadata for internationalization and
  interactive features.
  """

  @type data_type ::
          :numeric | :categorical | :coordinate_pairs | :multi_series | :time_series | :mixed
  @type format_type :: :raw | :aggregated | :statistical | :normalized

  defstruct [
    # Data content
    raw_data: [],
    processed_data: [],
    labels: [],
    datasets: [],

    # Rendered output
    svg: nil,

    # Data characteristics
    data_type: :numeric,
    format_type: :raw,
    value_count: 0,
    series_count: 1,

    # Statistical properties
    min_value: nil,
    max_value: nil,
    average_value: nil,
    median_value: nil,
    std_deviation: nil,

    # Time series properties
    time_range: nil,
    time_interval: nil,
    has_gaps: false,

    # Internationalization
    locale: "en",
    text_direction: "ltr",
    number_format: nil,
    date_format: nil,

    # Interactive features
    filterable_fields: [],
    sortable_fields: [],
    drill_down_fields: [],

    # Performance metadata
    processing_time_ms: nil,
    cache_key: nil,
    last_updated: nil,

    # Validation
    errors: [],
    warnings: [],

    # Metadata
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          raw_data: list() | map(),
          processed_data: list(),
          labels: list(),
          datasets: list(),
          data_type: data_type(),
          format_type: format_type(),
          value_count: integer(),
          series_count: integer(),
          min_value: number() | nil,
          max_value: number() | nil,
          average_value: number() | nil,
          median_value: number() | nil,
          std_deviation: number() | nil,
          time_range: {DateTime.t(), DateTime.t()} | nil,
          time_interval: atom() | nil,
          has_gaps: boolean(),
          locale: String.t(),
          text_direction: String.t(),
          number_format: String.t() | nil,
          date_format: String.t() | nil,
          filterable_fields: list(),
          sortable_fields: list(),
          drill_down_fields: list(),
          processing_time_ms: number() | nil,
          cache_key: String.t() | nil,
          last_updated: DateTime.t() | nil,
          errors: list(),
          warnings: list()
        }

  @doc """
  Create a new ChartData structure from raw data.

  ## Examples

      # Numeric series data
      data = ChartData.new([1, 2, 3, 4, 5])
      
      # Coordinate pairs
      data = ChartData.new([{1, 10}, {2, 20}, {3, 15}])
      
      # Multi-series data
      data = ChartData.new(%{
        "Series A" => [1, 2, 3],
        "Series B" => [4, 5, 6]
      })

  """
  @spec new(list() | map(), keyword()) :: t()
  def new(raw_data, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    chart_data = %__MODULE__{
      raw_data: raw_data,
      last_updated: DateTime.utc_now(),
      locale: Keyword.get(opts, :locale, "en"),
      text_direction: Keyword.get(opts, :text_direction, "ltr")
    }

    chart_data =
      chart_data
      |> process_raw_data()
      |> calculate_statistics()
      |> detect_time_series()
      |> generate_cache_key()

    processing_time = System.monotonic_time(:millisecond) - start_time
    %{chart_data | processing_time_ms: processing_time}
  end

  @doc """
  Convert chart data to Chart.js compatible format.
  """
  @spec to_chartjs_format(t()) :: map()
  def to_chartjs_format(%__MODULE__{} = chart_data) do
    %{
      labels: chart_data.labels,
      datasets: chart_data.datasets
    }
  end

  @doc """
  Convert chart data to D3.js compatible format.
  """
  @spec to_d3_format(t()) :: list()
  def to_d3_format(%__MODULE__{} = chart_data) do
    chart_data.processed_data
  end

  @doc """
  Convert chart data to Plotly compatible format.
  """
  @spec to_plotly_format(t()) :: map()
  def to_plotly_format(%__MODULE__{} = chart_data) do
    case chart_data.data_type do
      :multi_series ->
        chart_data.datasets
        |> Enum.map(fn dataset ->
          %{
            x: Enum.map(dataset.data, & &1.x),
            y: Enum.map(dataset.data, & &1.y),
            name: dataset.label,
            type: "scatter"
          }
        end)

      _ ->
        [
          %{
            x: Enum.map(chart_data.processed_data, & &1.x),
            y: Enum.map(chart_data.processed_data, & &1.y),
            type: "scatter"
          }
        ]
    end
  end

  @doc """
  Apply statistical aggregation to the chart data.
  """
  @spec aggregate(t(), atom()) :: t()
  def aggregate(%__MODULE__{} = chart_data, aggregation_type) do
    aggregated_data =
      case aggregation_type do
        :sum -> aggregate_sum(chart_data.processed_data)
        :average -> aggregate_average(chart_data.processed_data)
        :count -> aggregate_count(chart_data.processed_data)
        :min -> aggregate_min(chart_data.processed_data)
        :max -> aggregate_max(chart_data.processed_data)
        _ -> chart_data.processed_data
      end

    %{chart_data | processed_data: aggregated_data, format_type: :aggregated}
    |> calculate_statistics()
  end

  @doc """
  Filter chart data based on provided criteria.
  """
  @spec filter(t(), map()) :: t()
  def filter(%__MODULE__{} = chart_data, criteria) when is_map(criteria) do
    filtered_data =
      chart_data.processed_data
      |> Enum.filter(fn data_point ->
        Enum.all?(criteria, fn {field, value} ->
          Map.get(data_point, field) == value
        end)
      end)

    %{chart_data | processed_data: filtered_data, value_count: length(filtered_data)}
    |> calculate_statistics()
  end

  @doc """
  Sort chart data by specified field and direction.
  """
  @spec sort(t(), atom(), :asc | :desc) :: t()
  def sort(%__MODULE__{} = chart_data, field, direction \\ :asc) do
    sorted_data =
      case direction do
        :asc -> Enum.sort_by(chart_data.processed_data, &Map.get(&1, field))
        :desc -> Enum.sort_by(chart_data.processed_data, &Map.get(&1, field), :desc)
      end

    %{chart_data | processed_data: sorted_data}
  end

  @doc """
  Add real-time update capability to chart data.
  """
  @spec enable_real_time(t(), keyword()) :: t()
  def enable_real_time(%__MODULE__{} = chart_data, _opts \\ []) do
    %{
      chart_data
      | last_updated: DateTime.utc_now(),
        cache_key: generate_realtime_cache_key(chart_data)
    }
  end

  # Private functions for data processing

  defp process_raw_data(%__MODULE__{raw_data: raw_data} = chart_data) do
    case raw_data do
      data when is_list(data) -> process_list_data(chart_data, data)
      data when is_map(data) -> process_map_data(chart_data, data)
      _ -> %{chart_data | errors: ["Invalid raw data format" | chart_data.errors]}
    end
  end

  defp process_list_data(chart_data, data) do
    processed =
      data
      |> Enum.with_index()
      |> Enum.map(fn
        {{x, y}, idx} -> %{x: x, y: y, index: idx}
        {[x, y], idx} -> %{x: x, y: y, index: idx}
        {value, idx} when is_number(value) -> %{x: idx, y: value, index: idx}
        {value, idx} -> %{x: to_string(value), y: 1, index: idx}
      end)

    labels = Enum.map(processed, & &1.x)

    datasets = [
      %{
        label: "Data Series",
        data: processed,
        backgroundColor: generate_colors(1) |> List.first(),
        borderColor: generate_colors(1) |> List.first()
      }
    ]

    %{
      chart_data
      | processed_data: processed,
        labels: labels,
        datasets: datasets,
        data_type: detect_list_data_type(data),
        value_count: length(processed),
        series_count: 1
    }
  end

  defp process_map_data(chart_data, data) do
    {labels, datasets} =
      data
      |> Enum.with_index()
      |> Enum.map(fn {{series_name, series_data}, idx} ->
        process_single_series(series_name, series_data, idx, map_size(data))
      end)
      |> Enum.unzip()

    # Combine labels from all series
    combined_labels = labels |> List.flatten() |> Enum.uniq()
    all_processed = datasets |> Enum.flat_map(fn dataset -> dataset.data end)

    %{
      chart_data
      | processed_data: all_processed,
        labels: combined_labels,
        datasets: datasets,
        data_type: :multi_series,
        value_count: length(all_processed),
        series_count: length(datasets)
    }
  end

  defp process_single_series(series_name, series_data, idx, total_series) do
    processed_series =
      series_data
      |> Enum.with_index()
      |> Enum.map(fn {value, point_idx} ->
        normalize_data_point(value, point_idx)
      end)

    colors = generate_colors(total_series)

    dataset = %{
      label: to_string(series_name),
      data: processed_series,
      backgroundColor: Enum.at(colors, idx),
      borderColor: Enum.at(colors, idx),
      fill: false
    }

    {Enum.map(processed_series, & &1.x), dataset}
  end

  defp normalize_data_point(value, point_idx) do
    case value do
      {x, y} -> %{x: x, y: y}
      [x, y] -> %{x: x, y: y}
      num when is_number(num) -> %{x: point_idx, y: num}
      str -> %{x: point_idx, y: to_string(str)}
    end
  end

  defp detect_list_data_type(data) do
    case data do
      [] -> :empty
      [first | _] when is_number(first) -> :numeric
      [first | _] when is_binary(first) -> :categorical
      [{_, _} | _] -> :coordinate_pairs
      [[_, _] | _] -> :coordinate_pairs
      _ -> :mixed
    end
  end

  defp calculate_statistics(%__MODULE__{processed_data: processed_data} = chart_data) do
    numeric_values =
      processed_data
      |> Enum.map(& &1.y)
      |> Enum.filter(&is_number/1)

    case numeric_values do
      [] ->
        chart_data

      values ->
        %{
          chart_data
          | min_value: Enum.min(values),
            max_value: Enum.max(values),
            average_value: Enum.sum(values) / length(values),
            median_value: calculate_median(values),
            std_deviation: calculate_std_deviation(values)
        }
    end
  end

  defp detect_time_series(%__MODULE__{processed_data: processed_data} = chart_data) do
    x_values = Enum.map(processed_data, & &1.x)

    time_series_detected =
      x_values
      |> Enum.any?(fn x ->
        is_binary(x) and String.contains?(x, ["-", "/", ":", "T"])
      end)

    if time_series_detected do
      # Parse time values and calculate range
      parsed_times =
        x_values
        |> Enum.map(&parse_time_value/1)
        |> Enum.filter(& &1)

      case parsed_times do
        [] ->
          chart_data

        times ->
          %{
            chart_data
            | data_type: :time_series,
              time_range: {Enum.min(times), Enum.max(times)},
              time_interval: detect_time_interval(times)
          }
      end
    else
      chart_data
    end
  end

  defp generate_cache_key(%__MODULE__{} = chart_data) do
    data_hash =
      chart_data.raw_data
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    cache_key = "chart_data_#{data_hash}_#{chart_data.locale}"
    %{chart_data | cache_key: cache_key}
  end

  defp generate_realtime_cache_key(chart_data) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "realtime_#{chart_data.cache_key}_#{timestamp}"
  end

  defp calculate_median(values) when is_list(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    case rem(count, 2) do
      0 ->
        # Even number of values
        mid1 = Enum.at(sorted, div(count, 2) - 1)
        mid2 = Enum.at(sorted, div(count, 2))
        (mid1 + mid2) / 2

      1 ->
        # Odd number of values
        Enum.at(sorted, div(count, 2))
    end
  end

  defp calculate_std_deviation(values) when is_list(values) do
    avg = Enum.sum(values) / length(values)

    variance =
      values
      |> Enum.map(fn val -> :math.pow(val - avg, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp parse_time_value(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _} ->
        case Date.from_iso8601(value) do
          {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
          {:error, _} -> nil
        end
    end
  end

  defp parse_time_value(_), do: nil

  defp detect_time_interval(times) when length(times) >= 2 do
    # Calculate differences between consecutive times
    time_diffs =
      times
      |> Enum.sort(DateTime)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1, :second) end)

    # Find the most common interval
    case time_diffs do
      [] ->
        nil

      diffs ->
        avg_diff = Enum.sum(diffs) / length(diffs)

        cond do
          # Less than 1 hour
          avg_diff < 3600 -> :minute
          # Less than 1 day
          avg_diff < 86400 -> :hour
          # Less than 1 week
          avg_diff < 604_800 -> :day
          # Less than 1 month
          avg_diff < 2_592_000 -> :week
          true -> :month
        end
    end
  end

  defp detect_time_interval(_), do: nil

  defp generate_colors(count) do
    # Generate visually distinct colors for multiple series
    base_colors = [
      "#FF6384",
      "#36A2EB",
      "#FFCE56",
      "#4BC0C0",
      "#9966FF",
      "#FF9F40",
      "#FF6384",
      "#C9CBCF"
    ]

    if count <= length(base_colors) do
      Enum.take(base_colors, count)
    else
      # Generate additional colors using HSL
      additional_colors =
        for i <- length(base_colors)..(count - 1) do
          # Golden angle for good distribution
          hue = rem(i * 137, 360)
          "hsl(#{hue}, 70%, 50%)"
        end

      base_colors ++ additional_colors
    end
  end

  # Aggregation functions

  defp aggregate_sum(data) do
    data
    |> Enum.group_by(& &1.x)
    |> Enum.map(fn {x, points} ->
      total_y = points |> Enum.map(& &1.y) |> Enum.filter(&is_number/1) |> Enum.sum()
      %{x: x, y: total_y}
    end)
  end

  defp aggregate_average(data) do
    data
    |> Enum.group_by(& &1.x)
    |> Enum.map(fn {x, points} ->
      numeric_ys = points |> Enum.map(& &1.y) |> Enum.filter(&is_number/1)
      avg_y = if length(numeric_ys) > 0, do: Enum.sum(numeric_ys) / length(numeric_ys), else: 0
      %{x: x, y: avg_y}
    end)
  end

  defp aggregate_count(data) do
    data
    |> Enum.group_by(& &1.x)
    |> Enum.map(fn {x, points} ->
      %{x: x, y: length(points)}
    end)
  end

  defp aggregate_min(data) do
    data
    |> Enum.group_by(& &1.x)
    |> Enum.map(fn {x, points} ->
      numeric_ys = points |> Enum.map(& &1.y) |> Enum.filter(&is_number/1)
      min_y = if length(numeric_ys) > 0, do: Enum.min(numeric_ys), else: 0
      %{x: x, y: min_y}
    end)
  end

  defp aggregate_max(data) do
    data
    |> Enum.group_by(& &1.x)
    |> Enum.map(fn {x, points} ->
      numeric_ys = points |> Enum.map(& &1.y) |> Enum.filter(&is_number/1)
      max_y = if length(numeric_ys) > 0, do: Enum.max(numeric_ys), else: 0
      %{x: x, y: max_y}
    end)
  end
end
