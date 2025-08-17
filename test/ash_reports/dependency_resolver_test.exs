defmodule AshReports.DependencyResolverTest do
  @moduledoc """
  Tests for AshReports.DependencyResolver variable dependency analysis.
  """

  use ExUnit.Case, async: true

  alias AshReports.{DependencyResolver, Variable}

  describe "Dependency graph building" do
    test "builds graph for independent variables" do
      variables = [
        Variable.new(:var1, type: :sum, expression: :field1),
        Variable.new(:var2, type: :count, expression: :field2),
        Variable.new(:var3, type: :average, expression: :field3)
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)

      assert Map.has_key?(graph, :var1)
      assert Map.has_key?(graph, :var2)
      assert Map.has_key?(graph, :var3)

      # Independent variables should have empty dependency lists
      assert graph[:var1] == []
      assert graph[:var2] == []
      assert graph[:var3] == []
    end

    test "builds graph for variables with field dependencies" do
      variables = [
        Variable.new(:base_amount, type: :sum, expression: :amount),
        Variable.new(:related_amount, type: :sum, expression: {:customer, :amount}),
        Variable.new(:complex_amount, type: :sum, expression: {:field, :order, :total})
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)

      # Field references become dependencies in the analysis
      assert graph[:base_amount] == [:amount]
      # Relationship reference
      assert graph[:related_amount] == [:customer]
      # Field from explicit relationship
      assert graph[:complex_amount] == [:total]
    end

    test "handles empty variable list" do
      {:ok, graph} = DependencyResolver.build_graph([])

      assert graph == %{}
    end

    test "handles variables with function expressions" do
      variables = [
        Variable.new(:func_var, type: :custom, expression: fn _data -> 42 end)
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)

      # Function expressions can't be analyzed for dependencies
      assert graph[:func_var] == []
    end

    test "handles variables with nil expressions" do
      variables = [
        Variable.new(:nil_var, type: :count, expression: nil)
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)

      assert graph[:nil_var] == []
    end
  end

  describe "Topological sorting" do
    test "resolves order for independent variables" do
      graph = %{
        var1: [],
        var2: [],
        var3: []
      }

      {:ok, order} = DependencyResolver.resolve_order(graph)

      # Order should include all variables
      assert length(order) == 3
      assert :var1 in order
      assert :var2 in order
      assert :var3 in order
    end

    test "resolves order for simple dependency chain" do
      # var1 -> var2 -> var3
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2]
      }

      {:ok, order} = DependencyResolver.resolve_order(graph)

      assert order == [:var1, :var2, :var3]
    end

    test "resolves order for complex dependencies" do
      # var1 and var2 are independent
      # var3 depends on both var1 and var2
      # var4 depends on var3
      graph = %{
        var1: [],
        var2: [],
        var3: [:var1, :var2],
        var4: [:var3]
      }

      {:ok, order} = DependencyResolver.resolve_order(graph)

      # var1 and var2 should come before var3, var3 before var4
      var1_index = Enum.find_index(order, &(&1 == :var1))
      var2_index = Enum.find_index(order, &(&1 == :var2))
      var3_index = Enum.find_index(order, &(&1 == :var3))
      var4_index = Enum.find_index(order, &(&1 == :var4))

      assert var1_index < var3_index
      assert var2_index < var3_index
      assert var3_index < var4_index
    end

    test "handles empty graph" do
      {:ok, order} = DependencyResolver.resolve_order(%{})

      assert order == []
    end

    test "detects circular dependencies" do
      # var1 -> var2 -> var3 -> var1 (circular)
      graph = %{
        var1: [:var3],
        var2: [:var1],
        var3: [:var2]
      }

      assert {:error, {:circular_dependency, cycle}} = DependencyResolver.resolve_order(graph)
      assert is_list(cycle)
      assert length(cycle) > 0
    end

    test "detects self-referencing variables" do
      graph = %{
        # Self-reference
        var1: [:var1]
      }

      assert {:error, {:circular_dependency, cycle}} = DependencyResolver.resolve_order(graph)
      assert :var1 in cycle
    end
  end

  describe "Partial order resolution" do
    test "resolves partial order for affected variables" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2],
        var4: [],
        var5: [:var4]
      }

      # If var1 changes, var2 and var3 are affected
      {:ok, order} = DependencyResolver.resolve_partial_order(graph, [:var1])

      assert :var1 in order
      assert :var2 in order
      assert :var3 in order
      refute :var4 in order
      refute :var5 in order

      # Order should be maintained
      var1_index = Enum.find_index(order, &(&1 == :var1))
      var2_index = Enum.find_index(order, &(&1 == :var2))
      var3_index = Enum.find_index(order, &(&1 == :var3))

      assert var1_index < var2_index
      assert var2_index < var3_index
    end

    test "resolves partial order for multiple starting variables" do
      graph = %{
        var1: [],
        var2: [],
        var3: [:var1, :var2],
        var4: [:var3]
      }

      # Both var1 and var2 change
      {:ok, order} = DependencyResolver.resolve_partial_order(graph, [:var1, :var2])

      # All variables are affected
      assert length(order) == 4

      var3_index = Enum.find_index(order, &(&1 == :var3))
      var4_index = Enum.find_index(order, &(&1 == :var4))

      assert var3_index < var4_index
    end

    test "handles partial order with no affected variables" do
      graph = %{
        var1: [],
        # Depends on external variable
        var2: [:var3],
        var3: []
      }

      {:ok, order} = DependencyResolver.resolve_partial_order(graph, [:var1])

      # Only var1 is affected
      assert order == [:var1]
    end
  end

  describe "Dependency analysis" do
    test "checks direct dependencies" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2]
      }

      assert DependencyResolver.depends_on?(graph, :var2, :var1) == true
      assert DependencyResolver.depends_on?(graph, :var1, :var2) == false
    end

    test "checks transitive dependencies" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2]
      }

      assert DependencyResolver.depends_on?(graph, :var3, :var1) == true
      assert DependencyResolver.depends_on?(graph, :var3, :var2) == true
      assert DependencyResolver.depends_on?(graph, :var1, :var3) == false
    end

    test "handles variables with no dependencies" do
      graph = %{
        var1: [],
        var2: []
      }

      assert DependencyResolver.depends_on?(graph, :var1, :var2) == false
      assert DependencyResolver.depends_on?(graph, :var2, :var1) == false
    end

    test "finds direct dependents" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var1],
        var4: [:var2]
      }

      dependents = DependencyResolver.find_dependents(graph, :var1)

      assert :var2 in dependents
      assert :var3 in dependents
      # Transitive dependent
      assert :var4 in dependents
    end

    test "finds no dependents for leaf variables" do
      graph = %{
        var1: [],
        var2: [:var1]
      }

      dependents = DependencyResolver.find_dependents(graph, :var2)

      assert dependents == []
    end
  end

  describe "Cycle detection" do
    test "detects no cycles in acyclic graph" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2]
      }

      assert {:ok, []} = DependencyResolver.detect_cycles(graph)
    end

    test "detects simple cycle" do
      graph = %{
        var1: [:var2],
        var2: [:var1]
      }

      assert {:error, {cycle, :circular_dependency}} = DependencyResolver.detect_cycles(graph)
      assert is_list(cycle)
      assert length(cycle) >= 2
    end

    test "detects complex cycle" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2],
        var4: [:var3],
        # Creates cycle: var2 -> var3 -> var4 -> var5 -> var2
        var5: [:var4, :var2]
      }

      assert {:error, {cycle, :circular_dependency}} = DependencyResolver.detect_cycles(graph)
      assert is_list(cycle)
    end

    test "detects self-reference cycle" do
      graph = %{
        var1: [:var1]
      }

      assert {:error, {cycle, :circular_dependency}} = DependencyResolver.detect_cycles(graph)
      assert :var1 in cycle
    end
  end

  describe "Dependency validation" do
    test "validates all dependencies exist" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2]
      }

      available_variables = [:var1, :var2, :var3]

      assert :ok = DependencyResolver.validate_dependencies(graph, available_variables)
    end

    test "detects missing dependencies" do
      graph = %{
        var1: [],
        var2: [:var1, :missing_var],
        var3: [:var2, :another_missing]
      }

      available_variables = [:var1, :var2, :var3]

      assert {:error, {:missing_dependencies, missing}} =
               DependencyResolver.validate_dependencies(graph, available_variables)

      assert :missing_var in missing
      assert :another_missing in missing
    end

    test "handles empty dependencies" do
      graph = %{
        var1: [],
        var2: [],
        var3: []
      }

      available_variables = [:var1, :var2, :var3]

      assert :ok = DependencyResolver.validate_dependencies(graph, available_variables)
    end
  end

  describe "Dependency depth calculation" do
    test "calculates depth for independent variables" do
      graph = %{
        var1: [],
        var2: [],
        var3: []
      }

      assert DependencyResolver.dependency_depth(graph, :var1) == 0
      assert DependencyResolver.dependency_depth(graph, :var2) == 0
      assert DependencyResolver.dependency_depth(graph, :var3) == 0
    end

    test "calculates depth for dependency chain" do
      graph = %{
        var1: [],
        var2: [:var1],
        var3: [:var2],
        var4: [:var3]
      }

      assert DependencyResolver.dependency_depth(graph, :var1) == 0
      assert DependencyResolver.dependency_depth(graph, :var2) == 1
      assert DependencyResolver.dependency_depth(graph, :var3) == 2
      assert DependencyResolver.dependency_depth(graph, :var4) == 3
    end

    test "calculates depth for complex dependencies" do
      graph = %{
        var1: [],
        var2: [],
        # Max depth of dependencies is 0
        var3: [:var1, :var2],
        # Depth 1 (var3) + 1 = 2
        var4: [:var3]
      }

      assert DependencyResolver.dependency_depth(graph, :var1) == 0
      assert DependencyResolver.dependency_depth(graph, :var2) == 0
      assert DependencyResolver.dependency_depth(graph, :var3) == 1
      assert DependencyResolver.dependency_depth(graph, :var4) == 2
    end

    test "handles missing variables" do
      graph = %{
        var1: []
      }

      # Missing variable should have depth 0 (empty dependencies)
      assert DependencyResolver.dependency_depth(graph, :missing_var) == 0
    end
  end

  describe "Integration with Variable structs" do
    test "analyzes real Variable expressions" do
      variables = [
        Variable.new(:base_price, type: :sum, expression: :price),
        Variable.new(:total_quantity, type: :sum, expression: :quantity),
        Variable.new(:total_value,
          type: :custom,
          expression: {:multiply, :base_price, :total_quantity}
        )
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)

      # Check that field references are extracted
      assert graph[:base_price] == [:price]
      assert graph[:total_quantity] == [:quantity]
      # Complex expressions might not be fully analyzed in the basic implementation
      assert is_list(graph[:total_value])
    end

    test "handles variables with relationship expressions" do
      variables = [
        Variable.new(:customer_region, type: :custom, expression: {:customer, :region}),
        Variable.new(:order_total, type: :sum, expression: {:field, :order, :total})
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)

      assert graph[:customer_region] == [:customer]
      assert graph[:order_total] == [:total]
    end

    test "resolves evaluation order for realistic scenario" do
      variables = [
        Variable.new(:base_amount, type: :sum, expression: :amount),
        Variable.new(:item_count, type: :count, expression: :id),
        Variable.new(:tax_rate, type: :custom, expression: 0.1),
        Variable.new(:tax_amount, type: :custom, expression: {:multiply, :base_amount, :tax_rate}),
        Variable.new(:final_total, type: :custom, expression: {:add, :base_amount, :tax_amount})
      ]

      {:ok, graph} = DependencyResolver.build_graph(variables)
      {:ok, order} = DependencyResolver.resolve_order(graph)

      # Verify all variables are included
      assert length(order) == 5
      assert :base_amount in order
      assert :item_count in order
      assert :tax_rate in order
      assert :tax_amount in order
      assert :final_total in order
    end
  end
end
