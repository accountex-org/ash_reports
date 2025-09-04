defmodule AshReports.VariableState do
  @moduledoc """
  GenServer-based state management for report variables with ETS backing.

  This module provides thread-safe variable storage and state management for
  AshReports, supporting:
  - Variable value tracking and calculation
  - Hierarchical scope reset logic (detail, group, page, report)
  - Dependency resolution for proper evaluation order
  - High-performance ETS-backed storage
  - Concurrent report execution

  ## Usage

      # Start a variable state for a report session
      {:ok, pid} = VariableState.start_link([
        %Variable{name: :total, type: :sum, reset_on: :report},
        %Variable{name: :group_total, type: :sum, reset_on: :group, reset_group: 1}
      ])

      # Update variable values
      VariableState.update_variable(pid, :total, %{amount: 100})
      VariableState.update_variable(pid, :group_total, %{amount: 50})

      # Get current values
      VariableState.get_value(pid, :total)  # => 100
      VariableState.get_value(pid, :group_total)  # => 50

      # Reset scopes
      VariableState.reset_scope(pid, :group, 1)
      VariableState.get_value(pid, :group_total)  # => 0

  """

  use GenServer

  alias AshReports.{CalculationEngine, DependencyResolver, ScopeManager, Variable}

  @type scope_reset :: :detail | :group | :page | :report
  @type variable_state :: %{
          variables: [Variable.t()],
          values: %{atom() => any()},
          dependencies: %{atom() => [atom()]},
          table_id: :ets.tid() | nil
        }

  @doc """
  Starts a new VariableState GenServer with the given variables.
  """
  @spec start_link([Variable.t()], Keyword.t()) :: GenServer.on_start()
  def start_link(variables, opts \\ []) do
    GenServer.start_link(__MODULE__, variables, opts)
  end

  @doc """
  Updates a variable with a new data context.

  The variable's calculation engine will evaluate the expression against
  the provided data and update the variable's current value.
  """
  @spec update_variable(GenServer.server(), atom(), map()) :: :ok | {:error, term()}
  def update_variable(server, variable_name, data_context) do
    GenServer.call(server, {:update_variable, variable_name, data_context})
  end

  @doc """
  Gets the current value of a variable.
  """
  @spec get_value(GenServer.server(), atom()) :: any()
  def get_value(server, variable_name) do
    GenServer.call(server, {:get_value, variable_name})
  end

  @doc """
  Gets all current variable values.
  """
  @spec get_all_values(GenServer.server() | variable_state()) :: %{atom() => any()}
  def get_all_values(server) when is_pid(server) do
    GenServer.call(server, :get_all_values)
  end
  
  def get_all_values(%{values: values}), do: values

  @doc """
  Resets variables based on scope changes.

  For group resets, specify the group level that changed.
  """
  @spec reset_scope(GenServer.server(), scope_reset(), pos_integer() | nil) :: :ok
  def reset_scope(server, scope, group_level \\ nil) do
    GenServer.call(server, {:reset_scope, scope, group_level})
  end

  @doc """
  Resets a specific variable to its initial value.
  """
  @spec reset_variable(GenServer.server(), atom()) :: :ok | {:error, :variable_not_found}
  def reset_variable(server, variable_name) do
    GenServer.call(server, {:reset_variable, variable_name})
  end

  @doc """
  Resets all variables to their initial values.
  """
  @spec reset_all(GenServer.server()) :: :ok
  def reset_all(server) do
    GenServer.call(server, :reset_all)
  end

  @doc """
  Gets variable dependencies for evaluation order.
  """
  @spec get_dependencies(GenServer.server()) :: %{atom() => [atom()]}
  def get_dependencies(server) do
    GenServer.call(server, :get_dependencies)
  end

  @doc """
  Checks if a variable exists in the state.
  """
  @spec has_variable?(GenServer.server(), atom()) :: boolean()
  def has_variable?(server, variable_name) do
    GenServer.call(server, {:has_variable, variable_name})
  end

  @doc """
  Updates multiple variables in dependency order.

  Evaluates variables in the correct order based on their dependencies
  to ensure variables that reference other variables get the correct values.
  """
  @spec update_variables_ordered(GenServer.server(), map()) :: :ok | {:error, term()}
  def update_variables_ordered(server, data_context) do
    GenServer.call(server, {:update_variables_ordered, data_context})
  end

  @doc """
  Integrates with ScopeManager to handle scope changes and variable resets.
  """
  @spec handle_scope_change(GenServer.server(), ScopeManager.scope_change()) :: :ok
  def handle_scope_change(server, scope_change) do
    GenServer.call(server, {:handle_scope_change, scope_change})
  end

  @doc """
  Gets variable evaluation order based on dependencies.
  """
  @spec get_evaluation_order(GenServer.server()) :: [atom()]
  def get_evaluation_order(server) do
    GenServer.call(server, :get_evaluation_order)
  end

  @doc """
  Creates a new VariableState struct with initialized variables.
  
  Simplified non-GenServer version for direct use in data processing.
  """
  @spec new([Variable.t()]) :: variable_state()
  def new(variables \\ []) do
    %{
      variables: variables,
      values: initialize_variable_values(variables),
      dependencies: %{},
      table_id: nil
    }
  end

  @doc """
  Updates a variable with a new record value.
  
  Simplified version that works directly with variable state struct.
  """
  @spec update_from_record(variable_state(), Variable.t(), map()) :: variable_state()
  def update_from_record(state, %Variable{} = variable, record) when is_map(record) do
    case evaluate_expression_against_record(variable.expression, record) do
      {:ok, new_value} ->
        current_value = Map.get(state.values, variable.name, variable.initial_value)
        calculated_value = Variable.calculate_next_value(variable, current_value, new_value)
        put_in(state.values[variable.name], calculated_value)
      
      {:error, _reason} ->
        # If expression evaluation fails, keep current state
        state
    end
  end


  # Private helper functions

  defp initialize_variable_values(variables) do
    Enum.into(variables, %{}, fn variable ->
      {variable.name, variable.initial_value || Variable.default_initial_value(variable.type)}
    end)
  end

  defp evaluate_expression_against_record(expression, record) do
    case expression do
      # Simple field reference
      field when is_atom(field) ->
        value = Map.get(record, field)
        {:ok, value}

      # Nested field path (e.g., [:customer, :name])
      path when is_list(path) ->
        value = get_in(record, path)
        {:ok, value}

      # Ash.Expr expressions or other complex expressions
      %{__struct__: struct_module} when struct_module != nil ->
        # Complex expression evaluation would go here
        # For now, return 1 for count operations, 0 for others
        {:ok, 1}

      # Simple value
      value ->
        {:ok, value}
    end
  rescue
    _error -> {:error, "Expression evaluation failed"}
  end

  # GenServer Callbacks

  @impl GenServer
  def init(variables) do
    # Create ETS table for high-performance variable storage
    table_id = :ets.new(:variable_state, [:set, :private])

    # Build dependency graph
    dependencies = build_dependency_graph(variables)

    # Initialize variable values
    initial_values =
      variables
      |> Enum.map(fn var -> {var.name, var.initial_value} end)
      |> Enum.into(%{})

    # Store initial values in ETS
    Enum.each(initial_values, fn {name, value} ->
      :ets.insert(table_id, {name, value})
    end)

    state = %{
      variables: variables,
      values: initial_values,
      dependencies: dependencies,
      table_id: table_id
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:update_variable, variable_name, data_context}, _from, state) do
    case find_variable(state.variables, variable_name) do
      {:ok, variable} ->
        current_value = get_current_value(state, variable_name)

        case calculate_new_value(variable, current_value, data_context) do
          {:ok, new_value} ->
            updated_state = store_value(state, variable_name, new_value)
            {:reply, :ok, updated_state}

          {:error, _reason} = error ->
            {:reply, error, state}
        end

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_value, variable_name}, _from, state) do
    case find_variable(state.variables, variable_name) do
      {:ok, variable} ->
        current_value = get_current_value(state, variable_name)
        display_value = Variable.get_display_value(variable, current_value)
        {:reply, display_value, state}

      {:error, _reason} ->
        {:reply, nil, state}
    end
  end

  @impl GenServer
  def handle_call(:get_all_values, _from, state) do
    all_values =
      state.variables
      |> Enum.map(fn var ->
        current_value = get_current_value(state, var.name)
        display_value = Variable.get_display_value(var, current_value)
        {var.name, display_value}
      end)
      |> Enum.into(%{})

    {:reply, all_values, state}
  end

  @impl GenServer
  def handle_call({:reset_scope, scope, group_level}, _from, state) do
    variables_to_reset =
      state.variables
      |> Enum.filter(fn var -> Variable.should_reset?(var, scope, group_level) end)

    updated_state =
      Enum.reduce(variables_to_reset, state, fn var, acc_state ->
        store_value(acc_state, var.name, var.initial_value)
      end)

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:reset_variable, variable_name}, _from, state) do
    case find_variable(state.variables, variable_name) do
      {:ok, variable} ->
        updated_state = store_value(state, variable_name, variable.initial_value)
        {:reply, :ok, updated_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:reset_all, _from, state) do
    updated_state =
      Enum.reduce(state.variables, state, fn var, acc_state ->
        store_value(acc_state, var.name, var.initial_value)
      end)

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call(:get_dependencies, _from, state) do
    {:reply, state.dependencies, state}
  end

  @impl GenServer
  def handle_call({:has_variable, variable_name}, _from, state) do
    exists = Enum.any?(state.variables, fn var -> var.name == variable_name end)
    {:reply, exists, state}
  end

  @impl GenServer
  def handle_call({:update_variables_ordered, data_context}, _from, state) do
    case DependencyResolver.resolve_order(state.dependencies) do
      {:ok, evaluation_order} ->
        result =
          Enum.reduce_while(evaluation_order, {:ok, state}, fn var_name, {:ok, acc_state} ->
            update_single_variable(acc_state, var_name, data_context)
          end)

        case result do
          {:ok, updated_state} -> {:reply, :ok, updated_state}
          {:error, _reason} = error -> {:reply, error, state}
        end

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:handle_scope_change, scope_change}, _from, state) do
    variables_to_reset = ScopeManager.variables_to_reset(state.variables, scope_change)

    updated_state =
      Enum.reduce(variables_to_reset, state, fn var_name, acc_state ->
        case find_variable(acc_state.variables, var_name) do
          {:ok, variable} ->
            store_value(acc_state, var_name, variable.initial_value)

          {:error, _reason} ->
            acc_state
        end
      end)

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call(:get_evaluation_order, _from, state) do
    case DependencyResolver.resolve_order(state.dependencies) do
      {:ok, order} -> {:reply, order, state}
      {:error, _reason} -> {:reply, [], state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Clean up ETS table
    if state.table_id do
      :ets.delete(state.table_id)
    end

    :ok
  end

  # Private Helper Functions

  defp find_variable(variables, name) do
    case Enum.find(variables, fn var -> var.name == name end) do
      nil -> {:error, :variable_not_found}
      variable -> {:ok, variable}
    end
  end

  defp get_current_value(state, variable_name) do
    case :ets.lookup(state.table_id, variable_name) do
      [{^variable_name, value}] -> value
      [] -> Map.get(state.values, variable_name)
    end
  end

  defp store_value(state, variable_name, value) do
    # Update ETS table
    :ets.insert(state.table_id, {variable_name, value})

    # Update state map (for backup/fallback)
    updated_values = Map.put(state.values, variable_name, value)
    %{state | values: updated_values}
  end

  defp calculate_new_value(variable, current_value, data_context) do
    case CalculationEngine.evaluate(variable.expression, data_context) do
      {:ok, expression_value} ->
        # Calculate next value based on variable type
        new_value = Variable.calculate_next_value(variable, current_value, expression_value)
        {:ok, new_value}

      {:error, {:field_not_found, _field}} ->
        # Handle missing fields gracefully by treating as nil
        new_value = Variable.calculate_next_value(variable, current_value, nil)
        {:ok, new_value}

      {:error, _reason} = error ->
        error
    end
  end

  defp build_dependency_graph(variables) do
    case DependencyResolver.build_graph(variables) do
      {:ok, graph} ->
        graph

      {:error, _reason} ->
        # Fallback to empty dependencies on error
        variables
        |> Enum.map(fn var -> {var.name, []} end)
        |> Enum.into(%{})
    end
  end

  defp update_single_variable(acc_state, var_name, data_context) do
    case find_variable(acc_state.variables, var_name) do
      {:ok, variable} ->
        current_value = get_current_value(acc_state, var_name)

        case calculate_new_value(variable, current_value, data_context) do
          {:ok, new_value} ->
            updated_state = store_value(acc_state, var_name, new_value)
            {:cont, {:ok, updated_state}}

          {:error, _reason} = error ->
            {:halt, error}
        end

      {:error, _reason} ->
        # Variable not found, skip it
        {:cont, {:ok, acc_state}}
    end
  end
end
