defmodule AshReports.Element do
  @moduledoc """
  Base module for report elements.
  
  Elements are the visual components within bands that display data, labels,
  lines, boxes, images, etc.
  """

  @type element_type :: :field | :label | :expression | :aggregate | :line | :box | :image

  @type position :: %{
          optional(:x) => number(),
          optional(:y) => number(),
          optional(:width) => number(),
          optional(:height) => number()
        }

  @type style :: %{
          optional(:font) => String.t(),
          optional(:font_size) => number(),
          optional(:font_weight) => :normal | :bold,
          optional(:font_style) => :normal | :italic,
          optional(:text_align) => :left | :center | :right | :justify,
          optional(:vertical_align) => :top | :middle | :bottom,
          optional(:color) => String.t(),
          optional(:background_color) => String.t(),
          optional(:border) => map(),
          optional(:padding) => number() | map(),
          optional(:margin) => number() | map()
        }

  @type t :: %{
          __struct__: module(),
          name: atom(),
          type: element_type(),
          position: position(),
          style: style(),
          conditional: Ash.Expr.t() | nil
        }

  @doc """
  Gets the type of the element.
  """
  @spec type(t()) :: element_type()
  def type(%{type: type}), do: type

  @doc """
  Checks if the element should be displayed based on its conditional expression.
  """
  @spec visible?(t(), map()) :: boolean()
  def visible?(%{conditional: nil}, _context), do: true
  def visible?(%{conditional: expr}, context) do
    # This would be evaluated by the rendering engine with the actual context
    # For now, we'll just return true as a placeholder
    # In the real implementation, this would use Ash expression evaluation
    true
  end

  @doc """
  Merges position properties with defaults.
  """
  @spec merge_position(map(), map()) :: map()
  def merge_position(position, defaults) do
    Map.merge(defaults, position)
  end

  @doc """
  Merges style properties with defaults.
  """
  @spec merge_style(map(), map()) :: map()
  def merge_style(style, defaults) do
    Map.merge(defaults, style)
  end

  @doc """
  Converts a keyword list to a map for position/style properties.
  """
  @spec keyword_to_map(Keyword.t()) :: map()
  def keyword_to_map(keyword) when is_list(keyword) do
    Map.new(keyword)
  end
  def keyword_to_map(map) when is_map(map), do: map
  def keyword_to_map(_), do: %{}
end