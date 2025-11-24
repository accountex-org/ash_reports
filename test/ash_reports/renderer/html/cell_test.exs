defmodule AshReports.Renderer.Html.CellTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Cell
  alias AshReports.Layout.IR

  describe "render/2 with grid context" do
    test "renders basic grid cell" do
      cell = IR.Cell.new(content: [%{text: "Hello"}])
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, ~s(class="ash-cell"))
      assert String.contains?(result, "Hello")
    end

    test "renders grid cell with colspan" do
      cell = IR.Cell.new(span: {2, 1}, content: [%{text: "Wide"}])
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "grid-column: span 2")
    end

    test "renders grid cell with rowspan" do
      cell = IR.Cell.new(span: {1, 3}, content: [%{text: "Tall"}])
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "grid-row: span 3")
    end

    test "renders grid cell with both colspan and rowspan" do
      cell = IR.Cell.new(span: {2, 3}, content: [%{text: "Big"}])
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "grid-column: span 2")
      assert String.contains?(result, "grid-row: span 3")
    end

    test "renders grid cell with explicit x position" do
      cell = IR.Cell.new(position: {2, 0}, content: [%{text: "Positioned"}])
      result = Cell.render(cell, context: :grid)

      # CSS Grid uses 1-based indexing, so x=2 becomes column 3
      assert String.contains?(result, "grid-column: 3")
    end

    test "renders grid cell with explicit y position" do
      cell = IR.Cell.new(position: {0, 2}, content: [%{text: "Positioned"}])
      result = Cell.render(cell, context: :grid)

      # CSS Grid uses 1-based indexing, so y=2 becomes row 3
      assert String.contains?(result, "grid-row: 3")
    end

    test "renders grid cell with both x and y position" do
      cell = IR.Cell.new(position: {1, 2}, content: [%{text: "Both"}])
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "grid-column: 2")
      assert String.contains?(result, "grid-row: 3")
    end

    test "renders grid cell with padding" do
      cell = IR.Cell.new(
        properties: %{inset: "10pt"},
        content: [%{text: "Padded"}]
      )
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "padding: 10px")
    end

    test "renders grid cell with background color" do
      cell = IR.Cell.new(
        properties: %{fill: "#ff0000"},
        content: [%{text: "Red"}]
      )
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "background-color: #ff0000")
    end

    test "renders grid cell with border" do
      cell = IR.Cell.new(
        properties: %{stroke: "1px solid black"},
        content: [%{text: "Bordered"}]
      )
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "border: 1px solid black")
    end

    test "renders grid cell with text alignment" do
      cell = IR.Cell.new(
        properties: %{align: :center},
        content: [%{text: "Centered"}]
      )
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "text-align: center")
    end

    test "renders grid cell with vertical alignment" do
      cell = IR.Cell.new(
        properties: %{vertical_align: :top},
        content: [%{text: "Top"}]
      )
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "vertical-align: top")
    end

    test "renders grid cell with tuple alignment (horizontal and vertical)" do
      cell = IR.Cell.new(
        properties: %{align: {:right, :bottom}},
        content: [%{text: "Both"}]
      )
      result = Cell.render(cell, context: :grid)

      assert String.contains?(result, "text-align: right")
      assert String.contains?(result, "vertical-align: bottom")
    end
  end

  describe "render/2 with table_header context" do
    test "renders table header cell as th" do
      cell = IR.Cell.new(content: [%{text: "Header"}])
      result = Cell.render(cell, context: :table_header)

      assert String.starts_with?(result, "<th")
      assert String.contains?(result, "Header")
      assert String.ends_with?(result, "</th>")
    end

    test "renders table header with colspan attribute" do
      cell = IR.Cell.new(span: {2, 1}, content: [%{text: "Wide Header"}])
      result = Cell.render(cell, context: :table_header)

      assert String.contains?(result, ~s(colspan="2"))
    end

    test "renders table header with rowspan attribute" do
      cell = IR.Cell.new(span: {1, 3}, content: [%{text: "Tall Header"}])
      result = Cell.render(cell, context: :table_header)

      assert String.contains?(result, ~s(rowspan="3"))
    end

    test "renders table header with both spans" do
      cell = IR.Cell.new(span: {2, 3}, content: [%{text: "Big Header"}])
      result = Cell.render(cell, context: :table_header)

      assert String.contains?(result, ~s(colspan="2"))
      assert String.contains?(result, ~s(rowspan="3"))
    end
  end

  describe "render/2 with table_body context" do
    test "renders table body cell as td" do
      cell = IR.Cell.new(content: [%{text: "Data"}])
      result = Cell.render(cell, context: :table_body)

      assert String.starts_with?(result, "<td")
      assert String.contains?(result, "Data")
      assert String.ends_with?(result, "</td>")
    end

    test "renders table body with styles" do
      cell = IR.Cell.new(
        properties: %{
          inset: "5pt",
          fill: "#eee",
          align: :right,
          vertical_align: :middle
        },
        content: [%{text: "Styled"}]
      )
      result = Cell.render(cell, context: :table_body)

      assert String.contains?(result, "padding: 5px")
      assert String.contains?(result, "background-color: #eee")
      assert String.contains?(result, "text-align: right")
      assert String.contains?(result, "vertical-align: middle")
    end

    test "renders table body with colspan" do
      cell = IR.Cell.new(span: {3, 1}, content: [%{text: "Wide"}])
      result = Cell.render(cell, context: :table_body)

      assert String.contains?(result, ~s(colspan="3"))
    end
  end

  describe "render/2 with table_footer context" do
    test "renders table footer cell as td" do
      cell = IR.Cell.new(content: [%{text: "Total"}])
      result = Cell.render(cell, context: :table_footer)

      assert String.starts_with?(result, "<td")
      assert String.contains?(result, "Total")
      assert String.ends_with?(result, "</td>")
    end
  end

  describe "render/2 with stack context" do
    test "renders stack context as grid cell" do
      cell = IR.Cell.new(content: [%{text: "Stack Item"}])
      result = Cell.render(cell, context: :stack)

      assert String.contains?(result, ~s(class="ash-cell"))
      assert String.contains?(result, "Stack Item")
    end
  end

  describe "content rendering" do
    test "renders text content" do
      cell = IR.Cell.new(content: [%{text: "Text"}])
      result = Cell.render(cell)

      assert String.contains?(result, "Text")
    end

    test "renders value content" do
      cell = IR.Cell.new(content: [%{value: 42}])
      result = Cell.render(cell)

      assert String.contains?(result, "42")
    end

    test "renders multiple content items" do
      cell = IR.Cell.new(content: [%{text: "Label: "}, %{value: 100}])
      result = Cell.render(cell)

      assert String.contains?(result, "Label: ")
      assert String.contains?(result, "100")
    end

    test "escapes HTML in content" do
      cell = IR.Cell.new(content: [%{text: "<script>alert('XSS')</script>"}])
      result = Cell.render(cell)

      assert String.contains?(result, "&lt;script&gt;")
      refute String.contains?(result, "<script>")
    end

    test "renders empty cell" do
      cell = IR.Cell.new(content: [])
      result = Cell.render(cell)

      assert String.contains?(result, ~s(class="ash-cell"))
      assert String.contains?(result, "><")  # Empty content
    end
  end

  describe "escape_html/1" do
    test "escapes ampersand" do
      assert Cell.escape_html("A & B") == "A &amp; B"
    end

    test "escapes less than" do
      assert Cell.escape_html("a < b") == "a &lt; b"
    end

    test "escapes greater than" do
      assert Cell.escape_html("a > b") == "a &gt; b"
    end

    test "escapes double quotes" do
      assert Cell.escape_html(~s("hello")) == "&quot;hello&quot;"
    end

    test "escapes single quotes" do
      assert Cell.escape_html("it's") == "it&#39;s"
    end

    test "escapes multiple special characters" do
      input = "<script>alert('XSS & attack')</script>"
      expected = "&lt;script&gt;alert(&#39;XSS &amp; attack&#39;)&lt;/script&gt;"
      assert Cell.escape_html(input) == expected
    end

    test "handles non-string input" do
      assert Cell.escape_html(123) == "123"
    end
  end

  describe "stroke rendering" do
    test "renders stroke as border with thickness and paint" do
      cell = IR.Cell.new(
        properties: %{stroke: %{thickness: "2pt", paint: "#000"}},
        content: [%{text: "Bordered"}]
      )
      result = Cell.render(cell)

      assert String.contains?(result, "border: 2px solid #000")
    end

    test "renders stroke with thickness only" do
      cell = IR.Cell.new(
        properties: %{stroke: %{thickness: "1pt"}},
        content: [%{text: "Bordered"}]
      )
      result = Cell.render(cell)

      assert String.contains?(result, "border: 1px solid currentColor")
    end

    test "renders :none stroke" do
      cell = IR.Cell.new(
        properties: %{stroke: :none},
        content: [%{text: "No border"}]
      )
      result = Cell.render(cell)

      refute String.contains?(result, "border:")
    end
  end

  describe "color rendering" do
    test "renders :none fill as transparent" do
      cell = IR.Cell.new(
        properties: %{fill: :none},
        content: [%{text: "Transparent"}]
      )
      result = Cell.render(cell)

      refute String.contains?(result, "background-color:")
    end

    test "renders atom color" do
      cell = IR.Cell.new(
        properties: %{fill: :red},
        content: [%{text: "Red"}]
      )
      result = Cell.render(cell)

      assert String.contains?(result, "background-color: red")
    end
  end
end
