defmodule AshReports.Typst.ChartEmbedder.TypstFormatterTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.ChartEmbedder.TypstFormatter

  describe "format_dimension/1" do
    test "returns string dimensions as-is" do
      assert TypstFormatter.format_dimension("100%") == "100%"
      assert TypstFormatter.format_dimension("300pt") == "300pt"
      assert TypstFormatter.format_dimension("50mm") == "50mm"
      assert TypstFormatter.format_dimension("1fr") == "1fr"
    end

    test "converts numbers to points" do
      assert TypstFormatter.format_dimension(300) == "300pt"
      assert TypstFormatter.format_dimension(150.5) == "150.5pt"
      assert TypstFormatter.format_dimension(0) == "0pt"
    end
  end

  describe "escape_string/1" do
    test "returns unchanged string without special characters" do
      assert TypstFormatter.escape_string("Sales Report") == "Sales Report"
      assert TypstFormatter.escape_string("Q1 Results") == "Q1 Results"
    end

    test "escapes backslashes" do
      assert TypstFormatter.escape_string("path\\to\\file") == "path\\\\to\\\\file"
    end

    test "escapes double quotes" do
      assert TypstFormatter.escape_string("Q1 \"Actual\"") == "Q1 \\\"Actual\\\""
    end

    test "escapes hash symbols" do
      assert TypstFormatter.escape_string("#hashtag") == "\\#hashtag"
      assert TypstFormatter.escape_string("Item #1") == "Item \\#1"
    end

    test "escapes square brackets" do
      assert TypstFormatter.escape_string("[Important]") == "\\[Important\\]"
      assert TypstFormatter.escape_string("Value [100]") == "Value \\[100\\]"
    end

    test "escapes multiple special characters" do
      input = "Path: C:\\Users\\[Admin] #tag \"value\""
      expected = "Path: C:\\\\Users\\\\\\[Admin\\] \\#tag \\\"value\\\""
      assert TypstFormatter.escape_string(input) == expected
    end
  end

  describe "build_grid/2" do
    test "builds grid with default options" do
      charts = ["#image(...)", "#image(...)"]
      {:ok, grid} = TypstFormatter.build_grid(charts)

      assert grid =~ "#grid("
      assert grid =~ "columns: (1fr, 1fr)"
      assert grid =~ "gutter: 10pt"
      assert grid =~ "[#image(...)]"
    end

    test "builds grid with custom columns" do
      charts = ["#image(...)", "#image(...)", "#image(...)"]
      {:ok, grid} = TypstFormatter.build_grid(charts, columns: 3)

      assert grid =~ "columns: (1fr, 1fr, 1fr)"
    end

    test "builds grid with custom gutter" do
      charts = ["#image(...)", "#image(...)"]
      {:ok, grid} = TypstFormatter.build_grid(charts, gutter: "20pt")

      assert grid =~ "gutter: 20pt"
    end

    test "builds grid with custom column widths" do
      charts = ["#image(...)", "#image(...)"]
      {:ok, grid} = TypstFormatter.build_grid(charts, column_widths: ["2fr", "1fr"])

      assert grid =~ "columns: (2fr, 1fr)"
    end

    test "wraps charts in content blocks" do
      charts = ["#image(\"chart1.svg\")", "#image(\"chart2.svg\")"]
      {:ok, grid} = TypstFormatter.build_grid(charts)

      assert grid =~ "[#image(\"chart1.svg\")]"
      assert grid =~ "[#image(\"chart2.svg\")]"
    end
  end

  describe "build_flow/2" do
    test "builds flow with default spacing" do
      charts = ["#image(...)", "#image(...)"]
      {:ok, flow} = TypstFormatter.build_flow(charts)

      assert flow =~ "#image(...)"
      assert flow =~ "#v(20pt)"
    end

    test "builds flow with custom spacing" do
      charts = ["#image(...)", "#image(...)"]
      {:ok, flow} = TypstFormatter.build_flow(charts, "30pt")

      assert flow =~ "#v(30pt)"
    end

    test "intersperses charts with spacing" do
      charts = ["chart1", "chart2", "chart3"]
      {:ok, flow} = TypstFormatter.build_flow(charts, "15pt")

      assert flow == "chart1\n#v(15pt)\nchart2\n#v(15pt)\nchart3"
    end

    test "handles single chart without spacing" do
      charts = ["#image(...)"]
      {:ok, flow} = TypstFormatter.build_flow(charts)

      assert flow == "#image(...)"
      refute flow =~ "#v("
    end

    test "handles empty chart list" do
      {:ok, flow} = TypstFormatter.build_flow([])

      assert flow == ""
    end
  end
end
