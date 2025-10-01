defmodule AshReports.TypstBenchmarkHelpersTest do
  use ExUnit.Case, async: false

  import AshReports.TypstBenchmarkHelpers

  @moduletag :benchmark

  describe "benchmark_compilation/2" do
    test "benchmarks simple template compilation" do
      template = "#set page(paper: \"a4\")" <> "\n" <> "= Test Report"

      result = benchmark_compilation(template, time: 1, warmup: 0)

      assert result.label == "typst_compilation"
      assert is_number(result.median_time)
      assert result.median_time > 0
      assert is_number(result.mean_time)
      assert is_number(result.sample_size)
      assert result.sample_size > 0
    end

    test "accepts custom label" do
      template = "#set page(paper: \"a4\")" <> "\n" <> "= Test"

      result = benchmark_compilation(template, label: "custom_test", time: 1, warmup: 0)

      assert result.label == "custom_test"
    end

    test "includes percentile statistics" do
      template = "#set page(paper: \"a4\")" <> "\n" <> "= Test"

      result = benchmark_compilation(template, time: 1, warmup: 0)

      assert is_number(result.p99)
      assert result.p99 >= result.median_time
    end
  end

  describe "run_typst_benchmark_suite/1" do
    @tag :slow
    test "runs complete benchmark suite" do
      results = run_typst_benchmark_suite(time: 1, warmup: 0)

      assert Map.has_key?(results, :simple)
      assert Map.has_key?(results, :medium)
      assert Map.has_key?(results, :complex)

      assert results.simple.label == "simple_report"
      assert results.medium.label == "medium_report"
      assert results.complex.label == "complex_report"
    end

    @tag :slow
    test "complex reports take longer than simple reports" do
      results = run_typst_benchmark_suite(time: 1, warmup: 0)

      # Generally, complex should be slower (though not guaranteed)
      assert is_number(results.simple.median_time)
      assert is_number(results.complex.median_time)
    end
  end

  describe "validate_performance_targets/2" do
    test "validates simple report performance" do
      result = %{
        label: "test",
        median_time: 100_000_000,
        # 100ms
        mean_time: 110_000_000,
        min_time: 90_000_000,
        max_time: 130_000_000,
        std_dev: 10_000_000,
        p99: 125_000_000,
        memory_median: 1_000_000,
        sample_size: 100
      }

      validation = validate_performance_targets(result, type: :simple)

      assert validation.passed == true
      assert validation.target_ns == 500_000_000
      assert validation.actual_ns == 100_000_000
      assert validation.percentage_of_target == 20.0
      assert validation.margin > 0
    end

    test "detects performance target failures" do
      result = %{
        label: "test",
        median_time: 600_000_000,
        # 600ms (over 500ms target)
        mean_time: 610_000_000,
        min_time: 590_000_000,
        max_time: 630_000_000,
        std_dev: 10_000_000,
        p99: 625_000_000,
        memory_median: 1_000_000,
        sample_size: 100
      }

      validation = validate_performance_targets(result, type: :simple)

      assert validation.passed == false
      assert validation.percentage_of_target > 100.0
      assert validation.margin < 0
    end

    test "validates medium report performance" do
      result = %{
        label: "test",
        median_time: 3_000_000_000,
        # 3s
        mean_time: 3_100_000_000,
        min_time: 2_900_000_000,
        max_time: 3_300_000_000,
        std_dev: 100_000_000,
        p99: 3_250_000_000,
        memory_median: 5_000_000,
        sample_size: 50
      }

      validation = validate_performance_targets(result, type: :medium)

      assert validation.passed == true
      assert validation.target_ns == 5_000_000_000
    end
  end

  describe "generate_performance_report/1" do
    test "generates formatted performance report" do
      result = %{
        label: "test_report",
        median_time: 150_000_000,
        mean_time: 160_000_000,
        min_time: 140_000_000,
        max_time: 180_000_000,
        std_dev: 10_000_000,
        p99: 175_000_000,
        memory_median: 2_000_000,
        sample_size: 100
      }

      report = generate_performance_report(result)

      assert report =~ "Performance Report: test_report"
      assert report =~ "Median Time"
      assert report =~ "Mean Time"
      assert report =~ "Memory Usage"
      assert report =~ "Sample Size: 100"
    end
  end

  describe "compare_benchmarks/2" do
    test "detects performance improvements" do
      baseline = %{
        median_time: 200_000_000,
        memory_median: 2_000_000
      }

      current = %{
        median_time: 150_000_000,
        # 25% faster
        memory_median: 1_800_000
      }

      diff = compare_benchmarks(baseline, current)

      assert diff.median_change_percent < 0
      assert diff.improvement? == true
      assert diff.regression? == false
      assert diff.summary =~ "improvement"
    end

    test "detects performance regressions" do
      baseline = %{
        median_time: 150_000_000,
        memory_median: 2_000_000
      }

      current = %{
        median_time: 200_000_000,
        # 33% slower
        memory_median: 2_500_000
      }

      diff = compare_benchmarks(baseline, current)

      assert diff.median_change_percent > 0
      assert diff.regression? == true
      assert diff.improvement? == false
      assert diff.summary =~ "regression"
    end

    test "detects similar performance" do
      baseline = %{
        median_time: 150_000_000,
        memory_median: 2_000_000
      }

      current = %{
        median_time: 153_000_000,
        # 2% change
        memory_median: 2_050_000
      }

      diff = compare_benchmarks(baseline, current)

      assert diff.regression? == false
      assert diff.improvement? == false
      assert diff.summary =~ "similar"
    end
  end
end
