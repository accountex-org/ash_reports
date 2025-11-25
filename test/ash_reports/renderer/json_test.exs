defmodule AshReports.Renderer.JsonTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Json
  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.{Cell, Row, Content, Line, Header, Footer, Style}

  describe "render/2" do
    test "serializes grid IR to map" do
      ir = IR.grid(properties: %{columns: ["1fr", "1fr"], gap: "10px"})
      result = Json.render(ir)

      assert result.type == "grid"
      assert result.properties.columns == ["1fr", "1fr"]
      assert result.properties.gap == "10px"
      assert result.children == []
      assert result.lines == []
      assert result.headers == []
      assert result.footers == []
    end

    test "serializes table IR to map" do
      ir = IR.table(properties: %{columns: ["1fr", "2fr"]})
      result = Json.render(ir)

      assert result.type == "table"
      assert result.properties.columns == ["1fr", "2fr"]
    end

    test "serializes stack IR to map" do
      ir = IR.stack(properties: %{direction: :ttb, spacing: "10px"})
      result = Json.render(ir)

      assert result.type == "stack"
      assert result.properties.direction == "ttb"
      assert result.properties.spacing == "10px"
    end

    test "serializes cells in children" do
      cell = Cell.new(
        position: {1, 2},
        span: {2, 3},
        properties: %{align: :center}
      )
      ir = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [cell]
      )
      result = Json.render(ir)

      assert length(result.children) == 1
      [cell_json] = result.children

      assert cell_json.type == "cell"
      assert cell_json.position == [1, 2]
      assert cell_json.span == [2, 3]
      assert cell_json.properties.align == "center"
    end

    test "serializes rows in children" do
      cell = Cell.new(content: [%{text: "Hello"}])
      row = Row.new(index: 1, properties: %{fill: "#f0f0f0"}, cells: [cell])
      ir = IR.table(
        properties: %{columns: ["1fr"]},
        children: [row]
      )
      result = Json.render(ir)

      assert length(result.children) == 1
      [row_json] = result.children

      assert row_json.type == "row"
      assert row_json.index == 1
      assert row_json.properties.fill == "#f0f0f0"
      assert length(row_json.cells) == 1
    end

    test "serializes label content" do
      style = %Style{font_size: "12pt", font_weight: :bold, color: "#000"}
      label = Content.label("Total:", style: style)
      cell = Cell.new(content: [label])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Json.render(ir)
      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.type == "label"
      assert content_json.text == "Total:"
      assert content_json.style.font_size == "12pt"
      assert content_json.style.font_weight == "bold"
      assert content_json.style.color == "#000"
    end

    test "serializes field content with data resolution" do
      field = Content.field(:amount, format: :currency, decimal_places: 2)
      cell = Cell.new(content: [field])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Json.render(ir, data: %{amount: 99.99})
      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.type == "field"
      assert content_json.source == "amount"
      assert content_json.value == 99.99
      assert content_json.format == "currency"
      assert content_json.decimal_places == 2
    end

    test "serializes field with nested source path" do
      field = Content.field([:user, :address, :city])
      cell = Cell.new(content: [field])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      data = %{user: %{address: %{city: "New York"}}}
      result = Json.render(ir, data: data)

      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.source == ["user", "address", "city"]
      assert content_json.value == "New York"
    end

    test "serializes nested layout content" do
      inner_ir = IR.grid(properties: %{columns: ["1fr"]})
      nested = Content.nested_layout(inner_ir)
      cell = Cell.new(content: [nested])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Json.render(ir)
      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.type == "nested_layout"
      assert content_json.layout.type == "grid"
      assert content_json.layout.properties.columns == ["1fr"]
    end

    test "serializes lines" do
      line = Line.hline(2, stroke: "1pt solid black", start: 0, end: 3)
      ir = IR.grid(
        properties: %{columns: ["1fr", "1fr", "1fr"]},
        lines: [line]
      )
      result = Json.render(ir)

      assert length(result.lines) == 1
      [line_json] = result.lines

      assert line_json.orientation == "horizontal"
      assert line_json.position == 2
      assert line_json.start == 0
      assert line_json.end == 3
      assert line_json.stroke == "1pt solid black"
    end

    test "serializes headers" do
      cell = Cell.new(content: [%{text: "Column 1"}])
      row = Row.new(cells: [cell])
      header = %Header{repeat: true, level: 0, rows: [row]}
      ir = IR.table(
        properties: %{columns: ["1fr"]},
        headers: [header]
      )
      result = Json.render(ir)

      assert length(result.headers) == 1
      [header_json] = result.headers

      assert header_json.type == "header"
      assert header_json.repeat == true
      assert length(header_json.rows) == 1
    end

    test "serializes footers" do
      cell = Cell.new(content: [%{text: "Total"}])
      row = Row.new(cells: [cell])
      footer = %Footer{repeat: false, rows: [row]}
      ir = IR.table(
        properties: %{columns: ["1fr"]},
        footers: [footer]
      )
      result = Json.render(ir)

      assert length(result.footers) == 1
      [footer_json] = result.footers

      assert footer_json.type == "footer"
      assert footer_json.repeat == false
    end

    test "serializes atom properties as strings" do
      ir = IR.grid(properties: %{
        direction: :ttb,
        align: :center,
        fill: :none
      })
      result = Json.render(ir)

      assert result.properties.direction == "ttb"
      assert result.properties.align == "center"
      assert result.properties.fill == "none"
    end

    test "serializes tuple properties as arrays" do
      ir = IR.grid(properties: %{
        position: {1, 2},
        span: {3, 4}
      })
      result = Json.render(ir)

      assert result.properties.position == [1, 2]
      assert result.properties.span == [3, 4]
    end

    test "handles functions in properties" do
      ir = IR.grid(properties: %{
        fill: fn _row, _col -> "#fff" end
      })
      result = Json.render(ir)

      assert result.properties.fill == "__function__"
    end

    test "handles missing field data gracefully" do
      field = Content.field(:missing_field)
      cell = Cell.new(content: [field])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Json.render(ir, data: %{other: "value"})
      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.value == nil
    end
  end

  describe "render_all/2" do
    test "serializes multiple layouts" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      table = IR.table(properties: %{columns: ["1fr", "1fr"]})
      stack = IR.stack(properties: %{direction: :ltr})

      result = Json.render_all([grid, table, stack])

      assert is_map(result)
      assert length(result.layouts) == 3

      [grid_json, table_json, stack_json] = result.layouts
      assert grid_json.type == "grid"
      assert table_json.type == "table"
      assert stack_json.type == "stack"
    end

    test "serializes empty list" do
      result = Json.render_all([])
      assert result.layouts == []
    end

    test "passes data to all layouts" do
      field1 = Content.field(:title)
      field2 = Content.field(:name)

      cell1 = Cell.new(content: [field1])
      cell2 = Cell.new(content: [field2])

      grid1 = IR.grid(properties: %{columns: ["1fr"]}, children: [cell1])
      grid2 = IR.grid(properties: %{columns: ["1fr"]}, children: [cell2])

      data = %{title: "Report", name: "Test"}
      result = Json.render_all([grid1, grid2], data: data)

      [layout1, layout2] = result.layouts
      assert hd(hd(layout1.children).content).value == "Report"
      assert hd(hd(layout2.children).content).value == "Test"
    end
  end

  describe "render_json/2" do
    test "encodes single IR to JSON string" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Json.render_json(ir)

      assert is_binary(result)
      decoded = Jason.decode!(result)
      assert decoded["type"] == "grid"
      assert decoded["properties"]["columns"] == ["1fr"]
    end

    test "encodes multiple layouts to JSON string" do
      layouts = [
        IR.grid(properties: %{columns: ["1fr"]}),
        IR.table(properties: %{columns: ["1fr"]})
      ]
      result = Json.render_json(layouts)

      assert is_binary(result)
      decoded = Jason.decode!(result)
      assert length(decoded["layouts"]) == 2
    end

    test "produces valid JSON" do
      cell = Cell.new(
        position: {0, 0},
        span: {2, 1},
        content: [Content.label("Test", style: %Style{font_weight: :bold})]
      )
      ir = IR.grid(
        properties: %{columns: ["1fr", "1fr"], gap: "10px"},
        children: [cell]
      )

      result = Json.render_json(ir)

      # Should not raise
      decoded = Jason.decode!(result)
      assert decoded["type"] == "grid"
      assert length(decoded["children"]) == 1
    end
  end

  describe "nested structures" do
    test "serializes deeply nested layouts" do
      inner_cell = Cell.new(content: [%{text: "Inner"}])
      inner_grid = IR.grid(properties: %{columns: ["1fr"]}, children: [inner_cell])
      nested = Content.nested_layout(inner_grid)
      outer_cell = Cell.new(content: [nested])
      outer_grid = IR.grid(properties: %{columns: ["1fr"]}, children: [outer_cell])

      result = Json.render(outer_grid)

      [cell] = result.children
      [content] = cell.content
      assert content.type == "nested_layout"
      assert content.layout.type == "grid"
      [inner_cell_json] = content.layout.children
      [inner_content] = inner_cell_json.content
      assert inner_content.text == "Inner"
    end

    test "serializes complete table with headers, body, and footers" do
      header_cell = Cell.new(content: [%{text: "Column"}])
      header_row = Row.new(cells: [header_cell])
      header = %Header{repeat: true, rows: [header_row]}

      body_cell = Cell.new(content: [%{text: "Data"}])
      body_row = Row.new(cells: [body_cell])

      footer_cell = Cell.new(content: [%{text: "Total"}])
      footer_row = Row.new(cells: [footer_cell])
      footer = %Footer{repeat: false, rows: [footer_row]}

      ir = IR.table(
        properties: %{columns: ["1fr"]},
        headers: [header],
        children: [body_row],
        footers: [footer]
      )

      result = Json.render(ir)

      assert result.type == "table"
      assert length(result.headers) == 1
      assert length(result.children) == 1
      assert length(result.footers) == 1
    end
  end

  describe "data resolution" do
    test "resolves data with string keys" do
      field = Content.field(:name)
      cell = Cell.new(content: [field])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Json.render(ir, data: %{"name" => "Test"})
      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.value == "Test"
    end

    test "resolves data with atom keys" do
      field = Content.field(:name)
      cell = Cell.new(content: [field])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Json.render(ir, data: %{name: "Test"})
      [cell_json] = result.children
      [content_json] = cell_json.content

      assert content_json.value == "Test"
    end

    test "resolves nested paths with mixed keys" do
      field = Content.field([:user, :profile, :name])
      cell = Cell.new(content: [field])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      # The resolver tries both atom and string keys at each level
      data = %{user: %{"profile" => %{name: "Alice"}}}
      result = Json.render(ir, data: data)

      [cell_json] = result.children
      [content_json] = cell_json.content

      # The resolver successfully finds the value by trying string key "profile"
      assert content_json.value == "Alice"
    end
  end
end
