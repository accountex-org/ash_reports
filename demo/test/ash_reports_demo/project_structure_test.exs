defmodule AshReportsDemo.ProjectStructureTest do
  @moduledoc """
  Tests for Phase 7.1 project structure and basic functionality.
  """

  use ExUnit.Case, async: true

  describe "module loading" do
    test "demo module loads successfully" do
      assert Code.ensure_loaded?(AshReportsDemo)
      assert Code.ensure_loaded?(AshReportsDemo.Application)
      assert Code.ensure_loaded?(AshReportsDemo.Domain)
      assert Code.ensure_loaded?(AshReportsDemo.DataGenerator)
      assert Code.ensure_loaded?(AshReportsDemo.EtsDataLayer)
    end

    test "application starts successfully" do
      # Application should already be started by test_helper.exs
      assert Process.whereis(AshReportsDemo.DataGenerator) != nil
      assert Process.whereis(AshReportsDemo.EtsDataLayer) != nil
    end
  end

  describe "data generator" do
    test "provides data statistics" do
      stats = AshReportsDemo.DataGenerator.data_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :current_volume)
      assert Map.has_key?(stats, :available_volumes)
      assert stats.available_volumes == [:small, :medium, :large]
    end

    test "handles reset operation" do
      assert :ok = AshReportsDemo.DataGenerator.reset_data()
    end
  end

  describe "ETS data layer" do
    test "provides table statistics" do
      stats = AshReportsDemo.EtsDataLayer.table_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :tables)
      assert Map.has_key?(stats, :total_records)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "supports data clearing" do
      assert :ok = AshReportsDemo.EtsDataLayer.clear_all_data()
    end
  end

  describe "domain configuration" do
    test "domain module exists and is configured" do
      assert Code.ensure_loaded?(AshReportsDemo.Domain)

      # Check that domain module has basic Ash domain structure
      # Phase 7.1: Basic validation that domain module loads and compiles
      assert AshReportsDemo.Domain.__info__(:module) == AshReportsDemo.Domain
    end
  end

  describe "public API" do
    test "provides data summary functionality" do
      summary = AshReportsDemo.data_summary()

      assert is_map(summary)
      assert Map.has_key?(summary, :customers)
      assert Map.has_key?(summary, :products)
      assert Map.has_key?(summary, :invoices)
      assert Map.has_key?(summary, :generated_at)

      # All counts should be 0 since no resources exist yet
      assert summary.customers == 0
      assert summary.products == 0
      assert summary.invoices == 0
    end

    test "lists available reports" do
      reports = AshReportsDemo.list_reports()
      assert is_list(reports)
      # Initially empty - reports added in Phase 7.5
    end

    test "handles data generation requests" do
      # Should handle gracefully even without full implementation
      case AshReportsDemo.generate_sample_data(:small) do
        :ok -> assert true
        {:error, reason} -> assert is_binary(reason)
      end
    end
  end
end
