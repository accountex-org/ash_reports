defmodule AshReports.Layout.ErrorsTest do
  @moduledoc """
  Tests for the layout errors module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.Errors

  describe "DSL Validation Error Constructors" do
    test "invalid_property creates error tuple" do
      error = Errors.invalid_property(:align, :diagonal, [:left, :center, :right])
      assert error == {:invalid_property, :align, :diagonal, [:left, :center, :right]}
    end

    test "invalid_nesting creates error tuple" do
      error = Errors.invalid_nesting(:cell, :cell)
      assert error == {:invalid_nesting, :cell, :cell}
    end

    test "missing_required creates error tuple" do
      error = Errors.missing_required(:grid, :columns)
      assert error == {:missing_required, :grid, :columns}
    end
  end

  describe "Positioning Error Constructors" do
    test "position_conflict creates error tuple" do
      error = Errors.position_conflict({2, 1}, :existing_cell)
      assert error == {:position_conflict, {2, 1}, :existing_cell}
    end

    test "span_overflow creates error tuple" do
      error = Errors.span_overflow({2, 0}, {3, 1}, 4)
      assert error == {:span_overflow, {2, 0}, {3, 1}, 4}
    end

    test "invalid_position creates error tuple" do
      error = Errors.invalid_position({5, 0}, {4, 3})
      assert error == {:invalid_position, {5, 0}, {4, 3}}
    end

    test "grid_gap creates error tuple" do
      error = Errors.grid_gap({1, 2})
      assert error == {:grid_gap, {1, 2}}
    end
  end

  describe "Property Validation Error Constructors" do
    test "invalid_track_size creates error tuple" do
      error = Errors.invalid_track_size("abc")
      assert error == {:invalid_track_size, "abc"}
    end

    test "invalid_color creates error tuple" do
      error = Errors.invalid_color("not-a-color")
      assert error == {:invalid_color, "not-a-color"}
    end

    test "invalid_alignment creates error tuple" do
      error = Errors.invalid_alignment(:diagonal)
      assert error == {:invalid_alignment, :diagonal}
    end

    test "invalid_length creates error tuple" do
      error = Errors.invalid_length("10px")
      assert error == {:invalid_length, "10px"}
    end
  end

  describe "format/1 - DSL Validation Errors" do
    test "formats invalid_property with list of expected values" do
      error = {:invalid_property, :align, :diagonal, [:left, :center, :right]}
      message = Errors.format(error)
      assert message =~ "Invalid align"
      assert message =~ ":diagonal"
      assert message =~ "Expected one of"
    end

    test "formats invalid_property with string description" do
      error = {:invalid_property, :columns, -1, "Expected positive integer"}
      message = Errors.format(error)
      assert message =~ "Invalid columns"
      assert message =~ "-1"
      assert message =~ "Expected positive integer"
    end

    test "formats invalid_nesting" do
      error = {:invalid_nesting, :cell, :cell}
      message = Errors.format(error)
      assert message =~ "cell cannot be nested directly inside cell"
    end

    test "formats missing_required" do
      error = {:missing_required, :grid, :columns}
      message = Errors.format(error)
      assert message =~ "columns is required for grid"
    end
  end

  describe "format/1 - Positioning Errors" do
    test "formats position_conflict" do
      error = {:position_conflict, {2, 1}, :existing_cell}
      message = Errors.format(error)
      assert message =~ "Cell at (2, 1) conflicts with existing cell"
    end

    test "formats position_conflict with spanning_cell" do
      error = {:position_conflict, {3, 2}, :spanning_cell}
      message = Errors.format(error)
      assert message =~ "Cell at (3, 2) conflicts with spanning cell"
    end

    test "formats span_overflow" do
      error = {:span_overflow, {2, 0}, {3, 1}, 4}
      message = Errors.format(error)
      assert message =~ "colspan 3 at column 2 exceeds grid width of 4"
    end

    test "formats invalid_position" do
      error = {:invalid_position, {5, 0}, {4, 3}}
      message = Errors.format(error)
      assert message =~ "Position (5, 0) outside grid bounds (4, 3)"
    end

    test "formats grid_gap" do
      error = {:grid_gap, {1, 2}}
      message = Errors.format(error)
      assert message =~ "No cell at position (1, 2)"
    end
  end

  describe "format/1 - Property Validation Errors" do
    test "formats invalid_track_size" do
      error = {:invalid_track_size, "abc"}
      message = Errors.format(error)
      assert message =~ "Invalid track size: 'abc'"
    end

    test "formats invalid_color" do
      error = {:invalid_color, "not-a-color"}
      message = Errors.format(error)
      assert message =~ "Invalid color: 'not-a-color'"
    end

    test "formats invalid_alignment" do
      error = {:invalid_alignment, :diagonal}
      message = Errors.format(error)
      assert message =~ "Invalid alignment: :diagonal"
    end

    test "formats invalid_length" do
      error = {:invalid_length, "10px"}
      message = Errors.format(error)
      assert message =~ "Unknown unit in '10px'"
    end

    test "formats unknown_element_type" do
      error = {:unknown_element_type, %{bad: :data}}
      message = Errors.format(error)
      assert message =~ "Unknown element type"
    end

    test "formats unsupported_layout_type" do
      error = {:unsupported_layout_type, %{type: :unknown}}
      message = Errors.format(error)
      assert message =~ "Unsupported layout type"
    end

    test "formats no_layout_in_band" do
      error = {:no_layout_in_band, %{name: :test}}
      message = Errors.format(error)
      assert message =~ "Band does not contain a layout"
    end

    test "formats unknown errors" do
      error = {:some_unknown_error, "data"}
      message = Errors.format(error)
      assert message =~ "Unknown error"
    end
  end

  describe "format_with_location/3" do
    test "includes file and line in error message" do
      error = {:invalid_property, :align, :diagonal, [:left, :center, :right]}
      message = Errors.format_with_location(error, "lib/my_report.ex", 42)
      assert message =~ "lib/my_report.ex:42:"
      assert message =~ "Invalid align"
    end

    test "handles different error types" do
      error = {:position_conflict, {2, 1}, :existing_cell}
      message = Errors.format_with_location(error, "test/file.ex", 100)
      assert message =~ "test/file.ex:100:"
      assert message =~ "Cell at (2, 1)"
    end
  end

  describe "validate_one_of/3" do
    test "returns :ok for valid value" do
      assert :ok = Errors.validate_one_of(:align, :center, [:left, :center, :right])
    end

    test "returns error for invalid value" do
      result = Errors.validate_one_of(:align, :diagonal, [:left, :center, :right])
      assert {:error, {:invalid_property, :align, :diagonal, _}} = result
    end
  end

  describe "validate_track_size/1" do
    test "accepts auto" do
      assert :ok = Errors.validate_track_size("auto")
      assert :ok = Errors.validate_track_size(:auto)
    end

    test "accepts numeric values" do
      assert :ok = Errors.validate_track_size(100)
      assert :ok = Errors.validate_track_size(50.5)
    end

    test "accepts fr units" do
      assert :ok = Errors.validate_track_size("1fr")
      assert :ok = Errors.validate_track_size("2.5fr")
    end

    test "accepts pt units" do
      assert :ok = Errors.validate_track_size("100pt")
      assert :ok = Errors.validate_track_size("10.5pt")
    end

    test "accepts cm units" do
      assert :ok = Errors.validate_track_size("2cm")
    end

    test "accepts mm units" do
      assert :ok = Errors.validate_track_size("25mm")
    end

    test "accepts in units" do
      assert :ok = Errors.validate_track_size("1in")
    end

    test "accepts percentage" do
      assert :ok = Errors.validate_track_size("50%")
    end

    test "accepts em units" do
      assert :ok = Errors.validate_track_size("1.5em")
    end

    test "rejects invalid formats" do
      assert {:error, {:invalid_track_size, "abc"}} = Errors.validate_track_size("abc")
      assert {:error, {:invalid_track_size, "10px"}} = Errors.validate_track_size("10px")
    end

    test "rejects non-numeric prefix" do
      assert {:error, {:invalid_track_size, "abcfr"}} = Errors.validate_track_size("abcfr")
    end
  end

  describe "validate_color/1" do
    test "accepts atom colors" do
      assert :ok = Errors.validate_color(:red)
      assert :ok = Errors.validate_color(:blue)
    end

    test "accepts named colors" do
      assert :ok = Errors.validate_color("red")
      assert :ok = Errors.validate_color("blue")
      assert :ok = Errors.validate_color("white")
      assert :ok = Errors.validate_color("black")
      assert :ok = Errors.validate_color("transparent")
    end

    test "accepts 3-digit hex colors" do
      assert :ok = Errors.validate_color("#fff")
      assert :ok = Errors.validate_color("#F00")
    end

    test "accepts 6-digit hex colors" do
      assert :ok = Errors.validate_color("#ff0000")
      assert :ok = Errors.validate_color("#00FF00")
    end

    test "accepts 8-digit hex colors (with alpha)" do
      assert :ok = Errors.validate_color("#ff0000ff")
    end

    test "accepts rgb() format" do
      assert :ok = Errors.validate_color("rgb(255, 0, 0)")
      assert :ok = Errors.validate_color("rgba(255, 0, 0, 0.5)")
    end

    test "accepts Typst color functions" do
      assert :ok = Errors.validate_color("luma(50)")
      assert :ok = Errors.validate_color("oklab(0.5, 0.1, 0.1)")
      assert :ok = Errors.validate_color("color.red")
    end

    test "rejects invalid colors" do
      assert {:error, {:invalid_color, "not-a-color"}} = Errors.validate_color("not-a-color")
      assert {:error, {:invalid_color, "123"}} = Errors.validate_color("123")
    end
  end

  describe "validate_alignment/1" do
    test "accepts horizontal alignments as atoms" do
      assert :ok = Errors.validate_alignment(:left)
      assert :ok = Errors.validate_alignment(:center)
      assert :ok = Errors.validate_alignment(:right)
    end

    test "accepts vertical alignments as atoms" do
      assert :ok = Errors.validate_alignment(:top)
      assert :ok = Errors.validate_alignment(:horizon)
      assert :ok = Errors.validate_alignment(:bottom)
    end

    test "accepts start/end alignments" do
      assert :ok = Errors.validate_alignment(:start)
      assert :ok = Errors.validate_alignment(:end)
    end

    test "accepts single string alignments" do
      assert :ok = Errors.validate_alignment("left")
      assert :ok = Errors.validate_alignment("center")
      assert :ok = Errors.validate_alignment("top")
    end

    test "accepts combined alignments" do
      assert :ok = Errors.validate_alignment("left+top")
      assert :ok = Errors.validate_alignment("center+horizon")
      assert :ok = Errors.validate_alignment("right+bottom")
    end

    test "rejects invalid alignments" do
      assert {:error, {:invalid_alignment, :diagonal}} = Errors.validate_alignment(:diagonal)
      assert {:error, {:invalid_alignment, "invalid"}} = Errors.validate_alignment("invalid")
      assert {:error, {:invalid_alignment, "left+middle"}} = Errors.validate_alignment("left+middle")
    end

    test "rejects more than two combined parts" do
      assert {:error, {:invalid_alignment, "left+top+center"}} =
               Errors.validate_alignment("left+top+center")
    end
  end

  describe "validate_length/1" do
    test "accepts auto" do
      assert :ok = Errors.validate_length("auto")
      assert :ok = Errors.validate_length(:auto)
    end

    test "accepts numeric values" do
      assert :ok = Errors.validate_length(100)
      assert :ok = Errors.validate_length(50.5)
    end

    test "accepts pt units" do
      assert :ok = Errors.validate_length("100pt")
    end

    test "accepts cm units" do
      assert :ok = Errors.validate_length("2cm")
    end

    test "accepts mm units" do
      assert :ok = Errors.validate_length("25mm")
    end

    test "accepts in units" do
      assert :ok = Errors.validate_length("1in")
    end

    test "accepts percentage" do
      assert :ok = Errors.validate_length("50%")
    end

    test "accepts fr units" do
      assert :ok = Errors.validate_length("1fr")
    end

    test "accepts em units" do
      assert :ok = Errors.validate_length("1.5em")
    end

    test "accepts plain number strings" do
      assert :ok = Errors.validate_length("100")
    end

    test "rejects invalid units" do
      assert {:error, {:invalid_length, "10px"}} = Errors.validate_length("10px")
      assert {:error, {:invalid_length, "5rem"}} = Errors.validate_length("5rem")
    end

    test "rejects non-numeric strings" do
      assert {:error, {:invalid_length, "abc"}} = Errors.validate_length("abc")
    end
  end
end
