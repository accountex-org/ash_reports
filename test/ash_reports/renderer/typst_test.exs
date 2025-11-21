defmodule AshReports.Renderer.TypstTest do
  @moduledoc """
  Tests for the main Typst renderer module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.{Cell, Content, Line}
  alias AshReports.Renderer.Typst

  describe "render/2" do
    test "renders grid IR" do
      ir = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      result = Typst.render(ir)

      assert result =~ "#grid("
      assert result =~ "columns: (1fr, 1fr)"
    end

    test "renders table IR" do
      ir = IR.table(properties: %{columns: ["auto", "1fr"]})
      result = Typst.render(ir)

      assert result =~ "#table("
      assert result =~ "columns: (auto, 1fr)"
    end

    test "renders stack IR" do
      ir = IR.stack(properties: %{dir: :ttb, spacing: "10pt"})
      result = Typst.render(ir)

      assert result =~ "#stack("
      assert result =~ "dir: ttb"
      assert result =~ "spacing: 10pt"
    end

    test "renders grid with children" do
      cell1 = Cell.new(content: [Content.label("A")])
      cell2 = Cell.new(content: [Content.label("B")])
      ir = IR.grid(
        properties: %{columns: ["1fr", "1fr"]},
        children: [cell1, cell2]
      )
      result = Typst.render(ir)

      assert result =~ "[A]"
      assert result =~ "[B]"
    end

    test "renders grid with field content" do
      cell = Cell.new(content: [Content.label("Name:")])
      ir = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [cell]
      )
      result = Typst.render(ir)

      assert result =~ "[Name:]"
    end

    test "renders grid with lines" do
      ir = IR.grid(
        properties: %{columns: ["1fr", "1fr"]},
        lines: [Line.hline(1, stroke: "2pt")]
      )
      result = Typst.render(ir)

      assert result =~ "grid.hline(y: 1, stroke: 2pt)"
    end

    test "renders table with lines" do
      ir = IR.table(
        properties: %{columns: ["1fr"]},
        lines: [Line.vline(0)]
      )
      result = Typst.render(ir)

      assert result =~ "table.vline(x: 0)"
    end
  end

  describe "render_report/3" do
    test "renders single layout" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Typst.render_report([ir])

      assert result =~ "#grid("
    end

    test "renders multiple layouts" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      table = IR.table(properties: %{columns: ["auto"]})
      result = Typst.render_report([grid, table])

      assert result =~ "#grid("
      assert result =~ "#table("
    end

    test "separates layouts with blank lines" do
      grid1 = IR.grid(properties: %{columns: ["1fr"]})
      grid2 = IR.grid(properties: %{columns: ["2fr"]})
      result = Typst.render_report([grid1, grid2])

      # Should have double newline between layouts
      assert result =~ ")\n\n#grid("
    end

    test "renders multiple layouts with labels" do
      cell = Cell.new(content: [Content.label("Value: 42")])
      grid = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [cell]
      )
      result = Typst.render_report([grid])

      assert result =~ "Value: 42"
    end

    test "adds page size preamble" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Typst.render_report([ir], %{}, page_size: "letter")

      assert result =~ "#set page(paper: \"letter\")"
    end

    test "adds margin preamble" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Typst.render_report([ir], %{}, margin: "1in")

      assert result =~ "#set page(margin: 1in)"
    end

    test "adds font preamble" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Typst.render_report([ir], %{}, font: "Arial")

      assert result =~ "#set text(font: \"Arial\")"
    end

    test "adds font size preamble" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Typst.render_report([ir], %{}, font_size: "12pt")

      assert result =~ "#set text(size: 12pt)"
    end

    test "combines multiple preamble settings" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Typst.render_report([ir], %{},
        page_size: "a4",
        font: "Times New Roman",
        font_size: "11pt"
      )

      assert result =~ "#set page(paper: \"a4\")"
      assert result =~ "#set text(font: \"Times New Roman\")"
      assert result =~ "#set text(size: 11pt)"
    end

    test "returns empty string for empty layouts" do
      result = Typst.render_report([])
      assert result == ""
    end
  end

  describe "render_layouts/2" do
    test "renders multiple layouts" do
      layouts = [
        IR.grid(properties: %{columns: ["1fr"]}),
        IR.stack(properties: %{dir: :ttb})
      ]
      result = Typst.render_layouts(layouts)

      assert result =~ "#grid("
      assert result =~ "#stack("
    end

    test "joins layouts with double newline" do
      layouts = [
        IR.grid(properties: %{columns: ["1fr"]}),
        IR.grid(properties: %{columns: ["2fr"]})
      ]
      result = Typst.render_layouts(layouts)

      assert String.contains?(result, "\n\n")
    end

    test "returns empty string for empty list" do
      result = Typst.render_layouts([])
      assert result == ""
    end
  end

  describe "supported_type?/1" do
    test "returns true for grid" do
      assert Typst.supported_type?(:grid)
    end

    test "returns true for table" do
      assert Typst.supported_type?(:table)
    end

    test "returns true for stack" do
      assert Typst.supported_type?(:stack)
    end

    test "returns false for unknown type" do
      refute Typst.supported_type?(:unknown)
    end
  end

  describe "integration scenarios" do
    test "renders complete report with header" do
      # Header row
      header_cells = [
        Cell.new(content: [Content.label("Name")]),
        Cell.new(content: [Content.label("Amount")])
      ]

      # Data row with static labels
      data_cells = [
        Cell.new(content: [Content.label("Widget")]),
        Cell.new(content: [Content.label("$29.99")])
      ]

      table = IR.table(
        properties: %{columns: ["1fr", "auto"]},
        children: header_cells ++ data_cells
      )

      result = Typst.render_report(
        [table],
        %{},
        page_size: "a4"
      )

      assert result =~ "#set page(paper: \"a4\")"
      assert result =~ "#table("
      assert result =~ "[Name]"
      assert result =~ "[Amount]"
      assert result =~ "Widget"
      assert result =~ "\\$29.99"
    end

    test "renders multi-section report" do
      # Title section
      title = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [Cell.new(content: [Content.label("Sales Report")])]
      )

      # Data table
      table = IR.table(
        properties: %{columns: ["1fr", "auto"]},
        children: [
          Cell.new(content: [Content.label("Product")]),
          Cell.new(content: [Content.label("Total")])
        ]
      )

      result = Typst.render_report([title, table])

      assert result =~ "Sales Report"
      assert result =~ "#grid("
      assert result =~ "#table("
    end

    test "renders report with lines" do
      table = IR.table(
        properties: %{columns: ["1fr", "1fr"]},
        children: [
          Cell.new(content: [Content.label("A")]),
          Cell.new(content: [Content.label("B")])
        ],
        lines: [
          Line.hline(0, stroke: "2pt"),
          Line.hline(1, stroke: "1pt")
        ]
      )

      result = Typst.render(table)

      assert result =~ "table.hline(y: 0, stroke: 2pt)"
      assert result =~ "table.hline(y: 1, stroke: 1pt)"
    end
  end
end
