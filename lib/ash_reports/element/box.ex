defmodule AshReports.Element.Box do
  @moduledoc """
  A box container element.
  """

  defstruct [
    :name,
    :border,
    :fill,
    :position,
    :style,
    :conditional,
    type: :box
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :box,
          border: map(),
          fill: map(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Box element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :box]
      |> Keyword.merge(opts)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:border, %{}, &process_border/1)
    |> Keyword.update(:fill, %{}, &process_fill/1)
  end

  defp process_border(border) when is_list(border), do: Map.new(border)
  defp process_border(border) when is_map(border), do: border
  defp process_border(_), do: %{}

  defp process_fill(fill) when is_list(fill), do: Map.new(fill)
  defp process_fill(fill) when is_map(fill), do: fill
  defp process_fill(_), do: %{}
end