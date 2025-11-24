defmodule AshReports.Renderer.Html.GridTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Grid
  alias AshReports.Layout.IR

  describe "render/2" do
    test "renders empty grid with CSS Grid display" do
      ir = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      result = Grid.render(ir)

      assert String.contains?(result, ~s(class="ash-grid"))
      assert String.contains?(result, "display: grid")
      assert String.contains?(result, "grid-template-columns: 1fr 1fr")
    end

    test "renders grid with multiple columns" do
      ir = IR.grid(properties: %{columns: ["100px", "1fr", "auto"]})
      result = Grid.render(ir)

      assert String.contains?(result, "grid-template-columns: 100px 1fr auto")
    end

    test "renders grid with integer column count" do
      ir = IR.grid(properties: %{columns: 3})
      result = Grid.render(ir)

      assert String.contains?(result, "grid-template-columns: repeat(3, 1fr)")
    end

    test "renders grid with explicit rows" do
      ir = IR.grid(properties: %{
        columns: ["1fr", "1fr"],
        rows: ["auto", "100px"]
      })
      result = Grid.render(ir)

      assert String.contains?(result, "grid-template-columns: 1fr 1fr")
      assert String.contains?(result, "grid-template-rows: auto 100px")
    end

    test "renders grid with gutter as gap" do
      ir = IR.grid(properties: %{
        columns: ["1fr", "1fr"],
        gutter: "10pt"
      })
      result = Grid.render(ir)

      assert String.contains?(result, "gap: 10px")
    end

    test "renders grid with column-gap and row-gap" do
      ir = IR.grid(properties: %{
        columns: ["1fr", "1fr"],
        column_gutter: "20pt",
        row_gutter: "10pt"
      })
      result = Grid.render(ir)

      assert String.contains?(result, "column-gap: 20px")
      assert String.contains?(result, "row-gap: 10px")
    end

    test "renders grid with alignment" do
      ir = IR.grid(properties: %{
        columns: ["1fr", "1fr"],
        align: :center
      })
      result = Grid.render(ir)

      assert String.contains?(result, "justify-items: center")
    end

    test "renders grid with combined alignment" do
      ir = IR.grid(properties: %{
        columns: ["1fr", "1fr"],
        align: {:right, :top}
      })
      result = Grid.render(ir)

      assert String.contains?(result, "justify-items: end")
      assert String.contains?(result, "align-items: start")
    end

    test "renders grid with fill as background-color" do
      ir = IR.grid(properties: %{
        columns: ["1fr"],
        fill: "#f0f0f0"
      })
      result = Grid.render(ir)

      assert String.contains?(result, "background-color: #f0f0f0")
    end

    test "renders empty grid without children" do
      ir = IR.grid(properties: %{columns: ["1fr"]})
      result = Grid.render(ir)

      assert result =~ ~r/<div class="ash-grid"[^>]*><\/div>/
    end
  end

  describe "build_styles/1" do
    test "builds style string with multiple properties" do
      properties = %{
        columns: ["1fr", "2fr"],
        gutter: "10px",
        align: :center
      }
      styles = Grid.build_styles(properties)

      assert String.contains?(styles, "display: grid")
      assert String.contains?(styles, "grid-template-columns: 1fr 2fr")
      assert String.contains?(styles, "gap: 10px")
    end

    test "returns display: grid for empty properties" do
      styles = Grid.build_styles(%{})
      assert styles == "display: grid"
    end
  end

  describe "render_columns/1" do
    test "renders list of track sizes" do
      result = Grid.render_columns(["1fr", "2fr", "auto"])
      assert result == "grid-template-columns: 1fr 2fr auto"
    end

    test "renders integer as repeat" do
      result = Grid.render_columns(3)
      assert result == "grid-template-columns: repeat(3, 1fr)"
    end
  end

  describe "render_rows/1" do
    test "renders list of track sizes" do
      result = Grid.render_rows(["auto", "100px", "1fr"])
      assert result == "grid-template-rows: auto 100px 1fr"
    end

    test "renders integer as repeat with auto" do
      result = Grid.render_rows(4)
      assert result == "grid-template-rows: repeat(4, auto)"
    end
  end

  describe "render_track_size/1" do
    test "renders :auto atom" do
      assert Grid.render_track_size(:auto) == "auto"
    end

    test "renders \"auto\" string" do
      assert Grid.render_track_size("auto") == "auto"
    end

    test "renders fractional unit tuple" do
      assert Grid.render_track_size({:fr, 2}) == "2fr"
    end

    test "renders string values directly" do
      assert Grid.render_track_size("100px") == "100px"
      assert Grid.render_track_size("1fr") == "1fr"
      assert Grid.render_track_size("50%") == "50%"
    end

    test "renders numbers as pixels" do
      assert Grid.render_track_size(100) == "100px"
      assert Grid.render_track_size(50.5) == "50.5px"
    end
  end

  describe "render_length/1" do
    test "renders :auto" do
      assert Grid.render_length(:auto) == "auto"
    end

    test "converts pt to px" do
      assert Grid.render_length("10pt") == "10px"
      assert Grid.render_length("15pt") == "15px"
    end

    test "passes through other units" do
      assert Grid.render_length("20px") == "20px"
      assert Grid.render_length("50%") == "50%"
      assert Grid.render_length("2em") == "2em"
    end

    test "renders numbers as pixels" do
      assert Grid.render_length(10) == "10px"
    end
  end

  describe "render_color/1" do
    test "renders :none as transparent" do
      assert Grid.render_color(:none) == "transparent"
    end

    test "renders nil as transparent" do
      assert Grid.render_color(nil) == "transparent"
    end

    test "renders hex colors directly" do
      assert Grid.render_color("#ff0000") == "#ff0000"
    end

    test "renders named colors" do
      assert Grid.render_color(:red) == "red"
      assert Grid.render_color("blue") == "blue"
    end
  end
end
