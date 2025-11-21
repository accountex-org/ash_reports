defmodule AshReports.Layout.PositioningTest do
  @moduledoc """
  Tests for the cell positioning engine.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.{Positioning, IR}

  describe "position_cells/2 - automatic flow positioning" do
    test "positions cells in row-major order" do
      cells = [
        %{content: "A"},
        %{content: "B"},
        %{content: "C"},
        %{content: "D"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)
      assert length(positioned) == 4

      # Check positions
      assert Enum.at(positioned, 0).position == {0, 0}
      assert Enum.at(positioned, 1).position == {1, 0}
      assert Enum.at(positioned, 2).position == {2, 0}
      assert Enum.at(positioned, 3).position == {0, 1}
    end

    test "positions cells in single column" do
      cells = [
        %{content: "A"},
        %{content: "B"},
        %{content: "C"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 1)

      assert Enum.at(positioned, 0).position == {0, 0}
      assert Enum.at(positioned, 1).position == {0, 1}
      assert Enum.at(positioned, 2).position == {0, 2}
    end

    test "positions empty cell list" do
      assert {:ok, []} = Positioning.position_cells([], columns: 3)
    end

    test "positions single cell" do
      cells = [%{content: "A"}]
      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)
      assert length(positioned) == 1
      assert hd(positioned).position == {0, 0}
    end

    test "fills complete rows" do
      cells = for i <- 1..6, do: %{content: "#{i}"}

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      # First row
      assert Enum.at(positioned, 0).position == {0, 0}
      assert Enum.at(positioned, 1).position == {1, 0}
      assert Enum.at(positioned, 2).position == {2, 0}
      # Second row
      assert Enum.at(positioned, 3).position == {0, 1}
      assert Enum.at(positioned, 4).position == {1, 1}
      assert Enum.at(positioned, 5).position == {2, 1}
    end
  end

  describe "position_cells/2 - explicit positioning" do
    test "places explicit cell at specified position" do
      cells = [
        %{x: 1, y: 0, content: "B"},
        %{content: "A"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      # Find cells by content
      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))

      assert cell_b.position == {1, 0}
      assert cell_a.position == {0, 0}
    end

    test "flows around explicit cells" do
      cells = [
        %{x: 1, y: 0, content: "Explicit"},
        %{content: "A"},
        %{content: "B"},
        %{content: "C"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      explicit = Enum.find(positioned, &(&1.content == "Explicit"))
      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))

      assert explicit.position == {1, 0}
      assert cell_a.position == {0, 0}
      assert cell_b.position == {2, 0}
      assert cell_c.position == {0, 1}
    end

    test "detects position conflicts" do
      cells = [
        %{x: 1, y: 0, content: "A"},
        %{x: 1, y: 0, content: "B"}
      ]

      assert {:error, {:position_conflict, {1, 0}, _}} = Positioning.position_cells(cells, columns: 3)
    end

    test "explicit cell at row 0 col 0 treated as flow" do
      # Cells with x=0, y=0 are treated as flow cells
      cells = [
        %{x: 0, y: 0, content: "A"},
        %{content: "B"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))

      assert cell_a.position == {0, 0}
      assert cell_b.position == {1, 0}
    end
  end

  describe "position_cells/2 - colspan" do
    test "respects colspan when flowing" do
      cells = [
        %{colspan: 2, content: "Wide"},
        %{content: "B"},
        %{content: "C"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      wide = Enum.find(positioned, &(&1.content == "Wide"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))

      assert wide.position == {0, 0}
      assert cell_b.position == {2, 0}
      assert cell_c.position == {0, 1}
    end

    test "wraps colspan to next row if doesn't fit" do
      cells = [
        %{content: "A"},
        %{colspan: 2, content: "Wide"},
        %{content: "C"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 2)

      cell_a = Enum.find(positioned, &(&1.content == "A"))
      wide = Enum.find(positioned, &(&1.content == "Wide"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))

      assert cell_a.position == {0, 0}
      # Wide doesn't fit at (1,0), wraps to (0,1)
      assert wide.position == {0, 1}
      assert cell_c.position == {0, 2}
    end

    test "validates colspan doesn't exceed grid" do
      cells = [
        %{x: 2, y: 0, colspan: 2, content: "Too Wide"}
      ]

      assert {:error, {:span_overflow, _, _, _}} = Positioning.position_cells(cells, columns: 3)
    end
  end

  describe "position_cells/2 - rowspan" do
    test "marks positions occupied by rowspan" do
      cells = [
        %{rowspan: 2, content: "Tall"},
        %{content: "B"},
        %{content: "C"},
        %{content: "D"},
        %{content: "E"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      tall = Enum.find(positioned, &(&1.content == "Tall"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))
      cell_d = Enum.find(positioned, &(&1.content == "D"))
      cell_e = Enum.find(positioned, &(&1.content == "E"))

      assert tall.position == {0, 0}
      assert cell_b.position == {1, 0}
      assert cell_c.position == {2, 0}
      # Row 1: position (0,1) is occupied by tall's rowspan
      assert cell_d.position == {1, 1}
      assert cell_e.position == {2, 1}
    end

    test "handles multiple rowspans" do
      cells = [
        %{rowspan: 2, content: "A"},
        %{rowspan: 2, content: "B"},
        %{content: "C"},
        %{content: "D"},
        %{content: "E"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))
      cell_d = Enum.find(positioned, &(&1.content == "D"))
      cell_e = Enum.find(positioned, &(&1.content == "E"))

      assert cell_a.position == {0, 0}
      assert cell_b.position == {1, 0}
      assert cell_c.position == {2, 0}
      # Row 1: (0,1) and (1,1) occupied
      assert cell_d.position == {2, 1}
      # Row 2
      assert cell_e.position == {0, 2}
    end
  end

  describe "position_cells/2 - combined colspan and rowspan" do
    test "handles cell spanning multiple rows and columns" do
      cells = [
        %{colspan: 2, rowspan: 2, content: "Big"},
        %{content: "A"},
        %{content: "B"},
        %{content: "C"},
        %{content: "D"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      big = Enum.find(positioned, &(&1.content == "Big"))
      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))
      cell_d = Enum.find(positioned, &(&1.content == "D"))

      # Big occupies (0,0), (1,0), (0,1), (1,1)
      assert big.position == {0, 0}
      assert cell_a.position == {2, 0}
      assert cell_b.position == {2, 1}
      assert cell_c.position == {0, 2}
      assert cell_d.position == {1, 2}
    end
  end

  describe "position_cells/2 - with IR.Cell structs" do
    test "positions IR.Cell structs" do
      cells = [
        %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["A"]},
        %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["B"]},
        %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["C"]}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      assert Enum.at(positioned, 0).position == {0, 0}
      assert Enum.at(positioned, 1).position == {1, 0}
      assert Enum.at(positioned, 2).position == {2, 0}
    end

    test "respects IR.Cell span" do
      cells = [
        %IR.Cell{position: {0, 0}, span: {2, 1}, content: ["Wide"]},
        %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["B"]}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      assert Enum.at(positioned, 0).position == {0, 0}
      assert Enum.at(positioned, 1).position == {2, 0}
    end
  end

  describe "position_rows/2" do
    test "positions cells within rows" do
      rows = [
        %{elements: [%{content: "A"}, %{content: "B"}]},
        %{elements: [%{content: "C"}, %{content: "D"}]}
      ]

      assert {:ok, positioned_rows} = Positioning.position_rows(rows, columns: 3)

      # First row
      row_0 = Enum.at(positioned_rows, 0)
      cells_0 = row_0.elements
      assert Enum.at(cells_0, 0).position == {0, 0}
      assert Enum.at(cells_0, 1).position == {1, 0}

      # Second row
      row_1 = Enum.at(positioned_rows, 1)
      cells_1 = row_1.elements
      assert Enum.at(cells_1, 0).position == {0, 1}
      assert Enum.at(cells_1, 1).position == {1, 1}
    end

    test "handles rowspan across rows" do
      rows = [
        %{elements: [%{rowspan: 2, content: "Tall"}, %{content: "B"}]},
        %{elements: [%{content: "C"}]}
      ]

      assert {:ok, positioned_rows} = Positioning.position_rows(rows, columns: 2)

      # First row
      row_0 = Enum.at(positioned_rows, 0)
      cells_0 = row_0.elements
      tall = Enum.at(cells_0, 0)
      cell_b = Enum.at(cells_0, 1)
      assert tall.position == {0, 0}
      assert cell_b.position == {1, 0}

      # Second row - position (0,1) is occupied by Tall's rowspan
      row_1 = Enum.at(positioned_rows, 1)
      cells_1 = row_1.elements
      cell_c = Enum.at(cells_1, 0)
      assert cell_c.position == {1, 1}
    end

    test "positions IR.Row structs" do
      rows = [
        %IR.Row{index: 0, cells: [
          %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["A"]},
          %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["B"]}
        ]},
        %IR.Row{index: 1, cells: [
          %IR.Cell{position: {0, 0}, span: {1, 1}, content: ["C"]}
        ]}
      ]

      assert {:ok, positioned_rows} = Positioning.position_rows(rows, columns: 3)

      row_0 = Enum.at(positioned_rows, 0)
      assert Enum.at(row_0.cells, 0).position == {0, 0}
      assert Enum.at(row_0.cells, 1).position == {1, 0}

      row_1 = Enum.at(positioned_rows, 1)
      assert Enum.at(row_1.cells, 0).position == {0, 1}
    end

    test "handles empty rows" do
      rows = [
        %{elements: []},
        %{elements: [%{content: "A"}]}
      ]

      assert {:ok, positioned_rows} = Positioning.position_rows(rows, columns: 3)

      row_0 = Enum.at(positioned_rows, 0)
      assert row_0.elements == []

      row_1 = Enum.at(positioned_rows, 1)
      assert Enum.at(row_1.elements, 0).position == {0, 1}
    end
  end

  describe "calculate_occupied_positions/2" do
    test "calculates single position for 1x1 span" do
      positions = Positioning.calculate_occupied_positions({0, 0}, {1, 1})
      assert positions == [{0, 0}]
    end

    test "calculates horizontal positions for colspan" do
      positions = Positioning.calculate_occupied_positions({0, 0}, {3, 1})
      assert positions == [{0, 0}, {1, 0}, {2, 0}]
    end

    test "calculates vertical positions for rowspan" do
      positions = Positioning.calculate_occupied_positions({0, 0}, {1, 3})
      assert positions == [{0, 0}, {0, 1}, {0, 2}]
    end

    test "calculates 2D grid for colspan + rowspan" do
      positions = Positioning.calculate_occupied_positions({1, 1}, {2, 2})
      assert Enum.sort(positions) == [{1, 1}, {1, 2}, {2, 1}, {2, 2}]
    end

    test "handles non-zero starting position" do
      positions = Positioning.calculate_occupied_positions({2, 3}, {2, 2})
      assert Enum.sort(positions) == [{2, 3}, {2, 4}, {3, 3}, {3, 4}]
    end
  end

  describe "validate_span/3" do
    test "validates span that fits" do
      assert :ok = Positioning.validate_span({0, 0}, {2, 1}, 3)
      assert :ok = Positioning.validate_span({1, 0}, {2, 1}, 3)
    end

    test "returns error for span overflow" do
      assert {:error, {:span_overflow, _, _, _}} = Positioning.validate_span({2, 0}, {2, 1}, 3)
      assert {:error, {:span_overflow, _, _, _}} = Positioning.validate_span({0, 0}, {4, 1}, 3)
    end

    test "validates single column span at edge" do
      assert :ok = Positioning.validate_span({2, 0}, {1, 1}, 3)
    end
  end

  describe "complex scenarios" do
    test "mixed explicit and flow with spans" do
      cells = [
        %{x: 2, y: 0, content: "Explicit"},
        %{colspan: 2, content: "Wide"},
        %{content: "A"},
        %{content: "B"},
        %{content: "C"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      explicit = Enum.find(positioned, &(&1.content == "Explicit"))
      wide = Enum.find(positioned, &(&1.content == "Wide"))
      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      cell_c = Enum.find(positioned, &(&1.content == "C"))

      # Explicit at (2,0)
      assert explicit.position == {2, 0}
      # Wide (2 cols) at (0,0)
      assert wide.position == {0, 0}
      # A flows to (0,1)
      assert cell_a.position == {0, 1}
      assert cell_b.position == {1, 1}
      assert cell_c.position == {2, 1}
    end

    test "large grid with multiple spans" do
      cells = [
        %{colspan: 2, rowspan: 2, content: "TopLeft"},
        %{content: "A"},
        %{content: "B"},
        %{rowspan: 3, content: "RightTall"},
        %{content: "C"},
        %{content: "D"},
        %{content: "E"},
        %{content: "F"}
      ]

      assert {:ok, positioned} = Positioning.position_cells(cells, columns: 4)

      top_left = Enum.find(positioned, &(&1.content == "TopLeft"))
      cell_a = Enum.find(positioned, &(&1.content == "A"))
      cell_b = Enum.find(positioned, &(&1.content == "B"))
      right_tall = Enum.find(positioned, &(&1.content == "RightTall"))

      # TopLeft at (0,0) spanning 2x2
      assert top_left.position == {0, 0}
      # A at (2,0)
      assert cell_a.position == {2, 0}
      # B at (3,0)
      assert cell_b.position == {3, 0}
      # RightTall at (2,1) spanning 1x3
      assert right_tall.position == {2, 1}
    end
  end
end
