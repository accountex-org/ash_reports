defmodule AshReports.Charts.DataLoaderTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.DataLoader

  describe "load_chart_data/3 validation" do
    test "returns error for invalid chart (not a map)" do
      assert {:error, {:invalid_chart, message}} =
               DataLoader.load_chart_data(TestDomain, "not a map", %{})

      assert message =~ "must be a map"
    end

    test "returns error for chart without driving_resource" do
      chart = %{name: :test_chart}

      assert {:error, {:missing_data_source, message}} =
               DataLoader.load_chart_data(TestDomain, chart, %{})

      assert message =~ "driving_resource"
    end

    test "returns error for chart with nil driving_resource" do
      chart = %{name: :test_chart, driving_resource: nil}

      assert {:error, {:invalid_driving_resource, message}} =
               DataLoader.load_chart_data(TestDomain, chart, %{})

      assert message =~ "cannot be nil"
    end

    test "returns error for chart with non-module driving_resource" do
      chart = %{name: :test_chart, driving_resource: "NotAModule"}

      assert {:error, {:invalid_driving_resource, message}} =
               DataLoader.load_chart_data(TestDomain, chart, %{})

      assert message =~ "must be a module atom"
    end
  end

  describe "load_chart_data/4 with options" do
    test "accepts timeout option" do
      chart = %{name: :test_chart, driving_resource: NonExistentModule}

      # Should not crash on options validation
      result = DataLoader.load_chart_data(TestDomain, chart, %{}, timeout: 5000)
      assert match?({:error, _}, result)
    end

    test "accepts actor option" do
      chart = %{name: :test_chart, driving_resource: NonExistentModule}

      result = DataLoader.load_chart_data(TestDomain, chart, %{}, actor: %{id: 1})
      assert match?({:error, _}, result)
    end

    test "accepts load_relationships option" do
      chart = %{name: :test_chart, driving_resource: NonExistentModule}

      result = DataLoader.load_chart_data(TestDomain, chart, %{}, load_relationships: false)
      assert match?({:error, _}, result)
    end
  end

  describe "telemetry events" do
    setup do
      # Attach telemetry handler
      handler_id = "test-handler-#{:erlang.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:ash_reports, :charts, :data_loading, :start],
          [:ash_reports, :charts, :data_loading, :stop],
          [:ash_reports, :charts, :data_loading, :exception]
        ],
        fn event_name, measurements, metadata, _config ->
          send(self(), {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      :ok
    end

    test "emits start event when loading begins" do
      chart = %{name: :test_chart, driving_resource: NonExistentModule}
      DataLoader.load_chart_data(TestDomain, chart, %{region: "CA"})

      assert_receive {:telemetry_event, [:ash_reports, :charts, :data_loading, :start],
                      _measurements, metadata}

      assert metadata.domain == TestDomain
      assert metadata.chart_name == :test_chart
      assert metadata.params == %{region: "CA"}
    end

    test "emits exception event on error" do
      chart = %{name: :error_chart, driving_resource: NonExistentModule}
      DataLoader.load_chart_data(TestDomain, chart, %{})

      assert_receive {:telemetry_event, [:ash_reports, :charts, :data_loading, :exception],
                      measurements, metadata}

      assert metadata.domain == TestDomain
      assert metadata.chart_name == :error_chart
      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
    end
  end
end
