defmodule AshReports.Renderer.Typst.GridTest do
  @moduledoc """
  Tests for the Typst Grid renderer.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Typst.Grid

  describe "render/2" do
    test "renders empty grid" do
      ir = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      result = Grid.render(ir)

      assert result =~ "#grid("
      assert result =~ "columns: (1fr, 1fr)"
    end

    test "renders grid with all column formats" do
      ir = IR.grid(properties: %{columns: ["100pt", "1fr", "auto", "2cm"]})
      result = Grid.render(ir)

      assert result =~ "columns: (100pt, 1fr, auto, 2cm)"
    end

    test "renders grid with integer columns" do
      ir = IR.grid(properties: %{columns: 3})
      result = Grid.render(ir)

      assert result =~ "columns: 3"
    end

    test "renders grid with rows" do
      ir = IR.grid(properties: %{columns: ["1fr"], rows: ["auto", "100pt"]})
      result = Grid.render(ir)

      assert result =~ "columns: (1fr)"
      assert result =~ "rows: (auto, 100pt)"
    end

    test "renders grid with gutter" do
      ir = IR.grid(properties: %{columns: ["1fr"], gutter: "10pt"})
      result = Grid.render(ir)

      assert result =~ "gutter: 10pt"
    end

    test "renders grid with column-gutter and row-gutter" do
      ir = IR.grid(properties: %{
        columns: ["1fr"],
        column_gutter: "5pt",
        row_gutter: "10pt"
      })
      result = Grid.render(ir)

      assert result =~ "column-gutter: 5pt"
      assert result =~ "row-gutter: 10pt"
    end

    test "renders grid with align" do
      ir = IR.grid(properties: %{columns: ["1fr"], align: :center})
      result = Grid.render(ir)

      assert result =~ "align: center"
    end

    test "renders grid with combined alignment" do
      ir = IR.grid(properties: %{columns: ["1fr"], align: {:left, :top}})
      result = Grid.render(ir)

      assert result =~ "align: left + top"
    end

    test "renders grid with inset" do
      ir = IR.grid(properties: %{columns: ["1fr"], inset: "5pt"})
      result = Grid.render(ir)

      assert result =~ "inset: 5pt"
    end

    test "renders grid with fill color" do
      ir = IR.grid(properties: %{columns: ["1fr"], fill: "red"})
      result = Grid.render(ir)

      assert result =~ "fill: red"
    end

    test "renders grid with hex fill color" do
      ir = IR.grid(properties: %{columns: ["1fr"], fill: "#ff0000"})
      result = Grid.render(ir)

      assert result =~ "fill: rgb(\"#ff0000\")"
    end

    test "renders grid with fill none" do
      ir = IR.grid(properties: %{columns: ["1fr"], fill: :none})
      result = Grid.render(ir)

      assert result =~ "fill: none"
    end

    test "renders grid with stroke" do
      ir = IR.grid(properties: %{columns: ["1fr"], stroke: "1pt"})
      result = Grid.render(ir)

      assert result =~ "stroke: 1pt"
    end

    test "renders grid with stroke none" do
      ir = IR.grid(properties: %{columns: ["1fr"], stroke: :none})
      result = Grid.render(ir)

      assert result =~ "stroke: none"
    end

    test "renders grid with cells" do
      cell1 = IR.Cell.new(content: [%{text: "A"}])
      cell2 = IR.Cell.new(content: [%{text: "B"}])
      ir = IR.grid(properties: %{columns: ["1fr", "1fr"]}, children: [cell1, cell2])
      result = Grid.render(ir)

      assert result =~ "[A]"
      assert result =~ "[B]"
    end

    test "renders grid with all parameters" do
      ir = IR.grid(properties: %{
        columns: ["1fr", "2fr"],
        rows: ["auto"],
        gutter: "10pt",
        align: :center,
        inset: "5pt",
        fill: "lightgray",
        stroke: "1pt"
      })
      result = Grid.render(ir)

      assert result =~ "columns: (1fr, 2fr)"
      assert result =~ "rows: (auto)"
      assert result =~ "gutter: 10pt"
      assert result =~ "align: center"
      assert result =~ "inset: 5pt"
      assert result =~ "fill: lightgray"
      assert result =~ "stroke: 1pt"
    end
  end

  describe "render_columns/1" do
    test "renders list of track sizes" do
      result = Grid.render_columns(["1fr", "2fr", "auto"])
      assert result == "columns: (1fr, 2fr, auto)"
    end

    test "renders integer column count" do
      result = Grid.render_columns(3)
      assert result == "columns: 3"
    end
  end

  describe "render_rows/1" do
    test "renders list of track sizes" do
      result = Grid.render_rows(["auto", "100pt"])
      assert result == "rows: (auto, 100pt)"
    end
  end

  describe "render_track_size/1" do
    test "renders auto" do
      assert Grid.render_track_size(:auto) == "auto"
      assert Grid.render_track_size("auto") == "auto"
    end

    test "renders string sizes" do
      assert Grid.render_track_size("1fr") == "1fr"
      assert Grid.render_track_size("100pt") == "100pt"
      assert Grid.render_track_size("2cm") == "2cm"
    end

    test "renders numeric sizes with pt default" do
      assert Grid.render_track_size(100) == "100pt"
      assert Grid.render_track_size(50.5) == "50.5pt"
    end
  end

  describe "render_alignment/1" do
    test "renders atom alignments" do
      assert Grid.render_alignment(:left) == "left"
      assert Grid.render_alignment(:center) == "center"
      assert Grid.render_alignment(:right) == "right"
      assert Grid.render_alignment(:top) == "top"
      assert Grid.render_alignment(:bottom) == "bottom"
    end

    test "renders combined alignments" do
      assert Grid.render_alignment({:left, :top}) == "left + top"
      assert Grid.render_alignment({:center, :horizon}) == "center + horizon"
    end

    test "renders string alignments" do
      assert Grid.render_alignment("center") == "center"
    end
  end

  describe "render_fill/1" do
    test "renders none" do
      assert Grid.render_fill(:none) == "none"
      assert Grid.render_fill(nil) == "none"
    end

    test "renders color names" do
      assert Grid.render_fill("red") == "red"
      assert Grid.render_fill("blue") == "blue"
    end

    test "renders hex colors as rgb()" do
      assert Grid.render_fill("#ff0000") == "rgb(\"#ff0000\")"
      assert Grid.render_fill("#fff") == "rgb(\"#fff\")"
    end

    test "renders atom colors" do
      assert Grid.render_fill(:red) == "red"
    end
  end

  describe "render_stroke/1" do
    test "renders none" do
      assert Grid.render_stroke(:none) == "none"
      assert Grid.render_stroke(nil) == "none"
    end

    test "renders stroke values" do
      assert Grid.render_stroke("1pt") == "1pt"
      assert Grid.render_stroke("2pt") == "2pt"
    end
  end
end
