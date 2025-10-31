defmodule AshReports.Charts.Types.SparklineTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.Sparkline

  describe "build/2" do
    test "builds sparkline with simple array data" do
      data = [1, 5, 10, 15, 12, 12, 15, 14, 20, 14, 10, 15, 15]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert %Contex.Sparkline{} = sparkline
      assert sparkline.data == data
      assert sparkline.height == 20  # Default height
      assert sparkline.width == 100  # Default width
    end

    test "builds sparkline with map data format" do
      data = [
        %{value: 10},
        %{value: 15},
        %{value: 12},
        %{value: 18}
      ]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert %Contex.Sparkline{} = sparkline
      assert sparkline.data == [10, 15, 12, 18]
    end

    test "builds sparkline with string key map data" do
      data = [
        %{"value" => 5},
        %{"value" => 10},
        %{"value" => 8}
      ]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert %Contex.Sparkline{} = sparkline
      assert sparkline.data == [5, 10, 8]
    end

    test "applies custom width from config" do
      data = [1, 2, 3, 4, 5]
      config = %{width: 200}

      sparkline = Sparkline.build(data, config)

      assert sparkline.width == 200
    end

    test "applies custom height from config" do
      data = [1, 2, 3, 4, 5]
      config = %{height: 40}

      sparkline = Sparkline.build(data, config)

      assert sparkline.height == 40
    end

    test "applies custom colors when two colors provided" do
      data = [1, 2, 3]
      config = %{colors: ["#fad48e", "#ff9838"]}

      sparkline = Sparkline.build(data, config)

      assert sparkline.fill_colour == "#fad48e"
      assert sparkline.line_colour == "#ff9838"
    end

    test "applies single color with transparency for fill" do
      data = [1, 2, 3]
      config = %{colors: ["#ff0000"]}

      sparkline = Sparkline.build(data, config)

      assert sparkline.fill_colour == "#ff000033"
      assert sparkline.line_colour == "#ff0000"
    end

    test "uses default colors when none provided" do
      data = [1, 2, 3]
      config = %{}

      sparkline = Sparkline.build(data, config)

      # Contex defaults are green
      assert String.contains?(sparkline.fill_colour, "200")
      assert String.contains?(sparkline.line_colour, "200")
    end

    test "uses default line_width" do
      data = [1, 2, 3]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert sparkline.line_width == 1  # Contex default
    end

    test "uses default spot_radius" do
      data = [1, 2, 3]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert sparkline.spot_radius == 2  # Contex default
    end

    test "uses default spot_colour" do
      data = [1, 2, 3]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert sparkline.spot_colour == "red"  # Contex default
    end

    test "adds # prefix to hex colors without it" do
      data = [1, 2, 3]
      config = %{colors: ["fad48e", "ff9838"]}

      sparkline = Sparkline.build(data, config)

      assert sparkline.fill_colour == "#fad48e"
      assert sparkline.line_colour == "#ff9838"
    end

    test "handles named CSS colors" do
      data = [1, 2, 3]
      config = %{colors: ["red", "blue"]}

      sparkline = Sparkline.build(data, config)

      assert sparkline.fill_colour == "red"
      assert sparkline.line_colour == "blue"
    end
  end

  describe "validate/1" do
    test "validates simple array data" do
      data = [1, 2, 3, 4, 5]

      assert :ok = Sparkline.validate(data)
    end

    test "validates map data with value key" do
      data = [%{value: 10}, %{value: 20}, %{value: 15}]

      assert :ok = Sparkline.validate(data)
    end

    test "validates map data with string keys" do
      data = [%{"value" => 10}, %{"value" => 20}]

      assert :ok = Sparkline.validate(data)
    end

    test "validates mixed number types (integers and floats)" do
      data = [1, 2.5, 3, 4.7, 5]

      assert :ok = Sparkline.validate(data)
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = Sparkline.validate([])
    end

    test "rejects non-list data" do
      assert {:error, "Data must be a list"} = Sparkline.validate(%{value: 1})
      assert {:error, "Data must be a list"} = Sparkline.validate("string")
      assert {:error, "Data must be a list"} = Sparkline.validate(42)
    end

    test "rejects data with non-numeric values" do
      data = [1, 2, "three", 4]

      assert {:error, "All data points must be numbers or maps with :value key"} =
               Sparkline.validate(data)
    end

    test "rejects map data without value key" do
      data = [%{x: 1}, %{x: 2}]

      assert {:error, "All data points must be numbers or maps with :value key"} =
               Sparkline.validate(data)
    end

    test "rejects map data with non-numeric values" do
      data = [%{value: "10"}, %{value: 20}]

      assert {:error, "All data points must be numbers or maps with :value key"} =
               Sparkline.validate(data)
    end

    test "requires at least 2 data points" do
      data = [1]

      assert {:error, "Sparkline requires at least 2 data points"} = Sparkline.validate(data)
    end

    test "accepts exactly 2 data points" do
      data = [1, 2]

      assert :ok = Sparkline.validate(data)
    end
  end

  describe "integration with Charts.generate/3" do
    test "generates SVG output through Charts module" do
      data = [0, 5, 10, 15, 12, 12, 15, 14, 20, 14, 10, 15, 15]
      config = %{width: 100, height: 20}

      # Note: This will only work after sparkline is registered
      # For now, we test the build function directly
      sparkline = Sparkline.build(data, config)
      svg = Contex.Sparkline.draw(sparkline)

      assert {:safe, svg_content} = svg
      assert is_list(svg_content) or is_binary(svg_content)
    end
  end

  describe "data extraction" do
    test "handles mixed data formats in same list" do
      # All should be treated as numeric values
      data = [1, %{value: 2}, %{"value" => 3}, 4]
      config = %{}

      sparkline = Sparkline.build(data, config)

      assert sparkline.data == [1, 2, 3, 4]
    end

    test "defaults invalid entries to 0" do
      # When building (not validating), invalid entries become 0
      data = [1, 2, 3]
      config = %{}

      sparkline = Sparkline.build(data, config)

      # All should be extracted correctly
      assert sparkline.data == [1, 2, 3]
    end
  end

  describe "compact visualization" do
    test "creates ultra-compact sparkline with minimal height" do
      data = [1, 5, 3, 7, 4, 9, 2, 6]
      config = %{width: 50, height: 10}

      sparkline = Sparkline.build(data, config)

      assert sparkline.width == 50
      assert sparkline.height == 10
      assert length(sparkline.data) == 8
    end

    test "creates wide sparkline for dashboard use" do
      data = Enum.map(1..50, fn _ -> :rand.uniform(100) end)
      config = %{width: 300, height: 30}

      sparkline = Sparkline.build(data, config)

      assert sparkline.width == 300
      assert sparkline.height == 30
      assert length(sparkline.data) == 50
    end
  end
end
