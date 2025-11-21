defmodule AshReports.Renderer.Typst.PropertyRenderingTest do
  @moduledoc """
  Tests for Typst property rendering functions (Section 3.3).

  These tests cover track sizes, alignment, colors, fills, and strokes.
  """

  use ExUnit.Case, async: true

  alias AshReports.Renderer.Typst.Grid

  describe "render_track_size/1" do
    test "renders :auto as auto" do
      assert Grid.render_track_size(:auto) == "auto"
    end

    test "renders string auto as auto" do
      assert Grid.render_track_size("auto") == "auto"
    end

    test "renders {:fr, n} tuple as nfr" do
      assert Grid.render_track_size({:fr, 1}) == "1fr"
      assert Grid.render_track_size({:fr, 2}) == "2fr"
      assert Grid.render_track_size({:fr, 0.5}) == "0.5fr"
    end

    test "renders string fr values directly" do
      assert Grid.render_track_size("1fr") == "1fr"
      assert Grid.render_track_size("2.5fr") == "2.5fr"
    end

    test "renders length strings directly" do
      assert Grid.render_track_size("100pt") == "100pt"
      assert Grid.render_track_size("2cm") == "2cm"
      assert Grid.render_track_size("25mm") == "25mm"
      assert Grid.render_track_size("1in") == "1in"
      assert Grid.render_track_size("50%") == "50%"
    end

    test "renders numeric values with pt default" do
      assert Grid.render_track_size(100) == "100pt"
      assert Grid.render_track_size(50.5) == "50.5pt"
    end
  end

  describe "render_columns/1" do
    test "renders list of track sizes as array" do
      assert Grid.render_columns(["1fr", "2fr", "auto"]) == "columns: (1fr, 2fr, auto)"
    end

    test "renders mixed track sizes" do
      assert Grid.render_columns(["100pt", {:fr, 1}, :auto, "2cm"]) ==
               "columns: (100pt, 1fr, auto, 2cm)"
    end

    test "renders integer as column count" do
      assert Grid.render_columns(3) == "columns: 3"
    end
  end

  describe "render_rows/1" do
    test "renders list of track sizes as array" do
      assert Grid.render_rows(["auto", "100pt"]) == "rows: (auto, 100pt)"
    end

    test "renders integer as row count" do
      assert Grid.render_rows(5) == "rows: 5"
    end
  end

  describe "render_alignment/1" do
    test "renders :left as left" do
      assert Grid.render_alignment(:left) == "left"
    end

    test "renders :center as center" do
      assert Grid.render_alignment(:center) == "center"
    end

    test "renders :right as right" do
      assert Grid.render_alignment(:right) == "right"
    end

    test "renders :top as top" do
      assert Grid.render_alignment(:top) == "top"
    end

    test "renders :bottom as bottom" do
      assert Grid.render_alignment(:bottom) == "bottom"
    end

    test "renders :horizon as horizon" do
      assert Grid.render_alignment(:horizon) == "horizon"
    end

    test "renders :start as start" do
      assert Grid.render_alignment(:start) == "start"
    end

    test "renders :end as end" do
      assert Grid.render_alignment(:end) == "end"
    end

    test "renders combined {:left, :top} as left + top" do
      assert Grid.render_alignment({:left, :top}) == "left + top"
    end

    test "renders combined {:center, :horizon} as center + horizon" do
      assert Grid.render_alignment({:center, :horizon}) == "center + horizon"
    end

    test "renders combined {:right, :bottom} as right + bottom" do
      assert Grid.render_alignment({:right, :bottom}) == "right + bottom"
    end

    test "renders string alignment directly" do
      assert Grid.render_alignment("center") == "center"
    end
  end

  describe "render_fill/1 - basic colors" do
    test "renders :none as none" do
      assert Grid.render_fill(:none) == "none"
    end

    test "renders nil as none" do
      assert Grid.render_fill(nil) == "none"
    end

    test "renders color name string directly" do
      assert Grid.render_fill("red") == "red"
      assert Grid.render_fill("blue") == "blue"
      assert Grid.render_fill("lightgray") == "lightgray"
    end

    test "renders atom color as string" do
      assert Grid.render_fill(:red) == "red"
      assert Grid.render_fill(:blue) == "blue"
    end

    test "renders hex color as rgb()" do
      assert Grid.render_fill("#ff0000") == "rgb(\"#ff0000\")"
      assert Grid.render_fill("#fff") == "rgb(\"#fff\")"
      assert Grid.render_fill("#00ff00ff") == "rgb(\"#00ff00ff\")"
    end
  end

  describe "render_fill/1 - function fills" do
    test "renders function as placeholder" do
      func = fn _x, _y -> "red" end
      assert Grid.render_fill(func) == "(x, y) => none"
    end

    test "renders map with function body directly" do
      assert Grid.render_fill(%{function: "(x, y) => if calc.odd(y) { gray } else { white }"}) ==
               "(x, y) => if calc.odd(y) { gray } else { white }"
    end

    test "renders alternating colors" do
      result = Grid.render_fill(%{alternating: ["white", "gray"]})
      assert result =~ "(x, y) =>"
      assert result =~ "calc.rem"
    end
  end

  describe "render_stroke/1 - basic strokes" do
    test "renders :none as none" do
      assert Grid.render_stroke(:none) == "none"
    end

    test "renders nil as none" do
      assert Grid.render_stroke(nil) == "none"
    end

    test "renders simple width string" do
      assert Grid.render_stroke("1pt") == "1pt"
      assert Grid.render_stroke("2pt") == "2pt"
      assert Grid.render_stroke("0.5pt") == "0.5pt"
    end

    test "renders atom stroke as string" do
      assert Grid.render_stroke(:thin) == "thin"
    end
  end

  describe "render_stroke/1 - complex strokes" do
    test "renders width + color as combined spec" do
      assert Grid.render_stroke(%{thickness: "1pt", paint: "black"}) == "1pt + black"
      assert Grid.render_stroke(%{thickness: "2pt", paint: "red"}) == "2pt + red"
    end

    test "renders width + hex color" do
      assert Grid.render_stroke(%{thickness: "1pt", paint: "#ff0000"}) ==
               "1pt + rgb(\"#ff0000\")"
    end

    test "renders width + atom color" do
      assert Grid.render_stroke(%{thickness: "1pt", paint: :blue}) == "1pt + blue"
    end

    test "renders full stroke spec with dash" do
      result = Grid.render_stroke(%{thickness: "2pt", paint: "red", dash: "dashed"})
      assert result == "(thickness: 2pt, paint: red, dash: \"dashed\")"
    end

    test "renders full stroke spec with dotted dash" do
      result = Grid.render_stroke(%{thickness: "1pt", paint: "black", dash: "dotted"})
      assert result == "(thickness: 1pt, paint: black, dash: \"dotted\")"
    end

    test "renders thickness only map" do
      assert Grid.render_stroke(%{thickness: "3pt"}) == "3pt"
    end
  end

  describe "render_length/1" do
    test "renders :auto as auto" do
      assert Grid.render_length(:auto) == "auto"
    end

    test "renders string auto as auto" do
      assert Grid.render_length("auto") == "auto"
    end

    test "renders length strings directly" do
      assert Grid.render_length("10pt") == "10pt"
      assert Grid.render_length("2cm") == "2cm"
      assert Grid.render_length("5mm") == "5mm"
    end

    test "renders numeric values with pt default" do
      assert Grid.render_length(100) == "100pt"
      assert Grid.render_length(25.5) == "25.5pt"
    end
  end

  describe "integration - grid with complex properties" do
    alias AshReports.Layout.IR

    test "renders grid with fr tuple columns" do
      ir = IR.grid(properties: %{columns: [{:fr, 1}, {:fr, 2}, :auto]})
      result = Grid.render(ir)

      assert result =~ "columns: (1fr, 2fr, auto)"
    end

    test "renders grid with complex stroke" do
      ir = IR.grid(properties: %{
        columns: ["1fr"],
        stroke: %{thickness: "1pt", paint: "gray", dash: "dashed"}
      })
      result = Grid.render(ir)

      assert result =~ "stroke: (thickness: 1pt, paint: gray, dash: \"dashed\")"
    end

    test "renders grid with width+color stroke" do
      ir = IR.grid(properties: %{
        columns: ["1fr"],
        stroke: %{thickness: "2pt", paint: "black"}
      })
      result = Grid.render(ir)

      assert result =~ "stroke: 2pt + black"
    end
  end
end
