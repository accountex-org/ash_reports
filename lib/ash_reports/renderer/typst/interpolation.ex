defmodule AshReports.Renderer.Typst.Interpolation do
  @moduledoc """
  Variable interpolation for Typst rendered content.

  Detects [variable_name] patterns in text and replaces them with values
  from the data context. Supports nested paths like [user.name] and
  handles missing variables gracefully.

  ## Examples

      iex> interpolate("Hello [name]!", %{name: "World"})
      "Hello World!"

      iex> interpolate("Total: [order.total]", %{order: %{total: 99.99}})
      "Total: 99.99"

      iex> interpolate("Missing: [unknown]", %{})
      "Missing: [unknown]"
  """

  @variable_pattern ~r/\[([^\]]+)\]/

  @doc """
  Interpolates variables in text with values from data context.

  ## Parameters

  - `text` - Text containing [variable_name] patterns
  - `data` - Map containing variable values

  ## Returns

  String with variables replaced by their values.

  ## Examples

      iex> interpolate("Hello [name]!", %{name: "Alice"})
      "Hello Alice!"

      iex> interpolate("[greeting] [name]!", %{greeting: "Hi", name: "Bob"})
      "Hi Bob!"
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

  ## Examples

      iex> get_variable_value(%{name: "Alice"}, "name")
      "Alice"

      iex> get_variable_value(%{user: %{name: "Bob"}}, "user.name")
      "Bob"

      iex> get_variable_value(%{}, "missing")
      "[missing]"
  """
  @spec get_variable_value(map(), String.t()) :: String.t()
  def get_variable_value(data, variable_name) when is_map(data) do
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
end
