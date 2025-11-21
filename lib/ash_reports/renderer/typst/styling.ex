defmodule AshReports.Renderer.Typst.Styling do
  @moduledoc """
  Typst text styling renderer.

  Generates Typst #text() function calls with styling parameters:
  - font_size → size: 24pt
  - font_weight → weight: "bold"
  - font_style → style: "italic"
  - color → fill: red or fill: rgb("#ff0000")
  - font_family → font: "Arial"

  ## Examples

      iex> style = %AshReports.Layout.IR.Style{font_weight: :bold}
      iex> AshReports.Renderer.Typst.Styling.apply_style("Hello", style)
      "#text(weight: \"bold\")[Hello]"

      iex> style = %AshReports.Layout.IR.Style{font_size: "14pt", color: "red"}
      iex> AshReports.Renderer.Typst.Styling.apply_style("Important", style)
      "#text(size: 14pt, fill: red)[Important]"
  """

  alias AshReports.Layout.IR.Style

  @doc """
  Applies styling to text content using Typst #text() function.

  Returns the original text if no styling is needed.

  ## Parameters

  - `text` - The text content to style
  - `style` - The StyleIR struct with styling properties

  ## Returns

  String with Typst #text() wrapper if styling is needed, or original text.
  """
  @spec apply_style(String.t(), Style.t() | nil) :: String.t()
  def apply_style(text, nil), do: text

  def apply_style(text, %Style{} = style) do
    if Style.empty?(style) do
      text
    else
      wrap_with_text(text, style)
    end
  end

  @doc """
  Wraps text with Typst #text() function for styling.

  ## Examples

      iex> style = %AshReports.Layout.IR.Style{font_weight: :bold}
      iex> wrap_with_text("Hello", style)
      "#text(weight: \"bold\")[Hello]"
  """
  @spec wrap_with_text(String.t(), Style.t()) :: String.t()
  def wrap_with_text(text, %Style{} = style) do
    params = build_style_parameters(style)

    if params == "" do
      text
    else
      "#text(#{params})[#{text}]"
    end
  end

  @doc """
  Builds Typst text() parameters from a StyleIR.

  ## Examples

      iex> style = %AshReports.Layout.IR.Style{font_size: "14pt", font_weight: :bold}
      iex> build_style_parameters(style)
      "size: 14pt, weight: \"bold\""
  """
  @spec build_style_parameters(Style.t()) :: String.t()
  def build_style_parameters(%Style{} = style) do
    params =
      []
      |> maybe_add_font_size(style)
      |> maybe_add_font_weight(style)
      |> maybe_add_font_style(style)
      |> maybe_add_color(style)
      |> maybe_add_font_family(style)
      |> Enum.reverse()

    Enum.join(params, ", ")
  end

  # Style parameter builders

  defp maybe_add_font_size(params, %Style{font_size: nil}), do: params

  defp maybe_add_font_size(params, %Style{font_size: size}) do
    ["size: #{size}" | params]
  end

  defp maybe_add_font_weight(params, %Style{font_weight: nil}), do: params

  defp maybe_add_font_weight(params, %Style{font_weight: weight}) do
    weight_str = render_font_weight(weight)
    ["weight: #{weight_str}" | params]
  end

  defp maybe_add_font_style(params, %Style{font_style: nil}), do: params
  defp maybe_add_font_style(params, %Style{font_style: :normal}), do: params

  defp maybe_add_font_style(params, %Style{font_style: :italic}) do
    ["style: \"italic\"" | params]
  end

  defp maybe_add_color(params, %Style{color: nil}), do: params

  defp maybe_add_color(params, %Style{color: color}) do
    ["fill: #{render_color(color)}" | params]
  end

  defp maybe_add_font_family(params, %Style{font_family: nil}), do: params

  defp maybe_add_font_family(params, %Style{font_family: family}) do
    ["font: \"#{family}\"" | params]
  end

  @doc """
  Renders font weight to Typst syntax.

  ## Examples

      iex> render_font_weight(:bold)
      "\"bold\""

      iex> render_font_weight(:light)
      "\"light\""

      iex> render_font_weight(400)
      "400"
  """
  @spec render_font_weight(atom() | String.t() | integer()) :: String.t()
  def render_font_weight(:normal), do: "\"regular\""
  def render_font_weight(:bold), do: "\"bold\""
  def render_font_weight(:light), do: "\"light\""
  def render_font_weight(:medium), do: "\"medium\""
  def render_font_weight(:semibold), do: "\"semibold\""
  def render_font_weight(:thin), do: "\"thin\""
  def render_font_weight(:black), do: "\"black\""
  def render_font_weight(:extrabold), do: "\"extrabold\""
  def render_font_weight(:extralight), do: "\"extralight\""
  def render_font_weight(weight) when is_integer(weight), do: "#{weight}"
  def render_font_weight(weight) when is_atom(weight), do: "\"#{weight}\""
  def render_font_weight(weight) when is_binary(weight), do: "\"#{weight}\""

  @doc """
  Renders a color value to Typst syntax.

  ## Examples

      iex> render_color("red")
      "red"

      iex> render_color("#ff0000")
      "rgb(\"#ff0000\")"

      iex> render_color(:blue)
      "blue"
  """
  @spec render_color(String.t() | atom()) :: String.t()
  def render_color(color) when is_binary(color) do
    if String.starts_with?(color, "#") do
      "rgb(\"#{color}\")"
    else
      color
    end
  end

  def render_color(color) when is_atom(color), do: Atom.to_string(color)

  @doc """
  Checks if a style has any styling properties set.

  ## Examples

      iex> has_styling?(%AshReports.Layout.IR.Style{font_weight: :bold})
      true

      iex> has_styling?(%AshReports.Layout.IR.Style{})
      false
  """
  @spec has_styling?(Style.t() | nil) :: boolean()
  def has_styling?(nil), do: false

  def has_styling?(%Style{} = style) do
    not Style.empty?(style)
  end
end
