defmodule AshReports.Charts.ChartsTest do
  use ExUnit.Case, async: false

  alias AshReports.Charts
  alias AshReports.Charts.{Config, Registry}

  describe "generate/3" do
    test "generates a bar chart with valid data" do
      data = [
        %{category: "A", value: 10},
        %{category: "B", value: 20},
        %{category: "C", value: 15}
      ]

      config = %Config{title: "Test Bar Chart", width: 600, height: 400}

      assert {:ok, svg} = Charts.generate(:bar, data, config)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
      assert String.contains?(svg, "</svg>")
    end

    test "generates a line chart with valid data" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20},
        %{x: 3, y: 15}
      ]

      config = %Config{title: "Test Line Chart"}

      assert {:ok, svg} = Charts.generate(:line, data, config)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end

    test "generates a pie chart with valid data" do
      data = [
        %{category: "A", value: 30},
        %{category: "B", value: 70}
      ]

      config = %Config{title: "Test Pie Chart"}

      assert {:ok, svg} = Charts.generate(:pie, data, config)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end

    test "returns error for unknown chart type" do
      data = [%{x: 1, y: 2}]
      config = %Config{}

      assert {:error, :not_found} = Charts.generate(:unknown, data, config)
    end

    test "accepts map config and converts to struct" do
      data = [%{category: "A", value: 10}]
      config_map = %{title: "Test", width: 800}

      assert {:ok, svg} = Charts.generate(:bar, data, config_map)
      assert is_binary(svg)
    end

    test "uses default config when not provided" do
      data = [%{category: "A", value: 10}]

      assert {:ok, svg} = Charts.generate(:bar, data)
      assert is_binary(svg)
    end
  end

  describe "list_types/0" do
    test "lists all registered chart types" do
      types = Charts.list_types()

      assert is_list(types)
      assert :bar in types
      assert :line in types
      assert :pie in types
    end
  end

  describe "type_available?/1" do
    test "returns true for registered chart types" do
      assert Charts.type_available?(:bar) == true
      assert Charts.type_available?(:line) == true
      assert Charts.type_available?(:pie) == true
    end

    test "returns false for unregistered chart types" do
      assert Charts.type_available?(:unknown) == false
      assert Charts.type_available?(:scatter) == false
    end
  end
end
