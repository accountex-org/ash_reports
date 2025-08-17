defmodule AshReports.Element.Image do
  @moduledoc """
  An image element.
  """

  defstruct [
    :name,
    :source,
    :scale_mode,
    :position,
    :style,
    :conditional,
    type: :image
  ]

  @type scale_mode :: :fit | :fill | :stretch | :none

  @type t :: %__MODULE__{
          name: atom(),
          type: :image,
          source: String.t() | Ash.Expr.t(),
          scale_mode: scale_mode(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Image element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :image]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:scale_mode, :fit)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
  end
end
