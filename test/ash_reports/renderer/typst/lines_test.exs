defmodule AshReports.Renderer.Typst.LinesTest do
  @moduledoc """
  Tests for the Typst Lines renderer.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR.Line
  alias AshReports.Renderer.Typst.Lines

  describe "render/2 - horizontal lines" do
    test "renders simple hline at row position" do
      line = Line.hline(2)
      result = Lines.render(line)

      assert result == "grid.hline(y: 2)"
    end

    test "renders hline at row 0" do
      line = Line.hline(0)
      result = Lines.render(line)

      assert result == "grid.hline(y: 0)"
    end

    test "renders hline with stroke" do
      line = Line.hline(1, stroke: "2pt")
      result = Lines.render(line)

      assert result == "grid.hline(y: 1, stroke: 2pt)"
    end

    test "renders hline with start position" do
      line = Line.hline(1, start: 1)
      result = Lines.render(line)

      assert result == "grid.hline(y: 1, start: 1)"
    end

    test "renders hline with end position" do
      line = Line.hline(1, end: 3)
      result = Lines.render(line)

      assert result == "grid.hline(y: 1, end: 3)"
    end

    test "renders hline with start and end (partial line)" do
      line = Line.hline(2, start: 1, end: 4)
      result = Lines.render(line)

      assert result == "grid.hline(y: 2, start: 1, end: 4)"
    end

    test "renders hline with all parameters" do
      line = Line.hline(3, start: 0, end: 5, stroke: "1pt + black")
      result = Lines.render(line)

      assert result == "grid.hline(y: 3, start: 0, end: 5, stroke: 1pt + black)"
    end

    test "renders hline in table context" do
      line = Line.hline(1)
      result = Lines.render(line, context: :table)

      assert result == "table.hline(y: 1)"
    end

    test "renders hline with indentation" do
      line = Line.hline(1)
      result = Lines.render(line, indent: 2)

      assert result == "    grid.hline(y: 1)"
    end
  end

  describe "render/2 - vertical lines" do
    test "renders simple vline at column position" do
      line = Line.vline(2)
      result = Lines.render(line)

      assert result == "grid.vline(x: 2)"
    end

    test "renders vline at column 0" do
      line = Line.vline(0)
      result = Lines.render(line)

      assert result == "grid.vline(x: 0)"
    end

    test "renders vline with stroke" do
      line = Line.vline(1, stroke: "2pt")
      result = Lines.render(line)

      assert result == "grid.vline(x: 1, stroke: 2pt)"
    end

    test "renders vline with start position" do
      line = Line.vline(1, start: 1)
      result = Lines.render(line)

      assert result == "grid.vline(x: 1, start: 1)"
    end

    test "renders vline with end position" do
      line = Line.vline(1, end: 3)
      result = Lines.render(line)

      assert result == "grid.vline(x: 1, end: 3)"
    end

    test "renders vline with start and end (partial line)" do
      line = Line.vline(2, start: 0, end: 4)
      result = Lines.render(line)

      assert result == "grid.vline(x: 2, start: 0, end: 4)"
    end

    test "renders vline with all parameters" do
      line = Line.vline(3, start: 1, end: 5, stroke: "1pt + red")
      result = Lines.render(line)

      assert result == "grid.vline(x: 3, start: 1, end: 5, stroke: 1pt + red)"
    end

    test "renders vline in table context" do
      line = Line.vline(1)
      result = Lines.render(line, context: :table)

      assert result == "table.vline(x: 1)"
    end

    test "renders vline with indentation" do
      line = Line.vline(1)
      result = Lines.render(line, indent: 2)

      assert result == "    grid.vline(x: 1)"
    end
  end

  describe "render/2 - stroke values" do
    test "renders simple string stroke" do
      line = Line.hline(1, stroke: "1pt")
      result = Lines.render(line)

      assert result =~ "stroke: 1pt"
    end

    test "renders atom stroke" do
      line = Line.hline(1, stroke: :none)
      result = Lines.render(line)

      assert result =~ "stroke: none"
    end

    test "renders width + color stroke" do
      line = Line.hline(1, stroke: "2pt + black")
      result = Lines.render(line)

      assert result =~ "stroke: 2pt + black"
    end

    test "renders map-based stroke" do
      line = Line.hline(1, stroke: %{thickness: "2pt", paint: "red"})
      result = Lines.render(line)

      assert result =~ "stroke: 2pt + red"
    end

    test "renders map-based stroke with dash" do
      line = Line.hline(1, stroke: %{thickness: "1pt", paint: "black", dash: "dashed"})
      result = Lines.render(line)

      assert result =~ "stroke: (thickness: 1pt, paint: black, dash: \"dashed\")"
    end
  end

  describe "render_hline/2" do
    test "renders horizontal line" do
      line = Line.hline(1, stroke: "1pt")
      result = Lines.render_hline(line)

      assert result == "grid.hline(y: 1, stroke: 1pt)"
    end
  end

  describe "render_vline/2" do
    test "renders vertical line" do
      line = Line.vline(1, stroke: "1pt")
      result = Lines.render_vline(line)

      assert result == "grid.vline(x: 1, stroke: 1pt)"
    end
  end

  describe "build_line_parameters/1" do
    test "builds parameters for hline" do
      line = Line.hline(2, start: 1, end: 4, stroke: "2pt")
      result = Lines.build_line_parameters(line)

      assert result == "y: 2, start: 1, end: 4, stroke: 2pt"
    end

    test "builds parameters for vline" do
      line = Line.vline(3, start: 0, end: 5, stroke: "1pt")
      result = Lines.build_line_parameters(line)

      assert result == "x: 3, start: 0, end: 5, stroke: 1pt"
    end

    test "builds minimal parameters" do
      line = Line.hline(1)
      result = Lines.build_line_parameters(line)

      assert result == "y: 1"
    end
  end

  describe "integration tests" do
    test "renders multiple lines for a grid" do
      lines = [
        Line.hline(0, stroke: "2pt"),
        Line.hline(1),
        Line.vline(0, stroke: "2pt"),
        Line.vline(3, stroke: "2pt")
      ]

      results = Enum.map(lines, &Lines.render/1)

      assert Enum.at(results, 0) == "grid.hline(y: 0, stroke: 2pt)"
      assert Enum.at(results, 1) == "grid.hline(y: 1)"
      assert Enum.at(results, 2) == "grid.vline(x: 0, stroke: 2pt)"
      assert Enum.at(results, 3) == "grid.vline(x: 3, stroke: 2pt)"
    end

    test "renders lines for table with proper context" do
      lines = [
        Line.hline(0),
        Line.vline(1)
      ]

      results = Enum.map(lines, &Lines.render(&1, context: :table))

      assert Enum.at(results, 0) == "table.hline(y: 0)"
      assert Enum.at(results, 1) == "table.vline(x: 1)"
    end
  end
end
