defmodule AshReports.Element.Field do
  @moduledoc """
  A data field element that displays resource attributes.
  """

  defstruct [
    :name,
    :source,
    :format,
    :position,
    :style,
    :padding,
    :margin,
    :spacing_before,
    :spacing_after,
    :align,
    :decimal_places,
    :number_format,
    :conditional,
    type: :field
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :field,
          source: Ash.Expr.t() | atom() | list(atom()),
          format: any(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          padding: String.t() | Keyword.t() | nil,
          margin: String.t() | Keyword.t() | nil,
          spacing_before: String.t() | nil,
          spacing_after: String.t() | nil,
          align: atom() | nil,
          decimal_places: integer() | nil,
          number_format: Keyword.t() | nil,
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Field element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :field]
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
