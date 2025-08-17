defmodule AshReports.GroupProcessorTest do
  @moduledoc """
  Comprehensive tests for AshReports.GroupProcessor.

  Tests cover:
  - Group processing initialization
  - Multi-level group break detection
  - Stream-based processing
  - Variable system integration
  - Performance and edge cases
  """

  use ExUnit.Case, async: true

  alias AshReports.{Group, GroupProcessor}

  describe "GroupProcessor initialization" do
    test "creates new processor with empty groups" do
      processor = GroupProcessor.new([])

      assert processor.groups == []
      assert processor.current_values == %{}
      assert processor.previous_record == nil
      assert processor.group_counts == %{}
      assert is_map(processor.scope_manager)
    end

    test "creates processor with single group" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      assert length(processor.groups) == 1
      assert hd(processor.groups).name == :region
      assert GroupProcessor.has_groups?(processor)
      assert GroupProcessor.get_group_levels(processor) == [1]
    end

    test "creates processor with multiple groups" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :desc},
        %Group{name: :customer, level: 3, expression: {:field, :customer, :name}, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      assert length(processor.groups) == 3
      assert GroupProcessor.has_groups?(processor)
      assert GroupProcessor.get_group_levels(processor) == [1, 2, 3]
    end

    test "sorts groups by level automatically" do
      # Create groups out of order
      groups = [
        %Group{name: :customer, level: 3, expression: {:field, :customer, :name}, sort: :asc},
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :desc}
      ]

      processor = GroupProcessor.new(groups)

      # Should be sorted by level
      levels = Enum.map(processor.groups, & &1.level)
      assert levels == [1, 2, 3]

      names = Enum.map(processor.groups, & &1.name)
      assert names == [:region, :category, :customer]
    end
  end

  describe "group value extraction" do
    test "extracts simple field values" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :status, level: 2, expression: :status, sort: :asc}
      ]

      record = %{region: "West", status: "active", amount: 100}

      values = GroupProcessor.extract_group_values(groups, record)

      assert values == %{1 => "West", 2 => "active"}
    end

    test "extracts nested field values" do
      groups = [
        %Group{name: :customer, level: 1, expression: {:field, :customer, :name}, sort: :asc}
      ]

      record = %{
        customer: %{name: "John Doe", region: "West"},
        amount: 150
      }

      values = GroupProcessor.extract_group_values(groups, record)

      assert values == %{1 => "John Doe"}
    end

    test "extracts deeply nested field values" do
      groups = [
        %Group{
          name: :company,
          level: 1,
          expression: {:field, :customer, :company, :name},
          sort: :asc
        }
      ]

      record = %{
        customer: %{
          name: "John Doe",
          company: %{name: "ACME Corp", region: "West"}
        },
        amount: 200
      }

      values = GroupProcessor.extract_group_values(groups, record)

      assert values == %{1 => "ACME Corp"}
    end

    test "handles missing field values gracefully" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :customer, level: 2, expression: {:field, :customer, :name}, sort: :asc}
      ]

      record = %{region: "West", amount: 100}
      # Missing customer field

      values = GroupProcessor.extract_group_values(groups, record)

      assert values == %{1 => "West", 2 => nil}
    end

    test "handles function-based expressions" do
      groups = [
        %Group{
          name: :year,
          level: 1,
          expression: fn record -> Map.get(record, :date) |> then(&(&1.year)) end,
          sort: :asc
        }
      ]

      record = %{date: ~D[2024-03-15], amount: 100}

      values = GroupProcessor.extract_group_values(groups, record)

      assert values == %{1 => 2024}
    end
  end

  describe "single record processing" do
    test "processes first record without group changes" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)
      record = %{region: "West", amount: 100}

      {updated_processor, result} = GroupProcessor.process_record(processor, record)

      assert result.record == record
      assert result.group_changes == []
      assert result.group_values == %{1 => "West"}
      assert result.should_reset_variables == false

      assert updated_processor.current_values == %{1 => "West"}
      assert updated_processor.previous_record == record
    end

    test "detects group change on second record" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Process first record
      record1 = %{region: "West", amount: 100}
      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Process second record with different region
      record2 = %{region: "East", amount: 150}
      {_processor, result2} = GroupProcessor.process_record(processor, record2)

      assert result2.record == record2
      assert result2.group_changes == [{:group_change, 1}]
      assert result2.group_values == %{1 => "East"}
      assert result2.should_reset_variables == true
    end

    test "detects no change when group values are same" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Process first record
      record1 = %{region: "West", amount: 100}
      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Process second record with same region
      record2 = %{region: "West", amount: 150}
      {_processor, result2} = GroupProcessor.process_record(processor, record2)

      assert result2.record == record2
      assert result2.group_changes == [{:detail_change}]
      assert result2.group_values == %{1 => "West"}
      assert result2.should_reset_variables == false
    end
  end

  describe "multi-level group break detection" do
    setup do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :asc},
        %Group{name: :customer, level: 3, expression: {:field, :customer, :name}, sort: :asc}
      ]

      {:ok, groups: groups}
    end

    test "detects level 1 group change", %{groups: groups} do
      processor = GroupProcessor.new(groups)

      # First record
      record1 = %{
        region: "West",
        category: "Electronics",
        customer: %{name: "John"},
        amount: 100
      }

      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Second record - region changes (highest level)
      record2 = %{
        region: "East",
        category: "Electronics",
        customer: %{name: "John"},
        amount: 150
      }

      {_processor, result2} = GroupProcessor.process_record(processor, record2)

      assert result2.group_changes == [{:group_change, 1}]
      assert result2.should_reset_variables == true
    end

    test "detects level 2 group change", %{groups: groups} do
      processor = GroupProcessor.new(groups)

      # First record
      record1 = %{
        region: "West",
        category: "Electronics",
        customer: %{name: "John"},
        amount: 100
      }

      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Second record - category changes (level 2)
      record2 = %{
        region: "West",
        category: "Books",
        customer: %{name: "John"},
        amount: 150
      }

      {_processor, result2} = GroupProcessor.process_record(processor, record2)

      assert result2.group_changes == [{:group_change, 2}]
      assert result2.should_reset_variables == true
    end

    test "detects level 3 group change", %{groups: groups} do
      processor = GroupProcessor.new(groups)

      # First record
      record1 = %{
        region: "West",
        category: "Electronics",
        customer: %{name: "John"},
        amount: 100
      }

      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Second record - customer changes (level 3)
      record2 = %{
        region: "West",
        category: "Electronics",
        customer: %{name: "Jane"},
        amount: 150
      }

      {_processor, result2} = GroupProcessor.process_record(processor, record2)

      assert result2.group_changes == [{:group_change, 3}]
      assert result2.should_reset_variables == true
    end

    test "detects highest level change when multiple levels change", %{groups: groups} do
      processor = GroupProcessor.new(groups)

      # First record
      record1 = %{
        region: "West",
        category: "Electronics",
        customer: %{name: "John"},
        amount: 100
      }

      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Second record - region and category both change
      record2 = %{
        region: "East",
        category: "Books",
        customer: %{name: "John"},
        amount: 150
      }

      {_processor, result2} = GroupProcessor.process_record(processor, record2)

      # Should detect the highest level change (region = level 1)
      assert result2.group_changes == [{:group_change, 1}]
      assert result2.should_reset_variables == true
    end

    test "processes sequence with various group changes", %{groups: groups} do
      processor = GroupProcessor.new(groups)

      records = [
        %{region: "West", category: "Electronics", customer: %{name: "John"}, amount: 100},
        %{region: "West", category: "Electronics", customer: %{name: "Jane"}, amount: 150},
        %{region: "West", category: "Books", customer: %{name: "John"}, amount: 200},
        %{region: "East", category: "Electronics", customer: %{name: "Bob"}, amount: 250}
      ]

      results =
        records
        |> Enum.reduce({processor, []}, fn record, {proc, acc} ->
          {updated_proc, result} = GroupProcessor.process_record(proc, record)
          {updated_proc, [result | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      # First record: no changes
      assert Enum.at(results, 0).group_changes == []

      # Second record: customer change (level 3)
      assert Enum.at(results, 1).group_changes == [{:group_change, 3}]

      # Third record: category change (level 2)
      assert Enum.at(results, 2).group_changes == [{:group_change, 2}]

      # Fourth record: region change (level 1)
      assert Enum.at(results, 3).group_changes == [{:group_change, 1}]
    end
  end

  describe "group state tracking" do
    test "tracks group counts correctly" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      records = [
        %{region: "West", category: "A"},    # First record: no changes
        %{region: "West", category: "A"},    # Same values: detail change only
        %{region: "West", category: "B"},    # Category change: level 2
        %{region: "East", category: "A"}     # Region change: level 1 (highest)
      ]

      {final_processor, results} =
        records
        |> Enum.reduce({processor, []}, fn record, {proc, acc} ->
          {updated_proc, result} = GroupProcessor.process_record(proc, record)
          {updated_proc, [result | acc]}
        end)

      results = Enum.reverse(results)

      # Verify the changes detected
      assert Enum.at(results, 0).group_changes == []  # First record
      assert Enum.at(results, 1).group_changes == [{:detail_change}]  # Same values
      assert Enum.at(results, 2).group_changes == [{:group_change, 2}]  # Category change
      assert Enum.at(results, 3).group_changes == [{:group_change, 1}]  # Region change

      # Level 1 changed once (West -> East)
      assert GroupProcessor.get_group_count(final_processor, 1) == 1

      # Level 2 changed once (A -> B), not twice because the region change
      # is detected as level 1 change, not level 2
      assert GroupProcessor.get_group_count(final_processor, 2) == 1
    end

    test "retrieves current group values" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)
      record = %{region: "West", category: "Electronics"}

      {updated_processor, _result} = GroupProcessor.process_record(processor, record)

      assert GroupProcessor.get_group_value(updated_processor, 1) == "West"
      assert GroupProcessor.get_group_value(updated_processor, 2) == "Electronics"
      assert GroupProcessor.get_group_value(updated_processor, 3) == nil

      all_values = GroupProcessor.get_all_group_values(updated_processor)
      assert all_values == %{1 => "West", 2 => "Electronics"}
    end
  end

  describe "check group break (lookahead)" do
    test "checks for group break without updating state" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Process first record
      record1 = %{region: "West", amount: 100}
      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Check next record without processing
      next_record = %{region: "East", amount: 150}
      change = GroupProcessor.check_group_break(processor, next_record)

      assert change == {:group_change, 1}

      # Verify processor state unchanged
      assert GroupProcessor.get_group_value(processor, 1) == "West"
      assert processor.previous_record == record1
    end

    test "detects no change in lookahead" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Process first record
      record1 = %{region: "West", amount: 100}
      {processor, _result1} = GroupProcessor.process_record(processor, record1)

      # Check next record with same values
      next_record = %{region: "West", amount: 150}
      change = GroupProcessor.check_group_break(processor, next_record)

      assert change == {:detail_change}
    end
  end

  describe "stream processing" do
    test "processes stream of records" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      data = [
        %{region: "West", amount: 100},
        %{region: "West", amount: 150},
        %{region: "East", amount: 200}
      ]

      results =
        processor
        |> GroupProcessor.process_stream(data)
        |> Enum.to_list()

      assert length(results) == 3

      # First record
      assert hd(results).group_changes == []
      assert hd(results).group_values == %{1 => "West"}

      # Second record
      assert Enum.at(results, 1).group_changes == [{:detail_change}]
      assert Enum.at(results, 1).group_values == %{1 => "West"}

      # Third record
      assert Enum.at(results, 2).group_changes == [{:group_change, 1}]
      assert Enum.at(results, 2).group_values == %{1 => "East"}

      # All results should have processing metadata
      Enum.each(results, fn result ->
        assert Map.has_key?(result, :processed_at)
        assert is_integer(result.processed_at)
      end)
    end

    test "handles empty stream" do
      processor = GroupProcessor.new([])

      results =
        processor
        |> GroupProcessor.process_stream([])
        |> Enum.to_list()

      assert results == []
    end

    test "processes large stream efficiently" do
      groups = [
        %Group{name: :category, level: 1, expression: :category, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Generate large dataset
      data =
        1..1000
        |> Enum.map(fn i ->
          %{category: rem(i, 5), amount: i * 10}
        end)

      start_time = System.monotonic_time(:millisecond)

      results =
        processor
        |> GroupProcessor.process_stream(data)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      assert length(results) == 1000
      # Should process 1000 records reasonably quickly (< 1 second)
      assert duration < 1000

      # Verify group changes are detected correctly
      changes_count =
        results
        |> Enum.count(fn result ->
          result.group_changes != [] and result.should_reset_variables
        end)

      # Should have detected changes when category values change
      assert changes_count > 0
    end
  end

  describe "variable system integration" do
    test "determines variables to reset for group changes" do
      # Mock variables with different reset scopes
      variables = [
        %{name: :detail_var, reset_on: :detail},
        %{name: :group1_var, reset_on: :group, reset_group: 1},
        %{name: :group2_var, reset_on: :group, reset_group: 2},
        %{name: :report_var, reset_on: :report}
      ]

      # Test level 1 group change
      group_changes = [{:group_change, 1}]
      vars_to_reset = GroupProcessor.variables_to_reset(variables, group_changes)

      # Should reset detail and all group variables at or below level 1
      expected = [:detail_var, :group1_var, :group2_var]
      assert MapSet.new(vars_to_reset) == MapSet.new(expected)
    end

    test "determines variables to reset for level 2 group change" do
      variables = [
        %{name: :detail_var, reset_on: :detail},
        %{name: :group1_var, reset_on: :group, reset_group: 1},
        %{name: :group2_var, reset_on: :group, reset_group: 2},
        %{name: :group3_var, reset_on: :group, reset_group: 3},
        %{name: :report_var, reset_on: :report}
      ]

      # Test level 2 group change
      group_changes = [{:group_change, 2}]
      vars_to_reset = GroupProcessor.variables_to_reset(variables, group_changes)

      # Should reset detail and group variables at or below level 2
      expected = [:detail_var, :group2_var, :group3_var]
      assert MapSet.new(vars_to_reset) == MapSet.new(expected)
    end

    test "determines variables to reset for detail change only" do
      variables = [
        %{name: :detail_var, reset_on: :detail},
        %{name: :group1_var, reset_on: :group, reset_group: 1},
        %{name: :report_var, reset_on: :report}
      ]

      # Test detail change only
      group_changes = [{:detail_change}]
      vars_to_reset = GroupProcessor.variables_to_reset(variables, group_changes)

      # Should only reset detail variables
      assert vars_to_reset == [:detail_var]
    end
  end

  describe "processor reset and utilities" do
    test "resets processor to initial state" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Process some records
      record = %{region: "West", amount: 100}
      {processor, _result} = GroupProcessor.process_record(processor, record)

      assert processor.current_values != %{}
      assert processor.previous_record != nil

      # Reset processor
      reset_processor = GroupProcessor.reset(processor)

      assert reset_processor.current_values == %{}
      assert reset_processor.previous_record == nil
      assert reset_processor.group_counts == %{}
      # But groups configuration should be preserved
      assert reset_processor.groups == groups
    end

    test "utility functions work correctly" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      assert GroupProcessor.has_groups?(processor) == true
      assert GroupProcessor.get_group_levels(processor) == [1, 2]

      empty_processor = GroupProcessor.new([])
      assert GroupProcessor.has_groups?(empty_processor) == false
      assert GroupProcessor.get_group_levels(empty_processor) == []
    end
  end

  describe "error handling and edge cases" do
    test "handles records with missing group fields" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Record missing category field
      record = %{region: "West", amount: 100}

      {_processor, result} = GroupProcessor.process_record(processor, record)

      assert result.record == record
      assert result.group_values == %{1 => "West", 2 => nil}
    end

    test "handles complex expression evaluation errors gracefully" do
      groups = [
        %Group{
          name: :complex,
          level: 1,
          expression: {:some_unknown_function, :field},
          sort: :asc
        }
      ]

      processor = GroupProcessor.new(groups)
      record = %{field: "value", amount: 100}

      {_processor, result} = GroupProcessor.process_record(processor, record)

      # Should handle evaluation errors gracefully
      assert result.record == record
      assert result.group_values == %{1 => nil}
    end

    test "handles nil and empty values correctly" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      records = [
        %{region: nil, amount: 100},
        %{region: "", amount: 150},
        %{region: "West", amount: 200}
      ]

      results =
        records
        |> Enum.reduce({processor, []}, fn record, {proc, acc} ->
          {updated_proc, result} = GroupProcessor.process_record(proc, record)
          {updated_proc, [result | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      # First record: no changes (first record)
      assert Enum.at(results, 0).group_changes == []

      # Second record: nil -> "" is a change
      assert Enum.at(results, 1).group_changes == [{:group_change, 1}]

      # Third record: "" -> "West" is a change
      assert Enum.at(results, 2).group_changes == [{:group_change, 1}]
    end
  end
end
