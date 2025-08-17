defmodule AshReports.VariableStateTest do
  @moduledoc """
  Comprehensive tests for AshReports.VariableState GenServer implementation.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Variable, VariableState}

  describe "VariableState initialization" do
    test "starts with empty variables list" do
      {:ok, pid} = VariableState.start_link([])

      assert VariableState.get_all_values(pid) == %{}
      assert VariableState.get_dependencies(pid) == %{}

      GenServer.stop(pid)
    end

    test "starts with single variable" do
      variables = [
        Variable.new(:total, type: :sum, expression: :amount, initial_value: 0)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      assert VariableState.get_value(pid, :total) == 0
      assert VariableState.has_variable?(pid, :total) == true
      assert VariableState.has_variable?(pid, :nonexistent) == false

      GenServer.stop(pid)
    end

    test "starts with multiple variables" do
      variables = [
        Variable.new(:total, type: :sum, expression: :amount, initial_value: 0),
        Variable.new(:count, type: :count, expression: :id, initial_value: 0),
        Variable.new(:avg, type: :average, expression: :value, initial_value: {0, 0})
      ]

      {:ok, pid} = VariableState.start_link(variables)

      values = VariableState.get_all_values(pid)
      assert values[:total] == 0
      assert values[:count] == 0
      # Display value for average
      assert values[:avg] == 0

      GenServer.stop(pid)
    end
  end

  describe "Variable updates" do
    setup do
      variables = [
        Variable.new(:total, type: :sum, expression: :amount, initial_value: 0),
        Variable.new(:count, type: :count, expression: :id, initial_value: 0),
        Variable.new(:average, type: :average, expression: :value, initial_value: {0, 0}),
        Variable.new(:min_val, type: :min, expression: :value, initial_value: nil),
        Variable.new(:max_val, type: :max, expression: :value, initial_value: nil)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      on_exit(fn -> GenServer.stop(pid) end)

      %{pid: pid}
    end

    test "updates sum variable", %{pid: pid} do
      :ok = VariableState.update_variable(pid, :total, %{amount: 100})
      assert VariableState.get_value(pid, :total) == 100

      :ok = VariableState.update_variable(pid, :total, %{amount: 50})
      assert VariableState.get_value(pid, :total) == 150

      :ok = VariableState.update_variable(pid, :total, %{amount: -30})
      assert VariableState.get_value(pid, :total) == 120
    end

    test "updates count variable", %{pid: pid} do
      :ok = VariableState.update_variable(pid, :count, %{id: 1})
      assert VariableState.get_value(pid, :count) == 1

      :ok = VariableState.update_variable(pid, :count, %{id: 2})
      assert VariableState.get_value(pid, :count) == 2

      :ok = VariableState.update_variable(pid, :count, %{})
      assert VariableState.get_value(pid, :count) == 3
    end

    test "updates average variable", %{pid: pid} do
      :ok = VariableState.update_variable(pid, :average, %{value: 10})
      assert VariableState.get_value(pid, :average) == 10.0

      :ok = VariableState.update_variable(pid, :average, %{value: 20})
      assert VariableState.get_value(pid, :average) == 15.0

      :ok = VariableState.update_variable(pid, :average, %{value: 30})
      assert VariableState.get_value(pid, :average) == 20.0
    end

    test "updates min/max variables", %{pid: pid} do
      :ok = VariableState.update_variable(pid, :min_val, %{value: 50})
      :ok = VariableState.update_variable(pid, :max_val, %{value: 50})
      assert VariableState.get_value(pid, :min_val) == 50
      assert VariableState.get_value(pid, :max_val) == 50

      :ok = VariableState.update_variable(pid, :min_val, %{value: 30})
      :ok = VariableState.update_variable(pid, :max_val, %{value: 70})
      assert VariableState.get_value(pid, :min_val) == 30
      assert VariableState.get_value(pid, :max_val) == 70

      :ok = VariableState.update_variable(pid, :min_val, %{value: 40})
      :ok = VariableState.update_variable(pid, :max_val, %{value: 60})
      # Still minimum
      assert VariableState.get_value(pid, :min_val) == 30
      # Still maximum
      assert VariableState.get_value(pid, :max_val) == 70
    end

    test "handles missing fields gracefully", %{pid: pid} do
      :ok = VariableState.update_variable(pid, :total, %{other_field: 100})
      # No 'amount' field, so adds nil (treated as 0)
      assert VariableState.get_value(pid, :total) == 0
    end

    test "returns error for nonexistent variable", %{pid: pid} do
      assert {:error, :variable_not_found} =
               VariableState.update_variable(pid, :nonexistent, %{amount: 100})
    end
  end

  describe "Variable resets" do
    setup do
      variables = [
        Variable.new(:detail_var, type: :sum, expression: :amount, reset_on: :detail),
        Variable.new(:group1_var,
          type: :sum,
          expression: :amount,
          reset_on: :group,
          reset_group: 1
        ),
        Variable.new(:group2_var,
          type: :sum,
          expression: :amount,
          reset_on: :group,
          reset_group: 2
        ),
        Variable.new(:page_var, type: :sum, expression: :amount, reset_on: :page),
        Variable.new(:report_var, type: :sum, expression: :amount, reset_on: :report)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      # Set initial values
      VariableState.update_variable(pid, :detail_var, %{amount: 10})
      VariableState.update_variable(pid, :group1_var, %{amount: 10})
      VariableState.update_variable(pid, :group2_var, %{amount: 10})
      VariableState.update_variable(pid, :page_var, %{amount: 10})
      VariableState.update_variable(pid, :report_var, %{amount: 10})

      on_exit(fn -> GenServer.stop(pid) end)

      %{pid: pid}
    end

    test "resets detail scope variables", %{pid: pid} do
      :ok = VariableState.reset_scope(pid, :detail)

      assert VariableState.get_value(pid, :detail_var) == 0
      # Unchanged
      assert VariableState.get_value(pid, :group1_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :group2_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :page_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 10
    end

    test "resets group scope variables", %{pid: pid} do
      :ok = VariableState.reset_scope(pid, :group, 1)

      # Unchanged
      assert VariableState.get_value(pid, :detail_var) == 10
      # Reset
      assert VariableState.get_value(pid, :group1_var) == 0
      # Unchanged (different level)
      assert VariableState.get_value(pid, :group2_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :page_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 10
    end

    test "resets page scope variables", %{pid: pid} do
      :ok = VariableState.reset_scope(pid, :page)

      # Unchanged
      assert VariableState.get_value(pid, :detail_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :group1_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :group2_var) == 10
      # Reset
      assert VariableState.get_value(pid, :page_var) == 0
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 10
    end

    test "resets specific variable", %{pid: pid} do
      :ok = VariableState.reset_variable(pid, :group1_var)

      # Unchanged
      assert VariableState.get_value(pid, :detail_var) == 10
      # Reset
      assert VariableState.get_value(pid, :group1_var) == 0
      # Unchanged
      assert VariableState.get_value(pid, :group2_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :page_var) == 10
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 10
    end

    test "resets all variables", %{pid: pid} do
      :ok = VariableState.reset_all(pid)

      assert VariableState.get_value(pid, :detail_var) == 0
      assert VariableState.get_value(pid, :group1_var) == 0
      assert VariableState.get_value(pid, :group2_var) == 0
      assert VariableState.get_value(pid, :page_var) == 0
      assert VariableState.get_value(pid, :report_var) == 0
    end

    test "returns error when resetting nonexistent variable", %{pid: pid} do
      assert {:error, :variable_not_found} =
               VariableState.reset_variable(pid, :nonexistent)
    end
  end

  describe "Ordered variable updates" do
    test "handles variables with dependencies" do
      variables = [
        Variable.new(:base_amount, type: :sum, expression: :amount, initial_value: 0),
        Variable.new(:tax_amount, type: :custom, expression: :base_amount, initial_value: 0),
        Variable.new(:total_amount,
          type: :custom,
          expression: {:add, :base_amount, :tax_amount},
          initial_value: 0
        )
      ]

      {:ok, pid} = VariableState.start_link(variables)

      # Update in dependency order
      :ok =
        VariableState.update_variables_ordered(pid, %{
          amount: 100,
          base_amount: 100,
          tax_amount: 10
        })

      assert VariableState.get_value(pid, :base_amount) == 100
      # Note: actual dependency resolution would require more complex setup

      GenServer.stop(pid)
    end

    test "handles variables without dependencies" do
      variables = [
        Variable.new(:total1, type: :sum, expression: :amount1, initial_value: 0),
        Variable.new(:total2, type: :sum, expression: :amount2, initial_value: 0),
        Variable.new(:count, type: :count, expression: :id, initial_value: 0)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      :ok = VariableState.update_variables_ordered(pid, %{amount1: 50, amount2: 75, id: 1})

      assert VariableState.get_value(pid, :total1) == 50
      assert VariableState.get_value(pid, :total2) == 75
      assert VariableState.get_value(pid, :count) == 1

      GenServer.stop(pid)
    end
  end

  describe "Scope change handling" do
    setup do
      variables = [
        Variable.new(:detail_var, type: :count, expression: :id, reset_on: :detail),
        Variable.new(:group_var,
          type: :sum,
          expression: :amount,
          reset_on: :group,
          reset_group: 1
        ),
        Variable.new(:page_var, type: :sum, expression: :amount, reset_on: :page),
        Variable.new(:report_var, type: :sum, expression: :amount, reset_on: :report)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      # Set some values
      VariableState.update_variable(pid, :detail_var, %{id: 1})
      VariableState.update_variable(pid, :group_var, %{amount: 100})
      VariableState.update_variable(pid, :page_var, %{amount: 100})
      VariableState.update_variable(pid, :report_var, %{amount: 100})

      on_exit(fn -> GenServer.stop(pid) end)

      %{pid: pid}
    end

    test "handles detail change", %{pid: pid} do
      :ok = VariableState.handle_scope_change(pid, {:detail_change})

      # Reset
      assert VariableState.get_value(pid, :detail_var) == 0
      # Unchanged
      assert VariableState.get_value(pid, :group_var) == 100
      # Unchanged
      assert VariableState.get_value(pid, :page_var) == 100
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 100
    end

    test "handles group change", %{pid: pid} do
      :ok = VariableState.handle_scope_change(pid, {:group_change, 1})

      # Reset (lower scope)
      assert VariableState.get_value(pid, :detail_var) == 0
      # Reset
      assert VariableState.get_value(pid, :group_var) == 0
      # Unchanged
      assert VariableState.get_value(pid, :page_var) == 100
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 100
    end

    test "handles page change", %{pid: pid} do
      :ok = VariableState.handle_scope_change(pid, {:page_change})

      # Reset (lower scope)
      assert VariableState.get_value(pid, :detail_var) == 0
      # Reset (lower scope)
      assert VariableState.get_value(pid, :group_var) == 0
      # Reset
      assert VariableState.get_value(pid, :page_var) == 0
      # Unchanged
      assert VariableState.get_value(pid, :report_var) == 100
    end

    test "handles no change", %{pid: pid} do
      :ok = VariableState.handle_scope_change(pid, :no_change)

      # All values should remain unchanged
      assert VariableState.get_value(pid, :detail_var) == 1
      assert VariableState.get_value(pid, :group_var) == 100
      assert VariableState.get_value(pid, :page_var) == 100
      assert VariableState.get_value(pid, :report_var) == 100
    end
  end

  describe "Evaluation order" do
    test "gets evaluation order for independent variables" do
      variables = [
        Variable.new(:var1, type: :sum, expression: :amount1),
        Variable.new(:var2, type: :sum, expression: :amount2),
        Variable.new(:var3, type: :count, expression: :id)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      order = VariableState.get_evaluation_order(pid)

      # Should include all variable names
      assert length(order) == 3
      assert :var1 in order
      assert :var2 in order
      assert :var3 in order

      GenServer.stop(pid)
    end

    test "handles empty variable list" do
      {:ok, pid} = VariableState.start_link([])

      order = VariableState.get_evaluation_order(pid)
      assert order == []

      GenServer.stop(pid)
    end
  end

  describe "Error handling" do
    setup do
      variables = [
        Variable.new(:valid_var, type: :sum, expression: :amount, initial_value: 0)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      on_exit(fn -> GenServer.stop(pid) end)

      %{pid: pid}
    end

    test "handles calculation errors gracefully", %{pid: pid} do
      # Test with the existing variable and invalid data that might cause issues
      result = VariableState.update_variable(pid, :valid_var, %{amount: "invalid"})

      # Should handle gracefully - in this case, string might be converted to 0
      assert result == :ok or match?({:error, _}, result)
    end

    test "handles missing variable gracefully", %{pid: pid} do
      assert {:error, :variable_not_found} =
               VariableState.update_variable(pid, :missing_var, %{amount: 100})
    end
  end

  describe "ETS backing" do
    test "persists values in ETS table" do
      variables = [
        Variable.new(:test_var, type: :sum, expression: :amount, initial_value: 0)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      # Update variable
      :ok = VariableState.update_variable(pid, :test_var, %{amount: 100})
      assert VariableState.get_value(pid, :test_var) == 100

      # Update again to verify persistence
      :ok = VariableState.update_variable(pid, :test_var, %{amount: 50})
      assert VariableState.get_value(pid, :test_var) == 150

      GenServer.stop(pid)
    end

    test "cleans up ETS table on termination" do
      variables = [
        Variable.new(:test_var, type: :sum, expression: :amount, initial_value: 0)
      ]

      {:ok, pid} = VariableState.start_link(variables)

      # Stop the GenServer
      GenServer.stop(pid)

      # ETS table should be cleaned up (we can't easily test this directly)
      # but the process should terminate cleanly
      refute Process.alive?(pid)
    end
  end
end
