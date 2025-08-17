defmodule AshReports.DependencyResolver do
  @moduledoc """
  Resolves variable dependencies to determine proper evaluation order.

  This module analyzes variable expressions to build a dependency graph
  and provides topological sorting to ensure variables are evaluated in
  the correct order. This is critical when variables reference other variables
  in their calculations.

  ## Features

  - **Dependency Analysis**: Parses expressions to find variable references
  - **Circular Dependency Detection**: Identifies and reports circular dependencies
  - **Topological Sort**: Orders variables for safe evaluation
  - **Error Reporting**: Provides detailed error information for resolution failures

  ## Usage

      variables = [
        %Variable{name: :base_amount, expression: expr(price * quantity)},
        %Variable{name: :tax_amount, expression: expr(base_amount * 0.1)},
        %Variable{name: :total_amount, expression: expr(base_amount + tax_amount)}
      ]

      # Build dependency graph
      {:ok, graph} = DependencyResolver.build_graph(variables)

      # Get evaluation order
      {:ok, order} = DependencyResolver.resolve_order(graph)
      # => [:base_amount, :tax_amount, :total_amount]

      # Check for specific dependencies
      DependencyResolver.depends_on?(graph, :total_amount, :base_amount)
      # => true

  """

  alias AshReports.{CalculationEngine, Variable}

  @type dependency_graph :: %{atom() => [atom()]}
  @type resolution_result :: {:ok, [atom()]} | {:error, term()}
  @type variable_reference :: atom()

  @doc """
  Builds a dependency graph from a list of variables.

  Returns `{:ok, graph}` where graph maps variable names to their dependencies,
  or `{:error, reason}` if the analysis fails.
  """
  @spec build_graph([Variable.t()]) :: {:ok, dependency_graph()} | {:error, term()}
  def build_graph(variables) do
    graph =
      variables
      |> Enum.map(&analyze_variable_dependencies/1)
      |> Enum.into(%{})

    {:ok, graph}
  rescue
    error -> {:error, {:dependency_analysis_failed, error}}
  end

  @doc """
  Resolves the evaluation order for variables based on their dependencies.

  Uses topological sorting to ensure variables are evaluated in an order
  that respects all dependencies.
  """
  @spec resolve_order(dependency_graph()) :: resolution_result()
  def resolve_order(graph) do
    case topological_sort(graph) do
      {:ok, _order} = result -> result
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Resolves evaluation order for a subset of variables.

  Useful when only updating specific variables and needing to determine
  which dependent variables also need recalculation.
  """
  @spec resolve_partial_order(dependency_graph(), [atom()]) :: resolution_result()
  def resolve_partial_order(graph, variable_names) do
    # Find all variables that depend on the given variables (transitively)
    affected_variables = find_affected_variables(graph, variable_names)

    # Create subgraph with only affected variables
    subgraph =
      graph
      |> Enum.filter(fn {var, _deps} -> var in affected_variables end)
      |> Enum.map(fn {var, deps} ->
        {var, Enum.filter(deps, &(&1 in affected_variables))}
      end)
      |> Enum.into(%{})

    topological_sort(subgraph)
  end

  @doc """
  Checks if one variable depends on another (directly or transitively).
  """
  @spec depends_on?(dependency_graph(), atom(), atom()) :: boolean()
  def depends_on?(graph, variable, dependency) do
    direct_deps = Map.get(graph, variable, [])
    has_direct_dependency?(direct_deps, dependency) or has_transitive_dependency?(graph, direct_deps, dependency)
  end

  defp has_direct_dependency?(direct_deps, dependency) do
    dependency in direct_deps
  end

  defp has_transitive_dependency?(graph, direct_deps, dependency) do
    Enum.any?(direct_deps, fn dep ->
      depends_on?(graph, dep, dependency)
    end)
  end

  @doc """
  Finds all variables that directly or transitively depend on the given variable.
  """
  @spec find_dependents(dependency_graph(), atom()) :: [atom()]
  def find_dependents(graph, variable) do
    graph
    |> Enum.filter(fn {_var, deps} -> variable in deps end)
    |> Enum.map(fn {var, _deps} -> var end)
    |> Enum.flat_map(fn dependent ->
      [dependent | find_dependents(graph, dependent)]
    end)
    |> Enum.uniq()
  end

  @doc """
  Detects circular dependencies in the graph.
  """
  @spec detect_cycles(dependency_graph()) :: {:ok, []} | {:error, {[atom()], term()}}
  def detect_cycles(graph) do
    case find_cycle(graph) do
      nil -> {:ok, []}
      cycle -> {:error, {cycle, :circular_dependency}}
    end
  end

  @doc """
  Validates that all variable dependencies exist in the variable set.
  """
  @spec validate_dependencies(dependency_graph(), [atom()]) :: :ok | {:error, term()}
  def validate_dependencies(graph, available_variables) do
    available_set = MapSet.new(available_variables)

    missing_deps =
      graph
      |> Enum.flat_map(fn {_var, deps} -> deps end)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(available_set, &1))

    case missing_deps do
      [] -> :ok
      missing -> {:error, {:missing_dependencies, missing}}
    end
  end

  @doc """
  Gets the depth of a variable in the dependency tree.

  Variables with no dependencies have depth 0, variables that depend
  on depth-0 variables have depth 1, etc.
  """
  @spec dependency_depth(dependency_graph(), atom()) :: non_neg_integer()
  def dependency_depth(graph, variable) do
    case Map.get(graph, variable, []) do
      [] ->
        0

      deps ->
        max_dep_depth =
          deps
          |> Enum.map(&dependency_depth(graph, &1))
          |> Enum.max(fn -> -1 end)

        max_dep_depth + 1
    end
  end

  # Private Implementation

  defp analyze_variable_dependencies(%Variable{name: name, expression: expression}) do
    dependencies = extract_variable_references(expression)
    {name, dependencies}
  end

  defp extract_variable_references(expression) do
    # Use the CalculationEngine to extract field references
    field_refs = CalculationEngine.extract_field_references(expression)

    # Additional analysis for variable-specific patterns
    variable_refs = extract_custom_variable_references(expression)

    (field_refs ++ variable_refs)
    |> Enum.uniq()
    |> Enum.filter(&is_atom/1)
  end

  defp extract_custom_variable_references(expression) do
    extract_refs_by_type(expression)
  end

  defp extract_refs_by_type(func) when is_function(func, 1), do: []
  defp extract_refs_by_type(%Ash.Query.Call{args: args}), do: Enum.flat_map(args, &extract_variable_references/1)
  defp extract_refs_by_type({var}) when is_atom(var), do: [var]
  defp extract_refs_by_type({var1, var2}) when is_atom(var1) and is_atom(var2), do: [var1, var2]
  defp extract_refs_by_type(list) when is_list(list), do: Enum.flat_map(list, &extract_variable_references/1)

  defp extract_refs_by_type(map) when is_map(map) and not is_struct(map) do
    map
    |> Map.values()
    |> Enum.flat_map(&extract_variable_references/1)
  end

  defp extract_refs_by_type(_), do: []

  defp topological_sort(graph) do
    # Kahn's algorithm for topological sorting
    case detect_cycles(graph) do
      {:ok, []} ->
        do_topological_sort(graph)

      {:error, {cycle, :circular_dependency}} ->
        {:error, {:circular_dependency, cycle}}
    end
  end

  defp do_topological_sort(graph) do
    # Calculate in-degrees for all nodes
    in_degrees = calculate_in_degrees(graph)

    # Start with nodes that have no dependencies
    queue =
      in_degrees
      |> Enum.filter(fn {_node, degree} -> degree == 0 end)
      |> Enum.map(fn {node, _degree} -> node end)

    process_queue(queue, in_degrees, graph, [])
  end

  defp calculate_in_degrees(graph) do
    all_nodes = Map.keys(graph) ++ Enum.flat_map(Map.values(graph), & &1)

    all_nodes
    |> Enum.uniq()
    |> Enum.map(fn node ->
      in_degree =
        graph
        |> Enum.count(fn {_var, deps} -> node in deps end)

      {node, in_degree}
    end)
    |> Enum.into(%{})
  end

  defp process_queue([], _in_degrees, _graph, result) do
    {:ok, Enum.reverse(result)}
  end

  defp process_queue([node | rest], in_degrees, graph, result) do
    # Add node to result
    new_result = [node | result]

    # Get nodes that depend on current node
    dependents = Map.get(graph, node, [])

    # Decrease in-degree for dependent nodes
    updated_in_degrees =
      Enum.reduce(dependents, in_degrees, fn dependent, acc ->
        Map.update!(acc, dependent, &(&1 - 1))
      end)

    # Add nodes with zero in-degree to queue
    new_queue_items =
      dependents
      |> Enum.filter(fn dep -> Map.get(updated_in_degrees, dep, 0) == 0 end)
      |> Enum.reject(fn dep -> dep in rest or dep in result end)

    updated_queue = rest ++ new_queue_items

    process_queue(updated_queue, updated_in_degrees, graph, new_result)
  end

  defp find_cycle(graph) do
    visited = MapSet.new()
    rec_stack = MapSet.new()

    # Try to find a cycle starting from each unvisited node
    Enum.find_value(Map.keys(graph), fn node ->
      if MapSet.member?(visited, node) do
        nil
      else
        dfs_cycle_detection(graph, node, visited, rec_stack, [])
      end
    end)
  end

  defp dfs_cycle_detection(graph, node, visited, rec_stack, path) do
    cond do
      MapSet.member?(rec_stack, node) ->
        extract_cycle_from_path(path, node)

      MapSet.member?(visited, node) ->
        nil

      true ->
        check_dependencies_for_cycle(graph, node, visited, rec_stack, path)
    end
  end

  defp extract_cycle_from_path(path, node) do
    cycle_start_index = Enum.find_index(path, &(&1 == node))
    Enum.drop(path, cycle_start_index) ++ [node]
  end

  defp check_dependencies_for_cycle(graph, node, visited, rec_stack, path) do
    new_visited = MapSet.put(visited, node)
    new_rec_stack = MapSet.put(rec_stack, node)
    new_path = [node | path]
    dependencies = Map.get(graph, node, [])

    Enum.find_value(dependencies, fn dep ->
      dfs_cycle_detection(graph, dep, new_visited, new_rec_stack, new_path)
    end)
  end

  defp find_affected_variables(graph, initial_variables) do
    initial_set = MapSet.new(initial_variables)

    find_affected_variables_recursive(graph, initial_set, initial_set)
  end

  defp find_affected_variables_recursive(graph, affected_so_far, newly_affected) do
    # Find variables that depend on newly affected variables
    additional_affected =
      graph
      |> Enum.filter(fn {_var, deps} ->
        Enum.any?(deps, &MapSet.member?(newly_affected, &1))
      end)
      |> Enum.map(fn {var, _deps} -> var end)
      |> MapSet.new()
      |> MapSet.difference(affected_so_far)

    if MapSet.size(additional_affected) == 0 do
      MapSet.to_list(affected_so_far)
    else
      new_affected_so_far = MapSet.union(affected_so_far, additional_affected)
      find_affected_variables_recursive(graph, new_affected_so_far, additional_affected)
    end
  end
end
