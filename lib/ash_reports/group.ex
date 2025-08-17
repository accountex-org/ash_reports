defmodule AshReports.Group do
  @moduledoc """
  Represents a grouping level for report data.

  Groups define how data should be organized hierarchically in the report,
  with support for multi-level grouping.
  """

  defstruct [
    :name,
    :level,
    :expression,
    :sort
  ]

  @type t :: %__MODULE__{
          name: atom(),
          level: pos_integer(),
          expression: Ash.Expr.t(),
          sort: :asc | :desc
        }

  @doc """
  Creates a new Group struct with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:sort, :asc)
    )
  end

  @doc """
  Compares two values according to the group's sort order.
  """
  @spec compare(t(), any(), any()) :: :lt | :eq | :gt
  def compare(%__MODULE__{sort: :asc}, val1, val2) do
    cond do
      val1 < val2 -> :lt
      val1 > val2 -> :gt
      true -> :eq
    end
  end

  def compare(%__MODULE__{sort: :desc}, val1, val2) do
    cond do
      val1 < val2 -> :gt
      val1 > val2 -> :lt
      true -> :eq
    end
  end
end
