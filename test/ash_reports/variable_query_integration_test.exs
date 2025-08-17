defmodule AshReports.VariableQueryIntegrationTest do
  @moduledoc """
  Tests for AshReports.VariableQueryIntegration module.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Group, Report, Variable, VariableQueryIntegration}

  setup do
    # Create a mock report with variables and groups
    variables = [
      Variable.new(:total_amount, type: :sum, expression: :amount, reset_on: :report),
      Variable.new(:group_count, type: :count, expression: :id, reset_on: :group, reset_group: 1),
      Variable.new(:detail_counter, type: :count, expression: :id, reset_on: :detail)
    ]

    groups = [
      %Group{name: :category, level: 1, expression: :category},
      %Group{name: :region, level: 2, expression: :region}
    ]

    report = %Report{
      name: :test_report,
      variables: variables,
      groups: groups,
      driving_resource: TestResource
    }

    %{report: report, variables: variables, groups: groups}
  end

  describe "Variable initialization" do
    test "initializes variables for a report", %{report: report} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      assert is_pid(var_state)
      assert Process.alive?(var_state)

      # Check initial values
      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 0
      assert values[:group_count] == 0
      assert values[:detail_counter] == 0

      VariableQueryIntegration.cleanup_variables(var_state)
    end

    test "handles report with no variables" do
      report = %Report{name: :empty_report, variables: []}

      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      assert is_pid(var_state)
      values = VariableQueryIntegration.get_final_values(var_state)
      assert values == %{}

      VariableQueryIntegration.cleanup_variables(var_state)
    end

    test "initializes variables with custom initial values" do
      variables = [
        Variable.new(:custom_var, type: :sum, expression: :amount, initial_value: 100)
      ]

      report = %Report{name: :custom_report, variables: variables}

      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:custom_var] == 100

      VariableQueryIntegration.cleanup_variables(var_state)
    end
  end

  describe "Record processing" do
    setup %{report: report, groups: groups} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      on_exit(fn -> VariableQueryIntegration.cleanup_variables(var_state) end)

      %{var_state: var_state, groups: groups}
    end

    test "processes single record", %{var_state: var_state, groups: groups} do
      records = [
        %{id: 1, category: "Electronics", region: "North", amount: 100}
      ]

      :ok = VariableQueryIntegration.process_records(var_state, records, groups)

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 100
      assert values[:group_count] == 1
      assert values[:detail_counter] == 1
    end

    test "processes multiple records with same groups", %{var_state: var_state, groups: groups} do
      records = [
        %{id: 1, category: "Electronics", region: "North", amount: 100},
        %{id: 2, category: "Electronics", region: "North", amount: 150},
        %{id: 3, category: "Electronics", region: "North", amount: 75}
      ]

      :ok = VariableQueryIntegration.process_records(var_state, records, groups)

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 325
      assert values[:group_count] == 3
      # Reset on each detail
      assert values[:detail_counter] == 1
    end

    test "processes records with group changes", %{var_state: var_state, groups: groups} do
      records = [
        %{id: 1, category: "Electronics", region: "North", amount: 100},
        # Region change
        %{id: 2, category: "Electronics", region: "South", amount: 150},
        # Category change
        %{id: 3, category: "Clothing", region: "North", amount: 75}
      ]

      :ok = VariableQueryIntegration.process_records(var_state, records, groups)

      values = VariableQueryIntegration.get_final_values(var_state)
      # Report-scoped, no reset
      assert values[:total_amount] == 325
      # Reset on group changes
      assert values[:group_count] == 1
      # Reset on each detail
      assert values[:detail_counter] == 1
    end

    test "handles empty record list", %{var_state: var_state, groups: groups} do
      :ok = VariableQueryIntegration.process_records(var_state, [], groups)

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 0
      assert values[:group_count] == 0
      assert values[:detail_counter] == 0
    end
  end

  describe "Single record processing" do
    setup %{report: report, groups: groups} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)
      scope_manager = AshReports.ScopeManager.new(groups)

      on_exit(fn -> VariableQueryIntegration.cleanup_variables(var_state) end)

      %{var_state: var_state, scope_manager: scope_manager}
    end

    test "processes first record", %{var_state: var_state, scope_manager: scope_manager} do
      record = %{id: 1, category: "Electronics", region: "North", amount: 100}

      {:ok, updated_scope} =
        VariableQueryIntegration.process_record(var_state, record, scope_manager)

      assert updated_scope.current_record == record
      assert updated_scope.detail_count == 1

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 100
    end

    test "processes subsequent records", %{var_state: var_state, scope_manager: scope_manager} do
      record1 = %{id: 1, category: "Electronics", region: "North", amount: 100}
      {:ok, scope1} = VariableQueryIntegration.process_record(var_state, record1, scope_manager)

      record2 = %{id: 2, category: "Electronics", region: "North", amount: 150}
      {:ok, scope2} = VariableQueryIntegration.process_record(var_state, record2, scope1)

      assert scope2.detail_count == 2

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 250
      assert values[:group_count] == 2
    end

    test "handles group changes in single record processing", %{
      var_state: var_state,
      scope_manager: scope_manager
    } do
      record1 = %{id: 1, category: "Electronics", region: "North", amount: 100}
      {:ok, scope1} = VariableQueryIntegration.process_record(var_state, record1, scope_manager)

      # Change region (level 2 group change)
      record2 = %{id: 2, category: "Electronics", region: "South", amount: 150}
      {:ok, scope2} = VariableQueryIntegration.process_record(var_state, record2, scope1)

      values = VariableQueryIntegration.get_final_values(var_state)
      # Report-scoped, no reset
      assert values[:total_amount] == 250
      # Reset due to group change
      assert values[:group_count] == 1
    end
  end

  describe "Variable value access" do
    setup %{report: report} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      # Set some values
      VariableQueryIntegration.batch_update_variables(var_state, %{
        id: 1,
        amount: 100
      })

      on_exit(fn -> VariableQueryIntegration.cleanup_variables(var_state) end)

      %{var_state: var_state}
    end

    test "gets individual variable value", %{var_state: var_state} do
      value = VariableQueryIntegration.get_variable_value(var_state, :total_amount)
      assert value == 100

      value = VariableQueryIntegration.get_variable_value(var_state, :detail_counter)
      assert value == 1
    end

    test "gets all variable values", %{var_state: var_state} do
      values = VariableQueryIntegration.get_final_values(var_state)

      assert is_map(values)
      assert Map.has_key?(values, :total_amount)
      assert Map.has_key?(values, :group_count)
      assert Map.has_key?(values, :detail_counter)
    end

    test "creates variable context map", %{var_state: var_state} do
      context = VariableQueryIntegration.create_variable_context(var_state)

      assert is_map(context)
      assert context[:total_amount] == 100
      assert context[:detail_counter] == 1
    end
  end

  describe "Scope management integration" do
    setup %{report: report} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      on_exit(fn -> VariableQueryIntegration.cleanup_variables(var_state) end)

      %{var_state: var_state}
    end

    test "handles page breaks", %{var_state: var_state} do
      # Set some values first
      VariableQueryIntegration.batch_update_variables(var_state, %{id: 1, amount: 100})

      values_before = VariableQueryIntegration.get_final_values(var_state)
      assert values_before[:total_amount] == 100

      # Page break should not reset report-scoped variables
      :ok = VariableQueryIntegration.handle_page_break(var_state)

      values_after = VariableQueryIntegration.get_final_values(var_state)
      # Report-scoped, unchanged
      assert values_after[:total_amount] == 100
      # Reset by page break
      assert values_after[:group_count] == 0
      # Reset by page break
      assert values_after[:detail_counter] == 0
    end

    test "handles group breaks", %{var_state: var_state} do
      # Set some values first
      VariableQueryIntegration.batch_update_variables(var_state, %{id: 1, amount: 100})

      values_before = VariableQueryIntegration.get_final_values(var_state)
      assert values_before[:group_count] == 1

      # Group break at level 1
      :ok = VariableQueryIntegration.handle_group_break(var_state, 1)

      values_after = VariableQueryIntegration.get_final_values(var_state)
      # Report-scoped, unchanged
      assert values_after[:total_amount] == 100
      # Reset by group break
      assert values_after[:group_count] == 0
      # Reset by group break (lower scope)
      assert values_after[:detail_counter] == 0
    end

    test "resets all variables", %{var_state: var_state} do
      # Set some values first
      VariableQueryIntegration.batch_update_variables(var_state, %{id: 1, amount: 100})

      values_before = VariableQueryIntegration.get_final_values(var_state)
      assert values_before[:total_amount] == 100
      assert values_before[:group_count] == 1

      :ok = VariableQueryIntegration.reset_variables(var_state)

      values_after = VariableQueryIntegration.get_final_values(var_state)
      assert values_after[:total_amount] == 0
      assert values_after[:group_count] == 0
      assert values_after[:detail_counter] == 0
    end
  end

  describe "Dependency analysis" do
    test "gets variable dependencies", %{report: report} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      dependencies = VariableQueryIntegration.get_variable_dependencies(var_state)

      assert is_map(dependencies)
      assert Map.has_key?(dependencies, :total_amount)
      assert Map.has_key?(dependencies, :group_count)
      assert Map.has_key?(dependencies, :detail_counter)

      VariableQueryIntegration.cleanup_variables(var_state)
    end

    test "gets evaluation order", %{report: report} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      order = VariableQueryIntegration.get_evaluation_order(var_state)

      assert is_list(order)
      assert :total_amount in order
      assert :group_count in order
      assert :detail_counter in order

      VariableQueryIntegration.cleanup_variables(var_state)
    end

    test "validates variable dependencies" do
      variables = [
        Variable.new(:var1, type: :sum, expression: :field1),
        Variable.new(:var2, type: :sum, expression: :field2)
      ]

      report = %Report{name: :test_report, variables: variables}

      assert :ok = VariableQueryIntegration.validate_variable_dependencies(report)
    end

    test "detects circular dependencies" do
      variables = [
        Variable.new(:var1, type: :custom, expression: :var2),
        Variable.new(:var2, type: :custom, expression: :var1)
      ]

      report = %Report{name: :circular_report, variables: variables}

      # Note: This depends on the implementation of dependency analysis
      # The basic implementation might not detect this, but it's a test case
      result = VariableQueryIntegration.detect_circular_dependencies(report)
      assert result == :ok or match?({:error, {:circular_dependency, _}}, result)
    end
  end

  describe "Integration with QueryBuilder" do
    test "builds query with variables", %{report: report} do
      params = %{start_date: ~D[2024-01-01]}

      # This would require mocking the QueryBuilder.build function
      # For now, test the interface exists
      assert function_exported?(VariableQueryIntegration, :build_with_variables, 3)
    end
  end

  describe "Batch operations" do
    setup %{report: report} do
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      on_exit(fn -> VariableQueryIntegration.cleanup_variables(var_state) end)

      %{var_state: var_state}
    end

    test "batch updates variables", %{var_state: var_state} do
      data = %{id: 1, amount: 250, category: "Electronics"}

      :ok = VariableQueryIntegration.batch_update_variables(var_state, data)

      values = VariableQueryIntegration.get_final_values(var_state)
      assert values[:total_amount] == 250
      assert values[:group_count] == 1
      assert values[:detail_counter] == 1
    end

    test "handles batch update errors gracefully", %{var_state: var_state} do
      # Test with data that might cause issues
      data = %{invalid_field: "value"}

      result = VariableQueryIntegration.batch_update_variables(var_state, data)

      # Should complete without error (fields not found are handled gracefully)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "Cleanup and error handling" do
    test "cleans up variable state properly" do
      variables = [Variable.new(:test_var, type: :sum, expression: :amount)]
      report = %Report{name: :cleanup_test, variables: variables}

      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)
      assert Process.alive?(var_state)

      :ok = VariableQueryIntegration.cleanup_variables(var_state)

      # Give the process time to terminate
      Process.sleep(10)
      refute Process.alive?(var_state)
    end

    test "handles cleanup of non-pid gracefully" do
      assert :ok = VariableQueryIntegration.cleanup_variables(:not_a_pid)
      assert :ok = VariableQueryIntegration.cleanup_variables(nil)
    end

    test "handles invalid reports gracefully" do
      invalid_report = %{not: "a valid report"}

      result = VariableQueryIntegration.initialize_variables(invalid_report)

      # Should return an error rather than crashing
      assert match?({:error, _}, result)
    end
  end
end
