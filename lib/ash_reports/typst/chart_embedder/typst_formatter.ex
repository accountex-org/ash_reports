defmodule AshReports.Typst.ChartEmbedder.TypstFormatter do
  @moduledoc """
  Formats Typst code for chart embedding.

  Provides utilities for:
  - Dimension formatting (pt, mm, cm, %, fr)
  - String escaping for Typst safety
  - Grid and flow layout code generation
  - Caption and title wrapping
  """

  @doc """
  Formats a dimension value for Typst.

  ## Parameters

    - `value` - Dimension as string or number
      - String: "100%", "300pt", "50mm", "1fr"
      - Number: treated as points (pt)

  ## Returns

  Formatted Typst dimension string

  ## Examples

      format_dimension("100%") # => "100%"
      format_dimension("300pt") # => "300pt"
      format_dimension(300) # => "300pt"
      format_dimension("1fr") # => "1fr"
  """
  @spec format_dimension(String.t() | number()) :: String.t()
  def format_dimension(value) when is_binary(value) do
    # Already formatted, return as-is
    value
  end

  def format_dimension(value) when is_number(value) do
    # Treat numbers as points
    "#{value}pt"
  end

  @doc """
  Escapes a string for safe use in Typst code.

  Escapes special Typst characters:
  - Backslash (\\)
  - Double quotes (")
  - Hash (#)
  - Square brackets ([])

  ## Examples

      escape_string("Sales Report") # => "Sales Report"
      escape_string("Q1 \"Actual\"") # => "Q1 \\\"Actual\\\""
      escape_string("#hashtag") # => "\\#hashtag"
  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("#", "\\#")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
  end

  @doc """
  Builds a Typst grid layout from embedded chart codes.

  ## Parameters

    - `charts` - List of Typst code strings (already embedded)
    - `opts` - Grid options:
      - `:columns` - Number of columns (default: 2)
      - `:gutter` - Space between cells (default: "10pt")
      - `:column_widths` - Custom column widths (e.g., ["1fr", "2fr"])

  ## Returns

    - `{:ok, typst_grid_code}` - Complete grid code

  ## Examples

      charts = ["#image(...)", "#image(...)"]
      {:ok, grid} = build_grid(charts, columns: 2, gutter: "15pt")
  """
  @spec build_grid(list(String.t()), keyword()) :: {:ok, String.t()} | {:error, term()}
  def build_grid(charts, opts \\ []) when is_list(charts) do
    columns = Keyword.get(opts, :columns, 2)
    gutter = Keyword.get(opts, :gutter, "10pt")
    column_widths = Keyword.get(opts, :column_widths)

    columns_spec = build_columns_spec(columns, column_widths)

    # Wrap each chart in a content block
    chart_cells =
      charts
      |> Enum.map(fn chart -> "[#{chart}]" end)
      |> Enum.join(",\n  ")

    grid_code = """
    #grid(
      columns: #{columns_spec},
      gutter: #{gutter},
      #{chart_cells}
    )
    """

    {:ok, grid_code}
  end

  @doc """
  Builds a Typst flow (vertical stack) layout from embedded chart codes.

  ## Parameters

    - `charts` - List of Typst code strings (already embedded)
    - `spacing` - Vertical spacing between charts (default: "20pt")

  ## Returns

    - `{:ok, typst_flow_code}` - Complete flow code

  ## Examples

      charts = ["#image(...)", "#image(...)"]
      {:ok, flow} = build_flow(charts, "30pt")
  """
  @spec build_flow(list(String.t()), String.t()) :: {:ok, String.t()} | {:error, term()}
  def build_flow(charts, spacing \\ "20pt") when is_list(charts) do
    flow_code =
      charts
      |> Enum.intersperse("#v(#{spacing})")
      |> Enum.join("\n")

    {:ok, flow_code}
  end

  # Private functions

  defp build_columns_spec(columns, nil) when is_integer(columns) do
    # Default: equal width columns using fr
    widths =
      1..columns
      |> Enum.map(fn _ -> "1fr" end)
      |> Enum.join(", ")

    "(#{widths})"
  end

  defp build_columns_spec(_columns, column_widths) when is_list(column_widths) do
    # Custom column widths
    widths = Enum.join(column_widths, ", ")
    "(#{widths})"
  end
end
