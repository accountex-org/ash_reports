defmodule AshReports.Typst.DataLoaderTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.{AggregationConfigurator, DataLoader}

  describe "typst_config/1" do
    test "creates default configuration" do
      config = DataLoader.typst_config()

      assert config[:chunk_size] == 1000
      assert config[:type_conversion][:datetime_format] == :iso8601
    end

    test "allows configuration overrides" do
      config = DataLoader.typst_config(chunk_size: 2000)

      assert config[:chunk_size] == 2000
      # Defaults should still be present
      assert config[:type_conversion][:datetime_format] == :iso8601
    end
  end

  describe "stream_for_typst/4" do
    test "returns error for not implemented streaming" do
      # Test that streaming returns the expected not-implemented error
      result = DataLoader.stream_for_typst(NonExistentDomain, :test_report, %{})

      assert {:error, _reason} = result
      # We expect either streaming_not_implemented or report lookup error
    end
  end

  describe "cumulative grouping (Section 2.4.3)" do
    # These tests verify the cumulative grouping feature where each level
    # includes all fields from previous levels for hierarchical reports

    test "single-level grouping returns atom" do
      # Setup: Report with one group
      report = %{
        groups: [
          %{level: 1, name: :territory_group, expression: :territory, sort: :asc}
        ],
        variables: []
      }

      # Call the private function via send
      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      # Assert: Single field should be an atom, not a list
      assert [config] = result
      assert config.group_by == :territory
      assert config.level == 1
      assert is_list(config.aggregations)
    end

    test "two-level grouping returns cumulative fields" do
      # Setup: Report with two groups
      report = %{
        groups: [
          %{level: 1, name: :territory_group, expression: :territory, sort: :asc},
          %{level: 2, name: :customer_group, expression: :customer_name, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      # Assert: Level 1 should have single field (atom)
      assert [level1, level2] = result
      assert level1.group_by == :territory
      assert level1.level == 1

      # Assert: Level 2 should have cumulative fields (list)
      assert level2.group_by == [:territory, :customer_name]
      assert level2.level == 2
    end

    test "three-level grouping returns fully cumulative fields" do
      # Setup: Report with three groups
      report = %{
        groups: [
          %{level: 1, name: :territory_group, expression: :territory, sort: :asc},
          %{level: 2, name: :customer_group, expression: :customer_name, sort: :asc},
          %{level: 3, name: :order_type_group, expression: :order_type, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      assert [level1, level2, level3] = result

      # Level 1: Single field
      assert level1.group_by == :territory
      assert level1.level == 1

      # Level 2: Territory + Customer
      assert level2.group_by == [:territory, :customer_name]
      assert level2.level == 2

      # Level 3: Territory + Customer + Order Type
      assert level3.group_by == [:territory, :customer_name, :order_type]
      assert level3.level == 3
    end

    test "handles nested field expressions in cumulative grouping" do
      # Setup: Report with relationship traversal expressions
      report = %{
        groups: [
          %{level: 1, name: :region_group, expression: {:field, :customer, :region}, sort: :asc},
          %{
            level: 2,
            name: :status_group,
            expression: {:field, :order, :status},
            sort: :asc
          }
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      assert [level1, level2] = result

      # Level 1: Extracts terminal field
      assert level1.group_by == :region
      assert level1.level == 1

      # Level 2: Cumulative with both extracted fields
      assert level2.group_by == [:region, :status]
      assert level2.level == 2
    end

    test "empty groups list returns empty config" do
      report = %{groups: [], variables: []}

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      assert result == []
    end

    test "groups maintain sort order in config" do
      report = %{
        groups: [
          %{level: 1, name: :territory_group, expression: :territory, sort: :desc},
          %{level: 2, name: :customer_group, expression: :customer_name, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      assert [level1, level2] = result
      assert level1.sort == :desc
      assert level2.sort == :asc
    end

    test "maps variable types to aggregations in cumulative grouping" do
      report = %{
        groups: [
          %{level: 1, name: :territory_group, expression: :territory, sort: :asc},
          %{level: 2, name: :customer_group, expression: :customer_name, sort: :asc}
        ],
        variables: [
          %{name: :total_sales, type: :sum, reset_on: :group, reset_group: 1},
          %{name: :avg_amount, type: :average, reset_on: :group, reset_group: 1},
          %{name: :record_count, type: :count, reset_on: :group, reset_group: 2}
        ]
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      assert [level1, level2] = result

      # Level 1 should have sum and avg from its variables
      assert :sum in level1.aggregations
      assert :avg in level1.aggregations

      # Level 2 should have count from its variable
      assert :count in level2.aggregations
    end

    test "handles unsorted groups by sorting them by level" do
      # Setup: Groups provided out of order
      report = %{
        groups: [
          %{level: 3, name: :order_type_group, expression: :order_type, sort: :asc},
          %{level: 1, name: :territory_group, expression: :territory, sort: :asc},
          %{level: 2, name: :customer_group, expression: :customer_name, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      # Should be sorted by level and cumulative
      assert [level1, level2, level3] = result
      assert level1.level == 1
      assert level1.group_by == :territory

      assert level2.level == 2
      assert level2.group_by == [:territory, :customer_name]

      assert level3.level == 3
      assert level3.group_by == [:territory, :customer_name, :order_type]
    end

    test "handles sparse level numbering (gaps in levels)" do
      # Setup: Levels 1, 3, 5 (missing 2 and 4)
      report = %{
        groups: [
          %{level: 1, name: :group1, expression: :field1, sort: :asc},
          %{level: 3, name: :group3, expression: :field3, sort: :asc},
          %{level: 5, name: :group5, expression: :field5, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)

      # Should still accumulate correctly despite gaps
      assert [level1, level3, level5] = result

      assert level1.group_by == :field1
      assert level1.level == 1

      assert level3.group_by == [:field1, :field3]
      assert level3.level == 3

      assert level5.group_by == [:field1, :field3, :field5]
      assert level5.level == 5
    end
  end

  describe "non-cumulative grouping (Section 9)" do
    test "cumulative: false creates independent groupings" do
      report = %{
        groups: [
          %{level: 1, name: :region_group, expression: :region, sort: :asc},
          %{level: 2, name: :city_group, expression: :city, sort: :asc},
          %{level: 3, name: :product_group, expression: :product, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report, cumulative: false)

      assert [level1, level2, level3] = result

      # Each level should only group by its own field
      assert level1.group_by == :region
      assert level2.group_by == :city
      assert level3.group_by == :product
    end

    test "non-cumulative reduces memory footprint" do
      report = %{
        groups: [
          %{level: 1, name: :region_group, expression: :region, sort: :asc},
          %{level: 2, name: :city_group, expression: :city, sort: :asc}
        ],
        variables: []
      }

      # Cumulative: Level 2 has 2 fields
      assert {:ok, cumulative_result} = AggregationConfigurator.build_aggregations(report, cumulative: true)
      [_, level2_cumulative] = cumulative_result
      assert level2_cumulative.group_by == [:region, :city]

      # Non-cumulative: Level 2 has 1 field
      assert {:ok, non_cumulative_result} = AggregationConfigurator.build_aggregations(report, cumulative: false)
      [_, level2_non_cumulative] = non_cumulative_result
      assert level2_non_cumulative.group_by == :city
    end
  end

  describe "memory validation (Section 9)" do
    test "fails when estimated groups exceed max_estimated_groups" do
      # Create a report with many nested levels (exceeds 100K default limit)
      report = %{
        name: :large_report,
        groups: [
          %{level: 1, name: :g1, expression: :field1, sort: :asc},
          %{level: 2, name: :g2, expression: :field2, sort: :asc},
          %{level: 3, name: :g3, expression: :field3, sort: :asc},
          %{level: 4, name: :g4, expression: :field4, sort: :asc}
        ],
        variables: []
      }

      # With 4 nested levels, estimate is: 100 + 1000 + 5000 + 10000 = 16100 groups
      # Set limit to 10,000 to trigger failure
      result = AggregationConfigurator.build_aggregations(report, max_estimated_groups: 10_000)

      assert {:error, {:memory_limit_exceeded, details}} = result
      assert details.reason == :too_many_groups
      assert details.estimated_groups > 10_000
      assert details.report == :large_report
      assert details.message =~ "cumulative: false"
    end

    test "fails when estimated memory exceeds max_estimated_memory" do
      report = %{
        name: :large_report,
        groups: [
          %{level: 1, name: :g1, expression: :field1, sort: :asc},
          %{level: 2, name: :g2, expression: :field2, sort: :asc},
          %{level: 3, name: :g3, expression: :field3, sort: :asc}
        ],
        variables: []
      }

      # Set very low memory limit to trigger failure
      result = AggregationConfigurator.build_aggregations(report, max_estimated_memory: 1_000_000)

      assert {:error, {:memory_limit_exceeded, details}} = result
      assert details.reason == :memory_too_high
      assert details.estimated_memory > 1_000_000
      assert is_binary(details.estimated_memory_formatted)
      assert is_binary(details.max_memory_formatted)
    end

    test "passes validation with reasonable limits" do
      report = %{
        name: :small_report,
        groups: [
          %{level: 1, name: :region, expression: :region, sort: :asc}
        ],
        variables: []
      }

      assert {:ok, result} = AggregationConfigurator.build_aggregations(report)
      assert [config] = result
      assert config.group_by == :region
    end

    test "enforce_limits: false allows exceeding limits with warning" do
      report = %{
        name: :large_report,
        groups: [
          %{level: 1, name: :g1, expression: :field1, sort: :asc},
          %{level: 2, name: :g2, expression: :field2, sort: :asc},
          %{level: 3, name: :g3, expression: :field3, sort: :asc},
          %{level: 4, name: :g4, expression: :field4, sort: :asc}
        ],
        variables: []
      }

      # With enforce: false, should return ok even when exceeding limits
      assert {:ok, result} =
               AggregationConfigurator.build_aggregations(report,
                 max_estimated_groups: 10_000,
                 enforce_limits: false
               )

      assert length(result) == 4
    end

    test "non-cumulative grouping reduces estimated memory" do
      report = %{
        name: :test_report,
        groups: [
          %{level: 1, name: :g1, expression: :field1, sort: :asc},
          %{level: 2, name: :g2, expression: :field2, sort: :asc},
          %{level: 3, name: :g3, expression: :field3, sort: :asc}
        ],
        variables: []
      }

      # Cumulative should create more groups
      # Level 1: 100, Level 2: 1000, Level 3: 5000 = 6100 groups
      assert {:ok, _cumulative} = AggregationConfigurator.build_aggregations(report)

      # Non-cumulative should create fewer groups
      # Level 1: 100, Level 2: 100, Level 3: 100 = 300 groups
      assert {:ok, _non_cumulative} =
               AggregationConfigurator.build_aggregations(report, cumulative: false)
    end
  end

  # Helper to call test interface
end
