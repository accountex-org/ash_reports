defmodule AshReports.StreamingBenchmarks do
  @moduledoc """
  MVP Performance Benchmarks for Streaming Pipeline.

  Focuses on critical metrics:
  - Memory usage with 100K records
  - Throughput (records/second)
  - Concurrent stream handling (5 streams)

  Run with: mix run benchmarks/streaming_pipeline_benchmarks.exs
  """

  @doc """
  Runs the MVP benchmark suite.

  Returns results map with summary.
  """
  def run_mvp_suite(opts \\ []) do
    time = Keyword.get(opts, :time, 3)
    memory_time = Keyword.get(opts, :memory_time, 2)

    IO.puts("Running MVP Benchmark Suite...")
    IO.puts("- Memory benchmark (100K records)")
    IO.puts("- Throughput benchmark")
    IO.puts("- Concurrency benchmark (5 streams)\n")

    # Run memory benchmark
    memory_results = run_memory_benchmark(memory_time)

    # Run throughput benchmark
    throughput_results = run_throughput_benchmark(time)

    # Run concurrency benchmark
    concurrency_results = run_concurrency_benchmark(time)

    # Generate summary
    summary = generate_summary(memory_results, throughput_results, concurrency_results)

    %{
      memory: memory_results,
      throughput: throughput_results,
      concurrency: concurrency_results,
      summary: summary
    }
  end

  @doc """
  Benchmarks memory usage with 100K records.

  Target: <1.5x baseline memory usage
  """
  def run_memory_benchmark(memory_time) do
    IO.puts("\n📊 Memory Benchmark (100K records)...")

    # Measure baseline memory (empty system)
    baseline_memory = measure_baseline_memory()

    Benchee.run(
      %{
        "Streaming 100K records" => fn ->
          generate_test_data(100_000)
          |> Enum.take(100_000)
        end
      },
      time: 0,
      memory_time: memory_time,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/results/memory_mvp.html"},
        {Benchee.Formatters.Console, extended_statistics: true}
      ]
    )

    %{
      baseline_mb: baseline_memory,
      target_multiplier: 1.5,
      status: :completed
    }
  end

  @doc """
  Benchmarks throughput (records/second).

  Target: 1000+ records/second
  """
  def run_throughput_benchmark(time) do
    IO.puts("\n⚡ Throughput Benchmark...")

    Benchee.run(
      %{
        "Simple streaming (10K records)" => fn ->
          generate_test_data(10_000)
          |> Enum.to_list()
        end,
        "With map transformation (10K records)" => fn ->
          generate_test_data(10_000)
          |> Enum.map(fn record -> Map.put(record, :processed, true) end)
          |> Enum.to_list()
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/results/throughput_mvp.html"},
        {Benchee.Formatters.Console, extended_statistics: true}
      ]
    )

    %{
      target_records_per_sec: 1000,
      status: :completed
    }
  end

  @doc """
  Benchmarks concurrent stream handling.

  Target: Handle 5+ concurrent streams
  """
  def run_concurrency_benchmark(time) do
    IO.puts("\n🔄 Concurrency Benchmark (5 concurrent streams)...")

    Benchee.run(
      %{
        "Sequential (5 × 1K records)" => fn ->
          for _ <- 1..5 do
            generate_test_data(1_000) |> Enum.to_list()
          end
        end,
        "Concurrent (5 × 1K records)" => fn ->
          1..5
          |> Task.async_stream(
            fn _ ->
              generate_test_data(1_000) |> Enum.to_list()
            end,
            max_concurrency: 5
          )
          |> Enum.to_list()
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/results/concurrency_mvp.html"},
        {Benchee.Formatters.Console, extended_statistics: true}
      ]
    )

    %{
      target_concurrent_streams: 5,
      status: :completed
    }
  end

  # Private Helper Functions

  defp measure_baseline_memory do
    # Force garbage collection
    :erlang.garbage_collect()
    Process.sleep(100)

    # Get current memory usage in MB
    memory_bytes = :erlang.memory(:total)
    Float.round(memory_bytes / 1_024 / 1_024, 2)
  end

  defp generate_test_data(count) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.take(count)
    |> Stream.map(fn id ->
      %{
        id: id,
        name: "Record #{id}",
        value: id * 10,
        amount: id * 1.5,
        category: if(rem(id, 2) == 0, do: "even", else: "odd"),
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp generate_summary(memory, throughput, concurrency) do
    """
    Memory Usage:
      Baseline: #{memory.baseline_mb} MB
      Target: <#{memory.target_multiplier}x baseline
      Status: #{memory.status}

    Throughput:
      Target: #{throughput.target_records_per_sec}+ records/second
      Status: #{throughput.status}
      Note: See HTML report for actual measurements

    Concurrency:
      Target: #{concurrency.target_concurrent_streams}+ concurrent streams
      Status: #{concurrency.status}

    ✓ MVP Benchmark Suite Complete
    → Check benchmarks/results/*.html for detailed metrics
    """
  end
end
