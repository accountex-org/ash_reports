defmodule AshReports.GroupProcessor do
  @moduledoc """
  Stream-based group processing engine for AshReports.

  This module implements multi-level group break detection and value tracking
  for hierarchical report processing. It coordinates with the Variable System
  to trigger variable resets when group values change.

  ## Features

  - **Multi-level Group Support**: Handles nested grouping (levels 1, 2, 3+)
  - **Change Detection**: Efficient algorithms for detecting value changes
  - **Stream Processing**: Memory-efficient processing of large datasets
  - **Variable Integration**: Coordinates with VariableState for resets
  - **Performance Optimized**: Lazy evaluation and minimal memory footprint

  ## Usage

      # Initialize with group configuration
      groups = [
        %Group{name: :region, level: 1, expression: :region},
        %Group{name: :category, level: 2, expression: :category}
      ]

      processor = GroupProcessor.new(groups)

      # Process data stream
      data
      |> Stream.map(&GroupProcessor.process_record(processor, &1))
      |> Stream.map(&handle_group_changes/1)
      |> Enum.to_list()

  ## Group Break Detection

  Group breaks are detected by comparing current group values with the next
  record's values. When a change is detected at any level, all lower levels
  are also considered to have changed.

  Example:
  - Current: {region: "West", category: "A"}
  - Next: {region: "West", category: "B"}
  - Result: Category break at level 2 (also resets levels 3+)

  ## Integration with Variable System

  When group breaks occur, the processor coordinates with VariableState to
  reset variables based on their reset scope configuration:

  - Variables with `reset_on: :group` and `reset_group: 2` reset when level 2+ changes
  - Variables with `reset_on: :detail` reset on every record
  - Variables with `reset_on: :page` reset only on page breaks

  """

  alias AshReports.{CalculationEngine, Group, ScopeManager, VariableState}

  @type group_state :: %{
          groups: [Group.t()],
          current_values: %{pos_integer() => any()},
          previous_record: map() | nil,
          group_counts: %{pos_integer() => pos_integer()},
          scope_manager: ScopeManager.scope_state()
        }

  @type group_change :: ScopeManager.scope_change()

  @type processing_result :: %{
          record: map(),
          group_changes: [group_change()],
          group_values: %{pos_integer() => any()},
          should_reset_variables: boolean()
        }

  @doc """
  Creates a new GroupProcessor with the given group configuration.

  Groups are automatically sorted by level to ensure proper hierarchy processing.
  """
  @spec new([Group.t()]) :: group_state()
  def new(groups \\ []) do
    # Sort groups by level for consistent processing order
    sorted_groups = Enum.sort_by(groups, & &1.level)

    # Initialize scope manager
    scope_manager = ScopeManager.new(sorted_groups)

    %{
      groups: sorted_groups,
      current_values: %{},
      previous_record: nil,
      group_counts: %{},
      scope_manager: scope_manager
    }
  end

  @doc """
  Processes a single record through the group processing engine.

  Returns a processing result that includes group change information
  and instructions for variable resets.
  """
  @spec process_record(group_state(), map()) :: {group_state(), processing_result()}
  def process_record(processor, record) do
    # Extract group values from the current record
    new_group_values = extract_group_values(processor.groups, record)

    # Detect group changes
    group_changes = detect_group_changes(processor, new_group_values)

    # Update group counts
    updated_counts = update_group_counts(processor.group_counts, group_changes)

    # Update scope manager
    updated_scope_manager = ScopeManager.update_detail(processor.scope_manager, record)

    # Build processing result
    result = %{
      record: record,
      group_changes: group_changes,
      group_values: new_group_values,
      should_reset_variables: has_meaningful_changes?(group_changes)
    }

    # Update processor state
    updated_processor = %{
      processor
      | current_values: new_group_values,
        previous_record: record,
        group_counts: updated_counts,
        scope_manager: updated_scope_manager
    }

    {updated_processor, result}
  end

  @doc """
  Checks for group breaks between current state and next record.

  This is useful for lookahead processing without updating the processor state.
  """
  @spec check_group_break(group_state(), map()) :: group_change()
  def check_group_break(processor, next_record) do
    ScopeManager.check_scope_change(processor.scope_manager, next_record)
  end

  @doc """
  Extracts group values from a record using group expressions.
  """
  @spec extract_group_values([Group.t()], map()) :: %{pos_integer() => any()}
  def extract_group_values(groups, record) do
    groups
    |> Enum.map(fn group ->
      value = evaluate_group_expression(group.expression, record)
      {group.level, value}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gets the current group values for a specific level.
  """
  @spec get_group_value(group_state(), pos_integer()) :: any()
  def get_group_value(processor, level) do
    Map.get(processor.current_values, level)
  end

  @doc """
  Gets all current group values.
  """
  @spec get_all_group_values(group_state()) :: %{pos_integer() => any()}
  def get_all_group_values(processor) do
    processor.current_values
  end

  @doc """
  Gets the count of records processed for a specific group level.
  """
  @spec get_group_count(group_state(), pos_integer()) :: pos_integer()
  def get_group_count(processor, level) do
    Map.get(processor.group_counts, level, 0)
  end

  @doc """
  Checks if the processor has any groups configured.
  """
  @spec has_groups?(group_state()) :: boolean()
  def has_groups?(processor) do
    length(processor.groups) > 0
  end

  @doc """
  Gets all configured group levels.
  """
  @spec get_group_levels(group_state()) :: [pos_integer()]
  def get_group_levels(processor) do
    Enum.map(processor.groups, & &1.level)
  end

  @doc """
  Determines which variables should be reset based on group changes.

  Coordinates with VariableState to identify variables that need to be reset
  when specific group levels change.
  """
  @spec variables_to_reset([AshReports.Variable.t()], [group_change()]) :: [atom()]
  def variables_to_reset(variables, group_changes) do
    group_changes
    |> Enum.flat_map(fn change ->
      ScopeManager.variables_to_reset(variables, change)
    end)
    |> Enum.uniq()
  end

  @doc """
  Integrates with VariableState to handle group change resets.

  This function should be called whenever group changes are detected to
  ensure variables are reset according to their configuration.
  """
  @spec handle_variable_resets(GenServer.server(), [group_change()]) :: :ok | {:error, term()}
  def handle_variable_resets(variable_state_pid, group_changes) do
    Enum.reduce_while(group_changes, :ok, fn change, :ok ->
      case VariableState.handle_scope_change(variable_state_pid, change) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Resets the processor to initial state while preserving configuration.
  """
  @spec reset(group_state()) :: group_state()
  def reset(processor) do
    %{
      processor
      | current_values: %{},
        previous_record: nil,
        group_counts: %{},
        scope_manager: ScopeManager.reset(processor.scope_manager)
    }
  end

  @doc """
  Processes a stream of records with group break detection.

  This is the main entry point for stream-based group processing.
  Returns a stream of processing results.
  """
  @spec process_stream(group_state(), Enumerable.t()) :: Enumerable.t()
  def process_stream(initial_processor, data_stream) do
    {stream, _final_processor} =
      data_stream
      |> Stream.transform(initial_processor, fn record, processor ->
        {updated_processor, result} = process_record(processor, record)
        {[result], updated_processor}
      end)
      |> Stream.map(&add_processing_metadata/1)
      |> then(&{&1, nil})

    stream
  end

  # Private Helper Functions

  defp detect_group_changes(processor, new_group_values) do
    cond do
      # First record - no changes yet
      processor.previous_record == nil ->
        []

      # No groups configured
      processor.groups == [] ->
        [{:detail_change}]

      # Check for group value changes
      true ->
        find_group_changes(processor.current_values, new_group_values)
    end
  end

  defp find_group_changes(current_values, new_values) do
    # Find the highest level where values changed
    changed_levels =
      current_values
      |> Map.keys()
      |> Enum.filter(fn level ->
        Map.get(current_values, level) != Map.get(new_values, level)
      end)
      |> Enum.sort()

    case changed_levels do
      [] ->
        # No group changes, just detail change
        [{:detail_change}]

      [level | _] ->
        # Group change at the highest changed level
        [{:group_change, level}]
    end
  end

  defp update_group_counts(counts, group_changes) do
    # Increment counts for groups that changed and all lower levels
    Enum.reduce(group_changes, counts, fn change, acc ->
      case change do
        {:group_change, level} ->
          # When a group changes, all groups at this level and below should increment
          # For now, just increment the specific level
          Map.update(acc, level, 1, &(&1 + 1))

        {:detail_change} ->
          # Detail changes don't affect group counts
          acc

        _ ->
          acc
      end
    end)
  end

  defp has_meaningful_changes?(group_changes) do
    Enum.any?(group_changes, fn change ->
      case change do
        {:group_change, _level} -> true
        {:page_change} -> true
        _ -> false
      end
    end)
  end

  defp evaluate_group_expression(expression, record) do
    case expression do
      # Simple field reference
      field when is_atom(field) ->
        Map.get(record, field)

      # Ash.Expr expressions - evaluate using the record data
      %{__struct__: Ash.Expr} = ash_expr ->
        evaluate_ash_expression_for_group(ash_expr, record)

      # Nested field reference
      {:field, relationship, field} ->
        evaluate_nested_field(record, [relationship, field])

      # Complex nested field
      {:field, rel1, rel2, field} ->
        evaluate_nested_field(record, [rel1, rel2, field])

      # Function-based expression
      expr when is_function(expr, 1) ->
        try do
          expr.(record)
        rescue
          _error -> nil
        end

      # Complex expression (would need CalculationEngine for full evaluation)
      complex_expr ->
        evaluate_complex_expression(complex_expr, record)
    end
  end

  defp evaluate_nested_field(record, path) do
    Enum.reduce_while(path, record, fn key, acc ->
      case acc do
        %{} = map -> {:cont, Map.get(map, key)}
        _ -> {:halt, nil}
      end
    end)
  end

  defp evaluate_complex_expression(expression, record) do
    case CalculationEngine.evaluate(expression, record) do
      {:ok, value} -> value
      {:error, _reason} -> nil
    end
  end

  # Handle Ash expressions for grouping (similar to VariableState but for groups)
  defp evaluate_ash_expression_for_group(ash_expr, record) do
    case extract_field_from_ash_expr_for_group(ash_expr) do
      {:ok, field} when is_atom(field) ->
        Map.get(record, field)
        
      {:ok, path} when is_list(path) ->
        evaluate_nested_field(record, path)
        
      :error ->
        nil
    end
  end

  # Extract field reference from Ash expression (simplified for groups)
  defp extract_field_from_ash_expr_for_group(ash_expr) do
    try do
      case ash_expr do
        %{expression: {:ref, [], field}} when is_atom(field) ->
          {:ok, field}
          
        %{expression: field} when is_atom(field) ->
          {:ok, field}
          
        # Handle relationship traversal like addresses.state
        %{expression: {:get_path, _, [%{expression: {:ref, [], rel}}, field]}} ->
          {:ok, [rel, field]}
          
        _ ->
          :error
      end
    rescue
      _error -> :error
    end
  end

  defp add_processing_metadata(result) do
    Map.put(result, :processed_at, System.monotonic_time(:millisecond))
  end

  @doc """
  Processes multiple records and returns group summary information.

  Simplified version for Phase 8.1 integration.
  """
  @spec process_records(group_state(), [map()]) :: %{term() => map()}
  def process_records(_group_state, []), do: %{}

  def process_records(group_state, records) when is_list(records) do
    # Group records by their group values
    records
    |> Enum.group_by(fn record ->
      # Extract group values for this record
      Enum.reduce(group_state.groups, %{}, fn group, acc ->
        group_value = evaluate_group_expression(group.expression, record)
        Map.put(acc, group.level, group_value)
      end)
    end)
    |> Enum.into(%{}, fn {group_key, group_records} ->
      {group_key,
       %{
         record_count: length(group_records),
         first_record: List.first(group_records),
         last_record: List.last(group_records),
         group_level_values: group_key
       }}
    end)
  end
end
