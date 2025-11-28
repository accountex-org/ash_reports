defmodule AshReports.Renderer.Typst.Content do
  @moduledoc """
  Typst renderer for content elements.

  Renders labels, fields, and nested layouts to Typst markup with proper styling
  and character escaping.

  ## Examples

      iex> label = %AshReports.Layout.IR.Content.Label{text: "Total:", style: nil}
      iex> AshReports.Renderer.Typst.Content.render(label)
      "Total:"

      iex> label = %AshReports.Layout.IR.Content.Label{
      ...>   text: "Important",
      ...>   style: %AshReports.Layout.IR.Style{font_weight: :bold, color: "red"}
      ...> }
      iex> AshReports.Renderer.Typst.Content.render(label)
      "#text(weight: \"bold\", fill: red)[Important]"
  """

  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.Content.{Label, Field, NestedLayout}
  alias AshReports.Layout.IR.Style

  @doc """
  Renders content to Typst markup.

  ## Parameters

  - `content` - The content IR to render (Label, Field, or NestedLayout)
  - `opts` - Rendering options
    - `:indent` - Current indentation level
    - `:data` - Data context for field value interpolation

  ## Returns

  String containing the Typst markup for the content.
  """
  @spec render(IR.Content.t(), keyword()) :: String.t()
  def render(content, opts \\ [])

  def render(%Label{text: text, style: nil}, opts) do
    generate_refs = Keyword.get(opts, :generate_refs, false)
    interpolate_variables(text, generate_refs)
  end

  def render(%Label{text: text, style: style}, opts) do
    generate_refs = Keyword.get(opts, :generate_refs, false)
    content = interpolate_variables(text, generate_refs)

    if Style.empty?(style) do
      content
    else
      wrap_with_style(content, style)
    end
  end

  def render(%Field{source: source, format: format, decimal_places: decimal_places, style: style}, opts) do
    data = Keyword.get(opts, :data)
    generate_refs = Keyword.get(opts, :generate_refs, false)

    # Check if we should render as a variable reference (for Typst code generation)
    # or interpolate the actual value (for preview/testing)
    content =
      if generate_refs or is_nil(data) do
        # Code generation mode - output Typst variable reference for runtime interpolation
        render_field_reference(source, format, decimal_places)
      else
        # Data rendering mode - interpolate the actual value
        value = get_field_value(data, source)
        formatted = format_value(value, format, decimal_places)
        escape_typst(formatted)
      end

    if is_nil(style) or Style.empty?(style) do
      content
    else
      wrap_with_style(content, style)
    end
  end

  def render(%NestedLayout{layout: layout}, opts) do
    indent = Keyword.get(opts, :indent, 0)
    render_nested_layout(layout, indent)
  end

  # Handle maps with text key (legacy format)
  def render(%{text: text}, _opts) when is_binary(text) do
    escape_typst(text)
  end

  # Handle maps with value key (legacy format)
  def render(%{value: value}, _opts) do
    escape_typst(to_string(value))
  end

  def render(_, _opts), do: ""

  @doc """
  Escapes special Typst characters in text.

  Typst uses certain characters for markup that must be escaped:
  - `#` - Function calls
  - `$` - Math mode
  - `@` - References
  - `*` - Bold text
  - `_` - Italic text
  - `\\` - Escape character
  - `[` and `]` - Content blocks
  - `{` and `}` - Code blocks
  - `<` and `>` - Labels

  ## Examples

      iex> escape_typst("Price: $100")
      "Price: \\$100"

      iex> escape_typst("Item #5")
      "Item \\#5"
  """
  @spec escape_typst(String.t()) :: String.t()
  def escape_typst(text) when is_binary(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace("#", "\\#")
    |> String.replace("$", "\\$")
    |> String.replace("@", "\\@")
    |> String.replace("*", "\\*")
    |> String.replace("_", "\\_")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("<", "\\<")
    |> String.replace(">", "\\>")
  end

  def escape_typst(other), do: to_string(other)

  @doc """
  Wraps text content with Typst #text() function for styling.

  ## Examples

      iex> style = %AshReports.Layout.IR.Style{font_weight: :bold}
      iex> wrap_with_style("Hello", style)
      "#text(weight: \"bold\")[Hello]"
  """
  @spec wrap_with_style(String.t(), Style.t()) :: String.t()
  def wrap_with_style(text, %Style{} = style) do
    params = build_style_parameters(style)

    if params == "" do
      text
    else
      "#text(#{params})[#{text}]"
    end
  end

  @doc """
  Builds Typst text() parameters from a StyleIR.
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

  defp maybe_add_font_size(params, %Style{font_size: size}) when is_integer(size) do
    ["size: #{size}pt" | params]
  end

  defp maybe_add_font_size(params, %Style{font_size: size}) when is_binary(size) do
    # If already a string (e.g., "18pt", "1.5em"), use as-is
    ["size: #{size}" | params]
  end

  defp maybe_add_font_size(params, %Style{font_size: size}) do
    # Fallback for other types - assume pt
    ["size: #{size}pt" | params]
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

  # Helper renderers

  @doc """
  Renders font weight to Typst syntax.
  """
  @spec render_font_weight(atom() | String.t()) :: String.t()
  def render_font_weight(:normal), do: "\"regular\""
  def render_font_weight(:bold), do: "\"bold\""
  def render_font_weight(:light), do: "\"light\""
  def render_font_weight(:medium), do: "\"medium\""
  def render_font_weight(:semibold), do: "\"semibold\""
  def render_font_weight(weight) when is_atom(weight), do: "\"#{weight}\""
  def render_font_weight(weight) when is_binary(weight), do: "\"#{weight}\""

  @doc """
  Renders a color value to Typst syntax.
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

  # Field value handling

  @doc """
  Renders a field reference as Typst code for runtime interpolation.

  Generates code like `#record.field_name` that will be evaluated when the
  band function is called with actual data.
  """
  @spec render_field_reference(atom() | list(), atom() | nil, non_neg_integer() | nil) :: String.t()
  def render_field_reference(source, format, decimal_places) when is_atom(source) do
    # Base reference without # prefix - the # is added by wrap_field_formatting
    # when switching from markup mode to code mode
    base_ref = "record.#{source}"
    wrap_field_formatting(base_ref, format, decimal_places)
  end

  def render_field_reference(source, format, decimal_places) when is_list(source) do
    # Nested path like [:product, :name]
    path = Enum.map_join(source, ".", &to_string/1)
    base_ref = "record.#{path}"
    wrap_field_formatting(base_ref, format, decimal_places)
  end

  def render_field_reference(_source, _format, _decimal_places), do: ""

  # Wrap field reference with formatting functions if needed
  # The ref comes WITHOUT the # prefix. We add # when needed to switch to code mode.
  # Inside function calls (already in code mode), we use the ref directly without #.
  # We handle Typst 'none' values by displaying a dash "-" instead of 0 to avoid
  # confusion and to make it clear the value is missing (not actually zero).
  # This also prevents any potential division-by-zero if these values were ever
  # used in calculations.
  defp wrap_field_formatting(ref, nil, _decimal_places), do: "##{ref}"

  defp wrap_field_formatting(ref, :currency, decimal_places) do
    places = decimal_places || 2
    # \$ outputs literal dollar sign, use code block to handle none values
    # If the field is none, display dash to indicate missing value
    "\\$\#{ let v = #{ref}; if v == none { \"-\" } else { calc.round(v, digits: #{places}) } }"
  end

  defp wrap_field_formatting(ref, :percent, decimal_places) do
    places = decimal_places || 1
    # Use code block to handle none values - display dash for missing values
    # Include % inside else branch so we don't get "-%" for none values
    # Note: We assume the value is already a percentage (0-100 range), not a decimal (0-1 range)
    # If the source data is in decimal form, multiply by 100 at the data layer, not here
    "\#{ let v = #{ref}; if v == none { \"-\" } else { str(calc.round(v, digits: #{places})) + \"%\" } }"
  end

  defp wrap_field_formatting(ref, :number, decimal_places) when not is_nil(decimal_places) do
    # Use code block to handle none values - display dash for missing values
    "\#{ let v = #{ref}; if v == none { \"-\" } else { calc.round(v, digits: #{decimal_places}) } }"
  end

  defp wrap_field_formatting(ref, _format, _decimal_places), do: "##{ref}"

  # Variable interpolation for label text
  # Replaces [variable_name] with Typst variable references
  defp interpolate_variables(text, true) when is_binary(text) do
    # In generate_refs mode, replace [var_name] with #data.variables.var_name
    # The main template function receives 'data' as a parameter, which contains
    # both 'records' and 'variables'. We use 'data' not 'report_data' because
    # we're inside the function body where 'data' is the parameter name.
    ~r/\[([a-zA-Z_][a-zA-Z0-9_]*)\]/
    |> Regex.split(text, include_captures: true)
    |> Enum.map(fn part ->
      case Regex.run(~r/^\[([a-zA-Z_][a-zA-Z0-9_]*)\]$/, part) do
        [_, var_name] ->
          # This is a variable reference - output as Typst code
          # Variables are stored in data.variables (the function parameter)
          "#data.variables.#{var_name}"
        _ ->
          # Regular text - escape it
          escape_typst(part)
      end
    end)
    |> Enum.join("")
  end

  defp interpolate_variables(text, false) when is_binary(text) do
    # Not in generate_refs mode - just escape the text
    escape_typst(text)
  end

  defp interpolate_variables(text, _) when is_binary(text) do
    escape_typst(text)
  end

  defp get_field_value(data, source) when is_atom(source) do
    Map.get(data, source, "")
  end

  defp get_field_value(data, source) when is_list(source) do
    Enum.reduce_while(source, data, fn key, acc ->
      case acc do
        %{} -> {:cont, Map.get(acc, key)}
        _ -> {:halt, nil}
      end
    end) || ""
  end

  defp get_field_value(_data, _source), do: ""

  @doc """
  Formats a value based on the format type.

  ## Format Types

  - `:number` - Formatted number with decimal places
  - `:currency` - Currency format with symbol
  - `:date` - Date format
  - `:datetime` - DateTime format
  - `:percent` - Percentage format
  - `nil` - Raw value as string
  """
  @spec format_value(any(), atom() | nil, non_neg_integer() | nil) :: String.t()
  def format_value(nil, _format, _decimal_places), do: ""
  def format_value("", _format, _decimal_places), do: ""

  def format_value(value, nil, _decimal_places) do
    to_string(value)
  end

  def format_value(value, :number, decimal_places) when is_number(value) do
    places = decimal_places || 0
    :erlang.float_to_binary(value / 1, decimals: places)
  end

  def format_value(value, :currency, decimal_places) when is_number(value) do
    places = decimal_places || 2
    formatted = :erlang.float_to_binary(value / 1, decimals: places)
    "$#{formatted}"
  end

  def format_value(value, :percent, decimal_places) when is_number(value) do
    places = decimal_places || 1
    percent_value = value * 100
    formatted = :erlang.float_to_binary(percent_value / 1, decimals: places)
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

  defp render_nested_layout(%IR{type: :grid} = layout, indent) do
    AshReports.Renderer.Typst.Grid.render(layout, indent: indent)
  end

  defp render_nested_layout(%IR{type: :table} = layout, indent) do
    AshReports.Renderer.Typst.Table.render(layout, indent: indent)
  end

  defp render_nested_layout(%IR{type: :stack} = layout, indent) do
    AshReports.Renderer.Typst.Stack.render(layout, indent: indent)
  end

  defp render_nested_layout(_, _indent), do: ""
end
