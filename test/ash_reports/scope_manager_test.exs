defmodule AshReports.ScopeManagerTest do
  @moduledoc """
  Tests for AshReports.ScopeManager hierarchical scope tracking.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Group, ScopeManager, Variable}

  describe "ScopeManager initialization" do
    test "creates empty scope manager" do
      scope_manager = ScopeManager.new([])

      assert scope_manager.groups == []
      assert scope_manager.current_values == %{}
      assert scope_manager.current_record == nil
      assert scope_manager.page_number == 1
      assert scope_manager.detail_count == 0
    end

    test "creates scope manager with single group" do
      groups = [
        %Group{name: :category, level: 1, expression: :category}
      ]

      scope_manager = ScopeManager.new(groups)

      assert length(scope_manager.groups) == 1
      assert hd(scope_manager.groups).level == 1
    end

    test "creates scope manager with multiple groups" do
      groups = [
        %Group{name: :region, level: 2, expression: :region},
        %Group{name: :category, level: 1, expression: :category}
      ]

      scope_manager = ScopeManager.new(groups)

      # Should be sorted by level
      assert length(scope_manager.groups) == 2
      assert Enum.at(scope_manager.groups, 0).level == 1
      assert Enum.at(scope_manager.groups, 1).level == 2
    end

    test "sorts groups by level" do
      groups = [
        %Group{name: :subcategory, level: 3, expression: :subcategory},
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region}
      ]

      scope_manager = ScopeManager.new(groups)

      levels = Enum.map(scope_manager.groups, & &1.level)
      assert levels == [1, 2, 3]
    end
  end

  describe "Detail record updates" do
    test "updates scope with first record" do
      groups = [
        %Group{name: :category, level: 1, expression: :category}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{category: "Electronics", product: "Phone", price: 100}

      updated_scope = ScopeManager.update_detail(scope_manager, record)

      assert updated_scope.current_record == record
      assert updated_scope.current_values == %{1 => "Electronics"}
      assert updated_scope.detail_count == 1
    end

    test "updates scope with multiple records" do
      groups = [
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region}
      ]

      scope_manager = ScopeManager.new(groups)

      record1 = %{category: "Electronics", region: "North", product: "Phone"}
      updated_scope1 = ScopeManager.update_detail(scope_manager, record1)

      record2 = %{category: "Electronics", region: "North", product: "Tablet"}
      updated_scope2 = ScopeManager.update_detail(updated_scope1, record2)

      assert updated_scope2.current_record == record2
      assert updated_scope2.current_values == %{1 => "Electronics", 2 => "North"}
      assert updated_scope2.detail_count == 2
    end

    test "handles records with missing group fields" do
      groups = [
        %Group{name: :category, level: 1, expression: :category}
      ]

      scope_manager = ScopeManager.new(groups)
      # Missing category
      record = %{product: "Phone", price: 100}

      updated_scope = ScopeManager.update_detail(scope_manager, record)

      assert updated_scope.current_record == record
      assert updated_scope.current_values == %{1 => nil}
      assert updated_scope.detail_count == 1
    end
  end

  describe "Scope change detection" do
    setup do
      groups = [
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region}
      ]

      scope_manager = ScopeManager.new(groups)
      initial_record = %{category: "Electronics", region: "North", product: "Phone"}
      scope_manager = ScopeManager.update_detail(scope_manager, initial_record)

      %{scope_manager: scope_manager}
    end

    test "detects no change for identical record", %{scope_manager: scope_manager} do
      same_record = %{category: "Electronics", region: "North", product: "Phone"}

      change = ScopeManager.check_scope_change(scope_manager, same_record)
      assert change == :no_change
    end

    test "detects detail change for same group values", %{scope_manager: scope_manager} do
      different_product = %{category: "Electronics", region: "North", product: "Tablet"}

      change = ScopeManager.check_scope_change(scope_manager, different_product)
      assert change == {:detail_change}
    end

    test "detects group change at level 2", %{scope_manager: scope_manager} do
      different_region = %{category: "Electronics", region: "South", product: "Phone"}

      change = ScopeManager.check_scope_change(scope_manager, different_region)
      assert change == {:group_change, 2}
    end

    test "detects group change at level 1", %{scope_manager: scope_manager} do
      different_category = %{category: "Clothing", region: "North", product: "Shirt"}

      change = ScopeManager.check_scope_change(scope_manager, different_category)
      assert change == {:group_change, 1}
    end

    test "detects highest level change when multiple groups change", %{
      scope_manager: scope_manager
    } do
      completely_different = %{category: "Clothing", region: "South", product: "Shirt"}

      change = ScopeManager.check_scope_change(scope_manager, completely_different)
      # Highest level that changed
      assert change == {:group_change, 1}
    end
  end

  describe "Page handling" do
    test "tracks page breaks" do
      scope_manager = ScopeManager.new([])

      assert ScopeManager.current_page(scope_manager) == 1

      updated_scope = ScopeManager.page_break(scope_manager)
      assert ScopeManager.current_page(updated_scope) == 2

      updated_scope2 = ScopeManager.page_break(updated_scope)
      assert ScopeManager.current_page(updated_scope2) == 3
    end

    test "maintains other state during page breaks" do
      groups = [%Group{name: :category, level: 1, expression: :category}]
      scope_manager = ScopeManager.new(groups)

      record = %{category: "Electronics", product: "Phone"}
      scope_manager = ScopeManager.update_detail(scope_manager, record)

      updated_scope = ScopeManager.page_break(scope_manager)

      assert ScopeManager.current_page(updated_scope) == 2
      assert updated_scope.current_record == record
      assert updated_scope.current_values == %{1 => "Electronics"}
      assert updated_scope.detail_count == 1
    end
  end

  describe "Utility functions" do
    test "gets current group values" do
      groups = [
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{category: "Electronics", region: "North", product: "Phone"}
      scope_manager = ScopeManager.update_detail(scope_manager, record)

      values = ScopeManager.current_group_values(scope_manager)
      assert values == %{1 => "Electronics", 2 => "North"}
    end

    test "gets specific group value" do
      groups = [
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{category: "Electronics", region: "North", product: "Phone"}
      scope_manager = ScopeManager.update_detail(scope_manager, record)

      assert ScopeManager.group_value(scope_manager, 1) == "Electronics"
      assert ScopeManager.group_value(scope_manager, 2) == "North"
      assert ScopeManager.group_value(scope_manager, 3) == nil
    end

    test "checks if grouping is configured" do
      empty_scope = ScopeManager.new([])
      assert ScopeManager.has_groups?(empty_scope) == false

      grouped_scope =
        ScopeManager.new([%Group{name: :category, level: 1, expression: :category}])

      assert ScopeManager.has_groups?(grouped_scope) == true
    end

    test "gets group levels" do
      groups = [
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region},
        %Group{name: :subcategory, level: 3, expression: :subcategory}
      ]

      scope_manager = ScopeManager.new(groups)
      levels = ScopeManager.group_levels(scope_manager)

      assert levels == [1, 2, 3]
    end

    test "gets detail count" do
      scope_manager = ScopeManager.new([])

      assert ScopeManager.detail_count(scope_manager) == 0

      record1 = %{product: "Phone"}
      scope_manager = ScopeManager.update_detail(scope_manager, record1)
      assert ScopeManager.detail_count(scope_manager) == 1

      record2 = %{product: "Tablet"}
      scope_manager = ScopeManager.update_detail(scope_manager, record2)
      assert ScopeManager.detail_count(scope_manager) == 2
    end
  end

  describe "Variable reset determination" do
    setup do
      [
        detail_var: Variable.new(:detail_var, type: :count, reset_on: :detail),
        group1_var: Variable.new(:group1_var, type: :sum, reset_on: :group, reset_group: 1),
        group2_var: Variable.new(:group2_var, type: :sum, reset_on: :group, reset_group: 2),
        page_var: Variable.new(:page_var, type: :sum, reset_on: :page),
        report_var: Variable.new(:report_var, type: :sum, reset_on: :report)
      ]
    end

    test "determines variables to reset for no change", variables do
      variables_list = Map.values(variables)

      to_reset = ScopeManager.variables_to_reset(variables_list, :no_change)
      assert to_reset == []
    end

    test "determines variables to reset for detail change", variables do
      variables_list = Map.values(variables)

      to_reset = ScopeManager.variables_to_reset(variables_list, {:detail_change})
      assert :detail_var in to_reset
      refute :group1_var in to_reset
      refute :group2_var in to_reset
      refute :page_var in to_reset
      refute :report_var in to_reset
    end

    test "determines variables to reset for group change level 1", variables do
      variables_list = Map.values(variables)

      to_reset = ScopeManager.variables_to_reset(variables_list, {:group_change, 1})
      assert :detail_var in to_reset
      assert :group1_var in to_reset
      # Higher level, not reset
      refute :group2_var in to_reset
      refute :page_var in to_reset
      refute :report_var in to_reset
    end

    test "determines variables to reset for group change level 2", variables do
      variables_list = Map.values(variables)

      to_reset = ScopeManager.variables_to_reset(variables_list, {:group_change, 2})
      assert :detail_var in to_reset
      # Lower level, not reset
      refute :group1_var in to_reset
      assert :group2_var in to_reset
      refute :page_var in to_reset
      refute :report_var in to_reset
    end

    test "determines variables to reset for page change", variables do
      variables_list = Map.values(variables)

      to_reset = ScopeManager.variables_to_reset(variables_list, {:page_change})
      assert :detail_var in to_reset
      assert :group1_var in to_reset
      assert :group2_var in to_reset
      assert :page_var in to_reset
      refute :report_var in to_reset
    end
  end

  describe "Complex group expressions" do
    test "handles function-based group expressions" do
      groups = [
        %Group{
          name: :custom,
          level: 1,
          expression: fn record -> record.category <> "_" <> record.region end
        }
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{category: "Electronics", region: "North", product: "Phone"}

      updated_scope = ScopeManager.update_detail(scope_manager, record)

      assert updated_scope.current_values == %{1 => "Electronics_North"}
    end

    test "handles tuple-based field references" do
      groups = [
        %Group{name: :nested, level: 1, expression: {:customer_region}}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{customer_region: "West Coast", product: "Laptop"}

      updated_scope = ScopeManager.update_detail(scope_manager, record)

      assert updated_scope.current_values == %{1 => "West Coast"}
    end

    test "handles complex expression fallback" do
      # Complex expressions that can't be easily evaluated should be stored as-is
      complex_expr = %{complex: "expression"}

      groups = [
        %Group{name: :complex, level: 1, expression: complex_expr}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{product: "Phone"}

      updated_scope = ScopeManager.update_detail(scope_manager, record)

      assert updated_scope.current_values == %{1 => complex_expr}
    end
  end

  describe "Scope reset and state management" do
    test "resets scope to initial state" do
      groups = [
        %Group{name: :category, level: 1, expression: :category}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{category: "Electronics", product: "Phone"}

      # Update state
      updated_scope = ScopeManager.update_detail(scope_manager, record)
      updated_scope = ScopeManager.page_break(updated_scope)

      # Verify state is changed
      assert updated_scope.current_record == record
      assert updated_scope.page_number == 2
      assert updated_scope.detail_count == 1

      # Reset
      reset_scope = ScopeManager.reset(updated_scope)

      # Verify reset to initial state but preserves group configuration
      assert reset_scope.groups == groups
      assert reset_scope.current_values == %{}
      assert reset_scope.current_record == nil
      assert reset_scope.page_number == 1
      assert reset_scope.detail_count == 0
    end

    test "preserves group configuration during reset" do
      groups = [
        %Group{name: :category, level: 1, expression: :category},
        %Group{name: :region, level: 2, expression: :region}
      ]

      scope_manager = ScopeManager.new(groups)
      record = %{category: "Electronics", region: "North", product: "Phone"}
      updated_scope = ScopeManager.update_detail(scope_manager, record)

      reset_scope = ScopeManager.reset(updated_scope)

      assert reset_scope.groups == groups
      assert length(reset_scope.groups) == 2
    end
  end
end
