defmodule AshReports.Typst.DataLoaderIntegrationTest do
  @moduledoc """
  Integration tests for Section 2.4.4: DSL-Driven Grouped Aggregation Integration.

  Tests the complete flow from Report DSL → DataLoader → ProducerConsumer config generation.
  Verifies that:
  - Single-level and multi-level grouping work correctly
  - Variables are filtered by reset_on and reset_group
  - Edge cases are handled gracefully
  - Generated configs match ProducerConsumer contract
  """

  use ExUnit.Case, async: true

  alias AshReports.Typst.DataLoader
  alias AshReports.{Report, Group, Variable}

  describe "single-level grouping integration (Section 2.4.4 Test 1)" do
    test "generates valid ProducerConsumer config for single group" do
      report = build_single_level_report()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      assert config.group_by == :region
      assert config.level == 1
      assert :sum in config.aggregations
      assert config.sort == :asc
    end

    test "includes only variables for group level 1" do
      report = build_single_level_report_with_multiple_variables()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      # Should only include :sum (reset_group: 1), not :count (reset_group: 2)
      assert :sum in config.aggregations
      refute :count in config.aggregations
    end
  end

  describe "multi-level grouping integration (Section 2.4.4 Test 2)" do
    test "generates cumulative grouping for two levels" do
      report = build_two_level_report()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [level1, level2] = result

      # Level 1: single field as atom
      assert level1.group_by == :region
      assert level1.level == 1
      assert :sum in level1.aggregations

      # Level 2: cumulative fields as list
      assert level2.group_by == [:region, :name]
      assert level2.level == 2
      assert :count in level2.aggregations
    end

    test "correctly filters variables by reset_group for each level" do
      report = build_two_level_report_with_mixed_variables()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [level1, level2] = result

      # Level 1 should have sum and avg (reset_group: 1)
      assert :sum in level1.aggregations
      assert :avg in level1.aggregations
      refute :count in level1.aggregations
      assert length(level1.aggregations) == 2

      # Level 2 should have count (reset_group: 2)
      assert :count in level2.aggregations
      refute :sum in level2.aggregations
      assert length(level2.aggregations) == 1
    end
  end

  describe "variable filtering by reset_on and reset_group (Section 2.4.4 Test 3)" do
    test "excludes variables with reset_on: :report from grouped aggregations" do
      report = build_report_with_report_variables()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      # Should not include report-level variable, falls back to defaults
      assert config.aggregations == [:sum, :count]
    end

    test "includes only variables with matching reset_group" do
      report = build_report_with_mismatched_reset_groups()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [level1, level2] = result

      # Level 1 should only have variables with reset_group: 1
      assert level1.aggregations == [:sum]

      # Level 2 should only have variables with reset_group: 2
      assert level2.aggregations == [:count]
    end

    test "handles variables with nil reset_group" do
      report = build_report_with_nil_reset_group()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      # Variables with nil reset_group should not be included, falls back to defaults
      assert config.aggregations == [:sum, :count]
    end
  end

  describe "edge case: reports with no groups (Section 2.4.4 Test 4)" do
    test "returns empty list for reports without groups" do
      report = build_report_without_groups()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert result == []
    end
  end

  describe "edge case: groups with no variables (Section 2.4.4 Test 5)" do
    test "generates config with default aggregations [:sum, :count]" do
      report = build_report_without_variables()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      assert config.group_by == :region
      assert config.level == 1
      # Implementation provides default aggregations when none specified
      assert config.aggregations == [:sum, :count]
    end
  end

  describe "edge case: variables with mismatched group levels (Section 2.4.4 Test 6)" do
    test "handles variables for non-existent group levels gracefully" do
      report = build_report_with_mismatched_variable_levels()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      # Level 1 exists but variable has reset_group: 3 (doesn't exist)
      # Should not crash, falls back to default aggregations
      assert config.level == 1
      assert config.aggregations == [:sum, :count]
    end
  end

  describe "edge case: complex expressions requiring fallback (Section 2.4.4 Test 7)" do
    test "handles Ash.Expr structures with fallback parsing" do
      report = build_report_with_ash_expr()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      # Should successfully parse Ash.Expr and extract field
      assert config.group_by == :region
      assert config.level == 1
    end

    test "falls back to group name when expression parsing fails" do
      report = build_report_with_unparseable_expression()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      # Should fall back to using group name
      assert config.group_by == :fallback_group
      assert config.level == 1
    end
  end

  describe "three-level hierarchical grouping (Section 2.4.4 Test 10)" do
    test "generates cumulative grouping for three levels" do
      report = build_three_level_report()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [level1, level2, level3] = result

      # Level 1: single field
      assert level1.group_by == :territory
      assert level1.level == 1

      # Level 2: two fields (cumulative)
      assert level2.group_by == [:territory, :customer_name]
      assert level2.level == 2

      # Level 3: three fields (cumulative)
      assert level3.group_by == [:territory, :customer_name, :order_type]
      assert level3.level == 3
    end
  end

  describe "ProducerConsumer contract validation (Section 2.4.4 Test 8)" do
    test "generated config has all required fields" do
      report = build_single_level_report()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      assert Map.has_key?(config, :group_by)
      assert Map.has_key?(config, :level)
      assert Map.has_key?(config, :aggregations)
      assert Map.has_key?(config, :sort)
    end

    test "group_by is atom for single field, list for multiple fields" do
      single_level = build_single_level_report()
      two_level = build_two_level_report()

      [single_config] = DataLoader.__test_build_grouped_aggregations__(single_level)
      [_level1, level2_config] = DataLoader.__test_build_grouped_aggregations__(two_level)

      # Single field should be atom
      assert is_atom(single_config.group_by)

      # Multiple fields should be list
      assert is_list(level2_config.group_by)
      assert length(level2_config.group_by) == 2
    end

    test "aggregations is a list of atoms" do
      report = build_single_level_report()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      assert is_list(config.aggregations)
      assert Enum.all?(config.aggregations, &is_atom/1)
    end

    test "sort is either :asc or :desc" do
      report = build_single_level_report()

      result = DataLoader.__test_build_grouped_aggregations__(report)

      assert [config] = result
      assert config.sort in [:asc, :desc]
    end
  end

  # Helper functions to build test reports

  defp build_single_level_report do
    %Report{
      name: :single_level_test,
      groups: [
        %Group{
          level: 1,
          name: :region_group,
          expression: :region,
          sort: :asc
        }
      ],
      variables: [
        %Variable{
          name: :total_sales,
          type: :sum,
          reset_on: :group,
          reset_group: 1
        }
      ]
    }
  end

  defp build_single_level_report_with_multiple_variables do
    %Report{
      name: :single_level_multi_vars,
      groups: [
        %Group{
          level: 1,
          name: :region_group,
          expression: :region,
          sort: :asc
        }
      ],
      variables: [
        %Variable{
          name: :level1_sum,
          type: :sum,
          reset_on: :group,
          reset_group: 1
        },
        %Variable{
          name: :level2_count,
          type: :count,
          reset_on: :group,
          reset_group: 2
        }
      ]
    }
  end

  defp build_two_level_report do
    %Report{
      name: :two_level_test,
      groups: [
        %Group{
          level: 1,
          name: :region_group,
          expression: :region,
          sort: :asc
        },
        %Group{
          level: 2,
          name: :customer_group,
          expression: :name,
          sort: :asc
        }
      ],
      variables: [
        %Variable{
          name: :region_sum,
          type: :sum,
          reset_on: :group,
          reset_group: 1
        },
        %Variable{
          name: :customer_count,
          type: :count,
          reset_on: :group,
          reset_group: 2
        }
      ]
    }
  end

  defp build_two_level_report_with_mixed_variables do
    %Report{
      name: :two_level_mixed_vars,
      groups: [
        %Group{level: 1, name: :region_group, expression: :region, sort: :asc},
        %Group{level: 2, name: :customer_group, expression: :name, sort: :asc}
      ],
      variables: [
        %Variable{name: :l1_sum, type: :sum, reset_on: :group, reset_group: 1},
        %Variable{name: :l1_avg, type: :average, reset_on: :group, reset_group: 1},
        %Variable{name: :l2_count, type: :count, reset_on: :group, reset_group: 2}
      ]
    }
  end

  defp build_report_with_report_variables do
    %Report{
      name: :report_vars_test,
      groups: [
        %Group{level: 1, name: :region_group, expression: :region, sort: :asc}
      ],
      variables: [
        %Variable{
          name: :report_total,
          type: :sum,
          reset_on: :report
          # No reset_group - should be excluded
        }
      ]
    }
  end

  defp build_report_with_mismatched_reset_groups do
    %Report{
      name: :mismatched_groups,
      groups: [
        %Group{level: 1, name: :region_group, expression: :region, sort: :asc},
        %Group{level: 2, name: :customer_group, expression: :name, sort: :asc}
      ],
      variables: [
        %Variable{name: :l1_sum, type: :sum, reset_on: :group, reset_group: 1},
        %Variable{name: :l2_count, type: :count, reset_on: :group, reset_group: 2}
      ]
    }
  end

  defp build_report_with_nil_reset_group do
    %Report{
      name: :nil_reset_group,
      groups: [
        %Group{level: 1, name: :region_group, expression: :region, sort: :asc}
      ],
      variables: [
        %Variable{
          name: :var_without_group,
          type: :sum,
          reset_on: :group,
          reset_group: nil
        }
      ]
    }
  end

  defp build_report_without_groups do
    %Report{
      name: :no_groups_test,
      groups: [],
      variables: [
        %Variable{name: :total, type: :sum, reset_on: :report}
      ]
    }
  end

  defp build_report_without_variables do
    %Report{
      name: :no_vars_test,
      groups: [
        %Group{level: 1, name: :region_group, expression: :region, sort: :asc}
      ],
      variables: []
    }
  end

  defp build_report_with_mismatched_variable_levels do
    %Report{
      name: :mismatched_levels,
      groups: [
        %Group{level: 1, name: :region_group, expression: :region, sort: :asc}
      ],
      variables: [
        %Variable{
          name: :level3_var,
          type: :sum,
          reset_on: :group,
          reset_group: 3
          # Group level 3 doesn't exist!
        }
      ]
    }
  end

  defp build_report_with_ash_expr do
    %Report{
      name: :ash_expr_test,
      groups: [
        %Group{
          level: 1,
          name: :region_group,
          expression: %{__struct__: Ash.Expr, expression: {:ref, [], :region}},
          sort: :asc
        }
      ],
      variables: []
    }
  end

  defp build_report_with_unparseable_expression do
    %Report{
      name: :fallback_test,
      groups: [
        %Group{
          level: 1,
          name: :fallback_group,
          expression: {:unknown, :format, "that", "cannot", "be", "parsed"},
          sort: :asc
        }
      ],
      variables: []
    }
  end

  defp build_three_level_report do
    %Report{
      name: :three_level_test,
      groups: [
        %Group{level: 1, name: :territory_group, expression: :territory, sort: :asc},
        %Group{level: 2, name: :customer_group, expression: :customer_name, sort: :asc},
        %Group{level: 3, name: :order_type_group, expression: :order_type, sort: :asc}
      ],
      variables: [
        %Variable{name: :l1_sum, type: :sum, reset_on: :group, reset_group: 1},
        %Variable{name: :l2_avg, type: :avg, reset_on: :group, reset_group: 2},
        %Variable{name: :l3_count, type: :count, reset_on: :group, reset_group: 3}
      ]
    }
  end
end
