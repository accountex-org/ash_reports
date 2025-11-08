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
            sort_by: nil,
            limit: nil

  @type aggregate_type :: :count | :sum | :avg | :min | :max
  @type aggregate_spec :: {aggregate_type(), field :: atom() | tuple() | nil, as :: atom()}
  @type field_path :: atom() | tuple()
  @type date_grouping :: {atom(), :year | :month | :day | :hour}
  @type mapping :: %{
          optional(:category) => atom() | tuple(),
          optional(:value) => atom(),
          optional(:x) => atom() | tuple(),
          optional(:y) => atom(),
          optional(:task) => atom() | tuple(),
          optional(:start_time) => atom() | tuple(),
          optional(:end_time) => atom() | tuple(),
          optional(:values) => atom()
        }

  @type t :: %__MODULE__{
          group_by: field_path() | date_grouping() | nil,
          aggregates: [aggregate_spec()],
          mappings: mapping(),
          filters: map() | [term()],
          sort_by: {atom(), :asc | :desc} | nil,
          limit: pos_integer() | nil
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
        |> apply_pre_filters(transform.filters)
        |> apply_grouping(transform.group_by)
        |> apply_aggregations(transform.aggregates)
        |> apply_mappings(transform.mappings)
        |> apply_sorting(transform.sort_by)
        |> apply_limit(transform.limit)

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

  # Step 0: Apply pre-aggregation filters (simple map-based filters)
  defp apply_pre_filters(records, filters) when is_map(filters) and map_size(filters) > 0 do
    Enum.filter(records, fn record ->
      Enum.all?(filters, fn {field, expected_value} ->
        actual_value = get_field_value(record, field)

        cond do
          is_list(expected_value) -> actual_value in expected_value
          true -> actual_value == expected_value
        end
      end)
    end)
  end

  defp apply_pre_filters(records, _), do: records

  # Step 1: Group records by field
  defp apply_grouping(records, nil), do: [{nil, records}]

  defp apply_grouping(records, group_field) when is_atom(group_field) do
    records
    |> Enum.group_by(fn record ->
      get_field_value(record, group_field)
    end)
    |> Enum.to_list()
  end

  # Handle nested relationship paths like {:product, :category, :name}
  defp apply_grouping(records, group_path) when is_tuple(group_path) do
    # Check if this is date grouping (second element is :year, :month, :day, or :hour)
    if is_date_grouping?(group_path) do
      apply_date_grouping(records, group_path)
    else
      # Regular nested path grouping
      records
      |> Enum.group_by(fn record ->
        get_nested_value(record, Tuple.to_list(group_path))
      end)
      |> Enum.to_list()
    end
  end

  # Check if tuple is a date grouping pattern
  defp is_date_grouping?({_field, period}) when period in [:year, :month, :day, :hour], do: true
  defp is_date_grouping?(_), do: false

  # Apply date-based grouping
  defp apply_date_grouping(records, {field, period}) do
    records
    |> Enum.group_by(fn record ->
      date_value = get_field_value(record, field)
      extract_date_period(date_value, period)
    end)
    |> Enum.to_list()
  end

  defp extract_date_period(nil, _period), do: nil
  defp extract_date_period(%Date{} = date, :year), do: date.year
  defp extract_date_period(%Date{} = date, :month), do: "#{date.year}-#{String.pad_leading("#{date.month}", 2, "0")}"
  defp extract_date_period(%Date{} = date, :day), do: Date.to_string(date)

  defp extract_date_period(%DateTime{} = datetime, :year), do: datetime.year
  defp extract_date_period(%DateTime{} = datetime, :month), do: "#{datetime.year}-#{String.pad_leading("#{datetime.month}", 2, "0")}"
  defp extract_date_period(%DateTime{} = datetime, :day), do: Date.to_string(DateTime.to_date(datetime))
  defp extract_date_period(%DateTime{} = datetime, :hour), do: "#{Date.to_string(DateTime.to_date(datetime))} #{String.pad_leading("#{datetime.hour}", 2, "0")}:00"

  defp extract_date_period(_value, _period), do: nil

  # Step 2: Apply aggregations to each group
  defp apply_aggregations(grouped_data, []) when is_list(grouped_data) do
    # No aggregations - for simple mapping transforms
    # Return records directly with source record reference
    Enum.flat_map(grouped_data, fn {_group_key, group_records} ->
      Enum.map(group_records, fn record ->
        %{__source_record__: record}
      end)
    end)
  end

  defp apply_aggregations(grouped_data, aggregates) when is_list(aggregates) do
    Enum.map(grouped_data, fn {group_key, group_records} ->
      aggregate_results =
        Enum.reduce(aggregates, %{}, fn {agg_type, field, as_name}, acc ->
          value = calculate_aggregate(agg_type, group_records, field)
          Map.put(acc, as_name, value)
        end)

      # Combine group key with aggregate results
      # Also store first record for accessing non-aggregated fields
      base_data = if group_key, do: %{group_key: group_key}, else: %{}
      first_record = if group_records != [], do: %{__source_record__: List.first(group_records)}, else: %{}

      base_data
      |> Map.merge(aggregate_results)
      |> Map.merge(first_record)
    end)
  end

  # Step 3: Map to chart format
  defp apply_mappings(aggregated_data, mappings) when is_map(mappings) and map_size(mappings) == 0 do
    # No mappings defined, return as-is
    aggregated_data
  end

  defp apply_mappings(aggregated_data, mappings) when is_map(mappings) do
    Enum.map(aggregated_data, fn data ->
      Enum.reduce(mappings, %{}, fn {target_field, source_spec}, acc ->
        value = resolve_mapping_value(data, source_spec)
        # Convert Date to NaiveDateTime for Gantt chart time fields
        value = convert_date_for_gantt(target_field, value)
        Map.put(acc, target_field, value)
      end)
    end)
  end

  # Convert Date to NaiveDateTime for Gantt chart compatibility
  defp convert_date_for_gantt(field, %Date{} = date) when field in [:start_time, :end_time] do
    NaiveDateTime.new!(date, ~T[00:00:00])
  end
  defp convert_date_for_gantt(_field, value), do: value

  # Resolve mapping value - supports various source formats
  defp resolve_mapping_value(data, :group_key), do: Map.get(data, :group_key)

  # Simple atom field - check aggregates first, then source record
  defp resolve_mapping_value(data, source_field) when is_atom(source_field) do
    cond do
      Map.has_key?(data, source_field) -> Map.get(data, source_field)
      Map.has_key?(data, :__source_record__) -> get_field_value(data.__source_record__, source_field)
      true -> nil
    end
  end

  # Tuple with date calculation: {:field, :add_days, N}
  defp resolve_mapping_value(data, {field, :add_days, days}) when is_atom(field) and is_integer(days) do
    source_record = Map.get(data, :__source_record__)
    if source_record do
      date_value = get_field_value(source_record, field)
      add_days_to_date(date_value, days)
    else
      nil
    end
  end

  # Nested tuple path: {:product, :price}
  defp resolve_mapping_value(data, source_path) when is_tuple(source_path) do
    source_record = Map.get(data, :__source_record__)
    if source_record do
      get_field_value(source_record, source_path)
    else
      nil
    end
  end

  defp resolve_mapping_value(_data, _source_spec), do: nil

  # Helper to add days to a date - returns NaiveDateTime for Gantt chart compatibility
  defp add_days_to_date(nil, _days), do: nil
  defp add_days_to_date(%Date{} = date, days) do
    date
    |> Date.add(days)
    |> NaiveDateTime.new!(~T[00:00:00])
  end
  defp add_days_to_date(%DateTime{} = datetime, days) do
    datetime
    |> DateTime.to_date()
    |> Date.add(days)
    |> NaiveDateTime.new!(~T[00:00:00])
  end
  defp add_days_to_date(%NaiveDateTime{} = naive_datetime, days) do
    NaiveDateTime.add(naive_datetime, days * 24 * 60 * 60, :second)
  end
  defp add_days_to_date(_value, _days), do: nil

  # Step 4: Apply sorting
  defp apply_sorting(data, nil), do: data

  defp apply_sorting(data, {field, direction}) when direction in [:asc, :desc] do
    Enum.sort_by(data, &Map.get(&1, field), direction)
  end

  # Step 5: Apply limit
  defp apply_limit(data, nil), do: data
  defp apply_limit(data, limit) when is_integer(limit) and limit > 0 do
    Enum.take(data, limit)
  end

  # Aggregate Calculations

  defp calculate_aggregate(:count, records, _field) do
    length(records)
  end

  defp calculate_aggregate(:sum, records, field) do
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(0, fn value, acc ->
      add_values(acc, value)
    end)
  end

  defp calculate_aggregate(:avg, records, field) do
    values =
      records
      |> Enum.map(&get_field_value(&1, field))
      |> Enum.reject(&is_nil/1)

    case length(values) do
      0 -> 0
      count -> Enum.sum(values) / count
    end
  end

  defp calculate_aggregate(:min, records, field) do
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end

  defp calculate_aggregate(:max, records, field) do
    records
    |> Enum.map(&get_field_value(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  # Helper Functions

  # Get field value - supports both simple atoms and nested tuples
  defp get_field_value(record, field) when is_atom(field) do
    cond do
      is_map(record) -> Map.get(record, field)
      true -> nil
    end
  end

  defp get_field_value(record, field) when is_tuple(field) do
    get_nested_value(record, Tuple.to_list(field))
  end

  defp get_field_value(_record, _field), do: nil

  # Traverse nested relationships like [:product, :category, :name]
  defp get_nested_value(record, []), do: record
  defp get_nested_value(nil, _path), do: nil

  defp get_nested_value(record, [field | rest]) when is_map(record) do
    record
    |> Map.get(field)
    |> get_nested_value(rest)
  end

  defp get_nested_value(_record, _path), do: nil

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
  Extracts required relationships from a transform definition.

  Analyzes the transform to detect which relationships need to be preloaded
  based on nested field paths in group_by, aggregates, and mappings.

  ## Examples

      iex> transform = %Transform{group_by: {:product, :category, :name}}
      iex> Transform.detect_relationships(transform)
      [:product, {:product, :category}]

      iex> transform = %Transform{group_by: :status}
      iex> Transform.detect_relationships(transform)
      []
  """
  @spec detect_relationships(t() | nil) :: [atom() | tuple()]
  def detect_relationships(nil), do: []

  def detect_relationships(%__MODULE__{} = transform) do
    []
    |> detect_from_group_by(transform.group_by)
    |> detect_from_aggregates(transform.aggregates)
    |> detect_from_mappings(transform.mappings)
    |> Enum.uniq()
  end

  # Extract relationships from group_by field
  defp detect_from_group_by(acc, nil), do: acc
  defp detect_from_group_by(acc, field) when is_atom(field), do: acc

  defp detect_from_group_by(acc, field) when is_tuple(field) do
    path = Tuple.to_list(field)

    # Check if this is date grouping (e.g., {:updated_at, :day})
    if is_date_grouping?(field) do
      acc
    else
      # Build nested relationship list
      # {:product, :category, :name} → [:product, {:product, :category}]
      build_relationship_list(path) ++ acc
    end
  end

  # Extract relationships from aggregate fields
  defp detect_from_aggregates(acc, aggregates) when is_list(aggregates) do
    aggregate_rels =
      Enum.flat_map(aggregates, fn {_type, field, _as_name} ->
        case field do
          nil -> []
          field when is_atom(field) -> []
          field when is_tuple(field) -> build_relationship_list(Tuple.to_list(field))
          _ -> []
        end
      end)

    aggregate_rels ++ acc
  end

  # Extract relationships from mappings
  defp detect_from_mappings(acc, mappings) when is_map(mappings) do
    mapping_rels =
      mappings
      |> Map.values()
      |> Enum.flat_map(fn
        field when is_tuple(field) -> build_relationship_list(Tuple.to_list(field))
        _ -> []
      end)

    mapping_rels ++ acc
  end

  # Build nested relationship list from path
  # [:product, :category, :name] → [:product, {:product, :category}]
  defp build_relationship_list([]), do: []
  defp build_relationship_list([_single]), do: []

  defp build_relationship_list(path) do
    path
    |> Enum.with_index()
    |> Enum.flat_map(fn {_field, index} ->
      case Enum.slice(path, 0, index + 1) do
        [] -> []
        [single] -> [single]
        multiple -> [List.to_tuple(multiple)]
      end
    end)
    |> Enum.uniq()
  end

end
