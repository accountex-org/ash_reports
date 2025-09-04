#!/usr/bin/env elixir

# Test renderers that don't require external dependencies
IO.puts("Testing HTML, JSON, and HEEX renderers (excluding PDF)...")

# Generate test data first
AshReportsDemo.DataGenerator.reset_data()
AshReportsDemo.DataGenerator.generate_foundation_data()
AshReportsDemo.DataGenerator.generate_sample_data(:small)

formats_to_test = [:html, :json, :heex]

for format <- formats_to_test do
  IO.puts("\n=== Testing #{format} format via Runner ===")
  
  case AshReports.Runner.run_report(AshReportsDemo.Domain, :customer_summary, %{}, format: format) do
    {:ok, result} -> 
      IO.puts("✅ #{format} SUCCESS")
      IO.puts("  Format: #{inspect(result.format)}")
      content_length = String.length(result.content || "")
      IO.puts("  Content length: #{content_length} chars")
      IO.puts("  Record count: #{Map.get(result.metadata, :record_count, 0)}")
      IO.puts("  Execution time: #{Map.get(result.metadata, :execution_time_ms, 0)}ms")
      IO.puts("  Pipeline version: #{Map.get(result.metadata, :pipeline_version, "N/A")}")
      
      # Check content characteristics
      cond do
        format == :json && content_length > 0 ->
          case Jason.decode(result.content) do
            {:ok, _} -> IO.puts("  ✅ Valid JSON content")
            {:error, _} -> IO.puts("  ⚠️  Invalid JSON content")
          end
        format == :html && String.contains?(result.content, "<") ->
          IO.puts("  ✅ HTML content detected")
        format == :heex && content_length > 0 ->
          IO.puts("  ✅ HEEX template content generated")
        true ->
          IO.puts("  ⚠️  Content format needs verification")
      end
      
      if content_length > 0 && content_length < 500 do
        IO.puts("  Content preview: #{String.slice(result.content, 0, 200)}...")
      end
      
    {:error, reason} -> 
      IO.puts("❌ #{format} FAILED")
      IO.puts("  Reason: #{inspect(reason)}")
  end
end

IO.puts("\n=== Summary ===")
IO.puts("PDF renderer requires Chrome/Chromium installation for ChromicPDF dependency")
IO.puts("Other renderers should work without external dependencies")
IO.puts("Test completed.")