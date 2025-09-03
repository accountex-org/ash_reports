defmodule AshSql.Bindings do
  @moduledoc false

  @doc false
  def add_binding(query, data, additional_bindings \\ 0) do
    current = query.__ash_bindings__.current
    bindings = query.__ash_bindings__.bindings

    new_ash_bindings = %{
      query.__ash_bindings__
      | bindings: Map.put(bindings, current, data),
        current: current + 1 + additional_bindings
    }

    %{query | __ash_bindings__: new_ash_bindings}
  end

  def explicitly_set_binding(query, data, to) do
    %{
      query
      | __ash_bindings__: %{
          query.__ash_bindings__
          | bindings: Map.put(query.__ash_bindings__.bindings, to, data)
        }
    }
  end

  def merge_expr_accumulator(query, acc) do
    update_in(
      query.__ash_bindings__.expression_accumulator,
      &AshSql.Expr.merge_accumulator(&1, acc)
    )
  end

  def default_bindings(query, resource, sql_behaviour, context \\ %{})

  def default_bindings(%{__ash_bindings__: _} = query, _resource, _sql_behaviour, _context),
    do: query

  def default_bindings(query, resource, sql_behaviour, context) do
    default_start_bindings =
      if context[:data_layer][:lateral_join_source] do
        500
      else
        0
      end

    requested_start = context[:data_layer][:start_bindings_at] || 0

    start_bindings =
      if requested_start == 0 do
        default_start_bindings
      else
        requested_start
      end

    Map.put_new(query, :__ash_bindings__, %{
      resource: resource,
      sql_behaviour: sql_behaviour,
      current: Enum.count(query.joins) + 1 + start_bindings,
      expression_accumulator: %AshSql.Expr.ExprInfo{},
      in_group?: false,
      calculations: %{},
      parent_resources: [],
      aggregate_defs: %{},
      current_aggregate_name: :aggregate_0,
      current_calculation_name: :calculation_0,
      aggregate_names: %{},
      calculation_names: %{},
      context: context,
      root_binding: start_bindings,
      bindings: %{start_bindings => %{path: [], type: :root, source: resource}}
    })
  end

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

  def add_parent_bindings(data_layer_query, %{data_layer: %{parent_bindings: parent_bindings}})
      when not is_nil(parent_bindings) do
    new_bindings =
      data_layer_query.__ash_bindings__
      |> Map.put(:parent_bindings, Map.put(parent_bindings, :parent?, true))
      |> Map.put(:parent_resources, [
        parent_bindings.resource | parent_bindings[:parent_resources] || []
      ])
      |> Map.put(:lateral_join?, true)

    %{data_layer_query | __ash_bindings__: new_bindings}
  end

  def add_parent_bindings(data_layer_query, _context) do
    data_layer_query
  end
end
