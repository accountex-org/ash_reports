defmodule AshReports.Element.Aggregate do
  @moduledoc """
  An aggregate calculation element.
  """

  defstruct [
    :name,
    :function,
    :source,
    :scope,
    :format,
    :position,
    :column,
    :style,
    :conditional,
    type: :aggregate
  ]

  @type aggregate_function :: :sum | :count | :average | :min | :max
  @type aggregate_scope :: :band | :group | :page | :report

  @type t :: %__MODULE__{
          name: atom(),
          type: :aggregate,
          function: aggregate_function(),
          source: Ash.Expr.t() | atom() | list(atom()),
          scope: aggregate_scope(),
          format: any(),
          position: AshReports.Element.position(),
          column: non_neg_integer() | nil,
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Aggregate element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :aggregate]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:scope, :band)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
  end
end
