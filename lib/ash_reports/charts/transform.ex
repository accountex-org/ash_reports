defmodule AshReports.Charts.Transform do
  @moduledoc """
  Executes data transformations for declarative charts.

  This module transforms raw query results into chart-ready data by applying:
  - Grouping operations (`group_by`)
  - Aggregations (`:count`, `:sum`, `:avg`, `:min`, `:max`)
  - Data mappings (`as_category`, `as_value`, `as_x`, `as_y`)
  - Post-aggregation filters

  ## Transform Structure

  A transform is defined in the chart DSL:

      transform do
        group_by :status
        aggregate :count
        as_category :status
        as_value :count
      end

  ## Execution Flow

  1. **Group**: Records are grouped by the specified field
  2. **Aggregate**: Aggregations are calculated for each group
  3. **Map**: Results are mapped to chart format (category/value or x/y)
  4. **Filter**: Optional post-aggregation filtering

  ## Examples

      # Simple pie chart transform
      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :status, value: :count}
      }

      records = [
        %{status: :active, id: 1},
        %{status: :active, id: 2},
        %{status: :inactive, id: 3}
      ]

      Transform.execute(records, transform)
      # => [
      #   %{category: :active, value: 2},
      #   %{category: :inactive, value: 1}
      # ]
  """

  require Logger

  defstruct group_by: nil,
            aggregates: [],
            mappings: %{},
            filters: [],
            sort_by: nil

  @type aggregate_type :: :count | :sum | :avg | :min | :max
  @type aggregate_spec :: {aggregate_type(), field :: atom() | nil, as :: atom()}
  @type mapping :: %{
          optional(:category) => atom(),
          optional(:value) => atom(),
          optional(:x) => atom(),
          optional(:y) => atom()
        }

  @type t :: %__MODULE__{
          group_by: atom() | nil,
          aggregates: [aggregate_spec()],
          mappings: mapping(),
          filters: [term()],
          sort_by: {atom(), :asc | :desc} | nil
        }

  @doc """
  Executes a transform on a list of records.

  ## Parameters

    - `records` - List of maps/structs to transform
    - `transform` - Transform definition struct or nil

  ## Returns

    - `{:ok, chart_data}` - Successfully transformed data
    - `{:error, reason}` - Transformation failed

  ## Examples

      {:ok, chart_data} = Transform.execute(records, transform)

      # With nil transform (passthrough)
      {:ok, records} = Transform.execute(records, nil)
  """
  @spec execute([map()], t() | nil) :: {:ok, [map()]} | {:error, term()}
  def execute(records, nil), do: {:ok, records}
  def execute([], _transform), do: {:ok, []}

  def execute(records, %__MODULE__{} = transform) when is_list(records) do
    try do
      result =
        records
        |> apply_grouping(transform.group_by)
        |> apply_aggregations(transform.aggregates)
        |> apply_mappings(transform.mappings)
        |> apply_filters(transform.filters)
        |> apply_sorting(transform.sort_by)

      {:ok, result}
    rescue
      error ->
        Logger.error("Transform execution failed: #{Exception.message(error)}")
        {:error, {:transform_failed, Exception.message(error)}}
    end
  end

  def execute(_records, transform) do
    {:error, {:invalid_transform, "Expected Transform struct, got: #{inspect(transform)}"}}
  end

  # Private Functions

  # Step 1: Group records by field
  defp apply_grouping(records, nil), do: [{nil, records}]

  defp apply_grouping(records, group_field) when is_atom(group_field) do
    records
    |> Enum.group_by(fn record ->
      get_field_value(record, group_field)
    end)
    |> Enum.to_list()
  end

  # Step 2: Apply aggregations to each group
  defp apply_aggregations(grouped_data, aggregates) when is_list(aggregates) do
    Enum.map(grouped_data, fn {group_key, group_records} ->
      aggregate_results =
        Enum.reduce(aggregates, %{}, fn {agg_type, field, as_name}, acc ->
          value = calculate_aggregate(agg_type, group_records, field)
          Map.put(acc, as_name, value)
        end)

      # Combine group key with aggregate results
      base_data = if group_key, do: %{group_key: group_key}, else: %{}
      Map.merge(base_data, aggregate_results)
    end)
  end

  # Step 3: Map to chart format
  defp apply_mappings(aggregated_data, mappings) when is_map(mappings) and map_size(mappings) == 0 do
    # No mappings defined, return as-is
    aggregated_data
  end

  defp apply_mappings(aggregated_data, mappings) when is_map(mappings) do
    Enum.map(aggregated_data, fn data ->
      Enum.reduce(mappings, %{}, fn {target_field, source_field}, acc ->
        value =
          cond do
            # Source is a literal value (for group_key)
            source_field == :group_key -> Map.get(data, :group_key)
            # Source is an aggregate result
            Map.has_key?(data, source_field) -> Map.get(data, source_field)
            # Fallback to nil
            true -> nil
          end

        Map.put(acc, target_field, value)
      end)
    end)
  end

  # Step 4: Apply post-aggregation filters
  defp apply_filters(data, []), do: data

  defp apply_filters(data, filters) when is_list(filters) do
    Enum.filter(data, fn record ->
      Enum.all?(filters, fn filter_fn ->
        filter_fn.(record)
      end)
    end)
  end

  # Step 5: Apply sorting
  defp apply_sorting(data, nil), do: data

  defp apply_sorting(data, {field, direction}) when direction in [:asc, :desc] do
    Enum.sort_by(data, &Map.get(&1, field), direction)
  end

  # Aggregate Calculations

  defp calculate_aggregate(:count, records, _field) do
    length(records)
  end

  defp calculate_aggregate(:sum, records, field) when is_atom(field) do
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(0, fn value, acc ->
      add_values(acc, value)
    end)
  end

  defp calculate_aggregate(:avg, records, field) when is_atom(field) do
    values =
      records
      |> Enum.map(&get_field_value(&1, field))
      |> Enum.reject(&is_nil/1)

    case length(values) do
      0 -> 0
      count -> Enum.sum(values) / count
    end
  end

  defp calculate_aggregate(:min, records, field) when is_atom(field) do
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end

  defp calculate_aggregate(:max, records, field) when is_atom(field) do
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  # Helper Functions

  defp get_field_value(record, field) when is_atom(field) do
    cond do
      is_map(record) -> Map.get(record, field)
      true -> nil
    end
  end

  # Handle Decimal values for sum
  defp add_values(acc, %Decimal{} = value) do
    if is_integer(acc) or is_float(acc) do
      Decimal.add(Decimal.new(acc), value)
    else
      Decimal.add(acc, value)
    end
  end

  defp add_values(acc, value) when is_number(value) do
    if match?(%Decimal{}, acc) do
      Decimal.add(acc, Decimal.new(value))
    else
      acc + value
    end
  end

  defp add_values(acc, _value), do: acc

  @doc """
  Parses a transform definition from chart DSL.

  This is a placeholder for Phase 1. Full Spark DSL integration
  will be implemented in Phase 2.

  ## Examples

      transform_def = %{
        group_by: :status,
        aggregate: [:count],
        as_category: :status,
        as_value: :count
      }

      {:ok, transform} = Transform.parse(transform_def)
  """
  @spec parse(map() | nil) :: {:ok, t()} | {:error, term()}
  def parse(nil), do: {:ok, nil}

  def parse(transform_def) when is_map(transform_def) do
    try do
      transform = %__MODULE__{
        group_by: Map.get(transform_def, :group_by),
        aggregates: parse_aggregates(Map.get(transform_def, :aggregates, [])),
        mappings: parse_mappings(transform_def),
        filters: Map.get(transform_def, :filters, []),
        sort_by: Map.get(transform_def, :sort_by)
      }

      {:ok, transform}
    rescue
      error ->
        {:error, {:parse_failed, Exception.message(error)}}
    end
  end

  defp parse_aggregates(aggregates) when is_list(aggregates) do
    Enum.map(aggregates, fn
      {type, field, as_name} -> {type, field, as_name}
      {type, field} -> {type, field, field}
      type when is_atom(type) -> {type, nil, type}
    end)
  end

  defp parse_mappings(transform_def) do
    %{}
    |> maybe_put(:category, Map.get(transform_def, :as_category))
    |> maybe_put(:value, Map.get(transform_def, :as_value))
    |> maybe_put(:x, Map.get(transform_def, :as_x))
    |> maybe_put(:y, Map.get(transform_def, :as_y))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
