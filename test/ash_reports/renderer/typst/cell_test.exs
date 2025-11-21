defmodule AshReports.Renderer.Typst.CellTest do
  @moduledoc """
  Tests for the Typst Cell renderer.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.Content
  alias AshReports.Renderer.Typst.Cell

  describe "render/2" do
    test "renders simple cell with bracket syntax" do
      cell = IR.Cell.new(content: [Content.label("Hello")])
      result = Cell.render(cell)

      # Default indent is 0
      assert result == "[Hello]"
    end

    test "renders cell with colspan" do
      cell = IR.Cell.new(
        span: {2, 1},
        content: [Content.label("Wide")]
      )
      result = Cell.render(cell)

      assert result =~ "grid.cell(colspan: 2)"
      assert result =~ "[Wide]"
    end

    test "renders cell with rowspan" do
      cell = IR.Cell.new(
        span: {1, 3},
        content: [Content.label("Tall")]
      )
      result = Cell.render(cell)

      assert result =~ "grid.cell(rowspan: 3)"
      assert result =~ "[Tall]"
    end

    test "renders cell with colspan and rowspan" do
      cell = IR.Cell.new(
        span: {2, 3},
        content: [Content.label("Big")]
      )
      result = Cell.render(cell)

      assert result =~ "colspan: 2"
      assert result =~ "rowspan: 3"
    end

    test "renders cell with align override" do
      cell = IR.Cell.new(
        properties: %{align: :center},
        content: [Content.label("Centered")]
      )
      result = Cell.render(cell)

      assert result =~ "grid.cell(align: center)"
    end

    test "renders cell with combined alignment" do
      cell = IR.Cell.new(
        properties: %{align: {:left, :top}},
        content: [Content.label("Top-left")]
      )
      result = Cell.render(cell)

      assert result =~ "align: left + top"
    end

    test "renders cell with fill override" do
      cell = IR.Cell.new(
        properties: %{fill: "red"},
        content: [Content.label("Red")]
      )
      result = Cell.render(cell)

      assert result =~ "fill: red"
    end

    test "renders cell with hex fill" do
      cell = IR.Cell.new(
        properties: %{fill: "#ff0000"},
        content: [Content.label("Hex")]
      )
      result = Cell.render(cell)

      assert result =~ "fill: rgb(\"#ff0000\")"
    end

    test "renders cell with inset override" do
      cell = IR.Cell.new(
        properties: %{inset: "10pt"},
        content: [Content.label("Padded")]
      )
      result = Cell.render(cell)

      assert result =~ "inset: 10pt"
    end

    test "renders cell with breakable false" do
      cell = IR.Cell.new(
        properties: %{breakable: false},
        content: [Content.label("No break")]
      )
      result = Cell.render(cell)

      assert result =~ "breakable: false"
    end

    test "renders cell with multiple overrides" do
      cell = IR.Cell.new(
        span: {2, 1},
        properties: %{align: :center, fill: "gray", inset: "5pt"},
        content: [Content.label("Complex")]
      )
      result = Cell.render(cell)

      assert result =~ "colspan: 2"
      assert result =~ "align: center"
      assert result =~ "fill: gray"
      assert result =~ "inset: 5pt"
    end

    test "renders table cell with table context" do
      cell = IR.Cell.new(
        span: {2, 1},
        content: [Content.label("Table cell")]
      )
      result = Cell.render(cell, context: :table)

      assert result =~ "table.cell(colspan: 2)"
    end

    test "renders cell with multiple content items" do
      cell = IR.Cell.new(content: [
        Content.label("Name:"),
        Content.field(:name)
      ])
      result = Cell.render(cell, data: %{name: "Alice"})

      assert result =~ "Name:"
      assert result =~ "Alice"
    end

    test "respects indent option" do
      cell = IR.Cell.new(content: [Content.label("Indented")])
      result = Cell.render(cell, indent: 2)

      assert String.starts_with?(result, "    ")
    end
  end

  describe "build_cell_parameters/2" do
    test "returns empty string for simple cell" do
      cell = IR.Cell.new(content: [Content.label("Simple")])
      result = Cell.build_cell_parameters(cell, :grid)

      assert result == ""
    end

    test "builds colspan parameter" do
      cell = IR.Cell.new(span: {3, 1})
      result = Cell.build_cell_parameters(cell, :grid)

      assert result == "colspan: 3"
    end

    test "builds multiple parameters" do
      cell = IR.Cell.new(
        span: {2, 3},
        properties: %{align: :center}
      )
      result = Cell.build_cell_parameters(cell, :grid)

      assert result =~ "colspan: 2"
      assert result =~ "rowspan: 3"
      assert result =~ "align: center"
    end
  end

  describe "needs_cell_syntax?/1" do
    test "returns false for simple cell" do
      cell = IR.Cell.new(content: [Content.label("Simple")])
      refute Cell.needs_cell_syntax?(cell)
    end

    test "returns true for cell with colspan" do
      cell = IR.Cell.new(span: {2, 1})
      assert Cell.needs_cell_syntax?(cell)
    end

    test "returns true for cell with rowspan" do
      cell = IR.Cell.new(span: {1, 2})
      assert Cell.needs_cell_syntax?(cell)
    end

    test "returns true for cell with align" do
      cell = IR.Cell.new(properties: %{align: :center})
      assert Cell.needs_cell_syntax?(cell)
    end

    test "returns true for cell with fill" do
      cell = IR.Cell.new(properties: %{fill: "red"})
      assert Cell.needs_cell_syntax?(cell)
    end

    test "returns true for cell with inset" do
      cell = IR.Cell.new(properties: %{inset: "5pt"})
      assert Cell.needs_cell_syntax?(cell)
    end

    test "returns true for cell with breakable false" do
      cell = IR.Cell.new(properties: %{breakable: false})
      assert Cell.needs_cell_syntax?(cell)
    end
  end
end
