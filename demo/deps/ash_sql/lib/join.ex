defmodule AshSql.Join do
  @moduledoc false
  import Ecto.Query, only: [from: 2, subquery: 1]

  require Ash.Query

  alias Ash.Query.{Not, Ref}

  @known_inner_join_operators [
    Ash.Query.Operator.Eq,
    Ash.Query.Operator.GreaterThan,
    Ash.Query.Operator.GreaterThanOrEqual,
    Ash.Query.Operator.In,
    Ash.Query.Operator.LessThanOrEqual,
    Ash.Query.Operator.LessThan,
    Ash.Query.Operator.NotEq
  ]

  @known_inner_join_functions [
    Ash.Query.Function.Ago,
    Ash.Query.Function.Contains,
    Ash.Query.Function.At,
    Ash.Query.Function.DateAdd,
    Ash.Query.Function.DateTimeAdd,
    Ash.Query.Function.FromNow,
    Ash.Query.Function.GetPath,
    Ash.Query.Function.Length,
    Ash.Query.Function.Minus,
    Ash.Query.Function.Round,
    Ash.Query.Function.StringDowncase,
    Ash.Query.Function.StringJoin,
    Ash.Query.Function.StringLength,
    Ash.Query.Function.StringSplit,
    Ash.Query.Function.StringTrim
  ]

  def join_all_relationships(
        query,
        filter,
        opts \\ [],
        relationship_paths \\ nil,
        path \\ [],
        source \\ nil,
        sort? \\ true,
        join_filters \\ nil,
        parent_bindings \\ nil,
        no_inner_join? \\ false
      )

  # simple optimization for common cases
  def join_all_relationships(
        query,
        filter,
        _opts,
        relationship_paths,
        _path,
        _source,
        _sort?,
        _join_filters,
        _parent_bindings,
        _no_inner_join?
      )
      when is_nil(relationship_paths) and filter in [nil, true, false] do
    {:ok, query}
  end

  def join_all_relationships(
        query,
        filter,
        opts,
        relationship_paths,
        path,
        source,
        sort?,
        join_filters,
        parent_query,
        no_inner_join?
      ) do
    no_inner_join? =
      no_inner_join? || query.__ash_bindings__.context[:data_layer][:no_inner_join?]

    case join_parent_paths(query, filter, relationship_paths) do
      {:ok, query} ->
        relationship_paths =
          relationship_paths ||
            filter
            |> Ash.Filter.relationship_paths(true)
            |> to_joins(filter, query.__ash_bindings__.resource)

        # Add parent relationship paths from relationship filters with parent expressions
        # But only if we haven't already processed them (to avoid infinite recursion)
        {query, relationship_paths} =
          if query.__ash_bindings__[:processed_parent_paths] do
            {query, relationship_paths}
          else
            parent_relationship_paths =
              extract_parent_paths_from_exists_relationships(
                filter,
                query.__ash_bindings__.resource
              )

            updated_query = put_in(query.__ash_bindings__[:processed_parent_paths], true)
            {updated_query, relationship_paths ++ parent_relationship_paths}
          end

        Enum.reduce_while(relationship_paths, {:ok, query}, fn
          {_join_type, []}, {:ok, query} ->
            {:cont, {:ok, query}}

          {join_type, [relationship | rest_rels]}, {:ok, query} ->
            join_type =
              if no_inner_join? do
                :left
              else
                join_type
              end

            source = source || relationship.source

            current_path = path ++ [relationship]

            current_join_type = join_type

            look_for_join_types =
              case join_type do
                :left ->
                  [:left, :inner]

                :inner ->
                  [:left, :inner]

                other ->
                  [other]
              end

            binding =
              get_binding(source, Enum.map(current_path, & &1.name), query, look_for_join_types)

            # We can't reuse joins if we're adding filters/have a separate parent binding
            if is_nil(join_filters) && is_nil(parent_query) && binding do
              case join_all_relationships(
                     query,
                     filter,
                     opts,
                     [{join_type, rest_rels}],
                     current_path,
                     source,
                     sort?
                   ) do
                {:ok, query} ->
                  {:cont, {:ok, query}}

                {:error, error} ->
                  {:halt, {:error, error}}
              end
            else
              case join_relationship(
                     query,
                     relationship,
                     Enum.map(path, & &1.name),
                     current_join_type,
                     source,
                     filter,
                     sort?,
                     join_filters[Enum.map(current_path, & &1.name)]
                   ) do
                {:ok, joined_query} ->
                  joined_query_with_distinct = add_distinct(relationship, join_type, joined_query)

                  case join_all_relationships(
                         joined_query_with_distinct,
                         filter,
                         opts,
                         [{join_type, rest_rels}],
                         current_path,
                         source,
                         sort?,
                         join_filters,
                         Map.update!(joined_query, :__ash_bindings__, fn ash_bindings ->
                           Map.put(
                             ash_bindings,
                             :refs_at_path,
                             Enum.map(path, & &1.name) ++ [relationship.name]
                           )
                         end)
                       ) do
                    {:ok, query} ->
                      {:cont, {:ok, query}}

                    {:error, error} ->
                      {:halt, {:error, error}}
                  end

                {:error, error} ->
                  {:halt, {:error, error}}
              end
            end
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc false
  def parent_expr(filter) do
    filter
    |> Ash.Filter.map(fn
      %Ash.Query.Parent{expr: expr} ->
        {:halt, expr}

      %Ash.Query.Ref{} ->
        nil

      %Ash.Query.Exists{} ->
        nil

      other ->
        other
    end)
  end

  defp join_parent_paths(query, filter, nil) do
    case query.__ash_bindings__[:lateral_join_source_query] do
      nil ->
        {:ok, query}

      lateral_join_source_query ->
        case join_all_relationships(lateral_join_source_query, parent_expr(filter)) do
          {:ok, lateral_join_source_query} ->
            {:ok,
             put_in(query.__ash_bindings__.lateral_join_source_query, lateral_join_source_query)
             |> Map.update!(:__ash_bindings__, fn bindings ->
               Map.put(
                 bindings,
                 :parent_bindings,
                 Map.put(lateral_join_source_query.__ash_bindings__, :parent?, true)
               )
             end)}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp join_parent_paths(query, _filter, _relationship_paths) do
    {:ok, query}
  end

  defp to_joins(paths, filter, resource) do
    paths
    |> Enum.reject(&(&1 == []))
    |> Enum.map(fn path ->
      if can_inner_join?(path, filter) do
        {:inner,
         relationship_path_to_relationships(
           resource,
           path
         )}
      else
        {:left,
         relationship_path_to_relationships(
           resource,
           path
         )}
      end
    end)
  end

  defp extract_parent_paths_from_exists_relationships(filter, resource) do
    # Use flat_map to accumulate parent paths from exists expressions
    parent_paths =
      Ash.Filter.flat_map(filter, fn
        %Ash.Query.Exists{at_path: at_path, path: [first_rel_name | _rest]} = _exists ->
          resource = Ash.Resource.Info.related(resource, at_path)
          # Get the first relationship
          relationship = Ash.Resource.Info.relationship(resource, first_rel_name)

          if relationship && relationship.filter do
            # Extract parent expressions from the relationship filter
            extract_parent_refs_from_filter(relationship.filter)
          else
            []
          end

        _other ->
          []
      end)

    # Convert to relationship path tuples and return
    parent_paths
    |> Enum.uniq()
    |> Enum.map(fn path ->
      relationships = relationship_path_to_relationships(resource, path)
      {:left, relationships}
    end)
  end

  defp extract_parent_refs_from_filter(filter) do
    # Use flat_map to accumulate relationship paths from parent expressions
    Ash.Filter.flat_map(filter, fn
      %Ash.Query.Parent{expr: expr} = _parent ->
        # Extract refs from parent expression
        expr
        |> Ash.Filter.list_refs()
        |> Enum.map(& &1.relationship_path)
        |> Enum.reject(&Enum.empty?/1)

      _other ->
        []
    end)
    |> Enum.uniq()
  end

  def relationship_path_to_relationships(resource, path, acc \\ [])
  def relationship_path_to_relationships(_resource, [], acc), do: Enum.reverse(acc)

  def relationship_path_to_relationships(resource, [name | rest], acc) do
    relationship = Ash.Resource.Info.relationship(resource, name)

    if !relationship do
      raise "no such relationship #{inspect(resource)}.#{name}"
    end

    relationship_path_to_relationships(relationship.destination, rest, [relationship | acc])
  end

  def related_subquery(
        relationship,
        root_query,
        opts \\ []
      ) do
    on_parent_expr = Keyword.get(opts, :on_parent_expr, & &1)
    on_subquery = Keyword.get(opts, :on_subquery, & &1)
    filter = Keyword.get(opts, :filter, nil)
    filter_subquery? = Keyword.get(opts, :filter_subquery?, false)
    skip_distinct_for_first_rel? = Keyword.get(opts, :skip_distinct_for_first_rel?, false)

    with {:ok, query} <- related_query(relationship, root_query, opts) do
      has_parent_expr? =
        !!query.__ash_bindings__.context[:data_layer][:has_parent_expr?] ||
          not is_nil(query.limit)

      query =
        if has_parent_expr? do
          on_parent_expr.(query)
        else
          query
        end

      query =
        if skip_distinct_for_first_rel? do
          Map.update!(query, :__ash_bindings__, &Map.put(&1, :skip_distinct_for_first_rel?, true))
        else
          query
        end

      query = on_subquery.(query)

      query = limit_from_many(query, relationship, filter, filter_subquery?, opts)

      query =
        if opts[:return_subquery?] do
          subquery(query)
        else
          if Enum.empty?(query.joins) && Enum.empty?(query.order_bys) && Enum.empty?(query.wheres) do
            query
          else
            from(row in subquery(query), as: ^(opts[:start_bindings_at] || 0))
            |> AshSql.Bindings.default_bindings(
              relationship.destination,
              query.__ash_bindings__.sql_behaviour
            )
            |> AshSql.Bindings.merge_expr_accumulator(
              query.__ash_bindings__.expression_accumulator
            )
            |> Map.update!(
              :__ash_bindings__,
              fn bindings ->
                bindings
                |> Map.put(:current, query.__ash_bindings__.current)
                |> put_in([:context, :data_layer], %{
                  has_parent_expr?: has_parent_expr?
                })
              end
            )
          end
        end

      {:ok, query}
    end
  end

  defp related_query(relationship, query, opts) do
    sort? = Keyword.get(opts, :sort?, false)
    filter = Keyword.get(opts, :filter, nil)
    filter_subquery? = Keyword.get(opts, :filter_subquery?, false)
    parent_resources = Keyword.get(opts, :parent_stack, [relationship.source])

    read_action =
      relationship.read_action ||
        Ash.Resource.Info.primary_action!(relationship.destination, :read).name

    context = Map.delete(query.__ash_bindings__.context, :data_layer)

    tenant = query.__ash_bindings__.context[:private][:tenant]

    relationship.destination
    |> Ash.Query.new()
    |> Ash.Query.set_context(context)
    |> Ash.Query.set_context(%{data_layer: %{in_group?: !!opts[:in_group?]}})
    |> Ash.Query.set_context(%{
      data_layer: %{
        table: nil,
        start_bindings_at: opts[:start_bindings_at] || 0
      }
    })
    |> Ash.Query.set_context(relationship.context)
    |> Ash.Query.do_filter(relationship.filter, parent_stack: parent_resources)
    |> then(fn query ->
      if Map.get(relationship, :from_many?) && filter_subquery? do
        query
      else
        Ash.Query.do_filter(query, filter, parent_stack: parent_resources)
      end
    end)
    |> Ash.Query.do_filter(opts[:apply_filter], parent_stack: parent_resources)
    |> then(fn query ->
      if query.__validated_for_action__ == read_action do
        query
      else
        Ash.Query.for_read(query, read_action, %{},
          actor: context[:private][:actor],
          tenant: context[:private][:tenant]
        )
      end
    end)
    |> Ash.Query.unset([:sort, :distinct, :select, :limit, :offset])
    |> handle_attribute_multitenancy(tenant)
    |> hydrate_refs(context[:private][:actor])
    |> then(fn query ->
      if sort? do
        Ash.Query.sort(query, relationship.sort)
      else
        Ash.Query.unset(query, :sort)
      end
    end)
    |> set_has_parent_expr_context(relationship)
    |> case do
      %{valid?: true} = related_query ->
        parent_bindings =
          query.__ash_bindings__
          |> Map.put(:refs_at_path, List.wrap(opts[:refs_at_path]))
          |> then(fn bindings ->
            if opts[:skip_distinct_for_first_rel?] do
              Map.put(bindings, :skip_distinct_for_first_rel?, true)
            else
              bindings
            end
          end)

        Ash.Query.data_layer_query(
          Ash.Query.set_context(related_query, %{
            data_layer: %{
              parent_bindings: parent_bindings
            }
          })
        )
        |> case do
          {:ok, ecto_query} ->
            ecto_query =
              if opts[:skip_distinct_for_first_rel?] do
                Map.update!(
                  ecto_query,
                  :__ash_bindings__,
                  &Map.put(&1, :skip_distinct_for_first_rel?, true)
                )
              else
                ecto_query
              end

            {:ok,
             ecto_query
             |> set_join_prefix(query, Map.get(relationship, :through, relationship.destination))
             |> Ecto.Query.exclude(:select)}

          {:error, error} ->
            {:error, error}
        end

      %{errors: errors} ->
        {:error, errors}
    end
  end

  @doc false
  def handle_attribute_multitenancy(query, tenant) do
    if tenant && Ash.Resource.Info.multitenancy_strategy(query.resource) == :attribute do
      multitenancy_attribute = Ash.Resource.Info.multitenancy_attribute(query.resource)

      if multitenancy_attribute do
        {m, f, a} = Ash.Resource.Info.multitenancy_parse_attribute(query.resource)
        attribute_value = apply(m, f, [query.to_tenant | a])

        query
        |> Ash.Query.set_tenant(tenant)
        |> Ash.Query.filter(^Ash.Expr.ref(multitenancy_attribute) == ^attribute_value)
      else
        query
      end
    else
      query
    end
  end

  @doc false
  def hydrate_refs(query, actor) do
    query.filter
    |> Ash.Expr.fill_template(
      actor: actor,
      tenant: query.to_tenant,
      args: %{},
      context: query.context
    )
    |> Ash.Filter.hydrate_refs(%{resource: query.resource})
    |> case do
      {:ok, result} -> %{query | filter: result}
      {:error, error} -> Ash.Query.add_error(query, error)
    end
  end

  defp limit_from_many(
         query,
         %{from_many?: true, destination: destination},
         filter,
         filter_subquery?,
         opts
       ) do
    if filter_subquery? do
      query =
        from(row in Ecto.Query.subquery(from(row in query, limit: 1)),
          as: ^query.__ash_bindings__.root_binding
        )
        |> Map.put(:__ash_bindings__, query.__ash_bindings__)
        |> AshSql.Bindings.default_bindings(
          destination,
          query.__ash_bindings__.sql_behaviour
        )

      {:ok, query} = AshSql.Filter.filter(query, filter, query.__ash_bindings__.resource)

      if opts[:select_star?] do
        from(row in Ecto.Query.exclude(query, :select), select: 1)
      else
        query
      end
    else
      if opts[:select_star?] do
        from(row in Ecto.Query.exclude(query, :select), select: 1)
      else
        query
      end
    end
  end

  defp limit_from_many(query, _, _, _, opts) do
    if opts[:select_star?] do
      from(row in Ecto.Query.exclude(query, :select), select: 1)
    else
      query
    end
  end

  defp set_has_parent_expr_context(query, relationship) do
    has_parent_expr? =
      Ash.Actions.Read.Relationships.has_parent_expr?(
        %{
          relationship
          | filter: query.filter,
            sort: query.sort
        },
        query.context,
        query.domain
      )

    Ash.Query.set_context(query, %{data_layer: %{has_parent_expr?: has_parent_expr?}})
  end

  def set_join_prefix(join_query, query, resource) do
    %{join_query | prefix: join_prefix(join_query, query, resource)}
  end

  defp join_prefix(base_query, query, resource) do
    if Ash.Resource.Info.multitenancy_strategy(resource) == :context do
      query.__ash_bindings__.sql_behaviour.schema(resource) ||
        Map.get(query, :__tenant__) ||
        Map.get(base_query, :__tenant__) ||
        base_query.prefix ||
        query.__ash_bindings__.sql_behaviour.repo(resource, :mutate).config()[
          :default_prefix
        ]
    else
      query.__ash_bindings__.sql_behaviour.schema(resource) ||
        query.__ash_bindings__.sql_behaviour.repo(resource, :mutate).config()[
          :default_prefix
        ]
    end
  end

  defp can_inner_join?(path, expr) do
    expr
    |> AshSql.Expr.split_statements(:and)
    |> Enum.any?(&known_inner_join_predicate_for_path_in_all_branches?(path, &1))
  end

  defp known_inner_join_predicate_for_path_in_all_branches?(path, expr) do
    expr
    |> AshSql.Expr.split_statements(:or)
    |> case do
      [expr] ->
        case AshSql.Expr.split_statements(expr, :and) do
          [expr] ->
            known_predicates_only_containing?(path, expr)

          many ->
            Enum.any?(many, &known_inner_join_predicate_for_path_in_all_branches?(path, &1))
        end

      branches ->
        Enum.all?(branches, &can_inner_join?(path, &1))
    end
  end

  defp known_predicates_only_containing?(path, %Not{expression: expression}) do
    known_predicates_only_containing?(path, expression)
  end

  defp known_predicates_only_containing?(path, %struct{
         __operator__?: true,
         left: left,
         right: right
       })
       when struct in @known_inner_join_operators do
    Enum.any?([left, right], &known_predicates_only_containing?(path, &1))
  end

  defp known_predicates_only_containing?(path, %struct{
         __function__?: true,
         arguments: arguments
       })
       when struct in @known_inner_join_functions do
    Enum.any?(arguments, &known_predicates_only_containing?(path, &1))
  end

  defp known_predicates_only_containing?(path, %Ref{relationship_path: path}) do
    true
  end

  defp known_predicates_only_containing?(_, _), do: false

  @doc false
  def get_binding(resource, candidate_path, %{__ash_bindings__: _} = query, types) do
    types = List.wrap(types)

    Enum.find_value(query.__ash_bindings__.bindings, fn
      {binding, %{path: path, source: source, type: type}} ->
        if type in types &&
             Ash.SatSolver.synonymous_relationship_paths?(resource, path, candidate_path, source) do
          binding
        end

      _ ->
        nil
    end)
  end

  def get_binding(_, _, _, _), do: nil

  defp add_distinct(relationship, _join_type, joined_query) do
    # Skip distinct for first relationship in aggregate contexts
    skip_for_aggregate_first_rel? =
      Map.get(joined_query.__ash_bindings__, :skip_distinct_for_first_rel?, false) ||
        Map.get(
          joined_query.__ash_bindings__.context[:data_layer][:parent_bindings] || %{},
          :skip_distinct_for_first_rel?,
          false
        )

    if !(joined_query.__ash_bindings__.in_group? ||
           joined_query.__ash_bindings__.context[:data_layer][:in_group?]) &&
         (relationship.cardinality == :many || Map.get(relationship, :from_many?)) &&
         !skip_for_aggregate_first_rel? &&
         !joined_query.distinct do
      sort = joined_query.__ash_bindings__[:sort] || []

      {joined_query, distinct} =
        Enum.reduce(sort, {joined_query, []}, fn
          {attribute, direction}, {joined_query, distinct} when is_atom(attribute) ->
            {joined_query, [{attribute, direction} | distinct]}

          {%Ash.Query.Calculation{} = calculation, direction}, {joined_query, distinct} ->
            resource = joined_query.__ash_bindings__.resource
            expression = calculation.module.expression(calculation.opts, calculation.context)
            filter = %Ash.Filter{resource: resource, expression: expression}
            {:ok, joined_query} = AshSql.Join.join_all_relationships(joined_query, filter)

            case AshSql.Expr.dynamic_expr(joined_query, expression, joined_query.__ash_bindings__) do
              {result, _} when is_atom(result) -> {joined_query, []}
              {dynamic_expr, _} -> {joined_query, [{dynamic_expr, direction} | distinct]}
            end

          _other, {joined_query, distinct} ->
            {joined_query, distinct}
        end)
        |> then(fn {joined_query, distinct} ->
          {joined_query,
           Enum.concat(
             Enum.reverse(distinct),
             Ash.Resource.Info.primary_key(joined_query.__ash_bindings__.resource)
           )}
        end)

      distinct = distinct |> AshSql.Sort.sanitize_sort()

      if joined_query.__ash_bindings__.sql_behaviour.multicolumn_distinct?() do
        from(row in joined_query,
          distinct: ^distinct
        )
      else
        from(row in joined_query, distinct: true)
      end
    else
      joined_query
    end
  end

  defp join_relationship(
         query,
         %{manual: {module, opts}} = relationship,
         path,
         kind,
         source,
         filter,
         sort?,
         apply_filter
       ) do
    full_path = path ++ [relationship.name]
    initial_ash_bindings = query.__ash_bindings__

    binding_data = %{type: kind, path: full_path, source: source}

    query = AshSql.Bindings.add_binding(query, binding_data)

    used_aggregates = Ash.Filter.used_aggregates(filter, full_path)

    with {:ok, relationship_destination} <-
           related_subquery(relationship, query,
             sort?: sort?,
             apply_filter?: apply_filter,
             refs_at_path: path
           ) do
      binding_kinds =
        case kind do
          :left ->
            [:left, :inner]

          :inner ->
            [:left, :inner]

          other ->
            [other]
        end

      current_binding =
        Enum.find_value(
          initial_ash_bindings.bindings,
          initial_ash_bindings.root_binding,
          fn {binding, data} ->
            if data.type in binding_kinds && data.path == path do
              binding
            end
          end
        )

      case apply(module, query.__ash_bindings__.sql_behaviour.manual_relationship_function(), [
             query,
             opts,
             current_binding,
             initial_ash_bindings.current,
             kind,
             relationship_destination
           ]) do
        {:ok, query} ->
          AshSql.Aggregate.add_aggregates(
            query,
            used_aggregates,
            relationship.destination,
            false,
            initial_ash_bindings.current,
            {query.__ash_bindings__.resource, full_path}
          )

        {:error, query} ->
          {:error, query}
      end
    end
  rescue
    e in UndefinedFunctionError ->
      if e.function == query.__ash_bindings__.sql_behaviour.manual_relationship_function() do
        reraise """
                Cannot join to a manual relationship #{inspect(module)} that does not implement the `#{query.__ash_bindings__.sql_behaviour.manual_relationship_behaviour()}` behaviour.
                """,
                __STACKTRACE__
      else
        reraise e, __STACKTRACE__
      end
  end

  defp join_relationship(
         query,
         %{type: :many_to_many} = relationship,
         path,
         kind,
         source,
         filter,
         sort?,
         apply_filter
       ) do
    if Ash.Actions.Read.Relationships.has_parent_expr?(
         relationship,
         query.__ash_bindings__[:context],
         query.__ash_bindings__[:domain]
       ) do
      join_many_to_many_with_parent_expr(
        query,
        relationship,
        path,
        kind,
        source,
        filter,
        sort?,
        apply_filter
      )
    else
      join_relationship =
        Ash.Resource.Info.relationship(relationship.source, relationship.join_relationship)

      join_path = path ++ [join_relationship.name]

      full_path = path ++ [relationship.name]

      initial_ash_bindings = query.__ash_bindings__

      binding_data = %{type: kind, path: full_path, source: source}

      used_aggregates = Ash.Filter.used_aggregates(filter, full_path)

      query =
        query
        |> AshSql.Bindings.add_binding(%{
          path: join_path,
          type: :left,
          source: source
        })
        |> AshSql.Bindings.add_binding(binding_data)

      with {:ok, query} <- join_all_relationships(query, parent_expr(relationship.filter)),
           {:ok, relationship_through} <- related_subquery(join_relationship, query),
           {:ok, relationship_destination} <-
             related_subquery(relationship, query,
               sort?: sort?,
               apply_filter?: apply_filter,
               refs_at_path: path
             ) do
        relationship_through = set_join_prefix(relationship_through, query, relationship.through)

        relationship_destination =
          set_join_prefix(relationship_destination, query, relationship.destination)

        {relationship_destination, dest_acc} =
          maybe_apply_filter(
            relationship_destination,
            query,
            query.__ash_bindings__,
            apply_filter
          )

        query =
          query
          |> AshSql.Bindings.merge_expr_accumulator(dest_acc)

        binding_kinds =
          case kind do
            :left ->
              [:left, :inner]

            :inner ->
              [:left, :inner]

            other ->
              [other]
          end

        current_binding =
          Enum.find_value(
            initial_ash_bindings.bindings,
            initial_ash_bindings.root_binding,
            fn {binding, data} ->
              if data.type in binding_kinds && data.path == path do
                binding
              end
            end
          )

        query =
          case kind do
            :inner ->
              from(_ in query,
                join: through in ^relationship_through,
                as: ^initial_ash_bindings.current,
                on:
                  field(as(^current_binding), ^relationship.source_attribute) ==
                    field(through, ^relationship.source_attribute_on_join_resource),
                join: destination in ^relationship_destination,
                as: ^(initial_ash_bindings.current + 1),
                on:
                  field(destination, ^relationship.destination_attribute) ==
                    field(through, ^relationship.destination_attribute_on_join_resource)
              )

            _ ->
              from(_ in query,
                left_join: through in ^relationship_through,
                as: ^initial_ash_bindings.current,
                on:
                  field(as(^current_binding), ^relationship.source_attribute) ==
                    field(through, ^relationship.source_attribute_on_join_resource),
                left_join: destination in ^relationship_destination,
                as: ^(initial_ash_bindings.current + 1),
                on:
                  field(destination, ^relationship.destination_attribute) ==
                    field(through, ^relationship.destination_attribute_on_join_resource)
              )
          end

        AshSql.Aggregate.add_aggregates(
          query,
          used_aggregates,
          relationship.destination,
          false,
          initial_ash_bindings.current,
          {query.__ash_bindings__.resource, full_path}
        )
      end
    end
  end

  defp join_relationship(
         query,
         relationship,
         path,
         kind,
         source,
         filter,
         sort?,
         apply_filter
       ) do
    full_path = path ++ [relationship.name]
    initial_ash_bindings = query.__ash_bindings__

    binding_data = %{type: kind, path: full_path, source: source}

    query = AshSql.Bindings.add_binding(query, binding_data)

    used_aggregates = Ash.Filter.used_aggregates(filter, full_path)

    binding_kinds =
      case kind do
        :left ->
          [:left, :inner]

        :inner ->
          [:left, :inner]

        other ->
          [other]
      end

    current_binding =
      Enum.find_value(
        initial_ash_bindings.bindings,
        initial_ash_bindings.root_binding,
        fn {binding, data} ->
          if data.type in binding_kinds && data.path == path do
            binding
          end
        end
      )

    destination_filter =
      relationship.destination
      |> Ash.Query.do_filter(relationship.filter, parent_stack: [query.__ash_bindings__.resource])
      |> Map.get(:filter)

    case join_all_relationships(
           query,
           parent_expr(destination_filter),
           [],
           nil,
           relationship_path_to_relationships(query.__ash_bindings__.resource, path)
         ) do
      {:ok, query} ->
        case related_subquery(relationship, query,
               sort?: sort?,
               apply_filter: apply_filter,
               start_bindings_at: 500,
               refs_at_path: path,
               filter_subquery?: true,
               sort?: Map.get(relationship, :from_many?),
               on_subquery: fn subquery ->
                 if !Map.get(relationship, :from_many?) || Map.get(relationship, :no_attributes?) do
                   subquery
                 else
                   source_ref =
                     AshSql.Expr.ref_binding(
                       %Ref{
                         attribute:
                           Ash.Resource.Info.attribute(
                             query.__ash_bindings__.resource,
                             relationship.source_attribute
                           ),
                         resource: query.__ash_bindings__.resource,
                         relationship_path: path
                       },
                       query.__ash_bindings__
                     )

                   Ecto.Query.from(destination in subquery,
                     where:
                       field(parent_as(^source_ref), ^relationship.source_attribute) ==
                         field(destination, ^relationship.destination_attribute)
                   )
                 end
               end,
               on_parent_expr: fn subquery ->
                 if Map.get(relationship, :no_attributes?) do
                   subquery
                 else
                   from(row in subquery,
                     where:
                       field(parent_as(^current_binding), ^relationship.source_attribute) ==
                         field(
                           row,
                           ^relationship.destination_attribute
                         )
                   )
                 end
               end
             ) do
          {:error, error} ->
            {:error, error}

          {:ok, relationship_destination} ->
            query =
              case {kind, Map.get(relationship, :no_attributes?, false),
                    relationship_destination.__ash_bindings__.context[:data_layer][
                      :has_parent_expr?
                    ] || Map.get(relationship, :from_many?, false)} do
                {:inner, true, false} ->
                  from(_ in query,
                    join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on: true
                  )

                {:inner, true, true} ->
                  from(_ in query,
                    inner_lateral_join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on: true
                  )

                {:inner, false, false} ->
                  from(_ in query,
                    join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on:
                      field(as(^current_binding), ^relationship.source_attribute) ==
                        field(
                          destination,
                          ^relationship.destination_attribute
                        )
                  )

                {:inner, false, true} ->
                  from(_ in query,
                    inner_lateral_join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on: true
                  )

                {:left, true, false} ->
                  from(_ in query,
                    left_join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on: true
                  )

                {:left, true, true} ->
                  from(_ in query,
                    left_lateral_join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on: true
                  )

                {:left, false, false} ->
                  from(_ in query,
                    left_join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on:
                      field(as(^current_binding), ^relationship.source_attribute) ==
                        field(
                          destination,
                          ^relationship.destination_attribute
                        )
                  )

                {:left, false, true} ->
                  from(_ in query,
                    left_lateral_join: destination in ^relationship_destination,
                    as: ^initial_ash_bindings.current,
                    on: true
                  )
              end

            query
            |> AshSql.Aggregate.add_aggregates(
              used_aggregates,
              relationship.destination,
              false,
              initial_ash_bindings.current,
              {query.__ash_bindings__.resource, full_path}
            )
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp join_many_to_many_with_parent_expr(
         query,
         relationship,
         path,
         kind,
         source,
         filter,
         sort?,
         apply_filter
       ) do
    join_relationship =
      Ash.Resource.Info.relationship(relationship.source, relationship.join_relationship)

    join_path = path ++ [join_relationship.name]

    full_path = path ++ [relationship.name]

    initial_ash_bindings = query.__ash_bindings__

    binding_data = %{type: kind, path: full_path, source: source}

    used_aggregates = Ash.Filter.used_aggregates(filter, full_path)

    binding_kinds =
      case kind do
        :left ->
          [:left, :inner]

        :inner ->
          [:left, :inner]

        other ->
          [other]
      end

    current_binding =
      Enum.find_value(
        initial_ash_bindings.bindings,
        initial_ash_bindings.root_binding,
        fn {binding, data} ->
          if data.type in binding_kinds && data.path == path do
            binding
          end
        end
      )

    query_with_bindings =
      AshSql.Bindings.add_binding(query, %{
        path: join_path,
        type: :left,
        source: source
      })

    query_with_bindings =
      put_in(
        query_with_bindings.__ash_bindings__[:lateral_join_bindings],
        query.__ash_bindings__.current
      )

    with {:ok, query} <-
           join_all_relationships(
             query,
             parent_expr(relationship.filter),
             [],
             nil,
             relationship_path_to_relationships(query.__ash_bindings__.resource, path)
           ),
         {:ok, relationship_through} <- related_subquery(join_relationship, query),
         {:ok, relationship_destination} <-
           related_subquery(relationship, query_with_bindings,
             sort?: sort?,
             apply_filter?: apply_filter,
             on_subquery: fn subquery ->
               case kind do
                 :inner ->
                   from(destination in subquery,
                     join: through in ^relationship_through,
                     as: ^initial_ash_bindings.current,
                     on:
                       field(through, ^relationship.destination_attribute_on_join_resource) ==
                         field(destination, ^relationship.destination_attribute),
                     on:
                       field(parent_as(^current_binding), ^relationship.source_attribute) ==
                         field(through, ^relationship.source_attribute_on_join_resource)
                   )

                 _ ->
                   from(destination in subquery,
                     left_join: through in ^relationship_through,
                     as: ^initial_ash_bindings.current,
                     on:
                       field(through, ^relationship.destination_attribute_on_join_resource) ==
                         field(destination, ^relationship.destination_attribute),
                     on:
                       field(parent_as(^current_binding), ^relationship.source_attribute) ==
                         field(through, ^relationship.source_attribute_on_join_resource)
                   )
               end
             end,
             refs_at_path: path
           ) do
      {relationship_destination, dest_acc} =
        maybe_apply_filter(
          relationship_destination,
          query,
          query.__ash_bindings__,
          apply_filter
        )

      query =
        query
        |> AshSql.Bindings.merge_expr_accumulator(dest_acc)

      query =
        case kind do
          :inner ->
            from(row in query,
              inner_lateral_join: destination in ^relationship_destination,
              on: true,
              as: ^initial_ash_bindings.current
            )

          :left ->
            from(row in query,
              left_lateral_join: destination in ^relationship_destination,
              on: true,
              as: ^initial_ash_bindings.current
            )
        end

      query =
        query
        |> AshSql.Bindings.add_binding(binding_data)

      AshSql.Aggregate.add_aggregates(
        query,
        used_aggregates,
        relationship.destination,
        false,
        initial_ash_bindings.current,
        {query.__ash_bindings__.resource, full_path}
      )
    end
  end

  @doc false
  def maybe_apply_filter(query, _root_query, _bindings, nil),
    do: {query, %AshSql.Expr.ExprInfo{}}

  def maybe_apply_filter(query, root_query, bindings, filter) do
    {dynamic, acc} = AshSql.Expr.dynamic_expr(root_query, filter, bindings, true)
    {from(row in query, where: ^dynamic), acc}
  end
end
