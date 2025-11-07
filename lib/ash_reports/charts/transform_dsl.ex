defmodule AshReports.Charts.TransformDSL do
  @moduledoc """
  DSL-based transform specification for charts.

  This module defines the structure for declarative chart transformations using
  Spark DSL syntax. It replaces the map-based transform syntax with a more
  structured, compile-time validated approach.

  ## Structure

  A TransformDSL defines how to transform data for chart rendering:

  - Filtering: Pre-aggregation filters
  - Grouping: Group data by fields or date periods
  - Aggregation: Calculate metrics (count, sum, avg, min, max)
  - Mapping: Map transformed data to chart fields
  - Sorting: Order results
  - Limiting: Restrict number of results

  ## Examples

      # Simple pie chart transform
      %TransformDSL{
        group_by: :status,
        aggregates: [%AggregateSpec{type: :count, as: :total}],
        mappings: %{category: :group_key, value: :total}
      }

      # Line chart with date grouping and filtering
      %TransformDSL{
        filters: %{status: :paid},
        group_by: {:created_at, :month},
        aggregates: [%AggregateSpec{type: :sum, field: :amount, as: :revenue}],
        mappings: %{x: :group_key, y: :revenue},
        sort_by: {:x, :asc}
      }

      # Gantt chart with special mappings
      %TransformDSL{
        filters: %{status: [:sent, :paid, :overdue]},
        mappings: %{
          task: :invoice_number,
          start_date: :date,
          end_date: {:date, :add_days, 30}
        },
        sort_by: {:date, :desc},
        limit: 20
      }
  """

  alias AshReports.Charts.{AggregateSpec, Transform}

  alias AshReports.Charts.FilterSpec

  @type group_by_spec :: atom() | tuple()
  @type sort_spec :: {atom(), :asc | :desc} | atom()

  @type t :: %__MODULE__{
          # Collections
          filters: [FilterSpec.t()],
          aggregates: [AggregateSpec.t()],
          # Single values
          group_by: group_by_spec() | nil,
          sort_by: sort_spec() | nil,
          limit: pos_integer() | nil,
          # Mappings
          as_category: atom() | tuple() | nil,
          as_value: atom() | nil,
          as_x: atom() | tuple() | nil,
          as_y: atom() | nil,
          as_task: atom() | tuple() | nil,
          as_start_date: atom() | tuple() | nil,
          as_end_date: atom() | tuple() | nil,
          as_values: atom() | nil
        }

  defstruct filters: [],
            aggregates: [],
            group_by: nil,
            sort_by: nil,
            limit: nil,
            as_category: nil,
            as_value: nil,
            as_x: nil,
            as_y: nil,
            as_task: nil,
            as_start_date: nil,
            as_end_date: nil,
            as_values: nil

  @doc """
  Converts a TransformDSL to a Transform struct for execution.

  This function translates the DSL representation into the internal Transform
  structure used by the chart pipeline.

  ## Examples

      iex> dsl = %TransformDSL{
      ...>   group_by: :status,
      ...>   aggregates: [AggregateSpec.new(:count, nil, :total)]
      ...> }
      iex> {:ok, transform} = TransformDSL.to_transform(dsl)
      iex> transform.group_by
      :status
  """
  @spec to_transform(t()) :: {:ok, Transform.t()} | {:error, term()}
  def to_transform(%__MODULE__{} = dsl) do
    with :ok <- validate(dsl) do
      # Convert filters list to map
      filters_map =
        dsl.filters
        |> Enum.map(&FilterSpec.to_tuple/1)
        |> Map.new()

      # Build mappings map from individual fields
      mappings =
        %{}
        |> maybe_put_mapping(:category, dsl.as_category)
        |> maybe_put_mapping(:value, dsl.as_value)
        |> maybe_put_mapping(:x, dsl.as_x)
        |> maybe_put_mapping(:y, dsl.as_y)
        |> maybe_put_mapping(:task, dsl.as_task)
        |> maybe_put_mapping(:start_date, dsl.as_start_date)
        |> maybe_put_mapping(:end_date, dsl.as_end_date)
        |> maybe_put_mapping(:values, dsl.as_values)

      transform = %Transform{
        filters: filters_map,
        group_by: dsl.group_by,
        aggregates: Enum.map(dsl.aggregates, &AggregateSpec.to_tuple/1),
        mappings: mappings,
        sort_by: dsl.sort_by,
        limit: dsl.limit
      }

      {:ok, transform}
    end
  end

  defp maybe_put_mapping(map, _key, nil), do: map
  defp maybe_put_mapping(map, key, value), do: Map.put(map, key, value)

  @doc """
  Validates a TransformDSL specification.

  Checks that all fields are valid and consistent:
  - Filters are properly specified
  - Aggregates are properly specified
  - Limit is positive

  ## Examples

      iex> dsl = %TransformDSL{group_by: :status}
      iex> TransformDSL.validate(dsl)
      :ok

      iex> dsl = %TransformDSL{limit: -1}
      iex> TransformDSL.validate(dsl)
      {:error, "Limit must be a positive integer, got: -1"}
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = dsl) do
    with :ok <- validate_filters(dsl.filters),
         :ok <- validate_group_by(dsl.group_by),
         :ok <- validate_aggregates(dsl.aggregates),
         :ok <- validate_sort_by(dsl.sort_by),
         :ok <- validate_limit(dsl.limit) do
      :ok
    end
  end

  defp validate_filters(filters) when is_list(filters) do
    filters
    |> Enum.reduce_while(:ok, fn filter, :ok ->
      case FilterSpec.validate(filter) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_filters(filters), do: {:error, "Filters must be a list, got: #{inspect(filters)}"}

  defp validate_group_by(nil), do: :ok
  defp validate_group_by(field) when is_atom(field), do: :ok

  defp validate_group_by(tuple) when is_tuple(tuple) do
    # Date grouping like {:created_at, :month} or nested path like {:product, :category}
    :ok
  end

  defp validate_group_by(group_by),
    do: {:error, "Invalid group_by: #{inspect(group_by)}"}

  defp validate_aggregates(aggregates) when is_list(aggregates) do
    aggregates
    |> Enum.reduce_while(:ok, fn agg, :ok ->
      case AggregateSpec.validate(agg) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_aggregates(aggregates),
    do: {:error, "Aggregates must be a list, got: #{inspect(aggregates)}"}

  defp validate_sort_by(nil), do: :ok
  defp validate_sort_by({field, direction}) when is_atom(field) and direction in [:asc, :desc], do: :ok
  defp validate_sort_by(field) when is_atom(field), do: :ok
  defp validate_sort_by(sort), do: {:error, "Invalid sort_by: #{inspect(sort)}"}

  defp validate_limit(nil), do: :ok
  defp validate_limit(limit) when is_integer(limit) and limit > 0, do: :ok

  defp validate_limit(limit),
    do: {:error, "Limit must be a positive integer, got: #{inspect(limit)}"}

  @doc """
  Creates a new TransformDSL with default values.

  ## Examples

      iex> TransformDSL.new()
      %TransformDSL{filters: %{}, aggregates: [], mappings: %{}}
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Adds a filter to the transform.

  ## Examples

      iex> dsl = TransformDSL.new()
      iex> dsl = TransformDSL.add_filter(dsl, :status, :active)
      iex> length(dsl.filters)
      1
  """
  @spec add_filter(t(), atom(), term()) :: t()
  def add_filter(%__MODULE__{} = dsl, field, value) do
    filter = FilterSpec.new(field, value)
    %{dsl | filters: dsl.filters ++ [filter]}
  end

  @doc """
  Adds an aggregate to the transform.

  ## Examples

      iex> dsl = TransformDSL.new()
      iex> agg = AggregateSpec.new(:count, nil, :total)
      iex> dsl = TransformDSL.add_aggregate(dsl, agg)
      iex> length(dsl.aggregates)
      1
  """
  @spec add_aggregate(t(), AggregateSpec.t()) :: t()
  def add_aggregate(%__MODULE__{} = dsl, %AggregateSpec{} = aggregate) do
    %{dsl | aggregates: dsl.aggregates ++ [aggregate]}
  end

  @doc """
  Sets a mapping field on the transform.

  ## Examples

      iex> dsl = TransformDSL.new()
      iex> dsl = TransformDSL.set_mapping(dsl, :as_category, :group_key)
      iex> dsl.as_category
      :group_key
  """
  @spec set_mapping(t(), atom(), atom() | tuple()) :: t()
  def set_mapping(%__MODULE__{} = dsl, :as_category, value), do: %{dsl | as_category: value}
  def set_mapping(%__MODULE__{} = dsl, :as_value, value), do: %{dsl | as_value: value}
  def set_mapping(%__MODULE__{} = dsl, :as_x, value), do: %{dsl | as_x: value}
  def set_mapping(%__MODULE__{} = dsl, :as_y, value), do: %{dsl | as_y: value}
  def set_mapping(%__MODULE__{} = dsl, :as_task, value), do: %{dsl | as_task: value}
  def set_mapping(%__MODULE__{} = dsl, :as_start_date, value), do: %{dsl | as_start_date: value}
  def set_mapping(%__MODULE__{} = dsl, :as_end_date, value), do: %{dsl | as_end_date: value}
  def set_mapping(%__MODULE__{} = dsl, :as_values, value), do: %{dsl | as_values: value}
end
