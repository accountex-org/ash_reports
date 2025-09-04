#!/usr/bin/env elixir

# Test script to check PDF and HEEX renderer functionality

IO.puts("Testing PDF and HEEX renderers...")

# Generate test data
IO.puts("Setting up test data...")
AshReportsDemo.DataGenerator.reset_data()
AshReportsDemo.DataGenerator.generate_foundation_data()
AshReportsDemo.DataGenerator.generate_sample_data(:small)

formats_to_test = [:pdf, :heex, :html, :json]

for format <- formats_to_test do
  IO.puts("\n=== Testing #{format} renderer ===")
  
  case AshReports.Runner.run_report(AshReportsDemo.Domain, :customer_summary, %{}, format: format) do
    {:ok, result} -> 
      IO.puts("✅ #{format} SUCCESS")
      IO.puts("  Format: #{inspect(result.format)}")
      IO.puts("  Content length: #{String.length(result.content || "")} chars")
      IO.puts("  Record count: #{Map.get(result.metadata, :record_count, 0)}")
      IO.puts("  Execution time: #{Map.get(result.metadata, :execution_time_ms, 0)}ms")
      
      # Check content type
      cond do
        format == :json and String.starts_with?(result.content, "{") ->
          IO.puts("  ✅ Valid JSON content detected")
        format == :html and String.contains?(result.content, "<html") ->
          IO.puts("  ✅ Valid HTML content detected")
        format == :heex and is_binary(result.content) ->
          IO.puts("  ✅ HEEX content generated")
        format == :pdf and is_binary(result.content) ->
          IO.puts("  ✅ PDF content generated")
        true ->
          IO.puts("  ⚠️  Content format unclear")
      end
      
    {:error, reason} -> 
      IO.puts("❌ #{format} FAILED: #{inspect(reason)}")
  end
end

IO.puts("\nRenderer testing complete.")