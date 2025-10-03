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

    test "generates an area chart with valid data" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 15},
        %{x: 3, y: 12}
      ]

      config = %Config{title: "Test Area Chart"}

      assert {:ok, svg} = Charts.generate(:area, data, config)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end

    test "generates an area chart with date/value format" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      config = %Config{title: "Time Series Area"}

      assert {:ok, svg} = Charts.generate(:area, data, config)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end

    test "generates a scatter plot with valid data" do
      data = [
        %{x: 1.5, y: 10.2},
        %{x: 2.3, y: 15.7},
        %{x: 3.1, y: 12.5}
      ]

      config = %Config{title: "Scatter Plot"}

      assert {:ok, svg} = Charts.generate(:scatter, data, config)
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
      assert :area in types
      assert :scatter in types
    end
  end

  describe "type_available?/1" do
    test "returns true for registered chart types" do
      assert Charts.type_available?(:bar) == true
      assert Charts.type_available?(:line) == true
      assert Charts.type_available?(:pie) == true
      assert Charts.type_available?(:area) == true
      assert Charts.type_available?(:scatter) == true
    end

    test "returns false for unregistered chart types" do
      assert Charts.type_available?(:unknown) == false
      assert Charts.type_available?(:heatmap) == false
    end
  end

  describe "theme support" do
    test "applies corporate theme to chart" do
      data = [%{category: "A", value: 10}]
      config = %Config{title: "Test", theme_name: :corporate}

      assert {:ok, svg} = Charts.generate(:bar, data, config)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end

    test "applies minimal theme to chart" do
      data = [%{x: 1, y: 10}]
      config = %Config{theme_name: :minimal}

      assert {:ok, svg} = Charts.generate(:line, data, config)
      assert is_binary(svg)
    end

    test "uses default theme when theme_name is :default" do
      data = [%{category: "A", value: 10}]
      config = %Config{theme_name: :default}

      assert {:ok, svg} = Charts.generate(:bar, data, config)
      assert is_binary(svg)
    end
  end

  describe "conditional rendering" do
    test "renders chart when data meets min_data_points requirement" do
      data = [%{x: 1, y: 10}, %{x: 2, y: 20}, %{x: 3, y: 30}]
      config = %Config{min_data_points: 3}

      assert {:ok, svg} = Charts.generate(:line, data, config)
      assert is_binary(svg)
    end

    test "returns error when data doesn't meet min_data_points" do
      data = [%{x: 1, y: 10}]
      config = %Config{min_data_points: 3}

      assert {:error, {:insufficient_data, message}} = Charts.generate(:line, data, config)
      assert message =~ "requires at least 3 data points"
      assert message =~ "got 1"
    end

    test "renders chart when min_data_points is nil" do
      data = [%{category: "A", value: 10}]
      config = %Config{min_data_points: nil}

      assert {:ok, svg} = Charts.generate(:bar, data, config)
      assert is_binary(svg)
    end
  end
end
