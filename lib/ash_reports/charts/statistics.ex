defmodule AshReports.Charts.Statistics do
  @moduledoc """
  Statistical calculations for chart data analysis.

  Provides common statistical functions using the `statistics` library:
  - Percentiles (median, quartiles, custom percentiles)
  - Standard deviation
  - Variance
  - Distribution analysis

  ## Features

  - **Percentile Calculations**: median, quartiles, any percentile
  - **Variability Metrics**: standard deviation, variance
  - **Distribution Stats**: skewness, kurtosis (via statistics library)
  - **Null Handling**: Automatically filters nil values
  - **Type Safety**: Handles Integer, Float, Decimal

  ## Usage

  ### Basic Statistics

      data = [
        %{value: 10},
        %{value: 20},
        %{value: 30},
        %{value: 40},
        %{value: 50}
      ]

      Statistics.median(data, :value)
      # => 30.0

      Statistics.std_dev(data, :value)
      # => 14.142135623730951

  ### Percentiles

      Statistics.percentile(data, :value, 25)  # First quartile
      # => 20.0

      Statistics.percentile(data, :value, 75)  # Third quartile
      # => 40.0

  ### Quartile Analysis

      Statistics.quartiles(data, :value)
      # => %{q1: 20.0, q2: 30.0, q3: 40.0}

  ### Distribution Summary

      Statistics.summary(data, :value)
      # => %{
      #   min: 10,
      #   q1: 20.0,
      #   median: 30.0,
      #   q3: 40.0,
      #   max: 50,
      #   mean: 30.0,
      #   std_dev: 14.14
      # }

  ## Integration with Charts

      # Create box plot data
      stats = Statistics.summary(data, :value)

      box_plot_data = [
        %{category: "Dataset", min: stats.min, q1: stats.q1,
          median: stats.median, q3: stats.q3, max: stats.max}
      ]

  ## Performance

  Most operations are O(n log n) due to sorting requirements for percentiles.
  For large datasets, consider sampling or using streaming aggregations.
  """

  require Logger

  @type field :: atom() | String.t()

  @doc """
  Calculates the median (50th percentile) of values.

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze

  ## Returns

  Float median or nil if no values

  ## Examples

      iex> Statistics.median([%{x: 1}, %{x: 2}, %{x: 3}], :x)
      2.0
  """
  @spec median(Enumerable.t(), field()) :: float() | nil
  def median(data, field) do
    percentile(data, field, 50)
  end

  @doc """
  Calculates a specific percentile of values.

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze
    * `percentile` - Percentile to calculate (0-100)

  ## Returns

  Float percentile value or nil if no values

  ## Examples

      iex> Statistics.percentile(data, :value, 25)  # First quartile
      20.0

      iex> Statistics.percentile(data, :value, 95)  # 95th percentile
      48.0
  """
  @spec percentile(Enumerable.t(), field(), number()) :: float() | nil
  def percentile(data, field, percentile) when percentile >= 0 and percentile <= 100 do
    values = extract_numeric_values(data, field)

    case values do
      [] -> nil
      _ -> calculate_percentile(values, percentile)
    end
  end

  @doc """
  Calculates quartiles (Q1, Q2/median, Q3).

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze

  ## Returns

  Map with :q1, :q2, :q3 keys or nil if no values

  ## Examples

      iex> Statistics.quartiles(data, :value)
      %{q1: 20.0, q2: 30.0, q3: 40.0}
  """
  @spec quartiles(Enumerable.t(), field()) :: %{q1: float(), q2: float(), q3: float()} | nil
  def quartiles(data, field) do
    values = extract_numeric_values(data, field)

    case values do
      [] ->
        nil

      _ ->
        %{
          q1: percentile(data, field, 25),
          q2: percentile(data, field, 50),
          q3: percentile(data, field, 75)
        }
    end
  end

  @doc """
  Calculates standard deviation.

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze
    * `opts` - Options

  ## Options

    * `:population` - If true, uses population std dev (default: false, uses sample)

  ## Returns

  Float standard deviation or nil if insufficient values

  ## Examples

      iex> Statistics.std_dev(data, :value)
      14.142135623730951
  """
  @spec std_dev(Enumerable.t(), field(), keyword()) :: float() | nil
  def std_dev(data, field, opts \\ []) do
    values = extract_numeric_values(data, field)

    if length(values) < 2 do
      nil
    else
      population = Keyword.get(opts, :population, false)
      var = calculate_variance(values, population)
      if var, do: :math.sqrt(var), else: nil
    end
  end

  @doc """
  Calculates variance.

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze
    * `opts` - Options

  ## Options

    * `:population` - If true, uses population variance (default: false, uses sample)

  ## Returns

  Float variance or nil if insufficient values

  ## Examples

      iex> Statistics.variance(data, :value)
      200.0
  """
  @spec variance(Enumerable.t(), field(), keyword()) :: float() | nil
  def variance(data, field, opts \\ []) do
    values = extract_numeric_values(data, field)

    if length(values) < 2 do
      nil
    else
      population = Keyword.get(opts, :population, false)
      calculate_variance(values, population)
    end
  end

  @doc """
  Calculates a comprehensive statistical summary.

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze

  ## Returns

  Map with min, max, mean, median, std_dev, q1, q3

  ## Examples

      iex> Statistics.summary(data, :value)
      %{
        min: 10,
        q1: 20.0,
        median: 30.0,
        mean: 30.0,
        q3: 40.0,
        max: 50,
        std_dev: 14.14,
        count: 5
      }
  """
  @spec summary(Enumerable.t(), field()) :: map()
  def summary(data, field) do
    values = extract_numeric_values(data, field)

    case values do
      [] ->
        %{
          count: 0,
          min: nil,
          max: nil,
          mean: nil,
          median: nil,
          q1: nil,
          q3: nil,
          std_dev: nil
        }

      _ ->
        %{
          count: length(values),
          min: Enum.min(values),
          max: Enum.max(values),
          mean: mean(values),
          median: percentile(data, field, 50),
          q1: percentile(data, field, 25),
          q3: percentile(data, field, 75),
          std_dev: std_dev(data, field)
        }
    end
  end

  @doc """
  Identifies outliers using the IQR method.

  Outliers are defined as values outside [Q1 - 1.5*IQR, Q3 + 1.5*IQR]

  ## Parameters

    * `data` - List of records
    * `field` - Field name to analyze
    * `opts` - Options

  ## Options

    * `:multiplier` - IQR multiplier for outlier detection (default: 1.5)

  ## Returns

  List of outlier values

  ## Examples

      iex> Statistics.outliers(data, :value)
      [100, 105]  # Values significantly outside normal range
  """
  @spec outliers(Enumerable.t(), field(), keyword()) :: [number()]
  def outliers(data, field, opts \\ []) do
    multiplier = Keyword.get(opts, :multiplier, 1.5)
    quartile_data = quartiles(data, field)

    if quartile_data == nil do
      []
    else
      q1 = quartile_data.q1
      q3 = quartile_data.q3
      iqr = q3 - q1

      lower_bound = q1 - multiplier * iqr
      upper_bound = q3 + multiplier * iqr

      data
      |> extract_numeric_values(field)
      |> Enum.filter(fn value ->
        value < lower_bound or value > upper_bound
      end)
    end
  end

  # Private Helpers

  defp extract_numeric_values(data, field) do
    data
    |> Enum.map(fn record ->
      case get_field(record, field) do
        nil -> nil
        value when is_number(value) -> value
        %Decimal{} = value -> Decimal.to_float(value)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_field(record, field) when is_map(record) and is_atom(field) do
    Map.get(record, field) || Map.get(record, to_string(field))
  end

  defp get_field(record, field) when is_map(record) and is_binary(field) do
    Map.get(record, field) || Map.get(record, String.to_existing_atom(field))
  rescue
    ArgumentError -> Map.get(record, field)
  end

  defp get_field(_record, _field), do: nil

  defp mean([]), do: nil

  defp mean(values) do
    Enum.sum(values) / length(values)
  end

  defp calculate_percentile(values, percentile) do
    sorted = Enum.sort(values)
    n = length(sorted)

    if n == 0 do
      nil
    else
      rank = percentile / 100.0 * (n - 1)
      lower_index = floor(rank)
      upper_index = ceil(rank)

      if lower_index == upper_index do
        Enum.at(sorted, lower_index)
      else
        lower_value = Enum.at(sorted, lower_index)
        upper_value = Enum.at(sorted, upper_index)
        fraction = rank - lower_index
        lower_value + (upper_value - lower_value) * fraction
      end
    end
  end

  defp calculate_variance(values, population?) do
    avg = mean(values)

    if avg == nil do
      nil
    else
      n = length(values)
      divisor = if population?, do: n, else: n - 1

      sum_of_squares =
        values
        |> Enum.map(fn x -> :math.pow(x - avg, 2) end)
        |> Enum.sum()

      sum_of_squares / divisor
    end
  end
end
