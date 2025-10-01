defmodule AshReports.Integration.BenchmarkHelpers do
  @moduledoc """
  Performance benchmarking utilities for AshReports Phase 4 integration tests.

  Provides standardized benchmarking functions using Benchee for measuring
  the performance impact of Phase 4 internationalization features.
  """

  alias AshReports.Integration.TestHelpers
  alias AshReports.TestHelpers, as: BaseTestHelpers

  @performance_limits %{
    max_slowdown_ratio: 3.0,
    max_memory_mb: 50,
    max_render_time_ms: 5000
  }

  def run_phase4_benchmark(scenarios \\ default_scenarios()) do
    Benchee.run(scenarios,
      time: 10,
      memory_time: 2,
      pre_check: true,
      parallel: 1,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "tmp/phase4_integration_benchmarks.html"}
      ]
    )
  end

  def default_scenarios do
    %{
      "baseline_rendering" => fn ->
        report = BaseTestHelpers.build_simple_report()
        data = TestHelpers.create_multilingual_test_data()
        AshReports.HtmlRenderer.render(report, data, %{})
      end,
      "phase4_cldr_integration" => fn ->
        context = TestHelpers.create_cldr_context("en")
        report = TestHelpers.build_phase4_enhanced_report()
        data = TestHelpers.create_multilingual_test_data()
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "phase4_rtl_translation" => fn ->
        context = TestHelpers.create_full_phase4_context("ar")
        report = TestHelpers.build_rtl_test_report()
        data = TestHelpers.create_arabic_test_data()
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "full_phase4_integration" => fn ->
        context = TestHelpers.create_full_phase4_context("ar")
        report = TestHelpers.build_phase4_enhanced_report()
        data = TestHelpers.create_multilingual_test_data()
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end
    }
  end

  def multi_renderer_benchmark do
    report = TestHelpers.build_phase4_enhanced_report()
    data = TestHelpers.create_multilingual_test_data()

    scenarios = %{
      "html_renderer_phase4" => fn ->
        context = TestHelpers.create_full_phase4_context("ar")
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "heex_renderer_phase4" => fn ->
        context = TestHelpers.create_full_phase4_context("ar")
        AshReports.HeexRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "pdf_renderer_phase4" => fn ->
        context = TestHelpers.create_full_phase4_context("ar")
        AshReports.PdfRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "json_renderer_phase4" => fn ->
        context = TestHelpers.create_full_phase4_context("ar")
        AshReports.JsonRenderer.render_with_context(%{context | report: report, records: data})
      end
    }

    run_benchmark(scenarios, "tmp/multi_renderer_benchmarks.html")
  end

  def locale_scalability_benchmark do
    locales = TestHelpers.locales()
    report = TestHelpers.build_phase4_enhanced_report()

    scenarios =
      locales
      # Limit for reasonable benchmark time
      |> Enum.take(5)
      |> Map.new(fn locale ->
        {"locale_#{locale}",
         fn ->
           context = TestHelpers.create_full_phase4_context(locale)

           data =
             case locale do
               "ar" -> TestHelpers.create_arabic_test_data()
               "he" -> TestHelpers.create_hebrew_test_data()
               _ -> TestHelpers.create_multilingual_test_data()
             end

           AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
         end}
      end)

    run_benchmark(scenarios, "tmp/locale_scalability_benchmarks.html")
  end

  def data_size_benchmark do
    report = TestHelpers.build_phase4_enhanced_report()
    context = TestHelpers.create_full_phase4_context("ar")

    scenarios = %{
      "small_dataset_10" => fn ->
        data = TestHelpers.create_performance_test_data(10)
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "medium_dataset_100" => fn ->
        data = TestHelpers.create_performance_test_data(100)
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end,
      "large_dataset_1000" => fn ->
        data = TestHelpers.create_performance_test_data(1000)
        AshReports.HtmlRenderer.render_with_context(%{context | report: report, records: data})
      end
    }

    run_benchmark(scenarios, "tmp/data_size_benchmarks.html")
  end

  def run_benchmark(scenarios, output_file) do
    Benchee.run(scenarios,
      time: 5,
      memory_time: 1,
      pre_check: true,
      parallel: 1,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: output_file}
      ]
    )
  end

  def validate_performance_criteria(benchmark_results) do
    scenarios = benchmark_results.scenarios

    baseline = find_scenario(scenarios, "baseline_rendering")
    full_integration = find_scenario(scenarios, "full_phase4_integration")

    if baseline && full_integration do
      validate_performance_ratio(baseline, full_integration)
      validate_memory_usage(full_integration)
      validate_execution_time(full_integration)
    else
      {:error, "Required benchmark scenarios not found"}
    end
  end

  defp find_scenario(scenarios, name) do
    Enum.find(scenarios, &(&1.name == name))
  end

  defp validate_performance_ratio(baseline, full_integration) do
    baseline_time = baseline.run_time_data.statistics.average
    integration_time = full_integration.run_time_data.statistics.average

    ratio = integration_time / baseline_time
    max_ratio = @performance_limits.max_slowdown_ratio

    if ratio <= max_ratio do
      {:ok, "Performance ratio #{Float.round(ratio, 2)}x is within limits (max: #{max_ratio}x)"}
    else
      {:error, "Performance ratio #{Float.round(ratio, 2)}x exceeds limit of #{max_ratio}x"}
    end
  end

  defp validate_memory_usage(scenario) do
    if scenario.memory_usage_data do
      memory_bytes = scenario.memory_usage_data.statistics.average
      memory_mb = memory_bytes / (1024 * 1024)
      max_memory = @performance_limits.max_memory_mb

      if memory_mb <= max_memory do
        {:ok,
         "Memory usage #{Float.round(memory_mb, 2)}MB is within limits (max: #{max_memory}MB)"}
      else
        {:error, "Memory usage #{Float.round(memory_mb, 2)}MB exceeds limit of #{max_memory}MB"}
      end
    else
      {:ok, "Memory usage data not available"}
    end
  end

  defp validate_execution_time(scenario) do
    time_ns = scenario.run_time_data.statistics.average
    time_ms = time_ns / 1_000_000
    max_time = @performance_limits.max_render_time_ms

    if time_ms <= max_time do
      {:ok, "Execution time #{Float.round(time_ms, 2)}ms is within limits (max: #{max_time}ms)"}
    else
      {:error, "Execution time #{Float.round(time_ms, 2)}ms exceeds limit of #{max_time}ms"}
    end
  end

  def create_performance_report(benchmark_results) do
    """
    # Phase 4 Performance Report

    ## Benchmark Results Summary

    #{format_scenario_summary(benchmark_results.scenarios)}

    ## Performance Analysis

    #{analyze_performance_trends(benchmark_results.scenarios)}

    ## Recommendations

    #{generate_recommendations(benchmark_results.scenarios)}

    Generated at: #{DateTime.utc_now()}
    """
  end

  defp format_scenario_summary(scenarios) do
    scenarios
    |> Enum.map(fn scenario ->
      time_ms = scenario.run_time_data.statistics.average / 1_000_000

      memory_mb =
        if scenario.memory_usage_data do
          scenario.memory_usage_data.statistics.average / (1024 * 1024)
        else
          0
        end

      "- **#{scenario.name}**: #{Float.round(time_ms, 2)}ms, #{Float.round(memory_mb, 2)}MB"
    end)
    |> Enum.join("\n")
  end

  defp analyze_performance_trends(scenarios) do
    baseline = find_scenario(scenarios, "baseline_rendering")

    case baseline do
      nil -> "Baseline scenario not found for comparison analysis."
      baseline -> generate_performance_analysis(scenarios, baseline)
    end
  end

  defp generate_performance_analysis(scenarios, baseline) do
    baseline_time = baseline.run_time_data.statistics.average

    scenarios
    |> Enum.reject(&(&1.name == "baseline_rendering"))
    |> Enum.map(&format_scenario_comparison(&1, baseline_time))
    |> Enum.join("\n")
  end

  defp format_scenario_comparison(scenario, baseline_time) do
    ratio = scenario.run_time_data.statistics.average / baseline_time
    impact = categorize_performance_impact(ratio)

    "- **#{scenario.name}**: #{Float.round(ratio, 2)}x slower than baseline (#{impact})"
  end

  defp categorize_performance_impact(ratio) do
    cond do
      ratio < 1.5 -> "Low impact"
      ratio < 2.5 -> "Moderate impact"
      true -> "High impact"
    end
  end

  defp generate_recommendations(scenarios) do
    recommendations = []

    # Check for performance issues
    slow_scenarios =
      scenarios
      |> Enum.filter(fn scenario ->
        time_ms = scenario.run_time_data.statistics.average / 1_000_000
        # More than 1 second
        time_ms > 1000
      end)

    recommendations =
      if length(slow_scenarios) > 0 do
        [
          "Consider optimizing slow scenarios: #{Enum.map(slow_scenarios, & &1.name) |> Enum.join(", ")}"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for memory issues
    memory_intensive =
      scenarios
      |> Enum.filter(fn scenario ->
        if scenario.memory_usage_data do
          memory_mb = scenario.memory_usage_data.statistics.average / (1024 * 1024)
          # More than 25MB
          memory_mb > 25
        else
          false
        end
      end)

    recommendations =
      if length(memory_intensive) > 0 do
        [
          "Review memory usage for scenarios: #{Enum.map(memory_intensive, & &1.name) |> Enum.join(", ")}"
          | recommendations
        ]
      else
        recommendations
      end

    if length(recommendations) > 0 do
      recommendations |> Enum.map(&("- " <> &1)) |> Enum.join("\n")
    else
      "- All scenarios performing within expected parameters"
    end
  end

  def performance_limits, do: @performance_limits
end
