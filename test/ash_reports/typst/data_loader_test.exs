defmodule AshReports.Typst.DataLoaderTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.DataLoader

  describe "load_for_typst/4" do
    test "handles report not found error" do
      # Test the error case without needing mocking
      # Since AshReports.Info.report/2 will return nil for nonexistent reports
      result = DataLoader.load_for_typst(NonExistentDomain, :nonexistent_report, %{})

      assert {:error, _reason} = result
      # We expect some kind of error - could be report_not_found or report_lookup_failed
    end
  end

  describe "typst_config/1" do
    test "creates default configuration" do
      config = DataLoader.typst_config()

      assert config[:chunk_size] == 1000
      assert config[:enable_streaming] == false
      assert config[:type_conversion][:datetime_format] == :iso8601
      assert config[:variable_scopes] == [:detail, :group, :page, :report]
    end

    test "allows configuration overrides" do
      config = DataLoader.typst_config(chunk_size: 2000, enable_streaming: true)

      assert config[:chunk_size] == 2000
      assert config[:enable_streaming] == true
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
      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

      result = call_private(DataLoader, :build_grouped_aggregations_from_dsl, [report])

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

  # Helper to call test interface
  defp call_private(_module, :build_grouped_aggregations_from_dsl, [report]) do
    DataLoader.__test_build_grouped_aggregations__(report)
  end
end
