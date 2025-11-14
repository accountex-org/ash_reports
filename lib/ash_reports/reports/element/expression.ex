defmodule AshReports.Element.Expression do
  @moduledoc """
  A calculated expression element.
  """

  defstruct [
    :name,
    :expression,
    :format,
    :position,
    :column,
    :style,
    :conditional,
    type: :expression
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :expression,
          expression: Ash.Expr.t(),
          format: any(),
          position: AshReports.Element.position(),
          column: non_neg_integer() | nil,
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Expression element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :expression]
      |> Keyword.merge(opts)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
  end
end
