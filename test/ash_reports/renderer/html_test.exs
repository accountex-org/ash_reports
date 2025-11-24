defmodule AshReports.Renderer.HtmlTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html
  alias AshReports.Layout.IR

  describe "render/2" do
    test "renders grid IR" do
      ir = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      result = Html.render(ir)

      assert String.contains?(result, ~s(class="ash-grid"))
      assert String.contains?(result, "display: grid")
      assert String.contains?(result, "grid-template-columns: 1fr 1fr")
    end

    test "renders table IR" do
      ir = IR.table(properties: %{columns: ["1fr", "1fr"]})
      result = Html.render(ir)

      assert String.contains?(result, ~s(class="ash-table"))
      assert String.contains?(result, "border-collapse: collapse")
      assert String.contains?(result, "<tbody>")
    end

    test "renders stack IR" do
      ir = IR.stack(properties: %{direction: :ttb})
      result = Html.render(ir)

      assert String.contains?(result, ~s(class="ash-stack"))
      assert String.contains?(result, "display: flex")
      assert String.contains?(result, "flex-direction: column")
    end

    test "passes options through to layout renderers" do
      cell = IR.Cell.new(content: [%{text: "[name]"}])
      ir = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [cell]
      )
      result = Html.render(ir, data: %{"name" => "Test"})

      assert String.contains?(result, "Test")
    end
  end

  describe "render_all/2" do
    test "renders multiple layouts in sequence" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      table = IR.table(properties: %{columns: ["1fr"]})
      stack = IR.stack(properties: %{direction: :ttb})

      result = Html.render_all([grid, table, stack])

      assert String.contains?(result, ~s(class="ash-grid"))
      assert String.contains?(result, ~s(class="ash-table"))
      assert String.contains?(result, ~s(class="ash-stack"))
    end

    test "renders empty list" do
      result = Html.render_all([])
      assert result == ""
    end

    test "wraps output in container div when wrap: true" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_all([grid], wrap: true)

      assert String.starts_with?(result, ~s(<div class="ash-report">))
      assert String.ends_with?(result, "</div>")
    end

    test "uses custom class for wrapper" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_all([grid], wrap: true, class: "my-report")

      assert String.contains?(result, ~s(<div class="my-report">))
    end

    test "escapes malicious class values" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      # Attempt to inject attributes via class
      malicious_class = ~s[foo" onclick="alert(1)]
      result = Html.render_all([grid], wrap: true, class: malicious_class)

      # Quotes should be escaped, preventing attribute injection
      # The raw quote should not appear - it should be &quot;
      refute String.contains?(result, ~s[class="foo" onclick])
      assert String.contains?(result, "foo&quot; onclick=&quot;alert(1)")
    end

    test "does not wrap by default" do
      grid = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_all([grid])

      refute String.starts_with?(result, ~s(<div class="ash-report">))
    end

    test "passes data to all layouts" do
      cell1 = IR.Cell.new(content: [%{text: "[title]"}])
      cell2 = IR.Cell.new(content: [%{text: "[name]"}])

      grid1 = IR.grid(properties: %{columns: ["1fr"]}, children: [cell1])
      grid2 = IR.grid(properties: %{columns: ["1fr"]}, children: [cell2])

      result = Html.render_all([grid1, grid2], data: %{"title" => "Report", "name" => "Test"})

      assert String.contains?(result, "Report")
      assert String.contains?(result, "Test")
    end
  end

  describe "render_safe/2" do
    test "returns safe tuple for single IR" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_safe(ir)

      assert {:safe, html} = result
      assert String.contains?(html, ~s(class="ash-grid"))
    end

    test "returns safe tuple for list of IRs" do
      layouts = [
        IR.grid(properties: %{columns: ["1fr"]}),
        IR.table(properties: %{columns: ["1fr"]})
      ]
      result = Html.render_safe(layouts)

      assert {:safe, html} = result
      assert String.contains?(html, ~s(class="ash-grid"))
      assert String.contains?(html, ~s(class="ash-table"))
    end

    test "passes options through" do
      cell = IR.Cell.new(content: [%{text: "[value]"}])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      {:safe, html} = Html.render_safe(ir, data: %{"value" => "Hello"})

      assert String.contains?(html, "Hello")
    end
  end

  describe "render_document/2" do
    test "generates complete HTML document" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_document(ir)

      assert String.contains?(result, "<!DOCTYPE html>")
      assert String.contains?(result, "<html lang=\"en\">")
      assert String.contains?(result, "<head>")
      assert String.contains?(result, "<body>")
      assert String.contains?(result, "</html>")
    end

    test "uses default title" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_document(ir)

      assert String.contains?(result, "<title>Report</title>")
    end

    test "uses custom title" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_document(ir, title: "My Report")

      assert String.contains?(result, "<title>My Report</title>")
    end

    test "escapes HTML in title" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_document(ir, title: "<script>alert('xss')</script>")

      refute String.contains?(result, "<script>")
      assert String.contains?(result, "&lt;script&gt;")
    end

    test "includes default styles" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_document(ir)

      assert String.contains?(result, "<style>")
      assert String.contains?(result, ".ash-grid")
      assert String.contains?(result, ".ash-table")
      assert String.contains?(result, ".ash-stack")
      assert String.contains?(result, ".ash-cell")
    end

    test "uses custom styles" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      custom_styles = ".custom { color: red; }"
      result = Html.render_document(ir, styles: custom_styles)

      assert String.contains?(result, ".custom { color: red; }")
      refute String.contains?(result, ".ash-grid {")
    end

    test "wraps multiple layouts with container" do
      layouts = [
        IR.grid(properties: %{columns: ["1fr"]}),
        IR.table(properties: %{columns: ["1fr"]})
      ]
      result = Html.render_document(layouts)

      assert String.contains?(result, ~s(class="ash-report"))
    end

    test "includes rendered content in body" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Html.render_document(ir)

      assert String.contains?(result, ~s(class="ash-grid"))
    end

    test "passes data through for interpolation" do
      cell = IR.Cell.new(content: [%{text: "[greeting]"}])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      result = Html.render_document(ir, data: %{"greeting" => "Hello World"})

      assert String.contains?(result, "Hello World")
    end
  end

  describe "default_styles/0" do
    test "returns CSS string with base styles" do
      styles = Html.default_styles()

      assert is_binary(styles)
      assert String.contains?(styles, "box-sizing: border-box")
      assert String.contains?(styles, ".ash-report")
      assert String.contains?(styles, ".ash-grid")
      assert String.contains?(styles, ".ash-table")
      assert String.contains?(styles, ".ash-stack")
      assert String.contains?(styles, ".ash-cell")
      assert String.contains?(styles, ".ash-header")
      assert String.contains?(styles, ".ash-footer")
      assert String.contains?(styles, ".ash-label")
      assert String.contains?(styles, ".ash-field")
    end
  end

  describe "multi-band reports" do
    test "renders header, detail, and footer bands" do
      header = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [IR.Cell.new(content: [%{text: "Header"}])]
      )
      detail = IR.table(
        properties: %{columns: ["1fr", "1fr"]},
        children: [
          %IR.Row{cells: [
            IR.Cell.new(content: [%{text: "Col 1"}]),
            IR.Cell.new(content: [%{text: "Col 2"}])
          ]}
        ]
      )
      footer = IR.stack(
        properties: %{direction: :ltr},
        children: [IR.Cell.new(content: [%{text: "Footer"}])]
      )

      result = Html.render_all([header, detail, footer])

      # Check all three bands are present in order
      grid_pos = :binary.match(result, "ash-grid") |> elem(0)
      table_pos = :binary.match(result, "ash-table") |> elem(0)
      stack_pos = :binary.match(result, "ash-stack") |> elem(0)

      assert grid_pos < table_pos
      assert table_pos < stack_pos

      assert String.contains?(result, "Header")
      assert String.contains?(result, "Col 1")
      assert String.contains?(result, "Col 2")
      assert String.contains?(result, "Footer")
    end

    test "renders report with data interpolation across bands" do
      header = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [IR.Cell.new(content: [%{text: "[report_title]"}])]
      )
      detail = IR.grid(
        properties: %{columns: ["1fr"]},
        children: [IR.Cell.new(content: [%{text: "[detail_text]"}])]
      )

      data = %{
        "report_title" => "Sales Report",
        "detail_text" => "Q4 Results"
      }

      result = Html.render_all([header, detail], data: data)

      assert String.contains?(result, "Sales Report")
      assert String.contains?(result, "Q4 Results")
    end
  end

  describe "HEEX integration" do
    test "safe output can be used in templates" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      {:safe, html} = Html.render_safe(ir)

      # Verify the output is a valid string that could be used in HEEX
      assert is_binary(html)
      assert String.contains?(html, "<div")
      assert String.contains?(html, "</div>")
    end

    test "safe output preserves all content" do
      cell = IR.Cell.new(content: [%{text: "Test Content"}])
      ir = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])

      {:safe, html} = Html.render_safe(ir)

      assert String.contains?(html, "Test Content")
    end
  end
end
