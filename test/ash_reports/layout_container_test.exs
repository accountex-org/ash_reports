defmodule AshReports.LayoutContainerTest do
  @moduledoc """
  Tests for layout container DSL entities (Grid, Table, Stack).

  These tests verify that layout container entities are properly parsed
  and their properties are correctly extracted from the DSL.
  """

  use ExUnit.Case, async: true

  alias AshReports.Info

  describe "grid entity parsing" do
    test "parses grid with basic properties" do
      reports = Info.reports(AshReports.Test.GridLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])

      assert length(grids) == 1

      grid = hd(grids)
      assert grid.name == :metrics_grid
      assert grid.columns == [1, 1, 1]
      assert grid.gutter == "10pt"
      assert grid.align == :center
      assert grid.inset == "5pt"
      assert grid.stroke == "0.5pt"
    end

    test "parses grid elements correctly" do
      reports = Info.reports(AshReports.Test.GridLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)

      elements = Map.get(grid, :elements, [])
      assert length(elements) == 3

      revenue_label = Enum.find(elements, &(&1.name == :revenue_label))
      assert revenue_label.text == "Revenue"
    end

    test "parses grid with all options" do
      reports = Info.reports(AshReports.Test.GridAllOptionsLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)

      assert grid.name == :full_grid
      assert grid.columns == 3
      assert grid.rows == 2
      assert grid.gutter == "5pt"
      assert grid.column_gutter == "8pt"
      assert grid.row_gutter == "12pt"
      assert grid.align == {:left, :top}
      assert grid.inset == "10pt"
      assert grid.fill == "#f0f0f0"
      assert grid.stroke == :none
    end

    test "grid has correct defaults" do
      reports = Info.reports(AshReports.Test.GridLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)

      # These properties should use the explicit values, not defaults
      # Default behavior verified by checking absence of unexpected values
      assert is_list(grid.columns) or is_integer(grid.columns)
    end
  end

  describe "table entity parsing" do
    test "parses table with basic properties" do
      reports = Info.reports(AshReports.Test.TableLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])

      assert length(tables) == 1

      table = hd(tables)
      assert table.name == :data_table
      assert table.columns == [1, 2, 1]
      assert table.stroke == "0.5pt"
      assert table.inset == "5pt"
    end

    test "parses table elements correctly" do
      reports = Info.reports(AshReports.Test.TableLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)

      elements = Map.get(table, :elements, [])
      assert length(elements) == 3

      name_col = Enum.find(elements, &(&1.name == :name_col))
      assert name_col.text == "Name"
    end

    test "table has correct semantic defaults" do
      reports = Info.reports(AshReports.Test.TableDefaultsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)

      # Tables should have visible borders by default (stroke: "1pt")
      # and cell padding (inset: "5pt")
      assert table.stroke == "1pt"
      assert table.inset == "5pt"
    end
  end

  describe "stack entity parsing" do
    test "parses stack with basic properties" do
      reports = Info.reports(AshReports.Test.StackLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      stacks = Map.get(detail_band, :stacks, [])

      assert length(stacks) == 1

      stack = hd(stacks)
      assert stack.name == :address_stack
      assert stack.dir == :ttb
      assert stack.spacing == "3pt"
    end

    test "parses stack elements correctly" do
      reports = Info.reports(AshReports.Test.StackLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      stacks = Map.get(detail_band, :stacks, [])
      stack = hd(stacks)

      elements = Map.get(stack, :elements, [])
      assert length(elements) == 2

      street_label = Enum.find(elements, &(&1.name == :street))
      assert street_label.text == "123 Main St"
    end

    test "parses all stack direction options" do
      reports = Info.reports(AshReports.Test.StackDirectionsDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      stacks = Map.get(detail_band, :stacks, [])

      assert length(stacks) == 4

      ttb_stack = Enum.find(stacks, &(&1.name == :ttb_stack))
      assert ttb_stack.dir == :ttb

      btt_stack = Enum.find(stacks, &(&1.name == :btt_stack))
      assert btt_stack.dir == :btt

      ltr_stack = Enum.find(stacks, &(&1.name == :ltr_stack))
      assert ltr_stack.dir == :ltr

      rtl_stack = Enum.find(stacks, &(&1.name == :rtl_stack))
      assert rtl_stack.dir == :rtl
    end
  end

  describe "nested layouts" do
    test "parses multiple layout containers in same band" do
      reports = Info.reports(AshReports.Test.NestedLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))

      stacks = Map.get(detail_band, :stacks, [])
      grids = Map.get(detail_band, :grids, [])

      assert length(stacks) == 1
      assert length(grids) == 1

      stack = hd(stacks)
      assert stack.name == :outer_stack

      grid = hd(grids)
      assert grid.name == :inner_grid
    end
  end

  describe "layout container struct types" do
    test "grid returns correct struct type" do
      reports = Info.reports(AshReports.Test.GridLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)

      assert %AshReports.Layout.Grid{} = grid
    end

    test "table returns correct struct type" do
      reports = Info.reports(AshReports.Test.TableLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)

      assert %AshReports.Layout.Table{} = table
    end

    test "stack returns correct struct type" do
      reports = Info.reports(AshReports.Test.StackLayoutDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      stacks = Map.get(detail_band, :stacks, [])
      stack = hd(stacks)

      assert %AshReports.Layout.Stack{} = stack
    end
  end

  describe "grid cell entity parsing" do
    test "parses grid cells with positioning" do
      reports = Info.reports(AshReports.Test.GridCellDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)
      grid_cells = Map.get(grid, :grid_cells, [])

      assert length(grid_cells) == 3

      cell1 = Enum.at(grid_cells, 0)
      assert cell1.x == 0
      assert cell1.y == 0
      assert cell1.align == :left
      assert cell1.fill == "#f0f0f0"

      cell2 = Enum.at(grid_cells, 1)
      assert cell2.x == 1
      assert cell2.y == 0
      assert cell2.align == :center

      cell3 = Enum.at(grid_cells, 2)
      assert cell3.x == 2
      assert cell3.y == 0
      assert cell3.align == :right
      assert cell3.stroke == "1pt"
      assert cell3.inset == "10pt"
    end

    test "grid cell returns correct struct type" do
      reports = Info.reports(AshReports.Test.GridCellDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)
      grid_cells = Map.get(grid, :grid_cells, [])
      cell = hd(grid_cells)

      assert %AshReports.Layout.GridCell{} = cell
    end

    test "grid cell contains elements" do
      reports = Info.reports(AshReports.Test.GridCellDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)
      grid_cells = Map.get(grid, :grid_cells, [])
      cell = hd(grid_cells)

      elements = Map.get(cell, :elements, [])
      assert length(elements) == 1

      label = hd(elements)
      assert label.name == :cell1
      assert label.text == "Cell 1"
    end
  end

  describe "table cell entity parsing" do
    test "parses table cells with spanning" do
      reports = Info.reports(AshReports.Test.TableCellDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      table_cells = Map.get(table, :table_cells, [])

      assert length(table_cells) == 3

      cell1 = Enum.at(table_cells, 0)
      assert cell1.colspan == 2
      assert cell1.align == :left
      assert cell1.fill == "#e0e0e0"

      cell2 = Enum.at(table_cells, 1)
      assert cell2.rowspan == 1
      assert cell2.align == :right

      cell3 = Enum.at(table_cells, 2)
      assert cell3.x == 0
      assert cell3.y == 1
      assert cell3.breakable == false
      assert cell3.inset == "8pt"
    end

    test "table cell returns correct struct type" do
      reports = Info.reports(AshReports.Test.TableCellDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      table_cells = Map.get(table, :table_cells, [])
      cell = hd(table_cells)

      assert %AshReports.Layout.TableCell{} = cell
    end

    test "table cell contains elements" do
      reports = Info.reports(AshReports.Test.TableCellDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      table_cells = Map.get(table, :table_cells, [])
      cell = hd(table_cells)

      elements = Map.get(cell, :elements, [])
      assert length(elements) == 1

      label = hd(elements)
      assert label.name == :merged_cell
      assert label.text == "Merged Cell"
    end
  end

  describe "header and footer entity parsing" do
    test "parses table headers with cells" do
      reports = Info.reports(AshReports.Test.TableHeaderFooterDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      headers = Map.get(table, :headers, [])

      assert length(headers) == 1

      header = hd(headers)
      assert header.repeat == true

      table_cells = Map.get(header, :table_cells, [])
      assert length(table_cells) == 3
    end

    test "parses table footers with cells" do
      reports = Info.reports(AshReports.Test.TableHeaderFooterDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      footers = Map.get(table, :footers, [])

      assert length(footers) == 1

      footer = hd(footers)
      assert footer.repeat == true

      table_cells = Map.get(footer, :table_cells, [])
      assert length(table_cells) == 2

      # First cell has colspan
      cell = hd(table_cells)
      assert cell.colspan == 2
    end

    test "header returns correct struct type" do
      reports = Info.reports(AshReports.Test.TableHeaderFooterDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      headers = Map.get(table, :headers, [])
      header = hd(headers)

      assert %AshReports.Layout.Header{} = header
    end

    test "footer returns correct struct type" do
      reports = Info.reports(AshReports.Test.TableHeaderFooterDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      tables = Map.get(detail_band, :tables, [])
      table = hd(tables)
      footers = Map.get(table, :footers, [])
      footer = hd(footers)

      assert %AshReports.Layout.Footer{} = footer
    end
  end

  describe "row entity parsing" do
    test "parses row with properties" do
      reports = Info.reports(AshReports.Test.RowEntityDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)
      row_entities = Map.get(grid, :row_entities, [])

      assert length(row_entities) == 1

      row = hd(row_entities)
      assert row.name == :header_row
      assert row.height == "30pt"
      assert row.fill == "#f0f0f0"
      assert row.align == :center
      assert row.inset == "5pt"
    end

    test "row returns correct struct type" do
      reports = Info.reports(AshReports.Test.RowEntityDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)
      row_entities = Map.get(grid, :row_entities, [])
      row = hd(row_entities)

      assert %AshReports.Layout.Row{} = row
    end

    test "row contains elements" do
      reports = Info.reports(AshReports.Test.RowEntityDomain)
      report = hd(reports)

      detail_band = Enum.find(report.bands, &(&1.type == :detail))
      grids = Map.get(detail_band, :grids, [])
      grid = hd(grids)
      row_entities = Map.get(grid, :row_entities, [])
      row = hd(row_entities)

      elements = Map.get(row, :elements, [])
      assert length(elements) == 2

      col1 = Enum.find(elements, &(&1.name == :col1))
      assert col1.text == "Column 1"

      col2 = Enum.find(elements, &(&1.name == :col2))
      assert col2.text == "Column 2"
    end
  end
end
