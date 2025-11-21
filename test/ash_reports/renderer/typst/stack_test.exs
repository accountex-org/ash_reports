defmodule AshReports.Renderer.Typst.StackTest do
  @moduledoc """
  Tests for the Typst Stack renderer.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Renderer.Typst.Stack

  describe "render/2" do
    test "renders empty stack" do
      ir = IR.stack(properties: %{})
      result = Stack.render(ir)

      assert result =~ "#stack("
    end

    test "renders stack with direction ttb" do
      ir = IR.stack(properties: %{dir: :ttb})
      result = Stack.render(ir)

      assert result =~ "dir: ttb"
    end

    test "renders stack with direction btt" do
      ir = IR.stack(properties: %{dir: :btt})
      result = Stack.render(ir)

      assert result =~ "dir: btt"
    end

    test "renders stack with direction ltr" do
      ir = IR.stack(properties: %{dir: :ltr})
      result = Stack.render(ir)

      assert result =~ "dir: ltr"
    end

    test "renders stack with direction rtl" do
      ir = IR.stack(properties: %{dir: :rtl})
      result = Stack.render(ir)

      assert result =~ "dir: rtl"
    end

    test "renders stack with string direction" do
      ir = IR.stack(properties: %{dir: "ttb"})
      result = Stack.render(ir)

      assert result =~ "dir: ttb"
    end

    test "renders stack with spacing" do
      ir = IR.stack(properties: %{spacing: "10pt"})
      result = Stack.render(ir)

      assert result =~ "spacing: 10pt"
    end

    test "renders stack with numeric spacing" do
      ir = IR.stack(properties: %{spacing: 15})
      result = Stack.render(ir)

      assert result =~ "spacing: 15pt"
    end

    test "renders stack with dir and spacing" do
      ir = IR.stack(properties: %{dir: :ttb, spacing: "20pt"})
      result = Stack.render(ir)

      assert result =~ "dir: ttb"
      assert result =~ "spacing: 20pt"
    end

    test "renders stack with children" do
      child1 = %{text: "First"}
      child2 = %{text: "Second"}
      ir = IR.stack(properties: %{dir: :ttb}, children: [child1, child2])
      result = Stack.render(ir)

      assert result =~ "[First]"
      assert result =~ "[Second]"
    end

    test "renders stack with cell children" do
      cell1 = IR.Cell.new(content: [%{text: "A"}])
      cell2 = IR.Cell.new(content: [%{text: "B"}])
      ir = IR.stack(properties: %{dir: :ttb}, children: [cell1, cell2])
      result = Stack.render(ir)

      assert result =~ "[A]"
      assert result =~ "[B]"
    end

    test "renders stack with value children" do
      child1 = %{value: 100}
      child2 = %{value: 200}
      ir = IR.stack(properties: %{}, children: [child1, child2])
      result = Stack.render(ir)

      assert result =~ "[100]"
      assert result =~ "[200]"
    end
  end

  describe "build_parameters/1" do
    test "builds empty parameters" do
      result = Stack.build_parameters(%{})
      assert result == ""
    end

    test "builds dir parameter" do
      result = Stack.build_parameters(%{dir: :ltr})
      assert result =~ "dir: ltr"
    end

    test "builds spacing parameter" do
      result = Stack.build_parameters(%{spacing: "5pt"})
      assert result =~ "spacing: 5pt"
    end

    test "builds both parameters" do
      result = Stack.build_parameters(%{dir: :btt, spacing: "10pt"})
      assert result =~ "dir: btt"
      assert result =~ "spacing: 10pt"
    end
  end

  describe "render_direction/1" do
    test "renders atom directions" do
      assert Stack.render_direction(:ttb) == "ttb"
      assert Stack.render_direction(:btt) == "btt"
      assert Stack.render_direction(:ltr) == "ltr"
      assert Stack.render_direction(:rtl) == "rtl"
    end

    test "renders string directions" do
      assert Stack.render_direction("ttb") == "ttb"
      assert Stack.render_direction("ltr") == "ltr"
    end
  end

  describe "render_length/1" do
    test "renders auto" do
      assert Stack.render_length(:auto) == "auto"
      assert Stack.render_length("auto") == "auto"
    end

    test "renders string lengths" do
      assert Stack.render_length("10pt") == "10pt"
      assert Stack.render_length("2cm") == "2cm"
    end

    test "renders numeric lengths with pt default" do
      assert Stack.render_length(100) == "100pt"
      assert Stack.render_length(50.5) == "50.5pt"
    end
  end

  describe "nested layouts" do
    test "renders nested grid" do
      nested_grid = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      ir = IR.stack(properties: %{dir: :ttb}, children: [nested_grid])
      result = Stack.render(ir)

      assert result =~ "#stack("
      assert result =~ "#grid("
      assert result =~ "columns: (1fr, 1fr)"
    end

    test "renders nested table" do
      nested_table = IR.table(properties: %{columns: ["1fr"]})
      ir = IR.stack(properties: %{dir: :ttb}, children: [nested_table])
      result = Stack.render(ir)

      assert result =~ "#stack("
      assert result =~ "#table("
      assert result =~ "columns: (1fr)"
    end

    test "renders nested stack" do
      inner_stack = IR.stack(properties: %{dir: :ltr, spacing: "5pt"})
      outer_stack = IR.stack(properties: %{dir: :ttb}, children: [inner_stack])
      result = Stack.render(outer_stack)

      # Should have two stack calls
      matches = Regex.scan(~r/#stack\(/, result)
      assert length(matches) == 2
      assert result =~ "dir: ttb"
      assert result =~ "dir: ltr"
      assert result =~ "spacing: 5pt"
    end

    test "renders deeply nested layouts" do
      cell = IR.Cell.new(content: [%{text: "Deep"}])
      grid = IR.grid(properties: %{columns: ["1fr"]}, children: [cell])
      inner_stack = IR.stack(properties: %{dir: :ltr}, children: [grid])
      outer_stack = IR.stack(properties: %{dir: :ttb}, children: [inner_stack])
      result = Stack.render(outer_stack)

      assert result =~ "#stack("
      assert result =~ "#grid("
      assert result =~ "[Deep]"
    end
  end

  describe "indentation" do
    test "respects indent option" do
      ir = IR.stack(properties: %{dir: :ttb})
      result = Stack.render(ir, indent: 2)

      # Should start with 4 spaces (2 indents * 2 spaces each)
      assert String.starts_with?(result, "    #stack(")
    end

    test "children are indented correctly" do
      child = %{text: "Item"}
      ir = IR.stack(properties: %{dir: :ttb}, children: [child])
      result = Stack.render(ir, indent: 1)

      lines = String.split(result, "\n")
      # Find the line with [Item]
      item_line = Enum.find(lines, fn line -> String.contains?(line, "[Item]") end)
      assert item_line
      # Should have more indentation than the stack itself
      assert String.starts_with?(item_line, "    ")
    end
  end
end
