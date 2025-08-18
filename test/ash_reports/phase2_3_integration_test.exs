defmodule AshReports.Phase23IntegrationTest do
  @moduledoc """
  Integration tests for Phase 2.3 Group Processing Engine.

  Tests the integration between GroupProcessor and other components:
  - VariableState integration for resets
  - ScopeManager coordination
  - QueryBuilder integration
  - Stream processing performance
  """

  use ExUnit.Case, async: true

  alias AshReports.{Group, GroupProcessor, Variable, VariableState}

  describe "GroupProcessor with VariableState integration" do
    test "coordinates variable resets on group changes" do
      # Define variables with different reset scopes
      variables = [
        %Variable{
          name: :detail_count,
          type: :count,
          expression: 1,
          reset_on: :detail,
          initial_value: 0
        },
        %Variable{
          name: :group_total,
          type: :sum,
          expression: :amount,
          reset_on: :group,
          reset_group: 1,
          initial_value: 0
        },
        %Variable{
          name: :report_total,
          type: :sum,
          expression: :amount,
          reset_on: :report,
          initial_value: 0
        }
      ]

      # Start variable state
      {:ok, var_pid} = VariableState.start_link(variables)

      # Define groups
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Process records with group change
      records = [
        %{region: "West", amount: 100},
        %{region: "West", amount: 150},
        %{region: "East", amount: 200}
      ]

      # Track which variables should reset
      results =
        records
        |> Enum.reduce({processor, []}, fn record, {proc, acc} ->
          {updated_proc, result} = GroupProcessor.process_record(proc, record)

          # Handle variable resets for group changes
          if result.should_reset_variables do
            GroupProcessor.handle_variable_resets(var_pid, result.group_changes)
          end

          {updated_proc, [result | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      # Verify group changes were detected correctly
      assert Enum.at(results, 0).group_changes == []
      assert Enum.at(results, 1).group_changes == [{:detail_change}]
      assert Enum.at(results, 2).group_changes == [{:group_change, 1}]

      # The key test is that reset coordination works
      assert length(results) == 3

      GenServer.stop(var_pid)
    end

    test "determines correct variables to reset for group changes" do
      variables = [
        %Variable{
          name: :detail_var,
          type: :count,
          expression: 1,
          reset_on: :detail,
          initial_value: 0
        },
        %Variable{
          name: :group1_var,
          type: :sum,
          expression: :amount,
          reset_on: :group,
          reset_group: 1,
          initial_value: 0
        },
        %Variable{
          name: :group2_var,
          type: :sum,
          expression: :amount,
          reset_on: :group,
          reset_group: 2,
          initial_value: 0
        },
        %Variable{
          name: :report_var,
          type: :sum,
          expression: :amount,
          reset_on: :report,
          initial_value: 0
        }
      ]

      # Test level 1 group change
      group_changes = [{:group_change, 1}]
      vars_to_reset = GroupProcessor.variables_to_reset(variables, group_changes)

      # Should reset detail and all group variables at or below level 1
      expected = [:detail_var, :group1_var, :group2_var]
      assert MapSet.new(vars_to_reset) == MapSet.new(expected)

      # Test level 2 group change
      group_changes = [{:group_change, 2}]
      vars_to_reset = GroupProcessor.variables_to_reset(variables, group_changes)

      # Should reset detail and group variables at or below level 2
      expected = [:detail_var, :group2_var]
      assert MapSet.new(vars_to_reset) == MapSet.new(expected)

      # Test detail change only
      group_changes = [{:detail_change}]
      vars_to_reset = GroupProcessor.variables_to_reset(variables, group_changes)

      # Should only reset detail variables
      assert vars_to_reset == [:detail_var]
    end
  end

  describe "GroupProcessor stream processing performance" do
    test "processes large datasets efficiently" do
      groups = [
        %Group{name: :category, level: 1, expression: :category, sort: :asc},
        %Group{name: :subcategory, level: 2, expression: :subcategory, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Generate dataset with 1000 records across 5 categories, 10 subcategories each
      data =
        1..1000
        |> Enum.map(fn i ->
          %{
            category: "Category_#{rem(i, 5)}",
            subcategory: "Sub_#{rem(i, 10)}",
            amount: i * 10,
            id: i
          }
        end)

      start_time = System.monotonic_time(:millisecond)

      results =
        processor
        |> GroupProcessor.process_stream(data)
        |> Enum.to_list()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should process 1000 records in reasonable time
      assert length(results) == 1000
      # Less than 1 second
      assert duration < 1000

      # Verify group changes were detected appropriately
      group_changes =
        results
        |> Enum.filter(fn result -> result.should_reset_variables end)
        |> length()

      # Should have detected multiple group changes
      assert group_changes > 0
      # But not every record
      assert group_changes < 1000

      # Verify metadata is added
      Enum.each(results, fn result ->
        assert Map.has_key?(result, :processed_at)
        assert is_integer(result.processed_at)
      end)
    end

    @tag :performance
    test "maintains consistent memory usage with streaming" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      # Generate larger dataset
      data =
        1..10_000
        |> Stream.map(fn i ->
          %{
            region: "Region_#{rem(i, 100)}",
            amount: i,
            # Add some bulk
            description: String.duplicate("data", 100)
          }
        end)

      initial_memory = :erlang.memory(:total)

      # Process as stream to maintain constant memory usage
      final_count =
        processor
        |> GroupProcessor.process_stream(data)
        |> Stream.map(fn _result -> 1 end)
        |> Enum.sum()

      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      assert final_count == 10_000

      # Memory increase should be reasonable (less than 50MB for 10k records)
      assert memory_increase < 50 * 1024 * 1024
    end
  end

  describe "GroupProcessor utility functions" do
    test "extracts group values from complex nested structures" do
      groups = [
        %Group{
          name: :customer_name,
          level: 1,
          expression: {:field, :customer, :name},
          sort: :asc
        },
        %Group{
          name: :company_region,
          level: 2,
          expression: {:field, :customer, :company, :region},
          sort: :asc
        }
      ]

      record = %{
        id: 1,
        amount: 500,
        customer: %{
          name: "John Doe",
          company: %{
            name: "ACME Corp",
            region: "West Coast"
          }
        }
      }

      values = GroupProcessor.extract_group_values(groups, record)

      assert values == %{
               1 => "John Doe",
               2 => "West Coast"
             }
    end

    test "handles function-based group expressions" do
      groups = [
        %Group{
          name: :year_quarter,
          level: 1,
          expression: fn record ->
            date = Map.get(record, :date, ~D[2024-01-01])
            "#{date.year}-Q#{div(date.month - 1, 3) + 1}"
          end,
          sort: :asc
        }
      ]

      records = [
        %{date: ~D[2024-01-15], amount: 100},
        %{date: ~D[2024-03-20], amount: 200},
        %{date: ~D[2024-04-10], amount: 300}
      ]

      processor = GroupProcessor.new(groups)

      results =
        records
        |> Enum.reduce({processor, []}, fn record, {proc, acc} ->
          {updated_proc, result} = GroupProcessor.process_record(proc, record)
          {updated_proc, [result | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      # First record: 2024-Q1
      assert Enum.at(results, 0).group_values == %{1 => "2024-Q1"}

      # Second record: same quarter, no group change
      assert Enum.at(results, 1).group_values == %{1 => "2024-Q1"}
      assert Enum.at(results, 1).group_changes == [{:detail_change}]

      # Third record: 2024-Q2, group change
      assert Enum.at(results, 2).group_values == %{1 => "2024-Q2"}
      assert Enum.at(results, 2).group_changes == [{:group_change, 1}]
    end
  end

  describe "error handling and edge cases" do
    test "handles empty data streams gracefully" do
      processor = GroupProcessor.new([])

      results =
        processor
        |> GroupProcessor.process_stream([])
        |> Enum.to_list()

      assert results == []
    end

    test "processes single record correctly" do
      groups = [
        %Group{name: :status, level: 1, expression: :status, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)
      record = %{status: "active", amount: 100}

      {_processor, result} = GroupProcessor.process_record(processor, record)

      assert result.record == record
      assert result.group_changes == []
      assert result.group_values == %{1 => "active"}
      assert result.should_reset_variables == false
    end

    test "handles missing fields in group expressions" do
      groups = [
        %Group{name: :region, level: 1, expression: :region, sort: :asc},
        %Group{name: :category, level: 2, expression: :category, sort: :asc}
      ]

      processor = GroupProcessor.new(groups)

      records = [
        # Missing category
        %{region: "West"},
        # Missing region
        %{category: "Electronics"},
        # Complete
        %{region: "East", category: "Books"}
      ]

      results =
        records
        |> Enum.reduce({processor, []}, fn record, {proc, acc} ->
          {updated_proc, result} = GroupProcessor.process_record(proc, record)
          {updated_proc, [result | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      # First record
      assert Enum.at(results, 0).group_values == %{1 => "West", 2 => nil}

      # Second record
      assert Enum.at(results, 1).group_values == %{1 => nil, 2 => "Electronics"}
      assert Enum.at(results, 1).group_changes == [{:group_change, 1}]

      # Third record
      assert Enum.at(results, 2).group_values == %{1 => "East", 2 => "Books"}
      assert Enum.at(results, 2).group_changes == [{:group_change, 1}]
    end
  end
end
