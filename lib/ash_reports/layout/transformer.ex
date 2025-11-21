defmodule AshReports.Layout.Transformer do
  @moduledoc """
  Main transformer pipeline for converting DSL entities to IR.

  This module provides the entry point for transforming layout DSL entities
  (Grid, Table, Stack) into the normalized Intermediate Representation (IR).

  ## Pipeline Stages

  1. **Entity Transformation** - Convert DSL structs to IR structures
  2. **Cell Positioning** - Calculate positions for automatic flow
  3. **Property Resolution** - Resolve inherited properties

  ## Usage

      # Transform a grid with full pipeline
      {:ok, ir} = AshReports.Layout.Transformer.transform(grid_dsl)

      # Transform a table
      {:ok, ir} = AshReports.Layout.Transformer.transform(table_dsl)

      # Transform a stack
      {:ok, ir} = AshReports.Layout.Transformer.transform(stack_dsl)

      # Transform with options
      {:ok, ir} = AshReports.Layout.Transformer.transform(grid_dsl, position: true, resolve: true)
  """

  alias AshReports.Layout.{Positioning, PropertyResolver}

  @doc """
  Transforms a DSL layout entity to its IR representation.

  Dispatches to the appropriate transformer based on the entity type,
  then applies positioning and property resolution.

  ## Options

  - `:position` - Whether to apply cell positioning (default: true)
  - `:resolve` - Whether to resolve properties (default: true)

  ## Examples

      iex> grid = %AshReports.Layout.Grid{name: :test, columns: 3}
      iex> {:ok, ir} = AshReports.Layout.Transformer.transform(grid)
      iex> ir.type
      :grid
  """
  @spec transform(struct(), keyword()) :: {:ok, AshReports.Layout.IR.t()} | {:error, term()}
  def transform(entity, opts \\ []) do
    with {:ok, ir} <- transform_entity(entity),
         {:ok, ir} <- maybe_position(ir, opts),
         {:ok, ir} <- maybe_resolve(ir, opts) do
      {:ok, ir}
    end
  end

  @doc """
  Transforms a band's layout to IR.

  Extracts the layout from a band entity and transforms it.

  ## Examples

      iex> band = %{layout: %AshReports.Layout.Grid{columns: 2}}
      iex> {:ok, ir} = AshReports.Layout.Transformer.transform_band_layout(band)
  """
  @spec transform_band_layout(map()) :: {:ok, AshReports.Layout.IR.t()} | {:error, term()}
  def transform_band_layout(%{layout: layout}) when not is_nil(layout) do
    transform(layout)
  end

  def transform_band_layout(%{} = band) do
    # Check for layout in various places
    layout = Map.get(band, :layout) || Map.get(band, :grid) || Map.get(band, :table)

    if layout do
      transform(layout)
    else
      {:error, {:no_layout_in_band, band}}
    end
  end

  # Entity transformation (dispatches to type-specific transformers)

  defp transform_entity(%AshReports.Layout.Grid{} = grid) do
    AshReports.Layout.Transformer.Grid.transform(grid)
  end

  defp transform_entity(%AshReports.Layout.Table{} = table) do
    AshReports.Layout.Transformer.Table.transform(table)
  end

  defp transform_entity(%AshReports.Layout.Stack{} = stack) do
    AshReports.Layout.Transformer.Stack.transform(stack)
  end

  defp transform_entity(%{type: :grid} = map) do
    grid = struct(AshReports.Layout.Grid, map)
    AshReports.Layout.Transformer.Grid.transform(grid)
  end

  defp transform_entity(%{type: :table} = map) do
    table = struct(AshReports.Layout.Table, map)
    AshReports.Layout.Transformer.Table.transform(table)
  end

  defp transform_entity(%{type: :stack} = map) do
    stack = struct(AshReports.Layout.Stack, map)
    AshReports.Layout.Transformer.Stack.transform(stack)
  end

  defp transform_entity(other) do
    {:error, {:unsupported_layout_type, other}}
  end

  # Positioning stage

  defp maybe_position(ir, opts) do
    if Keyword.get(opts, :position, true) do
      apply_positioning(ir)
    else
      {:ok, ir}
    end
  end

  defp apply_positioning(%{type: type} = ir) when type in [:grid, :table] do
    columns = get_column_count(ir)

    # Separate rows from loose cells
    {rows, cells} = separate_rows_and_cells(ir.children)

    with {:ok, positioned_rows} <- position_rows(rows, columns),
         {:ok, positioned_cells} <- position_cells(cells, columns) do
      children = positioned_rows ++ positioned_cells
      {:ok, %{ir | children: children}}
    end
  end

  defp apply_positioning(ir) do
    # Stacks don't need positioning
    {:ok, ir}
  end

  defp get_column_count(%{properties: %{columns: columns}}) when is_list(columns) do
    length(columns)
  end

  defp get_column_count(_), do: 1

  defp separate_rows_and_cells(children) do
    Enum.split_with(children, fn
      %AshReports.Layout.IR.Row{} -> true
      _ -> false
    end)
  end

  defp position_rows([], _columns), do: {:ok, []}

  defp position_rows(rows, columns) do
    Positioning.position_rows(rows, columns: columns)
  end

  defp position_cells([], _columns), do: {:ok, []}

  defp position_cells(cells, columns) do
    Positioning.position_cells(cells, columns: columns)
  end

  # Property resolution stage

  defp maybe_resolve(ir, opts) do
    if Keyword.get(opts, :resolve, true) do
      apply_resolution(ir)
    else
      {:ok, ir}
    end
  end

  defp apply_resolution(%{type: type, properties: container_props, children: children} = ir)
       when type in [:grid, :table] do
    # Resolve properties for children
    resolved_children =
      Enum.map(children, fn child ->
        resolve_child_properties(child, container_props)
      end)

    {:ok, %{ir | children: resolved_children}}
  end

  defp apply_resolution(ir) do
    # Stacks pass through
    {:ok, ir}
  end

  defp resolve_child_properties(%AshReports.Layout.IR.Row{} = row, container_props) do
    row_props = row.properties || %{}

    # Resolve row properties from container
    resolved_row_props = PropertyResolver.resolve(row_props, container_props)

    # Resolve cells within row
    resolved_cells =
      Enum.map(row.cells, fn cell ->
        resolve_cell_properties(cell, resolved_row_props)
      end)

    %{row | properties: resolved_row_props, cells: resolved_cells}
  end

  defp resolve_child_properties(%AshReports.Layout.IR.Cell{} = cell, container_props) do
    resolve_cell_properties(cell, container_props)
  end

  defp resolve_child_properties(other, _container_props), do: other

  defp resolve_cell_properties(%AshReports.Layout.IR.Cell{} = cell, parent_props) do
    cell_props = cell.properties || %{}
    resolved_props = PropertyResolver.resolve(cell_props, parent_props)
    %{cell | properties: resolved_props}
  end
end
