defmodule AshSql.Query do
  @moduledoc false
  import Ecto.Query, only: [subquery: 1, from: 2]
  require Ecto.Query
  require Ash.Expr

  def resource_to_query(resource, implementation, domain \\ nil) do
    from(row in {implementation.table(resource) || "", resource}, [])
    |> Map.put(:__ash_domain__, domain)
  end

  def combination_of(
        [{:base, first} | combination_of],
        _resource,
        _implementation,
        _domain \\ nil
      ) do
    Enum.reduce(combination_of, subquery(first), fn {type, combination_of}, query ->
      case type do
        :union ->
          Ecto.Query.union(query, ^combination_of)

        :union_all ->
          Ecto.Query.union_all(query, ^combination_of)

        :intersect ->
          Ecto.Query.intersect(query, ^combination_of)

        :except ->
          Ecto.Query.except(query, ^combination_of)
      end
    end)
    |> then(&{:ok, &1})
  end

  def set_context(resource, data_layer_query, sql_behaviour, context) do
    data_layer_query =
      if context[:data_layer][:combination_of_queries?] do
        from(row in subquery(data_layer_query), [])
      else
        data_layer_query
      end

    default_start_bindings =
      if context[:data_layer][:lateral_join_source] do
        500
      else
        if context[:data_layer][:previous_combination] do
          context[:data_layer][:previous_combination].__ash_bindings__.current
        else
          0
        end
      end

    start_bindings = context[:data_layer][:start_bindings_at] || default_start_bindings

    context =
      context
      |> Map.put_new(:data_layer, %{})
      |> Map.update!(:data_layer, &Map.put(&1, :start_bindings_at, start_bindings))

    data_layer_query = from(row in data_layer_query, as: ^start_bindings)

    data_layer_query =
      if context[:data_layer][:table] do
        %{
          data_layer_query
          | from: %{data_layer_query.from | source: {context[:data_layer][:table], resource}}
        }
      else
        data_layer_query
      end

    data_layer_query =
      if context[:data_layer][:schema] do
        Ecto.Query.put_query_prefix(data_layer_query, to_string(context[:data_layer][:schema]))
      else
        data_layer_query
      end

    data_layer_query =
      data_layer_query
      |> AshSql.Bindings.default_bindings(resource, sql_behaviour, context)
      |> AshSql.Bindings.add_parent_bindings(context)

    data_layer_query =
      case context[:data_layer][:lateral_join_source] do
        {data, path} ->
          lateral_join_source_query = path |> List.first() |> elem(0)

          lateral_join_source_query.resource
          |> Ash.Query.set_context(%{
            :data_layer =>
              Map.put(
                lateral_join_source_query.context[:data_layer] || %{},
                :no_inner_join?,
                true
              )
              |> Map.delete(:lateral_join_source)
          })
          |> Ash.Query.set_tenant(lateral_join_source_query.tenant)
          |> set_lateral_join_prefix(data_layer_query)
          |> filter_for_records(data)
          |> case do
            %{valid?: true} = query ->
              relationship = path |> List.first() |> elem(3)

              {:ok, expr} =
                Ash.Filter.hydrate_refs(relationship.filter, %{
                  resource: relationship.destination,
                  parent_stack: [relationship.source]
                })

              parent_expr = AshSql.Join.parent_expr(expr)

              used_aggregates =
                Ash.Filter.used_aggregates(parent_expr, [])

              with {:ok, query} <- Ash.Query.data_layer_query(query) do
                AshSql.Aggregate.add_aggregates(
                  query,
                  used_aggregates,
                  relationship.source,
                  false,
                  query.__ash_bindings__.root_binding
                )
              end

            query ->
              {:error, query}
          end
          |> case do
            {:ok, lateral_join_source_query} ->
              lateral_join_source_query =
                if Enum.count(path) == 2 do
                  Map.update!(lateral_join_source_query, :__ash_bindings__, fn bindings ->
                    bindings
                    |> Map.put(:lateral_join_bindings, [start_bindings + 1])
                    |> Map.update!(:bindings, fn bindings ->
                      Map.put(
                        bindings,
                        start_bindings + 1,
                        %{
                          source: path |> Enum.at(1) |> elem(3) |> Map.get(:source),
                          path: [path |> Enum.at(1) |> elem(3) |> Map.get(:name)],
                          type: :inner
                        }
                      )
                    end)
                  end)
                else
                  lateral_join_source_query
                end

              {:ok,
               Map.update!(data_layer_query, :__ash_bindings__, fn bindings ->
                 Map.put(
                   bindings,
                   :lateral_join_source_query,
                   lateral_join_source_query
                 )
               end)}

            {:error, error} ->
              {:error, error}
          end

        _ ->
          {:ok, data_layer_query}
      end

    case data_layer_query do
      {:error, error} ->
        {:error, error}

      {:ok, data_layer_query} ->
        {domain, data_layer_query} = Map.pop(data_layer_query, :__ash_domain__)

        case context[:data_layer][:lateral_join_source] do
          {_, _} ->
            data_layer_query =
              data_layer_query
              |> Map.update!(:__ash_bindings__, &Map.put(&1, :lateral_join?, true))
              |> Map.update!(:__ash_bindings__, &Map.put(&1, :domain, domain))

            {:ok, data_layer_query}

          _ ->
            ash_bindings =
              data_layer_query.__ash_bindings__
              |> Map.put(:lateral_join?, false)
              |> Map.put(:domain, domain)

            {:ok, %{data_layer_query | __ash_bindings__: ash_bindings}}
        end
    end
  end

  defp filter_for_records(query, records) do
    keys =
      case Ash.Resource.Info.primary_key(query.resource) do
        [] ->
          case Ash.Resource.Info.identities(query.resource) do
            [%{keys: keys} | _] -> keys
            _ -> []
          end

        pkey ->
          pkey
      end

    expr =
      case keys do
        [] ->
          raise "Cannot use lateral joins with a resource that has no primary key and no identities"

        [key] ->
          Ash.Expr.expr(^Ash.Expr.ref(key) in ^Enum.map(records, &Map.get(&1, key)))

        keys ->
          Enum.reduce(records, Ash.Expr.expr(false), fn record, filter_expr ->
            all_keys_match_expr =
              Enum.reduce(keys, Ash.Expr.expr(true), fn key, key_expr ->
                Ash.Expr.expr(^key_expr and ^Ash.Expr.ref(key) == ^Map.get(record, key))
              end)

            Ash.Expr.expr(^filter_expr or ^all_keys_match_expr)
          end)
      end

    Ash.Query.do_filter(query, expr)
  end

  def return_query(%{__ash_bindings__: %{lateral_join?: true}} = query, resource) do
    query =
      AshSql.Bindings.default_bindings(query, resource, query.__ash_bindings__.sql_behaviour)

    if query.__ash_bindings__[:sort_applied?] do
      {:ok, query}
    else
      AshSql.Sort.apply_sort(
        query,
        query.__ash_bindings__[:sort],
        query.__ash_bindings__.resource
      )
    end
  end

  def return_query(query, resource) do
    query =
      AshSql.Bindings.default_bindings(query, resource, query.__ash_bindings__.sql_behaviour)

    with_sort_applied =
      if query.__ash_bindings__[:sort_applied?] do
        {:ok, query}
      else
        AshSql.Sort.apply_sort(query, query.__ash_bindings__[:sort], resource)
      end

    case with_sort_applied do
      {:error, error} ->
        {:error, error}

      {:ok, query} ->
        query =
          if query.__ash_bindings__[:__order__?] && query.windows[:order] do
            if query.distinct do
              {calculations_require_rewrite, aggregates_require_rewrite, query} =
                rewrite_nested_selects(query)

              query_with_order =
                from(row in query, select_merge: %{__order__: over(row_number(), :order)})

              query_without_limit_and_offset =
                query_with_order
                |> Ecto.Query.exclude(:limit)
                |> Ecto.Query.exclude(:offset)

              from(row in subquery(query_without_limit_and_offset),
                select: row,
                order_by: row.__order__
              )
              |> Map.put(:limit, query.limit)
              |> Map.put(:offset, query.offset)
              |> AshSql.Bindings.default_bindings(
                resource,
                query.__ash_bindings__.sql_behaviour,
                query.__ash_bindings__.context
              )
              |> Map.update!(:__ash_bindings__, fn bindings ->
                Map.merge(
                  bindings,
                  %{
                    calculations_require_rewrite: calculations_require_rewrite,
                    aggregates_require_rewrite: aggregates_require_rewrite
                  },
                  fn _, v1, v2 -> Map.merge(v1, v2) end
                )
              end)
            else
              order_by = %{query.windows[:order] | expr: query.windows[:order].expr[:order_by]}

              %{
                query
                | windows: Keyword.delete(query.windows, :order),
                  order_bys: [order_by]
              }
            end
          else
            %{query | windows: Keyword.delete(query.windows, :order)}
          end

        combination_fieldset =
          query.__ash_bindings__.context[:data_layer][:combination_fieldset]

        query =
          if combination_fieldset do
            fields =
              resource
              |> Ash.Resource.Info.fields([:attributes, :calculations, :aggregates])
              |> Enum.map(& &1.name)

            to_add_to_calcs = combination_fieldset -- fields

            add_combination_calcs(query, to_add_to_calcs)
          else
            query
          end

        {:ok, query}
    end
  end

  defp set_lateral_join_prefix(ash_query, query) do
    if Ash.Resource.Info.multitenancy_strategy(ash_query.resource) == :context do
      Ash.Query.set_tenant(ash_query, query.prefix)
    else
      ash_query
    end
  end

  defp add_combination_calcs(query, to_add_to_calcs) do
    case query.select do
      %Ecto.Query.SelectExpr{
        expr:
          {:merge, merge_meta,
           [
             merge_base,
             {:%{}, map_meta, current_merging}
           ]}
      } = select ->
        if Keyword.has_key?(current_merging, :calculations) do
          %{
            query
            | select: %{
                select
                | expr:
                    {:merge, merge_meta,
                     [
                       merge_base,
                       {:%{}, map_meta,
                        add_combinations_to_calc_map(
                          current_merging,
                          to_add_to_calcs,
                          query.__ash_bindings__.root_binding
                        )}
                     ]}
              }
          }
        else
          simple_combination_calcs(query, to_add_to_calcs)
        end

      %Ecto.Query.SelectExpr{expr: {:%{}, map_meta, fields}} = select ->
        if Keyword.has_key?(fields, :calculations) do
          %{
            query
            | select: %{
                select
                | expr:
                    {:%{}, map_meta,
                     add_combinations_to_calc_map(
                       fields,
                       to_add_to_calcs,
                       query.__ash_bindings__.root_binding
                     )}
              }
          }
        else
          simple_combination_calcs(query, to_add_to_calcs)
        end

      _ ->
        simple_combination_calcs(query, to_add_to_calcs)
    end
  end

  defp add_combinations_to_calc_map(fields, to_add_to_calcs, root_binding) do
    Keyword.update!(fields, :calculations, fn {:%{}, map_meta, calcs} ->
      merge =
        Keyword.new(to_add_to_calcs, fn name ->
          {name, {{:., [], [{:as, [], [root_binding]}, name]}, [], []}}
        end)

      {:%{}, map_meta, Keyword.merge(calcs, merge)}
    end)
  end

  defp simple_combination_calcs(query, to_add_to_calcs) do
    dynamics =
      Map.new(to_add_to_calcs, fn name ->
        {name, Ecto.Query.dynamic([row], field(row, ^name))}
      end)

    Ecto.Query.select_merge(query, ^%{calculations: dynamics})
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def rewrite_nested_selects(query) do
    case query.select do
      %Ecto.Query.SelectExpr{
        expr:
          {:merge, [],
           [
             merge_base,
             {:%{}, [], current_merging}
           ]}
      } = select ->
        # as we flatten these, they must all remain in the same relative order
        # I'm actually not sure why this is required by ecto, but it is :)
        merging =
          Enum.flat_map(current_merging, fn
            {type, {:%{}, _, type_exprs}} when type in [:calculations, :aggregates] ->
              Enum.map(type_exprs, fn {name, expr} ->
                {String.to_atom("__#{type}__#{name}"), expr}
              end)

            {type, other} ->
              [{type, other}]
          end)

        aggregate_merges =
          current_merging
          |> Keyword.get(:aggregates, {:%{}, [], []})
          |> elem(2)
          |> Map.new(fn {name, _expr} ->
            {String.to_existing_atom("__aggregates__#{name}"), name}
          end)

        calculation_merges =
          current_merging
          |> Keyword.get(:calculations, {:%{}, [], []})
          |> elem(2)
          |> Map.new(fn {name, _expr} ->
            {String.to_existing_atom("__calculations__#{name}"), name}
          end)

        new_query = %{
          query
          | select: %{select | expr: {:merge, [], [merge_base, {:%{}, [], merging}]}}
        }

        {calculation_merges, aggregate_merges, new_query}

      %Ecto.Query.SelectExpr{expr: {:%{}, map_meta, current_merging}} = select ->
        merging =
          Enum.flat_map(current_merging, fn
            {type, {:%{}, _, type_exprs}} when type in [:calculations, :aggregates] ->
              Enum.map(type_exprs, fn {name, expr} ->
                {String.to_atom("__#{type}__#{name}"), expr}
              end)

            {type, other} ->
              [{type, other}]
          end)

        aggregate_merges =
          current_merging
          |> Keyword.get(:aggregates, {:%{}, [], []})
          |> elem(2)
          |> Map.new(fn {name, _expr} ->
            {String.to_existing_atom("__aggregates__#{name}"), name}
          end)

        calculation_merges =
          current_merging
          |> Keyword.get(:calculations, {:%{}, [], []})
          |> elem(2)
          |> Map.new(fn {name, _expr} ->
            {String.to_existing_atom("__calculations__#{name}"), name}
          end)

        new_query = %{
          query
          | select: %{select | expr: {:%{}, map_meta, merging}}
        }

        {calculation_merges, aggregate_merges, new_query}

      _ ->
        {%{}, %{}, query}
    end
  end

  def remap_mapped_fields(
        results,
        query,
        calculations_require_rewrite \\ %{},
        aggregates_require_rewrite \\ %{}
      ) do
    calculation_names =
      query.__ash_bindings__.calculation_names

    aggregate_names = query.__ash_bindings__.aggregate_names

    calculations_require_rewrite =
      Map.merge(
        query.__ash_bindings__[:calculations_require_rewrite] || %{},
        calculations_require_rewrite
      )

    aggregates_require_rewrite =
      Map.merge(
        query.__ash_bindings__[:aggregates_require_rewrite] || %{},
        aggregates_require_rewrite
      )

    if Enum.empty?(calculation_names) and Enum.empty?(aggregate_names) and
         Enum.empty?(calculations_require_rewrite) and Enum.empty?(aggregates_require_rewrite) do
      results
    else
      Enum.map(results, fn result ->
        result
        |> remap_to_nested(:calculations, calculations_require_rewrite)
        |> remap_to_nested(:aggregates, aggregates_require_rewrite)
        |> remap(:calculations, calculation_names)
        |> remap(:aggregates, aggregate_names)
      end)
    end
  end

  defp remap_to_nested(record, _subfield, mapping) when mapping == %{} do
    record
  end

  defp remap_to_nested(record, subfield, mapping) do
    Map.update!(record, subfield, fn subfield_values ->
      Enum.reduce(mapping, subfield_values, fn {source, dest}, subfield_values ->
        subfield_values
        |> Map.put(dest, Map.get(record, source))
        |> Map.delete(source)
      end)
    end)
  end

  defp remap(record, _subfield, mapping) when mapping == %{} do
    record
  end

  defp remap(record, subfield, mapping) do
    Map.update!(record, subfield, fn subfield_values ->
      Enum.reduce(mapping, subfield_values, fn {dest, source}, subfield_values ->
        subfield_values
        |> Map.put(dest, Map.get(subfield_values, source))
        |> Map.delete(source)
      end)
    end)
  end
end
