defmodule AshReports.Renderer.Html.Styling do
  @moduledoc """
  CSS property mapping utilities for HTML rendering.

  This module provides centralized functions for mapping IR properties to CSS.
  It consolidates all CSS mapping logic for reuse across Grid, Table, Stack,
  Cell, and Content renderers.

  ## Track Size Mapping

  Maps track sizes to CSS grid-template-columns/rows:
  - `:auto` → `auto`
  - `{:fr, n}` → `nfr`
  - `"100pt"` → `100px` (unit conversion)
  - `"20%"` → `20%` (pass through)

  ## Alignment Mapping

  Maps alignment values to CSS properties:
  - `:left/:center/:right` → `text-align`
  - `:top/:middle/:bottom` → `vertical-align`
  - `{:left, :top}` → both axes

  ## Color and Fill Mapping

  Maps colors and fills to CSS:
  - `"#ffffff"` → pass through
  - `:red` → `red`
  - `:none` → `transparent`

  ## Stroke Mapping

  Maps strokes to CSS borders:
  - `:none` → no border
  - `"1pt"` → `1px solid currentColor`
  - `%{thickness: "1pt", paint: "#000"}` → `1px solid #000`
  - `%{thickness: "1pt", dash: :dashed}` → `1px dashed currentColor`
  """

  #############################################################################
  # Public API
  #############################################################################

  # Track Size Mapping

  @doc """
  Renders a track size to CSS syntax.

  ## Examples

      iex> render_track_size(:auto)
      "auto"

      iex> render_track_size({:fr, 2})
      "2fr"

      iex> render_track_size("100pt")
      "100pt"

      iex> render_track_size(50)
      "50px"
  """
  @spec render_track_size(atom() | tuple() | String.t() | number()) :: String.t()
  def render_track_size(:auto), do: "auto"
  def render_track_size("auto"), do: "auto"
  def render_track_size({:fr, n}), do: "#{n}fr"
  def render_track_size({:minmax, min, max}), do: "minmax(#{render_track_size(min)}, #{render_track_size(max)})"
  def render_track_size({:min_content}), do: "min-content"
  def render_track_size({:max_content}), do: "max-content"
  def render_track_size({:fit_content, size}), do: "fit-content(#{render_length(size)})"
  def render_track_size(size) when is_binary(size), do: sanitize_css_value(size)
  def render_track_size(size) when is_number(size), do: "#{size}px"

  @doc """
  Renders a list of track sizes to a space-separated CSS string.

  ## Examples

      iex> render_track_sizes(["1fr", "2fr", :auto])
      "1fr 2fr auto"

      iex> render_track_sizes([{:fr, 1}, "100pt", :auto])
      "1fr 100pt auto"
  """
  @spec render_track_sizes(list()) :: String.t()
  def render_track_sizes(tracks) when is_list(tracks) do
    Enum.map_join(tracks, " ", &render_track_size/1)
  end

  # Length Mapping

  @doc """
  Renders a length value to CSS syntax.

  Converts pt to px automatically (1:1 for simplicity).

  ## Examples

      iex> render_length("10pt")
      "10px"

      iex> render_length("20px")
      "20px"

      iex> render_length(15)
      "15px"

      iex> render_length(:auto)
      "auto"
  """
  @spec render_length(atom() | String.t() | number()) :: String.t()
  def render_length(:auto), do: "auto"
  def render_length("auto"), do: "auto"

  def render_length(length) when is_binary(length) do
    result = if String.ends_with?(length, "pt") do
      String.replace(length, "pt", "px")
    else
      length
    end
    sanitize_css_value(result)
  end

  def render_length(length) when is_number(length), do: "#{length}px"

  # Alignment Mapping

  @doc """
  Renders horizontal alignment to CSS text-align value.

  ## Examples

      iex> render_text_align(:left)
      "left"

      iex> render_text_align(:center)
      "center"

      iex> render_text_align({:right, :top})
      "right"
  """
  @spec render_text_align(atom() | tuple() | String.t()) :: String.t()
  def render_text_align(:left), do: "left"
  def render_text_align(:center), do: "center"
  def render_text_align(:right), do: "right"
  def render_text_align(:justify), do: "justify"
  def render_text_align({h, _v}), do: render_text_align(h)
  def render_text_align(align) when is_binary(align), do: align
  def render_text_align(_), do: "left"

  @doc """
  Renders vertical alignment to CSS vertical-align value.

  ## Examples

      iex> render_vertical_align(:top)
      "top"

      iex> render_vertical_align(:middle)
      "middle"

      iex> render_vertical_align(:bottom)
      "bottom"
  """
  @spec render_vertical_align(atom() | String.t()) :: String.t()
  def render_vertical_align(:top), do: "top"
  def render_vertical_align(:middle), do: "middle"
  def render_vertical_align(:bottom), do: "bottom"
  def render_vertical_align(valign) when is_binary(valign), do: valign
  def render_vertical_align(_), do: "middle"

  @doc """
  Renders horizontal alignment to CSS Grid justify-items value.

  CSS Grid uses start/end instead of left/right.

  ## Examples

      iex> render_justify_items(:left)
      "start"

      iex> render_justify_items(:center)
      "center"

      iex> render_justify_items(:right)
      "end"
  """
  @spec render_justify_items(atom()) :: String.t()
  def render_justify_items(:left), do: "start"
  def render_justify_items(:center), do: "center"
  def render_justify_items(:right), do: "end"
  def render_justify_items(:start), do: "start"
  def render_justify_items(:end), do: "end"
  def render_justify_items(_), do: "start"

  @doc """
  Renders vertical alignment to CSS Grid align-items value.

  CSS Grid uses start/end instead of top/bottom.

  ## Examples

      iex> render_align_items(:top)
      "start"

      iex> render_align_items(:middle)
      "center"

      iex> render_align_items(:bottom)
      "end"
  """
  @spec render_align_items(atom()) :: String.t()
  def render_align_items(:top), do: "start"
  def render_align_items(:middle), do: "center"
  def render_align_items(:bottom), do: "end"
  def render_align_items(:start), do: "start"
  def render_align_items(:end), do: "end"
  def render_align_items(_), do: "start"

  @doc """
  Parses an alignment value into horizontal and vertical components.

  ## Examples

      iex> parse_alignment({:left, :top})
      {:left, :top}

      iex> parse_alignment(:center)
      {:center, nil}

      iex> parse_alignment(:top)
      {nil, :top}
  """
  @spec parse_alignment(atom() | tuple()) :: {atom() | nil, atom() | nil}
  def parse_alignment({h, v}), do: {h, v}
  def parse_alignment(align) when align in [:left, :center, :right], do: {align, nil}
  def parse_alignment(align) when align in [:top, :middle, :bottom], do: {nil, align}
  def parse_alignment(_), do: {nil, nil}

  # Color and Fill Mapping

  @doc """
  Renders a color value to CSS.

  ## Examples

      iex> render_color("#ff0000")
      "#ff0000"

      iex> render_color(:red)
      "red"

      iex> render_color(:none)
      "transparent"

      iex> render_color(nil)
      "transparent"
  """
  @spec render_color(atom() | String.t() | nil) :: String.t()
  def render_color(:none), do: "transparent"
  def render_color(nil), do: "transparent"
  def render_color(color) when is_binary(color), do: sanitize_css_value(color)
  def render_color(color) when is_atom(color), do: Atom.to_string(color)

  @doc """
  Evaluates a fill value, which can be a static color or a function.

  ## Examples

      iex> evaluate_fill("#ff0000", %{})
      "#ff0000"

      iex> evaluate_fill(:none, %{})
      :none

      iex> fun = fn ctx -> if ctx.row_index == 0, do: "#eee", else: "#fff" end
      iex> evaluate_fill(fun, %{row_index: 0})
      "#eee"
  """
  @spec evaluate_fill(atom() | String.t() | function() | nil, map()) :: atom() | String.t() | nil
  def evaluate_fill(nil, _context), do: nil
  def evaluate_fill(:none, _context), do: :none
  def evaluate_fill(fill, _context) when is_binary(fill), do: fill
  def evaluate_fill(fill, _context) when is_atom(fill), do: fill

  def evaluate_fill(fill, context) when is_function(fill) do
    try do
      case Function.info(fill)[:arity] do
        0 -> fill.()
        1 -> fill.(context)
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  # Stroke Mapping

  @doc """
  Renders a stroke value to CSS border property.

  ## Examples

      iex> render_stroke(:none)
      "none"

      iex> render_stroke("1px solid black")
      "1px solid black"

      iex> render_stroke(%{thickness: "2pt", paint: "#000"})
      "2px solid #000"

      iex> render_stroke(%{thickness: "1pt", dash: :dashed})
      "1px dashed currentColor"

      iex> render_stroke(%{thickness: "1pt"})
      "1px solid currentColor"
  """
  @spec render_stroke(atom() | String.t() | map()) :: String.t()
  def render_stroke(:none), do: "none"
  def render_stroke(nil), do: "none"
  def render_stroke(stroke) when is_binary(stroke), do: sanitize_css_value(stroke)

  def render_stroke(%{thickness: thickness, paint: paint, dash: dash}) do
    "#{render_length(thickness)} #{render_dash_style(dash)} #{render_color(paint)}"
  end

  def render_stroke(%{thickness: thickness, paint: paint}) do
    "#{render_length(thickness)} solid #{render_color(paint)}"
  end

  def render_stroke(%{thickness: thickness, dash: dash}) do
    "#{render_length(thickness)} #{render_dash_style(dash)} currentColor"
  end

  def render_stroke(%{thickness: thickness}) do
    "#{render_length(thickness)} solid currentColor"
  end

  def render_stroke(_), do: "1px solid currentColor"

  @doc """
  Renders a dash style to CSS border-style value.

  ## Examples

      iex> render_dash_style(:solid)
      "solid"

      iex> render_dash_style(:dashed)
      "dashed"

      iex> render_dash_style(:dotted)
      "dotted"

      iex> render_dash_style("dash-dot")
      "dashed"
  """
  @spec render_dash_style(atom() | String.t()) :: String.t()
  def render_dash_style(:solid), do: "solid"
  def render_dash_style(:dashed), do: "dashed"
  def render_dash_style(:dotted), do: "dotted"
  def render_dash_style(:double), do: "double"
  def render_dash_style("solid"), do: "solid"
  def render_dash_style("dashed"), do: "dashed"
  def render_dash_style("dotted"), do: "dotted"
  def render_dash_style("dash-dot"), do: "dashed"
  def render_dash_style(_), do: "solid"

  # Font Weight Mapping

  @doc """
  Renders a font weight to CSS font-weight value.

  ## Examples

      iex> render_font_weight(:normal)
      "normal"

      iex> render_font_weight(:bold)
      "bold"

      iex> render_font_weight(:light)
      "300"

      iex> render_font_weight(:medium)
      "500"

      iex> render_font_weight(:semibold)
      "600"
  """
  @spec render_font_weight(atom() | String.t() | number()) :: String.t()
  def render_font_weight(:normal), do: "normal"
  def render_font_weight(:bold), do: "bold"
  def render_font_weight(:light), do: "300"
  def render_font_weight(:medium), do: "500"
  def render_font_weight(:semibold), do: "600"
  def render_font_weight(weight) when is_binary(weight), do: weight
  def render_font_weight(weight) when is_number(weight), do: to_string(weight)
  def render_font_weight(_), do: "normal"

  # Direction Mapping (for Flexbox)

  @doc """
  Renders a stack direction to CSS flex-direction value.

  ## Examples

      iex> render_direction(:ttb)
      "column"

      iex> render_direction(:btt)
      "column-reverse"

      iex> render_direction(:ltr)
      "row"

      iex> render_direction(:rtl)
      "row-reverse"
  """
  @spec render_direction(atom() | String.t()) :: String.t()
  def render_direction(:ttb), do: "column"
  def render_direction(:btt), do: "column-reverse"
  def render_direction(:ltr), do: "row"
  def render_direction(:rtl), do: "row-reverse"
  def render_direction("ttb"), do: "column"
  def render_direction("btt"), do: "column-reverse"
  def render_direction("ltr"), do: "row"
  def render_direction("rtl"), do: "row-reverse"
  def render_direction(_), do: "column"

  # CSS Sanitization

  @doc """
  Sanitizes a CSS value to prevent CSS injection attacks.

  Removes dangerous characters that could be used to break out of CSS
  property values and inject malicious styles.

  ## Examples

      iex> sanitize_css_value("#ff0000")
      "#ff0000"

      iex> sanitize_css_value("10px")
      "10px"

      iex> sanitize_css_value("red; } .admin { display: none; } .x {")
      "red  .admin  display none  .x "

      iex> sanitize_css_value("url(javascript:alert(1))")
      "url(javascript:alert(1))"
  """
  @spec sanitize_css_value(String.t() | any()) :: String.t()
  def sanitize_css_value(value) when is_binary(value) do
    # Remove characters that can break out of CSS values or inject new rules
    # Allowed: alphanumeric, #, %, ., -, space, (, ), comma, /
    value
    |> String.replace(~r/[;{}:<>]/, "")
    |> String.replace(~r/\/\*/, "")
    |> String.replace(~r/\*\//, "")
    |> String.replace(~r/\\/, "")
  end

  def sanitize_css_value(value), do: sanitize_css_value(to_string(value))

  # HTML Escaping

  @doc """
  Escapes HTML special characters to prevent XSS.

  Optimized single-pass implementation using IO lists for better performance
  than multiple String.replace/2 calls.

  ## Examples

      iex> escape_html("<script>alert('XSS')</script>")
      "&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;"

      iex> escape_html("A & B")
      "A &amp; B"
  """
  @spec escape_html(String.t() | any()) :: String.t()
  def escape_html(text) when is_binary(text) do
    text
    |> escape_html_iodata([])
    |> IO.iodata_to_binary()
  end

  def escape_html(text), do: escape_html(to_string(text))

  #############################################################################
  # Private Functions
  #############################################################################

  # Single-pass escape using IO lists for performance.
  # Processes each character once, building an IO list in reverse order.
  # More efficient than multiple String.replace/2 calls (O(n) vs O(5n)).
  defp escape_html_iodata(<<>>, acc), do: Enum.reverse(acc)

  defp escape_html_iodata(<<"&", rest::binary>>, acc),
    do: escape_html_iodata(rest, ["&amp;" | acc])

  defp escape_html_iodata(<<"<", rest::binary>>, acc),
    do: escape_html_iodata(rest, ["&lt;" | acc])

  defp escape_html_iodata(<<">", rest::binary>>, acc),
    do: escape_html_iodata(rest, ["&gt;" | acc])

  defp escape_html_iodata(<<"\"", rest::binary>>, acc),
    do: escape_html_iodata(rest, ["&quot;" | acc])

  defp escape_html_iodata(<<"'", rest::binary>>, acc),
    do: escape_html_iodata(rest, ["&#39;" | acc])

  defp escape_html_iodata(<<char::utf8, rest::binary>>, acc),
    do: escape_html_iodata(rest, [<<char::utf8>> | acc])
end
