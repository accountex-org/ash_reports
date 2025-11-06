defmodule AshReports.HeexRenderer.TemplateBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.HeexRenderer.TemplateBuilder

  describe "for_attr/2" do
    test "generates for comprehension attribute" do
      assert TemplateBuilder.for_attr("band", "@bands") == ":for={band <- @bands}"
    end

    test "handles different variable names" do
      assert TemplateBuilder.for_attr("item", "@items") == ":for={item <- @items}"
      assert TemplateBuilder.for_attr("record", "@records") == ":for={record <- @records}"
    end
  end

  describe "for_div/4" do
    test "generates div with for comprehension" do
      result = TemplateBuilder.for_div("band", "@bands", "", "<span>content</span>")
      assert result == "<div :for={band <- @bands}><span>content</span></div>"
    end

    test "includes additional attributes" do
      result = TemplateBuilder.for_div("band", "@bands", "class=\"band\"", "<span>content</span>")
      assert result == "<div :for={band <- @bands} class=\"band\"><span>content</span></div>"
    end

    test "handles empty content" do
      result = TemplateBuilder.for_div("item", "@items", "", "")
      assert result == "<div :for={item <- @items}></div>"
    end
  end

  describe "assign/2" do
    test "generates assign reference with interpolation by default" do
      assert TemplateBuilder.assign("report.title") == "<%= @report.title %>"
    end

    test "generates raw assign reference when raw: true" do
      assert TemplateBuilder.assign("band", raw: true) == "@band"
    end

    test "handles nested paths" do
      assert TemplateBuilder.assign("report.metadata.author") ==
               "<%= @report.metadata.author %>"
    end
  end

  describe "component/3" do
    test "generates self-closing component with no attrs" do
      assert TemplateBuilder.component("report_header") == "<.report_header />"
    end

    test "generates component with attributes" do
      result = TemplateBuilder.component("report_header", %{title: "@report.title"})
      assert result == "<.report_header title={@report.title} />"
    end

    test "generates component with content" do
      result =
        TemplateBuilder.component("band", %{type: "@band.type"}, "<span>content</span>")

      assert result == "<.band type={@band.type}><span>content</span></.band>"
    end

    test "generates component with multiple attributes" do
      result =
        TemplateBuilder.component("element", %{
          id: "@element.id",
          type: "@element.type"
        })

      assert result =~ "<.element"
      assert result =~ "id={@element.id}"
      assert result =~ "type={@element.type}"
      assert result =~ "/>"
    end
  end

  describe "if_condition/2" do
    test "generates if block" do
      result = TemplateBuilder.if_condition("@show_header", "<div>Header</div>")
      assert result == "<%= if @show_header do %><div>Header</div><% end %>"
    end

    test "handles complex conditions" do
      result = TemplateBuilder.if_condition("@band.type == :title", "<h1>Title</h1>")
      assert result == "<%= if @band.type == :title do %><h1>Title</h1><% end %>"
    end
  end

  describe "if_else/3" do
    test "generates if-else block" do
      result =
        TemplateBuilder.if_else("@has_data", "<div>Data</div>", "<div>No data</div>")

      assert result ==
               "<%= if @has_data do %><div>Data</div><% else %><div>No data</div><% end %>"
    end
  end

  describe "case_statement/2" do
    test "generates case statement with multiple clauses" do
      result =
        TemplateBuilder.case_statement("@band.type", [
          {:title, "<div>Title</div>"},
          {:detail, "<div>Detail</div>"}
        ])

      assert result =~ "<%= case @band.type do %>"
      assert result =~ "<% :title -> %><div>Title</div>"
      assert result =~ "<% :detail -> %><div>Detail</div>"
      assert result =~ "<% end %>"
    end
  end

  describe "escape/1" do
    test "escapes HTML entities" do
      assert TemplateBuilder.escape("<script>") == "&lt;script&gt;"
      assert TemplateBuilder.escape("&") == "&amp;"
      assert TemplateBuilder.escape("\"") == "&quot;"
      assert TemplateBuilder.escape("'") == "&#39;"
    end

    test "handles mixed content" do
      input = "<div class=\"test\" data-id='123'>Hello & Goodbye</div>"
      result = TemplateBuilder.escape(input)

      assert result =~ "&lt;div"
      assert result =~ "&quot;test&quot;"
      assert result =~ "&#39;123&#39;"
      assert result =~ "Hello &amp; Goodbye"
      assert result =~ "&lt;/div&gt;"
    end

    test "handles non-string values" do
      assert TemplateBuilder.escape(123) == "123"
      assert TemplateBuilder.escape(:atom) == "atom"
    end
  end

  describe "container/2" do
    test "wraps content in div with no class" do
      result = TemplateBuilder.container("<span>content</span>")
      assert result == "<div><span>content</span></div>"
    end

    test "wraps content in div with class" do
      result = TemplateBuilder.container("<span>content</span>", "ash-report")
      assert result == "<div class=\"ash-report\"><span>content</span></div>"
    end
  end

  describe "comment/1" do
    test "generates HEEX comment" do
      assert TemplateBuilder.comment("This is a band") == "<%!-- This is a band --%>"
    end
  end

  describe "join/2" do
    test "joins fragments with newline by default" do
      result = TemplateBuilder.join(["<div>1</div>", "<div>2</div>"])
      assert result == "<div>1</div>\n<div>2</div>"
    end

    test "joins fragments with custom separator" do
      result = TemplateBuilder.join(["<div>1</div>", "<div>2</div>"], " ")
      assert result == "<div>1</div> <div>2</div>"
    end

    test "handles empty list" do
      assert TemplateBuilder.join([]) == ""
    end

    test "handles single item" do
      assert TemplateBuilder.join(["<div>1</div>"]) == "<div>1</div>"
    end
  end

  describe "tag/3" do
    test "generates self-closing tag with no content" do
      result = TemplateBuilder.tag("img", src: "/logo.png", alt: "Logo")
      assert result =~ "<img"
      assert result =~ "src=\"/logo.png\""
      assert result =~ "alt=\"Logo\""
      assert result =~ "/>"
    end

    test "generates tag with content" do
      result = TemplateBuilder.tag("span", [class: "label"], "Hello")
      assert result == "<span class=\"label\">Hello</span>"
    end

    test "generates tag with no attributes" do
      result = TemplateBuilder.tag("div", [], "Content")
      assert result == "<div>Content</div>"
    end

    test "escapes attribute values" do
      result = TemplateBuilder.tag("div", [data: "<script>"], "Safe")
      assert result == "<div data=\"&lt;script&gt;\">Safe</div>"
    end
  end
end
