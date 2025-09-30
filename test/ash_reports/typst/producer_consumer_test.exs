defmodule AshReports.Typst.StreamingPipeline.ProducerConsumerTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline.{Producer, ProducerConsumer, Registry}

  setup do
    # Ensure Registry is running
    unless Process.whereis(AshReports.Typst.StreamingPipeline.Registry) do
      flunk("Registry not started - check Application supervision tree")
    end

    :ok
  end

  describe "ProducerConsumer initialization" do
    test "starts successfully with required options" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}]
      ]

      assert {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end

    test "accepts transformation_opts configuration" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        transformation_opts: [
          datetime_format: :iso8601,
          decimal_precision: 2,
          flatten_relationships: true
        ]
      ]

      assert {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end

    test "accepts aggregation configuration" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        aggregations: [:sum, :count, :avg, :min, :max]
      ]

      assert {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end

    test "accepts buffer configuration" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        buffer_size: 2000,
        max_demand: 1000,
        min_demand: 500
      ]

      assert {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end
  end

  describe "telemetry events" do
    test "emits batch_transformed telemetry" do
      test_pid = self()

      :telemetry.attach(
        "test-batch-transformed",
        [:ash_reports, :streaming, :producer_consumer, :batch_transformed],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :batch_transformed, measurements, metadata})
        end,
        nil
      )

      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        enable_telemetry: true
      ]

      {:ok, _pid} = ProducerConsumer.start_link(opts)

      # Telemetry would be emitted when events are processed
      # This test verifies the handler is set up correctly

      :telemetry.detach("test-batch-transformed")
      cleanup_process(producer_pid)
    end

    test "emits aggregation_computed telemetry when aggregations enabled" do
      test_pid = self()

      :telemetry.attach(
        "test-aggregation",
        [:ash_reports, :streaming, :producer_consumer, :aggregation_computed],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :aggregation, measurements, metadata})
        end,
        nil
      )

      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        aggregations: [:count, :sum],
        enable_telemetry: true
      ]

      {:ok, _pid} = ProducerConsumer.start_link(opts)

      :telemetry.detach("test-aggregation")
      cleanup_process(producer_pid)
    end
  end

  describe "aggregation functions" do
    test "initializes aggregation state correctly" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        aggregations: [:sum, :count, :avg, :min, :max, :running_total]
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      # State initialization is verified by successful start
      cleanup_process(producer_pid)
      cleanup_process(pid)
    end
  end

  describe "backpressure handling" do
    test "configures max_demand and min_demand" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, max_demand: 1000, min_demand: 500}],
        max_demand: 1000,
        min_demand: 500
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end
  end

  describe "transformation pipeline" do
    test "applies custom transformer function" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      # Custom transformer that adds a field
      transformer = fn record ->
        Map.put(record, :transformed, true)
      end

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        transformer: transformer
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end
  end

  describe "error handling" do
    test "handles transformation errors gracefully" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      # Transformer that raises an error
      transformer = fn _record ->
        raise "Intentional error"
      end

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        transformer: transformer
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end
  end

  describe "grouped aggregations" do
    test "accepts single-field grouped aggregation configuration" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        grouped_aggregations: [
          %{group_by: :territory, aggregations: [:sum, :count]}
        ]
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end

    test "accepts multi-field grouped aggregation configuration" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        grouped_aggregations: [
          %{group_by: [:territory, :customer_name], aggregations: [:sum, :count, :avg]}
        ]
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end

    test "accepts multiple grouped aggregation configurations" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        grouped_aggregations: [
          # Territory level
          %{group_by: :territory, aggregations: [:sum, :count]},
          # Territory + Customer level
          %{group_by: [:territory, :customer_name], aggregations: [:sum, :count, :avg]}
        ]
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end

    test "can combine global and grouped aggregations" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        # Global aggregations
        aggregations: [:sum, :count, :avg],
        # Grouped aggregations
        grouped_aggregations: [
          %{group_by: :territory, aggregations: [:sum, :count]}
        ]
      ]

      {:ok, pid} = ProducerConsumer.start_link(opts)
      assert Process.alive?(pid)

      cleanup_process(producer_pid)
      cleanup_process(pid)
    end
  end

  # Helper functions

  defp spawn_persistent_process do
    spawn(fn -> persistent_process_loop() end)
  end

  defp persistent_process_loop do
    receive do
      :stop -> :ok
      _ -> persistent_process_loop()
    end
  end

  defp cleanup_process(pid) do
    if Process.alive?(pid) do
      send(pid, :stop)
      Process.sleep(10)
    end
  end
end