defmodule AshSql do
  @moduledoc false
  def dynamic_repo(resource, sql_behaviour, %{
        __ash_bindings__: %{context: %{data_layer: %{repo: repo}}}
      }) do
    repo || sql_behaviour.repo(resource, :read)
  end

  def dynamic_repo(resource, sql_behaviour, %struct{context: %{data_layer: %{repo: repo}}}) do
    type = struct_to_repo_type(struct)

    repo || sql_behaviour.repo(resource, type)
  end

  def dynamic_repo(resource, sql_behaviour, %struct{}) do
    sql_behaviour.repo(resource, struct_to_repo_type(struct))
  end

  def repo_opts(_repo, sql_behaviour, timeout, tenant, resource) do
    if Ash.Resource.Info.multitenancy_strategy(resource) == :context do
      [prefix: tenant]
    else
      if schema = sql_behaviour.schema(resource) do
        [prefix: schema]
      else
        []
      end
    end
    |> add_timeout(timeout)
  end

  defp add_timeout(opts, timeout) when not is_nil(timeout) do
    Keyword.put(opts, :timeout, timeout)
  end

  defp add_timeout(opts, _), do: opts

  defp struct_to_repo_type(struct) do
    case struct do
      Ash.Changeset -> :mutate
      Ash.Query -> :read
      Ecto.Query -> :read
      Ecto.Changeset -> :mutate
    end
  end
end
