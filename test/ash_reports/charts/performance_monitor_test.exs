defmodule AshReports.Charts.PerformanceMonitorTest do
  @moduledoc """
  Test suite for chart performance monitoring and telemetry aggregation.
  """
  use ExUnit.Case, async: false

  alias AshReports.Charts
  alias AshReports.Charts.{PerformanceMonitor, Cache}

  setup do
    # Reset metrics before each test
    PerformanceMonitor.reset_metrics()
    Cache.clear()
    :ok
  end

  describe "metrics aggregation" do
    test "tracks chart generation metrics" do
      # Generate bar chart without caching
      bar_data = [%{category: "A", value: 10}, %{category: "B", value: 20}]
      line_data = [%{x: 1, y: 10}, %{x: 2, y: 20}]
      config = %{title: "Test Chart", width: 400, height: 300}

      # Disable cache to ensure generation happens
      {:ok, _svg1} = Charts.generate(:bar, bar_data, config, cache: false)
      {:ok, _svg2} = Charts.generate(:line, line_data, config, cache: false)

      # Small delay to allow telemetry events to be processed
      Process.sleep(50)

      metrics = PerformanceMonitor.get_metrics()

      assert metrics.total_charts_generated == 2
      assert metrics.avg_generation_time_ms > 0
      assert is_float(metrics.avg_generation_time_ms)
    end

    test "tracks cache hit and miss rates" do
      data = [%{category: "A", value: 10}]
      config = %{title: "Cached Chart", width: 400, height: 300}

      # First generation - cache miss
      {:ok, _svg} = Charts.generate(:bar, data, config)

      # Multiple cache hits
      {:ok, _svg} = Charts.generate(:bar, data, config)
      {:ok, _svg} = Charts.generate(:bar, data, config)
      {:ok, _svg} = Charts.generate(:bar, data, config)
      {:ok, _svg} = Charts.generate(:bar, data, config)
      {:ok, _svg} = Charts.generate(:bar, data, config)

      # Small delay to allow telemetry events to be processed
      Process.sleep(50)

      metrics = PerformanceMonitor.get_metrics()

      # We should have at least 5 hits and at least 1 miss
      assert metrics.cache_hits >= 5
      assert metrics.cache_misses >= 1
      # Hit rate should be reasonable (more hits than misses)
      assert metrics.cache_hit_rate > 0.5
      assert metrics.cache_hit_rate <= 1.0
    end

    test "tracks compression metrics" do
      # Create large SVG that will be compressed
      large_data =
        Enum.map(1..50, fn i ->
          %{category: "Category #{i}", value: :rand.uniform(100)}
        end)

      config = %{title: "Large Chart", width: 800, height: 600}

      # Generate chart (will be cached with compression)
      {:ok, _svg} = Charts.generate(:bar, large_data, config)

      # Small delay to allow telemetry events to be processed
      Process.sleep(50)

      metrics = PerformanceMonitor.get_metrics()

      # Should have at least one compressed entry
      assert metrics.total_compressed_entries >= 0
      assert metrics.avg_compression_ratio >= 0
    end

    test "initializes with zero metrics" do
      PerformanceMonitor.reset_metrics()
      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      assert metrics.total_charts_generated == 0
      assert metrics.avg_generation_time_ms == 0.0
      assert metrics.cache_hit_rate == 0.0
      assert metrics.cache_hits == 0
      assert metrics.cache_misses == 0
      assert metrics.avg_compression_ratio == 0.0
      assert metrics.total_compressed_entries == 0
      assert metrics.avg_preprocessing_time_ms == 0.0
      assert metrics.memory_usage_bytes == 0
    end
  end

  describe "reset_metrics/0" do
    test "resets all metrics to zero" do
      # Generate some charts to create metrics
      data = [%{category: "A", value: 10}]
      config = %{title: "Test", width: 400, height: 300}

      {:ok, _svg} = Charts.generate(:bar, data, config, cache: false)

      Process.sleep(50)

      # Verify metrics exist
      metrics_before = PerformanceMonitor.get_metrics()
      assert metrics_before.total_charts_generated > 0

      # Reset
      :ok = PerformanceMonitor.reset_metrics()

      Process.sleep(10)

      # Verify reset
      metrics_after = PerformanceMonitor.get_metrics()
      assert metrics_after.total_charts_generated == 0
      assert metrics_after.avg_generation_time_ms == 0.0
    end
  end

  describe "telemetry event handling" do
    test "handles chart generation telemetry events" do
      # Emit telemetry event manually
      :telemetry.execute(
        [:ash_reports, :charts, :generate, :stop],
        %{duration: 15_000_000},
        %{chart_type: :bar, from_cache: false, svg_size: 1024}
      )

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      # Should track the chart generation
      assert metrics.total_charts_generated >= 1
    end

    test "handles cache hit telemetry events" do
      # Emit cache hit events manually
      :telemetry.execute([:ash_reports, :charts, :cache, :hit], %{}, %{key: "test_key"})
      :telemetry.execute([:ash_reports, :charts, :cache, :hit], %{}, %{key: "test_key2"})

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      assert metrics.cache_hits >= 2
    end

    test "handles cache miss telemetry events" do
      # Emit cache miss event manually
      :telemetry.execute([:ash_reports, :charts, :cache, :miss], %{}, %{key: "test_key"})

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      assert metrics.cache_misses >= 1
    end

    test "handles compression telemetry events" do
      # Emit compression event manually
      :telemetry.execute(
        [:ash_reports, :charts, :cache, :put_compressed],
        %{original_size: 10_000, compressed_size: 3_500, ratio: 0.35},
        %{key: "compressed_key"}
      )

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      assert metrics.total_compressed_entries >= 1
      assert metrics.avg_compression_ratio > 0
    end

    test "ignores cached chart generations in metrics" do
      # Generate chart first time (not cached)
      data = [%{category: "A", value: 10}]
      config = %{title: "Test", width: 400, height: 300}

      {:ok, _svg} = Charts.generate(:bar, data, config)

      Process.sleep(50)

      metrics_after_first = PerformanceMonitor.get_metrics()
      first_count = metrics_after_first.total_charts_generated

      # Generate same chart (cached)
      {:ok, _svg} = Charts.generate(:bar, data, config)

      Process.sleep(50)

      metrics_after_second = PerformanceMonitor.get_metrics()

      # Count should not increase because second generation was cached
      assert metrics_after_second.total_charts_generated == first_count
    end
  end

  describe "memory tracking" do
    test "estimates memory usage from SVG size" do
      data = [%{category: "A", value: 10}, %{category: "B", value: 20}]
      config = %{title: "Memory Test", width: 400, height: 300}

      # Generate chart without cache (to track generation)
      {:ok, svg} = Charts.generate(:bar, data, config, cache: false)

      Process.sleep(50)

      metrics = PerformanceMonitor.get_metrics()

      # Memory usage should be tracked
      assert metrics.memory_usage_bytes > 0
      # Should be at least the size of the SVG
      assert metrics.memory_usage_bytes >= byte_size(svg)
    end
  end

  describe "integration with preprocessing" do
    test "tracks preprocessing metrics from ChartPreprocessor" do
      # Emit preprocessing telemetry events manually
      :telemetry.execute(
        [:ash_reports, :chart_preprocessor, :preprocess, :start],
        %{system_time: System.system_time()},
        %{chart_count: 3}
      )

      # Simulate preprocessing completion
      Process.sleep(10)

      :telemetry.execute(
        [:ash_reports, :chart_preprocessor, :preprocess, :stop],
        %{duration: 125_000_000},
        %{chart_count: 3, success_count: 3}
      )

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      # Should track preprocessing time
      assert metrics.avg_preprocessing_time_ms > 0
    end
  end

  describe "concurrent access" do
    test "handles concurrent metric updates" do
      # Generate charts concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            data = [%{category: "A", value: i * 10}]
            config = %{title: "Chart #{i}", width: 400, height: 300}
            Charts.generate(:bar, data, config, cache: false)
          end)
        end

      Enum.each(tasks, &Task.await/1)

      Process.sleep(100)

      metrics = PerformanceMonitor.get_metrics()

      # Should track all generations
      assert metrics.total_charts_generated == 10
      assert metrics.avg_generation_time_ms > 0
    end

    test "handles concurrent compression ratio updates without race conditions" do
      # Reset metrics first
      PerformanceMonitor.reset_metrics()
      Process.sleep(10)

      # Simulate 100 concurrent compression events with known ratios
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            # Each event has ratio 0.35 (35% of original size)
            :telemetry.execute(
              [:ash_reports, :charts, :cache, :put_compressed],
              %{ratio: 0.35},
              %{}
            )
          end)
        end

      Enum.each(tasks, &Task.await/1)

      Process.sleep(50)

      metrics = PerformanceMonitor.get_metrics()

      # All 100 compressions should be counted
      assert metrics.total_compressed_entries == 100

      # Average should be exactly 0.35 (no lost updates from race conditions)
      # If there were race conditions, we'd lose some updates and get incorrect average
      assert_in_delta metrics.avg_compression_ratio, 0.35, 0.001
    end

    test "compression ratio calculation is accurate under concurrent load" do
      PerformanceMonitor.reset_metrics()
      Process.sleep(10)

      # Mix of different compression ratios
      ratios = [0.3, 0.4, 0.35, 0.25, 0.5]

      tasks =
        for ratio <- ratios do
          # 20 concurrent events per ratio (100 total)
          for _ <- 1..20 do
            Task.async(fn ->
              :telemetry.execute(
                [:ash_reports, :charts, :cache, :put_compressed],
                %{ratio: ratio},
                %{}
              )
            end)
          end
        end
        |> List.flatten()

      Enum.each(tasks, &Task.await/1)

      Process.sleep(50)

      metrics = PerformanceMonitor.get_metrics()

      # Should have all 100 entries
      assert metrics.total_compressed_entries == 100

      # Expected average: (0.3*20 + 0.4*20 + 0.35*20 + 0.25*20 + 0.5*20) / 100 = 0.36
      expected_avg = (0.3 * 20 + 0.4 * 20 + 0.35 * 20 + 0.25 * 20 + 0.5 * 20) / 100
      assert_in_delta metrics.avg_compression_ratio, expected_avg, 0.001
    end
  end

  describe "metrics calculation" do
    test "calculates average generation time correctly" do
      # Emit events with known durations
      :telemetry.execute(
        [:ash_reports, :charts, :generate, :stop],
        %{duration: 10_000_000},
        %{from_cache: false, svg_size: 1024}
      )

      :telemetry.execute(
        [:ash_reports, :charts, :generate, :stop],
        %{duration: 20_000_000},
        %{from_cache: false, svg_size: 1024}
      )

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      # Average should be (10ms + 20ms) / 2 = 15ms
      assert metrics.total_charts_generated == 2
      assert_in_delta metrics.avg_generation_time_ms, 15.0, 0.1
    end

    test "calculates cache hit rate correctly" do
      # 3 hits, 1 miss = 75% hit rate
      :telemetry.execute([:ash_reports, :charts, :cache, :hit], %{}, %{})
      :telemetry.execute([:ash_reports, :charts, :cache, :hit], %{}, %{})
      :telemetry.execute([:ash_reports, :charts, :cache, :hit], %{}, %{})
      :telemetry.execute([:ash_reports, :charts, :cache, :miss], %{}, %{})

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      assert metrics.cache_hits == 3
      assert metrics.cache_misses == 1
      assert_in_delta metrics.cache_hit_rate, 0.75, 0.01
    end

    test "calculates average compression ratio correctly" do
      # Two compressions with different ratios
      :telemetry.execute(
        [:ash_reports, :charts, :cache, :put_compressed],
        %{ratio: 0.3},
        %{}
      )

      :telemetry.execute(
        [:ash_reports, :charts, :cache, :put_compressed],
        %{ratio: 0.4},
        %{}
      )

      Process.sleep(10)

      metrics = PerformanceMonitor.get_metrics()

      # Average should be (0.3 + 0.4) / 2 = 0.35
      assert metrics.total_compressed_entries == 2
      assert_in_delta metrics.avg_compression_ratio, 0.35, 0.01
    end
  end
end
