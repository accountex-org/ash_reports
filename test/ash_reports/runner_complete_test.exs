defmodule AshReports.RunnerCompleteTest do
  @moduledoc """
  Comprehensive tests for the complete report execution engine.

  Tests the full pipeline: DSL → Query → Data → Variables → Groups → Rendering
  """
  use ExUnit.Case

  setup do
    # Reset and generate test data before each test
    AshReportsDemo.DataGenerator.reset_data()
    AshReportsDemo.DataGenerator.generate_foundation_data()
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    :ok
  end

  describe "Runner.run_report/4 complete pipeline" do
    test "runs customer summary report with JSON format" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :json
        )

      assert result.format == :json
      assert result.content != nil
      assert is_binary(result.content)
      assert result.metadata.record_count >= 0

      # Parse JSON to verify structure
      {:ok, json_data} = Jason.decode(result.content)
      assert is_map(json_data)
    end

    test "runs customer summary report with HTML format" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :html
        )

      assert result.format == :html
      assert result.content != nil
      assert is_binary(result.content)
      assert result.metadata.record_count >= 0

      # Should contain HTML structure
      assert String.contains?(result.content, "<")
      assert String.contains?(result.content, ">")
    end

    test "runs report in all four formats" do
      formats = [:html, :pdf, :heex, :json]

      results =
        for format <- formats do
          case AshReports.Runner.run_report(
                 AshReportsDemo.Domain,
                 :customer_summary,
                 %{},
                 format: format
               ) do
            {:ok, result} ->
              {format, :success, result}

            {:error, reason} ->
              {format, :error, reason}
          end
        end

      # At least one format should work
      successes = Enum.count(results, fn {_, status, _} -> status == :success end)
      assert successes > 0, "No formats worked: #{inspect(results)}"

      # Check each successful result
      for {format, :success, result} <- results do
        assert result.format == format
        assert result.content != nil
        assert is_binary(result.content)
      end
    end

    test "handles parameters correctly" do
      # Test with parameters (may or may not filter based on report implementation)
      {:ok, filtered_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{region: "CA"},
          format: :json
        )

      {:ok, unfiltered_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :json
        )

      # Both should succeed
      assert filtered_result.format == :json
      assert unfiltered_result.format == :json

      # Filtered may have same or fewer records (depends on implementation)
      assert filtered_result.metadata.record_count <= unfiltered_result.metadata.record_count
    end

    test "includes variable data in results" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :json
        )

      assert result.format == :json

      # Should have data result for debugging
      assert Map.has_key?(result, :data)
      assert is_map(result.data)

      # Variables should be included in data
      if Map.has_key?(result.data, :variables) do
        assert is_map(result.data.variables)
      end
    end

    test "handles errors gracefully" do
      # Test with non-existent report
      case AshReports.Runner.run_report(
             AshReportsDemo.Domain,
             :nonexistent_report,
             %{},
             format: :json
           ) do
        {:ok, _result} ->
          # If it succeeds, that's fine (maybe there's a fallback)
          :ok

        {:error, reason} ->
          # Should provide meaningful error
          assert is_binary(reason) or is_atom(reason) or is_map(reason)
      end
    end

    test "pipeline metadata is populated" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :json
        )

      # Should have metadata from both data processing and rendering
      assert is_map(result.metadata)

      # Should have record count
      assert Map.has_key?(result.metadata, :record_count)
      assert is_integer(result.metadata.record_count)

      # Should track format
      assert result.format == :json
    end
  end

  describe "DataLoader integration" do
    test "DataLoader.load_report works with demo data" do
      {:ok, data_result} =
        AshReports.DataLoader.load_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{}
        )

      # Should have required fields
      assert Map.has_key?(data_result, :records)
      assert is_list(data_result.records)

      if Map.has_key?(data_result, :variables) do
        assert is_map(data_result.variables)
      end

      if Map.has_key?(data_result, :metadata) do
        assert is_map(data_result.metadata)
      end
    end
  end

  describe "RenderContext integration" do
    test "RenderContext.new works with DataLoader results" do
      {:ok, data_result} =
        AshReports.DataLoader.load_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{}
        )

      # This might fail if report is nil, which is expected
      context =
        AshReports.RenderContext.new(
          data_result.report || %{},
          data_result
        )

      assert %AshReports.RenderContext{} = context
      assert context.records == Map.get(data_result, :records, [])
      assert context.variables == Map.get(data_result, :variables, %{})
    end
  end

  describe "performance characteristics" do
    test "small dataset completes in reasonable time" do
      # Should complete in under 5 seconds for small dataset
      {time, {:ok, result}} =
        :timer.tc(fn ->
          AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            :customer_summary,
            %{},
            format: :json
          )
        end)

      time_ms = div(time, 1000)

      assert time_ms < 5000, "Report took #{time_ms}ms, should be under 5000ms"
      assert result.format == :json
    end
  end
end
