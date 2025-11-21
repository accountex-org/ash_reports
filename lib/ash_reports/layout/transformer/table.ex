defmodule AshReports.Layout.Transformer.Table do
  @moduledoc """
  Transforms Table DSL entities to TableIR.

  Extends grid transformation with table-specific properties like headers and footers.
  Tables have different defaults than grids (stroke: "1pt", inset: "5pt").
  """

  alias AshReports.Layout.{Table, IR}
  alias AshReports.Layout.Transformer.{Grid, Cell, Row}

  @doc """
  Transforms a Table DSL entity to a LayoutIR.

  ## Examples

      iex> table = %AshReports.Layout.Table{name: :my_table, columns: 3}
      iex> {:ok, ir} = AshReports.Layout.Transformer.Table.transform(table)
      iex> ir.type
      :table
  """
  @spec transform(Table.t()) :: {:ok, IR.t()} | {:error, term()}
  def transform(%Table{} = table) do
    with {:ok, columns} <- Grid.normalize_tracks(table.columns, :columns),
         {:ok, rows} <- Grid.normalize_tracks(table.rows, :rows),
         {:ok, children} <- transform_children(table),
         {:ok, headers} <- transform_headers(table),
         {:ok, footers} <- transform_footers(table),
         {:ok, properties} <- build_properties(table, columns, rows) do
      ir = IR.new(:table,
        properties: properties,
        children: children,
        headers: headers,
        footers: footers
      )

      {:ok, ir}
    end
  end

  defp transform_children(%Table{} = table) do
    children = []

    # Transform row entities
    row_children =
      Enum.with_index(table.row_entities)
      |> Enum.map(fn {row, index} ->
        case Row.transform(row, index) do
          {:ok, row_ir} -> row_ir
          {:error, _} = err -> throw(err)
        end
      end)

    # Transform table cells (loose cells not in rows)
    cell_children =
      Enum.map(table.table_cells, fn cell ->
        case Cell.transform(cell) do
          {:ok, cell_ir} -> cell_ir
          {:error, _} = err -> throw(err)
        end
      end)

    # Transform elements (labels, fields)
    element_children =
      Enum.map(table.elements, fn element ->
        case transform_element(element) do
          {:ok, content_ir} ->
            IR.Cell.new(content: [content_ir])
          {:error, _} = err -> throw(err)
        end
      end)

    all_children = children ++ row_children ++ cell_children ++ element_children
    {:ok, all_children}
  catch
    {:error, _} = err -> err
  end

  defp transform_headers(%Table{headers: headers}) do
    header_irs =
      Enum.map(headers, fn header ->
        case transform_header(header) do
          {:ok, header_ir} -> header_ir
          {:error, _} = err -> throw(err)
        end
      end)

    {:ok, header_irs}
  catch
    {:error, _} = err -> err
  end

  defp transform_header(header) do
    # Transform header rows
    rows =
      Map.get(header, :elements, [])
      |> Enum.with_index()
      |> Enum.map(fn {row_or_cell, index} ->
        # Check if it's a row or a cell
        if Map.has_key?(row_or_cell, :elements) do
          case Row.transform(row_or_cell, index) do
            {:ok, row_ir} -> row_ir
            {:error, _} = err -> throw(err)
          end
        else
          # It's a cell, wrap in a row
          case Cell.transform(row_or_cell) do
            {:ok, cell_ir} ->
              IR.Row.new(index: index, cells: [cell_ir])
            {:error, _} = err -> throw(err)
          end
        end
      end)

    header_ir = IR.Header.new(
      repeat: Map.get(header, :repeat, true),
      level: Map.get(header, :level, 0),
      rows: rows
    )

    {:ok, header_ir}
  catch
    {:error, _} = err -> err
  end

  defp transform_footers(%Table{footers: footers}) do
    footer_irs =
      Enum.map(footers, fn footer ->
        case transform_footer(footer) do
          {:ok, footer_ir} -> footer_ir
          {:error, _} = err -> throw(err)
        end
      end)

    {:ok, footer_irs}
  catch
    {:error, _} = err -> err
  end

  defp transform_footer(footer) do
    # Transform footer rows
    rows =
      Map.get(footer, :elements, [])
      |> Enum.with_index()
      |> Enum.map(fn {row_or_cell, index} ->
        if Map.has_key?(row_or_cell, :elements) do
          case Row.transform(row_or_cell, index) do
            {:ok, row_ir} -> row_ir
            {:error, _} = err -> throw(err)
          end
        else
          case Cell.transform(row_or_cell) do
            {:ok, cell_ir} ->
              IR.Row.new(index: index, cells: [cell_ir])
            {:error, _} = err -> throw(err)
          end
        end
      end)

    footer_ir = IR.Footer.new(
      repeat: Map.get(footer, :repeat, false),
      rows: rows
    )

    {:ok, footer_ir}
  catch
    {:error, _} = err -> err
  end

  defp transform_element(element) do
    cond do
      Map.has_key?(element, :text) ->
        style = build_element_style(element)
        {:ok, IR.Content.label(element.text || "", style: style)}

      Map.has_key?(element, :source) ->
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
    style_props = [
      font_size: Map.get(element, :font_size),
      font_weight: Map.get(element, :font_weight),
      color: Map.get(element, :color),
      font_family: Map.get(element, :font_family),
      text_align: Map.get(element, :text_align)
    ]

    if Enum.all?(style_props, fn {_k, v} -> is_nil(v) end) do
      nil
    else
      IR.Style.new(style_props)
    end
  end

  defp build_properties(%Table{} = table, columns, rows) do
    # Apply table defaults
    stroke = table.stroke || "1pt"
    inset = table.inset || "5pt"

    properties = %{
      columns: columns,
      rows: rows,
      gutter: resolve_gutter(table),
      column_gutter: table.column_gutter,
      row_gutter: table.row_gutter,
      align: table.align,
      inset: inset,
      fill: table.fill,
      stroke: stroke
    }

    # Remove nil values (but keep defaults)
    properties =
      properties
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, properties}
  end

  defp resolve_gutter(%Table{gutter: gutter, column_gutter: col, row_gutter: row}) do
    cond do
      col || row -> nil
      gutter -> gutter
      true -> nil
    end
  end
end
