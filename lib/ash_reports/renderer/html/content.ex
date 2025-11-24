defmodule AshReports.Renderer.Html.Content do
  @moduledoc """
  HTML renderer for content elements (labels and fields).

  Generates HTML spans with appropriate styling and CSS classes.

  ## Content Types

  - Labels → span with class="ash-label" and text content
  - Fields → span with class="ash-field" and formatted value

  ## Styling

  Content elements support inline styles for:
  - `font-size` from style.font_size
  - `font-weight` from style.font_weight
  - `font-style` from style.font_style
  - `color` from style.color
  - `font-family` from style.font_family
  - `background-color` from style.background_color
  """

  alias AshReports.Layout.IR.Content.{Label, Field, NestedLayout}
  alias AshReports.Layout.IR.Style
  alias AshReports.Renderer.Html.{Grid, Table, Stack}

  @doc """
  Renders content IR to HTML.

  ## Parameters

  - `content` - The content IR (Label, Field, or NestedLayout)
  - `opts` - Rendering options including :data for field interpolation

  ## Returns

  String containing the HTML markup.
  """
  @spec render(Label.t() | Field.t() | NestedLayout.t() | map(), keyword()) :: String.t()
  def render(content, opts \\ [])

  def render(%Label{text: text, style: style}, _opts) do
    styles = build_text_styles(style)
    escaped_text = escape_html(text)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<span class="ash-label"#{style_attr}>#{escaped_text}</span>)
  end

  def render(%Field{source: source, format: format, decimal_places: decimal_places, style: style}, opts) do
    data = Keyword.get(opts, :data, %{})
    value = get_field_value(data, source)
    formatted = format_value(value, format, decimal_places)
    styles = build_text_styles(style)
    escaped_value = escape_html(formatted)

    style_attr = if styles == "", do: "", else: ~s( style="#{styles}")

    ~s(<span class="ash-field"#{style_attr}>#{escaped_value}</span>)
  end

  def render(%NestedLayout{layout: layout}, opts) do
    render_layout(layout, opts)
  end

  # Handle simple map content (text or value)
  def render(%{text: text}, _opts) do
    ~s(<span class="ash-label">#{escape_html(text)}</span>)
  end

  def render(%{value: value}, _opts) do
    ~s(<span class="ash-field">#{escape_html(to_string(value))}</span>)
  end

  def render(text, _opts) when is_binary(text) do
    ~s(<span class="ash-label">#{escape_html(text)}</span>)
  end

  def render(_, _opts), do: ""

  # Style building

  @doc """
  Builds CSS style string from StyleIR.

  ## Parameters

  - `style` - The StyleIR struct or nil

  ## Returns

  String of CSS property-value pairs separated by semicolons.
  """
  @spec build_text_styles(Style.t() | nil) :: String.t()
  def build_text_styles(nil), do: ""

  def build_text_styles(%Style{} = style) do
    []
    |> maybe_add_font_size(style)
    |> maybe_add_font_weight(style)
    |> maybe_add_font_style(style)
    |> maybe_add_color(style)
    |> maybe_add_background_color(style)
    |> maybe_add_font_family(style)
    |> Enum.reverse()
    |> Enum.join("; ")
  end

  def build_text_styles(_), do: ""

  defp maybe_add_font_size(styles, %Style{font_size: font_size}) when not is_nil(font_size) do
    ["font-size: #{render_length(font_size)}" | styles]
  end
  defp maybe_add_font_size(styles, _), do: styles

  defp maybe_add_font_weight(styles, %Style{font_weight: font_weight}) when not is_nil(font_weight) do
    ["font-weight: #{render_font_weight(font_weight)}" | styles]
  end
  defp maybe_add_font_weight(styles, _), do: styles

  defp maybe_add_font_style(styles, %Style{font_style: font_style}) when not is_nil(font_style) do
    ["font-style: #{font_style}" | styles]
  end
  defp maybe_add_font_style(styles, _), do: styles

  defp maybe_add_color(styles, %Style{color: color}) when not is_nil(color) do
    ["color: #{color}" | styles]
  end
  defp maybe_add_color(styles, _), do: styles

  defp maybe_add_background_color(styles, %Style{background_color: bg_color}) when not is_nil(bg_color) do
    ["background-color: #{bg_color}" | styles]
  end
  defp maybe_add_background_color(styles, _), do: styles

  defp maybe_add_font_family(styles, %Style{font_family: font_family}) when not is_nil(font_family) do
    ["font-family: #{font_family}" | styles]
  end
  defp maybe_add_font_family(styles, _), do: styles

  # Helper functions

  defp render_length(length) when is_binary(length) do
    if String.ends_with?(length, "pt") do
      String.replace(length, "pt", "px")
    else
      length
    end
  end
  defp render_length(length) when is_number(length), do: "#{length}px"

  defp render_font_weight(:normal), do: "normal"
  defp render_font_weight(:bold), do: "bold"
  defp render_font_weight(:light), do: "300"
  defp render_font_weight(:medium), do: "500"
  defp render_font_weight(:semibold), do: "600"
  defp render_font_weight(weight) when is_binary(weight), do: weight
  defp render_font_weight(weight) when is_number(weight), do: to_string(weight)
  defp render_font_weight(_), do: "normal"

  # Field value handling

  defp get_field_value(data, source) when is_atom(source) do
    Map.get(data, source) || Map.get(data, to_string(source))
  end

  defp get_field_value(data, source) when is_list(source) do
    Enum.reduce_while(source, data, fn key, acc ->
      case acc do
        %{} ->
          value = Map.get(acc, key) || Map.get(acc, to_string(key))
          if value, do: {:cont, value}, else: {:halt, nil}
        _ ->
          {:halt, nil}
      end
    end)
  end

  defp get_field_value(_data, _source), do: nil

  # Value formatting

  @doc """
  Formats a value according to the specified format.

  ## Parameters

  - `value` - The value to format
  - `format` - The format type (:number, :currency, :date, etc.)
  - `decimal_places` - Number of decimal places for numeric formats

  ## Returns

  Formatted string representation of the value.
  """
  @spec format_value(any(), atom() | nil, non_neg_integer() | nil) :: String.t()
  def format_value(nil, _format, _decimal_places), do: ""

  def format_value(value, nil, _decimal_places) do
    to_string(value)
  end

  def format_value(value, :number, decimal_places) when is_number(value) do
    places = decimal_places || 0
    :erlang.float_to_binary(value * 1.0, decimals: places)
  end

  def format_value(value, :currency, decimal_places) when is_number(value) do
    places = decimal_places || 2
    formatted = :erlang.float_to_binary(value * 1.0, decimals: places)
    "$#{formatted}"
  end

  def format_value(value, :percent, decimal_places) when is_number(value) do
    places = decimal_places || 0
    formatted = :erlang.float_to_binary(value * 100.0, decimals: places)
    "#{formatted}%"
  end

  def format_value(%Date{} = value, :date, _decimal_places) do
    Date.to_string(value)
  end

  def format_value(%DateTime{} = value, :datetime, _decimal_places) do
    DateTime.to_string(value)
  end

  def format_value(%NaiveDateTime{} = value, :datetime, _decimal_places) do
    NaiveDateTime.to_string(value)
  end

  def format_value(value, _format, _decimal_places) do
    to_string(value)
  end

  # Nested layout rendering

  defp render_layout(%{type: :grid} = layout, opts) do
    Grid.render(layout, opts)
  end

  defp render_layout(%{type: :table} = layout, opts) do
    Table.render(layout, opts)
  end

  defp render_layout(%{type: :stack} = layout, opts) do
    Stack.render(layout, opts)
  end

  defp render_layout(_, _opts), do: ""

  @doc """
  Escapes HTML special characters to prevent XSS.
  """
  @spec escape_html(String.t()) :: String.t()
  def escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def escape_html(text), do: escape_html(to_string(text))
end
