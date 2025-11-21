defmodule AshReports.Renderer.Typst.TableTest do
  @moduledoc """
  Tests for the Typst Table renderer.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Typst.Table

  describe "render/2" do
    test "renders empty table with default stroke" do
      ir = IR.table(properties: %{columns: ["1fr", "1fr"]})
      result = Table.render(ir)

      assert result =~ "#table("
      assert result =~ "columns: (1fr, 1fr)"
      assert result =~ "stroke: 1pt"
    end

    test "renders table with all column formats" do
      ir = IR.table(properties: %{columns: ["100pt", "1fr", "auto", "2cm"]})
      result = Table.render(ir)

      assert result =~ "columns: (100pt, 1fr, auto, 2cm)"
    end

    test "renders table with custom stroke" do
      ir = IR.table(properties: %{columns: ["1fr"], stroke: "2pt"})
      result = Table.render(ir)

      assert result =~ "stroke: 2pt"
    end

    test "renders table with stroke none" do
      ir = IR.table(properties: %{columns: ["1fr"], stroke: :none})
      result = Table.render(ir)

      assert result =~ "stroke: none"
    end

    test "renders table with rows" do
      ir = IR.table(properties: %{columns: ["1fr"], rows: ["auto", "100pt"]})
      result = Table.render(ir)

      assert result =~ "columns: (1fr)"
      assert result =~ "rows: (auto, 100pt)"
    end

    test "renders table with gutter" do
      ir = IR.table(properties: %{columns: ["1fr"], gutter: "10pt"})
      result = Table.render(ir)

      assert result =~ "gutter: 10pt"
    end

    test "renders table with align" do
      ir = IR.table(properties: %{columns: ["1fr"], align: :center})
      result = Table.render(ir)

      assert result =~ "align: center"
    end

    test "renders table with inset" do
      ir = IR.table(properties: %{columns: ["1fr"], inset: "5pt"})
      result = Table.render(ir)

      assert result =~ "inset: 5pt"
    end

    test "renders table with fill color" do
      ir = IR.table(properties: %{columns: ["1fr"], fill: "lightgray"})
      result = Table.render(ir)

      assert result =~ "fill: lightgray"
    end

    test "renders table with cells" do
      cell1 = IR.Cell.new(content: [%{text: "A"}])
      cell2 = IR.Cell.new(content: [%{text: "B"}])
      ir = IR.table(properties: %{columns: ["1fr", "1fr"]}, children: [cell1, cell2])
      result = Table.render(ir)

      assert result =~ "[A]"
      assert result =~ "[B]"
    end

    test "renders table with rows containing cells" do
      cell1 = IR.Cell.new(content: [%{text: "A"}])
      cell2 = IR.Cell.new(content: [%{text: "B"}])
      row = IR.Row.new(cells: [cell1, cell2])
      ir = IR.table(properties: %{columns: ["1fr", "1fr"]}, children: [row])
      result = Table.render(ir)

      assert result =~ "[A]"
      assert result =~ "[B]"
    end
  end

  describe "render_headers/2" do
    test "renders empty headers" do
      result = Table.render_headers([], 1)
      assert result == ""
    end

    test "renders single header without repeat" do
      cell = IR.Cell.new(content: [%{text: "Header"}])
      row = IR.Row.new(cells: [cell])
      header = IR.Header.new(repeat: false, rows: [row])

      result = Table.render_headers([header], 1)

      assert result =~ "table.header("
      refute result =~ "repeat: true"
      assert result =~ "[Header]"
    end

    test "renders single header with repeat" do
      cell = IR.Cell.new(content: [%{text: "Header"}])
      row = IR.Row.new(cells: [cell])
      header = IR.Header.new(repeat: true, rows: [row])

      result = Table.render_headers([header], 1)

      assert result =~ "table.header(repeat: true,"
      assert result =~ "[Header]"
    end

    test "renders header with multiple cells" do
      cell1 = IR.Cell.new(content: [%{text: "Col1"}])
      cell2 = IR.Cell.new(content: [%{text: "Col2"}])
      row = IR.Row.new(cells: [cell1, cell2])
      header = IR.Header.new(repeat: false, rows: [row])

      result = Table.render_headers([header], 1)

      assert result =~ "[Col1]"
      assert result =~ "[Col2]"
    end

    test "renders header with multiple rows" do
      cell1 = IR.Cell.new(content: [%{text: "Row1"}])
      cell2 = IR.Cell.new(content: [%{text: "Row2"}])
      row1 = IR.Row.new(cells: [cell1])
      row2 = IR.Row.new(cells: [cell2])
      header = IR.Header.new(repeat: false, rows: [row1, row2])

      result = Table.render_headers([header], 1)

      assert result =~ "[Row1]"
      assert result =~ "[Row2]"
    end
  end

  describe "render_footers/2" do
    test "renders empty footers" do
      result = Table.render_footers([], 1)
      assert result == ""
    end

    test "renders single footer without repeat" do
      cell = IR.Cell.new(content: [%{text: "Footer"}])
      row = IR.Row.new(cells: [cell])
      footer = IR.Footer.new(repeat: false, rows: [row])

      result = Table.render_footers([footer], 1)

      assert result =~ "table.footer("
      refute result =~ "repeat: true"
      assert result =~ "[Footer]"
    end

    test "renders single footer with repeat" do
      cell = IR.Cell.new(content: [%{text: "Footer"}])
      row = IR.Row.new(cells: [cell])
      footer = IR.Footer.new(repeat: true, rows: [row])

      result = Table.render_footers([footer], 1)

      assert result =~ "table.footer(repeat: true,"
      assert result =~ "[Footer]"
    end

    test "renders footer with multiple cells" do
      cell1 = IR.Cell.new(content: [%{text: "Total"}])
      cell2 = IR.Cell.new(content: [%{text: "100"}])
      row = IR.Row.new(cells: [cell1, cell2])
      footer = IR.Footer.new(repeat: false, rows: [row])

      result = Table.render_footers([footer], 1)

      assert result =~ "[Total]"
      assert result =~ "[100]"
    end
  end

  describe "apply_table_defaults/1" do
    test "adds default stroke when not specified" do
      props = %{columns: ["1fr"]}
      result = Table.apply_table_defaults(props)

      assert result[:stroke] == "1pt"
    end

    test "preserves existing stroke" do
      props = %{columns: ["1fr"], stroke: "2pt"}
      result = Table.apply_table_defaults(props)

      assert result[:stroke] == "2pt"
    end

    test "preserves stroke none" do
      props = %{columns: ["1fr"], stroke: :none}
      result = Table.apply_table_defaults(props)

      assert result[:stroke] == :none
    end
  end

  describe "integration with headers and footers" do
    test "renders table with header and cells" do
      header_cell = IR.Cell.new(content: [%{text: "Name"}])
      header_row = IR.Row.new(cells: [header_cell])
      header = IR.Header.new(repeat: true, rows: [header_row])

      data_cell = IR.Cell.new(content: [%{text: "Alice"}])

      ir = IR.table(
        properties: %{columns: ["1fr"]},
        headers: [header],
        children: [data_cell]
      )
      result = Table.render(ir)

      assert result =~ "#table("
      assert result =~ "table.header(repeat: true,"
      assert result =~ "[Name]"
      assert result =~ "[Alice]"
    end

    test "renders table with header, cells, and footer" do
      header_cell = IR.Cell.new(content: [%{text: "Amount"}])
      header_row = IR.Row.new(cells: [header_cell])
      header = IR.Header.new(repeat: true, rows: [header_row])

      data_cell = IR.Cell.new(content: [%{text: "50"}])

      footer_cell = IR.Cell.new(content: [%{text: "Total: 50"}])
      footer_row = IR.Row.new(cells: [footer_cell])
      footer = IR.Footer.new(repeat: false, rows: [footer_row])

      ir = IR.table(
        properties: %{columns: ["1fr"]},
        headers: [header],
        children: [data_cell],
        footers: [footer]
      )
      result = Table.render(ir)

      assert result =~ "table.header(repeat: true,"
      assert result =~ "[Amount]"
      assert result =~ "[50]"
      assert result =~ "table.footer("
      assert result =~ "[Total: 50]"
    end
  end
end
