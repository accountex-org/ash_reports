defmodule AshSql.Sort do
  @moduledoc false
  require Ecto.Query

  def sort(
        query,
        sort,
        resource,
        relationship_path \\ [],
        binding \\ 0,
        type \\ :window
      ) do
    sort =
      Enum.map(sort, fn
        {key, val} when is_atom(key) ->
          case Ash.Resource.Info.field(resource, key) do
            %Ash.Resource.Calculation{calculation: {module, opts}} = calculation ->
              {:ok, calculation} =
                Ash.Query.Calculation.new(
                  calculation.name,
                  module,
                  opts,
                  calculation.type,
                  calculation.constraints
                )

              calculation =
                Ash.Actions.Read.add_calc_context(
                  calculation,
                  query.__ash_bindings__.context[:private][:actor],
                  query.__ash_bindings__.context[:private][:authorize?],
                  query.__ash_bindings__.context[:private][:tenant],
                  query.__ash_bindings__.context[:private][:tracer],
                  query.__ash_bindings__.context[:private][:domain],
                  query.__ash_bindings__.context[:private][:resource],
                  parent_stack: query.__ash_bindings__[:parent_resources] || []
                )

              {calculation, val}

            %Ash.Resource.Aggregate{} = aggregate ->
              related = Ash.Resource.Info.related(resource, aggregate.relationship_path)

              read_action =
                aggregate.read_action ||
                  Ash.Resource.Info.primary_action!(
                    related,
                    :read
                  ).name

              with %{valid?: true} = aggregate_query <- Ash.Query.for_read(related, read_action),
                   %{valid?: true} = aggregate_query <-
                     Ash.Query.build(aggregate_query,
                       filter: aggregate.filter,
                       sort: aggregate.sort
                     ) do
                case Ash.Query.Aggregate.new(
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
                     ) do
                  {:ok, agg} ->
                    {agg, val}

                  {:error, error} ->
                    raise Ash.Error.to_ash_error(error)
                end
              else
                %{errors: errors} -> raise Ash.Error.to_ash_error(errors)
              end

            _ ->
              {key, val}
          end

        {key, val} ->
          {key, val}
      end)

    used_aggregates =
      Enum.flat_map(sort, fn
        {%Ash.Query.Calculation{} = calculation, _} ->
          case Ash.Filter.hydrate_refs(
                 calculation.module.expression(calculation.opts, calculation.context),
                 %{
                   resource: resource,
                   aggregates: %{},
                   parent_stack: query.__ash_bindings__[:parent_resources] || [],
                   calculations: %{},
                   public?: false
                 }
               ) do
            {:ok, hydrated} ->
              Ash.Filter.used_aggregates(hydrated)

            _ ->
              []
          end

        {%Ash.Query.Aggregate{} = aggregate, _} ->
          [aggregate]

        {key, _} ->
          case Ash.Resource.Info.aggregate(resource, key) do
            nil ->
              []

            aggregate ->
              [aggregate]
          end

        _ ->
          []
      end)

    calcs =
      Enum.flat_map(sort, fn
        {%Ash.Query.Calculation{} = calculation, _} ->
          {:ok, expression} =
            calculation.opts
            |> calculation.module.expression(calculation.context)
            |> Ash.Filter.hydrate_refs(%{
              resource: resource,
              parent_stack: query.__ash_bindings__[:parent_resources] || [],
              public?: false
            })

          [{calculation, Ash.Filter.move_to_relationship_path(expression, relationship_path)}]

        _ ->
          []
      end)

    {:ok, query} =
      AshSql.Join.join_all_relationships(
        query,
        %Ash.Filter{
          resource: resource,
          expression: Enum.map(calcs, &elem(&1, 1))
        },
        left_only?: true
      )

    case AshSql.Aggregate.add_aggregates(query, used_aggregates, resource, false, 0) do
      {:error, error} ->
        {:error, error}

      {:ok, query} ->
        sort
        |> sanitize_sort()
        |> Enum.reduce_while({:ok, [], query}, fn
          {order, %Ash.Query.Aggregate{} = agg}, {:ok, query_expr, query} ->
            type =
              if agg.type do
                AshSql.Expr.parameterized_type(
                  query.__ash_bindings__.sql_behaviour,
                  agg.type,
                  agg.constraints,
                  :sort
                )
              else
                nil
              end

            expr =
              %Ash.Query.Ref{
                attribute: agg,
                resource: resource,
                relationship_path: relationship_path
              }

            bindings = query.__ash_bindings__

            {expr, acc} =
              AshSql.Expr.dynamic_expr(
                query,
                expr,
                bindings,
                false,
                type
              )

            {:cont,
             {:ok, query_expr ++ [{order, expr}],
              AshSql.Bindings.merge_expr_accumulator(query, acc)}}

          {order, %Ash.Query.Calculation{} = calc}, {:ok, query_expr, query} ->
            type =
              if calc.type do
                AshSql.Expr.parameterized_type(
                  query.__ash_bindings__.sql_behaviour,
                  calc.type,
                  calc.constraints,
                  :sort
                )
              else
                nil
              end

            calc.opts
            |> calc.module.expression(calc.context)
            |> Ash.Filter.hydrate_refs(%{
              resource: resource,
              parent_stack: query.__ash_bindings__[:parent_resources] || [],
              public?: false
            })
            |> Ash.Filter.move_to_relationship_path(relationship_path)
            |> case do
              {:ok, expr} ->
                bindings = query.__ash_bindings__

                {expr, acc} =
                  AshSql.Expr.dynamic_expr(
                    query,
                    expr,
                    bindings,
                    false,
                    type
                  )

                {:cont,
                 {:ok, query_expr ++ [{order, expr}],
                  AshSql.Bindings.merge_expr_accumulator(query, acc)}}

              {:error, error} ->
                {:halt, {:error, error}}
            end

          {order, sort}, {:ok, query_expr, query} ->
            expr =
              case find_aggregate_binding(
                     query.__ash_bindings__.bindings,
                     relationship_path,
                     sort
                   ) do
                {:ok, binding} ->
                  aggregate =
                    Ash.Resource.Info.aggregate(resource, sort) ||
                      raise "No such aggregate for query aggregate #{inspect(sort)}"

                  {:ok, attribute_type} =
                    if aggregate.field do
                      related = Ash.Resource.Info.related(resource, aggregate.relationship_path)

                      attr = Ash.Resource.Info.attribute(related, aggregate.field)

                      if attr && related do
                        {:ok,
                         AshSql.Expr.parameterized_type(
                           query.__ash_bindings__.sql_behaviour,
                           attr.type,
                           attr.constraints,
                           :sort
                         )}
                      else
                        {:ok, nil}
                      end
                    else
                      {:ok, nil}
                    end

                  default_value =
                    if is_function(aggregate.default) do
                      aggregate.default.()
                    else
                      aggregate.default
                    end

                  default_value =
                    default_value || Ash.Query.Aggregate.default_value(aggregate.kind)

                  if is_nil(default_value) do
                    Ecto.Query.dynamic(field(as(^binding), ^sort))
                  else
                    if attribute_type do
                      typed_default =
                        query.__ash_bindings__.sql_behaviour.type_expr(
                          default_value,
                          type
                        )

                      Ecto.Query.dynamic(
                        coalesce(
                          field(as(^binding), ^sort),
                          ^typed_default
                        )
                      )
                    else
                      Ecto.Query.dynamic(coalesce(field(as(^binding), ^sort), ^default_value))
                    end
                  end

                :error ->
                  aggregate = Ash.Resource.Info.aggregate(resource, sort)

                  {binding, sort} =
                    if aggregate &&
                         AshSql.Aggregate.optimizable_first_aggregate?(resource, aggregate, query) do
                      {AshSql.Join.get_binding(
                         resource,
                         aggregate.relationship_path,
                         query,
                         [
                           :left,
                           :inner
                         ]
                       ), aggregate.field}
                    else
                      {binding, sort}
                    end

                  Ecto.Query.dynamic(field(as(^binding), ^sort))
              end

            {:cont, {:ok, query_expr ++ [{order, expr}], query}}
        end)
        |> case do
          {:ok, [], query} ->
            if type == :return do
              {:ok, [], query}
            else
              {:ok, query}
            end

          {:ok, sort_exprs, query} ->
            case type do
              :return ->
                {:ok, order_to_fragments(sort_exprs), query}

              :window ->
                new_query = Ecto.Query.order_by(query, ^sort_exprs)

                sort_expr = List.last(new_query.order_bys)

                new_query =
                  new_query
                  |> Map.update!(:windows, fn windows ->
                    order_by_expr = %{sort_expr | expr: [order_by: sort_expr.expr]}
                    Keyword.put(windows, :order, order_by_expr)
                  end)
                  |> Map.update!(:__ash_bindings__, &Map.put(&1, :__order__?, true))

                {:ok, new_query}

              :direct ->
                {:ok, query |> Ecto.Query.order_by(^sort_exprs) |> set_sort_applied()}
            end

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def find_aggregate_binding(bindings, relationship_path, sort) do
    Enum.find_value(
      bindings,
      :error,
      fn
        {key, %{type: :aggregate, path: ^relationship_path, aggregates: aggregates}} ->
          if Enum.any?(aggregates, &(&1.name == sort)) do
            {:ok, key}
          end

        _ ->
          nil
      end
    )
  end

  def order_to_fragments([]), do: []

  def order_to_fragments([last]) do
    [do_order_to_fragments(last, false)]
  end

  def order_to_fragments([first | rest]) do
    [do_order_to_fragments(first, true) | order_to_fragments(rest)]
  end

  def do_order_to_fragments({order, sort}, comma?) do
    case {order, comma?} do
      {:asc, false} ->
        Ecto.Query.dynamic([row], fragment("? ASC", ^sort))

      {:desc, false} ->
        Ecto.Query.dynamic([row], fragment("? DESC", ^sort))

      {:asc_nulls_last, false} ->
        Ecto.Query.dynamic([row], fragment("? ASC NULLS LAST", ^sort))

      {:asc_nulls_first, false} ->
        Ecto.Query.dynamic([row], fragment("? ASC NULLS FIRST", ^sort))

      {:desc_nulls_first, false} ->
        Ecto.Query.dynamic([row], fragment("? DESC NULLS FIRST", ^sort))

      {:desc_nulls_last, false} ->
        Ecto.Query.dynamic([row], fragment("? DESC NULLS LAST", ^sort))
        "DESC NULLS LAST"

      {:asc, true} ->
        Ecto.Query.dynamic([row], fragment("? ASC, ", ^sort))

      {:desc, true} ->
        Ecto.Query.dynamic([row], fragment("? DESC, ", ^sort))

      {:asc_nulls_last, true} ->
        Ecto.Query.dynamic([row], fragment("? ASC NULLS LAST, ", ^sort))

      {:asc_nulls_first, true} ->
        Ecto.Query.dynamic([row], fragment("? ASC NULLS FIRST, ", ^sort))

      {:desc_nulls_first, true} ->
        Ecto.Query.dynamic([row], fragment("? DESC NULLS FIRST, ", ^sort))

      {:desc_nulls_last, true} ->
        Ecto.Query.dynamic([row], fragment("? DESC NULLS LAST, ", ^sort))
        "DESC NULLS LAST"
    end
  end

  def order_to_sql_order(dir) do
    case dir do
      :asc -> nil
      :asc_nils_last -> " ASC NULLS LAST"
      :asc_nils_first -> " ASC NULLS FIRST"
      :desc -> " DESC"
      :desc_nils_last -> " DESC NULLS LAST"
      :desc_nils_first -> " DESC NULLS FIRST"
    end
  end

  def apply_sort(query, sort, resource, type \\ :window)

  def apply_sort(query, sort, _resource, _) when sort in [nil, []] do
    {:ok, query |> set_sort_applied()}
  end

  def apply_sort(query, sort, resource, type) do
    AshSql.Sort.sort(query, sort, resource, [], query.__ash_bindings__.root_binding, type)
  end

  defp set_sort_applied(query) do
    Map.update!(query, :__ash_bindings__, &Map.put(&1, :sort_applied?, true))
  end

  def sanitize_sort(sort) do
    sort
    |> List.wrap()
    |> Enum.map(fn
      {sort, {order, context}} ->
        {ash_to_ecto_order(order), {sort, context}}

      {sort, order} ->
        {ash_to_ecto_order(order), sort}

      sort ->
        sort
    end)
  end

  defp ash_to_ecto_order(:asc_nils_last), do: :asc_nulls_last
  defp ash_to_ecto_order(:asc_nils_first), do: :asc_nulls_first
  defp ash_to_ecto_order(:desc_nils_last), do: :desc_nulls_last
  defp ash_to_ecto_order(:desc_nils_first), do: :desc_nulls_first
  defp ash_to_ecto_order(other), do: other
end
