#!/usr/bin/env elixir

# Test specific renderer functionality
IO.puts("Testing specific renderer functions...")

# Generate test data first
AshReportsDemo.DataGenerator.reset_data()
AshReportsDemo.DataGenerator.generate_foundation_data()
AshReportsDemo.DataGenerator.generate_sample_data(:small)

# Get data to test renderers directly
{:ok, data_result} = AshReports.DataLoader.load_report(AshReportsDemo.Domain, :customer_summary, %{})
context = AshReports.RenderContext.new(data_result.report || %{}, data_result)

IO.puts("Data result available: #{Map.keys(data_result) |> inspect}")
IO.puts("Context created: #{context.__struct__}")

# Test each renderer directly
renderers = [
  {:html, AshReports.HtmlRenderer},
  {:json, AshReports.JsonRenderer}, 
  {:heex, AshReports.HeexRenderer},
  {:pdf, AshReports.PdfRenderer}
]

for {format, renderer_module} <- renderers do
  IO.puts("\n=== Testing #{format} renderer directly ===")
  
  try do
    case renderer_module.render_with_context(context, []) do
      {:ok, result} ->
        IO.puts("✅ #{format} Direct SUCCESS")
        IO.puts("  Content length: #{String.length(result.content || "")} chars")
        if result.metadata do
          IO.puts("  Has metadata: #{Map.keys(result.metadata) |> length} keys")
        end
        
      {:error, reason} ->
        IO.puts("❌ #{format} Direct FAILED: #{inspect(reason)}")
    end
  rescue
    error ->
      IO.puts("❌ #{format} Direct EXCEPTION: #{Exception.message(error)}")
      IO.puts("  Exception type: #{error.__struct__}")
  end
end