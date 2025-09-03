defmodule AshSql.Aggregate do
  @moduledoc false

  require Ecto.Query
  require Ash.Query
  import Ecto.Query, only: [from: 2]

  @next_aggregate_names Enum.reduce(0..999, %{}, fn i, acc ->
                          Map.put(acc, :"aggregate_#{i}", :"aggregate_#{i + 1}")
                        end)

  def add_aggregates(
        query,
        aggregates,
        resource,
        select?,
        source_binding,
        root_data \\ nil
      )

  def add_aggregates(query, [], _, _, _, _), do: {:ok, query}

  def add_aggregates(query, aggregates, resource, select?, source_binding, root_data) do
    case resource_aggregates_to_aggregates(resource, query, aggregates) do
      {:ok, aggregates} ->
        root_data_path =
          case root_data do
            {_, path} ->
              path

            _ ->
              []
          end

        tenant =
          case Enum.at(aggregates, 0) do
            %{context: %{tenant: tenant}} ->
              Ash.ToTenant.to_tenant(tenant, resource)

            _ ->
              nil
          end

        {query, aggregates} =
          Enum.reduce(
            aggregates,
            {query, []},
            fn aggregate, {query, aggregates} ->
              if is_atom(aggregate.name) do
                existing_agg = query.__ash_bindings__.aggregate_defs[aggregate.name]

                if existing_agg && different_queries?(existing_agg.query, aggregate.query) do
                  {query, name} = use_aggregate_name(query, aggregate.name)
                  {query, [%{aggregate | name: name} | aggregates]}
                else
                  {query, [aggregate | aggregates]}
                end
              else
                {query, name} = use_aggregate_name(query, aggregate.name)

                {query, [%{aggregate | name: name} | aggregates]}
              end
            end
          )

        aggregates =
          if root_data_path == [] do
            Enum.reject(aggregates, fn aggregate ->
              if Map.has_key?(query.__ash_bindings__.aggregate_defs, aggregate.name) do
                true
              end
            end)
          else
            aggregates
          end

        query =
          if root_data_path == [] do
            query
            |> Map.update!(:__ash_bindings__, fn bindings ->
              bindings
              |> Map.update!(:aggregate_defs, fn aggregate_defs ->
                Map.merge(aggregate_defs, Map.new(aggregates, &{&1.name, &1}))
              end)
            end)
          else
            query
          end

        result =
          aggregates
          |> Enum.reject(&already_added?(&1, query.__ash_bindings__, root_data_path))
          |> Enum.group_by(fn aggregate ->
            {aggregate.relationship_path || [], aggregate.resource, aggregate.join_filters || %{},
             aggregate.query.action.name}
          end)
          |> Enum.flat_map(fn {{path, resource, join_filters, read_action}, aggregates} ->
            {can_group, cant_group} =
              Enum.split_with(aggregates, &can_group?(resource, &1, query))

            [{{path, resource, join_filters, read_action}, can_group}] ++
              Enum.map(cant_group, &{{path, resource, join_filters, read_action}, [&1]})
          end)
          |> Enum.reject(fn
            {_, []} ->
              true

            _ ->
              false
          end)
          |> Enum.reduce_while(
            {:ok, query, []},
            fn {{path, resource, join_filters, read_action}, aggregates},
               {:ok, query, dynamics} ->
              related = Ash.Resource.Info.related(resource, path)
              read_action = Ash.Resource.Info.action(related, read_action)

              if read_action.modify_query do
                raise """
                Data layer does not currently support aggregates over read actions that use `modify_query`.

                Resource: #{inspect(resource)}
                Relationship Path: #{inspect(path)}
                Action: #{read_action.name}
                """
              end

              {first_relationship, relationship_path} =
                case path do
                  [] ->
                    {nil, []}

                  [first_relationship | rest] ->
                    case Ash.Resource.Info.relationship(resource, first_relationship) do
                      nil ->
                        raise "No such relationship #{inspect(resource)}.#{first_relationship}. aggregates: #{inspect(aggregates)}"

                      first_relationship ->
                        {first_relationship, rest}
                    end
                end

              hydrated_agg_refs =
                aggregates
                |> Enum.map(&(&1.query.filter && &1.query.filter.expression))
                |> Ash.Filter.hydrate_refs(%{
                  resource: Enum.at(aggregates, 0).query.resource,
                  parent_stack:
                    if(first_relationship, do: [first_relationship.source], else: [resource])
                })
                |> elem(1)

              parent_expr =
                if first_relationship do
                  first_relationship.filter
                  |> Ash.Filter.hydrate_refs(%{
                    resource: first_relationship.destination,
                    parent_stack: [first_relationship.source]
                  })
                  |> elem(1)
                  |> then(&[&1 | hydrated_agg_refs])
                  |> AshSql.Join.parent_expr()
                end

              used_aggregates =
                Ash.Filter.used_aggregates(parent_expr, [])

              {:ok, query} =
                AshSql.Aggregate.add_aggregates(
                  query,
                  used_aggregates,
                  resource,
                  false,
                  query.__ash_bindings__.root_binding
                )

              {:ok, query} =
                AshSql.Join.join_all_relationships(
                  query,
                  parent_expr,
                  [],
                  nil,
                  [],
                  nil,
                  true,
                  nil,
                  nil,
                  true
                )

              is_single? = match?([_], aggregates)

              cond do
                is_single? &&
                    optimizable_first_aggregate?(
                      resource,
                      Enum.at(aggregates, 0),
                      query
                    ) ->
                  case add_first_join_aggregate(
                         query,
                         resource,
                         hd(aggregates),
                         root_data,
                         first_relationship,
                         source_binding
                       ) do
                    {:ok, query, dynamic} ->
                      query =
                        if select? do
                          select_or_merge(query, hd(aggregates).name, dynamic)
                        else
                          query
                        end

                      {:cont, {:ok, query, dynamics}}

                    {:error, error} ->
                      {:halt, {:error, error}}
                  end

                is_single? && Enum.at(aggregates, 0).kind == :exists ->
                  [aggregate] = aggregates

                  expr =
                    if is_nil(Map.get(aggregate.query, :filter)) do
                      true
                    else
                      Map.get(aggregate.query, :filter)
                    end

                  {exists, acc} =
                    AshSql.Expr.dynamic_expr(
                      query,
                      %Ash.Query.Exists{
                        path: root_data_path ++ aggregate.relationship_path,
                        related?: aggregate.related?,
                        resource: aggregate.query.resource,
                        expr: expr
                      },
                      query.__ash_bindings__
                    )

                  {:cont,
                   {:ok, AshSql.Bindings.merge_expr_accumulator(query, acc),
                    [{aggregate.load, aggregate.name, exists} | dynamics]}}

                true ->
                  tmp_query =
                    if first_relationship && first_relationship.type == :many_to_many do
                      put_in(query.__ash_bindings__[:lateral_join_bindings], [
                        query.__ash_bindings__.current
                      ])
                      |> AshSql.Bindings.explicitly_set_binding(
                        %{
                          type: :left,
                          path: [first_relationship.join_relationship]
                        },
                        query.__ash_bindings__.current
                      )
                    else
                      query
                    end

                  start_bindings_at =
                    if first_relationship && first_relationship.type == :many_to_many do
                      query.__ash_bindings__.current + 1
                    else
                      query.__ash_bindings__.current
                    end

                  case get_subquery(
                         resource,
                         aggregates,
                         is_single?,
                         first_relationship,
                         relationship_path,
                         tmp_query,
                         start_bindings_at,
                         query,
                         source_binding,
                         root_data_path,
                         tenant,
                         join_filters
                       ) do
                    {:error, error} ->
                      {:error, error}

                    {:ok, subquery} ->
                      query =
                        join_subquery(
                          query,
                          subquery,
                          first_relationship,
                          relationship_path,
                          aggregates,
                          source_binding,
                          root_data_path
                        )

                      if select? do
                        new_dynamics =
                          Enum.map(
                            aggregates,
                            &{&1.load, &1.name,
                             select_dynamic(
                               resource,
                               query,
                               &1,
                               query.__ash_bindings__.current - 1
                             )}
                          )

                        {:cont, {:ok, query, new_dynamics ++ dynamics}}
                      else
                        {:cont, {:ok, query, dynamics}}
                      end
                  end
              end
            end
          )

        case result do
          {:ok, query, dynamics} ->
            if select? do
              {:ok, add_aggregate_selects(query, dynamics)}
            else
              {:ok, query}
            end

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_subquery(
         _resource,
         aggregates,
         is_single?,
         nil,
         _relationship_path,
         _tmp_query,
         start_bindings_at,
         query,
         _source_binding,
         root_data_path,
         tenant,
         _join_filters
       ) do
    first_aggregate = Enum.at(aggregates, 0)
    aggregate_resource = first_aggregate.query.resource

    first_aggregate.query
    |> Ash.Query.set_context(%{
      data_layer: %{
        table: nil,
        parent_bindings:
          Map.put(
            query.__ash_bindings__,
            :refs_at_path,
            root_data_path
          ),
        start_bindings_at: start_bindings_at || 0
      }
    })
    |> Ash.Query.unset([:sort, :distinct, :select, :limit, :offset])
    |> AshSql.Join.handle_attribute_multitenancy(tenant)
    |> AshSql.Join.hydrate_refs(query.__ash_bindings__.context[:private][:actor])
    |> case do
      %{valid?: true} = related_query ->
        case Ash.Query.data_layer_query(related_query) do
          {:ok, ecto_query} ->
            {:ok, Ecto.Query.exclude(ecto_query, :select)}

          {:error, error} ->
            {:error, error}
        end

      %{errors: errors} ->
        {:error, errors}
    end
    |> case do
      {:ok, query} ->
        maybe_filter_subquery(
          query,
          nil,
          [],
          aggregates,
          is_single?,
          query.__ash_bindings__.root_binding
        )

      {:error, error} ->
        {:error, error}
    end
    |> case do
      {:error, error} ->
        {:error, error}

      {:ok, query} ->
        if is_single? and has_filter?(Enum.at(aggregates, 0).query) do
          AshSql.Filter.filter(
            query,
            Enum.at(aggregates, 0).query.filter,
            aggregate_resource
          )
        else
          {:ok, query}
        end
        |> case do
          {:error, error} ->
            {:error, error}

          {:ok, filtered} ->
            filtered =
              AshSql.Join.set_join_prefix(
                filtered,
                %{query | prefix: tenant},
                aggregate_resource
              )

            {:ok,
             select_all_aggregates(
               aggregates,
               filtered,
               [],
               query,
               is_single?,
               aggregate_resource,
               nil
             )}
        end
    end
  end

  defp get_subquery(
         resource,
         aggregates,
         is_single?,
         first_relationship,
         relationship_path,
         tmp_query,
         start_bindings_at,
         query,
         source_binding,
         root_data_path,
         tenant,
         join_filters
       ) do
    AshSql.Join.related_subquery(
      first_relationship,
      tmp_query,
      start_bindings_at: start_bindings_at,
      refs_at_path: root_data_path,
      skip_distinct_for_first_rel?: true,
      on_subquery: fn subquery ->
        base_binding = subquery.__ash_bindings__.root_binding
        current_binding = subquery.__ash_bindings__.current

        subquery =
          subquery
          |> Ecto.Query.exclude(:select)
          |> Ecto.Query.select(%{})

        subquery =
          if Map.get(first_relationship, :no_attributes?) do
            subquery
          else
            if first_relationship.type == :many_to_many do
              join_relationship_struct =
                Ash.Resource.Info.relationship(
                  first_relationship.source,
                  first_relationship.join_relationship
                )

              {:ok, through} =
                AshSql.Join.related_subquery(
                  join_relationship_struct,
                  query
                )

              field = first_relationship.source_attribute_on_join_resource

              subquery =
                from(sub in subquery,
                  join: through in ^through,
                  as: ^query.__ash_bindings__.current,
                  on:
                    field(
                      through,
                      ^first_relationship.destination_attribute_on_join_resource
                    ) ==
                      field(sub, ^first_relationship.destination_attribute),
                  select_merge: map(through, ^[field]),
                  group_by:
                    field(
                      through,
                      ^first_relationship.source_attribute_on_join_resource
                    ),
                  distinct:
                    field(
                      through,
                      ^first_relationship.source_attribute_on_join_resource
                    ),
                  where:
                    field(
                      parent_as(^source_binding),
                      ^first_relationship.source_attribute
                    ) ==
                      field(
                        through,
                        ^first_relationship.source_attribute_on_join_resource
                      )
                )

              AshSql.Join.set_join_prefix(
                subquery,
                %{query | prefix: tenant},
                first_relationship.destination
              )
            else
              field = first_relationship.destination_attribute

              if Map.get(first_relationship, :manual) do
                {module, opts} = first_relationship.manual

                from(row in subquery,
                  group_by: field(row, ^field),
                  select_merge: %{^field => field(row, ^field)}
                )

                subquery =
                  from(row in subquery, distinct: true)

                {:ok, subquery} =
                  apply(
                    module,
                    query.__ash_bindings__.sql_behaviour.manual_relationship_subquery_function(),
                    [
                      opts,
                      source_binding,
                      current_binding - 1,
                      subquery
                    ]
                  )

                AshSql.Join.set_join_prefix(
                  subquery,
                  %{query | prefix: tenant},
                  first_relationship.destination
                )
              else
                from(row in subquery,
                  group_by: field(row, ^field),
                  select_merge: %{^field => field(row, ^field)},
                  where:
                    field(
                      parent_as(^source_binding),
                      ^first_relationship.source_attribute
                    ) ==
                      field(
                        as(^base_binding),
                        ^first_relationship.destination_attribute
                      )
                )
              end
            end
          end

        subquery =
          AshSql.Join.set_join_prefix(
            subquery,
            %{query | prefix: tenant},
            first_relationship.destination
          )

        {:ok, subquery, _} =
          apply_first_relationship_join_filters(
            subquery,
            query,
            %AshSql.Expr.ExprInfo{},
            first_relationship,
            join_filters
          )

        subquery =
          set_in_group(
            subquery,
            query,
            resource
          )

        {:ok, joined} =
          join_all_relationships(
            subquery,
            aggregates,
            relationship_path,
            first_relationship,
            is_single?,
            join_filters
          )

        {:ok, filtered} =
          maybe_filter_subquery(
            joined,
            first_relationship,
            relationship_path,
            aggregates,
            is_single?,
            subquery.__ash_bindings__.root_binding
          )

        select_all_aggregates(
          aggregates,
          filtered,
          relationship_path,
          query,
          is_single?,
          Ash.Resource.Info.related(
            first_relationship.destination,
            relationship_path
          ),
          first_relationship
        )
      end
    )
  end

  defp set_in_group(%{__ash_bindings__: _} = query, _, _resource) do
    Map.update!(
      query,
      :__ash_bindings__,
      &Map.put(&1, :in_group?, true)
    )
  end

  defp set_in_group(%Ecto.SubQuery{} = subquery, query, resource) do
    subquery = from(row in subquery, [])

    subquery
    |> AshSql.Bindings.default_bindings(resource, query.__ash_bindings__.sql_behaviour)
    |> Map.update!(
      :__ash_bindings__,
      &Map.put(&1, :in_group?, true)
    )
  end

  defp set_in_group(other, query, resource) do
    from(row in other, as: ^0)
    |> AshSql.Bindings.default_bindings(resource, query.__ash_bindings__.sql_behaviour)
    |> Map.update!(
      :__ash_bindings__,
      &Map.put(&1, :in_group?, true)
    )
  end

  defp different_queries?(nil, nil), do: false
  defp different_queries?(nil, _), do: true
  defp different_queries?(_, nil), do: true

  defp different_queries?(query1, query2) do
    query1.filter != query2.filter && query1.sort != query2.sort
  end

  @doc false
  def extract_shared_filters(aggregates) do
    aggregates
    |> Enum.reduce_while({nil, []}, fn
      %{query: %{filter: filter}} = agg, {global_filters, aggs} when not is_nil(filter) ->
        and_statements =
          AshSql.Expr.split_statements(filter, :and)

        global_filters =
          if global_filters do
            Enum.filter(global_filters, &(&1 in and_statements))
          else
            and_statements
          end

        {:cont, {global_filters, [{agg, and_statements} | aggs]}}

      _, _ ->
        {:halt, {:error, aggregates}}
    end)
    |> case do
      {:error, aggregates} ->
        {:error, aggregates}

      {[], _} ->
        {:error, aggregates}

      {nil, _} ->
        {:error, aggregates}

      {global_filters, aggregates} ->
        global_filter = and_filters(Enum.uniq(global_filters))

        aggregates =
          Enum.map(aggregates, fn {agg, and_statements} ->
            applicable_and_statements =
              and_statements
              |> Enum.reject(&(&1 in global_filters))
              |> and_filters()

            %{agg | query: %{agg.query | filter: applicable_and_statements}}
          end)

        {{:ok, global_filter}, aggregates}
    end
  end

  defp and_filters(filters) do
    Enum.reduce(filters, nil, fn expr, acc ->
      if is_nil(acc) do
        expr
      else
        Ash.Query.BooleanExpression.new(:and, expr, acc)
      end
    end)
  end

  defp apply_first_relationship_join_filters(
         agg_root_query,
         query,
         acc,
         first_relationship,
         join_filters
       ) do
    case join_filters[[first_relationship]] do
      nil ->
        {:ok, agg_root_query, acc}

      filter ->
        with {:ok, agg_root_query} <-
               AshSql.Join.join_all_relationships(agg_root_query, filter) do
          agg_root_query =
            AshSql.Expr.set_parent_path(
              agg_root_query,
              query
            )

          {query, acc} =
            AshSql.Join.maybe_apply_filter(
              agg_root_query,
              agg_root_query,
              agg_root_query.__ash_bindings__,
              filter
            )

          {:ok, query, acc}
        end
    end
  end

  defp use_aggregate_name(query, aggregate_name) do
    {%{
       query
       | __ash_bindings__: %{
           query.__ash_bindings__
           | current_aggregate_name:
               next_aggregate_name(query.__ash_bindings__.current_aggregate_name),
             aggregate_names:
               Map.put(
                 query.__ash_bindings__.aggregate_names,
                 aggregate_name,
                 query.__ash_bindings__.current_aggregate_name
               )
         }
     }, query.__ash_bindings__.current_aggregate_name}
  end

  defp resource_aggregates_to_aggregates(resource, query, aggregates) do
    private_context = query.__ash_bindings__.context[:private]

    Enum.reduce_while(aggregates, {:ok, []}, fn
      %Ash.Query.Aggregate{} = aggregate, {:ok, aggregates} ->
        aggregate =
          Ash.Actions.Read.add_calc_context(
            aggregate,
            private_context[:actor],
            private_context[:authorize?],
            private_context[:tenant],
            private_context[:tracer],
            query.__ash_bindings__[:domain],
            query.__ash_bindings__[:resource],
            parent_stack: query.__ash_bindings__[:parent_resources] || []
          )

        {:cont, {:ok, [aggregate | aggregates]}}

      aggregate, {:ok, aggregates} ->
        related = Ash.Resource.Info.related(resource, aggregate.relationship_path)

        read_action =
          aggregate.read_action || Ash.Resource.Info.primary_action!(related, :read).name

        with %{valid?: true} = aggregate_query <- Ash.Query.for_read(related, read_action),
             %{valid?: true} = aggregate_query <-
               Ash.Query.build(aggregate_query, filter: aggregate.filter, sort: aggregate.sort) do
          Ash.Query.Aggregate.new(
            resource,
            aggregate.name,
            aggregate.kind,
            path: aggregate.relationship_path,
            query: aggregate_query,
            field: aggregate.field,
            default: aggregate.default,
            filterable?: aggregate.filterable?,
            type: aggregate.type,
            sortable?: aggregate.filterable?,
            include_nil?: aggregate.include_nil?,
            constraints: aggregate.constraints,
            implementation: aggregate.implementation,
            uniq?: aggregate.uniq?,
            read_action:
              aggregate.read_action ||
                Ash.Resource.Info.primary_action!(
                  Ash.Resource.Info.related(resource, aggregate.relationship_path),
                  :read
                ).name,
            authorize?: aggregate.authorize?
          )
        else
          %{errors: errors} ->
            {:error, errors}
        end
        |> case do
          {:ok, aggregate} ->
            aggregate =
              aggregate
              |> Map.put(:load, aggregate.name)
              |> Ash.Actions.Read.add_calc_context(
                private_context[:actor],
                private_context[:authorize?],
                private_context[:tenant],
                private_context[:tracer],
                query.__ash_bindings__[:domain],
                query.__ash_bindings__[:resource],
                parent_stack: query.__ash_bindings__[:parent_resources] || []
              )

            {:cont, {:ok, [aggregate | aggregates]}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
    end)
  end

  defp add_first_join_aggregate(
         query,
         _resource,
         %{related?: false} = aggregate,
         root_data,
         _,
         source_binding
       ) do
    path =
      case root_data do
        {_resource, path} ->
          path

        _ ->
          []
      end

    subquery_result =
      aggregate.query
      |> Ash.Query.set_context(%{
        data_layer: %{
          table: nil,
          parent_bindings:
            Map.put(
              query.__ash_bindings__,
              :refs_at_path,
              path
            ),
          start_bindings_at: (query.__ash_bindings__.current || 0) + 1
        }
      })
      |> Ash.Query.limit(1)
      |> Ash.Query.data_layer_query()

    case subquery_result do
      {:ok, ecto_query} ->
        ref =
          %Ash.Query.Ref{
            attribute: aggregate.field,
            resource: aggregate.query.resource
          }

        {:ok, ecto_query} = AshSql.Join.join_all_relationships(ecto_query, ref)

        ecto_query =
          case aggregate.field do
            %Ash.Query.Aggregate{} = aggregate ->
              {:ok, ecto_query} =
                add_aggregates(
                  ecto_query,
                  [aggregate],
                  aggregate.query.resource,
                  true,
                  source_binding,
                  root_data
                )

              ecto_query

            %Ash.Resource.Aggregate{} = aggregate ->
              {:ok, ecto_query} =
                add_aggregates(
                  ecto_query,
                  [aggregate],
                  Ash.Resource.Info.related(aggregate.resource, aggregate.relationship_path),
                  true,
                  source_binding,
                  root_data
                )

              ecto_query

            %Ash.Resource.Calculation{
              name: name,
              calculation: {module, opts},
              type: type,
              constraints: constraints
            } ->
              {:ok, new_calc} = Ash.Query.Calculation.new(name, module, opts, type, constraints)
              expression = module.expression(opts, new_calc.context)

              expression =
                Ash.Expr.fill_template(
                  expression,
                  actor: aggregate.context.actor,
                  tenant: aggregate.query.to_tenant,
                  args: %{},
                  context: aggregate.context
                )

              {:ok, expression} =
                Ash.Filter.hydrate_refs(expression, %{
                  resource: ecto_query.__ash_bindings__.resource,
                  public?: false
                })

              {:ok, ecto_query} =
                AshSql.Calculation.add_calculations(
                  ecto_query,
                  [{new_calc, expression}],
                  ecto_query.__ash_bindings__.resource,
                  source_binding,
                  true
                )

              ecto_query

            %Ash.Query.Calculation{
              module: module,
              opts: opts,
              context: context
            } = calc ->
              expression = module.expression(opts, context)

              expression =
                Ash.Expr.fill_template(
                  expression,
                  actor: context.actor,
                  tenant: aggregate.query.to_tenant,
                  args: context.arguments,
                  context: context.source_context
                )

              {:ok, expression} =
                Ash.Filter.hydrate_refs(expression, %{
                  resource: ecto_query.__ash_bindings__.resource,
                  public?: false
                })

              {:ok, ecto_query} =
                AshSql.Calculation.add_calculations(
                  ecto_query,
                  [{calc, expression}],
                  ecto_query.__ash_bindings__.resource,
                  source_binding,
                  true
                )

              ecto_query

            _ ->
              ecto_query
          end

        ref =
          %Ash.Query.Ref{
            attribute: aggregate_field(aggregate, aggregate.query.resource, query),
            relationship_path: [],
            resource: aggregate.query.resource
          }

        value =
          Ecto.Query.dynamic(field(as(^query.__ash_bindings__.current), ^ref.attribute.name))

        AshSql.Expr.dynamic_expr(query, ref, query.__ash_bindings__, false)

        query =
          if has_parent_expr?(aggregate.query.filter) do
            from(row in query,
              left_lateral_join: related in subquery(ecto_query),
              on: true,
              as: ^query.__ash_bindings__.current
            )
          else
            from(row in query,
              left_join: related in subquery(ecto_query),
              on: true,
              as: ^query.__ash_bindings__.current
            )
          end

        query =
          AshSql.Bindings.add_binding(
            query,
            %{
              path: path,
              type: :aggregate,
              aggregates: [aggregate]
            }
          )

        type =
          AshSql.Expr.parameterized_type(
            query.__ash_bindings__.sql_behaviour,
            aggregate.type,
            aggregate.constraints,
            :aggregate
          )

        with_default =
          if aggregate.default_value do
            if type do
              type_expr =
                query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

              Ecto.Query.dynamic(coalesce(^value, ^type_expr))
            else
              Ecto.Query.dynamic(coalesce(^value, ^aggregate.default_value))
            end
          else
            value
          end

        casted =
          if type do
            query.__ash_bindings__.sql_behaviour.type_expr(with_default, type)
          else
            with_default
          end

        {:ok, query, casted}

      {:error, error} ->
        {:error, error}
    end
  end

  defp add_first_join_aggregate(
         query,
         resource,
         aggregate,
         root_data,
         first_relationship,
         _source_binding
       ) do
    {resource, path} =
      case root_data do
        {resource, path} ->
          {resource, path}

        _ ->
          {resource, []}
      end

    join_filters =
      if has_filter?(aggregate) do
        %{(path ++ aggregate.relationship_path) => aggregate.query.filter}
      else
        %{}
      end

    case AshSql.Join.join_all_relationships(
           query,
           nil,
           [],
           [
             {:left,
              AshSql.Join.relationship_path_to_relationships(
                resource,
                path ++ aggregate.relationship_path
              )}
           ],
           [],
           nil,
           false,
           join_filters
         ) do
      {:ok, query} ->
        ref =
          aggregate_field_ref(
            aggregate,
            Ash.Resource.Info.related(resource, path ++ aggregate.relationship_path),
            path ++ aggregate.relationship_path,
            query,
            first_relationship
          )

        {:ok, query} = AshSql.Join.join_all_relationships(query, ref)

        {value, acc} = AshSql.Expr.dynamic_expr(query, ref, query.__ash_bindings__, false)

        type =
          AshSql.Expr.parameterized_type(
            query.__ash_bindings__.sql_behaviour,
            aggregate.type,
            aggregate.constraints,
            :aggregate
          )

        with_default =
          if aggregate.default_value do
            if type do
              type_expr =
                query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

              Ecto.Query.dynamic(coalesce(^value, ^type_expr))
            else
              Ecto.Query.dynamic(coalesce(^value, ^aggregate.default_value))
            end
          else
            value
          end

        casted =
          if type do
            query.__ash_bindings__.sql_behaviour.type_expr(with_default, type)
          else
            with_default
          end

        {:ok, AshSql.Bindings.merge_expr_accumulator(query, acc), casted}

      {:error, error} ->
        {:error, error}
    end
  end

  defp already_added?(aggregate, bindings, root_data_path) do
    Enum.any?(bindings.bindings, fn
      {_, %{type: :aggregate, aggregates: aggregates}, path: ^root_data_path} ->
        aggregate in aggregates

      _ ->
        false
    end)
  end

  defp maybe_filter_subquery(
         agg_query,
         first_relationship,
         relationship_path,
         aggregates,
         is_single?,
         source_binding
       ) do
    Enum.reduce_while(aggregates, {:ok, agg_query}, fn aggregate, {:ok, agg_query} ->
      filter =
        if !Enum.empty?(relationship_path) && aggregate.query.filter do
          Ash.Filter.move_to_relationship_path(
            aggregate.query.filter,
            relationship_path
          )
          |> Map.put(:resource, first_relationship.destination)
        else
          aggregate.query.filter
        end

      # For unrelated aggregates (first_relationship is nil), use the aggregate's resource
      # For related aggregates, use the relationship destination
      related =
        if first_relationship do
          first_relationship.destination
        else
          aggregate.query.resource
        end

      field =
        case aggregate.field do
          field when is_atom(field) ->
            Ash.Resource.Info.field(related, field)

          field ->
            field
        end

      root_data =
        case first_relationship do
          nil ->
            nil

          %{destination: destination, name: name} ->
            {destination, [name]}
        end

      agg_query =
        case field do
          %Ash.Query.Aggregate{} = aggregate ->
            {:ok, agg_query} =
              add_aggregates(agg_query, [aggregate], related, false, source_binding, root_data)

            agg_query

          %Ash.Resource.Aggregate{} = aggregate ->
            {:ok, agg_query} =
              add_aggregates(agg_query, [aggregate], related, false, source_binding, root_data)

            agg_query

          %Ash.Resource.Calculation{
            name: name,
            calculation: {module, opts},
            type: type,
            constraints: constraints
          } ->
            {:ok, new_calc} = Ash.Query.Calculation.new(name, module, opts, type, constraints)
            expression = module.expression(opts, new_calc.context)

            expression =
              Ash.Expr.fill_template(
                expression,
                actor: aggregate.context.actor,
                tenant: aggregate.query.to_tenant,
                args: %{},
                context: aggregate.context
              )

            expression =
              if Enum.empty?(relationship_path) do
                expression
              else
                Ash.Filter.move_to_relationship_path(
                  expression,
                  relationship_path
                )
              end

            {:ok, expression} =
              Ash.Filter.hydrate_refs(expression, %{
                resource: agg_query.__ash_bindings__.resource,
                public?: false
              })

            {:ok, agg_query} =
              AshSql.Calculation.add_calculations(
                agg_query,
                [{new_calc, expression}],
                agg_query.__ash_bindings__.resource,
                source_binding,
                false
              )

            agg_query

          %Ash.Query.Calculation{
            module: module,
            opts: opts,
            context: context
          } = calc ->
            expression = module.expression(opts, context)

            expression =
              Ash.Expr.fill_template(
                expression,
                actor: context.actor,
                tenant: aggregate.query.to_tenant,
                args: context.arguments,
                context: context.source_context
              )

            expression =
              if Enum.empty?(relationship_path) do
                expression
              else
                Ash.Filter.move_to_relationship_path(
                  expression,
                  relationship_path
                )
              end

            {:ok, expression} =
              Ash.Filter.hydrate_refs(expression, %{
                resource: agg_query.__ash_bindings__.resource,
                public?: false
              })

            {:ok, agg_query} =
              AshSql.Calculation.add_calculations(
                agg_query,
                [{calc, expression}],
                agg_query.__ash_bindings__.resource,
                source_binding,
                false
              )

            agg_query

          _ ->
            agg_query
        end

      if has_filter?(aggregate.query) && is_single? do
        {:cont, AshSql.Filter.filter(agg_query, filter, agg_query.__ash_bindings__.resource)}
      else
        {:cont, {:ok, agg_query}}
      end
    end)
  end

  defp join_subquery(
         query,
         subquery,
         nil,
         _relationship_path,
         aggregates,
         _source_binding,
         root_data_path
       ) do
    query =
      from(row in query,
        left_lateral_join: sub in subquery(subquery),
        as: ^query.__ash_bindings__.current,
        on: true
      )

    AshSql.Bindings.add_binding(
      query,
      %{
        path: root_data_path,
        type: :aggregate,
        aggregates: aggregates
      }
    )
  end

  defp join_subquery(
         query,
         subquery,
         %{manual: {_, _}},
         _relationship_path,
         aggregates,
         _source_binding,
         root_data_path
       ) do
    query =
      from(row in query,
        left_lateral_join: sub in ^subquery,
        as: ^query.__ash_bindings__.current,
        on: true
      )

    AshSql.Bindings.add_binding(
      query,
      %{
        path: root_data_path,
        type: :aggregate,
        aggregates: aggregates
      }
    )
  end

  defp join_subquery(
         query,
         subquery,
         %{type: :many_to_many},
         _relationship_path,
         aggregates,
         _source_binding,
         root_data_path
       ) do
    query =
      from(row in query,
        left_lateral_join: agg in ^subquery,
        as: ^query.__ash_bindings__.current,
        on: true
      )

    query
    |> AshSql.Bindings.add_binding(%{
      path: root_data_path,
      type: :aggregate,
      aggregates: aggregates
    })
    |> AshSql.Bindings.merge_expr_accumulator(%AshSql.Expr.ExprInfo{})
  end

  defp join_subquery(
         query,
         subquery,
         _first_relationship,
         _relationship_path,
         aggregates,
         _source_binding,
         root_data_path
       ) do
    query =
      from(row in query,
        left_lateral_join: agg in ^subquery,
        as: ^query.__ash_bindings__.current,
        on: true
      )

    AshSql.Bindings.add_binding(
      query,
      %{
        path: root_data_path,
        type: :aggregate,
        aggregates: aggregates
      }
    )
  end

  def next_aggregate_name(i) do
    @next_aggregate_names[i] ||
      raise Ash.Error.Framework.AssumptionFailed,
        message: """
        All 1000 static names for aggregates have been used in a single query.
        Congratulations, this means that you have gone so wildly beyond our imagination
        of how much can fit into a single quer. Please file an issue and we will raise the limit.
        """
  end

  defp select_all_aggregates(
         aggregates,
         joined,
         relationship_path,
         _query,
         is_single?,
         resource,
         first_relationship
       ) do
    Enum.reduce(aggregates, joined, fn aggregate, joined ->
      add_subquery_aggregate_select(
        joined,
        relationship_path,
        aggregate,
        resource,
        is_single?,
        first_relationship
      )
    end)
  end

  defp join_all_relationships(
         agg_root_query,
         _aggregates,
         relationship_path,
         first_relationship,
         _is_single?,
         join_filters
       ) do
    if Enum.empty?(relationship_path) do
      {:ok, agg_root_query}
    else
      join_filters =
        Enum.reduce(join_filters, %{}, fn {key, value}, acc ->
          if List.starts_with?(key, [first_relationship.name]) do
            Map.put(acc, Enum.drop(key, 1), value)
          else
            acc
          end
        end)

      AshSql.Join.join_all_relationships(
        agg_root_query,
        Map.values(join_filters),
        [],
        [
          {:inner,
           AshSql.Join.relationship_path_to_relationships(
             first_relationship.destination,
             relationship_path
           )}
        ],
        [],
        nil,
        false,
        join_filters,
        agg_root_query
      )
    end
  end

  @doc false
  def can_group?(_, %{kind: :exists}, _), do: false
  def can_group?(_, %{kind: :list}, _), do: false

  def can_group?(resource, aggregate, query) do
    can_group_kind?(aggregate, resource, query) && !has_exists?(aggregate) &&
      !references_to_many_relationships?(aggregate) &&
      !optimizable_first_aggregate?(resource, aggregate, query) &&
      !has_parent_expr?(aggregate.query.filter)
  end

  defp has_parent_expr?(filter, depth \\ 0) do
    not is_nil(
      Ash.Filter.find(
        filter,
        fn
          %Ash.Query.Call{name: :parent, args: [expr]} ->
            if depth == 0 do
              true
            else
              has_parent_expr?(expr, depth - 1)
            end

          %Ash.Query.Exists{expr: expr} ->
            has_parent_expr?(expr, depth + 1)

          %Ash.Query.Parent{expr: expr} ->
            if depth == 0 do
              true
            else
              has_parent_expr?(expr, depth - 1)
            end

          %Ash.Query.Ref{
            attribute: %Ash.Query.Aggregate{
              field: %Ash.Query.Calculation{module: module, opts: opts, context: context}
            }
          } ->
            if module.has_expression?() do
              module.expression(opts, context)
              |> has_parent_expr?(depth + 1)
            else
              false
            end

          _other ->
            false
        end,
        true,
        true,
        true
      )
    )
  end

  # We can potentially optimize this. We don't have to prevent aggregates that reference
  # relationships from joining, we can
  # 1. group up the ones that do join relationships by the relationships they join
  # 2. potentially group them all up that join to relationships and just join to all the relationships
  # but this method is predictable and easy so we're starting by just not grouping them
  defp references_to_many_relationships?(aggregate) do
    if aggregate.query do
      aggregate.query.filter
      |> Ash.Filter.relationship_paths()
      |> Enum.any?(&to_many_path?(aggregate.query.resource, &1))
    else
      false
    end
  end

  defp to_many_path?(_resource, []), do: false

  defp to_many_path?(resource, [rel | rest]) do
    case Ash.Resource.Info.relationship(resource, rel) do
      %{cardinality: :many} ->
        true

      nil ->
        raise """
        No such relationship #{inspect(resource)}.#{rel}
        """

      rel ->
        to_many_path?(rel.destination, rest)
    end
  end

  defp can_group_kind?(aggregate, resource, query) do
    if aggregate.kind == :first do
      if array_type?(resource, aggregate) ||
           optimizable_first_aggregate?(resource, aggregate, query) do
        false
      else
        true
      end
    else
      true
    end
  end

  @doc false
  def optimizable_first_aggregate?(
        resource,
        %{
          kind: :first,
          relationship_path: relationship_path,
          join_filters: join_filters,
          field: %Ash.Query.Calculation{} = field
        },
        _
      ) do
    ref =
      %Ash.Query.Ref{
        attribute: field,
        relationship_path: relationship_path,
        resource: resource
      }

    with true <- join_filters == %{},
         [] <- Ash.Filter.used_aggregates(ref, :all),
         [] <- Ash.Filter.relationship_paths(ref) do
      true
    else
      _ ->
        false
    end
  end

  def optimizable_first_aggregate?(
        _resource,
        %{
          kind: :first,
          field: %Ash.Query.Aggregate{}
        },
        _
      ) do
    false
  end

  def optimizable_first_aggregate?(
        resource,
        %{
          name: name,
          kind: :first,
          relationship_path: relationship_path,
          join_filters: join_filters,
          query: %{resource: related},
          field: field
        } = aggregate,
        query
      ) do
    related
    |> Ash.Resource.Info.field(field)
    |> case do
      %Ash.Resource.Aggregate{} ->
        false

      %Ash.Resource.Calculation{} ->
        field = aggregate_field(aggregate, resource, query)

        ref =
          %Ash.Query.Ref{
            attribute: field,
            relationship_path: relationship_path,
            resource: resource
          }

        with [] <- Ash.Filter.used_aggregates(ref, :all),
             [] <- Ash.Filter.relationship_paths(ref) do
          true
        else
          _ ->
            false
        end

      nil ->
        false

      _ ->
        name in query.__ash_bindings__.sql_behaviour.simple_join_first_aggregates(resource) ||
          (join_filters in [nil, %{}, []] &&
             single_path?(resource, relationship_path))
    end
  end

  def optimizable_first_aggregate?(_, _, _), do: false

  defp array_type?(resource, aggregate) do
    related = Ash.Resource.Info.related(resource, aggregate.relationship_path)

    case aggregate.field do
      nil ->
        false

      %{type: {:array, _}} ->
        true

      type when is_atom(type) ->
        case Ash.Resource.Info.field(related, aggregate.field).type do
          {:array, _} ->
            true

          _ ->
            false
        end

      _ ->
        false
    end
  end

  defp has_exists?(aggregate) do
    !!Ash.Filter.find(aggregate.query && aggregate.query.filter, fn
      %Ash.Query.Exists{} -> true
      _ -> false
    end)
  end

  defp add_aggregate_selects(query, dynamics) do
    {in_aggregates, in_body} =
      Enum.split_with(dynamics, fn {load, _name, _dynamic} -> is_nil(load) end)

    aggs =
      in_body
      |> Map.new(fn {load, _, dynamic} ->
        {load, dynamic}
      end)

    aggs =
      if Enum.empty?(in_aggregates) do
        aggs
      else
        Map.put(
          aggs,
          :aggregates,
          Map.new(in_aggregates, fn {_, name, dynamic} ->
            {name, dynamic}
          end)
        )
      end

    Ecto.Query.select_merge(query, ^aggs)
  end

  defp select_dynamic(_resource, query, aggregate, binding) do
    type =
      AshSql.Expr.parameterized_type(
        query.__ash_bindings__.sql_behaviour,
        aggregate.type,
        aggregate.constraints,
        :aggregate
      )

    field =
      if type do
        field_ref = Ecto.Query.dynamic(field(as(^binding), ^aggregate.name))
        query.__ash_bindings__.sql_behaviour.type_expr(field_ref, type)
      else
        Ecto.Query.dynamic(field(as(^binding), ^aggregate.name))
      end

    coalesced =
      if is_nil(aggregate.default_value) do
        field
      else
        if type do
          typed_default =
            query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

          Ecto.Query.dynamic(
            coalesce(
              ^field,
              ^typed_default
            )
          )
        else
          Ecto.Query.dynamic(
            coalesce(
              ^field,
              ^aggregate.default_value
            )
          )
        end
      end

    if type do
      query.__ash_bindings__.sql_behaviour.type_expr(coalesced, type)
    else
      coalesced
    end
  end

  defp has_filter?(nil), do: false
  defp has_filter?(%{filter: nil}), do: false
  defp has_filter?(%{filter: %Ash.Filter{expression: nil}}), do: false
  defp has_filter?(_), do: true

  defp has_sort?(nil), do: false
  defp has_sort?(%{sort: nil}), do: false
  defp has_sort?(%{sort: []}), do: false
  defp has_sort?(%{sort: _}), do: true
  defp has_sort?(_), do: false

  def add_subquery_aggregate_select(
        query,
        relationship_path,
        %{kind: :first} = aggregate,
        resource,
        is_single?,
        first_relationship
      ) do
    ref =
      aggregate_field_ref(
        aggregate,
        resource,
        relationship_path,
        query,
        first_relationship
      )

    type =
      AshSql.Expr.parameterized_type(
        query.__ash_bindings__.sql_behaviour,
        aggregate.type,
        aggregate.constraints,
        :aggregate
      )

    binding =
      AshSql.Bindings.get_binding(
        query.__ash_bindings__.resource,
        relationship_path,
        query,
        [:left, :inner, :root]
      )

    {field, acc} = AshSql.Expr.dynamic_expr(query, ref, query.__ash_bindings__, false)

    has_sort? = has_sort?(aggregate.query)

    array_agg =
      query.__ash_bindings__.sql_behaviour.list_aggregate(aggregate.query.resource)

    {sorted, include_nil_filter_field, query} =
      if has_sort? || first_relationship.sort not in [nil, []] do
        {sort, binding} =
          if has_sort? do
            {aggregate.query.sort, binding}
          else
            {List.wrap(first_relationship.sort), query.__ash_bindings__.root_binding}
          end

        {:ok, sort_expr, query} =
          AshSql.Sort.sort(
            query,
            sort,
            Ash.Resource.Info.related(
              query.__ash_bindings__.resource,
              relationship_path
            ),
            relationship_path,
            binding,
            :return
          )

        if aggregate.include_nil? do
          question_marks = Enum.map(sort_expr, fn _ -> " ? " end)

          {:ok, expr} =
            Ash.Query.Function.Fragment.casted_new(
              ["#{array_agg}(? ORDER BY #{question_marks})", field] ++ sort_expr
            )

          {sort_expr, acc} =
            AshSql.Expr.dynamic_expr(query, expr, query.__ash_bindings__, false)

          query =
            AshSql.Bindings.merge_expr_accumulator(query, acc)

          {sort_expr, nil, query}
        else
          question_marks = Enum.map(sort_expr, fn _ -> " ? " end)

          {expr, include_nil_filter_field} =
            if has_filter?(aggregate.query) and !is_single? do
              {:ok, expr} =
                Ash.Query.Function.Fragment.casted_new(
                  [
                    "#{array_agg}(? ORDER BY #{question_marks})",
                    field
                  ] ++
                    sort_expr
                )

              {expr, field}
            else
              {:ok, expr} =
                Ash.Query.Function.Fragment.casted_new(
                  [
                    "#{array_agg}(? ORDER BY #{question_marks}) FILTER (WHERE ? IS NOT NULL)",
                    field
                  ] ++
                    sort_expr ++ [field]
                )

              {expr, nil}
            end

          {sort_expr, acc} =
            AshSql.Expr.dynamic_expr(query, expr, query.__ash_bindings__, false)

          query =
            AshSql.Bindings.merge_expr_accumulator(query, acc)

          {sort_expr, include_nil_filter_field, query}
        end
      else
        case array_agg do
          "array_agg" ->
            {Ecto.Query.dynamic(
               [row],
               fragment("array_agg(?)", ^field)
             ), nil, query}

          "any_value" ->
            {Ecto.Query.dynamic(
               [row],
               fragment("any_value(?)", ^field)
             ), nil, query}
        end
      end

    {query, filtered} =
      filter_field(
        sorted,
        include_nil_filter_field,
        query,
        aggregate,
        relationship_path,
        is_single?
      )

    value =
      if array_agg == "array_agg" do
        Ecto.Query.dynamic(fragment("(?)[1]", ^filtered))
      else
        filtered
      end

    with_default =
      if aggregate.default_value do
        if type do
          typed_default =
            query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

          Ecto.Query.dynamic(coalesce(^value, ^typed_default))
        else
          Ecto.Query.dynamic(coalesce(^value, ^aggregate.default_value))
        end
      else
        value
      end

    casted =
      if type do
        query.__ash_bindings__.sql_behaviour.type_expr(with_default, type)
      else
        with_default
      end

    query = AshSql.Bindings.merge_expr_accumulator(query, acc)

    select_or_merge(
      query,
      aggregate.name,
      casted
    )
  end

  def add_subquery_aggregate_select(
        query,
        relationship_path,
        %{kind: :list} = aggregate,
        resource,
        is_single?,
        first_relationship
      ) do
    type =
      AshSql.Expr.parameterized_type(
        query.__ash_bindings__.sql_behaviour,
        aggregate.type,
        aggregate.constraints,
        :aggregate
      )

    binding =
      AshSql.Bindings.get_binding(
        query.__ash_bindings__.resource,
        relationship_path,
        query,
        [:left, :inner, :root]
      )

    ref =
      aggregate_field_ref(
        aggregate,
        resource,
        relationship_path,
        query,
        first_relationship
      )

    {field, acc} =
      AshSql.Expr.dynamic_expr(
        query,
        ref,
        Map.put(query.__ash_bindings__, :location, :aggregate),
        false
      )

    related =
      Ash.Resource.Info.related(
        query.__ash_bindings__.resource,
        relationship_path
      )

    has_sort? = has_sort?(aggregate.query)

    {sorted, include_nil_filter_field, query} =
      if has_sort? || (first_relationship && first_relationship.sort not in [nil, []]) do
        {sort, binding} =
          if has_sort? do
            {aggregate.query.sort, binding}
          else
            {List.wrap(first_relationship.sort), query.__ash_bindings__.root_binding}
          end

        {:ok, sort_expr, query} =
          AshSql.Sort.sort(
            query,
            sort,
            related,
            relationship_path,
            binding,
            :return
          )

        question_marks = Enum.map(sort_expr, fn _ -> " ? " end)

        distinct =
          if Map.get(aggregate, :uniq?) do
            "DISTINCT "
          else
            ""
          end

        {expr, include_nil_filter_field} =
          if aggregate.include_nil? do
            {:ok, expr} =
              Ash.Query.Function.Fragment.casted_new(
                ["array_agg(#{distinct}? ORDER BY #{question_marks})", field] ++ sort_expr
              )

            {expr, nil}
          else
            if has_filter?(aggregate.query) and !is_single? do
              {:ok, expr} =
                Ash.Query.Function.Fragment.casted_new(
                  [
                    "array_agg(#{distinct}? ORDER BY #{question_marks})",
                    field
                  ] ++
                    sort_expr ++ [field]
                )

              {expr, field}
            else
              {:ok, expr} =
                Ash.Query.Function.Fragment.casted_new(
                  [
                    "array_agg(#{distinct}? ORDER BY #{question_marks}) FILTER (WHERE ? IS NOT NULL)",
                    field
                  ] ++
                    sort_expr ++ [field]
                )

              {expr, nil}
            end
          end

        {expr, acc} =
          AshSql.Expr.dynamic_expr(query, expr, query.__ash_bindings__, false)

        query =
          AshSql.Bindings.merge_expr_accumulator(query, acc)

        {expr, include_nil_filter_field, query}
      else
        if Map.get(aggregate, :uniq?) do
          {Ecto.Query.dynamic(
             [row],
             fragment("array_agg(DISTINCT ?)", ^field)
           ), nil, query}
        else
          {Ecto.Query.dynamic(
             [row],
             fragment("array_agg(?)", ^field)
           ), nil, query}
        end
      end

    {query, filtered} =
      filter_field(
        sorted,
        include_nil_filter_field,
        query,
        aggregate,
        relationship_path,
        is_single?
      )

    with_default =
      if aggregate.default_value do
        if type do
          typed_default =
            query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

          Ecto.Query.dynamic(coalesce(^filtered, ^typed_default))
        else
          Ecto.Query.dynamic(coalesce(^filtered, ^aggregate.default_value))
        end
      else
        filtered
      end

    cast =
      if type do
        query.__ash_bindings__.sql_behaviour.type_expr(with_default, type)
      else
        with_default
      end

    query = AshSql.Bindings.merge_expr_accumulator(query, acc)

    select_or_merge(
      query,
      aggregate.name,
      cast
    )
  end

  def add_subquery_aggregate_select(
        query,
        relationship_path,
        %{kind: kind} = aggregate,
        resource,
        is_single?,
        first_relationship
      )
      when kind in [:count, :sum, :avg, :max, :min, :custom] do
    ref =
      aggregate_field_ref(
        aggregate,
        resource,
        relationship_path,
        query,
        first_relationship
      )

    {field, query} =
      case kind do
        :custom ->
          # we won't use this if its custom so don't try to make one
          {nil, query}

        :count ->
          if aggregate.field do
            {expr, acc} = AshSql.Expr.dynamic_expr(query, ref, query.__ash_bindings__, false)

            {expr, AshSql.Bindings.merge_expr_accumulator(query, acc)}
          else
            {nil, query}
          end

        _ ->
          {expr, acc} = AshSql.Expr.dynamic_expr(query, ref, query.__ash_bindings__, false)

          {expr, AshSql.Bindings.merge_expr_accumulator(query, acc)}
      end

    type =
      AshSql.Expr.parameterized_type(
        query.__ash_bindings__.sql_behaviour,
        aggregate.type,
        aggregate.constraints,
        :aggregate
      )

    binding =
      AshSql.Bindings.get_binding(
        query.__ash_bindings__.resource,
        relationship_path,
        query,
        [:left, :inner, :root]
      )

    field =
      case kind do
        :count ->
          cond do
            !aggregate.field ->
              Ecto.Query.dynamic([row], count())

            Map.get(aggregate, :uniq?) ->
              Ecto.Query.dynamic([row], count(^field, :distinct))

            match?(%{attribute: %{allow_nil?: false}}, ref) ->
              Ecto.Query.dynamic([row], count())

            true ->
              Ecto.Query.dynamic([row], count(^field))
          end

        :sum ->
          Ecto.Query.dynamic([row], sum(^field))

        :avg ->
          Ecto.Query.dynamic([row], avg(^field))

        :max ->
          Ecto.Query.dynamic([row], max(^field))

        :min ->
          Ecto.Query.dynamic([row], min(^field))

        :custom ->
          {module, opts} = aggregate.implementation

          module.dynamic(opts, binding)
      end

    {query, filtered} = filter_field(field, nil, query, aggregate, relationship_path, is_single?)

    with_default =
      if aggregate.default_value do
        if type do
          typed_default =
            query.__ash_bindings__.sql_behaviour.type_expr(aggregate.default_value, type)

          Ecto.Query.dynamic(coalesce(^filtered, ^typed_default))
        else
          Ecto.Query.dynamic(coalesce(^filtered, ^aggregate.default_value))
        end
      else
        filtered
      end

    cast =
      if type do
        query.__ash_bindings__.sql_behaviour.type_expr(with_default, type)
      else
        with_default
      end

    select_or_merge(query, aggregate.name, cast)
  end

  defp filter_field(field, include_nil_filter_field, query, _aggregate, _relationship_path, true) do
    if include_nil_filter_field do
      {query, Ecto.Query.dynamic(filter(^field, not is_nil(^include_nil_filter_field)))}
    else
      {query, field}
    end
  end

  defp filter_field(
         field,
         include_nil_filter_field,
         query,
         aggregate,
         relationship_path,
         _is_single?
       ) do
    if has_filter?(aggregate.query) do
      filter =
        Ash.Filter.move_to_relationship_path(
          aggregate.query.filter,
          relationship_path
        )

      used_aggregates = Ash.Filter.used_aggregates(filter, [])

      # here we bypass an inner join.
      # Really, we should check if all aggs in a group
      # could do the same inner join, then do an inner join
      {:ok, query} =
        AshSql.Join.join_all_relationships(
          query,
          filter,
          [],
          nil,
          [],
          nil,
          true,
          nil,
          nil,
          true
        )

      {:ok, query} =
        add_aggregates(
          query,
          used_aggregates,
          query.__ash_bindings__.resource,
          false,
          query.__ash_bindings__.root_binding
        )

      {expr, acc} =
        AshSql.Expr.dynamic_expr(
          query,
          filter,
          query.__ash_bindings__,
          false,
          {aggregate.type, aggregate.constraints}
        )

      if include_nil_filter_field do
        {AshSql.Bindings.merge_expr_accumulator(query, acc),
         Ecto.Query.dynamic(filter(^field, ^expr and not is_nil(^include_nil_filter_field)))}
      else
        {AshSql.Bindings.merge_expr_accumulator(query, acc),
         Ecto.Query.dynamic(filter(^field, ^expr))}
      end
    else
      if include_nil_filter_field do
        {query, Ecto.Query.dynamic(filter(^field, not is_nil(^include_nil_filter_field)))}
      else
        {query, field}
      end
    end
  end

  defp select_or_merge(query, aggregate_name, casted) do
    query =
      if query.select do
        query
      else
        Ecto.Query.select(query, %{})
      end

    Ecto.Query.select_merge(query, ^%{aggregate_name => casted})
  end

  def aggregate_field_ref(aggregate, resource, relationship_path, query, first_relationship) do
    if aggregate.kind == :count && !aggregate.field do
      nil
    else
      %Ash.Query.Ref{
        attribute: aggregate_field(aggregate, resource, query),
        relationship_path: relationship_path,
        resource: query.__ash_bindings__.resource
      }
      |> case do
        %{attribute: %Ash.Resource.Aggregate{}} = ref when not is_nil(first_relationship) ->
          if first_relationship do
            %{ref | relationship_path: [first_relationship.name | ref.relationship_path]}
          else
            ref
          end

        %{attribute: %Ash.Query.Aggregate{}} = ref when not is_nil(first_relationship) ->
          if first_relationship do
            %{ref | relationship_path: [first_relationship.name | ref.relationship_path]}
          else
            ref
          end

        other ->
          other
      end
    end
  end

  defp single_path?(_, []), do: true

  defp single_path?(resource, [relationship | rest]) do
    relationship = Ash.Resource.Info.relationship(resource, relationship)

    !Map.get(relationship, :from_many?) &&
      (relationship.type == :belongs_to ||
         has_one_with_identity?(relationship)) &&
      single_path?(relationship.destination, rest)
  end

  defp has_one_with_identity?(%{type: :has_one, from_many?: false} = relationship) do
    Ash.Resource.Info.primary_key(relationship.destination) == [
      relationship.destination_attribute
    ] ||
      relationship.destination
      |> Ash.Resource.Info.identities()
      |> Enum.any?(fn %{keys: keys} ->
        keys == [relationship.destination_attribute]
      end)
  end

  defp has_one_with_identity?(_), do: false

  @doc false
  def aggregate_field(aggregate, resource, query) do
    if is_atom(aggregate.field) do
      case Ash.Resource.Info.field(
             resource,
             aggregate.field || List.first(Ash.Resource.Info.primary_key(resource))
           ) do
        %Ash.Resource.Calculation{calculation: {module, opts}} = calculation ->
          calc_type =
            AshSql.Expr.parameterized_type(
              query.__ash_bindings__.sql_behaviour,
              calculation.type,
              Map.get(calculation, :constraints, []),
              :calculation
            )

          AshSql.Expr.validate_type!(query, calc_type, "#{inspect(calculation.name)}")

          {:ok, query_calc} =
            Ash.Query.Calculation.new(
              calculation.name,
              module,
              opts,
              calculation.type,
              calculation.constraints
            )

          Ash.Actions.Read.add_calc_context(
            query_calc,
            aggregate.context.actor,
            aggregate.context.authorize?,
            aggregate.context.tenant,
            aggregate.context.tracer,
            query.__ash_bindings__[:domain],
            aggregate.query.resource,
            parent_stack: [
              query.__ash_bindings__.resource | query.__ash_bindings__[:parent_resources] || []
            ]
          )

        nil ->
          raise "no such aggregate field: #{inspect(resource)}.#{aggregate.field}"

        other ->
          other
      end
    else
      aggregate.field
    end
  end
end
