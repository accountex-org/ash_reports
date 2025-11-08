defmodule AshReports.Typst.ExpressionParser do
  @moduledoc """
  Parses AshReports DSL expressions and extracts field names for streaming pipeline configuration.

  This module handles parsing of `Ash.Expr.t()` expressions from group definitions,
  extracting field names that can be used for grouping operations in the streaming pipeline.

  ## Supported Expression Formats

  1. **Simple atom**: `:field_name`
  2. **Tuple notation**: `{:field, :field_name}`
  3. **Nested field**: `{:field, :relationship, :field_name}`
  4. **Multi-level nested**: `{:field, :rel1, :rel2, :field_name}`
  5. **Ash.Expr simple ref**: `%Ash.Expr{expression: {:ref, [], :field_name}}`
  6. **Ash.Expr atom**: `%Ash.Expr{expression: :field_name}`
  7. **Ash.Expr get_path**: `%Ash.Expr{expression: {:get_path, _, [...]}}`
  8. **Complex Ash.Expr**: Nested structures with refs and get_path

  ## Usage

      iex> ExpressionParser.extract_field(:region)
      {:ok, :region}

      iex> ExpressionParser.extract_field({:field, :customer, :region})
      {:ok, :region}

      iex> ash_expr = %Ash.Expr{expression: {:ref, [], :status}}
      iex> ExpressionParser.extract_field(ash_expr)
      {:ok, :status}

      iex> ExpressionParser.extract_field_with_fallback(invalid_expr, :default_name)
      {:ok, :default_name}
  """

  @doc """
  Extracts the terminal field name from an expression.

  Returns `{:ok, field_name}` where `field_name` is an atom representing
  the final field in the expression path.

  For relationship traversal (e.g., `customer.region`), returns the terminal
  field name (`:region`) rather than the full path.

  ## Examples

      iex> extract_field(:region)
      {:ok, :region}

      iex> extract_field({:field, :customer, :region})
      {:ok, :region}

      iex> extract_field({:field, :rel1, :rel2, :field_name})
      {:ok, :field_name}

  ## Returns

  - `{:ok, field_name}` - Successfully extracted field name
  - `{:error, reason}` - Failed to parse expression
  """
  def extract_field(expression) do
    try do
      case expression do
        # Pattern 1: Simple atom
        field when is_atom(field) and not is_nil(field) ->
          {:ok, field}

        # Pattern 2: Tuple notation - {:field, field_name}
        {:field, field} when is_atom(field) ->
          {:ok, field}

        # Pattern 3: Nested field - {:field, relationship, field_name}
        {:field, _relationship, field} when is_atom(field) ->
          {:ok, field}

        # Pattern 4: Multi-level nested - {:field, rel1, rel2, ..., field_name}
        {:field, _, _, field} when is_atom(field) ->
          {:ok, field}

        # Pattern 5: Multi-level with more relationships
        tuple when is_tuple(tuple) and tuple_size(tuple) > 2 ->
          case Tuple.to_list(tuple) do
            [:field | [_ | _] = rest] ->
              field = List.last(rest)
              if is_atom(field), do: {:ok, field}, else: {:error, :invalid_field_type}

            _ ->
              {:error, :unrecognized_tuple_format}
          end

        # Pattern 6: Ash.Expr with simple ref
        %{__struct__: Ash.Expr, expression: {:ref, [], field}} when is_atom(field) ->
          {:ok, field}

        # Pattern 7: Ash.Expr with direct atom
        %{__struct__: Ash.Expr, expression: field} when is_atom(field) ->
          {:ok, field}

        # Pattern 8: Ash.Expr with get_path (relationship traversal)
        %{__struct__: Ash.Expr, expression: {:get_path, _, path}} ->
          extract_field_from_get_path(path)

        # Pattern 9: Ash.Expr with nested structure
        %{__struct__: Ash.Expr, expression: expr} ->
          # Recursively try to extract from nested expression
          extract_field(expr)

        _ ->
          {:error, :unrecognized_expression_format}
      end
    rescue
      error ->
        {:error, {:exception_during_parsing, error}}
    end
  end

  @doc """
  Extracts the full field path from an expression, preserving relationship traversal.

  Unlike `extract_field/1`, this function returns the complete path including
  relationships, useful for debugging or when the full context is needed.

  ## Examples

      iex> extract_field_path(:region)
      {:ok, [:region]}

      iex> extract_field_path({:field, :customer, :region})
      {:ok, [:customer, :region]}

      iex> extract_field_path({:field, :order, :customer, :region})
      {:ok, [:order, :customer, :region]}

  ## Returns

  - `{:ok, [field | relationships]}` - List representing the full path
  - `{:error, reason}` - Failed to parse expression
  """
  def extract_field_path(expression) do
    try do
      case expression do
        # Simple atom
        field when is_atom(field) and not is_nil(field) ->
          {:ok, [field]}

        # Tuple notation
        {:field, field} when is_atom(field) ->
          {:ok, [field]}

        # Nested field
        {:field, relationship, field} when is_atom(relationship) and is_atom(field) ->
          {:ok, [relationship, field]}

        # Multi-level nested
        tuple when is_tuple(tuple) ->
          case Tuple.to_list(tuple) do
            [:field | [_ | _] = rest] ->
              if Enum.all?(rest, &is_atom/1) do
                {:ok, rest}
              else
                {:error, :non_atom_in_path}
              end

            _ ->
              {:error, :unrecognized_tuple_format}
          end

        # Ash.Expr with simple ref
        %{__struct__: Ash.Expr, expression: {:ref, [], field}} when is_atom(field) ->
          {:ok, [field]}

        # Ash.Expr with direct atom
        %{__struct__: Ash.Expr, expression: field} when is_atom(field) ->
          {:ok, [field]}

        # Ash.Expr with get_path
        %{__struct__: Ash.Expr, expression: {:get_path, _, path}} ->
          extract_path_from_get_path(path)

        # Ash.Expr with nested structure
        %{__struct__: Ash.Expr, expression: expr} ->
          extract_field_path(expr)

        _ ->
          {:error, :unrecognized_expression_format}
      end
    rescue
      error ->
        {:error, {:exception_during_parsing, error}}
    end
  end

  @doc """
  Validates that an expression can be parsed without errors.

  Returns `{:ok, field}` if valid, `{:error, reason}` if invalid.

  ## Examples

      iex> validate_expression(:region)
      {:ok, :region}

      iex> validate_expression({:invalid, "not an atom"})
      {:error, :unrecognized_expression_format}
  """
  def validate_expression(expression) do
    extract_field(expression)
  end

  @doc """
  Extracts field name with a fallback value if parsing fails.

  This is useful for ensuring that grouped aggregations can always be configured,
  even if the expression format is not recognized.

  ## Examples

      iex> extract_field_with_fallback(:region, :default)
      {:ok, :region}

      iex> extract_field_with_fallback(invalid_expr, :fallback_name)
      {:ok, :fallback_name}

  ## Returns

  Always returns `{:ok, field_name}`, using fallback if needed.
  """
  def extract_field_with_fallback(expression, fallback) when is_atom(fallback) do
    case extract_field(expression) do
      {:ok, field} -> {:ok, field}
      {:error, _} -> {:ok, fallback}
    end
  end

  @doc """
  Extracts relationship dependencies from an expression.

  Returns the list of relationship atoms that need to be preloaded
  for this expression to be evaluated successfully. For simple fields,
  returns an empty list.

  ## Examples

      # Relationship path
      iex> expression = %Ash.Expr{expression: {:get_path, _, [...]}}
      iex> extract_relationship_dependencies(expression)
      {:ok, [:addresses]}

      # Simple field
      iex> extract_relationship_dependencies(:region)
      {:ok, []}

      # Multi-level relationship
      iex> extract_relationship_dependencies(expr(customer.address.country.region))
      {:ok, [:customer, :address, :country]}

  ## Returns

  - `{:ok, [relationship_atoms]}` - List of relationships to preload
  - `{:ok, []}` - No relationships needed (simple field)
  """
  def extract_relationship_dependencies(expression) do
    case extract_field_path(expression) do
      {:ok, [_single_field]} ->
        # No relationships, just a field
        {:ok, []}

      {:ok, path} when is_list(path) and length(path) > 1 ->
        # Path like [:addresses, :state] → need to load :addresses
        # Path like [:customer, :address, :country] → need to load [:customer, :address, :country]
        relationships = Enum.take(path, length(path) - 1)
        {:ok, relationships}

      {:error, _} ->
        # Failed to parse, assume no dependencies
        {:ok, []}
    end
  end

  # Private helper: Extract terminal field from get_path structure
  defp extract_field_from_get_path(path) when is_list(path) and length(path) > 0 do
    case List.last(path) do
      field when is_atom(field) and not is_nil(field) ->
        {:ok, field}

      %{expression: field} when is_atom(field) and not is_nil(field) ->
        {:ok, field}

      %{expression: {:ref, [], field}} when is_atom(field) ->
        {:ok, field}

      _ ->
        {:error, :cannot_extract_field_from_get_path}
    end
  end

  defp extract_field_from_get_path(_), do: {:error, :invalid_get_path_structure}

  # Private helper: Extract full path from get_path structure
  defp extract_path_from_get_path(path) when is_list(path) do
    try do
      extracted_path =
        Enum.map(path, fn
          field when is_atom(field) -> field
          %{expression: field} when is_atom(field) -> field
          %{expression: {:ref, [], field}} when is_atom(field) -> field
          _ -> nil
        end)

      if Enum.all?(extracted_path, &is_atom/1) do
        {:ok, extracted_path}
      else
        {:error, :cannot_extract_full_path}
      end
    rescue
      _ -> {:error, :exception_extracting_path}
    end
  end

  defp extract_path_from_get_path(_), do: {:error, :invalid_get_path_structure}
end
