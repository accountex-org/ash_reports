# Streaming Pipeline Performance Benchmarks - MVP
#
# Run with: mix run benchmarks/streaming_pipeline_benchmarks.exs
#
# This MVP benchmark suite focuses on critical performance metrics:
# - Memory usage (100K records)
# - Throughput (records/second)
# - Concurrency (5 concurrent streams)

# Ensure benchmark helpers are loaded
Code.require_file("../test/support/benchmarks/streaming_benchmarks.ex", __DIR__)

alias AshReports.StreamingBenchmarks

IO.puts("\n=== Streaming Pipeline Performance Benchmarks (MVP) ===\n")
IO.puts("This will take approximately 2-3 minutes...\n")

# Run the MVP benchmark suite
results = StreamingBenchmarks.run_mvp_suite()

IO.puts("\n=== Benchmark Complete ===\n")
IO.puts("Results saved to: benchmarks/results/\n")
IO.puts("\nPerformance Summary:")
IO.puts("-------------------")

if results[:summary] do
  IO.puts(results[:summary])
else
  IO.puts("Check HTML reports in benchmarks/results/ for detailed metrics")
end
