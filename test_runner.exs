#!/usr/bin/env elixir

# Test script to check current Runner functionality

# Generate some test data first
AshReportsDemo.DataGenerator.reset_data()
AshReportsDemo.DataGenerator.generate_foundation_data()
AshReportsDemo.DataGenerator.generate_sample_data(:small)

# Try to run a report
case AshReports.Runner.run_report(AshReportsDemo.Domain, :customer_summary, %{}, format: :json) do
  {:ok, result} -> 
    IO.puts "SUCCESS: Got result with format #{inspect(result.format)}"
    IO.puts "Metadata: #{inspect(result.metadata)}"
    IO.puts "Content length: #{String.length(result.content || "")} chars"
  {:error, reason} -> 
    IO.puts "ERROR: #{inspect(reason)}"
end