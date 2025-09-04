#!/usr/bin/env elixir

# Simple test to check current Runner functionality
IO.puts("Starting test...")

# Generate test data
IO.puts("Resetting data...")
AshReportsDemo.DataGenerator.reset_data()

IO.puts("Generating foundation data...")
AshReportsDemo.DataGenerator.generate_foundation_data()

IO.puts("Generating sample data...")
AshReportsDemo.DataGenerator.generate_sample_data(:small)

IO.puts("Attempting to run report...")

# Try to run a report
case AshReports.Runner.run_report(AshReportsDemo.Domain, :customer_summary, %{}, format: :json) do
  {:ok, result} -> 
    IO.puts("SUCCESS: Got result with format #{inspect(result.format)}")
    IO.puts("Metadata keys: #{inspect(Map.keys(result.metadata))}")
    if result.content do
      content_length = String.length(result.content)
      IO.puts("Content length: #{content_length} chars")
      if content_length > 0 and content_length < 1000 do
        IO.puts("Content preview: #{String.slice(result.content, 0, 200)}...")
      end
    else
      IO.puts("No content in result")
    end
  {:error, reason} -> 
    IO.puts("ERROR: #{inspect(reason)}")
end

IO.puts("Test complete.")