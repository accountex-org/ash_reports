defmodule AshReports.TypstMemoryMonitorTest do
  use ExUnit.Case, async: false

  import AshReports.TypstMemoryMonitor
  import AshReports.TypstMockData

  describe "monitor_compilation_memory/2" do
    test "monitors memory usage during simple compilation" do
      template = generate_mock_report(complexity: :simple)

      result = monitor_compilation_memory(template)

      assert result.success
      assert is_number(result.initial_memory_mb)
      assert is_number(result.final_memory_mb)
      assert is_number(result.peak_memory_mb)
      assert is_number(result.memory_growth_mb)
      assert is_number(result.compilation_time_ms)

      # Peak should be >= initial
      assert result.peak_memory_mb >= result.initial_memory_mb
    end

    test "captures memory samples during compilation" do
      template = generate_mock_report(complexity: :simple)

      result = monitor_compilation_memory(template, samples: 5)

      assert is_list(result.memory_samples)
      assert length(result.memory_samples) <= 5
      assert Enum.all?(result.memory_samples, &is_number/1)
    end

    test "respects gc_before option" do
      template = generate_mock_report(complexity: :simple)

      # With GC before
      result_with_gc = monitor_compilation_memory(template, gc_before: true)
      assert result_with_gc.success

      # Without GC before
      result_without_gc = monitor_compilation_memory(template, gc_before: false)
      assert result_without_gc.success
    end

    test "includes GC statistics" do
      template = generate_mock_report(complexity: :simple)

      result = monitor_compilation_memory(template)

      assert is_map(result.gc_stats)
      assert Map.has_key?(result.gc_stats, :minor_gcs)
      assert Map.has_key?(result.gc_stats, :number_of_gcs)
      assert Map.has_key?(result.gc_stats, :words_reclaimed)
    end

    test "tracks system memory" do
      template = generate_mock_report(complexity: :simple)

      result = monitor_compilation_memory(template)

      assert is_number(result.system_memory_before_mb)
      assert is_number(result.system_memory_after_mb)
      assert result.system_memory_before_mb > 0
      assert result.system_memory_after_mb > 0
    end
  end

  describe "detect_memory_leak/2" do
    test "detects no leak for simple template" do
      template = generate_mock_report(complexity: :simple)

      result = detect_memory_leak(template, cycles: 5, warmup: 1)

      assert is_boolean(result.leak_detected)
      assert is_list(result.memory_per_cycle)
      assert length(result.memory_per_cycle) == 5
      assert is_number(result.avg_growth_mb_per_cycle)
      assert is_number(result.trend)

      # Simple templates shouldn't leak
      refute result.leak_detected
    end

    test "provides per-cycle memory information" do
      template = generate_mock_report(complexity: :simple)

      result = detect_memory_leak(template, cycles: 3, warmup: 1)

      assert length(result.memory_per_cycle) == 3

      Enum.each(result.memory_per_cycle, fn cycle_info ->
        assert Map.has_key?(cycle_info, :cycle)
        assert Map.has_key?(cycle_info, :before_mb)
        assert Map.has_key?(cycle_info, :after_mb)
        assert Map.has_key?(cycle_info, :growth_mb)
      end)
    end

    test "calculates memory growth statistics" do
      template = generate_mock_report(complexity: :simple)

      result = detect_memory_leak(template, cycles: 5)

      assert is_number(result.avg_growth_mb_per_cycle)
      assert is_number(result.max_growth_mb)
      assert is_number(result.min_growth_mb)

      # Max should be >= min
      assert result.max_growth_mb >= result.min_growth_mb
    end

    test "respects gc_between option" do
      template = generate_mock_report(complexity: :simple)

      # With GC between cycles
      result_with_gc = detect_memory_leak(template, cycles: 3, gc_between: true)
      assert is_map(result_with_gc)

      # Without GC between cycles
      result_without_gc = detect_memory_leak(template, cycles: 3, gc_between: false)
      assert is_map(result_without_gc)
    end
  end

  describe "validate_memory_limits/2" do
    test "validates simple report memory usage" do
      template = generate_mock_report(complexity: :simple)
      memory_result = monitor_compilation_memory(template)

      validation = validate_memory_limits(memory_result, type: :simple)

      assert is_boolean(validation.passed)
      assert validation.target_mb == 10
      assert is_number(validation.actual_mb)
      assert is_number(validation.percentage_of_target)
      assert is_binary(validation.message)

      # Simple reports should pass 10 MB limit
      assert validation.passed
    end

    test "validates medium report memory usage" do
      template = generate_mock_report(complexity: :medium)
      memory_result = monitor_compilation_memory(template)

      validation = validate_memory_limits(memory_result, type: :medium)

      assert validation.target_mb == 50
      # Medium reports should stay under 50 MB
      assert validation.passed
    end

    test "allows custom memory limits" do
      template = generate_mock_report(complexity: :simple)
      memory_result = monitor_compilation_memory(template)

      validation = validate_memory_limits(memory_result, max_peak_mb: 5)

      assert validation.target_mb == 5
      assert is_boolean(validation.passed)
    end

    test "calculates percentage and margin correctly" do
      template = generate_mock_report(complexity: :simple)
      memory_result = monitor_compilation_memory(template)

      validation = validate_memory_limits(memory_result, type: :simple)

      assert validation.percentage_of_target ==
               Float.round(validation.actual_mb / validation.target_mb * 100, 1)

      assert validation.margin_mb ==
               Float.round(validation.target_mb - validation.actual_mb, 2)
    end
  end

  describe "generate_memory_report/1" do
    test "generates formatted memory report" do
      template = generate_mock_report(complexity: :simple)
      memory_result = monitor_compilation_memory(template)

      report = generate_memory_report(memory_result)

      assert is_binary(report)
      assert report =~ "Memory Usage Report"
      assert report =~ "Compilation Status:"
      assert report =~ "Compilation Time:"
      assert report =~ "Initial Memory:"
      assert report =~ "Final Memory:"
      assert report =~ "Peak Memory:"
      assert report =~ "Memory Growth:"
      assert report =~ "GC Statistics:"
    end

    test "includes compilation status in report" do
      template = generate_mock_report(complexity: :simple)
      memory_result = monitor_compilation_memory(template)

      report = generate_memory_report(memory_result)

      if memory_result.success do
        assert report =~ "Success"
      else
        assert report =~ "Failed"
      end
    end
  end
end
