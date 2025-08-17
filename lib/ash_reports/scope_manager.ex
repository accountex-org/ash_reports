defmodule AshReports.ScopeManager do
  @moduledoc """
  Manages hierarchical scope tracking and reset triggers for report variables.

  This module handles the detection of scope changes during report processing
  and coordinates variable resets based on the hierarchical scope system:

  - **Report scope**: Never resets during report execution
  - **Page scope**: Resets when page breaks occur  
  - **Group scope**: Resets when group values change at specified levels
  - **Detail scope**: Resets for each detail row processed

  ## Scope Hierarchy

  ```
  Report (entire report)
  └── Page (page break)
      └── Group Level 1 (major grouping)
          └── Group Level 2 (sub-grouping)
              └── ... (nested groups)
                  └── Detail (individual records)
  ```

  ## Usage

      # Initialize scope manager with grouping configuration
      scope_manager = ScopeManager.new([
        %Group{field: :category, level: 1},
        %Group{field: :subcategory, level: 2}
      ])

      # Track current scope state
      scope_manager = ScopeManager.update_detail(scope_manager, %{category: "A", subcategory: "X"})

      # Check for scope changes with next record
      case ScopeManager.check_scope_change(scope_manager, %{category: "A", subcategory: "Y"}) do
        {:group_change, 2} -> # Subcategory changed, reset level 2 and below
        {:detail_change} -> # Same group, just detail change
        :no_change -> # Identical record
      end

  """

  alias AshReports.Group

  @type scope_change ::
          :no_change
          | {:detail_change}
          | {:group_change, pos_integer()}
          | {:page_change}

  @type scope_state :: %{
          groups: [Group.t()],
          current_values: %{pos_integer() => any()},
          current_record: map() | nil,
          page_number: pos_integer(),
          detail_count: pos_integer()
        }

  @doc """
  Creates a new ScopeManager with the given group configuration.
  """
  @spec new([Group.t()]) :: scope_state()
  def new(groups \\ []) do
    # Sort groups by level to ensure proper hierarchy
    sorted_groups = Enum.sort_by(groups, & &1.level)

    %{
      groups: sorted_groups,
      current_values: %{},
      current_record: nil,
      page_number: 1,
      detail_count: 0
    }
  end

  @doc """
  Updates the scope manager with a new detail record.

  This should be called for each record being processed to track
  the current scope state.
  """
  @spec update_detail(scope_state(), map()) :: scope_state()
  def update_detail(scope_manager, record) do
    # Extract group values from the current record
    group_values = extract_group_values(scope_manager.groups, record)

    %{
      scope_manager
      | current_values: group_values,
        current_record: record,
        detail_count: scope_manager.detail_count + 1
    }
  end

  @doc """
  Checks what scope changes occur when moving to the next record.

  Returns the highest-level scope that needs to be reset.
  """
  @spec check_scope_change(scope_state(), map()) :: scope_change()
  def check_scope_change(scope_manager, next_record) do
    next_group_values = extract_group_values(scope_manager.groups, next_record)

    # Check for group changes from highest level down
    case find_group_change_level(scope_manager.current_values, next_group_values) do
      nil ->
        # No group changes detected
        if scope_manager.current_record == next_record do
          :no_change
        else
          {:detail_change}
        end

      level ->
        {:group_change, level}
    end
  end

  @doc """
  Triggers a page break, incrementing the page number.
  """
  @spec page_break(scope_state()) :: scope_state()
  def page_break(scope_manager) do
    %{scope_manager | page_number: scope_manager.page_number + 1}
  end

  @doc """
  Gets the current page number.
  """
  @spec current_page(scope_state()) :: pos_integer()
  def current_page(scope_manager) do
    scope_manager.page_number
  end

  @doc """
  Gets the current detail count.
  """
  @spec detail_count(scope_state()) :: pos_integer()
  def detail_count(scope_manager) do
    scope_manager.detail_count
  end

  @doc """
  Gets the current group values.
  """
  @spec current_group_values(scope_state()) :: %{pos_integer() => any()}
  def current_group_values(scope_manager) do
    scope_manager.current_values
  end

  @doc """
  Gets the value for a specific group level.
  """
  @spec group_value(scope_state(), pos_integer()) :: any()
  def group_value(scope_manager, level) do
    Map.get(scope_manager.current_values, level)
  end

  @doc """
  Checks if the scope manager is configured for grouping.
  """
  @spec has_groups?(scope_state()) :: boolean()
  def has_groups?(scope_manager) do
    length(scope_manager.groups) > 0
  end

  @doc """
  Gets all configured group levels.
  """
  @spec group_levels(scope_state()) :: [pos_integer()]
  def group_levels(scope_manager) do
    Enum.map(scope_manager.groups, & &1.level)
  end

  @doc """
  Determines which variables should be reset for a given scope change.
  """
  @spec variables_to_reset([AshReports.Variable.t()], scope_change()) :: [atom()]
  def variables_to_reset(variables, scope_change) do
    case scope_change do
      :no_change ->
        []

      {:detail_change} ->
        variables
        |> Enum.filter(fn var -> var.reset_on == :detail end)
        |> Enum.map(& &1.name)

      {:group_change, level} ->
        variables
        |> Enum.filter(fn var ->
          var.reset_on == :detail or
            (var.reset_on == :group and should_reset_for_group_level?(var, level))
        end)
        |> Enum.map(& &1.name)

      {:page_change} ->
        variables
        |> Enum.filter(fn var ->
          var.reset_on in [:detail, :group, :page]
        end)
        |> Enum.map(& &1.name)
    end
  end

  @doc """
  Resets the scope manager to initial state while preserving configuration.
  """
  @spec reset(scope_state()) :: scope_state()
  def reset(scope_manager) do
    %{
      scope_manager
      | current_values: %{},
        current_record: nil,
        page_number: 1,
        detail_count: 0
    }
  end

  # Private Helper Functions

  defp extract_group_values(groups, record) do
    groups
    |> Enum.map(fn group ->
      value = extract_group_value(group, record)
      {group.level, value}
    end)
    |> Enum.into(%{})
  end

  defp extract_group_value(%Group{expression: expression}, record) when is_atom(expression) do
    Map.get(record, expression)
  end

  defp extract_group_value(%Group{expression: {field}}, record) when is_atom(field) do
    Map.get(record, field)
  end

  defp extract_group_value(%Group{expression: expression}, record)
       when is_function(expression, 1) do
    expression.(record)
  end

  defp extract_group_value(%Group{expression: expression}, _record) do
    # For complex expressions, return the expression itself
    # In a full implementation, this would evaluate Ash expressions
    expression
  end

  defp find_group_change_level(current_values, next_values) do
    # Find the highest level where values changed
    current_values
    |> Map.keys()
    |> Enum.sort()
    |> Enum.find(fn level ->
      Map.get(current_values, level) != Map.get(next_values, level)
    end)
  end

  defp should_reset_for_group_level?(%{reset_on: :group, reset_group: reset_group}, change_level)
       when is_integer(reset_group) do
    # Reset if the change level is at or above the variable's reset level
    change_level <= reset_group
  end

  defp should_reset_for_group_level?(%{reset_on: :group, reset_group: nil}, _change_level) do
    # If no specific reset level, reset for any group change
    true
  end

  defp should_reset_for_group_level?(_variable, _change_level) do
    false
  end
end
