defmodule AshReports.Typst.StreamingPipelineTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline
  alias AshReports.Typst.StreamingPipeline.{HealthMonitor, Producer, ProducerConsumer, Registry}

  setup do
    # Application is already started in test environment via test_helper.exs
    # Just ensure the Registry and HealthMonitor are available
    unless Process.whereis(AshReports.Typst.StreamingPipeline.Registry) do
      flunk("Registry not started - check Application supervision tree")
    end

    :ok
  end

  describe "Registry" do
    test "registers and retrieves pipeline info" do
      producer_pid = spawn_persistent_process()
      metadata = %{report_name: :test_report}

      {:ok, stream_id} = Registry.register_pipeline(producer_pid, metadata)

      assert is_binary(stream_id)
      assert {:ok, info} = Registry.get_pipeline(stream_id)
      assert info.producer_pid == producer_pid
      assert info.status == :running
      assert info.metadata == metadata

      cleanup_process(producer_pid)
    end

    test "updates pipeline status" do
      producer_pid = spawn_persistent_process()
      {:ok, stream_id} = Registry.register_pipeline(producer_pid, %{})

      :ok = Registry.update_status(stream_id, :paused)

      assert {:ok, info} = Registry.get_pipeline(stream_id)
      assert info.status == :paused

      cleanup_process(producer_pid)
    end

    test "increments records processed" do
      producer_pid = spawn_persistent_process()
      {:ok, stream_id} = Registry.register_pipeline(producer_pid, %{})

      :ok = Registry.increment_records(stream_id, 100)
      :ok = Registry.increment_records(stream_id, 50)

      assert {:ok, info} = Registry.get_pipeline(stream_id)
      assert info.records_processed == 150

      cleanup_process(producer_pid)
    end

    test "updates memory usage" do
      producer_pid = spawn_persistent_process()
      {:ok, stream_id} = Registry.register_pipeline(producer_pid, %{})

      :ok = Registry.update_memory_usage(stream_id, 1_000_000)

      assert {:ok, info} = Registry.get_pipeline(stream_id)
      assert info.memory_usage == 1_000_000

      cleanup_process(producer_pid)
    end

    test "lists pipelines by status" do
      producer_pid1 = spawn_persistent_process()
      producer_pid2 = spawn_persistent_process()

      {:ok, stream_id1} = Registry.register_pipeline(producer_pid1, %{})
      {:ok, stream_id2} = Registry.register_pipeline(producer_pid2, %{})

      # Verify they were actually registered
      {:ok, _info1} = Registry.get_pipeline(stream_id1)
      {:ok, _info2} = Registry.get_pipeline(stream_id2)

      # Ensure registration is complete
      Process.sleep(10)

      Registry.update_status(stream_id1, :paused)

      running_pipelines = Registry.list_pipelines(status: :running)
      paused_pipelines = Registry.list_pipelines(status: :paused)

      assert Enum.any?(running_pipelines, fn p -> p.stream_id == stream_id2 end)
      assert Enum.any?(paused_pipelines, fn p -> p.stream_id == stream_id1 end)

      cleanup_process(producer_pid1)
      cleanup_process(producer_pid2)
    end

    test "counts pipelines by status" do
      producer_pid1 = spawn_persistent_process()
      producer_pid2 = spawn_persistent_process()

      {:ok, _stream_id1} = Registry.register_pipeline(producer_pid1, %{})
      {:ok, stream_id2} = Registry.register_pipeline(producer_pid2, %{})

      # Ensure registration is complete
      Process.sleep(10)

      Registry.update_status(stream_id2, :completed)

      counts = Registry.count_by_status()

      assert counts[:running] >= 1
      assert counts[:completed] >= 1

      cleanup_process(producer_pid1)
      cleanup_process(producer_pid2)
    end

    test "handles process termination" do
      # Spawn a temporary process to register
      {pid, ref} = spawn_monitor(fn -> Process.sleep(100) end)

      {:ok, stream_id} = Registry.register_pipeline(pid, %{})

      # Kill the process
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      # Give the registry time to process the DOWN message
      Process.sleep(50)

      # Pipeline should be marked as failed
      assert {:ok, info} = Registry.get_pipeline(stream_id)
      assert info.status == :failed
    end
  end

  describe "HealthMonitor telemetry" do
    test "emits start telemetry" do
      test_pid = self()

      :telemetry.attach(
        "test-start",
        [:ash_reports, :streaming, :pipeline, :start],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :start, measurements, metadata})
        end,
        nil
      )

      HealthMonitor.emit_start("test-stream-123", :test_report)

      assert_receive {:telemetry, :start, %{system_time: _},
                      %{stream_id: "test-stream-123", report_name: :test_report}}

      :telemetry.detach("test-start")
    end

    test "emits stop telemetry" do
      test_pid = self()

      :telemetry.attach(
        "test-stop",
        [:ash_reports, :streaming, :pipeline, :stop],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :stop, measurements, metadata})
        end,
        nil
      )

      HealthMonitor.emit_stop("test-stream-123", :completed, 5000, 1000)

      assert_receive {:telemetry, :stop, %{duration: 5000, records_processed: 1000},
                      %{stream_id: "test-stream-123", status: :completed}}

      :telemetry.detach("test-stop")
    end

    test "emits throughput telemetry" do
      test_pid = self()

      :telemetry.attach(
        "test-throughput",
        [:ash_reports, :streaming, :throughput],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :throughput, measurements, metadata})
        end,
        nil
      )

      HealthMonitor.emit_throughput("test-stream-123", 123.45)

      assert_receive {:telemetry, :throughput, %{records_per_second: 123.45},
                      %{stream_id: "test-stream-123"}}

      :telemetry.detach("test-throughput")
    end
  end

  describe "StreamingPipeline.Supervisor" do
    test "supervisor starts successfully" do
      assert Process.whereis(AshReports.Typst.StreamingPipeline.Supervisor) != nil
    end

    test "registry is available" do
      assert Process.whereis(AshReports.Typst.StreamingPipeline.Registry) != nil
    end

    test "health monitor is available" do
      assert Process.whereis(AshReports.Typst.StreamingPipeline.HealthMonitor) != nil
    end

    test "pipeline supervisor returns valid PID" do
      case AshReports.Typst.StreamingPipeline.Supervisor.pipeline_supervisor() do
        {:error, _} -> flunk("Pipeline supervisor not found")
        pid when is_pid(pid) -> assert Process.alive?(pid)
      end
    end
  end

  # Helper functions for creating persistent test processes

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
      # Give it a moment to terminate
      Process.sleep(10)
    end
  end
end
