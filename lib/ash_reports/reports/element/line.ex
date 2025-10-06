defmodule AshReports.Element.Line do
  @moduledoc """
  A line separator element.
  """

  defstruct [
    :name,
    :orientation,
    :thickness,
    :position,
    :style,
    :conditional,
    type: :line
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :line,
          orientation: :horizontal | :vertical,
          thickness: pos_integer(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Creates a new Line element with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name, type: :line]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:orientation, :horizontal)
      |> Keyword.put_new(:thickness, 1)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
  end
end
