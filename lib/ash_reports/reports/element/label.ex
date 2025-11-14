defmodule AshReports.Element.Label do
  @moduledoc """
  A static text label element.
  """

  defstruct [
    :name,
    :text,
    :position,
    :column,
    :style,
    :conditional,
    type: :label
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :label,
          text: String.t(),
          position: AshReports.Element.position(),
          column: non_neg_integer() | nil,
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Label element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :label]
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
