defmodule AshReports.Charts.FilterSpec do
  @moduledoc """
  Specification for a filter condition in a chart transform.

  Filters are applied before grouping and aggregation to limit the data
  being processed.

  ## Fields

  - `:field` - The field name to filter on
  - `:value` - The value or list of values to match

  ## Examples

      # Simple equality filter
      %FilterSpec{field: :status, value: :active}

      # List membership filter
      %FilterSpec{field: :status, value: [:sent, :paid, :overdue]}
  """

  @type t :: %__MODULE__{
          field: atom(),
          value: term()
        }

  defstruct [:field, :value]

  @doc """
  Creates a new filter specification.

  ## Parameters

    - `field` - The field name
    - `value` - The filter value

  ## Examples

      FilterSpec.new(:status, :active)
      FilterSpec.new(:region, ["CA", "NY"])
  """
  @spec new(atom(), term()) :: t()
  def new(field, value) do
    %__MODULE__{
      field: field,
      value: value
    }
  end

  @doc """
  Converts a FilterSpec to a tuple for use in Transform filters map.

  ## Examples

      iex> spec = FilterSpec.new(:status, :active)
      iex> FilterSpec.to_tuple(spec)
      {:status, :active}
  """
  @spec to_tuple(t()) :: {atom(), term()}
  def to_tuple(%__MODULE__{field: field, value: value}) do
    {field, value}
  end

  @doc """
  Validates a filter specification.

  ## Examples

      iex> spec = FilterSpec.new(:status, :active)
      iex> FilterSpec.validate(spec)
      :ok

      iex> spec = FilterSpec.new(nil, :active)
      iex> FilterSpec.validate(spec)
      {:error, "Filter field must be an atom"}
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{field: field, value: value}) do
    cond do
      field == nil ->
        {:error, "Filter must have a field"}

      not is_atom(field) ->
        {:error, "Filter field must be an atom"}

      value == nil ->
        {:error, "Filter must have a value"}

      true ->
        :ok
    end
  end
end
