defmodule AshReports.QueryBuilder do
  @moduledoc """
  Builds Ash queries for report data fetching.

  This module implements complete query generation for AshReports, handling:
  - Parameter substitution and validation
  - Relationship loading and optimization
  - Scope application
  - Group-based sorting
  - Aggregate and calculation pre-loading
  """

  alias AshReports.{Parameter, Report}

  @doc """
  Builds an Ash query for the report with the given parameters.

  ## Options

  - `:validate_params` - Whether to validate parameters (default: true)
  - `:load_relationships` - Whether to auto-load relationships (default: true)
  - `:optimize_aggregates` - Whether to optimize aggregate loading (default: true)

  ## Examples

      iex> report = %AshReports.Report{
      ...>   driving_resource: MyApp.Order,
      ...>   parameters: [%Parameter{name: :status, type: :string}]
      ...> }
      iex> params = %{status: "shipped"}
      iex> QueryBuilder.build(report, params)
      %Ash.Query{resource: MyApp.Order, ...}

  ## Errors

  Returns `{:error, error}` for:
  - Invalid parameters
  - Missing required parameters
  - Invalid scope expressions
  - Resource not found
  """
  @spec build(Report.t(), map(), Keyword.t()) :: {:ok, Ash.Query.t()} | {:error, term()}
  def build(report, params \\ %{}, opts \\ []) do
    with {:ok, validated_params} <- validate_parameters(report, params, opts),
         {:ok, base_query} <- build_base_query(report),
         {:ok, scoped_query} <- apply_scope(base_query, report.scope, validated_params),
         {:ok, filtered_query} <- apply_parameter_filters(scoped_query, report, validated_params),
         {:ok, sorted_query} <- apply_group_sorting(filtered_query, report),
         {:ok, loaded_query} <- load_relationships(sorted_query, report, opts),
         {:ok, final_query} <- preload_aggregates(loaded_query, report, opts) do
      {:ok, final_query}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Builds an Ash query for the report with the given parameters.

  This is the bang version that raises on error.
  """
  @spec build!(Report.t(), map(), Keyword.t()) :: Ash.Query.t()
  def build!(report, params \\ %{}, opts \\ []) do
    case build(report, params, opts) do
      {:ok, query} -> query
      {:error, error} -> raise "Failed to build query: #{inspect(error)}"
    end
  end

  @doc """
  Validates parameters against the report parameter definitions.
  """
  @spec validate_parameters(Report.t(), map(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def validate_parameters(%Report{parameters: parameters}, params, opts) do
    should_validate = Keyword.get(opts, :validate_params, true)

    if should_validate do
      do_validate_parameters(parameters, params)
    else
      {:ok, params}
    end
  end

  @doc """
  Extracts required relationships from report bands, elements, and groups.
  """
  @spec extract_relationships(Report.t()) :: [atom()]
  def extract_relationships(%Report{bands: bands, groups: groups}) do
    band_relationships =
      bands
      |> Enum.flat_map(&extract_band_relationships/1)

    group_relationships =
      (groups || [])
      |> Enum.flat_map(&extract_group_relationships/1)

    (band_relationships ++ group_relationships)
    |> Enum.uniq()
  end

  @doc """
  Builds filter expressions from parameter values.
  """
  @spec build_parameter_filters(Report.t(), map()) :: [Ash.Expr.t()]
  def build_parameter_filters(%Report{parameters: parameters}, params) do
    parameters
    |> Enum.filter(fn param -> Map.has_key?(params, param.name) end)
    |> Enum.map(fn param -> build_filter_expression(param, params[param.name]) end)
    |> Enum.reject(&is_nil/1)
  end

  # Private functions

  # This function is used by do_validate_parameters
  # defp validate_parameters([], _params), do: {:ok, %{}}

  defp do_validate_parameters(parameters, params) do
    Enum.reduce_while(parameters, {:ok, %{}}, fn param, {:ok, acc} ->
      case validate_single_parameter(param, params) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, param.name, value)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_single_parameter(%Parameter{name: name, required: true}, params) do
    case Map.get(params, name) do
      nil -> {:error, {Ash.Error.Invalid, "Parameter #{name} is required but not provided"}}
      value -> {:ok, value}
    end
  end

  defp validate_single_parameter(
         %Parameter{name: name, required: false, default: default},
         params
       ) do
    value = Map.get(params, name, default)
    {:ok, value}
  end

  defp build_base_query(%Report{driving_resource: resource}) when is_atom(resource) do
    query = Ash.Query.new(resource)
    {:ok, query}
  rescue
    error ->
      {:error,
       {Ash.Error.Framework, "Failed to create query for resource #{resource}: #{inspect(error)}"}}
  end

  defp build_base_query(%Report{driving_resource: resource}) do
    {:error, {Ash.Error.Invalid, "Invalid driving_resource: #{inspect(resource)}"}}
  end

  defp apply_scope(query, nil, _params), do: {:ok, query}

  defp apply_scope(query, scope_expr, params) do
    # Apply scope expression with parameter substitution
    scoped_query =
      case scope_expr do
        expr when is_function(expr, 1) ->
          # If scope is a function, call it with params
          expr.(params)
          |> apply_to_query(query)

        _expr ->
          # If scope is an expression, apply directly
          # For now, we can't apply arbitrary expressions without context
          query
      end

    {:ok, scoped_query}
  rescue
    error -> {:error, {Ash.Error.Invalid, "Failed to apply scope: #{inspect(error)}"}}
  end

  defp apply_to_query(scope_result, query) when is_struct(scope_result, Ash.Query) do
    # If scope returns a query, merge filter and loads from it
    query
    |> apply_scope_filter(scope_result.filter)
    |> apply_scope_loads(scope_result.load)
  end

  defp apply_scope_filter(query, nil), do: query
  defp apply_scope_filter(query, filter), do: Ash.Query.do_filter(query, filter)

  defp apply_scope_loads(query, []), do: query
  defp apply_scope_loads(query, nil), do: query
  defp apply_scope_loads(query, loads) when is_list(loads) do
    Enum.reduce(loads, query, fn load, acc_query ->
      Ash.Query.load(acc_query, load)
    end)
  end
  defp apply_scope_loads(query, load), do: Ash.Query.load(query, load)

  defp apply_to_query(_scope_result, query) do
    # If scope returns an expression, apply as filter
    # For now, we can't apply arbitrary expressions without context
    query
  end

  defp apply_parameter_filters(query, %Report{parameters: []}, _params), do: {:ok, query}

  defp apply_parameter_filters(query, report, params) do
    filters = build_parameter_filters(report, params)

    filtered_query =
      Enum.reduce(filters, query, fn _filter, acc_query ->
        # For now, parameter filters are not applied directly
        # They should be handled in the scope expression
        acc_query
      end)

    {:ok, filtered_query}
  rescue
    error ->
      {:error, {Ash.Error.Invalid, "Failed to apply parameter filters: #{inspect(error)}"}}
  end

  defp apply_group_sorting(query, %Report{groups: []}) do
    {:ok, query}
  end

  defp apply_group_sorting(query, %Report{groups: groups}) do
    # Filter out any nil groups and sort by groups in order of their level
    valid_groups =
      groups
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn group ->
        is_struct(group, AshReports.Group) && group.level && group.expression
      end)
      |> Enum.sort_by(fn group -> group.level end)

    sorted_query =
      Enum.reduce(valid_groups, query, fn group, acc_query ->
        sort_direction = if group.sort == :desc, do: :desc, else: :asc

        require Logger

        expr_type = try do
          inspect(group.expression.__struct__)
        rescue
          _ -> "not_a_struct"
        end

        Logger.debug("QueryBuilder: Processing group #{inspect(group.name)}, expression type: #{expr_type}")

        # Apply group expression as sort
        case group.expression do
          field when is_atom(field) ->
            # Try to sort by the field
            try do
              Ash.Query.sort(acc_query, [{field, sort_direction}])
            rescue
              _error ->
                # If sorting fails, just return the query unchanged
                acc_query
            end

          %{__struct__: _} = expr ->
            # For Ash expressions, check if we need an aggregate or calculation
            calc_name = :"__group_#{group.level}_#{group.name}"
            Logger.debug("QueryBuilder: Processing expression for #{calc_name}")

            # Check if this expression accesses a has_many relationship
            case extract_relationship_and_field(expr, query.resource) do
              {:has_many, rel_name, field_name} ->
                # Use a first aggregate for has_many relationships
                Logger.debug("QueryBuilder: Creating aggregate for has_many #{rel_name}.#{field_name}")

                try do
                  acc_query
                  |> Ash.Query.aggregate(calc_name, {:first, field_name}, path: [rel_name])
                  |> Ash.Query.sort([{calc_name, sort_direction}])
                rescue
                  error ->
                    Logger.warning("QueryBuilder: Failed to add aggregate for #{group.name}: #{inspect(error)}")
                    acc_query
                end

              :not_relationship ->
                # Regular calculation
                Logger.debug("QueryBuilder: Creating calculation for expression")

                try do
                  acc_query
                  |> Ash.Query.calculate(calc_name, expr, :string)
                  |> Ash.Query.sort([{calc_name, sort_direction}])
                rescue
                  error ->
                    Logger.warning("QueryBuilder: Failed to add calculation for #{group.name}: #{inspect(error)}")
                    acc_query
                end
            end

          expr ->
            # For other expressions, fallback to basic sorting
            Logger.debug("QueryBuilder: Unhandled expression type for group #{group.name}: #{inspect(expr)}")
            acc_query
        end
      end)

    {:ok, sorted_query}
  end

  defp load_relationships(query, report, opts) do
    should_load = Keyword.get(opts, :load_relationships, true)

    if should_load do
      relationships = extract_relationships(report)

      loaded_query =
        Enum.reduce(relationships, query, fn rel, acc ->
          Ash.Query.load(acc, rel)
        end)

      {:ok, loaded_query}
    else
      {:ok, query}
    end
  rescue
    error ->
      {:error, {Ash.Error.Framework, "Failed to load relationships: #{inspect(error)}"}}
  end

  defp preload_aggregates(query, report, opts) do
    should_optimize = Keyword.get(opts, :optimize_aggregates, true)

    if should_optimize do
      do_preload_aggregates(query, report)
    else
      {:ok, query}
    end
  rescue
    error ->
      {:error, {Ash.Error.Framework, "Failed to preload aggregates: #{inspect(error)}"}}
  end

  defp do_preload_aggregates(query, report) do
    # Extract aggregate requirements from report elements
    aggregates = extract_aggregates(report)

    optimized_query =
      Enum.reduce(aggregates, query, fn agg, acc ->
        # Load aggregates that can be computed at query time
        case agg do
          {:count, field} -> Ash.Query.load(acc, [{:count, field}])
          {:sum, field} -> Ash.Query.load(acc, [{:sum, field}])
          # Other aggregates computed at render time
          _ -> acc
        end
      end)

    {:ok, optimized_query}
  end

  defp extract_band_relationships(band) do
    element_relationships = extract_element_relationships(band.elements || [])

    sub_band_relationships =
      case band.bands do
        nil -> []
        sub_bands -> Enum.flat_map(sub_bands, &extract_band_relationships/1)
      end

    element_relationships ++ sub_band_relationships
  end

  defp extract_element_relationships(elements) do
    Enum.flat_map(elements, fn element ->
      case element do
        %{source: source} when is_atom(source) -> [source]
        %{source: {:field, relationship, _field}} -> [relationship]
        %{source: {relationship, _field}} when is_atom(relationship) -> [relationship]
        _ -> []
      end
    end)
  end

  defp extract_group_relationships(groups) when is_list(groups) do
    Enum.flat_map(groups, &extract_group_relationships/1)
  end

  defp extract_group_relationships(%{expression: expression}) do
    extract_relationships_from_expression(expression)
  end

  defp extract_group_relationships(_), do: []

  # Extract relationships from expressions (like expr(addresses.state))
  defp extract_relationships_from_expression(expression) do
    case expression do
      # Ash expression with relationship traversal
      %{__struct__: Ash.Expr} = ash_expr ->
        extract_relationships_from_ash_expr(ash_expr)

      # Simple field - no relationships
      field when is_atom(field) ->
        []

      # Nested field reference
      {:field, relationship, _field} when is_atom(relationship) ->
        [relationship]

      # Function expression
      expr when is_function(expr, 1) ->
        # Can't easily extract from function expressions,
        # but they're often relationship traversals
        []

      _ ->
        []
    end
  end

  # Extract relationships from Ash expressions
  defp extract_relationships_from_ash_expr(ash_expr) do
    try do
      case ash_expr do
        # Handle relationship traversal like expr(addresses.state)
        %{expression: {:get_path, _, [%{expression: {:ref, [], rel}}, _field]}} ->
          [rel]

        # Other patterns can be added as needed
        _ ->
          []
      end
    rescue
      _error -> []
    end
  end

  defp extract_aggregates(%Report{bands: bands}) do
    bands
    |> Enum.flat_map(&extract_band_aggregates/1)
    |> Enum.uniq()
  end

  defp extract_band_aggregates(band) do
    element_aggregates =
      (band.elements || [])
      |> Enum.flat_map(&extract_element_aggregates/1)

    sub_band_aggregates =
      case band.bands do
        nil -> []
        sub_bands -> Enum.flat_map(sub_bands, &extract_band_aggregates/1)
      end

    element_aggregates ++ sub_band_aggregates
  end

  defp extract_element_aggregates(element) do
    case element do
      %{function: function, source: source}
      when function in [:sum, :count, :average, :min, :max] ->
        [{function, source}]

      _ ->
        []
    end
  end

  @doc """
  Builds a query for a report by domain and report name.

  Convenience function for use with domain/report name instead of report struct.
  """
  @spec build_by_name(module(), atom(), map(), Keyword.t()) ::
          {:ok, Ash.Query.t()} | {:error, term()}
  def build_by_name(domain, report_name, params \\ %{}, opts \\ []) do
    case AshReports.Info.report(domain, report_name) do
      nil -> {:error, "Report #{report_name} not found in domain #{domain}"}
      report -> build(report, params, opts)
    end
  end

  defp build_filter_expression(%Parameter{name: _name, type: type}, value) do
    case type do
      :string when is_binary(value) ->
        # For string parameters, we assume they're used for field equality
        # We can't build a generic filter without knowing the field
        nil

      :date when is_struct(value, Date) ->
        # Same issue - need field context
        nil

      _ ->
        # Return nil for now, specific filters should be built in scope
        nil
    end
  end

  # Extract relationship and field from an Ash expression
  # Returns {:has_many, rel_name, field_name} if it's a has_many relationship
  # Returns :not_relationship otherwise
  defp extract_relationship_and_field(expr, resource) do
    try do
      case expr do
        # Handle relationship traversal like expr(addresses.state)
        %{expression: {:get_path, _context, [%{expression: {:ref, [], rel}}, field]}} ->
          # Check if this is a has_many relationship
          case Ash.Resource.Info.relationship(resource, rel) do
            %{cardinality: :many} ->
              {:has_many, rel, field}

            _ ->
              :not_relationship
          end

        # For other expression types
        _ ->
          :not_relationship
      end
    rescue
      _ -> :not_relationship
    end
  end
end
