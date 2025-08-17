defmodule AshReports.VariableQueryIntegration do
  @moduledoc """
  Integration layer between VariableState and QueryBuilder for seamless Phase 2.1 extension.

  This module provides functionality to:
  - Initialize variable state during report query building
  - Update variables as query results are processed
  - Handle scope changes during data iteration
  - Provide variable values for use in report elements

  ## Usage

      # Initialize during query building
      {:ok, var_state} = VariableQueryIntegration.initialize_variables(report)

      # Process query results with variable updates
      VariableQueryIntegration.process_records(var_state, records, groups)

      # Get final variable values
      final_values = VariableQueryIntegration.get_final_values(var_state)

  """

  alias AshReports.{QueryBuilder, Report, ScopeManager, VariableState}

  @doc """
  Initializes variable state for a report's variables.

  This should be called during query building to set up the variable
  tracking infrastructure.
  """
  @spec initialize_variables(Report.t()) :: {:ok, pid()} | {:error, term()}
  def initialize_variables(%Report{variables: variables}) do
    VariableState.start_link(variables)
  end

  @doc """
  Processes query records, updating variables and handling scope changes.

  This integrates with the data processing pipeline to maintain variable
  state as records are processed.
  """
  @spec process_records(pid(), [map()], [AshReports.Group.t()]) :: :ok | {:error, term()}
  def process_records(variable_state, records, groups) do
    scope_manager = ScopeManager.new(groups)

    Enum.reduce_while(records, {:ok, scope_manager}, fn record, {:ok, current_scope} ->
      # Check for scope changes
      scope_change = ScopeManager.check_scope_change(current_scope, record)

      # Handle scope resets if needed
      case scope_change do
        :no_change -> :ok
        _ -> VariableState.handle_scope_change(variable_state, scope_change)
      end

      # Update scope manager with current record
      updated_scope = ScopeManager.update_detail(current_scope, record)

      # Update variables with current record data
      case VariableState.update_variables_ordered(variable_state, record) do
        :ok -> {:cont, {:ok, updated_scope}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, _final_scope} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Processes a single record with variable updates and scope management.

  Useful for streaming processing where records are handled one at a time.
  """
  @spec process_record(pid(), map(), ScopeManager.scope_state()) ::
          {:ok, ScopeManager.scope_state()} | {:error, term()}
  def process_record(variable_state, record, scope_manager) do
    # Check for scope changes
    scope_change = ScopeManager.check_scope_change(scope_manager, record)

    # Handle scope resets if needed
    case scope_change do
      :no_change -> :ok
      _ -> VariableState.handle_scope_change(variable_state, scope_change)
    end

    # Update scope manager with current record
    updated_scope = ScopeManager.update_detail(scope_manager, record)

    # Update variables with current record data
    case VariableState.update_variables_ordered(variable_state, record) do
      :ok -> {:ok, updated_scope}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Gets the final variable values after processing.
  """
  @spec get_final_values(pid()) :: %{atom() => any()}
  def get_final_values(variable_state) do
    VariableState.get_all_values(variable_state)
  end

  @doc """
  Gets the current value of a specific variable.
  """
  @spec get_variable_value(pid(), atom()) :: any()
  def get_variable_value(variable_state, variable_name) do
    VariableState.get_value(variable_state, variable_name)
  end

  @doc """
  Extends QueryBuilder.build/3 to include variable state initialization.

  This creates an enhanced query result that includes variable tracking.
  """
  @spec build_with_variables(Report.t(), map(), Keyword.t()) ::
          {:ok, {Ash.Query.t(), pid()}} | {:error, term()}
  def build_with_variables(report, params \\ %{}, opts \\ []) do
    with {:ok, query} <- QueryBuilder.build(report, params, opts),
         {:ok, variable_state} <- initialize_variables(report) do
      {:ok, {query, variable_state}}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Resets variable state for a new report run.
  """
  @spec reset_variables(pid()) :: :ok
  def reset_variables(variable_state) do
    VariableState.reset_all(variable_state)
  end

  @doc """
  Handles page breaks by resetting page-scoped variables.
  """
  @spec handle_page_break(pid()) :: :ok
  def handle_page_break(variable_state) do
    VariableState.handle_scope_change(variable_state, {:page_change})
  end

  @doc """
  Handles group breaks by resetting group-scoped variables.
  """
  @spec handle_group_break(pid(), pos_integer()) :: :ok
  def handle_group_break(variable_state, group_level) do
    VariableState.handle_scope_change(variable_state, {:group_change, group_level})
  end

  @doc """
  Gets variable dependencies for understanding evaluation order.
  """
  @spec get_variable_dependencies(pid()) :: %{atom() => [atom()]}
  def get_variable_dependencies(variable_state) do
    VariableState.get_dependencies(variable_state)
  end

  @doc """
  Gets the evaluation order for variables.
  """
  @spec get_evaluation_order(pid()) :: [atom()]
  def get_evaluation_order(variable_state) do
    VariableState.get_evaluation_order(variable_state)
  end

  @doc """
  Validates that all variable dependencies can be resolved.
  """
  @spec validate_variable_dependencies(Report.t()) :: :ok | {:error, term()}
  def validate_variable_dependencies(%Report{variables: variables}) do
    case AshReports.DependencyResolver.build_graph(variables) do
      {:ok, graph} ->
        variable_names = Enum.map(variables, & &1.name)
        AshReports.DependencyResolver.validate_dependencies(graph, variable_names)

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Detects circular dependencies in variable definitions.
  """
  @spec detect_circular_dependencies(Report.t()) :: :ok | {:error, term()}
  def detect_circular_dependencies(%Report{variables: variables}) do
    case AshReports.DependencyResolver.build_graph(variables) do
      {:ok, graph} ->
        case AshReports.DependencyResolver.detect_cycles(graph) do
          {:ok, []} ->
            :ok

          {:error, {cycle, :circular_dependency}} ->
            {:error, {:circular_dependency, cycle}}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Cleanup function to properly shut down variable state.

  Should be called when report processing is complete.
  """
  @spec cleanup_variables(pid()) :: :ok
  def cleanup_variables(variable_state) when is_pid(variable_state) do
    GenServer.stop(variable_state, :normal)
  end

  def cleanup_variables(_non_pid) do
    :ok
  end

  @doc """
  Creates a variable context map for use in report elements.

  This provides a simple map interface for accessing variable values
  in report element expressions.
  """
  @spec create_variable_context(pid()) :: %{atom() => any()}
  def create_variable_context(variable_state) do
    get_final_values(variable_state)
  end

  @doc """
  Updates multiple variables efficiently in a batch operation.
  """
  @spec batch_update_variables(pid(), map()) :: :ok | {:error, term()}
  def batch_update_variables(variable_state, data_context) do
    VariableState.update_variables_ordered(variable_state, data_context)
  end
end
