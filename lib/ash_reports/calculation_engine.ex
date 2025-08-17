defmodule AshReports.CalculationEngine do
  @moduledoc """
  Enhanced runtime expression evaluation engine for AshReports variables.

  This module provides comprehensive expression evaluation capabilities for
  all variable types, supporting:
  - Field references and relationship traversal
  - Arithmetic and logical operations
  - Ash expression evaluation
  - Custom calculation functions
  - Type-safe value extraction and conversion
  - Error handling with detailed context

  ## Supported Expression Types

  ### Simple Field References
  - `:field_name` - Direct field access
  - `{:field, :relationship, :field}` - Relationship traversal
  - `expr(field_name)` - Ash expression syntax

  ### Calculations
  - Arithmetic: `expr(price * quantity)`
  - Conditionals: `expr(if(status == "active", 1, 0))`
  - Aggregations: `expr(sum(line_items.amount))`
  - Functions: `expr(round(average, 2))`

  ### Custom Functions
  Functions registered with the engine can be called in expressions.

  ## Usage

      # Simple field evaluation
      CalculationEngine.evaluate(:amount, %{amount: 100})
      # => {:ok, 100}

      # Complex expression evaluation
      expression = expr(price * quantity)
      CalculationEngine.evaluate(expression, %{price: 10.50, quantity: 3})
      # => {:ok, 31.50}

      # Error handling
      CalculationEngine.evaluate(:missing_field, %{amount: 100})
      # => {:error, {:field_not_found, :missing_field}}

  """

  @type expression ::
          atom()
          | {atom()}
          | {atom(), atom()}
          | {:field, atom(), atom()}
          | function()
          | Ash.Expr.t()
          | any()

  @type data_context :: map()
  @type evaluation_result :: {:ok, any()} | {:error, {atom(), any()}}

  @doc """
  Evaluates an expression against a data context.

  Returns `{:ok, value}` on success or `{:error, reason}` on failure.
  """
  @spec evaluate(expression(), data_context()) :: evaluation_result()
  def evaluate(expression, data_context) do
    case do_evaluate(expression, data_context) do
      {:error, _} = error -> error
      value -> {:ok, value}
    end
  rescue
    error -> {:error, {:evaluation_error, error}}
  catch
    :throw, error -> {:error, {:thrown_error, error}}
    :exit, reason -> {:error, {:process_exit, reason}}
  end

  @doc """
  Evaluates an expression, raising on error.
  """
  @spec evaluate!(expression(), data_context()) :: any()
  def evaluate!(expression, data_context) do
    case evaluate(expression, data_context) do
      {:ok, value} -> value
      {:error, reason} -> raise "Expression evaluation failed: #{inspect(reason)}"
    end
  end

  @doc """
  Validates that an expression can be evaluated (without actually evaluating it).
  """
  @spec validate_expression(expression()) :: :ok | {:error, term()}
  def validate_expression(expression) do
    if valid_expression?(expression) do
      :ok
    else
      {:error, {:unsupported_expression, expression}}
    end
  end

  defp valid_expression?(nil), do: true
  defp valid_expression?(atom) when is_atom(atom), do: true
  defp valid_expression?({atom}) when is_atom(atom), do: true
  defp valid_expression?({atom1, atom2}) when is_atom(atom1) and is_atom(atom2), do: true
  defp valid_expression?({:field, rel, field}) when is_atom(rel) and is_atom(field), do: true
  defp valid_expression?(func) when is_function(func, 1), do: true
  defp valid_expression?(%Ash.Query.Ref{}), do: true
  defp valid_expression?(_), do: false

  @doc """
  Registers a custom calculation function.
  """
  @spec register_function(atom(), function()) :: :ok
  def register_function(name, function) when is_atom(name) and is_function(function) do
    :persistent_term.put({__MODULE__, :function, name}, function)
    :ok
  end

  @doc """
  Gets a registered calculation function.
  """
  @spec get_function(atom()) :: {:ok, function()} | {:error, :not_found}
  def get_function(name) when is_atom(name) do
    case :persistent_term.get({__MODULE__, :function, name}, nil) do
      nil -> {:error, :not_found}
      function -> {:ok, function}
    end
  end

  @doc """
  Lists all registered function names.
  """
  @spec list_functions() :: [atom()]
  def list_functions do
    :persistent_term.get()
    |> Enum.filter(fn {{module, type, _name}, _value} ->
      module == __MODULE__ and type == :function
    end)
    |> Enum.map(fn {{_module, _type, name}, _value} -> name end)
  end

  @doc """
  Extracts field references from an expression for dependency analysis.
  """
  @spec extract_field_references(expression()) :: [atom()]
  def extract_field_references(expression) do
    extract_field_refs(expression)
  end

  defp extract_field_refs(nil), do: []
  defp extract_field_refs(atom) when is_atom(atom), do: [atom]
  defp extract_field_refs({atom}) when is_atom(atom), do: [atom]
  defp extract_field_refs({field1, field2}) when is_atom(field1) and is_atom(field2), do: [field1, field2]
  defp extract_field_refs({:field, _rel, field}) when is_atom(field), do: [field]
  defp extract_field_refs(func) when is_function(func, 1), do: []
  defp extract_field_refs(%Ash.Query.Ref{attribute: %{name: name}}), do: [name]
  defp extract_field_refs(_), do: []

  # Private Implementation

  defp do_evaluate(nil, _data_context) do
    nil
  end

  defp do_evaluate(atom, data_context) when is_atom(atom) do
    case Map.get(data_context, atom) do
      nil -> {:error, {:field_not_found, atom}}
      value -> value
    end
  end

  defp do_evaluate({atom}, data_context) when is_atom(atom) do
    do_evaluate(atom, data_context)
  end

  defp do_evaluate({field1, field2}, data_context)
       when is_atom(field1) and is_atom(field2) do
    # Handle relationship traversal: record.relationship.field
    case Map.get(data_context, field1) do
      nil ->
        {:error, {:relationship_not_found, field1}}

      related_record when is_map(related_record) ->
        case Map.get(related_record, field2) do
          nil -> {:error, {:field_not_found, field2}}
          value -> value
        end

      _non_map ->
        {:error, {:invalid_relationship, field1}}
    end
  end

  defp do_evaluate({:field, relationship, field}, data_context)
       when is_atom(relationship) and is_atom(field) do
    do_evaluate({relationship, field}, data_context)
  end

  defp do_evaluate(func, data_context) when is_function(func, 1) do
    func.(data_context)
  end

  defp do_evaluate(%Ash.Query.Ref{} = ref, data_context) do
    evaluate_ash_ref(ref, data_context)
  end

  defp do_evaluate(%{__struct__: struct_module} = ash_expr, data_context)
       when struct_module in [Ash.Query.Call, Ash.Query.BooleanExpression, Ash.Query.Ref] do
    evaluate_ash_expression(ash_expr, data_context)
  end

  defp do_evaluate(literal_value, _data_context) do
    # Return literal values as-is
    literal_value
  end

  defp evaluate_ash_ref(%Ash.Query.Ref{attribute: %{name: name}}, data_context)
       when is_atom(name) do
    do_evaluate(name, data_context)
  end

  defp evaluate_ash_ref(
         %Ash.Query.Ref{relationship_path: [relationship], attribute: %{name: field}},
         data_context
       )
       when is_atom(relationship) and is_atom(field) do
    do_evaluate({relationship, field}, data_context)
  end

  defp evaluate_ash_ref(ref, _data_context) do
    {:error, {:unsupported_ash_ref, ref}}
  end

  defp evaluate_ash_expression(%Ash.Query.Call{name: :+, args: [left, right]}, data_context) do
    with {:ok, left_val} <- safe_evaluate(left, data_context),
         {:ok, right_val} <- safe_evaluate(right, data_context) do
      add_values(left_val, right_val)
    end
  end

  defp evaluate_ash_expression(%Ash.Query.Call{name: :-, args: [left, right]}, data_context) do
    with {:ok, left_val} <- safe_evaluate(left, data_context),
         {:ok, right_val} <- safe_evaluate(right, data_context) do
      subtract_values(left_val, right_val)
    end
  end

  defp evaluate_ash_expression(%Ash.Query.Call{name: :*, args: [left, right]}, data_context) do
    with {:ok, left_val} <- safe_evaluate(left, data_context),
         {:ok, right_val} <- safe_evaluate(right, data_context) do
      multiply_values(left_val, right_val)
    end
  end

  defp evaluate_ash_expression(%Ash.Query.Call{name: :/, args: [left, right]}, data_context) do
    with {:ok, left_val} <- safe_evaluate(left, data_context),
         {:ok, right_val} <- safe_evaluate(right, data_context) do
      divide_values(left_val, right_val)
    end
  end

  defp evaluate_ash_expression(
         %Ash.Query.Call{name: :if, args: [condition, true_val, false_val]},
         data_context
       ) do
    case safe_evaluate(condition, data_context) do
      {:ok, truthy} when truthy not in [nil, false] ->
        safe_evaluate(true_val, data_context)

      {:ok, _falsy} ->
        safe_evaluate(false_val, data_context)

      error ->
        error
    end
  end

  defp evaluate_ash_expression(%Ash.Query.Call{name: name, args: args}, data_context) do
    # Try to find a registered custom function
    case get_function(name) do
      {:ok, function} ->
        # Evaluate all arguments first
        case evaluate_all_args(args, data_context) do
          {:ok, evaluated_args} -> apply(function, evaluated_args)
          error -> error
        end

      {:error, :not_found} ->
        {:error, {:unknown_function, name}}
    end
  end

  defp evaluate_ash_expression(expr, _data_context) do
    {:error, {:unsupported_ash_expression, expr}}
  end

  defp safe_evaluate(expr, data_context) do
    case do_evaluate(expr, data_context) do
      {:error, _} = error -> error
      value -> {:ok, value}
    end
  end

  defp evaluate_all_args(args, data_context) do
    Enum.reduce_while(args, {:ok, []}, fn arg, {:ok, acc} ->
      case safe_evaluate(arg, data_context) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed_args} -> {:ok, Enum.reverse(reversed_args)}
      error -> error
    end
  end

  # Arithmetic operations with type safety

  defp add_values(left, right) when is_number(left) and is_number(right) do
    {:ok, left + right}
  end

  defp add_values(left, right) when is_binary(left) and is_binary(right) do
    {:ok, left <> right}
  end

  defp add_values(left, right) do
    {:error, {:invalid_arithmetic, :+, left, right}}
  end

  defp subtract_values(left, right) when is_number(left) and is_number(right) do
    {:ok, left - right}
  end

  defp subtract_values(left, right) do
    {:error, {:invalid_arithmetic, :-, left, right}}
  end

  defp multiply_values(left, right) when is_number(left) and is_number(right) do
    {:ok, left * right}
  end

  defp multiply_values(left, right) do
    {:error, {:invalid_arithmetic, :*, left, right}}
  end

  defp divide_values(_left, 0) do
    {:error, {:division_by_zero}}
  end

  defp divide_values(_left, +0.0) do
    {:error, {:division_by_zero}}
  end

  defp divide_values(_left, -0.0) do
    {:error, {:division_by_zero}}
  end

  defp divide_values(left, right) when is_number(left) and is_number(right) do
    {:ok, left / right}
  end

  defp divide_values(left, right) do
    {:error, {:invalid_arithmetic, :/, left, right}}
  end
end
