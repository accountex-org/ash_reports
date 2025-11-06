defmodule AshReports.Charts.DataSourceHelpers do
  @moduledoc """
  Helper functions for optimizing chart data source queries.

  ## Avoiding N+1 Query Problems

  When working with large datasets, eagerly loading relationships with `Ash.Query.load/2`
  can cause severe performance issues known as "N+1 query problems". This occurs when
  loading a relationship for each record in a collection, resulting in N individual queries.

  ### Example Problem

      # ❌ BAD - This creates an N+1 query problem
      data_source(fn ->
        InvoiceLineItem
        |> Ash.Query.load(product: :category)  # Loads product for EVERY line item!
        |> Ash.read!(domain: MyApp.Domain)
      end)

  With 325,000 line items, this performs 325,000+ individual lookups. This can take
  **8+ minutes** on large datasets!

  ### Solution Pattern

      # ✅ GOOD - Load relationships separately and join in memory
      data_source(fn ->
        # 1. Load main records without relationships
        items = InvoiceLineItem |> Ash.read!(domain: MyApp.Domain)

        # 2. Get unique related IDs
        product_ids = items |> Enum.map(& &1.product_id) |> Enum.uniq()

        # 3. Load related records once
        products =
          Product
          |> Ash.read!(domain: MyApp.Domain)
          |> build_lookup_map(:id)

        # 4. Join in memory using helper
        chart_data = join_and_aggregate(items, products, :product_id)
      end)

  This reduces execution time from **8 minutes to <1 second** on large datasets!

  ## Using the Helpers

  This module provides helper functions to make the optimized pattern easier to implement:

  - `build_lookup_map/2` - Create fast lookup maps from collections
  - `extract_unique_ids/2` - Extract unique IDs from a collection
  - `load_related_batch/3` - Load related records in a single query
  - `join_with_lookup/3` - Join collections using a lookup map
  - `warn_if_loaded/2` - Runtime warning for potential N+1 issues

  See individual function documentation for detailed usage examples.
  """

  require Logger

  @doc """
  Builds a fast lookup map from a collection of records.

  This creates a map where keys are the specified field values and values are
  the records themselves, enabling O(1) lookups instead of O(N) scans.

  ## Parameters

    - `records` - Collection of records to index
    - `key_field` - Field name to use as the map key (atom)

  ## Returns

  A map with `key_field` values as keys and records as values.

  ## Examples

      # Create lookup map by ID
      products = [%Product{id: 1, name: "A"}, %Product{id: 2, name: "B"}]
      lookup = build_lookup_map(products, :id)
      # => %{1 => %Product{id: 1, name: "A"}, 2 => %Product{id: 2, name: "B"}}

      # Create lookup map by name
      lookup = build_lookup_map(products, :name)
      # => %{"A" => %Product{id: 1, name: "A"}, "B" => %Product{id: 2, name: "B"}}

  """
  @spec build_lookup_map(list(), atom()) :: map()
  def build_lookup_map(records, key_field) when is_list(records) and is_atom(key_field) do
    records
    |> Enum.reject(&is_nil(Map.get(&1, key_field)))
    |> Map.new(fn record -> {Map.get(record, key_field), record} end)
  end

  @doc """
  Extracts unique ID values from a collection of records.

  Filters out nil values and returns only unique IDs.

  ## Parameters

    - `records` - Collection of records
    - `id_field` - Field name containing the ID (atom)

  ## Returns

  List of unique, non-nil ID values.

  ## Examples

      line_items = [
        %{product_id: 1},
        %{product_id: 1},
        %{product_id: 2},
        %{product_id: nil}
      ]

      extract_unique_ids(line_items, :product_id)
      # => [1, 2]

  """
  @spec extract_unique_ids(list(), atom()) :: list()
  def extract_unique_ids(records, id_field) when is_list(records) and is_atom(id_field) do
    records
    |> Enum.map(&Map.get(&1, id_field))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Loads related records in a single batch query.

  This is a convenience wrapper that combines extracting IDs and loading the
  related records in one step.

  ## Parameters

    - `source_records` - Collection of source records
    - `foreign_key` - Field name in source records pointing to related records
    - `related_module` - Ash resource module for related records
    - `opts` - Keyword list of options
      - `:domain` - Ash domain (required)
      - `:preload` - Fields to preload on related records (optional)
      - `:key_field` - Field to use as map key (default: `:id`)

  ## Returns

  `{:ok, lookup_map}` or `{:error, reason}`

  ## Examples

      # Load products for line items
      {:ok, products_map} = load_related_batch(
        line_items,
        :product_id,
        Product,
        domain: MyApp.Domain,
        preload: :category
      )

  """
  @spec load_related_batch(list(), atom(), module(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def load_related_batch(source_records, foreign_key, related_module, opts)
      when is_list(source_records) and is_atom(foreign_key) and is_atom(related_module) do
    domain = Keyword.fetch!(opts, :domain)
    preload_fields = Keyword.get(opts, :preload, [])
    key_field = Keyword.get(opts, :key_field, :id)

    # Extract unique IDs
    unique_ids = extract_unique_ids(source_records, foreign_key)

    # Load related records
    query = Ash.Query.new(related_module)

    query =
      if preload_fields != [] do
        Ash.Query.load(query, preload_fields)
      else
        query
      end

    case Ash.read(query, domain: domain) do
      {:ok, all_related} ->
        # Filter to only IDs we need and build lookup map
        filtered =
          all_related
          |> Enum.filter(&(Map.get(&1, key_field) in unique_ids))

        lookup_map = build_lookup_map(filtered, key_field)
        {:ok, lookup_map}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Joins source records with related records using a lookup map.

  This performs an in-memory join by looking up related records for each source record.

  ## Parameters

    - `source_records` - Collection of source records
    - `lookup_map` - Map created by `build_lookup_map/2`
    - `foreign_key` - Field in source records containing the lookup key

  ## Returns

  List of tuples `{source_record, related_record}` for matching records.

  ## Examples

      products_map = build_lookup_map(products, :id)

      joined = join_with_lookup(line_items, products_map, :product_id)
      # => [
      #   {%LineItem{product_id: 1}, %Product{id: 1}},
      #   {%LineItem{product_id: 2}, %Product{id: 2}}
      # ]

  """
  @spec join_with_lookup(list(), map(), atom()) :: list(tuple())
  def join_with_lookup(source_records, lookup_map, foreign_key)
      when is_list(source_records) and is_map(lookup_map) and is_atom(foreign_key) do
    source_records
    |> Enum.map(fn record ->
      lookup_key = Map.get(record, foreign_key)
      related = Map.get(lookup_map, lookup_key)
      {record, related}
    end)
    |> Enum.reject(fn {_source, related} -> is_nil(related) end)
  end

  @doc """
  Warns if records were loaded with relationships (potential N+1 issue).

  This can be used as a runtime check to detect potentially inefficient queries.
  Checks the first record in the collection to see if relationship fields are loaded.

  ## Parameters

    - `records` - Collection of records to check
    - `relationship_fields` - List of relationship field names (atoms)

  ## Returns

  The original records (passthrough for piping).

  ## Examples

      InvoiceLineItem
      |> Ash.read!(domain: MyApp.Domain)
      |> warn_if_loaded([:product, :invoice])
      # Logs warning if product or invoice are loaded

  """
  @spec warn_if_loaded(list(), list(atom())) :: list()
  def warn_if_loaded(records, relationship_fields)
      when is_list(records) and is_list(relationship_fields) do
    if records != [] do
      first_record = List.first(records)

      loaded_relationships =
        relationship_fields
        |> Enum.filter(fn field ->
          value = Map.get(first_record, field)
          # Check if it's loaded (not %NotLoaded{} and not nil)
          not is_nil(value) and not match?(%Ash.NotLoaded{}, value)
        end)

      if loaded_relationships != [] do
        Logger.warning("""
        [AshReports Performance Warning]
        Detected loaded relationships in data source: #{inspect(loaded_relationships)}

        This may cause N+1 query problems with large datasets!

        Consider using AshReports.Charts.DataSourceHelpers to optimize:
        - Use load_related_batch/4 to load relationships separately
        - Use build_lookup_map/2 to create fast lookup tables
        - Use join_with_lookup/3 to join in memory

        See: AshReports.Charts.DataSourceHelpers documentation
        """)
      end
    end

    records
  end

  @doc """
  Optimized pattern for loading records with a single relationship.

  This is a convenience function that combines the common pattern of loading
  records, extracting IDs, loading related records, and creating a lookup map.

  ## Parameters

    - `source_module` - Ash resource module for source records
    - `related_module` - Ash resource module for related records
    - `foreign_key` - Field in source records pointing to related records
    - `opts` - Keyword list of options
      - `:domain` - Ash domain (required)
      - `:preload` - Fields to preload on related records (optional)

  ## Returns

  `{:ok, {source_records, lookup_map}}` or `{:error, reason}`

  ## Examples

      {:ok, {line_items, products_map}} = load_with_relationship(
        InvoiceLineItem,
        Product,
        :product_id,
        domain: MyApp.Domain,
        preload: :category
      )

      # Now use the lookup map
      enriched_items = Enum.map(line_items, fn item ->
        product = products_map[item.product_id]
        %{item | product: product}
      end)

  """
  @spec load_with_relationship(module(), module(), atom(), keyword()) ::
          {:ok, {list(), map()}} | {:error, term()}
  def load_with_relationship(source_module, related_module, foreign_key, opts)
      when is_atom(source_module) and is_atom(related_module) and is_atom(foreign_key) do
    domain = Keyword.fetch!(opts, :domain)

    with {:ok, source_records} <- Ash.read(source_module, domain: domain),
         {:ok, lookup_map} <-
           load_related_batch(source_records, foreign_key, related_module, opts) do
      {:ok, {source_records, lookup_map}}
    end
  end
end
