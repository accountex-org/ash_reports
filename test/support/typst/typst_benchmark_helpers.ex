defmodule AshReports.TypstBenchmarkHelpers do
  @moduledoc """
  Performance benchmarking helpers for Typst compilation.

  Provides utilities for:
  - Benchmarking compilation speed with Benchee
  - Validating performance against baseline targets
  - Generating performance reports
  - Tracking performance over time

  ## Usage

      import AshReports.TypstBenchmarkHelpers

      test "compilation meets performance targets" do
        template = generate_sales_report_template()

        result = benchmark_compilation(template, label: "sales_report")

        assert result.median_time < 500_000  # 500ms
      end

  ## Performance Targets

  - **Simple reports (1-10 pages)**: < 500ms
  - **Medium reports (10-100 pages)**: < 5s
  - **Large reports (100+ pages)**: < 30s
  """

  alias AshReports.Typst.BinaryWrapper

  @doc """
  Benchmarks Typst template compilation.

  Returns timing statistics including median, mean, and percentiles.

  ## Options

  - `:label` - Label for the benchmark (default: "typst_compilation")
  - `:warmup` - Warmup time in seconds (default: 1)
  - `:time` - Benchmark time in seconds (default: 3)
  - `:memory_time` - Memory measurement time (default: 1)

  ## Examples

      iex> template = "#set page(paper: \\"a4\\")\\n= Report"
      iex> result = benchmark_compilation(template)
      iex> result.median_time < 1_000_000  # Under 1 second
      true
  """
  def benchmark_compilation(template, opts \\ []) do
    label = Keyword.get(opts, :label, "typst_compilation")
    warmup = Keyword.get(opts, :warmup, 1)
    time = Keyword.get(opts, :time, 3)
    memory_time = Keyword.get(opts, :memory_time, 1)

    # Run benchmark
    result =
      Benchee.run(
        %{
          label => fn -> BinaryWrapper.compile(template) end
        },
        warmup: warmup,
        time: time,
        memory_time: memory_time,
        print: [fast_warning: false],
        formatters: []
      )

    # Extract statistics
    scenario = result.scenarios |> List.first()

    # Safely extract memory data (may not be available)
    memory_median =
      case scenario do
        %{memory_usage_data: %{statistics: %{median: median}}} when is_number(median) ->
          median

        _ ->
          0
      end

    %{
      label: label,
      median_time: scenario.run_time_data.statistics.median,
      mean_time: scenario.run_time_data.statistics.average,
      min_time: scenario.run_time_data.statistics.minimum,
      max_time: scenario.run_time_data.statistics.maximum,
      std_dev: scenario.run_time_data.statistics.std_dev,
      p99: scenario.run_time_data.statistics.percentiles[99],
      memory_median: memory_median,
      sample_size: scenario.run_time_data.statistics.sample_size
    }
  end

  @doc """
  Runs the complete Typst benchmark suite.

  Tests various report complexities:
  - Simple: Single page, minimal formatting
  - Medium: 10 pages with tables
  - Complex: 50 pages with nested structures

  Returns a map of benchmark results.

  ## Examples

      iex> results = run_typst_benchmark_suite()
      iex> results.simple.median_time < 500_000
      true
  """
  def run_typst_benchmark_suite(opts \\ []) do
    %{
      simple: benchmark_simple_report(opts),
      medium: benchmark_medium_report(opts),
      complex: benchmark_complex_report(opts)
    }
  end

  @doc """
  Validates benchmark results against performance targets.

  ## Performance Targets

  - Simple reports: median < 500ms
  - Medium reports: median < 5s
  - Complex reports: median < 30s

  ## Examples

      iex> result = benchmark_compilation(simple_template)
      iex> validation = validate_performance_targets(result, type: :simple)
      iex> validation.passed
      true
  """
  def validate_performance_targets(result, opts \\ []) do
    type = Keyword.get(opts, :type, :simple)

    target =
      case type do
        :simple ->
          500_000_000

        # 500ms in nanoseconds
        :medium ->
          5_000_000_000

        # 5s in nanoseconds
        :complex ->
          30_000_000_000

        # 30s in nanoseconds
        _ ->
          1_000_000_000
          # 1s default
      end

    passed = result.median_time <= target
    percentage = result.median_time / target * 100

    %{
      passed: passed,
      target_ns: target,
      actual_ns: result.median_time,
      percentage_of_target: percentage,
      margin: target - result.median_time,
      message: performance_message(passed, type, percentage)
    }
  end

  @doc """
  Generates a performance report from benchmark results.

  Returns a formatted string with performance metrics.

  ## Examples

      iex> result = benchmark_compilation(template)
      iex> report = generate_performance_report(result)
      iex> report =~ "Median Time"
      true
  """
  def generate_performance_report(result) do
    """
    === Performance Report: #{result.label} ===

    Timing Statistics:
      Median Time: #{format_time(result.median_time)}
      Mean Time:   #{format_time(result.mean_time)}
      Min Time:    #{format_time(result.min_time)}
      Max Time:    #{format_time(result.max_time)}
      Std Dev:     #{format_time(result.std_dev)}
      P99:         #{format_time(result.p99)}

    Memory Usage:
      Median:      #{format_memory(result.memory_median)}

    Sample Size: #{result.sample_size}
    """
  end

  @doc """
  Compares two benchmark results and returns the difference.

  Useful for detecting performance regressions.

  ## Examples

      iex> baseline = benchmark_compilation(template_v1)
      iex> current = benchmark_compilation(template_v2)
      iex> diff = compare_benchmarks(baseline, current)
      iex> diff.regression?
      false
  """
  def compare_benchmarks(baseline, current) do
    median_diff = current.median_time - baseline.median_time
    median_change_pct = median_diff / baseline.median_time * 100

    memory_diff = current.memory_median - baseline.memory_median

    regression_threshold = 10.0
    # 10% slower is a regression

    %{
      baseline_median: baseline.median_time,
      current_median: current.median_time,
      median_diff_ns: median_diff,
      median_change_percent: median_change_pct,
      regression?: median_change_pct > regression_threshold,
      improvement?: median_change_pct < -5.0,
      memory_diff_bytes: memory_diff,
      summary: comparison_summary(median_change_pct)
    }
  end

  # Private helpers

  defp benchmark_simple_report(opts) do
    template = """
    #set page(paper: "a4")
    #set text(font: "Liberation Sans")

    = Simple Report

    This is a simple single-page report for benchmarking.

    == Section 1
    Lorem ipsum dolor sit amet.

    == Section 2
    Consectetur adipiscing elit.
    """

    benchmark_compilation(template, Keyword.merge([label: "simple_report"], opts))
  end

  defp benchmark_medium_report(opts) do
    # Generate a 10-page report
    sections =
      for i <- 1..10 do
        """
        == Section #{i}

        #{generate_lorem_ipsum(100)}

        #table(
          columns: 3,
          [Header 1], [Header 2], [Header 3],
          [Data 1], [Data 2], [Data 3],
          [Data 4], [Data 5], [Data 6]
        )

        #pagebreak()
        """
      end

    template = """
    #set page(paper: "a4")
    #set text(font: "Liberation Sans")

    = Medium Report

    #{Enum.join(sections, "\n")}
    """

    benchmark_compilation(template, Keyword.merge([label: "medium_report"], opts))
  end

  defp benchmark_complex_report(opts) do
    # Generate a 50-page report with nested structures
    sections =
      for i <- 1..50 do
        """
        == Chapter #{i}

        #{generate_lorem_ipsum(200)}

        === Subsection #{i}.1
        #{generate_lorem_ipsum(100)}

        === Subsection #{i}.2
        #{generate_lorem_ipsum(100)}

        #table(
          columns: 4,
          [Col 1], [Col 2], [Col 3], [Col 4],
          ..for j in range(5) {
            ([Data], [Data], [Data], [Data])
          }
        )

        #pagebreak()
        """
      end

    template = """
    #set page(paper: "a4", margin: 2cm)
    #set text(font: "Liberation Sans", size: 11pt)
    #set heading(numbering: "1.1")

    = Complex Report
    #outline()

    #{Enum.join(sections, "\n")}
    """

    benchmark_compilation(template, Keyword.merge([label: "complex_report"], opts))
  end

  defp generate_lorem_ipsum(word_count) do
    words = [
      "lorem",
      "ipsum",
      "dolor",
      "sit",
      "amet",
      "consectetur",
      "adipiscing",
      "elit",
      "sed",
      "do",
      "eiusmod",
      "tempor",
      "incididunt",
      "ut",
      "labore",
      "et",
      "dolore",
      "magna",
      "aliqua"
    ]

    1..word_count
    |> Enum.map(fn _ -> Enum.random(words) end)
    |> Enum.join(" ")
  end

  defp format_time(nanoseconds) when is_number(nanoseconds) do
    cond do
      nanoseconds < 1_000 -> "#{Float.round(nanoseconds, 2)} ns"
      nanoseconds < 1_000_000 -> "#{Float.round(nanoseconds / 1_000, 2)} μs"
      nanoseconds < 1_000_000_000 -> "#{Float.round(nanoseconds / 1_000_000, 2)} ms"
      true -> "#{Float.round(nanoseconds / 1_000_000_000, 2)} s"
    end
  end

  defp format_time(_), do: "N/A"

  defp format_memory(bytes) when is_number(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 2)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
    end
  end

  defp format_memory(_), do: "N/A"

  defp performance_message(true, type, percentage) do
    "✓ Performance target met for #{type} report (#{Float.round(percentage, 1)}% of target)"
  end

  defp performance_message(false, type, percentage) do
    "✗ Performance target missed for #{type} report (#{Float.round(percentage, 1)}% of target)"
  end

  defp comparison_summary(change_pct) when change_pct > 10 do
    "⚠ Significant regression: #{Float.round(change_pct, 1)}% slower"
  end

  defp comparison_summary(change_pct) when change_pct > 5 do
    "⚠ Minor regression: #{Float.round(change_pct, 1)}% slower"
  end

  defp comparison_summary(change_pct) when change_pct < -10 do
    "✓ Significant improvement: #{Float.round(abs(change_pct), 1)}% faster"
  end

  defp comparison_summary(change_pct) when change_pct < -5 do
    "✓ Minor improvement: #{Float.round(abs(change_pct), 1)}% faster"
  end

  defp comparison_summary(_) do
    "≈ Performance similar to baseline"
  end
end
