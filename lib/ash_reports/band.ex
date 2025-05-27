defmodule AshReports.Band do
  @moduledoc """
  Represents a band within a report structure.
  
  Bands are the fundamental building blocks of reports and can be hierarchically nested.
  They contain elements that define what data and formatting to display.
  """

  defstruct [
    :name,
    :type,
    :group_level,
    :detail_number,
    :target_alias,
    :on_entry,
    :on_exit,
    :height,
    :can_grow,
    :can_shrink,
    :keep_together,
    :visible,
    :elements,
    :bands
  ]

  @type band_type ::
          :title
          | :page_header
          | :column_header
          | :group_header
          | :detail_header
          | :detail
          | :detail_footer
          | :group_footer
          | :column_footer
          | :page_footer
          | :summary

  @type t :: %__MODULE__{
          name: atom(),
          type: band_type(),
          group_level: pos_integer() | nil,
          detail_number: pos_integer() | nil,
          target_alias: Ash.Expr.t() | nil,
          on_entry: Ash.Expr.t() | nil,
          on_exit: Ash.Expr.t() | nil,
          height: pos_integer() | nil,
          can_grow: boolean(),
          can_shrink: boolean(),
          keep_together: boolean(),
          visible: Ash.Expr.t() | boolean(),
          elements: [AshReports.Element.t()],
          bands: [t()] | nil
        }

  @doc """
  Creates a new Band struct with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:can_grow, true)
      |> Keyword.put_new(:can_shrink, false)
      |> Keyword.put_new(:keep_together, false)
      |> Keyword.put_new(:visible, true)
      |> Keyword.put_new(:elements, [])
    )
  end

  @doc """
  Gets the element with the given name from the band.
  """
  @spec get_element(t(), atom()) :: AshReports.Element.t() | nil
  def get_element(%__MODULE__{elements: elements}, name) do
    Enum.find(elements, &(&1.name == name))
  end

  @doc """
  Gets all elements of a specific type from the band.
  """
  @spec get_elements_by_type(t(), atom()) :: [AshReports.Element.t()]
  def get_elements_by_type(%__MODULE__{elements: elements}, type) do
    Enum.filter(elements, &(&1.type == type))
  end

  @doc """
  Checks if this is a group band (group_header or group_footer).
  """
  @spec group_band?(t()) :: boolean()
  def group_band?(%__MODULE__{type: type}) do
    type in [:group_header, :group_footer]
  end

  @doc """
  Checks if this is a detail band type.
  """
  @spec detail_band?(t()) :: boolean()
  def detail_band?(%__MODULE__{type: type}) do
    type in [:detail_header, :detail, :detail_footer]
  end

  @doc """
  Gets all child bands recursively.
  """
  @spec all_bands(t()) :: [t()]
  def all_bands(%__MODULE__{bands: nil}), do: []
  def all_bands(%__MODULE__{bands: bands}) do
    Enum.flat_map(bands, fn band ->
      [band | all_bands(band)]
    end)
  end
end