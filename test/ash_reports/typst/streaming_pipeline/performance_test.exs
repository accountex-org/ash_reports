defmodule AshReports.Typst.StreamingPipeline.PerformanceTest do
  @moduledoc """
  Performance validation tests for streaming pipeline benchmarks.

  These tests validate that benchmarks run successfully and basic
  performance characteristics are within acceptable ranges.

  Run with: mix test test/ash_reports/typst/streaming_pipeline/performance_test.exs
  """

  use ExUnit.Case, async: false

  alias AshReports.StreamingBenchmarks

  @moduletag :performance
  @moduletag timeout: 120_000

  describe "MVP Benchmark Suite" do
    test "benchmark suite runs successfully with short time" do
      # Run with very short time for CI/testing
      results = StreamingBenchmarks.run_mvp_suite(time: 0.1, memory_time: 0.1)

      # Verify all benchmarks completed
      assert results[:memory][:status] == :completed
      assert results[:throughput][:status] == :completed
      assert results[:concurrency][:status] == :completed

      # Verify summary was generated
      assert is_binary(results[:summary])
      assert results[:summary] =~ "MVP Benchmark Suite Complete"
    end

    test "memory baseline is measured" do
      results = StreamingBenchmarks.run_mvp_suite(time: 0.1, memory_time: 0.1)

      # Baseline memory should be a reasonable number (> 0, < 1000 MB)
      baseline_mb = results[:memory][:baseline_mb]
      assert is_float(baseline_mb)
      assert baseline_mb > 0
      assert baseline_mb < 1000
    end

    test "performance targets are documented" do
      results = StreamingBenchmarks.run_mvp_suite(time: 0.1, memory_time: 0.1)

      # Memory target
      assert results[:memory][:target_multiplier] == 1.5

      # Throughput target
      assert results[:throughput][:target_records_per_sec] == 1000

      # Concurrency target
      assert results[:concurrency][:target_concurrent_streams] == 5
    end
  end

  describe "Individual Benchmarks" do
    test "memory benchmark runs without errors" do
      result = StreamingBenchmarks.run_memory_benchmark(0.1)

      assert result[:status] == :completed
      assert result[:baseline_mb] > 0
    end

    test "throughput benchmark runs without errors" do
      result = StreamingBenchmarks.run_throughput_benchmark(0.1)

      assert result[:status] == :completed
      assert result[:target_records_per_sec] == 1000
    end

    test "concurrency benchmark runs without errors" do
      result = StreamingBenchmarks.run_concurrency_benchmark(0.1)

      assert result[:status] == :completed
      assert result[:target_concurrent_streams] == 5
    end
  end

  describe "Benchmark Outputs" do
    test "HTML reports are generated" do
      # Run benchmarks (will generate HTML)
      StreamingBenchmarks.run_mvp_suite(time: 0.1, memory_time: 0.1)

      # Check that HTML files were created
      assert File.exists?("benchmarks/results/memory_mvp.html")
      assert File.exists?("benchmarks/results/throughput_mvp.html")
      assert File.exists?("benchmarks/results/concurrency_mvp.html")
    end
  end
end
