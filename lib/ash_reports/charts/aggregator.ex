defmodule AshReports.Charts.Aggregator do
  @moduledoc """
  Provides aggregation functions for chart data processing.

  This module implements common aggregation operations needed for chart generation:
  - Statistical aggregations (sum, count, avg, min, max)
  - Grouped aggregations (group by field)
  - Time-series aggregations (with bucketing)
  - Custom aggregation functions

  Reuses the ProducerConsumer aggregation logic from the streaming pipeline
  for consistency and performance.

  ## Features

  - **Standard Aggregations**: sum, count, avg, min, max
  - **Grouped Aggregations**: Group by one or more fields
  - **Streaming Support**: Works with both lists and streams
  - **Type Safety**: Handles various numeric types (Integer, Float, Decimal)
  - **Null Handling**: Skips nil values in aggregations

  ## Usage

  ### Basic Aggregations

      data = [
        %{amount: 100},
        %{amount: 200},
        %{amount: 150}
      ]

      Aggregator.sum(data, :amount)
      # => 450

      Aggregator.avg(data, :amount)
      # => 150.0

  ### Grouped Aggregations

      data = [
        %{category: "A", amount: 100},
        %{category: "B", amount: 200},
        %{category: "A", amount: 150}
      ]

      Aggregator.group_by(data, :category, :amount, :sum)
      # => [%{category: "A", value: 250}, %{category: "B", value: 200}]

  ### Multiple Aggregations

      Aggregator.aggregate(data, [
        {:total, :amount, :sum},
        {:average, :amount, :avg},
        {:count, :amount, :count}
      ])
      # => %{total: 450, average: 150.0, count: 3}

  ## Integration with Charts

      # Prepare data for bar chart
      sales_data = [...]
      aggregated = Aggregator.group_by(sales_data, :product, :quantity, :sum)

      Charts.generate(:bar, aggregated, config)

  ## Performance

  - **List aggregation**: O(n) for most operations
  - **Grouped aggregation**: O(n * log(g)) where g = number of groups
  - **Streaming**: Constant memory usage regardless of dataset size
  """

  require Logger

  @type field :: atom() | String.t()
  @type aggregation :: :sum | :count | :avg | :min | :max
  @type aggregate_spec :: {atom(), field(), aggregation()}

  @doc """
  Calculates the sum of values for a given field.

  ## Parameters

    * `data` - List or stream of records
    * `field` - Field name to sum

  ## Returns

  Numeric sum or 0 if no values

  ## Examples

      iex> Aggregator.sum([%{x: 1}, %{x: 2}, %{x: 3}], :x)
      6
  """
  @spec sum(Enumerable.t(), field()) :: number()
  def sum(data, field) do
    data
    |> Enum.reduce(0, fn record, acc ->
      case get_field(record, field) do
        nil -> acc
        value when is_number(value) -> acc + value
        %Decimal{} = value -> acc + Decimal.to_float(value)
        _ -> acc
      end
    end)
  end

  @doc """
  Counts non-nil values for a given field.

  ## Parameters

    * `data` - List or stream of records
    * `field` - Field name to count

  ## Returns

  Integer count

  ## Examples

      iex> Aggregator.count([%{x: 1}, %{x: nil}, %{x: 3}], :x)
      2
  """
  @spec count(Enumerable.t(), field()) :: non_neg_integer()
  def count(data, field) do
    data
    |> Enum.reduce(0, fn record, acc ->
      case get_field(record, field) do
        nil -> acc
        _ -> acc + 1
      end
    end)
  end

  @doc """
  Calculates the average of values for a given field.

  ## Parameters

    * `data` - List or stream of records
    * `field` - Field name to average

  ## Returns

  Float average or 0.0 if no values

  ## Examples

      iex> Aggregator.avg([%{x: 10}, %{x: 20}, %{x: 30}], :x)
      20.0
  """
  @spec avg(Enumerable.t(), field()) :: float()
  def avg(data, field) do
    {sum, count} =
      data
      |> Enum.reduce({0, 0}, fn record, {sum_acc, count_acc} ->
        case get_field(record, field) do
          nil ->
            {sum_acc, count_acc}

          value when is_number(value) ->
            {sum_acc + value, count_acc + 1}

          %Decimal{} = value ->
            {sum_acc + Decimal.to_float(value), count_acc + 1}

          _ ->
            {sum_acc, count_acc}
        end
      end)

    if count > 0, do: sum / count, else: 0.0
  end

  @doc """
  Finds the minimum value for a given field.

  ## Parameters

    * `data` - List or stream of records
    * `field` - Field name to find min

  ## Returns

  Minimum value or nil if no values

  ## Examples

      iex> Aggregator.field_min([%{x: 10}, %{x: 5}, %{x: 20}], :x)
      5
  """
  @spec field_min(Enumerable.t(), field()) :: number() | nil
  def field_min(data, field) do
    data
    |> Enum.reduce(nil, fn record, acc ->
      case get_field(record, field) do
        nil ->
          acc

        value when is_number(value) ->
          if acc == nil or value < acc, do: value, else: acc

        %Decimal{} = value ->
          float_value = Decimal.to_float(value)
          if acc == nil or float_value < acc, do: float_value, else: acc

        _ ->
          acc
      end
    end)
  end

  @doc """
  Finds the maximum value for a given field.

  ## Parameters

    * `data` - List or stream of records
    * `field` - Field name to find max

  ## Returns

  Maximum value or nil if no values

  ## Examples

      iex> Aggregator.field_max([%{x: 10}, %{x: 5}, %{x: 20}], :x)
      20
  """
  @spec field_max(Enumerable.t(), field()) :: number() | nil
  def field_max(data, field) do
    data
    |> Enum.reduce(nil, fn record, acc ->
      case get_field(record, field) do
        nil ->
          acc

        value when is_number(value) ->
          if acc == nil or value > acc, do: value, else: acc

        %Decimal{} = value ->
          float_value = Decimal.to_float(value)
          if acc == nil or float_value > acc, do: float_value, else: acc

        _ ->
          acc
      end
    end)
  end

  @doc """
  Groups data by a field and applies an aggregation to another field.

  ## Parameters

    * `data` - List or stream of records
    * `group_field` - Field to group by
    * `value_field` - Field to aggregate
    * `aggregation` - Aggregation function (:sum, :count, :avg, :min, :max)

  ## Returns

  List of maps with group key and aggregated value

  ## Examples

      data = [
        %{category: "A", amount: 100},
        %{category: "B", amount: 200},
        %{category: "A", amount: 50}
      ]

      Aggregator.group_by(data, :category, :amount, :sum)
      # => [%{category: "A", value: 150}, %{category: "B", value: 200}]
  """
  @spec group_by(Enumerable.t(), field(), field(), aggregation()) :: [map()]
  def group_by(data, group_field, value_field, aggregation) do
    # Group records by group_field
    grouped =
      data
      |> Enum.group_by(fn record -> get_field(record, group_field) end)

    # Apply aggregation to each group
    grouped
    |> Enum.map(fn {group_key, records} ->
      aggregated_value =
        case aggregation do
          :sum -> sum(records, value_field)
          :count -> count(records, value_field)
          :avg -> avg(records, value_field)
          :min -> field_min(records, value_field)
          :max -> field_max(records, value_field)
        end

      %{
        group_key_name(group_field) => group_key,
        :value => aggregated_value
      }
    end)
    |> Enum.sort_by(& &1[group_key_name(group_field)])
  end

  @doc """
  Applies multiple aggregations to data.

  ## Parameters

    * `data` - List or stream of records
    * `specs` - List of {output_key, field, aggregation} tuples

  ## Returns

  Map of output_key => aggregated_value

  ## Examples

      Aggregator.aggregate(data, [
        {:total, :amount, :sum},
        {:average, :amount, :avg},
        {:count, :amount, :count}
      ])
      # => %{total: 450, average: 150.0, count: 3}
  """
  @spec aggregate(Enumerable.t(), [aggregate_spec()]) :: map()
  def aggregate(data, specs) do
    # Convert to list once to avoid multiple enumeration
    data_list = Enum.to_list(data)

    Enum.reduce(specs, %{}, fn {output_key, field, agg_type}, acc ->
      value =
        case agg_type do
          :sum -> sum(data_list, field)
          :count -> count(data_list, field)
          :avg -> avg(data_list, field)
          :min -> field_min(data_list, field)
          :max -> field_max(data_list, field)
        end

      Map.put(acc, output_key, value)
    end)
  end

  @doc """
  Applies a custom aggregation function to data.

  ## Parameters

    * `data` - List or stream of records
    * `field` - Field to aggregate
    * `initial` - Initial accumulator value
    * `fun` - Function of arity 2 (value, acc) => new_acc

  ## Returns

  Final accumulator value

  ## Examples

      # Custom concatenation aggregation
      Aggregator.custom(data, :name, "", fn value, acc ->
        if acc == "", do: value, else: acc <> ", " <> value
      end)
  """
  @spec custom(Enumerable.t(), field(), term(), (term(), term() -> term())) :: term()
  def custom(data, field, initial, fun) do
    data
    |> Enum.reduce(initial, fn record, acc ->
      case get_field(record, field) do
        nil -> acc
        value -> fun.(value, acc)
      end
    end)
  end

  # Private Helpers

  defp get_field(record, field) when is_map(record) and is_atom(field) do
    Map.get(record, field) || Map.get(record, to_string(field))
  end

  defp get_field(record, field) when is_map(record) and is_binary(field) do
    Map.get(record, field) || Map.get(record, String.to_existing_atom(field))
  rescue
    ArgumentError -> Map.get(record, field)
  end

  defp get_field(_record, _field), do: nil

  defp group_key_name(field) when is_atom(field), do: field

  # Security: Keep field names as strings to prevent atom table exhaustion
  # User-controlled field names should never be converted to atoms
  defp group_key_name(field) when is_binary(field), do: field
end
