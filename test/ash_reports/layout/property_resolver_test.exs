defmodule AshReports.Layout.PropertyResolverTest do
  @moduledoc """
  Tests for the property resolver module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.PropertyResolver

  describe "resolve/3" do
    test "merges child with parent, child takes precedence" do
      parent = %{align: "left", inset: "5pt"}
      child = %{align: "center"}

      result = PropertyResolver.resolve(child, parent)

      assert result.align == "center"
      assert result.inset == "5pt"
    end

    test "applies defaults when neither has property" do
      parent = %{align: "left"}
      child = %{fill: "blue"}
      defaults = %{inset: "10pt", stroke: "1pt"}

      result = PropertyResolver.resolve(child, parent, defaults)

      assert result.align == "left"
      assert result.fill == "blue"
      assert result.inset == "10pt"
      assert result.stroke == "1pt"
    end

    test "child overrides both parent and defaults" do
      defaults = %{align: "left"}
      parent = %{align: "center"}
      child = %{align: "right"}

      result = PropertyResolver.resolve(child, parent, defaults)

      assert result.align == "right"
    end

    test "removes nil values" do
      parent = %{align: "left", inset: nil}
      child = %{fill: nil}

      result = PropertyResolver.resolve(child, parent)

      assert result == %{align: "left"}
      refute Map.has_key?(result, :inset)
      refute Map.has_key?(result, :fill)
    end

    test "handles empty maps" do
      assert PropertyResolver.resolve(%{}, %{}) == %{}
      assert PropertyResolver.resolve(%{}, %{a: 1}) == %{a: 1}
      assert PropertyResolver.resolve(%{a: 1}, %{}) == %{a: 1}
    end
  end

  describe "resolve_chain/4" do
    test "resolves full inheritance chain" do
      container = %{align: "left", inset: "5pt", fill: "white"}
      row = %{fill: "gray"}
      cell = %{align: "center"}

      result = PropertyResolver.resolve_chain(cell, row, container)

      assert result.align == "center"  # from cell
      assert result.fill == "gray"     # from row
      assert result.inset == "5pt"     # from container
    end

    test "cell overrides all" do
      container = %{align: "left"}
      row = %{align: "center"}
      cell = %{align: "right"}

      result = PropertyResolver.resolve_chain(cell, row, container)

      assert result.align == "right"
    end

    test "row overrides container" do
      container = %{inset: "5pt"}
      row = %{inset: "10pt"}
      cell = %{}

      result = PropertyResolver.resolve_chain(cell, row, container)

      assert result.inset == "10pt"
    end

    test "applies defaults" do
      defaults = %{align: "left", inset: "5pt"}
      container = %{}
      row = %{}
      cell = %{}

      result = PropertyResolver.resolve_chain(cell, row, container, defaults)

      assert result.align == "left"
      assert result.inset == "5pt"
    end
  end

  describe "resolve_align/3" do
    test "returns cell align if present" do
      props = %{align: "center"}
      parent = %{align: "left"}

      assert PropertyResolver.resolve_align(props, parent) == "center"
    end

    test "falls back to parent align" do
      props = %{}
      parent = %{align: "left"}

      assert PropertyResolver.resolve_align(props, parent) == "left"
    end

    test "falls back to default" do
      props = %{}
      parent = %{}

      assert PropertyResolver.resolve_align(props, parent, "center") == "center"
    end

    test "handles string keys" do
      props = %{"align" => "right"}
      parent = %{}

      assert PropertyResolver.resolve_align(props, parent) == "right"
    end
  end

  describe "resolve_inset/3" do
    test "returns cell inset if present" do
      props = %{inset: "10pt"}
      parent = %{inset: "5pt"}

      assert PropertyResolver.resolve_inset(props, parent) == "10pt"
    end

    test "falls back to parent inset" do
      props = %{}
      parent = %{inset: "5pt"}

      assert PropertyResolver.resolve_inset(props, parent) == "5pt"
    end

    test "falls back to default" do
      props = %{}
      parent = %{}

      assert PropertyResolver.resolve_inset(props, parent, "3pt") == "3pt"
    end
  end

  describe "is_dynamic?/1" do
    test "returns true for functions" do
      assert PropertyResolver.is_dynamic?(fn x, y -> x + y end)
      assert PropertyResolver.is_dynamic?(&(&1 + &2))
      assert PropertyResolver.is_dynamic?(fn _ -> "blue" end)
    end

    test "returns false for static values" do
      refute PropertyResolver.is_dynamic?("blue")
      refute PropertyResolver.is_dynamic?(123)
      refute PropertyResolver.is_dynamic?(:left)
      refute PropertyResolver.is_dynamic?(nil)
      refute PropertyResolver.is_dynamic?(%{})
    end
  end

  describe "separate_static_dynamic/1" do
    test "separates static and dynamic properties" do
      fill_fn = fn x, y -> if rem(x + y, 2) == 0, do: "white", else: "gray" end

      props = %{
        align: "center",
        fill: fill_fn,
        inset: "5pt"
      }

      {static, dynamic} = PropertyResolver.separate_static_dynamic(props)

      assert static == %{align: "center", inset: "5pt"}
      assert Map.keys(dynamic) == [:fill]
      assert is_function(dynamic.fill)
    end

    test "handles all static" do
      props = %{align: "left", inset: "5pt"}

      {static, dynamic} = PropertyResolver.separate_static_dynamic(props)

      assert static == props
      assert dynamic == %{}
    end

    test "handles all dynamic" do
      props = %{
        fill: fn _, _ -> "blue" end,
        stroke: fn _, _ -> "1pt" end
      }

      {static, dynamic} = PropertyResolver.separate_static_dynamic(props)

      assert static == %{}
      assert Map.keys(dynamic) |> Enum.sort() == [:fill, :stroke]
    end
  end

  describe "evaluate_dynamic/2" do
    test "evaluates 2-arity function with x, y" do
      func = fn x, y -> if rem(x + y, 2) == 0, do: "white", else: "gray" end

      assert PropertyResolver.evaluate_dynamic(func, %{x: 0, y: 0}) == "white"
      assert PropertyResolver.evaluate_dynamic(func, %{x: 1, y: 0}) == "gray"
      assert PropertyResolver.evaluate_dynamic(func, %{x: 1, y: 1}) == "white"
    end

    test "evaluates 1-arity function with context" do
      func = fn ctx -> "row-#{ctx[:row]}" end

      assert PropertyResolver.evaluate_dynamic(func, %{row: 5}) == "row-5"
    end

    test "returns static value unchanged" do
      assert PropertyResolver.evaluate_dynamic("blue", %{x: 0, y: 0}) == "blue"
      assert PropertyResolver.evaluate_dynamic(123, %{x: 0, y: 0}) == 123
    end

    test "uses col/row as fallback for x/y" do
      func = fn x, y -> {x, y} end

      assert PropertyResolver.evaluate_dynamic(func, %{col: 2, row: 3}) == {2, 3}
    end
  end

  describe "parse_length/1" do
    test "parses pt units" do
      assert {:ok, {100.0, :pt}} = PropertyResolver.parse_length("100pt")
      assert {:ok, {10.5, :pt}} = PropertyResolver.parse_length("10.5pt")
    end

    test "parses cm units" do
      assert {:ok, {2.0, :cm}} = PropertyResolver.parse_length("2cm")
      assert {:ok, {1.5, :cm}} = PropertyResolver.parse_length("1.5cm")
    end

    test "parses mm units" do
      assert {:ok, {25.4, :mm}} = PropertyResolver.parse_length("25.4mm")
    end

    test "parses in units" do
      assert {:ok, {1.0, :in}} = PropertyResolver.parse_length("1in")
    end

    test "parses percentage" do
      assert {:ok, {20.0, :percent}} = PropertyResolver.parse_length("20%")
      assert {:ok, {100.0, :percent}} = PropertyResolver.parse_length("100%")
    end

    test "parses fr units" do
      assert {:ok, {1.0, :fr}} = PropertyResolver.parse_length("1fr")
      assert {:ok, {2.5, :fr}} = PropertyResolver.parse_length("2.5fr")
    end

    test "parses em units" do
      assert {:ok, {1.5, :em}} = PropertyResolver.parse_length("1.5em")
    end

    test "parses auto" do
      assert {:ok, :auto} = PropertyResolver.parse_length("auto")
      assert {:ok, :auto} = PropertyResolver.parse_length(:auto)
    end

    test "parses plain numbers as pt" do
      assert {:ok, {10.0, :pt}} = PropertyResolver.parse_length(10)
      assert {:ok, {5.5, :pt}} = PropertyResolver.parse_length(5.5)
    end

    test "parses numeric string as pt" do
      assert {:ok, {10.0, :pt}} = PropertyResolver.parse_length("10")
    end

    test "handles whitespace" do
      assert {:ok, {5.0, :pt}} = PropertyResolver.parse_length("  5pt  ")
    end

    test "returns error for invalid format" do
      assert {:error, {:invalid_length, "abc"}} = PropertyResolver.parse_length("abc")
      assert {:error, {:invalid_length, "10px"}} = PropertyResolver.parse_length("10px")
    end
  end

  describe "normalize_to_points/1" do
    test "converts pt to points" do
      assert {:ok, 100.0} = PropertyResolver.normalize_to_points("100pt")
    end

    test "converts cm to points" do
      {:ok, result} = PropertyResolver.normalize_to_points("1cm")
      assert_in_delta result, 28.3465, 0.001
    end

    test "converts mm to points" do
      {:ok, result} = PropertyResolver.normalize_to_points("10mm")
      assert_in_delta result, 28.3465, 0.001
    end

    test "converts in to points" do
      {:ok, result} = PropertyResolver.normalize_to_points("1in")
      assert result == 72.0
    end

    test "preserves percentage as tuple" do
      assert {:ok, {:percent, 50.0}} = PropertyResolver.normalize_to_points("50%")
    end

    test "preserves fr as tuple" do
      assert {:ok, {:fr, 2.0}} = PropertyResolver.normalize_to_points("2fr")
    end

    test "preserves em as tuple" do
      assert {:ok, {:em, 1.5}} = PropertyResolver.normalize_to_points("1.5em")
    end

    test "returns auto unchanged" do
      assert {:ok, :auto} = PropertyResolver.normalize_to_points("auto")
    end
  end

  describe "parse_lengths/1" do
    test "parses single length" do
      assert {:ok, [{5.0, :pt}]} = PropertyResolver.parse_lengths("5pt")
    end

    test "parses multiple lengths" do
      assert {:ok, [{5.0, :pt}, {10.0, :pt}]} = PropertyResolver.parse_lengths("5pt 10pt")
    end

    test "parses mixed units" do
      assert {:ok, [{5.0, :pt}, {1.0, :cm}, {20.0, :percent}]} =
        PropertyResolver.parse_lengths("5pt 1cm 20%")
    end

    test "handles multiple spaces" do
      assert {:ok, [{5.0, :pt}, {10.0, :pt}]} = PropertyResolver.parse_lengths("5pt   10pt")
    end

    test "returns error for invalid lengths" do
      assert {:error, {:invalid_lengths, "5pt abc"}} = PropertyResolver.parse_lengths("5pt abc")
    end
  end

  describe "resolve_all/1" do
    test "normalizes length properties" do
      props = %{
        inset: "5pt",
        gutter: "10pt",
        align: "center"
      }

      result = PropertyResolver.resolve_all(props)

      assert result.inset == {5.0, :pt}
      assert result.gutter == {10.0, :pt}
      assert result.align == "center"
    end

    test "handles non-string length values" do
      props = %{
        inset: 5,
        gutter: nil
      }

      result = PropertyResolver.resolve_all(props)

      # Non-string values pass through unchanged
      assert result.inset == 5
      # nil values are preserved (use resolve/3 to remove nils)
      assert Map.has_key?(result, :gutter)
      assert result.gutter == nil
    end

    test "keeps invalid lengths unchanged" do
      props = %{
        inset: "invalid"
      }

      result = PropertyResolver.resolve_all(props)

      assert result.inset == "invalid"
    end
  end
end
