defmodule AshReports.Charts.AggregateSpec do
  @moduledoc """
  Specification for an aggregate operation in a chart transform.

  Aggregates define calculations to be performed on grouped data, such as counting
  records, summing values, calculating averages, etc.

  ## Fields

  - `:type` - The type of aggregation (`:count`, `:sum`, `:avg`, `:min`, `:max`)
  - `:field` - The field to aggregate (optional for `:count`)
  - `:as` - The name to use for the aggregate result (required)

  ## Examples

      # Count aggregation
      %AggregateSpec{type: :count, field: nil, as: :total_count}

      # Sum aggregation
      %AggregateSpec{type: :sum, field: :amount, as: :total_amount}

      # Average aggregation
      %AggregateSpec{type: :avg, field: :price, as: :avg_price}
  """

  @type aggregate_type :: :count | :sum | :avg | :min | :max

  @type t :: %__MODULE__{
          type: aggregate_type(),
          field: atom() | nil,
          as: atom()
        }

  defstruct [:type, :field, :as]

  @doc """
  Creates a new aggregate specification.

  ## Parameters

    - `type` - The aggregate type
    - `field` - The field to aggregate (optional for :count)
    - `as` - The result name

  ## Examples

      AggregateSpec.new(:count, nil, :total)
      AggregateSpec.new(:sum, :amount, :total_amount)
  """
  @spec new(aggregate_type(), atom() | nil, atom()) :: t()
  def new(type, field, as) do
    %__MODULE__{
      type: type,
      field: field,
      as: as
    }
  end

  @doc """
  Converts an AggregateSpec to the tuple format used by Transform.

  ## Examples

      iex> spec = AggregateSpec.new(:sum, :amount, :total)
      iex> AggregateSpec.to_tuple(spec)
      {:sum, :amount, :total}

      iex> spec = AggregateSpec.new(:count, nil, :total)
      iex> AggregateSpec.to_tuple(spec)
      {:count, :total}
  """
  @spec to_tuple(t()) :: tuple()
  def to_tuple(%__MODULE__{type: :count, as: as}), do: {:count, as}
  def to_tuple(%__MODULE__{type: type, field: field, as: as}), do: {type, field, as}

  @doc """
  Validates an aggregate specification.

  ## Examples

      iex> spec = AggregateSpec.new(:sum, :amount, :total)
      iex> AggregateSpec.validate(spec)
      :ok

      iex> spec = AggregateSpec.new(:sum, nil, :total)
      iex> AggregateSpec.validate(spec)
      {:error, "Aggregate type :sum requires a field"}
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{type: type, field: field, as: as}) do
    cond do
      as == nil ->
        {:error, "Aggregate must have an :as name"}

      not is_atom(as) ->
        {:error, "Aggregate :as must be an atom, got: #{inspect(as)}"}

      type not in [:count, :sum, :avg, :min, :max] ->
        {:error, "Invalid aggregate type: #{inspect(type)}"}

      type != :count and field == nil ->
        {:error, "Aggregate type #{inspect(type)} requires a field"}

      field != nil and not is_atom(field) ->
        {:error, "Aggregate field must be an atom, got: #{inspect(field)}"}

      true ->
        :ok
    end
  end
end
