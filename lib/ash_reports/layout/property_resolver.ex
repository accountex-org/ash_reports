defmodule AshReports.Layout.PropertyResolver do
  @moduledoc """
  Resolves property inheritance and normalization for layout elements.

  This module handles:
  - Property inheritance chain (grid/table -> row -> cell)
  - Property override at each level
  - Conditional property detection and preservation
  - Length value normalization

  ## Inheritance Chain

  Properties flow from parent to child:
  1. Grid/Table level - defines defaults for all children
  2. Row level - can override grid/table properties
  3. Cell level - can override row and grid/table properties

  ## Examples

      # Resolve cell properties with inheritance
      parent_props = %{align: "left", inset: "5pt"}
      cell_props = %{align: "center"}  # overrides parent
      resolved = PropertyResolver.resolve(cell_props, parent_props)
      # => %{align: "center", inset: "5pt"}

      # Parse length values
      {:ok, length} = PropertyResolver.parse_length("10pt")
      # => {:ok, {10.0, :pt}}
  """

  alias AshReports.Layout.Errors

  @doc """
  Resolves properties by merging child with parent, child taking precedence.

  ## Parameters

  - `child_props` - Properties from the child element (higher priority)
  - `parent_props` - Properties from the parent element (lower priority)
  - `defaults` - Default values if neither child nor parent specifies (optional)

  ## Returns

  Merged properties map with child overriding parent.
  """
  @spec resolve(map(), map(), map()) :: map()
  def resolve(child_props, parent_props, defaults \\ %{}) do
    defaults
    |> Map.merge(parent_props)
    |> Map.merge(child_props)
    |> reject_nil_values()
  end

  @doc """
  Resolves properties through the full inheritance chain.

  ## Parameters

  - `cell_props` - Cell-level properties
  - `row_props` - Row-level properties
  - `container_props` - Grid/Table-level properties
  - `defaults` - Default values

  ## Returns

  Fully resolved properties map.
  """
  @spec resolve_chain(map(), map(), map(), map()) :: map()
  def resolve_chain(cell_props, row_props, container_props, defaults \\ %{}) do
    defaults
    |> Map.merge(container_props)
    |> Map.merge(row_props)
    |> Map.merge(cell_props)
    |> reject_nil_values()
  end

  @doc """
  Resolves the align property with inheritance and default.

  ## Parameters

  - `props` - Properties map to extract align from
  - `parent_props` - Parent properties for inheritance
  - `default` - Default alignment if not specified

  ## Returns

  The resolved alignment value.
  """
  @spec resolve_align(map(), map(), String.t() | atom()) :: String.t() | atom() | nil
  def resolve_align(props, parent_props \\ %{}, default \\ nil) do
    props[:align] || props["align"] ||
      parent_props[:align] || parent_props["align"] ||
      default
  end

  @doc """
  Resolves the inset property with inheritance and default.

  ## Parameters

  - `props` - Properties map to extract inset from
  - `parent_props` - Parent properties for inheritance
  - `default` - Default inset if not specified

  ## Returns

  The resolved inset value.
  """
  @spec resolve_inset(map(), map(), String.t() | nil) :: String.t() | nil
  def resolve_inset(props, parent_props \\ %{}, default \\ nil) do
    props[:inset] || props["inset"] ||
      parent_props[:inset] || parent_props["inset"] ||
      default
  end

  @doc """
  Checks if a property value is a function (conditional/dynamic).

  ## Examples

      iex> PropertyResolver.is_dynamic?(&(&1 + &2))
      true

      iex> PropertyResolver.is_dynamic?("blue")
      false
  """
  @spec is_dynamic?(any()) :: boolean()
  def is_dynamic?(value) when is_function(value), do: true
  def is_dynamic?(_), do: false

  @doc """
  Separates static and dynamic properties.

  ## Parameters

  - `props` - Properties map

  ## Returns

  Tuple of {static_props, dynamic_props}
  """
  @spec separate_static_dynamic(map()) :: {map(), map()}
  def separate_static_dynamic(props) do
    {static, dynamic} =
      props
      |> Enum.split_with(fn {_k, v} -> not is_dynamic?(v) end)

    {Map.new(static), Map.new(dynamic)}
  end

  @doc """
  Evaluates a dynamic property (function) with context.

  ## Parameters

  - `func` - The function to evaluate
  - `context` - Context map with :x, :y, :row, :col keys

  ## Returns

  The evaluated value or nil if not a function.
  """
  @spec evaluate_dynamic(any(), map()) :: any()
  def evaluate_dynamic(func, context) when is_function(func, 2) do
    x = context[:x] || context[:col] || 0
    y = context[:y] || context[:row] || 0
    func.(x, y)
  end

  def evaluate_dynamic(func, context) when is_function(func, 1) do
    func.(context)
  end

  def evaluate_dynamic(value, _context), do: value

  @doc """
  Parses a length string into a normalized representation.

  ## Supported formats

  - `"100pt"` - Points
  - `"2cm"` - Centimeters
  - `"25.4mm"` - Millimeters
  - `"1in"` - Inches
  - `"20%"` - Percentage
  - `"1fr"` - Fractional unit
  - `"auto"` - Auto sizing

  ## Returns

  - `{:ok, {value, unit}}` for numeric lengths
  - `{:ok, :auto}` for auto
  - `{:error, reason}` for invalid formats
  """
  @spec parse_length(String.t() | number() | atom()) :: {:ok, {number(), atom()} | atom()} | {:error, term()}
  def parse_length("auto"), do: {:ok, :auto}
  def parse_length(:auto), do: {:ok, :auto}

  def parse_length(value) when is_number(value) do
    {:ok, {value * 1.0, :pt}}
  end

  def parse_length(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "auto" ->
        {:ok, :auto}

      String.ends_with?(value, "pt") ->
        parse_numeric(value, "pt", :pt)

      String.ends_with?(value, "cm") ->
        parse_numeric(value, "cm", :cm)

      String.ends_with?(value, "mm") ->
        parse_numeric(value, "mm", :mm)

      String.ends_with?(value, "in") ->
        parse_numeric(value, "in", :in)

      String.ends_with?(value, "%") ->
        parse_numeric(value, "%", :percent)

      String.ends_with?(value, "fr") ->
        parse_numeric(value, "fr", :fr)

      String.ends_with?(value, "em") ->
        parse_numeric(value, "em", :em)

      true ->
        # Try to parse as plain number (default to pt)
        case Float.parse(value) do
          {num, ""} -> {:ok, {num, :pt}}
          _ -> {:error, Errors.invalid_length(value)}
        end
    end
  end

  def parse_length(value), do: {:error, Errors.invalid_length(inspect(value))}

  @doc """
  Normalizes a length value to points.

  ## Conversion rates

  - 1in = 72pt
  - 1cm = 28.3465pt
  - 1mm = 2.83465pt

  ## Returns

  - `{:ok, points}` for absolute lengths
  - `{:ok, {:percent, value}}` for percentages
  - `{:ok, {:fr, value}}` for fractional units
  - `{:ok, :auto}` for auto
  - `{:error, reason}` for invalid input
  """
  @spec normalize_to_points(String.t() | number() | atom()) :: {:ok, number() | {atom(), number()} | atom()} | {:error, term()}
  def normalize_to_points(value) do
    case parse_length(value) do
      {:ok, :auto} ->
        {:ok, :auto}

      {:ok, {num, :pt}} ->
        {:ok, num}

      {:ok, {num, :cm}} ->
        {:ok, num * 28.3465}

      {:ok, {num, :mm}} ->
        {:ok, num * 2.83465}

      {:ok, {num, :in}} ->
        {:ok, num * 72.0}

      {:ok, {num, :em}} ->
        # em is relative, preserve it
        {:ok, {:em, num}}

      {:ok, {num, :percent}} ->
        {:ok, {:percent, num}}

      {:ok, {num, :fr}} ->
        {:ok, {:fr, num}}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Parses and normalizes multiple length values (e.g., for padding).

  ## Examples

      iex> PropertyResolver.parse_lengths("5pt 10pt")
      {:ok, [{5.0, :pt}, {10.0, :pt}]}

      iex> PropertyResolver.parse_lengths("5pt")
      {:ok, [{5.0, :pt}]}
  """
  @spec parse_lengths(String.t()) :: {:ok, list()} | {:error, term()}
  def parse_lengths(value) when is_binary(value) do
    parts = String.split(value, ~r/\s+/, trim: true)

    results =
      Enum.map(parts, fn part ->
        case parse_length(part) do
          {:ok, length} -> {:ok, length}
          {:error, _} = err -> err
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      lengths = Enum.map(results, fn {:ok, l} -> l end)
      {:ok, lengths}
    else
      {:error, {:invalid_lengths, value}}
    end
  end

  def parse_lengths(value), do: {:error, {:invalid_lengths, value}}

  @doc """
  Resolves all properties in a properties map, normalizing lengths.

  ## Parameters

  - `props` - Properties map with potential length values

  ## Returns

  Properties map with lengths normalized.
  """
  @spec resolve_all(map()) :: map()
  def resolve_all(props) do
    length_keys = [:inset, :gutter, :column_gutter, :row_gutter, :stroke, :height]

    Enum.reduce(length_keys, props, fn key, acc ->
      case Map.get(acc, key) do
        nil -> acc
        value when is_binary(value) ->
          case parse_length(value) do
            {:ok, parsed} -> Map.put(acc, key, parsed)
            {:error, _} -> acc  # Keep original on error
          end
        _ -> acc
      end
    end)
  end

  # Private functions

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_numeric(value, suffix, unit) do
    num_str = String.trim_trailing(value, suffix)
    case Float.parse(num_str) do
      {num, ""} -> {:ok, {num, unit}}
      _ -> {:error, Errors.invalid_length(value)}
    end
  end
end
