defmodule AshReports.Integration.PerformanceIntegrationTest do
  @moduledoc """
  Performance benchmarking tests for AshReports Phase 4 integration.

  Uses Benchee to measure the performance impact of Phase 4 features
  and ensure they meet acceptable performance criteria.
  """

  use ExUnit.Case

  alias AshReports.Integration.{BenchmarkHelpers, TestHelpers}
  alias AshReports.{HeexRenderer, HtmlRenderer, JsonRenderer, PdfRenderer}

  @moduletag :benchmark
  @moduletag :performance
  # 5 minutes for performance tests
  @moduletag timeout: 300_000

  describe "Phase 4 Performance Benchmarks" do
    @tag :slow
    test "benchmark Phase 4 feature impact vs baseline" do
      results = BenchmarkHelpers.run_phase4_benchmark()

      # Validate performance criteria
      case BenchmarkHelpers.validate_performance_criteria(results) do
        {:ok, message} ->
          IO.puts("✅ Performance validation passed: #{message}")

        {:error, message} ->
          flunk("❌ Performance validation failed: #{message}")
      end

      # Generate performance report
      report = BenchmarkHelpers.create_performance_report(results)
      File.write("tmp/phase4_performance_report.md", report)

      IO.puts("📊 Performance report generated: tmp/phase4_performance_report.md")
    end

    @tag :slow
    test "multi-renderer performance comparison" do
      results = BenchmarkHelpers.multi_renderer_benchmark()

      scenarios = results.scenarios

      # All renderers should complete within reasonable time
      Enum.each(scenarios, fn scenario ->
        time_ms = scenario.run_time_data.statistics.average / 1_000_000
        max_time = BenchmarkHelpers.performance_limits().max_render_time_ms

        assert time_ms <= max_time,
               "#{scenario.name} took #{Float.round(time_ms, 2)}ms (limit: #{max_time}ms)"
      end)

      # Memory usage should be reasonable
      Enum.each(scenarios, fn scenario ->
        if scenario.memory_usage_data do
          memory_mb = scenario.memory_usage_data.statistics.average / (1024 * 1024)
          max_memory = BenchmarkHelpers.performance_limits().max_memory_mb

          assert memory_mb <= max_memory,
                 "#{scenario.name} used #{Float.round(memory_mb, 2)}MB memory (limit: #{max_memory}MB)"
        end
      end)
    end

    @tag :slow
    test "locale scalability performance" do
      results = BenchmarkHelpers.locale_scalability_benchmark()

      scenarios = results.scenarios

      # Performance should not degrade significantly with different locales
      execution_times =
        scenarios
        |> Enum.map(fn scenario ->
          {scenario.name, scenario.run_time_data.statistics.average / 1_000_000}
        end)

      {_slowest_name, slowest_time} = Enum.max_by(execution_times, fn {_, time} -> time end)
      {_fastest_name, fastest_time} = Enum.min_by(execution_times, fn {_, time} -> time end)

      # Slowest locale should not be more than 2x slower than fastest
      performance_variance = slowest_time / fastest_time

      assert performance_variance <= 2.0,
             "Locale performance variance too high: #{Float.round(performance_variance, 2)}x (limit: 2.0x)"

      IO.puts("📈 Locale performance variance: #{Float.round(performance_variance, 2)}x")
    end

    @tag :slow
    test "data size scalability benchmark" do
      results = BenchmarkHelpers.data_size_benchmark()

      scenarios = results.scenarios

      time_by_size =
        scenarios
        |> Enum.map(fn scenario ->
          size =
            case scenario.name do
              "small_dataset_10" -> 10
              "medium_dataset_100" -> 100
              "large_dataset_1000" -> 1000
            end

          time_ms = scenario.run_time_data.statistics.average / 1_000_000
          {size, time_ms}
        end)
        |> Enum.sort_by(fn {size, _} -> size end)

      # Check if scaling is reasonable (should be roughly linear)
      [{small_size, small_time}, {medium_size, medium_time}, {large_size, large_time}] =
        time_by_size

      # Medium should not be more than 15x slower than small (10x data + overhead)
      small_to_medium_ratio = medium_time / small_time
      expected_medium_ratio = medium_size / small_size

      assert small_to_medium_ratio <= expected_medium_ratio * 1.5,
             "Medium dataset performance degradation too high: #{Float.round(small_to_medium_ratio, 2)}x vs expected ~#{expected_medium_ratio}x"

      # Large should not be more than 15x slower than medium
      medium_to_large_ratio = large_time / medium_time
      expected_large_ratio = large_size / medium_size

      assert medium_to_large_ratio <= expected_large_ratio * 1.5,
             "Large dataset performance degradation too high: #{Float.round(medium_to_large_ratio, 2)}x vs expected ~#{expected_large_ratio}x"

      IO.puts("📊 Scaling performance:")
      IO.puts("  Small (#{small_size}): #{Float.round(small_time, 2)}ms")

      IO.puts(
        "  Medium (#{medium_size}): #{Float.round(medium_time, 2)}ms (#{Float.round(small_to_medium_ratio, 2)}x)"
      )

      IO.puts(
        "  Large (#{large_size}): #{Float.round(large_time, 2)}ms (#{Float.round(medium_to_large_ratio, 2)}x)"
      )
    end
  end

  describe "Phase 4 Component Performance" do
    @tag :component_performance
    test "CLDR formatting performance impact" do
      # Compare CLDR formatting vs basic formatting
      baseline_data = TestHelpers.create_multilingual_test_data()

      scenarios = %{
        "basic_number_formatting" => fn ->
          Enum.map(baseline_data, fn customer ->
            "ID: #{customer.id}, Amount: #{:erlang.float_to_binary(123.45, decimals: 2)}"
          end)
        end,
        "cldr_number_formatting" => fn ->
          Enum.map(baseline_data, fn customer ->
            {:ok, formatted} = AshReports.Cldr.format_number(123.45, "en")
            "ID: #{customer.id}, Amount: #{formatted}"
          end)
        end,
        "cldr_currency_formatting" => fn ->
          Enum.map(baseline_data, fn customer ->
            {:ok, formatted} = AshReports.Cldr.format_currency(123.45, "en", "USD")
            "ID: #{customer.id}, Amount: #{formatted}"
          end)
        end
      }

      results = BenchmarkHelpers.run_benchmark(scenarios, "tmp/cldr_component_benchmarks.html")

      # CLDR should not be more than 2x slower than basic formatting
      baseline = Enum.find(results.scenarios, &(&1.name == "basic_number_formatting"))
      cldr_number = Enum.find(results.scenarios, &(&1.name == "cldr_number_formatting"))

      if baseline && cldr_number do
        ratio =
          cldr_number.run_time_data.statistics.average / baseline.run_time_data.statistics.average

        assert ratio <= 2.0,
               "CLDR number formatting too slow: #{Float.round(ratio, 2)}x vs baseline"
      end
    end

    @tag :component_performance
    test "RTL layout engine performance" do
      data = TestHelpers.create_arabic_test_data()

      scenarios = %{
        "ltr_layout_processing" => fn ->
          _context = TestHelpers.create_integration_context("en")

          Enum.map(data, fn customer ->
            # Simulate basic LTR processing
            %{customer | name: String.reverse(customer.name)}
          end)
        end,
        "rtl_layout_processing" => fn ->
          context = TestHelpers.create_rtl_context("ar")

          Enum.map(data, fn customer ->
            {:ok, adapted} = AshReports.RtlLayoutEngine.adapt_text_content(customer.name, context)
            %{customer | name: adapted}
          end)
        end
      }

      results = BenchmarkHelpers.run_benchmark(scenarios, "tmp/rtl_component_benchmarks.html")

      # RTL processing should not be more than 3x slower than LTR
      ltr = Enum.find(results.scenarios, &(&1.name == "ltr_layout_processing"))
      rtl = Enum.find(results.scenarios, &(&1.name == "rtl_layout_processing"))

      if ltr && rtl do
        ratio = rtl.run_time_data.statistics.average / ltr.run_time_data.statistics.average
        assert ratio <= 3.0, "RTL layout processing too slow: #{Float.round(ratio, 2)}x vs LTR"
      end
    end

    @tag :component_performance
    test "translation system performance" do
      scenarios = %{
        "direct_text_processing" => fn ->
          keys = ["report.title", "field.name", "field.email", "total.amount"]

          Enum.map(keys, fn key ->
            String.replace(key, ".", "_") |> String.upcase()
          end)
        end,
        "translation_processing" => fn ->
          keys = ["report.title", "field.name", "field.email", "total.amount"]

          Enum.map(keys, fn key ->
            AshReports.Translation.translate_ui(key, [], "en")
          end)
        end,
        "multilingual_translation" => fn ->
          keys = ["report.title", "field.name", "field.email", "total.amount"]
          locales = ["en", "ar", "es"]

          for locale <- locales, key <- keys do
            AshReports.Translation.translate_ui(key, [], locale)
          end
        end
      }

      results =
        BenchmarkHelpers.run_benchmark(scenarios, "tmp/translation_component_benchmarks.html")

      # Translation should not be more than 5x slower than direct processing
      direct = Enum.find(results.scenarios, &(&1.name == "direct_text_processing"))
      translation = Enum.find(results.scenarios, &(&1.name == "translation_processing"))

      if direct && translation do
        ratio =
          translation.run_time_data.statistics.average / direct.run_time_data.statistics.average

        assert ratio <= 5.0,
               "Translation processing too slow: #{Float.round(ratio, 2)}x vs direct"
      end
    end
  end

  describe "Memory Usage Profiling" do
    @tag :memory_profiling
    test "Phase 4 memory usage patterns" do
      # Test memory usage with different Phase 4 configurations
      test_scenarios = [
        %{name: "baseline", context_fn: fn -> TestHelpers.create_integration_context("en") end},
        %{name: "cldr_only", context_fn: fn -> TestHelpers.create_cldr_context("en") end},
        %{name: "rtl_only", context_fn: fn -> TestHelpers.create_rtl_context("ar") end},
        %{name: "full_phase4", context_fn: fn -> TestHelpers.create_full_phase4_context("ar") end}
      ]

      memory_results =
        Enum.map(test_scenarios, fn scenario ->
          {result, memory_used} =
            TestHelpers.measure_memory_usage(fn ->
              context = scenario.context_fn.()
              report = TestHelpers.build_phase4_enhanced_report()
              data = TestHelpers.create_multilingual_test_data()

              AshReports.HtmlRenderer.render_with_context(%{context | report: report, data: data})
            end)

          {scenario.name, memory_used, result}
        end)

      # Verify memory usage is reasonable
      Enum.each(memory_results, fn {name, memory_used, _result} ->
        memory_mb = memory_used / (1024 * 1024)
        max_memory = BenchmarkHelpers.performance_limits().max_memory_mb

        assert memory_mb <= max_memory,
               "#{name} used #{Float.round(memory_mb, 2)}MB memory (limit: #{max_memory}MB)"
      end)

      # Log memory usage patterns
      IO.puts("🧠 Memory usage by scenario:")

      Enum.each(memory_results, fn {name, memory_used, _} ->
        memory_mb = memory_used / (1024 * 1024)
        IO.puts("  #{name}: #{Float.round(memory_mb, 2)}MB")
      end)
    end
  end

  describe "Concurrent Performance" do
    @tag :concurrent_performance
    @tag :slow
    test "concurrent rendering performance" do
      # Test how Phase 4 performs under concurrent load
      report = TestHelpers.build_phase4_enhanced_report()

      contexts = [
        TestHelpers.create_full_phase4_context("en"),
        TestHelpers.create_full_phase4_context("ar"),
        TestHelpers.create_full_phase4_context("es"),
        TestHelpers.create_full_phase4_context("fr")
      ]

      # Measure sequential vs concurrent performance
      sequential_time =
        :timer.tc(fn ->
          Enum.each(contexts, fn context ->
            data = TestHelpers.create_multilingual_test_data()
            AshReports.HtmlRenderer.render_with_context(%{context | report: report, data: data})
          end)
        end)
        |> elem(0)

      concurrent_time =
        :timer.tc(fn ->
          contexts
          |> Task.async_stream(
            fn context ->
              data = TestHelpers.create_multilingual_test_data()
              AshReports.HtmlRenderer.render_with_context(%{context | report: report, data: data})
            end,
            max_concurrency: 4
          )
          |> Enum.to_list()
        end)
        |> elem(0)

      # Concurrent should be faster than sequential for multiple cores
      improvement_ratio = sequential_time / concurrent_time

      # Should see at least some improvement (>1.2x) due to concurrency
      assert improvement_ratio >= 1.2,
             "Concurrent rendering not faster than sequential: #{Float.round(improvement_ratio, 2)}x"

      IO.puts("🚀 Concurrent performance improvement: #{Float.round(improvement_ratio, 2)}x")
    end
  end
end
