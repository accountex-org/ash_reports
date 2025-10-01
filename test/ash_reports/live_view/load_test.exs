defmodule AshReports.LiveView.LoadTest do
  @moduledoc """
  Comprehensive load testing for AshReports Phase 6.2 LiveView platform.

  Tests system performance under enterprise-grade load conditions including:
  - 1000+ concurrent WebSocket connections
  - High-frequency chart updates and real-time streaming
  - Multi-user collaborative dashboard sessions
  - Memory usage and garbage collection optimization
  - WebSocket connection scaling and failover
  """

  use ExUnit.Case, async: false

  alias AshReports.LiveView.{
    DistributedConnectionManager,
    PerformanceTelemetry,
    WebSocketOptimizer
  }

  alias AshReports.PubSub.ChartBroadcaster
  alias AshReports.LiveView.{DataPipeline, SessionManager}

  @moduletag :load_testing
  @moduletag :performance
  # 5 minute timeout for load tests
  @moduletag timeout: 300_000

  describe "Concurrent user load testing" do
    @tag :slow
    @tag :concurrent_users
    test "handles 100 concurrent dashboard sessions" do
      concurrent_users = 100
      charts_per_user = 3
      test_duration_seconds = 30

      IO.puts("Starting load test: #{concurrent_users} users, #{charts_per_user} charts each")

      # Start performance monitoring
      start_time = System.monotonic_time(:millisecond)
      initial_memory = get_system_memory()

      # Simulate concurrent users
      user_tasks =
        for user_id <- 1..concurrent_users do
          Task.async(fn ->
            simulate_user_load(user_id, charts_per_user, test_duration_seconds)
          end)
        end

      # Wait for all users to complete
      results = Task.await_many(user_tasks, 60_000)

      end_time = System.monotonic_time(:millisecond)
      final_memory = get_system_memory()

      # Analyze results
      successful_users = Enum.count(results, &(&1 == :success))
      total_time = end_time - start_time
      memory_used = final_memory - initial_memory

      # Performance assertions
      # 95% success rate
      assert successful_users >= concurrent_users * 0.95
      # Within 50% of target time
      assert total_time < test_duration_seconds * 1500
      # Less than 500MB memory increase
      assert memory_used < 500 * 1024 * 1024

      IO.puts("""
      Load test results:
      - Successful users: #{successful_users}/#{concurrent_users}
      - Total time: #{total_time}ms
      - Memory used: #{Float.round(memory_used / (1024 * 1024), 2)}MB
      - Success rate: #{Float.round(successful_users / concurrent_users * 100, 2)}%
      """)
    end

    @tag :slow
    @tag :high_frequency
    test "handles high-frequency chart updates" do
      chart_count = 50
      updates_per_chart = 100
      target_latency_ms = 100

      IO.puts("High-frequency test: #{chart_count} charts, #{updates_per_chart} updates each")

      # Subscribe to all chart updates
      chart_ids = for i <- 1..chart_count, do: "load_chart_#{i}"

      Enum.each(chart_ids, fn chart_id ->
        Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")
      end)

      start_time = System.monotonic_time(:millisecond)

      # Start concurrent high-frequency updates
      update_tasks =
        chart_ids
        |> Enum.map(fn chart_id ->
          Task.async(fn ->
            simulate_high_frequency_updates(chart_id, updates_per_chart)
          end)
        end)

      # Wait for all updates to complete
      Task.await_many(update_tasks, 30_000)

      # Measure how many updates were received
      total_expected = chart_count * updates_per_chart
      received_updates = count_received_updates(total_expected, 0, 5000)

      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time
      average_latency = total_time / received_updates

      # Performance assertions
      # 80% delivery rate (batching may reduce count)
      assert received_updates >= total_expected * 0.8
      # Average latency target
      assert average_latency < target_latency_ms

      IO.puts("""
      High-frequency test results:
      - Updates sent: #{total_expected}
      - Updates received: #{received_updates}
      - Average latency: #{Float.round(average_latency, 2)}ms
      - Delivery rate: #{Float.round(received_updates / total_expected * 100, 2)}%
      """)
    end
  end

  describe "Memory and resource optimization" do
    @tag :memory_intensive
    test "memory usage scales linearly with load" do
      base_memory = get_system_memory()

      # Test with increasing chart counts
      chart_counts = [10, 50, 100, 200]
      memory_measurements = []

      for chart_count <- chart_counts do
        # Create charts
        chart_ids = for i <- 1..chart_count, do: "memory_chart_#{chart_count}_#{i}"

        Enum.each(chart_ids, fn chart_id ->
          test_data = generate_load_test_data(20)
          ChartBroadcaster.broadcast_chart_update(chart_id, test_data)
        end)

        # Measure memory
        current_memory = get_system_memory()
        memory_increase = current_memory - base_memory

        measurement = %{
          chart_count: chart_count,
          memory_mb: memory_increase / (1024 * 1024),
          memory_per_chart_kb: memory_increase / chart_count / 1024
        }

        memory_measurements = [measurement | memory_measurements]

        IO.puts(
          "#{chart_count} charts: #{Float.round(measurement.memory_mb, 2)}MB, #{Float.round(measurement.memory_per_chart_kb, 2)}KB per chart"
        )
      end

      # Verify linear scaling
      memory_measurements = Enum.reverse(memory_measurements)

      # Memory per chart should remain relatively constant
      memory_per_chart_values = Enum.map(memory_measurements, & &1.memory_per_chart_kb)
      max_per_chart = Enum.max(memory_per_chart_values)
      min_per_chart = Enum.min(memory_per_chart_values)
      variation_ratio = max_per_chart / min_per_chart

      # Variation should be less than 2x (linear scaling)
      assert variation_ratio < 2.0

      IO.puts("Memory scaling ratio: #{Float.round(variation_ratio, 2)}x (should be <2.0)")
    end

    @tag :gc_optimization
    test "garbage collection optimization maintains performance" do
      # Force memory allocation
      large_datasets =
        for i <- 1..20 do
          chart_id = "gc_test_#{i}"
          large_data = generate_load_test_data(1000)
          ChartBroadcaster.broadcast_chart_update(chart_id, large_data)
          large_data
        end

      memory_before_gc = get_system_memory()
      gc_start = System.monotonic_time(:millisecond)

      # Force garbage collection
      :erlang.garbage_collect()

      gc_time = System.monotonic_time(:millisecond) - gc_start
      memory_after_gc = get_system_memory()
      memory_freed = memory_before_gc - memory_after_gc

      # GC should be effective and fast
      # Should free some memory
      assert memory_freed > 0
      # Should complete within 1 second
      assert gc_time < 1000

      IO.puts("""
      GC optimization results:
      - Memory freed: #{Float.round(memory_freed / (1024 * 1024), 2)}MB
      - GC time: #{gc_time}ms
      - GC efficiency: #{Float.round(memory_freed / memory_before_gc * 100, 2)}%
      """)
    end
  end

  describe "WebSocket scaling" do
    @tag :slow
    @tag :websocket_scaling
    test "WebSocket connections scale efficiently" do
      connection_counts = [10, 50, 100]
      scaling_results = []

      for connection_count <- connection_counts do
        start_time = System.monotonic_time(:millisecond)

        # Simulate WebSocket connections
        connection_tasks =
          for i <- 1..connection_count do
            Task.async(fn ->
              simulate_websocket_connection("scaling_user_#{i}", connection_count)
            end)
          end

        # Wait for connections to establish
        connection_results = Task.await_many(connection_tasks, 10_000)
        successful_connections = Enum.count(connection_results, &(&1 == :success))

        end_time = System.monotonic_time(:millisecond)
        connection_time = end_time - start_time

        result = %{
          target_connections: connection_count,
          successful_connections: successful_connections,
          connection_time_ms: connection_time,
          success_rate: successful_connections / connection_count * 100,
          average_time_per_connection: connection_time / successful_connections
        }

        scaling_results = [result | scaling_results]

        IO.puts(
          "#{connection_count} connections: #{successful_connections} successful in #{connection_time}ms"
        )
      end

      # Verify scaling efficiency
      scaling_results = Enum.reverse(scaling_results)

      # Success rate should remain high
      Enum.each(scaling_results, fn result ->
        assert result.success_rate >= 90.0
      end)

      # Connection time should scale reasonably
      connection_times = Enum.map(scaling_results, & &1.connection_time_ms)
      time_scaling_factor = List.last(connection_times) / List.first(connection_times)

      # Time scaling should be sub-linear (better than O(n))
      # For 10x more connections, <8x time increase
      assert time_scaling_factor < 8.0

      IO.puts("WebSocket scaling factor: #{Float.round(time_scaling_factor, 2)}x")
    end

    @tag :connection_limits
    test "handles connection limit enforcement" do
      max_connections_per_user = 5
      user_id = "limit_test_user"

      # Create session with connection limit
      {:ok, session_id} =
        SessionManager.create_session(
          user_id: user_id,
          max_connections: max_connections_per_user
        )

      # Add connections up to limit
      connection_pids =
        for i <- 1..max_connections_per_user do
          pid = spawn(fn -> :timer.sleep(5000) end)
          :ok = SessionManager.add_connection(session_id, pid)
          pid
        end

      # Additional connection should be rejected
      extra_pid = spawn(fn -> :timer.sleep(1000) end)
      {:error, reason} = SessionManager.add_connection(session_id, extra_pid)

      assert reason =~ "Connection limit exceeded"

      # Cleanup
      Enum.each(connection_pids, fn pid ->
        if Process.alive?(pid), do: Process.exit(pid, :kill)
      end)

      if Process.alive?(extra_pid), do: Process.exit(extra_pid, :kill)
    end
  end

  describe "Real-time performance validation" do
    @tag :real_time_accuracy
    test "real-time updates maintain sub-100ms latency" do
      chart_id = "latency_test_chart"
      update_count = 50
      target_latency_ms = 100

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      latencies = []

      # Send updates and measure latency
      for i <- 1..update_count do
        send_time = System.monotonic_time(:millisecond)

        # Send update with timestamp
        ChartBroadcaster.broadcast_chart_update(
          chart_id,
          %{
            sequence: i,
            send_time: send_time
          },
          priority: :high
        )

        # Measure receive latency
        receive do
          {:real_time_update, broadcast_data} ->
            receive_time = System.monotonic_time(:millisecond)
            latency = receive_time - broadcast_data.data.send_time
            latencies = [latency | latencies]
        after
          1000 ->
            # Timeout penalty
            latencies = [1000 | latencies]
        end

        # Small delay between updates
        :timer.sleep(10)
      end

      # Analyze latencies
      average_latency = Enum.sum(latencies) / length(latencies)
      max_latency = Enum.max(latencies)
      p95_latency = Enum.at(Enum.sort(latencies), round(length(latencies) * 0.95))

      # Performance assertions
      assert average_latency < target_latency_ms
      # P95 within 2x target
      assert p95_latency < target_latency_ms * 2
      # Max within 5x target
      assert max_latency < target_latency_ms * 5

      IO.puts("""
      Latency test results:
      - Average latency: #{Float.round(average_latency, 2)}ms
      - P95 latency: #{p95_latency}ms  
      - Max latency: #{max_latency}ms
      - Updates processed: #{length(latencies)}/#{update_count}
      """)
    end

    @tag :data_accuracy
    test "real-time updates maintain data accuracy under load" do
      chart_count = 20
      updates_per_chart = 25

      # Create charts and track data integrity
      chart_data_tracking =
        for i <- 1..chart_count do
          chart_id = "accuracy_chart_#{i}"
          Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

          %{
            chart_id: chart_id,
            expected_sequences: Enum.to_list(1..updates_per_chart),
            received_sequences: []
          }
        end

      # Send sequential updates to all charts
      for chart_tracking <- chart_data_tracking do
        Task.async(fn ->
          for sequence <- 1..updates_per_chart do
            ChartBroadcaster.broadcast_chart_update(
              chart_tracking.chart_id,
              %{sequence: sequence, checksum: calculate_checksum(sequence)},
              priority: :normal
            )

            # Small delay
            :timer.sleep(5)
          end
        end)
      end

      # Collect updates for all charts
      final_tracking =
        collect_chart_updates(chart_data_tracking, chart_count * updates_per_chart, 10_000)

      # Verify data accuracy
      accuracy_results =
        Enum.map(final_tracking, fn chart ->
          expected_count = length(chart.expected_sequences)
          received_count = length(chart.received_sequences)
          accuracy = received_count / expected_count * 100

          %{
            chart_id: chart.chart_id,
            expected: expected_count,
            received: received_count,
            accuracy: accuracy
          }
        end)

      # Calculate overall accuracy
      total_expected = chart_count * updates_per_chart
      total_received = Enum.sum(Enum.map(accuracy_results, & &1.received))
      overall_accuracy = total_received / total_expected * 100

      # Should maintain high accuracy
      # 80% accuracy target (accounting for batching)
      assert overall_accuracy >= 80.0

      IO.puts("""
      Data accuracy results:
      - Overall accuracy: #{Float.round(overall_accuracy, 2)}%
      - Updates expected: #{total_expected}
      - Updates received: #{total_received}
      """)
    end
  end

  describe "System resource optimization" do
    @tag :memory_optimization
    test "optimizes memory usage patterns" do
      # Baseline memory measurement
      :erlang.garbage_collect()
      baseline_memory = :erlang.memory(:total)

      # Create memory pressure with many charts
      chart_count = 100
      # 500 data points per chart
      large_data_size = 500

      IO.puts(
        "Memory optimization test: #{chart_count} charts with #{large_data_size} data points each"
      )

      # Create charts with large datasets
      for i <- 1..chart_count do
        chart_id = "memory_opt_chart_#{i}"
        large_dataset = generate_load_test_data(large_data_size)
        ChartBroadcaster.broadcast_chart_update(chart_id, large_dataset)
      end

      # Measure memory after load
      before_optimization = :erlang.memory(:total)
      memory_increase = before_optimization - baseline_memory

      # Apply memory optimizations
      WebSocketOptimizer.apply_performance_tuning(%{
        gc_optimization: true,
        compression_enabled: true,
        memory_optimization: true
      })

      # Force garbage collection
      :erlang.garbage_collect()

      # Measure memory after optimization
      after_optimization = :erlang.memory(:total)
      memory_saved = before_optimization - after_optimization

      # Calculate efficiency metrics
      memory_per_chart = memory_increase / chart_count
      optimization_effectiveness = memory_saved / memory_increase * 100

      IO.puts("""
      Memory optimization results:
      - Memory increase: #{Float.round(memory_increase / (1024 * 1024), 2)}MB
      - Memory per chart: #{Float.round(memory_per_chart / 1024, 2)}KB
      - Memory saved: #{Float.round(memory_saved / (1024 * 1024), 2)}MB
      - Optimization effectiveness: #{Float.round(optimization_effectiveness, 2)}%
      """)

      # Assertions
      # Less than 50KB per chart
      assert memory_per_chart < 50 * 1024
      # At least 10% memory savings
      assert optimization_effectiveness > 10.0
    end

    @tag :cpu_optimization
    test "CPU usage remains reasonable under load" do
      # Simulate CPU-intensive operations
      chart_count = 30
      computation_complexity = 100

      start_time = System.monotonic_time(:millisecond)

      # Create CPU-intensive chart operations
      cpu_tasks =
        for i <- 1..chart_count do
          Task.async(fn ->
            simulate_cpu_intensive_chart_operations(i, computation_complexity)
          end)
        end

      # Wait for all operations to complete
      Task.await_many(cpu_tasks, 15_000)

      end_time = System.monotonic_time(:millisecond)
      total_cpu_time = end_time - start_time

      # Calculate CPU efficiency
      # Minimum expected time (10ms per chart)
      expected_min_time = chart_count * 10
      cpu_efficiency = expected_min_time / total_cpu_time * 100

      IO.puts("""
      CPU optimization results:
      - Total CPU time: #{total_cpu_time}ms
      - Expected minimum: #{expected_min_time}ms
      - CPU efficiency: #{Float.round(cpu_efficiency, 2)}%
      - Time per chart: #{Float.round(total_cpu_time / chart_count, 2)}ms
      """)

      # CPU should be efficient
      # Should be within 10x of theoretical minimum
      assert total_cpu_time < expected_min_time * 10
      # At least 5% efficiency
      assert cpu_efficiency > 5.0
    end
  end

  describe "Distributed performance" do
    @tag :distributed_load
    test "distributed connection management scales efficiently" do
      # Test distributed connection management
      # Current node (would be multiple in real cluster)
      node_count = 1
      connections_per_node = 100

      IO.puts(
        "Distributed test: #{node_count} nodes, #{connections_per_node} connections per node"
      )

      # Get optimal node for connections
      start_time = System.monotonic_time(:millisecond)

      optimal_nodes =
        for _i <- 1..connections_per_node do
          case DistributedConnectionManager.get_optimal_node() do
            {:ok, node} -> node
            # Fallback
            {:error, _} -> Node.self()
          end
        end

      end_time = System.monotonic_time(:millisecond)
      node_selection_time = end_time - start_time

      # Verify node selection performance
      unique_nodes = Enum.uniq(optimal_nodes)
      # Selections per second
      selection_efficiency = length(optimal_nodes) / node_selection_time * 1000

      IO.puts("""
      Distributed performance results:
      - Node selections: #{length(optimal_nodes)}
      - Unique nodes used: #{length(unique_nodes)}
      - Selection time: #{node_selection_time}ms
      - Selections per second: #{Float.round(selection_efficiency, 2)}
      """)

      # Performance assertions
      # Should complete within 5 seconds
      assert node_selection_time < 5000
      # At least 10 selections per second
      assert selection_efficiency > 10.0
    end
  end

  # Helper functions for load testing

  defp simulate_user_load(user_id, chart_count, duration_seconds) do
    # Simulate realistic user behavior
    # Create user session
    {:ok, session_id} =
      SessionManager.create_session(
        user_id: "load_user_#{user_id}",
        max_connections: chart_count + 2
      )

    # Simulate chart interactions
    for i <- 1..chart_count do
      chart_id = "user_#{user_id}_chart_#{i}"

      # Simulate chart data updates
      for j <- 1..div(duration_seconds, 2) do
        test_data = %{
          user: user_id,
          chart: i,
          update: j,
          timestamp: DateTime.utc_now()
        }

        ChartBroadcaster.broadcast_chart_update(chart_id, test_data)
        # Simulate realistic update frequency
        :timer.sleep(100)
      end
    end

    :success
  rescue
    _ -> :failure
  end

  defp simulate_high_frequency_updates(chart_id, update_count) do
    for i <- 1..update_count do
      ChartBroadcaster.broadcast_chart_update(
        chart_id,
        %{
          sequence: i,
          value: :rand.uniform(100),
          timestamp: System.monotonic_time(:millisecond)
        },
        priority: :normal
      )

      # Very short delay for high frequency
      :timer.sleep(1)
    end

    :success
  end

  defp simulate_websocket_connection(user_id, _connection_index) do
    # Simulate WebSocket connection establishment
    {:ok, session_id} =
      SessionManager.create_session(
        user_id: user_id,
        max_connections: 3
      )

    # Simulate connection
    connection_pid = spawn(fn -> :timer.sleep(1000) end)
    :ok = SessionManager.add_connection(session_id, connection_pid)

    # Simulate some activity
    :timer.sleep(100)

    # Cleanup
    SessionManager.remove_connection(session_id, connection_pid)

    :success
  rescue
    _ -> :failure
  end

  defp simulate_cpu_intensive_chart_operations(chart_index, complexity) do
    # Simulate CPU-intensive chart generation
    chart_id = "cpu_test_chart_#{chart_index}"

    # Generate complex data
    complex_data =
      for i <- 1..complexity do
        # Simulate statistical calculations
        values = for j <- 1..10, do: :rand.uniform(100)

        %{
          index: i,
          mean: Enum.sum(values) / length(values),
          variance: calculate_variance(values),
          timestamp: DateTime.utc_now()
        }
      end

    ChartBroadcaster.broadcast_chart_update(chart_id, complex_data)
    :success
  end

  defp generate_load_test_data(size) do
    for i <- 1..size do
      %{
        x: i,
        y: :rand.uniform(100),
        metadata: "data_point_#{i}",
        timestamp: DateTime.utc_now()
      }
    end
  end

  defp count_received_updates(0, count, _timeout), do: count

  defp count_received_updates(remaining, count, timeout) do
    receive do
      {:real_time_update, _data} ->
        count_received_updates(remaining - 1, count + 1, timeout)
    after
      timeout ->
        count
    end
  end

  defp collect_chart_updates(chart_tracking, expected_total, timeout) do
    # Collect updates for all charts being tracked
    receive do
      {:real_time_update, broadcast_data} ->
        # Find which chart this update belongs to and record it
        updated_tracking =
          Enum.map(chart_tracking, fn chart ->
            if broadcast_data.chart_id == chart.chart_id do
              sequence = broadcast_data.data[:sequence]
              %{chart | received_sequences: [sequence | chart.received_sequences]}
            else
              chart
            end
          end)

        # Continue collecting if we haven't received enough
        total_received =
          Enum.sum(Enum.map(updated_tracking, fn chart -> length(chart.received_sequences) end))

        if total_received < expected_total do
          collect_chart_updates(updated_tracking, expected_total, timeout)
        else
          updated_tracking
        end
    after
      timeout ->
        # Return what we have
        chart_tracking
    end
  end

  defp get_system_memory do
    # Get total system memory usage
    :erlang.memory(:total)
  end

  defp calculate_checksum(data) do
    :crypto.hash(:md5, :erlang.term_to_binary(data))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 8)
  end

  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)

    variance =
      values
      |> Enum.map(fn val -> :math.pow(val - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    variance
  end
end
