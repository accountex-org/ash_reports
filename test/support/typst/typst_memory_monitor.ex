defmodule AshReports.TypstMemoryMonitor do
  @moduledoc """
  Memory usage monitoring for Typst PDF generation.

  Provides utilities for:
  - Tracking memory usage during compilation
  - Detecting memory leaks
  - Monitoring memory growth patterns
  - Validating memory limits for large reports

  ## Usage

      import AshReports.TypstMemoryMonitor

      test "compilation stays within memory limits" do
        result = monitor_compilation_memory(large_template)

        assert result.peak_memory_mb < 100  # Under 100 MB
        assert result.memory_growth_mb < 50  # Limited growth
      end

  ## Memory Targets

  - **Simple reports**: < 10 MB peak
  - **Medium reports**: < 50 MB peak
  - **Large reports**: < 200 MB peak
  """

  alias AshReports.Typst.BinaryWrapper

  @doc """
  Monitors memory usage during Typst compilation.

  Returns detailed memory statistics:
  - Initial memory before compilation
  - Peak memory during compilation
  - Final memory after compilation
  - Memory growth during compilation
  - GC statistics

  ## Options

  - `:gc_before` - Run garbage collection before starting (default: true)
  - `:gc_after` - Run garbage collection after completion (default: false)
  - `:samples` - Number of memory samples to take (default: 10)

  ## Examples

      iex> template = generate_large_report()
      iex> result = monitor_compilation_memory(template)
      iex> result.peak_memory_mb
      45.2
  """
  def monitor_compilation_memory(template, opts \\ []) do
    gc_before? = Keyword.get(opts, :gc_before, true)
    gc_after? = Keyword.get(opts, :gc_after, false)
    samples = Keyword.get(opts, :samples, 10)

    # Run GC before measurement if requested
    if gc_before?, do: :erlang.garbage_collect()

    # Capture initial memory
    initial_memory = get_process_memory()
    initial_system_memory = get_system_memory()

    # Start background memory sampler
    sampler_pid = start_memory_sampler(samples)

    # Compile the template
    start_time = System.monotonic_time(:microsecond)
    compilation_result = BinaryWrapper.compile(template)
    end_time = System.monotonic_time(:microsecond)

    # Stop sampler and get samples
    memory_samples = stop_memory_sampler(sampler_pid)

    # Capture final memory
    final_memory = get_process_memory()
    final_system_memory = get_system_memory()

    # Run GC after if requested
    if gc_after?, do: :erlang.garbage_collect()

    # Calculate statistics
    peak_memory = Enum.max([initial_memory | memory_samples])
    memory_growth = final_memory - initial_memory

    %{
      success: match?({:ok, _}, compilation_result),
      initial_memory_bytes: initial_memory,
      final_memory_bytes: final_memory,
      peak_memory_bytes: peak_memory,
      memory_growth_bytes: memory_growth,
      initial_memory_mb: bytes_to_mb(initial_memory),
      final_memory_mb: bytes_to_mb(final_memory),
      peak_memory_mb: bytes_to_mb(peak_memory),
      memory_growth_mb: bytes_to_mb(memory_growth),
      compilation_time_ms: div(end_time - start_time, 1000),
      memory_samples: Enum.map(memory_samples, &bytes_to_mb/1),
      system_memory_before_mb: bytes_to_mb(initial_system_memory),
      system_memory_after_mb: bytes_to_mb(final_system_memory),
      gc_stats: get_gc_stats()
    }
  end

  @doc """
  Runs multiple compilation cycles to detect memory leaks.

  Compiles the same template multiple times and tracks memory
  growth between iterations. Memory should stabilize after
  initial warmup.

  ## Options

  - `:cycles` - Number of compilation cycles (default: 10)
  - `:warmup` - Number of warmup cycles before measurement (default: 2)
  - `:gc_between` - Run GC between cycles (default: true)

  ## Examples

      iex> template = generate_report()
      iex> result = detect_memory_leak(template, cycles: 5)
      iex> result.leak_detected
      false
  """
  def detect_memory_leak(template, opts \\ []) do
    cycles = Keyword.get(opts, :cycles, 10)
    warmup = Keyword.get(opts, :warmup, 2)
    gc_between? = Keyword.get(opts, :gc_between, true)

    # Warmup phase
    for _ <- 1..warmup do
      BinaryWrapper.compile(template)
      if gc_between?, do: :erlang.garbage_collect()
    end

    # Measurement phase
    memory_per_cycle =
      for cycle <- 1..cycles do
        if gc_between?, do: :erlang.garbage_collect()

        before = get_process_memory()
        BinaryWrapper.compile(template)
        after_mem = get_process_memory()

        growth = after_mem - before

        %{
          cycle: cycle,
          before_mb: bytes_to_mb(before),
          after_mb: bytes_to_mb(after_mem),
          growth_mb: bytes_to_mb(growth)
        }
      end

    # Analyze for leaks
    growths = Enum.map(memory_per_cycle, & &1.growth_mb)
    avg_growth = Enum.sum(growths) / length(growths)

    # Memory leak if average growth > 1 MB per cycle
    leak_detected = avg_growth > 1.0

    # Calculate trend (positive = growing, negative = shrinking)
    trend = calculate_trend(growths)

    %{
      leak_detected: leak_detected,
      cycles: cycles,
      avg_growth_mb_per_cycle: Float.round(avg_growth, 3),
      max_growth_mb: Enum.max(growths),
      min_growth_mb: Enum.min(growths),
      trend: trend,
      memory_per_cycle: memory_per_cycle
    }
  end

  @doc """
  Validates memory usage against target limits.

  ## Options

  - `:type` - Report complexity (:simple | :medium | :large)
  - `:max_peak_mb` - Custom peak memory limit in MB

  ## Examples

      iex> result = monitor_compilation_memory(template)
      iex> validation = validate_memory_limits(result, type: :medium)
      iex> validation.passed
      true
  """
  def validate_memory_limits(memory_result, opts \\ []) do
    type = Keyword.get(opts, :type, :simple)

    target_mb =
      case Keyword.get(opts, :max_peak_mb) do
        nil ->
          case type do
            :simple -> 10
            :medium -> 50
            :large -> 200
            _ -> 50
          end

        custom ->
          custom
      end

    passed = memory_result.peak_memory_mb <= target_mb
    percentage = memory_result.peak_memory_mb / target_mb * 100

    %{
      passed: passed,
      target_mb: target_mb,
      actual_mb: memory_result.peak_memory_mb,
      percentage_of_target: Float.round(percentage, 1),
      margin_mb: Float.round(target_mb - memory_result.peak_memory_mb, 2),
      message: memory_message(passed, type, memory_result.peak_memory_mb, target_mb)
    }
  end

  @doc """
  Generates a memory usage report from monitoring results.

  ## Examples

      iex> result = monitor_compilation_memory(template)
      iex> report = generate_memory_report(result)
      iex> report =~ "Peak Memory"
      true
  """
  def generate_memory_report(result) do
    """
    === Memory Usage Report ===

    Compilation Status: #{if result.success, do: "Success", else: "Failed"}
    Compilation Time:   #{result.compilation_time_ms} ms

    Memory Usage:
      Initial Memory:  #{Float.round(result.initial_memory_mb, 2)} MB
      Final Memory:    #{Float.round(result.final_memory_mb, 2)} MB
      Peak Memory:     #{Float.round(result.peak_memory_mb, 2)} MB
      Memory Growth:   #{Float.round(result.memory_growth_mb, 2)} MB

    System Memory:
      Before:          #{Float.round(result.system_memory_before_mb, 2)} MB
      After:           #{Float.round(result.system_memory_after_mb, 2)} MB

    GC Statistics:
      Minor GCs:       #{result.gc_stats.minor_gcs}
      Collections:     #{result.gc_stats.number_of_gcs}
      Words Reclaimed: #{result.gc_stats.words_reclaimed}
    """
  end

  # Private helpers

  defp start_memory_sampler(num_samples) do
    parent = self()
    # Sample every 50ms
    interval = 50

    spawn(fn ->
      samples = collect_samples(num_samples, interval, [])
      send(parent, {:memory_samples, samples})
    end)
  end

  defp collect_samples(0, _interval, acc), do: Enum.reverse(acc)

  defp collect_samples(remaining, interval, acc) do
    sample = get_process_memory()
    Process.sleep(interval)
    collect_samples(remaining - 1, interval, [sample | acc])
  end

  defp stop_memory_sampler(pid) do
    receive do
      {:memory_samples, samples} -> samples
    after
      5000 ->
        # Timeout - kill sampler and return empty list
        Process.exit(pid, :kill)
        []
    end
  end

  defp get_process_memory do
    {:memory, memory} = Process.info(self(), :memory)
    memory
  end

  defp get_system_memory do
    :erlang.memory(:total)
  end

  defp get_gc_stats do
    case Process.info(self(), :garbage_collection) do
      {:garbage_collection, gc_info} ->
        %{
          minor_gcs: Keyword.get(gc_info, :minor_gcs, 0),
          number_of_gcs: Keyword.get(gc_info, :number_of_gcs, 0),
          words_reclaimed: Keyword.get(gc_info, :words_reclaimed, 0)
        }

      nil ->
        %{minor_gcs: 0, number_of_gcs: 0, words_reclaimed: 0}
    end
  end

  defp bytes_to_mb(bytes) when is_number(bytes) do
    bytes / (1024 * 1024)
  end

  defp bytes_to_mb(_), do: 0.0

  defp calculate_trend(values) when length(values) < 2, do: 0.0

  defp calculate_trend(values) do
    # Simple linear regression slope
    n = length(values)
    indexed = Enum.with_index(values, 1)

    sum_x = n * (n + 1) / 2
    sum_y = Enum.sum(values)
    sum_xy = Enum.reduce(indexed, 0, fn {y, x}, acc -> acc + x * y end)
    sum_x2 = Enum.reduce(1..n, 0, fn x, acc -> acc + x * x end)

    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    Float.round(slope, 4)
  end

  defp memory_message(true, type, actual, target) do
    "✓ Memory limit met for #{type} report (#{Float.round(actual, 1)} MB / #{target} MB)"
  end

  defp memory_message(false, type, actual, target) do
    "✗ Memory limit exceeded for #{type} report (#{Float.round(actual, 1)} MB / #{target} MB)"
  end
end
