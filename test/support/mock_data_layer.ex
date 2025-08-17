unless Code.ensure_loaded?(AshReports.MockDataLayer) do
  defmodule AshReports.MockDataLayer do
    @moduledoc """
    ETS-based mock data layer for testing AshReports.

    This data layer simulates realistic Ash.Resource behavior using ETS tables
    to avoid compilation deadlocks during testing while maintaining proper
    Ash semantics.
    """

    @behaviour Ash.DataLayer

    @impl true
    def can?(_, :read), do: true
    def can?(_, :create), do: true
    def can?(_, :update), do: true
    def can?(_, :destroy), do: true
    def can?(_, :sort), do: true
    def can?(_, :filter), do: true
    def can?(_, :limit), do: true
    def can?(_, :offset), do: true
    def can?(_, :boolean_filter), do: true
    def can?(_, :async_engine), do: false
    def can?(_, :transact), do: false
    def can?(_, :composite_primary_key), do: true
    def can?(_, :upsert), do: true
    def can?(_, _), do: false

    @impl true
    def resource_to_query(resource, _domain) do
      table_name = ets_table_name(resource)
      %{resource: resource, table: table_name, query: []}
    end

    @impl true
    def run_query(query, _opts) do
      resource = query.resource
      table = query.table

      # Ensure table exists
      case :ets.info(table) do
        :undefined ->
          create_table(table)
          {:ok, []}

        _ ->
          # Retrieve all records from ETS
          records =
            :ets.tab2list(table)
            |> Enum.map(fn {_key, record} -> record end)
            |> Enum.map(&struct(resource, &1))

          {:ok, records}
      end
    end

    @impl true
    def create(changeset, _opts) do
      resource = changeset.resource
      table = ets_table_name(resource)
      create_table(table)

      attributes = changeset.attributes

      # Generate ID if not provided
      attributes =
        if Map.has_key?(attributes, :id) && attributes.id do
          attributes
        else
          Map.put(attributes, :id, generate_id())
        end

      record = struct(resource, attributes)
      :ets.insert(table, {attributes.id, attributes})

      {:ok, record}
    end

    @impl true
    def update(changeset, _opts) do
      resource = changeset.resource
      table = ets_table_name(resource)
      id = changeset.data.id

      case :ets.lookup(table, id) do
        [{_key, existing_attrs}] ->
          updated_attrs = Map.merge(existing_attrs, changeset.attributes)
          :ets.insert(table, {id, updated_attrs})
          {:ok, struct(resource, updated_attrs)}

        [] ->
          {:error, :not_found}
      end
    end

    @impl true
    def destroy(changeset, _opts) do
      resource = changeset.resource
      table = ets_table_name(resource)
      id = changeset.data.id

      case :ets.lookup(table, id) do
        [{_key, _attrs}] ->
          :ets.delete(table, id)
          {:ok, changeset.data}

        [] ->
          {:error, :not_found}
      end
    end

    @impl true
    def sort(query, sort, _opts) do
      # Basic sorting implementation for testing
      # In real usage, this would be more sophisticated
      {:ok, Map.put(query, :sort, sort)}
    end

    @impl true
    def filter(query, filter, _opts) do
      # Basic filter implementation for testing
      {:ok, Map.put(query, :filter, filter)}
    end

    @impl true
    def limit(query, limit, _opts) do
      {:ok, Map.put(query, :limit, limit)}
    end

    @impl true
    def offset(query, offset, _opts) do
      {:ok, Map.put(query, :offset, offset)}
    end

    # Helper functions

    defp ets_table_name(resource) do
      Module.concat(resource, EtsTable)
    end

    defp create_table(table) do
      case :ets.info(table) do
        :undefined ->
          :ets.new(table, [:set, :public, :named_table])

        _ ->
          :ok
      end
    end

    defp generate_id do
      :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    end

    @doc """
    Helper function to insert test data into ETS table for a resource.
    """
    def insert_test_data(resource, data) when is_list(data) do
      table = ets_table_name(resource)
      create_table(table)

      Enum.each(data, fn attrs ->
        id = attrs[:id] || generate_id()
        attrs_with_id = Map.new(attrs) |> Map.put(:id, id)
        :ets.insert(table, {id, attrs_with_id})
      end)
    end

    @doc """
    Helper function to clear test data from ETS table for a resource.
    """
    def clear_test_data(resource) do
      table = ets_table_name(resource)

      case :ets.info(table) do
        :undefined -> :ok
        _ -> :ets.delete_all_objects(table)
      end
    end

    @doc """
    Helper function to clear all test tables (for cleanup between tests).
    """
    def clear_all_test_data do
      :ets.all()
      |> Enum.filter(fn table ->
        try do
          info = :ets.info(table, :name)

          case info do
            :undefined ->
              false

            name when is_atom(name) ->
              table_name = Atom.to_string(name)
              String.contains?(table_name, "EtsTable")

            _ ->
              false
          end
        rescue
          _ -> false
        end
      end)
      |> Enum.each(&:ets.delete_all_objects/1)
    end
  end
end
