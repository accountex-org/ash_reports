defmodule AshReports.RealisticTestHelpersTest do
  use ExUnit.Case, async: false

  alias AshReports.RealisticTestHelpers
  alias AshReportsDemo.EtsDataLayer

  describe "setup_ets_tables/0" do
    test "returns list of ETS table names" do
      tables = RealisticTestHelpers.setup_ets_tables()

      assert is_list(tables)
      assert length(tables) == 8
      assert :demo_customers in tables
      assert :demo_invoices in tables
      assert :demo_products in tables
    end

    test "clears existing data from tables" do
      # First, ensure some data exists
      RealisticTestHelpers.generate_test_data(scenario: :small)

      # Verify data exists
      stats_before = EtsDataLayer.table_stats()
      assert stats_before.total_records > 0

      # Setup tables (should clear data)
      RealisticTestHelpers.setup_ets_tables()

      # Verify data is cleared
      stats_after = EtsDataLayer.table_stats()
      assert stats_after.total_records == 0
    end
  end

  describe "cleanup_ets_tables/0" do
    test "clears all data from ETS tables" do
      # Generate some data
      RealisticTestHelpers.generate_test_data(scenario: :small)

      # Verify data exists
      stats_before = EtsDataLayer.table_stats()
      assert stats_before.total_records > 0

      # Cleanup
      assert :ok == RealisticTestHelpers.cleanup_ets_tables()

      # Verify data is cleared
      stats_after = EtsDataLayer.table_stats()
      assert stats_after.total_records == 0
    end
  end

  describe "generate_test_data/1" do
    setup do
      # Clean up before each test
      RealisticTestHelpers.setup_ets_tables()
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "generates empty scenario with no data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :empty)

      assert is_map(result)
      assert result.customers == []
      assert result.invoices == []
      assert result.products == []

      # Verify ETS tables are still empty
      stats = EtsDataLayer.table_stats()
      assert stats.total_records == 0
    end

    test "generates small scenario with data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :small)

      assert is_map(result)
      assert result.scenario == :small
      assert result.status == :generated

      # Verify ETS tables have data
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    test "generates medium scenario with more data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :medium)

      assert is_map(result)
      assert result.scenario == :medium
      assert result.status == :generated

      # Verify ETS tables have data
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    @tag timeout: 180_000
    test "generates large scenario with lots of data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :large)

      assert is_map(result)
      assert result.scenario == :large
      assert result.status == :generated

      # Verify ETS tables have data
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    # Note: Seed reproducibility not implemented because Faker library
    # doesn't use Erlang's :rand module. This is a nice-to-have feature
    # that can be added later if needed for debugging purposes.
  end

  describe "setup_realistic_test_data/1" do
    test "sets up ETS tables and generates data" do
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :small)

      assert is_map(result)
      assert result.scenario == :small
      assert is_list(result.ets_tables)
      assert is_map(result.counts)
      assert is_map(result.generated_data)

      # Verify data was generated
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    test "defaults to small scenario" do
      result = RealisticTestHelpers.setup_realistic_test_data()

      assert result.scenario == :small
    end

    test "handles empty scenario" do
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :empty)

      assert result.scenario == :empty

      # Verify no data was generated
      stats = EtsDataLayer.table_stats()
      assert stats.total_records == 0
    end

    test "returns record counts" do
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :small)

      counts = result.counts
      assert is_map(counts)

      # Should have counts for all resource types
      assert Map.has_key?(counts, :customers)
      assert Map.has_key?(counts, :invoices)
      assert Map.has_key?(counts, :products)
    end
  end

  describe "integration tests" do
    test "full lifecycle: setup, use, cleanup" do
      # Setup
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      assert result.scenario == :small

      # Verify data exists
      stats_with_data = EtsDataLayer.table_stats()
      assert stats_with_data.total_records > 0

      # Cleanup
      RealisticTestHelpers.cleanup_ets_tables()

      # Verify data is gone
      stats_after_cleanup = EtsDataLayer.table_stats()
      assert stats_after_cleanup.total_records == 0
    end

    test "multiple setups clean up previous data" do
      # First setup
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      stats_1 = EtsDataLayer.table_stats()

      # Second setup (should clean previous data first)
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      stats_2 = EtsDataLayer.table_stats()

      # Both should have similar record counts (not double)
      assert_in_delta(stats_1.total_records, stats_2.total_records, 50)
    end
  end
end
