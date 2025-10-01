defmodule AshReports.TypstMockDataTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import AshReports.TypstMockData
  import AshReports.TypstTestHelpers

  describe "report_template_generator/1" do
    property "generates valid Typst templates" do
      check all template <- report_template_generator(sections: 1..3),
                max_runs: 10 do
        assert is_binary(template)
        assert template =~ "#set page"
        assert template =~ "= Test Report"
      end
    end

    test "generates templates with configurable sections" do
      template =
        report_template_generator(sections: 5..5, paragraphs_per_section: 2..2)
        |> Enum.take(1)
        |> List.first()

      # Should have approximately 5 sections
      section_count = Regex.scan(~r/== Section/, template) |> length()
      assert section_count >= 4 and section_count <= 6
    end
  end

  describe "table_generator/1" do
    property "generates tables with correct dimensions" do
      check all table <- table_generator(rows: 5..5, cols: 3..3),
                max_runs: 10 do
        assert length(table.headers) == 3
        assert length(table.rows) == 5
        assert Enum.all?(table.rows, &(length(&1) == 3))
      end
    end

    test "generates varying table sizes" do
      tables = Enum.take(table_generator(rows: 1..10, cols: 2..5), 5)

      assert Enum.all?(tables, fn table ->
        length(table.headers) >= 2 and length(table.headers) <= 5 and
          length(table.rows) >= 1 and length(table.rows) <= 10
      end)
    end
  end

  describe "edge_case_generator/0" do
    property "generates various edge case values" do
      check all value <- edge_case_generator(),
                max_runs: 20 do
        assert is_binary(value) or is_nil(value)
      end
    end

    test "includes empty strings" do
      values = Enum.take(edge_case_generator(), 100)
      assert "" in values
    end

    test "includes special characters" do
      values = Enum.take(edge_case_generator(), 100)
      assert Enum.any?(values, &(is_binary(&1) and String.contains?(&1, "<")))
    end
  end

  describe "nested_structure_generator/1" do
    property "generates nested structures with correct depth" do
      check all structure <- nested_structure_generator(depth: 2, items_per_level: 1..2),
                max_runs: 10 do
        assert is_map(structure)
        assert Map.has_key?(structure, :name)
        assert Map.has_key?(structure, :value)
        assert Map.has_key?(structure, :children)
      end
    end

    test "respects depth limit" do
      structure = Enum.take(nested_structure_generator(depth: 3), 1) |> List.first()

      assert is_map(structure)
      # Check that structure doesn't exceed depth
      max_depth = calculate_max_depth(structure)
      assert max_depth <= 3
    end
  end

  describe "generate_table_template/1" do
    test "generates valid Typst table syntax" do
      data = %{
        headers: ["A", "B", "C"],
        rows: [
          ["1", "2", "3"],
          ["4", "5", "6"]
        ]
      }

      template = generate_table_template(data)

      assert template =~ "#table"
      assert template =~ "columns: 3"
      assert template =~ "[A]"
      assert template =~ "[1]"
    end

    test "handles empty tables" do
      data = %{headers: [], rows: []}
      template = generate_table_template(data)

      assert template =~ "#table"
      assert template =~ "columns: 0"
    end
  end

  describe "generate_mock_report/1" do
    test "generates simple report" do
      report = generate_mock_report(complexity: :simple)

      assert is_binary(report)
      assert report =~ "Simple Test Report"
      assert {:ok, _pdf} = compile_and_validate(report)
    end

    test "generates medium complexity report" do
      report = generate_mock_report(complexity: :medium)

      assert is_binary(report)
      assert report =~ "Medium Complexity Report"
      assert report =~ "#table"
      assert {:ok, _pdf} = compile_and_validate(report)
    end

    test "generates complex report" do
      report = generate_mock_report(complexity: :complex)

      assert is_binary(report)
      assert report =~ "Complex Multi-Section Report"
      assert report =~ "#outline"
      assert report =~ "#pagebreak"
      assert {:ok, _pdf} = compile_and_validate(report)
    end
  end

  # Helper functions

  defp calculate_max_depth(structure, current_depth \\ 0) do
    if structure.children == [] or structure.children == nil do
      current_depth
    else
      child_depths =
        structure.children
        |> Enum.map(&calculate_max_depth(&1, current_depth + 1))

      Enum.max(child_depths)
    end
  end
end
