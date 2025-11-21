defmodule AshReports.Layout.Transformer.Row do
  @moduledoc """
  Transforms Row DSL entities to RowIR.

  Handles transformation of row properties and cells to the normalized IR format.
  """

  alias AshReports.Layout.{Row, IR}
  alias AshReports.Layout.Transformer.Cell

  @doc """
  Transforms a Row DSL entity to a RowIR.

  ## Parameters

  - `row` - The Row DSL entity
  - `index` - The row index (0-based)
  """
  @spec transform(Row.t() | map(), non_neg_integer()) :: {:ok, IR.Row.t()} | {:error, term()}
  def transform(%Row{} = row, index) do
    do_transform(row, index)
  end

  def transform(%{} = row, index) do
    do_transform(row, index)
  end

  defp do_transform(row, index) do
    with {:ok, cells} <- transform_cells(row),
         {:ok, properties} <- build_properties(row) do
      row_ir = IR.Row.new(
        index: index,
        properties: properties,
        cells: cells
      )

      {:ok, row_ir}
    end
  end

  defp transform_cells(row) do
    elements = Map.get(row, :elements, [])

    cells =
      Enum.map(elements, fn element ->
        case Cell.transform(element) do
          {:ok, cell_ir} -> cell_ir
          {:error, _} = err -> throw(err)
        end
      end)

    {:ok, cells}
  catch
    {:error, _} = err -> err
  end

  defp build_properties(row) do
    properties = %{
      height: Map.get(row, :height),
      fill: Map.get(row, :fill),
      stroke: Map.get(row, :stroke),
      align: Map.get(row, :align),
      inset: Map.get(row, :inset)
    }

    # Remove nil values
    properties =
      properties
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, properties}
  end
end
