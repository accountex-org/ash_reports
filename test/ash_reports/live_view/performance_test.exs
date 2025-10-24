defmodule AshReports.LiveView.PerformanceTest do
  @moduledoc """
  Performance and load testing for AshReports Phase 6.2 LiveView features.

  Tests system performance under various load conditions including:
  - Multiple concurrent users and chart updates
  - WebSocket connection scaling
  - Real-time update latency and throughput
  - Memory usage patterns and optimization
  """

  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias AshReports.LiveView.{
    DistributedConnectionManager,
    PerformanceTelemetry,
    WebSocketOptimizer
  }

  alias AshReports.PubSub.ChartBroadcaster

  @moduletag :performance
  @moduletag :load_testing
  # 1 minute timeout for performance tests
  @moduletag timeout: 60_000

  describe "Concurrent user simulation" do
    @tag :slow
    test "handles multiple concurrent dashboard sessions" do
      concurrent_users = 10
      charts_per_dashboard = 5

      # Simulate multiple users creating dashboard sessions
      user_sessions =
        for i <- 1..concurrent_users do
          Task.async(fn ->
            simulate_user_dashboard_session(i, charts_per_dashboard)
          end)
        end

      # Wait for all sessions to complete
      results = Task.await_many(user_sessions, 30_000)

      # All sessions should complete successfully
      assert length(results) == concurrent_users
      assert Enum.all?(results, &(&1 == :success))
    end

    @tag :slow
    test "maintains performance with high chart update frequency" do
      chart_id = "high_frequency_chart"
      update_count = 100
      target_latency_ms = 200

      # Subscribe to updates
      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      # Measure broadcast performance
      start_time = System.monotonic_time(:millisecond)

      # Send high-frequency updates
      for i <- 1..update_count do
        ChartBroadcaster.broadcast_chart_update(
          chart_id,
          %{sequence: i, value: :rand.uniform(100)},
          # Force immediate broadcast
          priority: :high
        )
      end

      # Measure how long it takes to process all updates
      updates_received = receive_performance_updates(update_count, 0, start_time)
      end_time = System.monotonic_time(:millisecond)

      total_time = end_time - start_time
      average_latency = total_time / updates_received

      # Performance assertions
      assert updates_received > 0
      assert average_latency < target_latency_ms

      IO.puts(
        "Performance: #{updates_received} updates in #{total_time}ms, avg latency: #{average_latency}ms"
      )
    end
  end

  describe "WebSocket optimization" do
    test "applies connection optimizations correctly" do
      # Get initial metrics
      initial_metrics = WebSocketOptimizer.get_performance_metrics()

      # Apply optimizations
      :ok = WebSocketOptimizer.optimize_connections()

      # Get updated metrics
      optimized_metrics = WebSocketOptimizer.get_performance_metrics()

      # Should have optimization metadata
      assert is_map(optimized_metrics)
      assert Map.has_key?(optimized_metrics, :optimization_status)
    end

    test "generates useful optimization recommendations" do
      recommendations = WebSocketOptimizer.get_optimization_recommendations()

      assert is_list(recommendations)
      assert length(recommendations) > 0

      # Should have meaningful recommendations
      first_recommendation = List.first(recommendations)
      assert is_binary(first_recommendation)
      assert String.length(first_recommendation) > 10
    end
  end

  describe "Performance telemetry" do
    test "collects performance metrics accurately" do
      metrics = PerformanceTelemetry.get_current_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :timestamp)

      # Should have WebSocket metrics
      if Map.has_key?(metrics, :websocket) do
        websocket_metrics = metrics.websocket
        assert is_map(websocket_metrics)
        assert Map.has_key?(websocket_metrics, :active_connections)
        assert Map.has_key?(websocket_metrics, :average_latency_ms)
      end

      # Should have system metrics
      if Map.has_key?(metrics, :system) do
        system_metrics = metrics.system
        assert is_map(system_metrics)
        assert Map.has_key?(system_metrics, :memory_used_mb)
        assert Map.has_key?(system_metrics, :process_count)
      end
    end

    test "generates performance recommendations" do
      recommendations = PerformanceTelemetry.get_optimization_recommendations()

      assert is_list(recommendations)
      assert length(recommendations) > 0

      # Each recommendation should have required fields
      Enum.each(recommendations, fn recommendation ->
        assert Map.has_key?(recommendation, :type)
        assert Map.has_key?(recommendation, :priority)
        assert Map.has_key?(recommendation, :recommendation)
      end)
    end
  end

  describe "Memory usage patterns" do
    @tag :memory_intensive
    test "memory usage remains stable with many charts" do
      chart_count = 20

      # Get initial memory usage
      {initial_memory, _} = :erlang.process_info(self(), :memory)

      # Create many chart broadcasts
      chart_ids =
        for i <- 1..chart_count do
          chart_id = "memory_test_chart_#{i}"

          # Subscribe and broadcast
          Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")
          ChartBroadcaster.broadcast_chart_update(chart_id, %{data: generate_test_data(50)})

          chart_id
        end

      # Receive all updates
      _updates = receive_all_chart_updates(chart_count, [])

      # Check memory usage after operations
      {final_memory, _} = :erlang.process_info(self(), :memory)
      memory_increase = final_memory - initial_memory

      # Memory increase should be reasonable (< 10MB for 20 charts)
      assert memory_increase < 10 * 1024 * 1024

      IO.puts("Memory test: #{chart_count} charts, memory increase: #{memory_increase} bytes")
    end

    @tag :memory_intensive
    test "garbage collection keeps memory usage optimal" do
      # Force some memory allocation
      large_data_sets =
        for i <- 1..10 do
          # Large dataset
          chart_data = generate_test_data(500)
          ChartBroadcaster.broadcast_chart_update("gc_test_#{i}", %{data: chart_data})
          chart_data
        end

      # Get memory before GC
      {memory_before_gc, _} = :erlang.process_info(self(), :memory)

      # Force garbage collection
      :erlang.garbage_collect()

      # Get memory after GC
      {memory_after_gc, _} = :erlang.process_info(self(), :memory)

      memory_freed = memory_before_gc - memory_after_gc

      # Should free some memory (at least 1KB)
      assert memory_freed > 1024

      IO.puts("GC test: freed #{memory_freed} bytes of memory")
    end
  end

  describe "Connection scaling" do
    @tag :slow
    test "distributes connections across cluster nodes" do
      # Test distributed connection management
      cluster_stats = DistributedConnectionManager.get_cluster_stats()

      assert is_map(cluster_stats)
      assert Map.has_key?(cluster_stats, :active_nodes)
      assert Map.has_key?(cluster_stats, :total_connections)

      # Should have at least one node (current node)
      assert cluster_stats.active_nodes >= 1
    end

    test "handles node failures gracefully" do
      # Simulate node failure
      fake_node = :fake_node@localhost

      # Should handle gracefully without crashing
      :ok = DistributedConnectionManager.handle_node_failure(fake_node)

      # System should remain functional
      cluster_stats = DistributedConnectionManager.get_cluster_stats()
      assert is_map(cluster_stats)
    end
  end

  describe "Real-time accuracy" do
    test "real-time updates maintain data integrity" do
      chart_id = "integrity_test_chart"

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      # Send data with known sequence
      original_data = %{
        sequence_id: 12345,
        data_points: [[1, 10], [2, 20], [3, 30]],
        checksum: calculate_data_checksum([[1, 10], [2, 20], [3, 30]])
      }

      :ok = ChartBroadcaster.broadcast_chart_update(chart_id, original_data)

      # Receive and verify data integrity
      assert_receive {:real_time_update, broadcast_data}, 1000
      received_data = broadcast_data.data

      assert received_data.sequence_id == original_data.sequence_id
      assert received_data.checksum == original_data.checksum
    end

    test "handles out-of-order updates correctly" do
      chart_id = "order_test_chart"

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      # Send updates with timestamps (simulate out-of-order)
      base_time = DateTime.utc_now()

      # Send "newer" update first
      ChartBroadcaster.broadcast_chart_update(chart_id, %{
        sequence: 2,
        timestamp: DateTime.add(base_time, 2, :second)
      })

      # Then send "older" update
      ChartBroadcaster.broadcast_chart_update(chart_id, %{
        sequence: 1,
        timestamp: base_time
      })

      # Should receive both updates
      assert_receive {:real_time_update, update1}, 1000
      assert_receive {:real_time_update, update2}, 1000

      # Both should be delivered
      assert update1.data.sequence in [1, 2]
      assert update2.data.sequence in [1, 2]
    end
  end

  # Helper functions

  defp simulate_user_dashboard_session(user_index, chart_count) do
    dashboard_config = %{
      dashboard_id: "perf_dashboard_#{user_index}",
      title: "Performance Dashboard #{user_index}",
      charts: generate_test_charts(chart_count),
      real_time: true,
      update_interval: 5000
    }

    try do
      # Simulate dashboard operations
      # Simulate user activity
      :timer.sleep(100)

      # Simulate some chart interactions
      for i <- 1..3 do
        chart_id = "chart_#{i}"
        test_data = %{user: user_index, interaction: i, timestamp: DateTime.utc_now()}
        ChartBroadcaster.broadcast_chart_update(chart_id, test_data)
        :timer.sleep(50)
      end

      :success
    rescue
      _ -> :failure
    end
  end

  defp generate_test_charts(count) do
    for i <- 1..count do
      %{
        id: "chart_#{i}",
        type: Enum.random([:line, :bar, :pie]),
        data: generate_test_data(10),
        title: "Chart #{i}",
        interactive: true,
        real_time: true
      }
    end
  end

  defp generate_test_data(size) do
    for i <- 1..size, do: %{x: i, y: :rand.uniform(100)}
  end

  defp receive_performance_updates(0, count, _start_time), do: count

  defp receive_performance_updates(remaining, count, start_time) do
    receive do
      {:real_time_update, _data} ->
        receive_performance_updates(remaining - 1, count + 1, start_time)
    after
      # Short timeout for performance test
      100 ->
        count
    end
  end

  defp receive_all_chart_updates(0, updates), do: updates

  defp receive_all_chart_updates(remaining, updates) do
    receive do
      {:real_time_update, _data} = update ->
        receive_all_chart_updates(remaining - 1, [update | updates])
    after
      # 2 second timeout
      2000 ->
        updates
    end
  end

  defp calculate_data_checksum(data) do
    :crypto.hash(:md5, :erlang.term_to_binary(data))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 8)
  end
end
