defmodule AshReports.InteractiveEngine.StatisticalAnalyzer do
  @moduledoc """
  Statistical analysis capabilities for AshReports Phase 5.1.

  Provides essential statistical analysis using native Elixir mathematical operations,
  including correlation analysis, regression modeling, trend detection,
  and descriptive statistics with locale-aware result formatting.

  ## Features

  - **Correlation Analysis**: Pearson, Spearman correlation coefficients
  - **Regression Modeling**: Linear, exponential, logarithmic regression
  - **Trend Analysis**: Time series trend detection and basic forecasting
  - **Statistical Summaries**: Descriptive statistics with quartiles and distribution metrics
  - **Outlier Detection**: IQR and Z-score based outlier identification
  - **Distribution Analysis**: Basic distribution metrics and frequency analysis

  ## Implementation

  Uses native Elixir mathematical operations and the :math module for efficient
  statistical calculations without heavy numerical computing dependencies.
  Designed for reporting server performance with memory-efficient algorithms.
  """

  alias AshReports.RenderContext

  @type regression_type :: :linear | :polynomial | :exponential | :logarithmic
  @type trend_type :: :linear | :polynomial | :seasonal | :exponential
  @type correlation_type :: :pearson | :spearman | :kendall

  @doc """
  Calculate correlation coefficient between specified fields.

  ## Examples

      # Pearson correlation between revenue and profit
      correlation = StatisticalAnalyzer.calculate_correlation(data, [:revenue, :profit], context)
      
      # Spearman correlation for non-linear relationships
      correlation = StatisticalAnalyzer.calculate_correlation(data, [:x, :y], context, :spearman)

  """
  @spec calculate_correlation(list(), [atom()], RenderContext.t(), correlation_type()) :: map()
  def calculate_correlation(
        data,
        fields,
        %RenderContext{} = context,
        correlation_type \\ :pearson
      ) do
    case length(fields) do
      2 -> calculate_bivariate_correlation(data, fields, context, correlation_type)
      n when n > 2 -> calculate_correlation_matrix(data, fields, context, correlation_type)
      _ -> %{error: "At least 2 fields required for correlation analysis"}
    end
  end

  @doc """
  Perform regression analysis for predictive modeling.

  ## Examples

      # Linear regression: profit = f(revenue)
      regression = StatisticalAnalyzer.calculate_regression(data, :revenue, :profit, :linear, context)
      
      # Polynomial regression for complex relationships
      regression = StatisticalAnalyzer.calculate_regression(data, :month, :sales, :polynomial, context)

  """
  @spec calculate_regression(list(), atom(), atom(), regression_type(), RenderContext.t()) ::
          map()
  def calculate_regression(data, x_field, y_field, regression_type, %RenderContext{} = context) do
    x_values = extract_numeric_field(data, x_field)
    y_values = extract_numeric_field(data, y_field)

    case {length(x_values), length(y_values)} do
      {0, _} ->
        %{error: "No numeric data found for field #{x_field}"}

      {_, 0} ->
        %{error: "No numeric data found for field #{y_field}"}

      {x_len, y_len} when x_len != y_len ->
        %{error: "Mismatched data lengths: #{x_len} vs #{y_len}"}

      {len, len} when len < 3 ->
        %{error: "At least 3 data points required for regression"}

      _ ->
        perform_regression_analysis(x_values, y_values, regression_type, context)
    end
  end

  @doc """
  Calculate trend analysis for time series data.

  ## Examples

      # Linear trend analysis
      trend = StatisticalAnalyzer.calculate_trend(time_series, :linear, context)
      
      # Seasonal trend with forecasting
      trend = StatisticalAnalyzer.calculate_trend(time_series, :seasonal, context)

  """
  @spec calculate_trend(list(), trend_type(), RenderContext.t()) :: map()
  def calculate_trend(time_series_data, trend_type, %RenderContext{} = context) do
    case validate_time_series(time_series_data) do
      {:ok, processed_series} ->
        perform_trend_analysis(processed_series, trend_type, context)

      {:error, reason} ->
        %{error: "Trend analysis failed: #{reason}"}
    end
  end

  @doc """
  Generate comprehensive descriptive statistics for a dataset.

  ## Examples

      stats = StatisticalAnalyzer.descriptive_statistics(data, [:revenue, :profit], context)

  """
  @spec descriptive_statistics(list(), [atom()], RenderContext.t()) :: map()
  def descriptive_statistics(data, fields, %RenderContext{} = context) do
    fields
    |> Enum.map(fn field ->
      values = extract_numeric_field(data, field)

      stats =
        case values do
          [] -> %{error: "No numeric data for field #{field}"}
          values -> calculate_field_statistics(values, field, context)
        end

      {field, stats}
    end)
    |> Map.new()
  end

  @doc """
  Detect outliers in dataset using statistical methods.

  ## Examples

      # IQR method for outlier detection
      outliers = StatisticalAnalyzer.detect_outliers(data, :revenue, :iqr, context)
      
      # Z-score method for outlier detection  
      outliers = StatisticalAnalyzer.detect_outliers(data, :profit, :zscore, context)

  """
  @spec detect_outliers(list(), atom(), atom(), RenderContext.t()) :: map()
  def detect_outliers(data, field, method, %RenderContext{} = context) do
    values = extract_numeric_field(data, field)

    case {values, method} do
      {[], _} -> %{error: "No numeric data for outlier detection"}
      {values, :iqr} -> detect_iqr_outliers(data, field, values, context)
      {values, :zscore} -> detect_zscore_outliers(data, field, values, context)
      {values, :modified_zscore} -> detect_modified_zscore_outliers(data, field, values, context)
      {_, unknown_method} -> %{error: "Unknown outlier detection method: #{unknown_method}"}
    end
  end

  # Private analysis functions

  defp calculate_bivariate_correlation(data, [field1, field2], context, correlation_type) do
    values1 = extract_numeric_field(data, field1)
    values2 = extract_numeric_field(data, field2)

    case {length(values1), length(values2)} do
      {0, _} ->
        %{error: "No numeric data for field #{field1}"}

      {_, 0} ->
        %{error: "No numeric data for field #{field2}"}

      {len1, len2} when len1 != len2 ->
        %{error: "Mismatched data lengths"}

      {len, len} when len < 3 ->
        %{error: "At least 3 data points required"}

      {len, len} ->
        coefficient =
          case correlation_type do
            :pearson -> calculate_pearson_correlation(values1, values2)
            :spearman -> calculate_spearman_correlation(values1, values2)
            :kendall -> calculate_kendall_correlation(values1, values2)
          end

        %{
          fields: [field1, field2],
          correlation_type: correlation_type,
          coefficient: coefficient,
          strength: interpret_correlation_strength(coefficient),
          sample_size: len,
          p_value: calculate_correlation_p_value(coefficient, len),
          locale: context.locale
        }
    end
  end

  defp calculate_correlation_matrix(data, fields, context, correlation_type) do
    # Create correlation matrix for multiple fields
    field_combinations = for field1 <- fields, field2 <- fields, do: [field1, field2]

    correlations =
      field_combinations
      |> Enum.map(fn [f1, f2] ->
        if f1 == f2 do
          # Perfect self-correlation
          {{f1, f2}, 1.0}
        else
          result = calculate_bivariate_correlation(data, [f1, f2], context, correlation_type)
          {{f1, f2}, result.coefficient || 0.0}
        end
      end)
      |> Map.new()

    %{
      fields: fields,
      correlation_matrix: correlations,
      correlation_type: correlation_type,
      generated_at: DateTime.utc_now(),
      locale: context.locale
    }
  end

  defp perform_regression_analysis(x_values, y_values, regression_type, context) do
    case regression_type do
      :linear -> calculate_linear_regression(x_values, y_values, context)
      :polynomial -> calculate_polynomial_regression(x_values, y_values, context)
      :exponential -> calculate_exponential_regression(x_values, y_values, context)
      :logarithmic -> calculate_logarithmic_regression(x_values, y_values, context)
    end
  end

  defp calculate_linear_regression(x_values, y_values, context) do
    n = length(x_values)
    sum_x = Enum.sum(x_values)
    sum_y = Enum.sum(y_values)
    sum_xy = x_values |> Enum.zip(y_values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    sum_x_squared = x_values |> Enum.map(&(&1 * &1)) |> Enum.sum()

    # Calculate slope (m) and intercept (b) for y = mx + b
    denominator = n * sum_x_squared - sum_x * sum_x

    if denominator == 0 do
      %{error: "Cannot calculate linear regression: x values have no variance"}
    else
      slope = (n * sum_xy - sum_x * sum_y) / denominator
      intercept = (sum_y - slope * sum_x) / n

      # Calculate R-squared
      y_mean = sum_y / n
      ss_tot = y_values |> Enum.map(fn y -> (y - y_mean) * (y - y_mean) end) |> Enum.sum()

      ss_res =
        x_values
        |> Enum.zip(y_values)
        |> Enum.map(fn {x, y} ->
          predicted_y = slope * x + intercept
          (y - predicted_y) * (y - predicted_y)
        end)
        |> Enum.sum()

      r_squared = if ss_tot == 0, do: 1.0, else: 1 - ss_res / ss_tot

      %{
        type: :linear,
        equation: "y = #{Float.round(slope, 4)}x + #{Float.round(intercept, 4)}",
        slope: slope,
        intercept: intercept,
        r_squared: r_squared,
        sample_size: n,
        correlation_strength: interpret_r_squared(r_squared),
        locale: context.locale,
        generated_at: DateTime.utc_now()
      }
    end
  end

  defp calculate_polynomial_regression(x_values, _y_values, context) do
    # Simple quadratic regression: y = ax² + bx + c
    # This is a basic implementation - could be enhanced with Nx for higher-order polynomials

    if length(x_values) < 4 do
      %{error: "At least 4 data points required for polynomial regression"}
    else
      %{
        type: :polynomial,
        degree: 2,
        equation: "y = ax² + bx + c (simplified implementation)",
        # Placeholder - would need matrix operations for proper calculation
        r_squared: 0.0,
        sample_size: length(x_values),
        note: "Enhanced polynomial regression requires Nx integration",
        locale: context.locale,
        generated_at: DateTime.utc_now()
      }
    end
  end

  defp calculate_exponential_regression(x_values, y_values, context) do
    # Exponential regression: y = a * e^(bx)
    # Transform to linear: ln(y) = ln(a) + bx

    # Check for positive y values (required for logarithm)
    if Enum.any?(y_values, &(&1 <= 0)) do
      %{error: "Exponential regression requires all y values to be positive"}
    else
      ln_y_values = Enum.map(y_values, &:math.log/1)
      linear_result = calculate_linear_regression(x_values, ln_y_values, context)

      case linear_result do
        %{error: _} = error ->
          error

        %{slope: b, intercept: ln_a} ->
          a = :math.exp(ln_a)

          %{
            type: :exponential,
            equation: "y = #{Float.round(a, 4)} * e^(#{Float.round(b, 4)}x)",
            coefficient_a: a,
            coefficient_b: b,
            r_squared: linear_result.r_squared,
            sample_size: length(x_values),
            correlation_strength: interpret_r_squared(linear_result.r_squared),
            locale: context.locale,
            generated_at: DateTime.utc_now()
          }
      end
    end
  end

  defp calculate_logarithmic_regression(x_values, y_values, context) do
    # Logarithmic regression: y = a + b * ln(x)

    # Check for positive x values (required for logarithm)
    if Enum.any?(x_values, &(&1 <= 0)) do
      %{error: "Logarithmic regression requires all x values to be positive"}
    else
      ln_x_values = Enum.map(x_values, &:math.log/1)
      linear_result = calculate_linear_regression(ln_x_values, y_values, context)

      case linear_result do
        %{error: _} = error ->
          error

        %{slope: b, intercept: a} ->
          %{
            type: :logarithmic,
            equation: "y = #{Float.round(a, 4)} + #{Float.round(b, 4)} * ln(x)",
            coefficient_a: a,
            coefficient_b: b,
            r_squared: linear_result.r_squared,
            sample_size: length(x_values),
            correlation_strength: interpret_r_squared(linear_result.r_squared),
            locale: context.locale,
            generated_at: DateTime.utc_now()
          }
      end
    end
  end

  defp perform_trend_analysis(time_series_data, trend_type, context) do
    case trend_type do
      :linear -> calculate_linear_trend(time_series_data, context)
      :polynomial -> calculate_polynomial_trend(time_series_data, context)
      :seasonal -> calculate_seasonal_trend(time_series_data, context)
      :exponential -> calculate_exponential_trend(time_series_data, context)
    end
  end

  defp calculate_linear_trend(time_series_data, context) do
    # Convert time series to numeric for regression
    {x_values, y_values} = time_series_to_numeric(time_series_data)

    case calculate_linear_regression(x_values, y_values, context) do
      %{error: _} = error ->
        error

      regression_result ->
        # Generate future predictions
        last_x = Enum.max(x_values)

        predictions =
          for i <- 1..5 do
            future_x = last_x + i
            future_y = regression_result.slope * future_x + regression_result.intercept
            %{period: i, predicted_value: future_y}
          end

        Map.merge(regression_result, %{
          trend_type: :linear,
          direction: if(regression_result.slope > 0, do: :increasing, else: :decreasing),
          predictions: predictions,
          confidence: regression_result.r_squared
        })
    end
  end

  defp calculate_polynomial_trend(time_series_data, context) do
    # Placeholder for polynomial trend analysis
    # Would require Nx for proper polynomial fitting
    %{
      trend_type: :polynomial,
      note: "Polynomial trend analysis requires Nx integration for proper implementation",
      sample_size: length(time_series_data),
      locale: context.locale,
      generated_at: DateTime.utc_now()
    }
  end

  defp calculate_seasonal_trend(time_series_data, context) do
    # Basic seasonal analysis - detect repeating patterns
    case detect_seasonality(time_series_data) do
      {:ok, seasonal_pattern} ->
        %{
          trend_type: :seasonal,
          seasonal_period: seasonal_pattern.period,
          seasonal_strength: seasonal_pattern.strength,
          base_trend: calculate_linear_trend(time_series_data, context),
          seasonal_components: seasonal_pattern.components,
          locale: context.locale,
          generated_at: DateTime.utc_now()
        }

      {:error, reason} ->
        %{error: "Seasonal analysis failed: #{reason}"}
    end
  end

  defp calculate_exponential_trend(time_series_data, context) do
    {x_values, y_values} = time_series_to_numeric(time_series_data)

    case calculate_exponential_regression(x_values, y_values, context) do
      %{error: _} = error ->
        error

      regression_result ->
        # Generate exponential predictions
        last_x = Enum.max(x_values)

        predictions =
          for i <- 1..5 do
            future_x = last_x + i

            future_y =
              regression_result.coefficient_a *
                :math.exp(regression_result.coefficient_b * future_x)

            %{period: i, predicted_value: future_y}
          end

        Map.merge(regression_result, %{
          trend_type: :exponential,
          growth_rate: regression_result.coefficient_b,
          predictions: predictions,
          confidence: regression_result.r_squared
        })
    end
  end

  # Utility functions

  defp extract_numeric_field(data, field) do
    data
    |> Enum.map(&Map.get(&1, field))
    |> Enum.filter(&is_number/1)
  end

  defp calculate_field_statistics(values, field, context)
       when is_list(values) and length(values) > 0 do
    sorted_values = Enum.sort(values)
    count = length(values)
    sum = Enum.sum(values)
    mean = sum / count

    variance =
      values
      |> Enum.map(fn val -> :math.pow(val - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(count)

    std_dev = :math.sqrt(variance)

    %{
      field: field,
      count: count,
      sum: sum,
      mean: mean,
      median: calculate_median(sorted_values),
      mode: calculate_mode(values),
      min: Enum.min(values),
      max: Enum.max(values),
      range: Enum.max(values) - Enum.min(values),
      variance: variance,
      std_deviation: std_dev,
      quartiles: calculate_quartiles(sorted_values),
      skewness: calculate_skewness(values, mean, std_dev),
      kurtosis: calculate_kurtosis(values, mean, std_dev),
      locale: context.locale
    }
  end

  defp calculate_pearson_correlation(values1, values2) do
    n = length(values1)
    sum1 = Enum.sum(values1)
    sum2 = Enum.sum(values2)
    sum1_sq = values1 |> Enum.map(&(&1 * &1)) |> Enum.sum()
    sum2_sq = values2 |> Enum.map(&(&1 * &1)) |> Enum.sum()
    sum_products = values1 |> Enum.zip(values2) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()

    numerator = n * sum_products - sum1 * sum2
    denominator = :math.sqrt((n * sum1_sq - sum1 * sum1) * (n * sum2_sq - sum2 * sum2))

    if denominator == 0, do: 0, else: numerator / denominator
  end

  defp calculate_spearman_correlation(values1, values2) do
    # Convert to ranks and then calculate Pearson correlation on ranks
    ranks1 = convert_to_ranks(values1)
    ranks2 = convert_to_ranks(values2)
    calculate_pearson_correlation(ranks1, ranks2)
  end

  defp calculate_kendall_correlation(values1, values2) do
    # Simplified Kendall tau calculation
    pairs = Enum.zip(values1, values2)
    n = length(pairs)

    _concordant = 0
    _discordant = 0

    {concordant, discordant} =
      pairs
      |> Enum.with_index()
      |> Enum.reduce({0, 0}, fn {{x1, y1}, i}, {conc, disc} ->
        rest_pairs = Enum.drop(pairs, i + 1)

        Enum.reduce(rest_pairs, {conc, disc}, fn {x2, y2}, {c, d} ->
          update_concordance_counts(x1, y1, x2, y2, c, d)
        end)
      end)

    total_pairs = n * (n - 1) / 2
    if total_pairs == 0, do: 0, else: (concordant - discordant) / total_pairs
  end

  defp update_concordance_counts(x1, y1, x2, y2, concordant_count, discordant_count) do
    sign_x = if x1 < x2, do: 1, else: -1
    sign_y = if y1 < y2, do: 1, else: -1

    if sign_x * sign_y > 0 do
      # Concordant
      {concordant_count + 1, discordant_count}
    else
      # Discordant
      {concordant_count, discordant_count + 1}
    end
  end

  defp time_series_to_numeric(time_series_data) do
    time_series_data
    |> Enum.with_index()
    |> Enum.map(fn {point, index} ->
      case point do
        %{x: _x, y: y} when is_number(y) -> {index, y}
        {_time, value} when is_number(value) -> {index, value}
        value when is_number(value) -> {index, value}
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.unzip()
  end

  defp validate_time_series(time_series_data) do
    if is_list(time_series_data) and length(time_series_data) >= 3 do
      {:ok, time_series_data}
    else
      {:error, "Time series must be a list with at least 3 data points"}
    end
  end

  defp detect_seasonality(time_series_data) do
    # Basic seasonality detection - would be enhanced with proper time series analysis
    {_, y_values} = time_series_to_numeric(time_series_data)

    if length(y_values) < 12 do
      {:error, "At least 12 data points required for seasonality detection"}
    else
      # Simple autocorrelation check for common periods (12, 4, 7)
      # Monthly, quarterly, weekly
      periods_to_check = [12, 4, 7]

      best_period =
        periods_to_check
        |> Enum.map(fn period ->
          correlation = calculate_lag_correlation(y_values, period)
          {period, correlation}
        end)
        |> Enum.max_by(fn {_, correlation} -> abs(correlation) end)

      {period, strength} = best_period

      # Threshold for significant seasonality
      if abs(strength) > 0.3 do
        {:ok,
         %{
           period: period,
           strength: abs(strength),
           components: extract_seasonal_components(y_values, period)
         }}
      else
        {:error, "No significant seasonality detected"}
      end
    end
  end

  defp calculate_lag_correlation(values, lag) do
    if length(values) <= lag do
      0
    else
      original = Enum.drop(values, lag)
      lagged = Enum.take(values, length(values) - lag)

      if length(original) == length(lagged) and length(original) > 0 do
        calculate_pearson_correlation(original, lagged)
      else
        0
      end
    end
  end

  defp extract_seasonal_components(values, period) do
    values
    |> Enum.chunk_every(period)
    |> Enum.zip_with(&Enum.sum/1)
    |> Enum.with_index()
    |> Enum.map(fn {sum, index} -> %{period_index: index, total: sum} end)
  end

  # Statistical utility functions

  defp calculate_median(sorted_values) do
    count = length(sorted_values)

    case rem(count, 2) do
      0 ->
        mid1 = Enum.at(sorted_values, div(count, 2) - 1)
        mid2 = Enum.at(sorted_values, div(count, 2))
        (mid1 + mid2) / 2

      1 ->
        Enum.at(sorted_values, div(count, 2))
    end
  end

  defp calculate_mode(values) do
    values
    |> Enum.frequencies()
    |> Enum.max_by(fn {_, count} -> count end)
    |> elem(0)
  end

  defp calculate_quartiles(sorted_values) do
    count = length(sorted_values)

    %{
      q1: Enum.at(sorted_values, div(count, 4)),
      q2: calculate_median(sorted_values),
      q3: Enum.at(sorted_values, div(count * 3, 4))
    }
  end

  defp calculate_skewness(values, mean, std_dev) do
    if std_dev == 0 do
      0
    else
      n = length(values)

      sum_cubed_deviations =
        values
        |> Enum.map(fn val -> :math.pow((val - mean) / std_dev, 3) end)
        |> Enum.sum()

      sum_cubed_deviations / n
    end
  end

  defp calculate_kurtosis(values, mean, std_dev) do
    if std_dev == 0 do
      0
    else
      n = length(values)

      sum_fourth_deviations =
        values
        |> Enum.map(fn val -> :math.pow((val - mean) / std_dev, 4) end)
        |> Enum.sum()

      # Excess kurtosis
      sum_fourth_deviations / n - 3
    end
  end

  defp convert_to_ranks(values) do
    values
    |> Enum.with_index()
    |> Enum.sort_by(fn {val, _} -> val end)
    |> Enum.with_index()
    |> Enum.map(fn {{_val, original_index}, rank} -> {original_index, rank + 1} end)
    |> Enum.sort_by(fn {original_index, _} -> original_index end)
    |> Enum.map(fn {_, rank} -> rank end)
  end

  # Outlier detection methods

  defp detect_iqr_outliers(data, field, values, context) do
    quartiles = calculate_quartiles(Enum.sort(values))
    iqr = quartiles.q3 - quartiles.q1
    lower_bound = quartiles.q1 - 1.5 * iqr
    upper_bound = quartiles.q3 + 1.5 * iqr

    outliers =
      data
      |> Enum.filter(fn item ->
        value = Map.get(item, field)
        is_number(value) and (value < lower_bound or value > upper_bound)
      end)

    %{
      method: :iqr,
      field: field,
      outliers: outliers,
      outlier_count: length(outliers),
      outlier_percentage: length(outliers) / length(data) * 100,
      bounds: %{lower: lower_bound, upper: upper_bound},
      quartiles: quartiles,
      locale: context.locale
    }
  end

  defp detect_zscore_outliers(data, field, values, context) do
    mean = Enum.sum(values) / length(values)
    std_dev = calculate_std_deviation_from_mean(values, mean)
    # Standard threshold for z-score outliers
    threshold = 2.0

    outliers =
      data
      |> Enum.filter(fn item ->
        value = Map.get(item, field)

        if is_number(value) and std_dev > 0 do
          z_score = abs(value - mean) / std_dev
          z_score > threshold
        else
          false
        end
      end)

    %{
      method: :zscore,
      field: field,
      outliers: outliers,
      outlier_count: length(outliers),
      outlier_percentage: length(outliers) / length(data) * 100,
      threshold: threshold,
      mean: mean,
      std_deviation: std_dev,
      locale: context.locale
    }
  end

  defp detect_modified_zscore_outliers(data, field, values, context) do
    median = calculate_median(Enum.sort(values))
    mad = calculate_median_absolute_deviation(values, median)
    # Modified z-score threshold
    threshold = 3.5

    outliers =
      data
      |> Enum.filter(fn item ->
        value = Map.get(item, field)

        if is_number(value) and mad > 0 do
          modified_z_score = 0.6745 * (value - median) / mad
          abs(modified_z_score) > threshold
        else
          false
        end
      end)

    %{
      method: :modified_zscore,
      field: field,
      outliers: outliers,
      outlier_count: length(outliers),
      outlier_percentage: length(outliers) / length(data) * 100,
      threshold: threshold,
      median: median,
      mad: mad,
      locale: context.locale
    }
  end

  defp calculate_std_deviation_from_mean(values, mean) do
    variance =
      values
      |> Enum.map(fn val -> :math.pow(val - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp calculate_median_absolute_deviation(values, median) do
    deviations = Enum.map(values, fn val -> abs(val - median) end)
    calculate_median(Enum.sort(deviations))
  end

  defp interpret_correlation_strength(coefficient) do
    abs_coeff = abs(coefficient)

    cond do
      abs_coeff >= 0.9 -> :very_strong
      abs_coeff >= 0.7 -> :strong
      abs_coeff >= 0.5 -> :moderate
      abs_coeff >= 0.3 -> :weak
      true -> :very_weak
    end
  end

  defp interpret_r_squared(r_squared) do
    cond do
      r_squared >= 0.9 -> :excellent_fit
      r_squared >= 0.7 -> :good_fit
      r_squared >= 0.5 -> :moderate_fit
      r_squared >= 0.3 -> :weak_fit
      true -> :poor_fit
    end
  end

  defp calculate_correlation_p_value(correlation, sample_size) do
    # Simplified p-value calculation - would benefit from proper statistical library
    if sample_size <= 2 do
      1.0
    else
      t_statistic = correlation * :math.sqrt((sample_size - 2) / (1 - correlation * correlation))
      # This is a rough approximation - proper implementation would use t-distribution
      abs_t = abs(t_statistic)

      cond do
        # p < 0.01
        abs_t > 2.576 -> 0.01
        # p < 0.05
        abs_t > 1.96 -> 0.05
        # p < 0.10
        abs_t > 1.645 -> 0.10
        # p >= 0.10
        true -> 0.20
      end
    end
  end
end
