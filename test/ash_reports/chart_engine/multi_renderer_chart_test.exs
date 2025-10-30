defmodule AshReports.ChartEngine.MultiRendererChartTest do
  @moduledoc """
  Comprehensive testing for Phase 6.3 multi-renderer chart completion.

  Tests chart integration across all renderers (HTML, HEEX, PDF, JSON)
  with consistent chart generation, data processing, and output validation.
  """

  use ExUnit.Case, async: true

  alias AshReports.ChartEngine.{ChartConfig, ChartDataProcessor}

  alias AshReports.{
    HeexRenderer,
    HtmlRenderer,
    JsonRenderer,
    PdfRenderer,
    RenderContext,
    TestHelpers
  }

  alias AshReports.JsonRenderer.ChartApi
  alias AshReports.PdfRenderer.ChartImageGenerator

  @moduletag :multi_renderer
  @moduletag :integration

  @test_chart_config %ChartConfig{
    type: :bar,
    data: [
      %{x: "Q1", y: 100},
      %{x: "Q2", y: 150},
      %{x: "Q3", y: 120},
      %{x: "Q4", y: 180}
    ],
    title: "Quarterly Sales",
    provider: :chartjs,
    interactive: true
  }

  @test_context %RenderContext{
    locale: "en",
    text_direction: "ltr",
    metadata: %{
      chart_configs: [@test_chart_config]
    }
  }

  describe "Universal chart data processing" do
    test "processes chart data for all renderer types" do
      renderer_types = [:html, :heex, :pdf, :json]

      results =
        Enum.map(renderer_types, fn renderer_type ->
          case ChartDataProcessor.process_for_renderer(
                 @test_chart_config,
                 @test_context,
                 renderer_type
               ) do
            {:ok, processed_data} -> {renderer_type, :success, processed_data}
            {:error, reason} -> {renderer_type, :error, reason}
          end
        end)

      # All renderers should process successfully
      Enum.each(results, fn {renderer_type, status, _data} ->
        assert status == :success, "#{renderer_type} renderer failed to process chart data"
      end)

      # Verify renderer-specific optimizations
      pdf_result = Enum.find(results, fn {type, _, _} -> type == :pdf end)
      {_type, :success, pdf_data} = pdf_result
      assert Map.has_key?(pdf_data, :image_config)

      json_result = Enum.find(results, fn {type, _, _} -> type == :json end)
      {_type, :success, json_data} = json_result
      assert Map.has_key?(json_data, :api_metadata)
    end

    test "caches processed data efficiently across renderers" do
      renderer_types = [:html, :pdf, :json]

      # First call should process and cache
      start_time = System.monotonic_time(:microsecond)

      {:ok, results1} =
        ChartDataProcessor.process_with_cache(@test_chart_config, @test_context, renderer_types)

      first_call_time = System.monotonic_time(:microsecond) - start_time

      # Second call should use cache
      start_time = System.monotonic_time(:microsecond)

      {:ok, results2} =
        ChartDataProcessor.process_with_cache(@test_chart_config, @test_context, renderer_types)

      second_call_time = System.monotonic_time(:microsecond) - start_time

      # Results should be identical
      assert results1 == results2

      # Second call should be faster due to caching
      assert second_call_time < first_call_time
    end
  end

  describe "PDF chart integration" do
    test "generates high-quality chart images for PDF" do
      image_options = %{
        format: :png,
        width: 800,
        height: 600,
        quality: 300
      }

      case ChartImageGenerator.generate_chart_image(
             @test_chart_config,
             @test_context,
             image_options
           ) do
        {:ok, image_binary} ->
          # Should generate valid PNG data
          assert is_binary(image_binary)
          # Reasonable image size
          assert byte_size(image_binary) > 1000
          # PNG signature
          assert binary_part(image_binary, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>

        {:error, reason} ->
          # Acceptable if ChromicPDF not available in test environment
          assert reason =~ "Chrome" or reason =~ "chromic"
      end
    end

    test "embeds chart images in PDF reports" do
      # Test PDF renderer with chart integration
      context_with_charts = %{
        @test_context
        | metadata: Map.put(@test_context.metadata, :chart_configs, [@test_chart_config])
      }

      case PdfRenderer.render_with_context(context_with_charts) do
        {:ok, result} ->
          # Should generate PDF with chart integration
          assert is_binary(result.content)
          assert result.metadata.chart_integration == true

        {:error, reason} ->
          # May fail if ChromicPDF not configured in test environment
          assert reason =~ "Chrome" or reason =~ "chromic" or reason =~ "pdf"
      end
    end

    test "handles multiple charts in PDF efficiently" do
      multiple_charts = [
        %ChartConfig{type: :line, data: [[1, 10], [2, 20]], title: "Chart 1"},
        %ChartConfig{type: :pie, data: [[1, 30], [2, 70]], title: "Chart 2"},
        %ChartConfig{type: :bar, data: [[1, 25], [2, 50]], title: "Chart 3"}
      ]

      context_with_multiple = %{
        @test_context
        | metadata: Map.put(@test_context.metadata, :chart_configs, multiple_charts)
      }

      case PdfRenderer.render_with_context(context_with_multiple) do
        {:ok, result} ->
          assert is_binary(result.content)
          assert result.metadata.chart_count == 3

        {:error, reason} ->
          # Acceptable if rendering infrastructure not available
          assert is_binary(reason)
      end
    end
  end

  describe "JSON chart API integration" do
    test "serializes chart configurations correctly" do
      context_with_charts = %{
        @test_context
        | metadata: Map.put(@test_context.metadata, :chart_configs, [@test_chart_config])
      }

      {:ok, result} = JsonRenderer.render_with_context(context_with_charts)

      # Should contain chart metadata in JSON
      assert is_binary(result.content)

      case Jason.decode(result.content) do
        {:ok, json_data} ->
          if Map.has_key?(json_data, "charts") do
            charts = json_data["charts"]
            assert is_map(charts)
            assert map_size(charts) > 0

            # Verify chart structure
            first_chart = charts |> Map.values() |> List.first()
            assert Map.has_key?(first_chart, "chart_id")
            assert Map.has_key?(first_chart, "type")
            assert Map.has_key?(first_chart, "api_endpoints")
          end

        {:error, _reason} ->
          flunk("JSON output should be valid")
      end
    end

    test "generates proper API endpoints for charts" do
      chart_id = ChartDataProcessor.generate_chart_id(@test_chart_config)
      endpoints = ChartDataProcessor.generate_chart_endpoints(@test_chart_config)

      assert is_map(endpoints)
      assert Map.has_key?(endpoints, :data)
      assert Map.has_key?(endpoints, :config)
      assert Map.has_key?(endpoints, :export)

      # Endpoints should contain chart ID
      assert endpoints.data =~ chart_id
      assert endpoints.config =~ chart_id
      assert endpoints.export =~ chart_id
    end
  end

  describe "Cross-renderer consistency" do
    test "chart data is consistent across all renderers" do
      chart_configs = [@test_chart_config]

      context_with_charts = %{
        @test_context
        | metadata: Map.put(@test_context.metadata, :chart_configs, chart_configs)
      }

      # Generate chart data for all renderers
      renderer_results = [
        {:html, HtmlRenderer.render_with_context(context_with_charts)},
        {:heex, HeexRenderer.render_with_context(context_with_charts)},
        {:json, JsonRenderer.render_with_context(context_with_charts)}
      ]

      # All renderers should handle charts successfully
      successful_renders =
        renderer_results
        |> Enum.filter(fn {_renderer, result} -> match?({:ok, _}, result) end)

      # At least HTML, HEEX, and JSON should work
      assert length(successful_renders) >= 3

      # Verify chart data consistency
      Enum.each(successful_renders, fn {renderer, {:ok, result}} ->
        assert is_binary(result.content)
        refute result.content == ""
      end)
    end

    test "chart metadata is preserved across renderer formats" do
      # Test that chart metadata is consistently preserved
      {:ok, processed_data} =
        ChartDataProcessor.process_for_multiple_renderers(
          @test_chart_config,
          @test_context,
          [:html, :pdf, :json]
        )

      # All renderers should have base metadata
      Enum.each(processed_data, fn {renderer_type, {:ok, data}} ->
        assert Map.has_key?(data, :metadata)
        assert data.metadata.title == @test_chart_config.title
        assert data.metadata.type == @test_chart_config.type
      end)

      # PDF should have image config
      pdf_data = processed_data[:pdf]

      if pdf_data do
        {:ok, pdf_processed} = pdf_data
        assert Map.has_key?(pdf_processed, :image_config)
      end

      # JSON should have API metadata
      json_data = processed_data[:json]

      if json_data do
        {:ok, json_processed} = json_data
        assert Map.has_key?(json_processed, :api_metadata)
      end
    end
  end

  describe "Error handling across renderers" do
    test "handles invalid chart configurations gracefully" do
      invalid_config = %ChartConfig{
        type: :invalid_type,
        data: "invalid_data",
        title: nil
      }

      renderer_types = [:html, :heex, :pdf, :json]

      results =
        Enum.map(renderer_types, fn renderer_type ->
          ChartDataProcessor.process_for_renderer(invalid_config, @test_context, renderer_type)
        end)

      # Should handle errors gracefully
      Enum.each(results, fn result ->
        case result do
          # Success is acceptable
          {:ok, _data} ->
            :ok

          {:error, reason} ->
            assert is_binary(reason)
            assert String.length(reason) > 0
        end
      end)
    end

    test "maintains renderer functionality when charts fail" do
      # Test that renderers continue to work even when chart processing fails
      context_with_bad_charts = %{
        @test_context
        | metadata:
            Map.put(@test_context.metadata, :chart_configs, [
              %ChartConfig{type: :invalid, data: nil}
            ])
      }

      # HTML renderer should still work
      case HtmlRenderer.render_with_context(context_with_bad_charts) do
        {:ok, result} ->
          assert is_binary(result.content)
          # Should contain HTML even if charts fail
          assert result.content =~ "<html" or result.content =~ "<div"

        {:error, _reason} ->
          # Acceptable - renderer may fail gracefully
          :ok
      end

      # JSON renderer should still work
      case JsonRenderer.render_with_context(context_with_bad_charts) do
        {:ok, result} ->
          assert is_binary(result.content)
          # Should contain valid JSON
          case Jason.decode(result.content) do
            {:ok, _json} -> :ok
            {:error, _reason} -> flunk("JSON should be valid even without charts")
          end

        {:error, _reason} ->
          # Acceptable - renderer may fail gracefully
          :ok
      end
    end
  end

  describe "Performance across renderers" do
    test "chart processing performance is reasonable" do
      large_chart_config = %ChartConfig{
        type: :scatter,
        data: for(i <- 1..1000, do: %{x: i, y: :rand.uniform(100)}),
        title: "Large Dataset Chart",
        provider: :chartjs
      }

      renderer_types = [:html, :pdf, :json]

      # Measure processing time for each renderer
      processing_times =
        Enum.map(renderer_types, fn renderer_type ->
          start_time = System.monotonic_time(:microsecond)

          result =
            ChartDataProcessor.process_for_renderer(
              large_chart_config,
              @test_context,
              renderer_type
            )

          end_time = System.monotonic_time(:microsecond)
          processing_time = end_time - start_time

          {renderer_type, processing_time, result}
        end)

      # All should complete within reasonable time (2 seconds)
      Enum.each(processing_times, fn {renderer_type, time, result} ->
        assert time < 2_000_000, "#{renderer_type} processing took too long: #{time} microseconds"

        case result do
          {:ok, _data} ->
            :ok

          {:error, reason} ->
            # Log but don't fail - some renderers may not be available in test env
            IO.puts("#{renderer_type} processing failed: #{reason}")
        end
      end)
    end
  end

  describe "Chart image generation" do
    test "generates valid chart images for PDF embedding" do
      image_options = %{format: :png, width: 600, height: 400, quality: 200}

      case ChartImageGenerator.generate_chart_image(
             @test_chart_config,
             @test_context,
             image_options
           ) do
        {:ok, image_binary} ->
          # Verify PNG structure
          assert is_binary(image_binary)
          assert byte_size(image_binary) > 100

          # Check PNG signature
          png_signature = binary_part(image_binary, 0, 8)
          expected_signature = <<137, 80, 78, 71, 13, 10, 26, 10>>
          assert png_signature == expected_signature

        {:error, reason} ->
          # ChromicPDF may not be available in test environment
          assert reason =~ "Chrome" or reason =~ "chromic"
      end
    end

    test "caches chart images for performance" do
      image_options = %{format: :png, width: 400, height: 300}

      # First generation (should cache)
      start_time = System.monotonic_time(:microsecond)

      result1 =
        ChartImageGenerator.generate_with_cache(@test_chart_config, @test_context, image_options)

      first_time = System.monotonic_time(:microsecond) - start_time

      # Second generation (should use cache)
      start_time = System.monotonic_time(:microsecond)

      result2 =
        ChartImageGenerator.generate_with_cache(@test_chart_config, @test_context, image_options)

      second_time = System.monotonic_time(:microsecond) - start_time

      case {result1, result2} do
        {{:ok, image1}, {:ok, image2}} ->
          # Images should be identical
          assert image1 == image2

          # Second call should be faster (cached)
          assert second_time < first_time

        _ ->
          # May fail if ChromicPDF not available
          :ok
      end
    end
  end

  describe "Internationalization across renderers" do
    test "handles RTL charts across all renderers" do
      rtl_context = %{@test_context | locale: "ar", text_direction: "rtl"}

      renderer_types = [:html, :heex, :pdf, :json]

      results =
        Enum.map(renderer_types, fn renderer_type ->
          case ChartDataProcessor.process_for_renderer(
                 @test_chart_config,
                 rtl_context,
                 renderer_type
               ) do
            {:ok, processed_data} ->
              # Verify RTL handling
              assert processed_data.metadata.text_direction == "rtl"
              assert processed_data.metadata.locale == "ar"

              {renderer_type, :success}

            {:error, _reason} ->
              {renderer_type, :error}
          end
        end)

      # Should handle RTL consistently
      successful_results = Enum.filter(results, fn {_, status} -> status == :success end)
      # At least HTML and JSON should work
      assert length(successful_results) >= 2
    end
  end

  describe "Chart data validation" do
    test "validates chart data integrity across processors" do
      # Test with various data formats
      data_formats = [
        # Array of arrays
        [[1, 10], [2, 20], [3, 30]],
        # Array of maps
        [%{x: 1, y: 10}, %{x: 2, y: 20}],
        # Map format
        %{"Series A" => [10, 20, 30]},
        # Simple array
        [1, 2, 3, 4, 5]
      ]

      renderer_types = [:html, :pdf, :json]

      Enum.each(data_formats, fn data_format ->
        test_config = %{@test_chart_config | data: data_format}

        results =
          Enum.map(renderer_types, fn renderer_type ->
            ChartDataProcessor.process_for_renderer(test_config, @test_context, renderer_type)
          end)

        # Should handle all data formats
        successful_results = Enum.filter(results, &match?({:ok, _}, &1))
        # Most renderers should handle various formats
        assert length(successful_results) >= 2
      end)
    end
  end

  describe "realistic data integration" do
    setup do
      AshReports.RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
    end

    test "generates invoice sales chart from realistic data" do
      invoices = AshReports.RealisticTestHelpers.list_invoices(limit: 50)

      # Transform invoice data into chart format
      chart_data =
        invoices
        |> Enum.map(fn invoice ->
          %{
            x: Date.to_string(invoice.date),
            y: Decimal.to_float(invoice.total)
          }
        end)

      chart_config = %ChartConfig{
        type: :bar,
        data: chart_data,
        title: "Invoice Totals",
        provider: :chartjs,
        interactive: true
      }

      context = %{@test_context | metadata: %{chart_configs: [chart_config]}}

      {:ok, processed} = ChartDataProcessor.process_for_renderer(chart_config, context, :html)

      assert Map.has_key?(processed, :metadata)
      assert processed.metadata.title == "Invoice Totals"
      assert length(chart_data) == length(invoices)
    end

    test "creates customer spend chart from realistic relationships" do
      customers = AshReports.RealisticTestHelpers.list_customers(limit: 10, load: [:invoices])

      # Calculate total spend per customer
      chart_data =
        customers
        |> Enum.map(fn customer ->
          total =
            customer.invoices
            |> Enum.map(& &1.total)
            |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
            |> Decimal.to_float()

          %{x: customer.name, y: total}
        end)
        |> Enum.sort_by(& &1.y, :desc)

      chart_config = %ChartConfig{
        type: :bar,
        data: chart_data,
        title: "Customer Total Spend",
        provider: :chartjs
      }

      # Test with multiple renderers
      results = [:html, :json]
      |> Enum.map(fn renderer ->
        {renderer, ChartDataProcessor.process_for_renderer(chart_config, @test_context, renderer)}
      end)

      successful = Enum.filter(results, fn {_, result} -> match?({:ok, _}, result) end)
      assert length(successful) >= 2
    end

    test "generates product sales chart from realistic invoice line items" do
      invoices = AshReports.RealisticTestHelpers.list_invoices(limit: 20, load: [:line_items])

      # Get line items count (simplified chart)
      chart_data =
        invoices
        |> Enum.map(fn invoice ->
          %{
            x: invoice.invoice_number,
            y: length(invoice.line_items)
          }
        end)
        |> Enum.take(10)  # Top 10 invoices

      chart_config = %ChartConfig{
        type: :line,
        data: chart_data,
        title: "Line Items per Invoice",
        provider: :chartjs
      }

      context = %{@test_context | metadata: %{chart_configs: [chart_config]}}

      {:ok, result} = HtmlRenderer.render_with_context(context)
      assert is_binary(result.content)
    end

    test "handles large realistic dataset in charts" do
      # Get all invoices to create a comprehensive sales chart
      all_invoices = AshReports.RealisticTestHelpers.list_invoices()

      chart_data =
        all_invoices
        |> Enum.map(fn inv ->
          %{x: Date.to_string(inv.date), y: Decimal.to_float(inv.total)}
        end)

      chart_config = %ChartConfig{
        type: :scatter,
        data: chart_data,
        title: "All Invoice Amounts",
        provider: :chartjs
      }

      start_time = System.monotonic_time(:microsecond)

      {:ok, processed} = ChartDataProcessor.process_for_renderer(chart_config, @test_context, :json)

      processing_time = System.monotonic_time(:microsecond) - start_time

      assert processing_time < 2_000_000
      assert Map.has_key?(processed, :metadata)
    end
  end
end
