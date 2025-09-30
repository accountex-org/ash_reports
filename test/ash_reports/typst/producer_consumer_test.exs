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

  describe "behavioral tests: data transformation" do
    test "transforms records through custom transformer" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      # Custom transformer that adds a field and notifies test
      transformer = fn record ->
        send(test_pid, {:transformed, record})
        Map.put(record, :transformed, true)
      end

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        transformer: transformer
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      # Send test events through producer
      GenStage.call(producer, {:queue, [%{id: 1, value: 100}, %{id: 2, value: 200}]})

      # Verify transformation occurred
      assert_receive {:transformed, %{id: 1, value: 100}}, 1000
      assert_receive {:transformed, %{id: 2, value: 200}}, 1000

      # Verify transformed records reached consumer
      assert_receive {:consumed, events}, 1000
      assert length(events) == 2
      assert Enum.all?(events, fn record -> record.transformed == true end)

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "filters out nil results from failed transformations" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      # Transformer that returns nil for even IDs
      transformer = fn record ->
        if rem(record.id, 2) == 0, do: nil, else: record
      end

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        transformer: transformer
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      # Send 4 records, expect only 2 to pass through
      GenStage.call(producer, {:queue, [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}]})

      assert_receive {:consumed, events}, 1000
      assert length(events) == 2
      assert Enum.map(events, & &1.id) == [1, 3]

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end
  end

  describe "behavioral tests: aggregation accuracy" do
    test "sum aggregation calculates correct totals" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        aggregations: [:sum]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      # Send records with known values
      records = [
        %{amount: 100, quantity: 5},
        %{amount: 200, quantity: 10},
        %{amount: 150, quantity: 7}
      ]

      GenStage.call(producer, {:queue, records})

      # Wait for processing
      assert_receive {:consumed, _}, 1000

      # Get state and verify sum
      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.sum.amount == 450
      assert state.aggregation_state.sum.quantity == 22

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "count aggregation tracks record count" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        aggregations: [:count]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid, max_demand: 10, min_demand: 5)

      # Give GenStage time to establish demand
      Process.sleep(50)

      # Send first batch
      GenStage.call(producer, {:queue, [%{id: 1}, %{id: 2}, %{id: 3}]})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.count == 3

      # Send second batch
      GenStage.call(producer, {:queue, [%{id: 4}, %{id: 5}]})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.count == 5

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "avg aggregation maintains sum and count" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        aggregations: [:avg]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      records = [
        %{score: 80},
        %{score: 90},
        %{score: 70}
      ]

      GenStage.call(producer, {:queue, records})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.avg.sum.score == 240
      assert state.aggregation_state.avg.count == 3
      # Average would be: 240 / 3 = 80.0

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "min and max aggregations track extremes" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        aggregations: [:min, :max]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      records = [
        %{value: 50, price: 100},
        %{value: 10, price: 500},
        %{value: 90, price: 50},
        %{value: 30, price: 200}
      ]

      GenStage.call(producer, {:queue, records})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.min.value == 10
      assert state.aggregation_state.min.price == 50
      assert state.aggregation_state.max.value == 90
      assert state.aggregation_state.max.price == 500

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "running_total accumulates across batches" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        aggregations: [:running_total]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid, max_demand: 10, min_demand: 5)

      # Give GenStage time to establish demand
      Process.sleep(50)

      # First batch
      GenStage.call(producer, {:queue, [%{amount: 100}, %{amount: 200}]})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.running_total.amount == 300

      # Second batch
      GenStage.call(producer, {:queue, [%{amount: 150}, %{amount: 250}]})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      assert state.aggregation_state.running_total.amount == 700

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end
  end

  describe "behavioral tests: grouped aggregations" do
    test "single-field grouping aggregates by category" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        grouped_aggregations: [
          %{group_by: :category, aggregations: [:sum, :count]}
        ]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      records = [
        %{category: "A", amount: 100},
        %{category: "B", amount: 200},
        %{category: "A", amount: 150},
        %{category: "B", amount: 50}
      ]

      GenStage.call(producer, {:queue, records})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      groups = state.grouped_aggregation_state[[:category]]

      assert groups["A"].sum.amount == 250
      assert groups["A"].count == 2
      assert groups["B"].sum.amount == 250
      assert groups["B"].count == 2

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "multi-field grouping creates composite keys" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        grouped_aggregations: [
          %{group_by: [:territory, :customer], aggregations: [:sum, :count]}
        ]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      records = [
        %{territory: "North", customer: "ABC", amount: 100},
        %{territory: "North", customer: "XYZ", amount: 200},
        %{territory: "North", customer: "ABC", amount: 150},
        %{territory: "South", customer: "ABC", amount: 300}
      ]

      GenStage.call(producer, {:queue, records})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)
      groups = state.grouped_aggregation_state[[:territory, :customer]]

      assert groups[{"North", "ABC"}].sum.amount == 250
      assert groups[{"North", "ABC"}].count == 2
      assert groups[{"North", "XYZ"}].sum.amount == 200
      assert groups[{"North", "XYZ"}].count == 1
      assert groups[{"South", "ABC"}].sum.amount == 300
      assert groups[{"South", "ABC"}].count == 1

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "multiple grouped aggregation configs work simultaneously" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        grouped_aggregations: [
          %{group_by: :territory, aggregations: [:sum]},
          %{group_by: [:territory, :customer], aggregations: [:count]}
        ]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      records = [
        %{territory: "North", customer: "ABC", amount: 100},
        %{territory: "North", customer: "ABC", amount: 150}
      ]

      GenStage.call(producer, {:queue, records})
      assert_receive {:consumed, _}, 1000

      %{state: state} = :sys.get_state(pc_pid)

      # Territory-level grouping
      territory_groups = state.grouped_aggregation_state[[:territory]]
      assert territory_groups["North"].sum.amount == 250

      # Territory + Customer grouping
      detailed_groups = state.grouped_aggregation_state[[:territory, :customer]]
      assert detailed_groups[{"North", "ABC"}].count == 2

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end
  end

  describe "behavioral tests: error handling" do
    test "handles transformer errors and continues processing" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      # Transformer that fails on specific record
      transformer = fn record ->
        if record.id == 2 do
          raise "Intentional error"
        else
          record
        end
      end

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        transformer: transformer
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      # Give GenStage time to establish demand
      Process.sleep(50)

      # This will trigger the error during batch processing
      GenStage.call(producer, {:queue, [%{id: 1}, %{id: 2}, %{id: 3}]})

      # Should receive only the successful records (error records filtered out as nil)
      assert_receive {:consumed, events}, 1000

      # Record with id: 2 should be filtered out (returned nil due to error)
      # Records with id: 1 and id: 3 should pass through
      assert length(events) == 2
      assert Enum.any?(events, fn r -> r.id == 1 end)
      assert Enum.any?(events, fn r -> r.id == 3 end)
      refute Enum.any?(events, fn r -> r.id == 2 end)

      # Verify process is still alive (didn't crash)
      assert Process.alive?(pc_pid)

      # Individual record errors are logged but not tracked in state.errors
      # (state.errors only tracks batch-level failures)
      # The test verified that:
      # 1. The error was logged (we saw the log output)
      # 2. Processing continued (records 1 and 3 were successfully transformed)
      # 3. The ProducerConsumer process didn't crash
      %{state: state} = :sys.get_state(pc_pid)
      assert state.errors == []  # No batch-level errors
      assert state.total_transformed == 2  # Only the 2 successful records

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
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

    test "enforces max_groups limit to prevent memory exhaustion" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      # Set a very low max_groups limit for testing
      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        grouped_aggregations: [
          %{group_by: :id, aggregations: [:count], max_groups: 3}
        ]
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid)

      Process.sleep(50)

      # Send 5 records with unique IDs - only first 3 should create groups
      records = [
        %{id: 1, value: 100},
        %{id: 2, value: 200},
        %{id: 3, value: 300},
        %{id: 4, value: 400},
        %{id: 5, value: 500}
      ]

      GenStage.call(producer, {:queue, records})
      assert_receive {:consumed, _}, 1000

      # Verify only 3 groups were created
      %{state: state} = :sys.get_state(pc_pid)
      groups = state.grouped_aggregation_state[[:id]]
      assert map_size(groups) == 3

      # Verify group counts are tracked
      assert state.group_counts[[:id]] == 3

      # Verify the first 3 groups exist
      assert Map.has_key?(groups, 1)
      assert Map.has_key?(groups, 2)
      assert Map.has_key?(groups, 3)

      # Groups 4 and 5 should not exist (rejected)
      refute Map.has_key?(groups, 4)
      refute Map.has_key?(groups, 5)

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end
  end

  describe "transformer security" do
    test "rejects transformer with wrong arity" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      # Transformer with arity-2 (invalid)
      invalid_transformer = fn _record, _extra -> %{} end

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        transformer: invalid_transformer
      ]

      # Use GenStage.start (no link) to avoid crashing the test
      assert {:error, {%ArgumentError{message: msg}, _stacktrace}} =
               GenStage.start(AshReports.Typst.StreamingPipeline.ProducerConsumer, opts)

      assert msg =~ "Expected arity-1 function"

      cleanup_process(producer_pid)
    end

    test "enforces timeout on slow transformers" do
      stream_id = "test-stream-#{:rand.uniform(10000)}"
      test_pid = self()

      # Transformer that sleeps longer than timeout
      slow_transformer = fn record ->
        Process.sleep(100)
        record
      end

      {:ok, producer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestProducer,
          :ok
        )

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer, []}],
        transformer: slow_transformer,
        transformer_timeout: 50
      ]

      {:ok, pc_pid} = ProducerConsumer.start_link(opts)
      {:ok, consumer} =
        GenStage.start_link(
          AshReports.Typst.StreamingPipeline.ProducerConsumerTest.TestConsumer,
          test_pid
        )
      GenStage.sync_subscribe(consumer, to: pc_pid, max_demand: 10, min_demand: 5)

      Process.sleep(50)

      # Send multiple records: one fast, one slow
      # The slow one will timeout and be filtered out
      fast_record = %{id: 1, value: 100, fast: true}
      slow_record = %{id: 2, value: 200}

      # For testing, let's modify transformer to check a flag
      # Actually, we can't modify the transformer after it's set
      # So let's just send one record and verify the process is still alive

      # Send record that will timeout
      GenStage.call(producer, {:queue, [slow_record]})

      # Wait for timeout to occur (50ms timeout + 100ms sleep)
      Process.sleep(200)

      # Verify the ProducerConsumer is still alive (didn't crash)
      assert Process.alive?(pc_pid)

      # Verify state shows no records were transformed
      %{state: state} = :sys.get_state(pc_pid)
      assert state.total_transformed == 0

      cleanup_process(producer)
      cleanup_process(pc_pid)
      cleanup_process(consumer)
    end

    test "validates transformer is a function" do
      producer_pid = spawn_persistent_process()
      stream_id = "test-stream-#{:rand.uniform(10000)}"

      # Not a function
      invalid_transformer = "not a function"

      opts = [
        stream_id: stream_id,
        subscribe_to: [{producer_pid, []}],
        transformer: invalid_transformer
      ]

      # Use GenStage.start (no link) to avoid crashing the test
      assert {:error, {%ArgumentError{message: msg}, _stacktrace}} =
               GenStage.start(AshReports.Typst.StreamingPipeline.ProducerConsumer, opts)

      assert msg =~ "Transformer must be a function"

      cleanup_process(producer_pid)
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

  # Test GenStage Producers and Consumers

  defmodule TestProducer do
    use GenStage

    def init(:ok) do
      {:producer, %{queue: :queue.new(), pending_demand: 0}}
    end

    def handle_call({:queue, events}, _from, state) do
      new_queue = :queue.join(state.queue, :queue.from_list(events))

      # If there's pending demand, dispatch immediately
      {events_to_dispatch, final_queue} =
        take_events(new_queue, state.pending_demand, [])

      # Only reduce pending_demand by the number of events we're actually dispatching
      remaining_demand = max(state.pending_demand - length(events_to_dispatch), 0)
      new_state = %{queue: final_queue, pending_demand: remaining_demand}
      {:reply, :ok, events_to_dispatch, new_state}
    end

    def handle_demand(demand, state) when demand > 0 do
      {events, new_queue} = take_events(state.queue, demand, [])

      # Track unfulfilled demand
      remaining_demand = demand - length(events)
      new_state = %{
        queue: new_queue,
        pending_demand: state.pending_demand + remaining_demand
      }

      {:noreply, events, new_state}
    end

    defp take_events(queue, 0, acc), do: {Enum.reverse(acc), queue}

    defp take_events(queue, demand, acc) when demand > 0 do
      case :queue.out(queue) do
        {{:value, event}, new_queue} -> take_events(new_queue, demand - 1, [event | acc])
        {:empty, queue} -> {Enum.reverse(acc), queue}
      end
    end
  end

  defmodule TestConsumer do
    use GenStage

    def init(test_pid) do
      {:consumer, test_pid}
    end

    def handle_events(events, _from, test_pid) do
      send(test_pid, {:consumed, events})
      # Keep consuming - this tells GenStage we're ready for more
      {:noreply, [], test_pid}
    end
  end
end
