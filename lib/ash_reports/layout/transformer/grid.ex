defmodule AshReports.Layout.Transformer.Grid do
  @moduledoc """
  Transforms Grid DSL entities to GridIR.

  Handles transformation of columns, rows, gutters, and other grid properties
  to the normalized IR format.
  """

  alias AshReports.Layout.{Grid, IR}
  alias AshReports.Layout.Transformer.{Cell, Row}

  @doc """
  Transforms a Grid DSL entity to a LayoutIR.

  ## Examples

      iex> grid = %AshReports.Layout.Grid{name: :my_grid, columns: 3}
      iex> {:ok, ir} = AshReports.Layout.Transformer.Grid.transform(grid)
      iex> ir.type
      :grid
  """
  @spec transform(Grid.t()) :: {:ok, IR.t()} | {:error, term()}
  def transform(%Grid{} = grid) do
    with {:ok, columns} <- normalize_tracks(grid.columns, :columns),
         {:ok, rows} <- normalize_tracks(grid.rows, :rows),
         {:ok, children} <- transform_children(grid),
         {:ok, properties} <- build_properties(grid, columns, rows) do
      ir = IR.new(:grid,
        properties: properties,
        children: children
      )

      {:ok, ir}
    end
  end

  @doc """
  Normalizes track sizes to a consistent list format.

  Handles integer (column count), list of sizes, or :auto.
  """
  @spec normalize_tracks(pos_integer() | [term()] | :auto | nil, atom()) ::
          {:ok, [String.t()]} | {:error, term()}
  def normalize_tracks(nil, _type), do: {:ok, []}
  def normalize_tracks(:auto, _type), do: {:ok, ["auto"]}

  def normalize_tracks(count, _type) when is_integer(count) and count > 0 do
    tracks = List.duplicate("auto", count)
    {:ok, tracks}
  end

  def normalize_tracks(tracks, _type) when is_list(tracks) do
    normalized =
      Enum.map(tracks, fn track ->
        normalize_track_size(track)
      end)

    {:ok, normalized}
  end

  def normalize_tracks(invalid, type) do
    {:error, {:invalid_track_definition, type, invalid}}
  end

  @doc """
  Normalizes a single track size to string format.

  Integer values in lists are treated as fraction units (e.g., 2 -> "2fr").
  Use strings with explicit units for point sizes (e.g., "100pt").
  """
  @spec normalize_track_size(term()) :: String.t()
  def normalize_track_size(:auto), do: "auto"
  def normalize_track_size({:fr, n}) when is_number(n), do: "#{n}fr"
  def normalize_track_size({:pt, n}) when is_number(n), do: "#{n}pt"
  def normalize_track_size(size) when is_binary(size), do: size
  # Integers in lists are treated as fraction units for column/row proportions
  def normalize_track_size(n) when is_integer(n), do: "#{n}fr"
  def normalize_track_size(n) when is_float(n), do: "#{n}fr"

  # Private functions

  defp transform_children(%Grid{} = grid) do
    # Collect all children: elements, row_entities, and grid_cells
    children = []

    # Transform row entities
    row_children =
      Enum.with_index(grid.row_entities)
      |> Enum.map(fn {row, index} ->
        case Row.transform(row, index) do
          {:ok, row_ir} -> row_ir
          {:error, _} = err -> throw(err)
        end
      end)

    # Transform grid cells (loose cells not in rows)
    cell_children =
      Enum.map(grid.grid_cells, fn cell ->
        case Cell.transform(cell) do
          {:ok, cell_ir} -> cell_ir
          {:error, _} = err -> throw(err)
        end
      end)

    # Transform elements (labels, fields in grid)
    element_children =
      Enum.map(grid.elements, fn element ->
        case transform_element(element) do
          {:ok, content_ir} ->
            # Wrap element content in a cell
            IR.Cell.new(content: [content_ir])
          {:error, _} = err -> throw(err)
        end
      end)

    all_children = children ++ row_children ++ cell_children ++ element_children
    {:ok, all_children}
  catch
    {:error, _} = err -> err
  end

  defp transform_element(element) do
    cond do
      Map.has_key?(element, :text) ->
        # Label element
        style = build_element_style(element)
        {:ok, IR.Content.label(element.text || "", style: style)}

      Map.has_key?(element, :source) ->
        # Field element
        style = build_element_style(element)
        {:ok, IR.Content.field(element.source,
          format: Map.get(element, :format),
          decimal_places: Map.get(element, :decimal_places),
          style: style
        )}

      true ->
        {:error, {:unknown_element_type, element}}
    end
  end

  defp build_element_style(element) do
    # Style properties are nested under the :style key in the element
    # Style can be a map or keyword list depending on how it was defined
    style = Map.get(element, :style) || %{}

    style_props = [
      font_size: get_style_prop(style, :font_size),
      font_weight: get_style_prop(style, :font_weight),
      font_style: get_style_prop(style, :font_style),
      color: get_style_prop(style, :color),
      font_family: get_style_prop(style, :font_family),
      text_align: get_style_prop(style, :text_align)
    ]

    if Enum.all?(style_props, fn {_k, v} -> is_nil(v) end) do
      nil
    else
      IR.Style.new(style_props)
    end
  end

  # Helper to get style property from either a map or keyword list
  defp get_style_prop(style, key) when is_list(style), do: Keyword.get(style, key)
  defp get_style_prop(style, key) when is_map(style), do: Map.get(style, key)
  defp get_style_prop(_, _), do: nil

  defp build_properties(%Grid{} = grid, columns, rows) do
    properties = %{
      columns: columns,
      rows: rows,
      gutter: resolve_gutter(grid),
      column_gutter: grid.column_gutter,
      row_gutter: grid.row_gutter,
      align: grid.align,
      inset: grid.inset,
      fill: grid.fill,
      stroke: grid.stroke
    }

    # Remove nil values
    properties =
      properties
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, properties}
  end

  defp resolve_gutter(%Grid{gutter: gutter, column_gutter: col, row_gutter: row}) do
    cond do
      col || row -> nil  # Specific gutters override general
      gutter -> gutter
      true -> nil
    end
  end
end
