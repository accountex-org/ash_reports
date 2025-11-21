defmodule AshReports.Layout.IR.Style do
  @moduledoc """
  Intermediate Representation for styling properties.

  StyleIR contains normalized styling information that can be applied
  to labels, fields, and other content elements.

  ## Examples

      style = AshReports.Layout.IR.Style.new(
        font_size: "12pt",
        font_weight: :bold,
        color: "#333333",
        font_family: "Helvetica"
      )
  """

  @type font_weight :: :normal | :bold | :light | :medium | :semibold

  @type t :: %__MODULE__{
          font_size: String.t() | nil,
          font_weight: font_weight() | nil,
          font_style: :normal | :italic | nil,
          color: String.t() | nil,
          background_color: String.t() | nil,
          font_family: String.t() | nil,
          text_align: :left | :center | :right | :justify | nil,
          vertical_align: :top | :middle | :bottom | nil,
          padding: String.t() | nil,
          border: String.t() | nil
        }

  defstruct [
    :font_size,
    :font_weight,
    :font_style,
    :color,
    :background_color,
    :font_family,
    :text_align,
    :vertical_align,
    :padding,
    :border
  ]

  @doc """
  Creates a new StyleIR struct with the given options.

  ## Options

  - `:font_size` - Font size (e.g., "12pt", "1em")
  - `:font_weight` - Font weight (:normal, :bold, :light, etc.)
  - `:font_style` - Font style (:normal, :italic)
  - `:color` - Text color (e.g., "#333333", "red")
  - `:background_color` - Background color
  - `:font_family` - Font family name
  - `:text_align` - Horizontal text alignment
  - `:vertical_align` - Vertical text alignment
  - `:padding` - Padding value
  - `:border` - Border specification

  ## Examples

      iex> AshReports.Layout.IR.Style.new(font_size: "14pt", font_weight: :bold)
      %AshReports.Layout.IR.Style{font_size: "14pt", font_weight: :bold, ...}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      font_size: Keyword.get(opts, :font_size),
      font_weight: Keyword.get(opts, :font_weight),
      font_style: Keyword.get(opts, :font_style),
      color: Keyword.get(opts, :color),
      background_color: Keyword.get(opts, :background_color),
      font_family: Keyword.get(opts, :font_family),
      text_align: Keyword.get(opts, :text_align),
      vertical_align: Keyword.get(opts, :vertical_align),
      padding: Keyword.get(opts, :padding),
      border: Keyword.get(opts, :border)
    }
  end

  @doc """
  Merges two styles, with the second style taking precedence.

  Only non-nil values from the second style override the first.

  ## Examples

      iex> base = AshReports.Layout.IR.Style.new(font_size: "12pt", color: "black")
      iex> override = AshReports.Layout.IR.Style.new(color: "red")
      iex> AshReports.Layout.IR.Style.merge(base, override)
      %AshReports.Layout.IR.Style{font_size: "12pt", color: "red", ...}
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = override) do
    base
    |> Map.from_struct()
    |> Enum.map(fn {key, value} ->
      override_value = Map.get(override, key)
      {key, override_value || value}
    end)
    |> then(&struct(__MODULE__, &1))
  end

  @doc """
  Returns true if the style has any non-nil values.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{} = style) do
    style
    |> Map.from_struct()
    |> Map.values()
    |> Enum.all?(&is_nil/1)
  end
end
