defmodule AshReports.Layout.Transformer do
  @moduledoc """
  Main transformer pipeline for converting DSL entities to IR.

  This module provides the entry point for transforming layout DSL entities
  (Grid, Table, Stack) into the normalized Intermediate Representation (IR).

  ## Usage

      # Transform a grid
      {:ok, ir} = AshReports.Layout.Transformer.transform(grid_dsl)

      # Transform a table
      {:ok, ir} = AshReports.Layout.Transformer.transform(table_dsl)

      # Transform a stack
      {:ok, ir} = AshReports.Layout.Transformer.transform(stack_dsl)
  """


  @doc """
  Transforms a DSL layout entity to its IR representation.

  Dispatches to the appropriate transformer based on the entity type.

  ## Examples

      iex> grid = %AshReports.Layout.Grid{name: :test, columns: 3}
      iex> {:ok, ir} = AshReports.Layout.Transformer.transform(grid)
      iex> ir.type
      :grid
  """
  @spec transform(struct()) :: {:ok, AshReports.Layout.IR.t()} | {:error, term()}
  def transform(%AshReports.Layout.Grid{} = grid) do
    AshReports.Layout.Transformer.Grid.transform(grid)
  end

  def transform(%AshReports.Layout.Table{} = table) do
    AshReports.Layout.Transformer.Table.transform(table)
  end

  def transform(%AshReports.Layout.Stack{} = stack) do
    AshReports.Layout.Transformer.Stack.transform(stack)
  end

  def transform(%{type: :grid} = map) do
    # Convert map to Grid struct
    grid = struct(AshReports.Layout.Grid, map)
    AshReports.Layout.Transformer.Grid.transform(grid)
  end

  def transform(%{type: :table} = map) do
    # Convert map to Table struct
    table = struct(AshReports.Layout.Table, map)
    AshReports.Layout.Transformer.Table.transform(table)
  end

  def transform(%{type: :stack} = map) do
    # Convert map to Stack struct
    stack = struct(AshReports.Layout.Stack, map)
    AshReports.Layout.Transformer.Stack.transform(stack)
  end

  def transform(other) do
    {:error, {:unsupported_layout_type, other}}
  end
end
