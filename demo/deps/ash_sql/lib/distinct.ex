defmodule AshSql.Distinct do
  @moduledoc false
  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  def distinct(query, empty, resource) when empty in [nil, []] do
    query |> AshSql.Sort.apply_sort(query.__ash_bindings__[:sort], resource)
  end

  def distinct(query, distinct_on, resource) do
    case get_distinct_statement(query, distinct_on) do
      {:ok, {distinct_statement, query}} ->
        %{query | distinct: distinct_statement}
        |> AshSql.Sort.apply_sort(query.__ash_bindings__[:sort], resource)

      {:error, {distinct_statement, query}} ->
        query
        |> Ecto.Query.exclude(:order_by)
        |> AshSql.Bindings.default_bindings(resource, query.__ash_bindings__.sql_behaviour)
        |> Map.put(:distinct, distinct_statement)
        |> AshSql.Sort.apply_sort(
          query.__ash_bindings__[:distinct_sort] || query.__ash_bindings__[:sort],
          resource,
          :direct
        )
        |> case do
          {:ok, distinct_query} ->
            on =
              Enum.reduce(Ash.Resource.Info.primary_key(resource), nil, fn key, dynamic ->
                if dynamic do
                  Ecto.Query.dynamic(
                    [row, distinct],
                    ^dynamic and field(row, ^key) == field(distinct, ^key)
                  )
                else
                  Ecto.Query.dynamic([row, distinct], field(row, ^key) == field(distinct, ^key))
                end
              end)

            joined_query_source =
              Enum.reduce(
                [
                  :join,
                  :order_by,
                  :group_by,
                  :having,
                  :distinct,
                  :select,
                  :combinations,
                  :with_ctes,
                  :limit,
                  :offset,
                  :lock,
                  :preload,
                  :update,
                  :where
                ],
                query,
                &Ecto.Query.exclude(&2, &1)
              )

            {calculations_require_rewrite, aggregates_require_rewrite, distinct_query} =
              AshSql.Query.rewrite_nested_selects(distinct_query)

            joined_query =
              from(row in joined_query_source,
                join: distinct in subquery(distinct_query),
                on: ^on
              )

            from([row, distinct] in joined_query,
              select: distinct
            )
            |> AshSql.Bindings.default_bindings(resource, query.__ash_bindings__.sql_behaviour)
            |> AshSql.Sort.apply_sort(query.__ash_bindings__[:sort], resource)
            |> case do
              {:ok, joined_query} ->
                {:ok,
                 Map.update!(
                   joined_query,
                   :__ash_bindings__,
                   fn ash_bindings ->
                     ash_bindings
                     |> Map.put(:__order__?, query.__ash_bindings__[:__order__?] || false)
                     |> Map.update(
                       :calculations_require_rewrite,
                       calculations_require_rewrite,
                       fn current_calculations_require_rewrite ->
                         Map.merge(
                           current_calculations_require_rewrite,
                           calculations_require_rewrite
                         )
                       end
                     )
                     |> Map.update(
                       :aggregates_require_rewrite,
                       aggregates_require_rewrite,
                       fn current_aggregates_require_rewrite ->
                         Map.merge(
                           current_aggregates_require_rewrite,
                           aggregates_require_rewrite
                         )
                       end
                     )
                   end
                 )}

              {:error, error} ->
                {:error, error}
            end

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp get_distinct_statement(query, distinct_on) do
    has_distinct_sort? = match?(%{__ash_bindings__: %{distinct_sort: _}}, query)

    if has_distinct_sort? do
      {:error, default_distinct_statement(query, distinct_on)}
    else
      sort = query.__ash_bindings__[:sort] || []

      distinct =
        if Code.ensure_loaded?(Ecto.Query.ByExpr) do
          query.distinct ||
            struct!(Ecto.Query.ByExpr, expr: [], params: [])
        else
          query.distinct ||
            %Ecto.Query.QueryExpr{
              expr: [],
              params: []
            }
        end

      if sort == [] do
        {:ok, default_distinct_statement(query, distinct_on)}
      else
        distinct_on
        |> Enum.reduce_while({sort, [], [], Enum.count(distinct.params), query}, fn
          _, {[], _distinct_statement, _, _count, _query} ->
            {:halt, :error}

          distinct_on, {[order_by | rest_order_by], distinct_statement, params, count, query} ->
            case order_by do
              {distinct_on, order} = ^distinct_on ->
                {distinct_expr, params, count, query} =
                  distinct_on_expr(query, distinct_on, params, count)

                {:cont,
                 {rest_order_by, [{order, distinct_expr} | distinct_statement], params, count,
                  query}}

              _ ->
                {:halt, :error}
            end
        end)
        |> case do
          :error ->
            {:error, default_distinct_statement(query, distinct_on)}

          {_, result, params, _, query} ->
            {:ok,
             {%{
                distinct
                | expr: distinct.expr ++ Enum.reverse(result),
                  params: distinct.params ++ Enum.reverse(params)
              }, query}}
        end
      end
    end
  end

  defp default_distinct_statement(query, distinct_on) do
    distinct =
      if Code.ensure_loaded?(Ecto.Query.ByExpr) do
        query.distinct ||
          struct!(Ecto.Query.ByExpr, expr: [], params: [])
      else
        query.distinct ||
          %Ecto.Query.QueryExpr{
            expr: [],
            params: []
          }
      end

    {expr, params, _, query} =
      Enum.reduce(distinct_on, {[], [], Enum.count(distinct.params), query}, fn
        {distinct_on_field, order}, {expr, params, count, query} ->
          {distinct_expr, params, count, query} =
            distinct_on_expr(query, distinct_on_field, params, count)

          {[{order, distinct_expr} | expr], params, count, query}

        distinct_on_field, {expr, params, count, query} ->
          {distinct_expr, params, count, query} =
            distinct_on_expr(query, distinct_on_field, params, count)

          {[{:asc, distinct_expr} | expr], params, count, query}
      end)

    {%{
       distinct
       | expr: distinct.expr ++ Enum.reverse(expr),
         params: distinct.params ++ Enum.reverse(params)
     }, query}
  end

  defp distinct_on_expr(query, field, params, count) do
    resource = query.__ash_bindings__.resource

    ref =
      case field do
        %Ash.Query.Calculation{} = calc ->
          %Ash.Query.Ref{attribute: calc, relationship_path: [], resource: resource}

        field ->
          %Ash.Query.Ref{
            attribute: Ash.Resource.Info.field(resource, field),
            relationship_path: [],
            resource: resource
          }
      end

    {dynamic, acc} = AshSql.Expr.dynamic_expr(query, ref, query.__ash_bindings__)

    result =
      Ecto.Query.Builder.Dynamic.partially_expand(
        :distinct,
        query,
        dynamic,
        params,
        count
      )

    expr = elem(result, 0)
    new_params = elem(result, 1)
    new_count = result |> Tuple.to_list() |> List.last()

    {expr, new_params, new_count, AshSql.Expr.merge_accumulator(query, acc)}
  end
end
