defmodule AshReports.Layout.IRTest do
  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.{Cell, Row, Content, Line, Header, Footer, Style}

  describe "Layout IR" do
    test "creates grid IR with default values" do
      ir = IR.new(:grid)

      assert ir.type == :grid
      assert ir.properties == %{}
      assert ir.children == []
      assert ir.lines == []
      assert ir.headers == []
      assert ir.footers == []
    end

    test "creates grid IR with properties" do
      ir = IR.new(:grid, properties: %{columns: ["1fr", "2fr"], rows: ["auto"]})

      assert ir.type == :grid
      assert ir.properties.columns == ["1fr", "2fr"]
      assert ir.properties.rows == ["auto"]
    end

    test "creates table IR" do
      ir = IR.new(:table, properties: %{stroke: "1pt"})

      assert ir.type == :table
      assert ir.properties.stroke == "1pt"
    end

    test "creates stack IR" do
      ir = IR.new(:stack, properties: %{dir: :ttb, spacing: "10pt"})

      assert ir.type == :stack
      assert ir.properties.dir == :ttb
      assert ir.properties.spacing == "10pt"
    end

    test "convenience constructors work" do
      assert IR.grid().type == :grid
      assert IR.table().type == :table
      assert IR.stack().type == :stack
    end

    test "adds children to IR" do
      cell = Cell.new(position: {0, 0})
      ir = IR.grid() |> IR.add_child(cell)

      assert length(ir.children) == 1
      assert hd(ir.children) == cell
    end

    test "adds lines to IR" do
      line = Line.hline(1, stroke: "1pt")
      ir = IR.grid() |> IR.add_line(line)

      assert length(ir.lines) == 1
      assert hd(ir.lines) == line
    end

    test "adds headers to table IR" do
      header = Header.new(repeat: true)
      ir = IR.table() |> IR.add_header(header)

      assert length(ir.headers) == 1
      assert hd(ir.headers).repeat == true
    end

    test "adds footers to table IR" do
      footer = Footer.new(repeat: true)
      ir = IR.table() |> IR.add_footer(footer)

      assert length(ir.footers) == 1
      assert hd(ir.footers).repeat == true
    end

    test "puts and gets properties" do
      ir = IR.grid()
      |> IR.put_property(:columns, ["1fr", "1fr"])
      |> IR.put_property(:gutter, "10pt")

      assert IR.get_property(ir, :columns) == ["1fr", "1fr"]
      assert IR.get_property(ir, :gutter) == "10pt"
      assert IR.get_property(ir, :missing, "default") == "default"
    end
  end

  describe "Cell IR" do
    test "creates cell with default values" do
      cell = Cell.new()

      assert cell.position == {0, 0}
      assert cell.span == {1, 1}
      assert cell.properties == %{}
      assert cell.content == []
    end

    test "creates cell with position and span" do
      cell = Cell.new(position: {2, 3}, span: {2, 1})

      assert cell.position == {2, 3}
      assert cell.span == {2, 1}
    end

    test "accessor functions work" do
      cell = Cell.new(position: {1, 2}, span: {3, 4})

      assert Cell.x(cell) == 1
      assert Cell.y(cell) == 2
      assert Cell.colspan(cell) == 3
      assert Cell.rowspan(cell) == 4
    end

    test "calculates occupied positions for single cell" do
      cell = Cell.new(position: {0, 0}, span: {1, 1})
      positions = Cell.occupied_positions(cell)

      assert positions == [{0, 0}]
    end

    test "calculates occupied positions for colspan" do
      cell = Cell.new(position: {1, 0}, span: {3, 1})
      positions = Cell.occupied_positions(cell)

      assert positions == [{1, 0}, {2, 0}, {3, 0}]
    end

    test "calculates occupied positions for rowspan" do
      cell = Cell.new(position: {0, 1}, span: {1, 3})
      positions = Cell.occupied_positions(cell)

      assert positions == [{0, 1}, {0, 2}, {0, 3}]
    end

    test "calculates occupied positions for 2D span" do
      cell = Cell.new(position: {1, 1}, span: {2, 2})
      positions = Cell.occupied_positions(cell)

      assert Enum.sort(positions) == [{1, 1}, {1, 2}, {2, 1}, {2, 2}]
    end

    test "adds content to cell" do
      label = Content.label("Test")
      cell = Cell.new() |> Cell.add_content(label)

      assert length(cell.content) == 1
    end

    test "puts and gets properties" do
      cell = Cell.new()
      |> Cell.put_property(:align, :center)
      |> Cell.put_property(:fill, "gray")

      assert Cell.get_property(cell, :align) == :center
      assert Cell.get_property(cell, :fill) == "gray"
    end
  end

  describe "Row IR" do
    test "creates row with default values" do
      row = Row.new()

      assert row.index == 0
      assert row.properties == %{}
      assert row.cells == []
    end

    test "creates row with index and properties" do
      row = Row.new(index: 2, properties: %{align: :center})

      assert row.index == 2
      assert row.properties.align == :center
    end

    test "adds cells to row" do
      cell = Cell.new()
      row = Row.new() |> Row.add_cell(cell)

      assert Row.cell_count(row) == 1
    end

    test "puts and gets properties" do
      row = Row.new()
      |> Row.put_property(:fill, "lightgray")

      assert Row.get_property(row, :fill) == "lightgray"
    end
  end

  describe "Content IR - Label" do
    test "creates label with text" do
      label = Content.label("Hello World")

      assert label.text == "Hello World"
      assert label.style == nil
    end

    test "creates label with style" do
      style = Style.new(font_weight: :bold)
      label = Content.label("Bold Text", style: style)

      assert label.text == "Bold Text"
      assert label.style.font_weight == :bold
    end

    test "content_type returns :label" do
      label = Content.label("Test")
      assert Content.content_type(label) == :label
    end
  end

  describe "Content IR - Field" do
    test "creates field with source" do
      field = Content.field(:amount)

      assert field.source == :amount
      assert field.format == nil
      assert field.decimal_places == nil
    end

    test "creates field with format options" do
      field = Content.field(:amount, format: :currency, decimal_places: 2)

      assert field.source == :amount
      assert field.format == :currency
      assert field.decimal_places == 2
    end

    test "creates field with nested source" do
      field = Content.field([:customer, :name])

      assert field.source == [:customer, :name]
    end

    test "content_type returns :field" do
      field = Content.field(:test)
      assert Content.content_type(field) == :field
    end
  end

  describe "Content IR - NestedLayout" do
    test "creates nested layout" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      nested = Content.nested_layout(grid)

      assert nested.layout.type == :grid
    end

    test "content_type returns :nested_layout" do
      nested = Content.nested_layout(IR.stack())
      assert Content.content_type(nested) == :nested_layout
    end
  end

  describe "Line IR" do
    test "creates horizontal line" do
      line = Line.new(orientation: :horizontal, position: 2)

      assert line.orientation == :horizontal
      assert line.position == 2
    end

    test "creates vertical line" do
      line = Line.new(orientation: :vertical, position: 1)

      assert line.orientation == :vertical
      assert line.position == 1
    end

    test "hline convenience constructor" do
      line = Line.hline(3, stroke: "2pt", start: 0, end: 4)

      assert line.orientation == :horizontal
      assert line.position == 3
      assert line.stroke == "2pt"
      assert line.start == 0
      assert line.end == 4
    end

    test "vline convenience constructor" do
      line = Line.vline(2, stroke: "1pt solid red")

      assert line.orientation == :vertical
      assert line.position == 2
      assert line.stroke == "1pt solid red"
    end

    test "horizontal? and vertical? predicates" do
      hline = Line.hline(0)
      vline = Line.vline(0)

      assert Line.horizontal?(hline) == true
      assert Line.horizontal?(vline) == false
      assert Line.vertical?(vline) == true
      assert Line.vertical?(hline) == false
    end
  end

  describe "Header IR" do
    test "creates header with default values" do
      header = Header.new()

      assert header.repeat == true
      assert header.level == 0
      assert header.rows == []
    end

    test "creates header with options" do
      header = Header.new(repeat: false, level: 1)

      assert header.repeat == false
      assert header.level == 1
    end

    test "adds rows to header" do
      row = Row.new()
      header = Header.new() |> Header.add_row(row)

      assert Header.row_count(header) == 1
    end
  end

  describe "Footer IR" do
    test "creates footer with default values" do
      footer = Footer.new()

      assert footer.repeat == false
      assert footer.rows == []
    end

    test "creates footer with options" do
      footer = Footer.new(repeat: true)

      assert footer.repeat == true
    end

    test "adds rows to footer" do
      row = Row.new()
      footer = Footer.new() |> Footer.add_row(row)

      assert Footer.row_count(footer) == 1
    end
  end

  describe "Style IR" do
    test "creates style with default nil values" do
      style = Style.new()

      assert style.font_size == nil
      assert style.font_weight == nil
      assert style.color == nil
    end

    test "creates style with options" do
      style = Style.new(
        font_size: "12pt",
        font_weight: :bold,
        color: "#333333",
        font_family: "Helvetica"
      )

      assert style.font_size == "12pt"
      assert style.font_weight == :bold
      assert style.color == "#333333"
      assert style.font_family == "Helvetica"
    end

    test "merges styles with override taking precedence" do
      base = Style.new(font_size: "12pt", color: "black", font_weight: :normal)
      override = Style.new(color: "red", font_weight: :bold)
      merged = Style.merge(base, override)

      assert merged.font_size == "12pt"
      assert merged.color == "red"
      assert merged.font_weight == :bold
    end

    test "empty? returns true for empty style" do
      style = Style.new()
      assert Style.empty?(style) == true
    end

    test "empty? returns false for non-empty style" do
      style = Style.new(font_size: "12pt")
      assert Style.empty?(style) == false
    end
  end

  describe "Nested IR structures" do
    test "creates complex nested structure" do
      # Create a grid with rows and cells
      label = Content.label("Header", style: Style.new(font_weight: :bold))
      field = Content.field(:amount, format: :currency)

      header_cell = Cell.new(position: {0, 0}, content: [label])
      data_cell = Cell.new(position: {0, 1}, content: [field])

      row1 = Row.new(index: 0, cells: [header_cell])
      row2 = Row.new(index: 1, cells: [data_cell])

      grid = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [row1, row2]
      )

      assert grid.type == :grid
      assert length(grid.children) == 2

      first_row = hd(grid.children)
      assert first_row.index == 0
      assert length(first_row.cells) == 1

      first_cell = hd(first_row.cells)
      assert first_cell.position == {0, 0}
      assert length(first_cell.content) == 1

      content = hd(first_cell.content)
      assert Content.content_type(content) == :label
      assert content.text == "Header"
    end

    test "creates table with header and footer" do
      header_row = Row.new(index: 0, cells: [Cell.new()])
      footer_row = Row.new(index: 0, cells: [Cell.new()])

      header = Header.new(repeat: true, rows: [header_row])
      footer = Footer.new(repeat: true, rows: [footer_row])

      data_row = Row.new(index: 0, cells: [Cell.new()])

      table = IR.table(
        properties: %{stroke: "1pt", columns: ["1fr", "1fr"]},
        children: [data_row],
        headers: [header],
        footers: [footer]
      )

      assert table.type == :table
      assert length(table.headers) == 1
      assert length(table.footers) == 1
      assert hd(table.headers).repeat == true
      assert hd(table.footers).repeat == true
    end

    test "creates nested layout within cell" do
      inner_grid = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      nested = Content.nested_layout(inner_grid)
      cell = Cell.new(content: [nested])

      assert length(cell.content) == 1
      content = hd(cell.content)
      assert Content.content_type(content) == :nested_layout
      assert content.layout.type == :grid
    end
  end
end
