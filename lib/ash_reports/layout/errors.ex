defmodule AshReports.Layout.Errors do
  @moduledoc """
  Error types and formatting for layout transformation errors.

  This module provides:
  - Structured error types for DSL validation
  - Positioning conflict errors
  - Property validation errors
  - Formatted error messages with context

  ## Error Categories

  1. **DSL Validation** - Invalid property values, nesting, required properties
  2. **Positioning** - Cell conflicts, span overflow, invalid positions
  3. **Property Validation** - Track sizes, colors, alignments, lengths

  ## Usage

      # Create a validation error
      error = Errors.invalid_property(:align, :diagonal, [:left, :center, :right])
      message = Errors.format(error)
      # => "Invalid alignment: :diagonal. Expected one of: [:left, :center, :right]"

      # Create a positioning error
      error = Errors.position_conflict({2, 1}, :existing_cell)
      message = Errors.format(error)
      # => "Cell at (2, 1) conflicts with existing cell"
  """

  @typedoc "Error tuple with type and details"
  @type t ::
          {:invalid_property, atom(), any(), list() | String.t()}
          | {:invalid_nesting, atom(), atom()}
          | {:missing_required, atom(), atom()}
          | {:position_conflict, {integer(), integer()}, atom()}
          | {:span_overflow, {integer(), integer()}, {integer(), integer()}, integer()}
          | {:invalid_position, {integer(), integer()}, {integer(), integer()}}
          | {:grid_gap, {integer(), integer()}}
          | {:invalid_track_size, String.t()}
          | {:invalid_color, String.t()}
          | {:invalid_alignment, any()}
          | {:invalid_length, String.t()}
          | {:unknown_element_type, any()}
          | {:unsupported_layout_type, any()}
          | {:no_layout_in_band, any()}

  # DSL Validation Errors

  @doc """
  Creates an error for invalid property values.

  ## Examples

      iex> Errors.invalid_property(:align, :diagonal, [:left, :center, :right])
      {:invalid_property, :align, :diagonal, [:left, :center, :right]}
  """
  @spec invalid_property(atom(), any(), list() | String.t()) :: t()
  def invalid_property(property, value, expected) do
    {:invalid_property, property, value, expected}
  end

  @doc """
  Creates an error for incorrect entity nesting.

  ## Examples

      iex> Errors.invalid_nesting(:cell, :cell)
      {:invalid_nesting, :cell, :cell}
  """
  @spec invalid_nesting(atom(), atom()) :: t()
  def invalid_nesting(parent, child) do
    {:invalid_nesting, parent, child}
  end

  @doc """
  Creates an error for missing required properties.

  ## Examples

      iex> Errors.missing_required(:grid, :columns)
      {:missing_required, :grid, :columns}
  """
  @spec missing_required(atom(), atom()) :: t()
  def missing_required(entity_type, property) do
    {:missing_required, entity_type, property}
  end

  # Positioning Errors

  @doc """
  Creates an error for cell position conflicts.

  ## Examples

      iex> Errors.position_conflict({2, 1}, :existing_cell)
      {:position_conflict, {2, 1}, :existing_cell}
  """
  @spec position_conflict({integer(), integer()}, atom()) :: t()
  def position_conflict(position, reason) do
    {:position_conflict, position, reason}
  end

  @doc """
  Creates an error for span overflow beyond grid bounds.

  ## Examples

      iex> Errors.span_overflow({2, 0}, {3, 1}, 4)
      {:span_overflow, {2, 0}, {3, 1}, 4}
  """
  @spec span_overflow({integer(), integer()}, {integer(), integer()}, integer()) :: t()
  def span_overflow(position, span, grid_width) do
    {:span_overflow, position, span, grid_width}
  end

  @doc """
  Creates an error for positions outside grid bounds.

  ## Examples

      iex> Errors.invalid_position({5, 0}, {4, 3})
      {:invalid_position, {5, 0}, {4, 3}}
  """
  @spec invalid_position({integer(), integer()}, {integer(), integer()}) :: t()
  def invalid_position(position, bounds) do
    {:invalid_position, position, bounds}
  end

  @doc """
  Creates a warning for gaps in grid layout.

  ## Examples

      iex> Errors.grid_gap({1, 2})
      {:grid_gap, {1, 2}}
  """
  @spec grid_gap({integer(), integer()}) :: t()
  def grid_gap(position) do
    {:grid_gap, position}
  end

  # Property Validation Errors

  @doc """
  Creates an error for invalid track size format.

  ## Examples

      iex> Errors.invalid_track_size("abc")
      {:invalid_track_size, "abc"}
  """
  @spec invalid_track_size(String.t()) :: t()
  def invalid_track_size(value) do
    {:invalid_track_size, value}
  end

  @doc """
  Creates an error for invalid color format.

  ## Examples

      iex> Errors.invalid_color("not-a-color")
      {:invalid_color, "not-a-color"}
  """
  @spec invalid_color(String.t()) :: t()
  def invalid_color(value) do
    {:invalid_color, value}
  end

  @doc """
  Creates an error for invalid alignment value.

  ## Examples

      iex> Errors.invalid_alignment(:diagonal)
      {:invalid_alignment, :diagonal}
  """
  @spec invalid_alignment(any()) :: t()
  def invalid_alignment(value) do
    {:invalid_alignment, value}
  end

  @doc """
  Creates an error for invalid length unit.

  ## Examples

      iex> Errors.invalid_length("10px")
      {:invalid_length, "10px"}
  """
  @spec invalid_length(String.t()) :: t()
  def invalid_length(value) do
    {:invalid_length, value}
  end

  # Formatting

  @doc """
  Formats an error tuple into a human-readable message.

  ## Examples

      iex> Errors.format({:invalid_property, :align, :diagonal, [:left, :center, :right]})
      "Invalid alignment: :diagonal. Expected one of: [:left, :center, :right]"

      iex> Errors.format({:position_conflict, {2, 1}, :existing_cell})
      "Cell at (2, 1) conflicts with existing cell"
  """
  @spec format(t()) :: String.t()
  def format({:invalid_property, property, value, expected}) when is_list(expected) do
    "Invalid #{property}: #{inspect(value)}. Expected one of: #{inspect(expected)}"
  end

  def format({:invalid_property, property, value, expected}) when is_binary(expected) do
    "Invalid #{property}: #{inspect(value)}. #{expected}"
  end

  def format({:invalid_nesting, parent, child}) do
    "#{child} cannot be nested directly inside #{parent}"
  end

  def format({:missing_required, entity_type, property}) do
    "#{property} is required for #{entity_type}"
  end

  def format({:position_conflict, {x, y}, reason}) do
    "Cell at (#{x}, #{y}) conflicts with #{format_reason(reason)}"
  end

  def format({:span_overflow, {x, _y}, {colspan, _rowspan}, grid_width}) do
    "colspan #{colspan} at column #{x} exceeds grid width of #{grid_width}"
  end

  def format({:invalid_position, {x, y}, {max_x, max_y}}) do
    "Position (#{x}, #{y}) outside grid bounds (#{max_x}, #{max_y})"
  end

  def format({:grid_gap, {x, y}}) do
    "No cell at position (#{x}, #{y})"
  end

  def format({:invalid_track_size, value}) do
    "Invalid track size: '#{value}'"
  end

  def format({:invalid_color, value}) do
    "Invalid color: '#{value}'"
  end

  def format({:invalid_alignment, value}) do
    "Invalid alignment: #{inspect(value)}"
  end

  def format({:invalid_length, value}) do
    "Unknown unit in '#{value}'"
  end

  def format({:unknown_element_type, value}) do
    "Unknown element type: #{inspect(value)}"
  end

  def format({:unsupported_layout_type, value}) do
    "Unsupported layout type: #{inspect(value)}"
  end

  def format({:no_layout_in_band, _band}) do
    "Band does not contain a layout"
  end

  def format(other) do
    "Unknown error: #{inspect(other)}"
  end

  @doc """
  Formats an error with file/line location information.

  ## Examples

      iex> error = {:invalid_property, :align, :diagonal, [:left, :center, :right]}
      iex> Errors.format_with_location(error, "lib/my_report.ex", 42)
      "lib/my_report.ex:42: Invalid alignment: :diagonal. Expected one of: [:left, :center, :right]"
  """
  @spec format_with_location(t(), String.t(), integer()) :: String.t()
  def format_with_location(error, file, line) do
    "#{file}:#{line}: #{format(error)}"
  end

  # Validation Functions

  @doc """
  Validates that a value is one of the allowed options.

  ## Examples

      iex> Errors.validate_one_of(:align, :center, [:left, :center, :right])
      :ok

      iex> Errors.validate_one_of(:align, :diagonal, [:left, :center, :right])
      {:error, {:invalid_property, :align, :diagonal, [:left, :center, :right]}}
  """
  @spec validate_one_of(atom(), any(), list()) :: :ok | {:error, t()}
  def validate_one_of(property, value, allowed) do
    if value in allowed do
      :ok
    else
      {:error, invalid_property(property, value, allowed)}
    end
  end

  @doc """
  Validates a track size format (length, fr, auto).

  ## Examples

      iex> Errors.validate_track_size("1fr")
      :ok

      iex> Errors.validate_track_size("abc")
      {:error, {:invalid_track_size, "abc"}}
  """
  @spec validate_track_size(String.t() | number() | atom()) :: :ok | {:error, t()}
  def validate_track_size("auto"), do: :ok
  def validate_track_size(:auto), do: :ok
  def validate_track_size(value) when is_number(value), do: :ok

  def validate_track_size(value) when is_binary(value) do
    cond do
      String.ends_with?(value, "fr") -> validate_numeric_prefix(value, "fr")
      String.ends_with?(value, "pt") -> validate_numeric_prefix(value, "pt")
      String.ends_with?(value, "cm") -> validate_numeric_prefix(value, "cm")
      String.ends_with?(value, "mm") -> validate_numeric_prefix(value, "mm")
      String.ends_with?(value, "in") -> validate_numeric_prefix(value, "in")
      String.ends_with?(value, "%") -> validate_numeric_prefix(value, "%")
      String.ends_with?(value, "em") -> validate_numeric_prefix(value, "em")
      true -> {:error, invalid_track_size(value)}
    end
  end

  def validate_track_size(value), do: {:error, invalid_track_size(inspect(value))}

  @doc """
  Validates a color format.

  Accepts:
  - Named colors: "red", "blue", "white", etc.
  - Hex colors: "#ff0000", "#fff"
  - RGB: "rgb(255, 0, 0)"
  - Atoms: :red, :blue

  ## Examples

      iex> Errors.validate_color("red")
      :ok

      iex> Errors.validate_color("#ff0000")
      :ok

      iex> Errors.validate_color("not-a-color")
      {:error, {:invalid_color, "not-a-color"}}
  """
  @spec validate_color(String.t() | atom()) :: :ok | {:error, t()}
  def validate_color(value) when is_atom(value), do: :ok

  def validate_color(value) when is_binary(value) do
    cond do
      # Hex color
      Regex.match?(~r/^#[0-9a-fA-F]{3}$/, value) -> :ok
      Regex.match?(~r/^#[0-9a-fA-F]{6}$/, value) -> :ok
      Regex.match?(~r/^#[0-9a-fA-F]{8}$/, value) -> :ok
      # RGB/RGBA
      Regex.match?(~r/^rgba?\s*\(/, value) -> :ok
      # Named colors (common ones)
      value in named_colors() -> :ok
      # Typst color functions
      String.starts_with?(value, "luma(") -> :ok
      String.starts_with?(value, "oklab(") -> :ok
      String.starts_with?(value, "oklch(") -> :ok
      String.starts_with?(value, "color.") -> :ok
      true -> {:error, invalid_color(value)}
    end
  end

  def validate_color(value), do: {:error, invalid_color(inspect(value))}

  @doc """
  Validates an alignment value.

  Accepts:
  - Horizontal: :left, :center, :right, "left", "center", "right"
  - Vertical: :top, :horizon, :bottom, "top", "horizon", "bottom"
  - Combined: "left+top", "center+horizon", etc.

  ## Examples

      iex> Errors.validate_alignment(:center)
      :ok

      iex> Errors.validate_alignment("left+top")
      :ok

      iex> Errors.validate_alignment(:diagonal)
      {:error, {:invalid_alignment, :diagonal}}
  """
  @spec validate_alignment(any()) :: :ok | {:error, t()}
  def validate_alignment(value) when value in [:left, :center, :right, :top, :horizon, :bottom, :start, :end] do
    :ok
  end

  def validate_alignment(value) when is_binary(value) do
    parts = String.split(value, "+")

    valid_parts =
      Enum.all?(parts, fn part ->
        part in ["left", "center", "right", "top", "horizon", "bottom", "start", "end"]
      end)

    if valid_parts and length(parts) <= 2 do
      :ok
    else
      {:error, invalid_alignment(value)}
    end
  end

  def validate_alignment(value), do: {:error, invalid_alignment(value)}

  @doc """
  Validates a length value format.

  ## Examples

      iex> Errors.validate_length("10pt")
      :ok

      iex> Errors.validate_length("10px")
      {:error, {:invalid_length, "10px"}}
  """
  @spec validate_length(String.t() | number() | atom()) :: :ok | {:error, t()}
  def validate_length("auto"), do: :ok
  def validate_length(:auto), do: :ok
  def validate_length(value) when is_number(value), do: :ok

  def validate_length(value) when is_binary(value) do
    # Use regex to match exact units (not substrings like "rem" matching "em")
    cond do
      Regex.match?(~r/^-?\d+\.?\d*pt$/, value) -> :ok
      Regex.match?(~r/^-?\d+\.?\d*cm$/, value) -> :ok
      Regex.match?(~r/^-?\d+\.?\d*mm$/, value) -> :ok
      Regex.match?(~r/^-?\d+\.?\d*in$/, value) -> :ok
      Regex.match?(~r/^-?\d+\.?\d*%$/, value) -> :ok
      Regex.match?(~r/^-?\d+\.?\d*fr$/, value) -> :ok
      Regex.match?(~r/^-?\d+\.?\d*em$/, value) -> :ok
      true ->
        # Check if it's a plain number
        case Float.parse(value) do
          {_num, ""} -> :ok
          _ -> {:error, invalid_length(value)}
        end
    end
  end

  def validate_length(value), do: {:error, invalid_length(inspect(value))}

  # Private helpers

  defp validate_numeric_prefix(value, suffix) do
    num_str = String.trim_trailing(value, suffix)

    case Float.parse(num_str) do
      {_num, ""} -> :ok
      _ -> {:error, invalid_track_size(value)}
    end
  end

  defp format_reason(:existing_cell), do: "existing cell"
  defp format_reason(:spanning_cell), do: "spanning cell"
  defp format_reason(:explicit_cell), do: "explicitly positioned cell"
  defp format_reason(other), do: inspect(other)

  defp named_colors do
    [
      "black", "white", "red", "green", "blue", "yellow", "cyan", "magenta",
      "gray", "grey", "orange", "purple", "pink", "brown", "navy", "teal",
      "maroon", "olive", "lime", "aqua", "fuchsia", "silver", "transparent",
      "lightgray", "lightgrey", "darkgray", "darkgrey"
    ]
  end
end
