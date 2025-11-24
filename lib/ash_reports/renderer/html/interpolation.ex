defmodule AshReports.Renderer.Html.Interpolation do
  @moduledoc """
  Variable interpolation for HTML rendered content.

  Detects [variable_name] patterns in text and replaces them with values
  from the data context. Supports nested paths like [user.name] and
  handles missing variables gracefully. All interpolated values are
  HTML-escaped to prevent XSS attacks.

  ## Examples

      iex> interpolate("Hello [name]!", %{name: "World"})
      "Hello World!"

      iex> interpolate("Total: [order.total]", %{order: %{total: 99.99}})
      "Total: 99.99"

      iex> interpolate("Code: [code]", %{code: "<script>alert('XSS')</script>"})
      "Code: &lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;"

  ## Sharing with Typst Renderer

  This module mirrors the Typst interpolation module but adds HTML escaping.
  The core interpolation logic (pattern matching, path parsing, value retrieval)
  is similar to enable consistent behavior across renderers.
  """

  alias AshReports.Renderer.Html.Styling

  @variable_pattern ~r/\[([^\]]+)\]/

  @doc """
  Interpolates variables in text with values from data context.

  All interpolated values are automatically HTML-escaped for XSS prevention.

  ## Parameters

  - `text` - Text containing [variable_name] patterns
  - `data` - Map containing variable values

  ## Returns

  String with variables replaced by their escaped values.

  ## Examples

      iex> interpolate("Hello [name]!", %{name: "Alice"})
      "Hello Alice!"

      iex> interpolate("[greeting] [name]!", %{greeting: "Hi", name: "Bob"})
      "Hi Bob!"

      iex> interpolate("Test [value]", %{value: "<b>bold</b>"})
      "Test &lt;b&gt;bold&lt;/b&gt;"
  """
  @spec interpolate(String.t(), map()) :: String.t()
  def interpolate(text, data) when is_binary(text) and is_map(data) do
    Regex.replace(@variable_pattern, text, fn _match, variable_name ->
      get_variable_value(data, variable_name)
    end)
  end

  def interpolate(text, _data) when is_binary(text), do: text
  def interpolate(other, _data), do: to_string(other)

  @doc """
  Interpolates variables without HTML escaping.

  Use this when the output will be further processed or when escaping
  is handled elsewhere.

  ## Parameters

  - `text` - Text containing [variable_name] patterns
  - `data` - Map containing variable values

  ## Returns

  String with variables replaced by their raw values.
  """
  @spec interpolate_raw(String.t(), map()) :: String.t()
  def interpolate_raw(text, data) when is_binary(text) and is_map(data) do
    Regex.replace(@variable_pattern, text, fn _match, variable_name ->
      get_variable_value_raw(data, variable_name)
    end)
  end

  def interpolate_raw(text, _data) when is_binary(text), do: text
  def interpolate_raw(other, _data), do: to_string(other)

  @doc """
  Checks if text contains any variable patterns.

  ## Examples

      iex> has_variables?("Hello [name]!")
      true

      iex> has_variables?("Hello World!")
      false
  """
  @spec has_variables?(String.t()) :: boolean()
  def has_variables?(text) when is_binary(text) do
    Regex.match?(@variable_pattern, text)
  end

  def has_variables?(_), do: false

  @doc """
  Extracts all variable names from text.

  ## Examples

      iex> extract_variables("Hello [name], your order [order.id] is ready")
      ["name", "order.id"]
  """
  @spec extract_variables(String.t()) :: [String.t()]
  def extract_variables(text) when is_binary(text) do
    @variable_pattern
    |> Regex.scan(text)
    |> Enum.map(fn [_full, name] -> name end)
  end

  def extract_variables(_), do: []

  @doc """
  Gets a variable value from data, supporting nested paths.

  The value is automatically HTML-escaped.

  ## Examples

      iex> get_variable_value(%{name: "Alice"}, "name")
      "Alice"

      iex> get_variable_value(%{user: %{name: "Bob"}}, "user.name")
      "Bob"

      iex> get_variable_value(%{}, "missing")
      "[missing]"

      iex> get_variable_value(%{html: "<b>test</b>"}, "html")
      "&lt;b&gt;test&lt;/b&gt;"
  """
  @spec get_variable_value(map(), String.t()) :: String.t()
  def get_variable_value(data, variable_name) when is_map(data) do
    value = get_variable_value_raw(data, variable_name)

    # Escape unless it's a placeholder for missing value
    if String.starts_with?(value, "[") and String.ends_with?(value, "]") do
      value
    else
      Styling.escape_html(value)
    end
  end

  @doc """
  Gets a variable value from data without HTML escaping.

  ## Examples

      iex> get_variable_value_raw(%{name: "Alice"}, "name")
      "Alice"

      iex> get_variable_value_raw(%{html: "<b>test</b>"}, "html")
      "<b>test</b>"
  """
  @spec get_variable_value_raw(map(), String.t()) :: String.t()
  def get_variable_value_raw(data, variable_name) when is_map(data) do
    path = parse_variable_path(variable_name)

    case get_nested_value(data, path) do
      nil -> "[#{variable_name}]"
      value -> format_interpolated_value(value)
    end
  end

  # Parse variable path like "user.name" into [:user, :name]
  defp parse_variable_path(variable_name) do
    variable_name
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end

  # Get nested value from map following the path
  defp get_nested_value(data, []), do: data

  defp get_nested_value(data, [key | rest]) when is_map(data) do
    value = Map.get(data, key) || Map.get(data, to_string(key))
    get_nested_value(value, rest)
  end

  defp get_nested_value(nil, _path), do: nil
  defp get_nested_value(_data, _path), do: nil

  # Format interpolated values appropriately
  defp format_interpolated_value(value) when is_binary(value), do: value
  defp format_interpolated_value(value) when is_integer(value), do: Integer.to_string(value)

  defp format_interpolated_value(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 2)
  end

  defp format_interpolated_value(%Date{} = value), do: Date.to_string(value)
  defp format_interpolated_value(%DateTime{} = value), do: DateTime.to_string(value)
  defp format_interpolated_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_string(value)
  defp format_interpolated_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_interpolated_value(value), do: inspect(value)

  # Field Value Formatting

  @doc """
  Formats a value according to the specified format.

  This function is shared with the Content module and provides consistent
  formatting across HTML rendering.

  ## Parameters

  - `value` - The value to format
  - `format` - The format type (:number, :currency, :date, etc.)
  - `decimal_places` - Number of decimal places for numeric formats

  ## Returns

  Formatted string representation of the value (not HTML-escaped).

  ## Examples

      iex> format_value(1234.5, :currency, 2)
      "$1,234.50"

      iex> format_value(0.156, :percent, 1)
      "15.6%"

      iex> format_value(~D[2024-01-15], :date, nil)
      "2024-01-15"
  """
  @spec format_value(any(), atom() | nil, non_neg_integer() | nil) :: String.t()
  def format_value(nil, _format, _decimal_places), do: ""

  def format_value(value, nil, _decimal_places) do
    to_string(value)
  end

  def format_value(value, :number, decimal_places) when is_number(value) do
    places = decimal_places || 0
    formatted = :erlang.float_to_binary(value * 1.0, decimals: places)
    format_number_with_commas(formatted)
  end

  def format_value(value, :currency, decimal_places) when is_number(value) do
    places = decimal_places || 2
    formatted = :erlang.float_to_binary(value * 1.0, decimals: places)
    "$#{format_number_with_commas(formatted)}"
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

  def format_value(value, :date_short, _decimal_places) do
    case value do
      %Date{year: y, month: m, day: d} ->
        "#{m}/#{d}/#{y}"
      %DateTime{year: y, month: m, day: d} ->
        "#{m}/#{d}/#{y}"
      %NaiveDateTime{year: y, month: m, day: d} ->
        "#{m}/#{d}/#{y}"
      _ ->
        to_string(value)
    end
  end

  def format_value(value, :boolean, _decimal_places) do
    case value do
      true -> "Yes"
      false -> "No"
      _ -> to_string(value)
    end
  end

  def format_value(value, _format, _decimal_places) do
    to_string(value)
  end

  # Format numbers with comma separators for thousands
  defp format_number_with_commas(number_string) when is_binary(number_string) do
    case String.split(number_string, ".") do
      [integer_part] ->
        format_integer_with_commas(integer_part)
      [integer_part, decimal_part] ->
        "#{format_integer_with_commas(integer_part)}.#{decimal_part}"
    end
  end

  defp format_integer_with_commas(integer_string) do
    integer_string
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  @doc """
  Formats and escapes a value for safe HTML display.

  Combines formatting and HTML escaping in a single operation.

  ## Parameters

  - `value` - The value to format and escape
  - `format` - The format type
  - `decimal_places` - Number of decimal places

  ## Returns

  Formatted and HTML-escaped string.

  ## Examples

      iex> format_value_safe("<b>100</b>", nil, nil)
      "&lt;b&gt;100&lt;/b&gt;"

      iex> format_value_safe(1234.5, :currency, 2)
      "$1,234.50"
  """
  @spec format_value_safe(any(), atom() | nil, non_neg_integer() | nil) :: String.t()
  def format_value_safe(value, format, decimal_places) do
    value
    |> format_value(format, decimal_places)
    |> Styling.escape_html()
  end
end
