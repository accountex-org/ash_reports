defmodule AshReports.ChartEngine do
  @moduledoc """
  Core chart engine for AshReports Phase 5.1 Interactive Data Visualization.

  Provides a unified interface for generating charts and visualizations across
  multiple chart providers (Chart.js, D3.js, Plotly) with automatic chart type
  selection and server-side generation capabilities.

  ## Features

  - **Multi-Provider Support**: Pluggable chart providers with consistent API
  - **Automatic Chart Selection**: Intelligent chart type selection based on data characteristics
  - **Server-Side Generation**: SVG generation for PDF and static outputs
  - **Client-Side Integration**: JavaScript generation for interactive HTML/HEEX renderers
  - **Internationalization**: Integration with Phase 4 CLDR and translation systems
  - **Performance Optimization**: Efficient chart data processing and caching

  ## Supported Chart Types

  ### Basic Charts:
  - **Line Charts**: Time series data, trends, continuous data
  - **Bar Charts**: Categorical comparisons, rankings, grouped data
  - **Pie Charts**: Proportional data, percentages, parts-of-whole
  - **Area Charts**: Cumulative data, stacked comparisons

  ### Advanced Charts:
  - **Scatter Plots**: Correlation analysis, data distribution
  - **Histogram Charts**: Frequency distribution, statistical analysis
  - **Box Plots**: Statistical summaries, outlier detection
  - **Heatmaps**: Density visualization, correlation matrices

  ## Chart Providers

  ### Chart.js Provider (Default)
  - Lightweight and performant for basic chart types
  - Excellent mobile responsiveness and accessibility
  - Strong internationalization support
  - Easy integration with existing HTML/HEEX renderers

  ### D3.js Provider (Advanced)
  - Maximum flexibility for custom visualizations
  - Complex interactive capabilities
  - Advanced statistical chart types
  - Custom animation and transition support

  ### Plotly Provider (Scientific)
  - Scientific and engineering chart types
  - 3D visualization capabilities
  - Statistical analysis integration
  - Publication-ready chart outputs

  ## Usage Examples

  ### Basic Chart Generation

      chart_config = %ChartConfig{
        type: :line,
        data: time_series_data,
        provider: :chartjs,
        options: %{responsive: true}
      }
      
      {:ok, chart} = ChartEngine.generate(chart_config, context)

  ### Automatic Chart Selection

      data = %{
        sales_by_month: monthly_sales_data,
        profit_margins: percentage_data
      }
      
      charts = ChartEngine.auto_select_charts(data, context)
      
  ### Interactive Chart with Real-time Updates

      interactive_config = %ChartConfig{
        type: :bar,
        data: sales_data,
        interactive: true,
        real_time: true,
        update_interval: 30_000  # 30 seconds
      }
      
      {:ok, chart} = ChartEngine.generate(interactive_config, context)

  """

  alias AshReports.ChartEngine.{ChartConfig, ChartData}
  alias AshReports.ChartEngine.Providers.{ChartJsProvider, D3Provider, PlotlyProvider}
  alias AshReports.RenderContext

  @type chart_type :: :line | :bar | :pie | :area | :scatter | :histogram | :boxplot | :heatmap
  @type provider :: :chartjs | :d3 | :plotly
  @type chart_result :: {:ok, ChartData.t()} | {:error, String.t()}

  @providers %{
    chartjs: ChartJsProvider,
    d3: D3Provider,
    plotly: PlotlyProvider
  }

  @default_provider :chartjs

  @doc """
  Generate a chart using the specified configuration and render context.

  ## Examples

      config = %ChartConfig{
        type: :line,
        data: [[1, 10], [2, 20], [3, 15]],
        title: "Sales Trend"
      }
      
      {:ok, chart} = ChartEngine.generate(config, context)

  """
  @spec generate(ChartConfig.t(), RenderContext.t()) :: chart_result()
  def generate(%ChartConfig{} = config, %RenderContext{} = context) do
    provider = get_provider(config.provider || @default_provider)

    with {:ok, processed_data} <- process_chart_data(config.data, context),
         {:ok, chart_spec} <- build_chart_specification(config, processed_data, context),
         {:ok, chart_output} <- provider.generate(chart_spec, context) do
      {:ok, chart_output}
    else
      {:error, reason} -> {:error, "Chart generation failed: #{reason}"}
    end
  end

  @doc """
  Automatically select appropriate chart types based on data characteristics.

  Analyzes the provided data and suggests the most suitable chart types
  for visualization based on data patterns, types, and relationships.

  ## Examples

      data = %{
        revenue: [100, 150, 200, 175],
        months: ["Jan", "Feb", "Mar", "Apr"]
      }
      
      suggestions = ChartEngine.auto_select_charts(data, context)
      # Returns: [%ChartConfig{type: :line, confidence: 0.9}, ...]

  """
  @spec auto_select_charts(map(), RenderContext.t()) :: [ChartConfig.t()]
  def auto_select_charts(data, %RenderContext{} = context) when is_map(data) do
    data
    |> analyze_data_characteristics()
    |> generate_chart_suggestions(context)
    |> rank_suggestions()
    |> take_top_suggestions(3)
  end

  @doc """
  Generate multiple charts for comprehensive data visualization.

  Creates a set of related charts that provide different perspectives
  on the same dataset for dashboard-style reporting.

  ## Examples

      chart_set = %{
        overview: %ChartConfig{type: :line, data: trend_data},
        breakdown: %ChartConfig{type: :pie, data: category_data},
        comparison: %ChartConfig{type: :bar, data: comparison_data}
      }
      
      {:ok, charts} = ChartEngine.generate_chart_set(chart_set, context)

  """
  @spec generate_chart_set(map(), RenderContext.t()) :: {:ok, map()} | {:error, String.t()}
  def generate_chart_set(chart_configs, %RenderContext{} = context) when is_map(chart_configs) do
    results =
      Enum.map(chart_configs, fn {key, config} ->
        case generate(config, context) do
          {:ok, chart} -> {key, {:ok, chart}}
          {:error, reason} -> {key, {:error, reason}}
        end
      end)

    errors = results |> Enum.filter(fn {_, result} -> match?({:error, _}, result) end)

    if length(errors) > 0 do
      error_messages = Enum.map(errors, fn {key, {:error, reason}} -> "#{key}: #{reason}" end)
      {:error, "Chart set generation failed: #{Enum.join(error_messages, ", ")}"}
    else
      successful_charts =
        results |> Enum.map(fn {key, {:ok, chart}} -> {key, chart} end) |> Map.new()

      {:ok, successful_charts}
    end
  end

  @doc """
  List all available chart providers and their capabilities.
  """
  @spec list_providers() :: map()
  def list_providers do
    @providers
    |> Enum.map(fn {key, provider_module} ->
      {key,
       %{
         module: provider_module,
         chart_types: provider_module.supported_chart_types(),
         features: provider_module.supported_features(),
         performance: provider_module.performance_characteristics()
       }}
    end)
    |> Map.new()
  end

  @doc """
  Get chart generation statistics and performance metrics.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    %{
      total_charts_generated: get_chart_counter(),
      provider_usage: get_provider_usage_stats(),
      average_generation_time: get_average_generation_time(),
      cache_hit_ratio: get_cache_hit_ratio()
    }
  end

  # Private Functions

  defp get_provider(provider_key) do
    case Map.get(@providers, provider_key) do
      nil ->
        raise ArgumentError,
              "Unknown chart provider: #{provider_key}. Available: #{Map.keys(@providers) |> Enum.join(", ")}"

      provider_module ->
        provider_module
    end
  end

  defp process_chart_data(data, %RenderContext{} = context) do
    # Process and validate chart data
    case data do
      data when is_list(data) ->
        {:ok,
         %ChartData{
           raw_data: data,
           processed_data: normalize_data_points(data),
           data_type: detect_data_type(data),
           locale: context.locale,
           text_direction: context.text_direction
         }}

      data when is_map(data) ->
        {:ok,
         %ChartData{
           raw_data: data,
           processed_data: convert_map_to_series(data),
           data_type: :multi_series,
           locale: context.locale,
           text_direction: context.text_direction
         }}

      _ ->
        {:error, "Invalid data format for chart generation"}
    end
  end

  defp build_chart_specification(
         %ChartConfig{} = config,
         %ChartData{} = data,
         %RenderContext{} = context
       ) do
    base_spec = %{
      type: config.type,
      data: data.processed_data,
      options: merge_chart_options(config.options, context),
      metadata: %{
        locale: context.locale,
        text_direction: context.text_direction,
        rtl_enabled: context.text_direction == "rtl",
        generated_at: DateTime.utc_now()
      }
    }

    # Apply locale-specific formatting
    spec_with_locale = apply_locale_formatting(base_spec, context)

    {:ok, spec_with_locale}
  end

  defp analyze_data_characteristics(data) when is_map(data) do
    Enum.map(data, fn {key, values} ->
      %{
        key: key,
        values: values,
        data_type: detect_data_type(values),
        value_count: length(values),
        has_time_series: detect_time_series(values),
        has_categories: detect_categories(values),
        numeric_range: calculate_numeric_range(values)
      }
    end)
  end

  defp generate_chart_suggestions(characteristics, %RenderContext{} = context) do
    characteristics
    |> Enum.flat_map(&suggest_charts_for_data(&1, context))
    |> Enum.uniq_by(& &1.type)
  end

  defp suggest_charts_for_data(%{data_type: :numeric, has_time_series: true}, _context) do
    [
      %ChartConfig{
        type: :line,
        confidence: 0.9,
        reasoning: "Time series data best shown as line chart"
      },
      %ChartConfig{
        type: :area,
        confidence: 0.7,
        reasoning: "Area chart good for cumulative time series"
      }
    ]
  end

  defp suggest_charts_for_data(%{data_type: :categorical, value_count: count}, _context)
       when count <= 10 do
    [
      %ChartConfig{
        type: :pie,
        confidence: 0.8,
        reasoning: "Small categorical dataset good for pie chart"
      },
      %ChartConfig{
        type: :bar,
        confidence: 0.9,
        reasoning: "Bar chart excellent for categorical comparisons"
      }
    ]
  end

  defp suggest_charts_for_data(%{data_type: :categorical}, _context) do
    [
      %ChartConfig{
        type: :bar,
        confidence: 0.9,
        reasoning: "Bar chart best for large categorical datasets"
      }
    ]
  end

  defp suggest_charts_for_data(%{data_type: :numeric, numeric_range: {min, max}}, _context)
       when max - min > 1000 do
    [
      %ChartConfig{
        type: :histogram,
        confidence: 0.8,
        reasoning: "Large numeric range good for histogram"
      },
      %ChartConfig{
        type: :boxplot,
        confidence: 0.7,
        reasoning: "Box plot shows distribution characteristics"
      }
    ]
  end

  defp suggest_charts_for_data(_, _context) do
    [%ChartConfig{type: :bar, confidence: 0.5, reasoning: "Default bar chart for general data"}]
  end

  defp rank_suggestions(suggestions) do
    Enum.sort_by(suggestions, & &1.confidence, :desc)
  end

  defp take_top_suggestions(suggestions, count) do
    Enum.take(suggestions, count)
  end

  defp normalize_data_points(data) when is_list(data) do
    Enum.map(data, fn
      {x, y} -> %{x: x, y: y}
      [x, y] -> %{x: x, y: y}
      value when is_number(value) -> %{x: length(data), y: value}
      value -> %{x: to_string(value), y: 1}
    end)
  end

  defp convert_map_to_series(data) when is_map(data) do
    data
    |> Enum.map(fn {label, values} ->
      %{
        label: to_string(label),
        data: normalize_data_points(values)
      }
    end)
  end

  defp detect_data_type(values) when is_list(values) do
    case values do
      [] -> :empty
      [first | _] when is_number(first) -> :numeric
      [first | _] when is_binary(first) -> :categorical
      [{_, _} | _] -> :coordinate_pairs
      [[_, _] | _] -> :coordinate_pairs
      _ -> :mixed
    end
  end

  defp detect_time_series(values) when is_list(values) do
    case values do
      [{x, _} | _] when is_binary(x) ->
        # Check if strings look like dates
        Enum.any?(values, fn {x_val, _} ->
          String.contains?(x_val, ["-", "/", ":", "T"])
        end)

      [[x, _] | _] when is_binary(x) ->
        Enum.any?(values, fn [x_val, _] ->
          String.contains?(x_val, ["-", "/", ":", "T"])
        end)

      _ ->
        false
    end
  end

  defp detect_categories(values) when is_list(values) do
    case values do
      [first | _] when is_binary(first) -> true
      [{x, _} | _] when is_binary(x) -> true
      [[x, _] | _] when is_binary(x) -> true
      _ -> false
    end
  end

  defp calculate_numeric_range(values) when is_list(values) do
    numeric_values =
      values
      |> Enum.flat_map(fn
        {_, y} when is_number(y) -> [y]
        [_, y] when is_number(y) -> [y]
        value when is_number(value) -> [value]
        _ -> []
      end)

    case numeric_values do
      [] -> {0, 0}
      nums -> {Enum.min(nums), Enum.max(nums)}
    end
  end

  defp merge_chart_options(config_options, %RenderContext{} = context) do
    base_options = %{
      responsive: true,
      maintainAspectRatio: false,
      locale: context.locale,
      rtl: context.text_direction == "rtl"
    }

    config_options = config_options || %{}

    # Apply RTL-specific options
    rtl_options =
      if context.text_direction == "rtl" do
        %{
          scales: %{
            x: %{reverse: true},
            y: %{position: "right"}
          },
          legend: %{
            rtl: true,
            textDirection: "rtl"
          }
        }
      else
        %{}
      end

    base_options
    |> Map.merge(config_options)
    |> Map.merge(rtl_options)
  end

  defp apply_locale_formatting(chart_spec, %RenderContext{} = context) do
    case context.locale do
      "ar" -> apply_arabic_formatting(chart_spec)
      "he" -> apply_hebrew_formatting(chart_spec)
      "fa" -> apply_persian_formatting(chart_spec)
      "ur" -> apply_urdu_formatting(chart_spec)
      _ -> chart_spec
    end
  end

  defp apply_arabic_formatting(chart_spec) do
    chart_spec
    |> put_in([:options, :scales, :x, :ticks, :font, :family], "Arial, sans-serif")
    |> put_in([:options, :plugins, :legend, :labels, :usePointStyle], true)
  end

  defp apply_hebrew_formatting(chart_spec) do
    chart_spec
    |> put_in([:options, :scales, :x, :ticks, :font, :family], "Arial, sans-serif")
    |> put_in([:options, :plugins, :title, :align], "end")
  end

  defp apply_persian_formatting(chart_spec) do
    chart_spec
    |> put_in([:options, :scales, :x, :ticks, :font, :family], "Tahoma, Arial, sans-serif")
    |> put_in(
      [:options, :scales, :y, :ticks, :callback],
      "function(value) { return value.toLocaleString('fa-IR'); }"
    )
  end

  defp apply_urdu_formatting(chart_spec) do
    chart_spec
    |> put_in(
      [:options, :scales, :x, :ticks, :font, :family],
      "Noto Sans Urdu, Arial, sans-serif"
    )
    |> put_in([:options, :plugins, :legend, :position], "right")
  end

  # Metrics and monitoring

  defp get_chart_counter do
    :persistent_term.get(:ash_reports_chart_counter, 0)
  end

  defp increment_chart_counter do
    current = get_chart_counter()
    :persistent_term.put(:ash_reports_chart_counter, current + 1)
  end

  defp get_provider_usage_stats do
    :persistent_term.get(:ash_reports_provider_stats, %{})
  end

  defp record_provider_usage(provider) do
    stats = get_provider_usage_stats()
    updated_stats = Map.update(stats, provider, 1, &(&1 + 1))
    :persistent_term.put(:ash_reports_provider_stats, updated_stats)
  end

  defp get_average_generation_time do
    times = :persistent_term.get(:ash_reports_generation_times, [])

    case times do
      [] -> 0
      times -> Enum.sum(times) / length(times)
    end
  end

  defp record_generation_time(time_ms) do
    times = :persistent_term.get(:ash_reports_generation_times, [])
    # Keep only last 100 measurements for rolling average
    updated_times = [time_ms | times] |> Enum.take(100)
    :persistent_term.put(:ash_reports_generation_times, updated_times)
  end

  defp get_cache_hit_ratio do
    stats = :persistent_term.get(:ash_reports_cache_stats, %{hits: 0, misses: 0})
    total = stats.hits + stats.misses

    if total > 0 do
      stats.hits / total
    else
      0.0
    end
  end

  @doc false
  def record_chart_generation(provider, generation_time_ms) do
    increment_chart_counter()
    record_provider_usage(provider)
    record_generation_time(generation_time_ms)
  end
end
