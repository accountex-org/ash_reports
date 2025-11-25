defmodule AshReports.Migration.ProductInventoryMigrationTest do
  @moduledoc """
  Tests for the migrated product_inventory report using new layout primitives.

  Verifies that the migration to grid, table, and stack layouts works correctly
  and produces proper HTML output.
  """
  use ExUnit.Case, async: true

  alias AshReports.Info
  alias AshReports.Layout.Transformer
  alias AshReports.Layout.Transformer.Grid, as: GridTransformer
  alias AshReports.Layout.Transformer.Table, as: TableTransformer

  @domain AshReportsDemo.Domain

  defp get_report do
    Info.report(@domain, :product_inventory)
  end

  describe "product_inventory report structure" do
    test "report compiles and is accessible" do
      report = get_report()

      assert report.name == :product_inventory
      assert report.title == "Product Inventory Report"
      assert report.driving_resource == AshReportsDemo.Product
    end

    test "report has correct bands" do
      report = get_report()
      band_names = Enum.map(report.bands, & &1.name)

      assert :title in band_names
      assert :column_headers in band_names
      assert :product_detail in band_names
      assert :inventory_summary in band_names
    end

    test "title band has grid layout" do
      report = get_report()
      title_band = Enum.find(report.bands, &(&1.name == :title))

      assert length(title_band.grids) == 1

      grid = hd(title_band.grids)
      assert grid.name == :title_grid
      assert grid.columns == 1
      assert grid.align == :center
    end

    test "column_headers band has table layout" do
      report = get_report()
      headers_band = Enum.find(report.bands, &(&1.name == :column_headers))

      assert length(headers_band.tables) == 1

      table = hd(headers_band.tables)
      assert table.name == :header_table
      assert table.columns == [2, 1, 1, 1]
      assert table.fill == "#f0f0f0"
    end

    test "detail band has table layout" do
      report = get_report()
      detail_band = Enum.find(report.bands, &(&1.name == :product_detail))

      assert length(detail_band.tables) == 1

      table = hd(detail_band.tables)
      assert table.name == :detail_table
      assert table.columns == [2, 1, 1, 1]
    end

    test "summary band has grid with labels" do
      report = get_report()
      summary_band = Enum.find(report.bands, &(&1.name == :inventory_summary))

      assert length(summary_band.grids) == 1

      grid = hd(summary_band.grids)
      assert grid.name == :summary_grid
      assert grid.columns == 2
      assert grid.rows == 2
      assert grid.fill == "#e8e8e8"
      assert length(grid.elements) == 4
    end

    test "report has correct variables" do
      report = get_report()
      variable_names = Enum.map(report.variables, & &1.name)

      assert :total_products in variable_names
      assert :total_inventory_value in variable_names
    end

    test "report has correct parameters" do
      report = get_report()
      param_names = Enum.map(report.parameters, & &1.name)

      assert :category_name in param_names
      assert :include_inactive in param_names
    end
  end

  describe "layout transformation" do
    test "transforms title band grid to IR" do
      report = get_report()
      title_band = Enum.find(report.bands, &(&1.name == :title))
      grid = hd(title_band.grids)

      {:ok, ir} = GridTransformer.transform(grid)

      assert ir.type == :grid
      assert ir.properties.align == :center
    end

    test "transforms header table to IR" do
      report = get_report()
      headers_band = Enum.find(report.bands, &(&1.name == :column_headers))
      table = hd(headers_band.tables)

      {:ok, ir} = TableTransformer.transform(table)

      assert ir.type == :table
      # Columns are converted to strings during transformation
      assert length(ir.properties.columns) == 4
      assert ir.properties.fill == "#f0f0f0"
    end

    test "transforms summary grid to IR" do
      report = get_report()
      summary_band = Enum.find(report.bands, &(&1.name == :inventory_summary))
      grid = hd(summary_band.grids)

      {:ok, ir} = GridTransformer.transform(grid)

      assert ir.type == :grid
      # Grid should have children from labels
      assert length(ir.children) == 4
    end
  end

  describe "HTML rendering" do
    test "renders title band grid to HTML" do
      report = get_report()
      title_band = Enum.find(report.bands, &(&1.name == :title))
      grid = hd(title_band.grids)

      {:ok, ir} = GridTransformer.transform(grid)
      html = AshReports.Renderer.Html.render(ir)

      assert html =~ "ash-grid"
      assert html =~ "display: grid"
      assert html =~ "Product Inventory Report"
    end

    test "renders header table to HTML" do
      report = get_report()
      headers_band = Enum.find(report.bands, &(&1.name == :column_headers))
      table = hd(headers_band.tables)

      {:ok, ir} = TableTransformer.transform(table)
      html = AshReports.Renderer.Html.render(ir)

      assert html =~ "ash-table"
      assert html =~ "Product Name"
      assert html =~ "SKU"
      assert html =~ "Price"
      assert html =~ "Margin"
    end

    test "renders detail table to HTML" do
      report = get_report()
      detail_band = Enum.find(report.bands, &(&1.name == :product_detail))
      table = hd(detail_band.tables)

      {:ok, ir} = TableTransformer.transform(table)
      html = AshReports.Renderer.Html.render(ir)

      assert html =~ "ash-table"
      # Detail table should have field placeholders
      assert html =~ "ash-field" or html =~ "<td>"
    end

    test "renders summary grid to HTML" do
      report = get_report()
      summary_band = Enum.find(report.bands, &(&1.name == :inventory_summary))
      grid = hd(summary_band.grids)

      {:ok, ir} = GridTransformer.transform(grid)
      html = AshReports.Renderer.Html.render(ir)

      assert html =~ "ash-grid"
      assert html =~ "Total Products"
      assert html =~ "Inventory Value"
    end
  end
end
