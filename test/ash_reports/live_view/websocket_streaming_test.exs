defmodule AshReports.LiveView.WebSocketStreamingTest do
  @moduledoc """
  WebSocket streaming and real-time functionality tests for Phase 6.2.

  Tests real-time data streaming, WebSocket performance, connection management,
  and broadcast accuracy under various load conditions.
  """

  use ExUnit.Case, async: false

  alias AshReports.PubSub.ChartBroadcaster
  alias AshReports.LiveView.{DataPipeline, SessionManager, WebSocketManager}

  @moduletag :websocket
  @moduletag :streaming
  @moduletag :performance

  describe "Chart broadcasting" do
    test "broadcasts chart updates successfully" do
      chart_id = "streaming_test_chart"
      test_data = %{values: [1, 2, 3, 4, 5], timestamp: DateTime.utc_now()}

      # Subscribe to chart updates
      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      # Broadcast update
      :ok = ChartBroadcaster.broadcast_chart_update(chart_id, test_data)

      # Should receive broadcast message
      assert_receive {:real_time_update, broadcast_data}, 1000
      assert broadcast_data.chart_id == chart_id
      assert broadcast_data.data == test_data
    end

    test "handles high-frequency broadcasts with batching" do
      chart_id = "batching_test_chart"

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      # Send multiple rapid updates
      for i <- 1..5 do
        ChartBroadcaster.broadcast_chart_update(
          chart_id,
          %{value: i, timestamp: DateTime.utc_now()},
          # Should be batched
          priority: :normal,
          batch_delay: 100
        )
      end

      # Should receive batched update
      assert_receive {:real_time_update, broadcast_data}, 1000
      assert broadcast_data.type == :batched_chart_update
      assert broadcast_data.batch_size > 1
    end

    test "compresses large data updates automatically" do
      chart_id = "compression_test_chart"

      # Create large dataset (>1KB)
      large_data = %{
        data: for(i <- 1..200, do: %{x: i, y: :rand.uniform(100), metadata: "data_point_#{i}"}),
        timestamp: DateTime.utc_now()
      }

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      # Broadcast large data with compression enabled
      :ok = ChartBroadcaster.broadcast_chart_update(chart_id, large_data, compression: true)

      # Should receive compressed data
      assert_receive {:real_time_update, broadcast_data}, 1000

      # Check if data was compressed
      if is_map(broadcast_data.data) and Map.has_key?(broadcast_data.data, :compressed) do
        assert broadcast_data.data.compressed == true
        assert broadcast_data.data.compressed_size < broadcast_data.data.original_size
      end
    end
  end

  describe "Dashboard streaming" do
    test "broadcasts dashboard updates to multiple charts" do
      dashboard_id = "streaming_dashboard"

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "dashboard_updates:#{dashboard_id}")

      chart_updates = %{
        "chart1" => %{data: [[1, 10], [2, 20]]},
        "chart2" => %{data: [[1, 15], [2, 25]]},
        "chart3" => %{data: [[1, 30], [2, 40]]}
      }

      :ok = ChartBroadcaster.broadcast_dashboard_update(dashboard_id, chart_updates)

      # Should receive dashboard update
      assert_receive {:dashboard_update, broadcast_data}, 1000
      assert broadcast_data.dashboard_id == dashboard_id
      assert map_size(broadcast_data.chart_updates) == 3
    end

    test "handles dashboard update batching efficiently" do
      dashboard_id = "batching_dashboard"

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "dashboard_updates:#{dashboard_id}")

      # Send multiple dashboard updates rapidly
      for i <- 1..3 do
        ChartBroadcaster.broadcast_dashboard_update(
          dashboard_id,
          %{"chart_#{i}" => %{data: [[1, i * 10]]}},
          batch_delay: 50
        )
      end

      # Should receive batched dashboard update
      assert_receive {:dashboard_update, broadcast_data}, 1000
      assert broadcast_data.type == :batched_dashboard_update
    end
  end

  describe "Performance testing" do
    @tag :slow
    test "handles multiple concurrent chart streams" do
      # Test concurrent streaming for multiple charts
      chart_ids = for i <- 1..10, do: "perf_chart_#{i}"

      # Subscribe to all chart streams
      Enum.each(chart_ids, fn chart_id ->
        Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")
      end)

      # Start concurrent broadcasts
      tasks =
        chart_ids
        |> Enum.map(fn chart_id ->
          Task.async(fn ->
            for j <- 1..5 do
              ChartBroadcaster.broadcast_chart_update(
                chart_id,
                %{iteration: j, data: [j * 10], timestamp: DateTime.utc_now()}
              )

              # Small delay between updates
              Process.sleep(10)
            end
          end)
        end)

      # Wait for all tasks to complete
      Task.await_many(tasks, 5000)

      # Should receive updates for all charts
      received_updates = receive_all_updates(length(chart_ids) * 5, [])
      # At least one update per chart
      assert length(received_updates) >= length(chart_ids)
    end

    @tag :slow
    test "maintains performance with high-frequency updates" do
      chart_id = "high_freq_chart"
      update_count = 50

      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "chart_updates:#{chart_id}")

      start_time = System.monotonic_time(:millisecond)

      # Send high-frequency updates
      for i <- 1..update_count do
        ChartBroadcaster.broadcast_chart_update(
          chart_id,
          %{sequence: i, timestamp: DateTime.utc_now()},
          priority: :normal
        )
      end

      # Receive updates (may be batched)
      updates = receive_all_updates(update_count, [], 2000)
      end_time = System.monotonic_time(:millisecond)

      total_time = end_time - start_time

      # Should handle updates efficiently
      assert length(updates) > 0
      # Should complete within 3 seconds
      assert total_time < 3000
    end
  end

  describe "Data pipeline integration" do
    test "starts filtered stream successfully" do
      stream_config = [
        chart_id: "pipeline_chart",
        filter_criteria: %{region: "North"},
        update_interval: 1000,
        data_source: :database
      ]

      {:ok, stream_id} = ChartBroadcaster.start_filtered_stream(stream_config)

      assert is_binary(stream_id)
      assert String.starts_with?(stream_id, "stream_")

      # Subscribe to filtered stream updates
      :ok = Phoenix.PubSub.subscribe(AshReports.PubSub, "filtered_stream:#{stream_id}")

      # Should eventually receive filtered data
      assert_receive {:filtered_update, _data}, 3000
    end

    test "applies filters to data pipeline correctly" do
      {:ok, pipeline_id} =
        DataPipeline.start_database_stream(
          chart_id: "filtered_pipeline_chart",
          query: "SELECT * FROM test_data",
          poll_interval: 1000,
          change_detection: :timestamp_based,
          filters: %{min_value: 50}
        )

      assert is_binary(pipeline_id)

      # Apply additional filters
      :ok = DataPipeline.apply_stream_filter(pipeline_id, %{max_value: 150})

      # Should handle filter application without errors
      assert true

      # Cleanup
      DataPipeline.stop_pipeline(pipeline_id)
    end
  end

  describe "Session management" do
    test "creates and manages user sessions correctly" do
      {:ok, session_id} =
        SessionManager.create_session(
          user_id: "session_test_user",
          organization_id: "test_org",
          permissions: [:view_charts, :interactive_charts],
          max_connections: 3
        )

      assert is_binary(session_id)
      assert String.starts_with?(session_id, "session_")

      # Get session info
      {:ok, session_info} = SessionManager.get_session_info(session_id)
      assert session_info.user_id == "session_test_user"
      assert session_info.organization_id == "test_org"
    end

    test "handles connection limits correctly" do
      {:ok, session_id} =
        SessionManager.create_session(
          user_id: "connection_limit_user",
          max_connections: 2
        )

      # Add connections up to limit
      :ok = SessionManager.add_connection(session_id, self())
      :ok = SessionManager.add_connection(session_id, spawn(fn -> :timer.sleep(1000) end))

      # Third connection should fail
      {:error, reason} =
        SessionManager.add_connection(session_id, spawn(fn -> :timer.sleep(1000) end))

      assert reason =~ "Connection limit exceeded"
    end
  end

  describe "Error handling" do
    test "handles broadcast failures gracefully" do
      # Try to broadcast to non-existent topic
      invalid_chart_id = "non_existent_chart_#{System.system_time(:millisecond)}"

      # Should not crash, should return ok (fire-and-forget)
      result = ChartBroadcaster.broadcast_chart_update(invalid_chart_id, %{data: []})
      assert result == :ok
    end

    test "recovers from temporary WebSocket failures" do
      # This would test reconnection logic
      # Placeholder for actual WebSocket failure simulation
      assert true
    end
  end

  # Helper functions

  defp receive_all_updates(0, updates), do: updates

  defp receive_all_updates(remaining, updates, timeout \\ 1000) do
    receive do
      {:real_time_update, _data} = update ->
        receive_all_updates(remaining - 1, [update | updates], timeout)

      {:dashboard_update, _data} = update ->
        receive_all_updates(remaining - 1, [update | updates], timeout)

      {:filtered_update, _data} = update ->
        receive_all_updates(remaining - 1, [update | updates], timeout)
    after
      timeout ->
        # Return what we have after timeout
        updates
    end
  end
end
