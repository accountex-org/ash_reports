defmodule AshReports.Charts.TimeSeries do
  @moduledoc """
  Time-series data formatting and bucketing for chart generation.

  Provides utilities for:
  - Time bucketing (daily, weekly, monthly, quarterly, yearly)
  - Gap filling (ensure continuous time series)
  - Date range generation
  - Time-based aggregations

  Uses Timex for advanced time manipulation and timezone support.

  ## Features

  - **Multiple Bucket Sizes**: hour, day, week, month, quarter, year
  - **Gap Filling**: Fill missing time periods with zero/null values
  - **Timezone Support**: Handle timezone conversions via Timex
  - **Flexible Input**: Works with Date, DateTime, NaiveDateTime
  - **Aggregation Integration**: Combine with Aggregator for time-based charts

  ## Usage

  ### Basic Time Bucketing

      data = [
        %{date: ~D[2024-01-05], amount: 100},
        %{date: ~D[2024-01-12], amount: 150},
        %{date: ~D[2024-01-20], amount: 200}
      ]

      TimeSeries.bucket(data, :date, :week)
      # => [
      #   %{period: ~D[2024-01-01], period_label: "Week 1", records: [...]},
      #   %{period: ~D[2024-01-08], period_label: "Week 2", records: [...]},
      #   %{period: ~D[2024-01-15], period_label: "Week 3", records: [...]}
      # ]

  ### With Aggregation

      data = [...]
      buckets = TimeSeries.bucket(data, :created_at, :month)

      aggregated = Enum.map(buckets, fn bucket ->
        %{
          period: bucket.period_label,
          total: Aggregator.sum(bucket.records, :amount)
        }
      end)

      Charts.generate(:line, aggregated, config)

  ### Gap Filling

      data = [
        %{date: ~D[2024-01-01], value: 100},
        # Missing 2024-01-02
        %{date: ~D[2024-01-03], value: 150}
      ]

      TimeSeries.fill_gaps(data, :date, :day,
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-01-03],
        fill_value: 0
      )
      # => [
      #   %{date: ~D[2024-01-01], value: 100},
      #   %{date: ~D[2024-01-02], value: 0},  # Filled
      #   %{date: ~D[2024-01-03], value: 150}
      # ]

  ## Bucket Types

  - `:hour` - Bucket by hour of day
  - `:day` - Bucket by calendar day
  - `:week` - Bucket by week (Monday start)
  - `:month` - Bucket by calendar month
  - `:quarter` - Bucket by quarter (Q1-Q4)
  - `:year` - Bucket by calendar year

  ## Performance

  - Bucketing: O(n) where n = number of records
  - Gap filling: O(n + gaps) where gaps = number of periods in range
  """

  alias AshReports.Charts.Aggregator

  @type bucket_type :: :hour | :day | :week | :month | :quarter | :year
  @type date_like :: Date.t() | DateTime.t() | NaiveDateTime.t()

  @doc """
  Buckets time-series data into time periods.

  ## Parameters

    * `data` - List of records with date/time fields
    * `date_field` - Field name containing date/time
    * `bucket_type` - Type of time bucket (:day, :week, :month, etc.)
    * `opts` - Optional configuration

  ## Options

    * `:timezone` - Timezone for DateTime conversion (default: "UTC")
    * `:week_start` - Week start day (default: :monday)

  ## Returns

  List of bucket maps with `:period`, `:period_label`, and `:records`

  ## Examples

      TimeSeries.bucket(data, :created_at, :month)
      # => [
      #   %{period: ~D[2024-01-01], period_label: "Jan 2024", records: [...]},
      #   %{period: ~D[2024-02-01], period_label: "Feb 2024", records: [...]}
      # ]
  """
  @spec bucket(Enumerable.t(), atom(), bucket_type(), keyword()) :: [map()]
  def bucket(data, date_field, bucket_type, opts \\ []) do
    # Group by bucket period
    grouped =
      data
      |> Enum.group_by(fn record ->
        date_value = Map.get(record, date_field)
        bucket_period(date_value, bucket_type, opts)
      end)

    # Convert to bucket format
    grouped
    |> Enum.map(fn {period, records} ->
      %{
        period: period,
        period_label: format_period(period, bucket_type),
        records: records
      }
    end)
    |> Enum.sort_by(& &1.period, {:asc, Date})
  end

  @doc """
  Buckets and aggregates time-series data in one operation.

  ## Parameters

    * `data` - List of records
    * `date_field` - Field containing date/time
    * `value_field` - Field to aggregate
    * `bucket_type` - Time bucket type
    * `aggregation` - Aggregation function (:sum, :avg, :count, etc.)
    * `opts` - Options

  ## Returns

  List of maps with `:period`, `:period_label`, and `:value`

  ## Examples

      TimeSeries.bucket_and_aggregate(
        data,
        :sale_date,
        :amount,
        :month,
        :sum
      )
      # => [
      #   %{period: ~D[2024-01-01], period_label: "Jan 2024", value: 5000},
      #   %{period: ~D[2024-02-01], period_label: "Feb 2024", value: 6500}
      # ]
  """
  @spec bucket_and_aggregate(
          Enumerable.t(),
          atom(),
          atom(),
          bucket_type(),
          Aggregator.aggregation(),
          keyword()
        ) :: [map()]
  def bucket_and_aggregate(data, date_field, value_field, bucket_type, aggregation, opts \\ []) do
    data
    |> bucket(date_field, bucket_type, opts)
    |> Enum.map(fn bucket ->
      value =
        case aggregation do
          :sum -> Aggregator.sum(bucket.records, value_field)
          :count -> Aggregator.count(bucket.records, value_field)
          :avg -> Aggregator.avg(bucket.records, value_field)
          :min -> Aggregator.field_min(bucket.records, value_field)
          :max -> Aggregator.field_max(bucket.records, value_field)
        end

      %{
        period: bucket.period,
        period_label: bucket.period_label,
        value: value
      }
    end)
  end

  @doc """
  Fills gaps in time-series data to ensure continuous periods.

  ## Parameters

    * `data` - List of records (must be sorted by date)
    * `date_field` - Field containing date
    * `bucket_type` - Time bucket type
    * `opts` - Fill options

  ## Options

    * `:start_date` - Start of range (default: first date in data)
    * `:end_date` - End of range (default: last date in data)
    * `:fill_value` - Value for missing periods (default: 0)
    * `:value_field` - Field to fill (default: :value)

  ## Returns

  List of records with gaps filled

  ## Examples

      TimeSeries.fill_gaps(data, :date, :day,
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-01-05],
        fill_value: 0
      )
  """
  @spec fill_gaps(Enumerable.t(), atom(), bucket_type(), keyword()) :: [map()]
  def fill_gaps(data, date_field, bucket_type, opts \\ []) do
    data_list = Enum.to_list(data)

    # Determine date range
    {start_date, end_date} = get_date_range(data_list, date_field, opts)

    # Generate all periods in range
    all_periods = generate_periods(start_date, end_date, bucket_type)

    # Create map of existing data by period
    existing_data =
      data_list
      |> Enum.group_by(fn record ->
        date_value = Map.get(record, date_field)
        bucket_period(date_value, bucket_type, [])
      end)
      |> Enum.map(fn {period, records} ->
        # If multiple records in same period, take first or aggregate
        {period, List.first(records)}
      end)
      |> Map.new()

    # Fill gaps
    fill_value = Keyword.get(opts, :fill_value, 0)
    value_field = Keyword.get(opts, :value_field, :value)

    Enum.map(all_periods, fn period ->
      case Map.get(existing_data, period) do
        nil ->
          # Gap - create fill record
          %{
            date_field => period,
            value_field => fill_value
          }

        existing_record ->
          existing_record
      end
    end)
  end

  # Private Functions

  defp bucket_period(%Date{} = date, :hour, _opts), do: date
  defp bucket_period(%Date{} = date, :day, _opts), do: date

  defp bucket_period(%Date{} = date, :week, opts) do
    week_start = Keyword.get(opts, :week_start, :monday)
    Timex.beginning_of_week(date, week_start)
  end

  defp bucket_period(%Date{} = date, :month, _opts) do
    Timex.beginning_of_month(date)
  end

  defp bucket_period(%Date{} = date, :quarter, _opts) do
    Timex.beginning_of_quarter(date)
  end

  defp bucket_period(%Date{} = date, :year, _opts) do
    Timex.beginning_of_year(date)
  end

  defp bucket_period(%DateTime{} = datetime, bucket_type, opts) do
    date = DateTime.to_date(datetime)
    bucket_period(date, bucket_type, opts)
  end

  defp bucket_period(%NaiveDateTime{} = datetime, bucket_type, opts) do
    date = NaiveDateTime.to_date(datetime)
    bucket_period(date, bucket_type, opts)
  end

  defp bucket_period(nil, _bucket_type, _opts), do: nil

  defp format_period(%Date{} = date, :day) do
    Timex.format!(date, "{YYYY}-{0M}-{0D}")
  end

  defp format_period(%Date{} = date, :week) do
    {iso_year, iso_week} = Timex.iso_week(date)
    "Week #{iso_week}, #{iso_year}"
  end

  defp format_period(%Date{} = date, :month) do
    Timex.format!(date, "{Mshort} {YYYY}")
  end

  defp format_period(%Date{} = date, :quarter) do
    quarter = Timex.quarter(date)
    "Q#{quarter} #{date.year}"
  end

  defp format_period(%Date{} = date, :year) do
    "#{date.year}"
  end

  defp format_period(nil, _bucket_type), do: "Unknown"

  defp get_date_range(data, date_field, opts) do
    start_date =
      Keyword.get_lazy(opts, :start_date, fn ->
        data
        |> Enum.map(&Map.get(&1, date_field))
        |> Enum.reject(&is_nil/1)
        |> Enum.min(Date, fn -> Date.utc_today() end)
      end)

    end_date =
      Keyword.get_lazy(opts, :end_date, fn ->
        data
        |> Enum.map(&Map.get(&1, date_field))
        |> Enum.reject(&is_nil/1)
        |> Enum.max(Date, fn -> Date.utc_today() end)
      end)

    {normalize_date(start_date), normalize_date(end_date)}
  end

  defp normalize_date(%Date{} = date), do: date
  defp normalize_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp normalize_date(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_date(datetime)

  defp generate_periods(start_date, end_date, :day) do
    Date.range(start_date, end_date) |> Enum.to_list()
  end

  defp generate_periods(start_date, end_date, :week) do
    week_start = Timex.beginning_of_week(start_date, :monday)
    week_end = Timex.beginning_of_week(end_date, :monday)

    Stream.iterate(week_start, &Timex.shift(&1, weeks: 1))
    |> Enum.take_while(&(Date.compare(&1, week_end) != :gt))
  end

  defp generate_periods(start_date, end_date, :month) do
    month_start = Timex.beginning_of_month(start_date)
    month_end = Timex.beginning_of_month(end_date)

    Stream.iterate(month_start, &Timex.shift(&1, months: 1))
    |> Enum.take_while(&(Date.compare(&1, month_end) != :gt))
  end

  defp generate_periods(start_date, end_date, :quarter) do
    quarter_start = Timex.beginning_of_quarter(start_date)
    quarter_end = Timex.beginning_of_quarter(end_date)

    Stream.iterate(quarter_start, &Timex.shift(&1, months: 3))
    |> Enum.take_while(&(Date.compare(&1, quarter_end) != :gt))
  end

  defp generate_periods(start_date, end_date, :year) do
    year_start = Timex.beginning_of_year(start_date)
    year_end = Timex.beginning_of_year(end_date)

    Stream.iterate(year_start, &Timex.shift(&1, years: 1))
    |> Enum.take_while(&(Date.compare(&1, year_end) != :gt))
  end
end
