defmodule AshReports.Charts.Types.ScatterPlotTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.ScatterPlot
  alias AshReports.Charts.ScatterChartConfig

  describe "build/2" do
    test "builds scatter plot with x/y data" do
      data = [
        %{x: 1.5, y: 10.2},
        %{x: 2.3, y: 15.7},
        %{x: 3.1, y: 12.5},
        %{x: 4.8, y: 18.3}
      ]

      config = %ScatterChartConfig{title: "Correlation Analysis"}

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
      assert chart.dataset
    end

    test "builds scatter plot with integer coordinates" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 15},
        %{x: 3, y: 12}
      ]

      config = %ScatterChartConfig{}

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "builds scatter plot with string keys" do
      data = [
        %{"x" => 1.5, "y" => 10.2},
        %{"x" => 2.3, "y" => 15.7}
      ]

      config = %ScatterChartConfig{}

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "applies custom colors" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %ScatterChartConfig{colours: ["#ff6384", "#36a2eb"]}

      chart = ScatterPlot.build(data, config)

      assert chart.options[:colour_palette] == ["ff6384", "36a2eb"]
    end

    test "applies 45 degree axis label rotation" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %ScatterChartConfig{axis_label_rotation: :"45"}

      chart = ScatterPlot.build(data, config)

      assert chart.options[:axis_label_rotation] == :"45"
    end

    test "applies 90 degree axis label rotation" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %ScatterChartConfig{axis_label_rotation: :"90"}

      chart = ScatterPlot.build(data, config)

      assert chart.options[:axis_label_rotation] == :"90"
    end

    test "handles auto axis label rotation" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %ScatterChartConfig{axis_label_rotation: :auto}

      chart = ScatterPlot.build(data, config)

      # :auto is included in options
      assert chart.options[:axis_label_rotation] == :auto
    end

    test "ignores invalid axis label rotation values" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %ScatterChartConfig{axis_label_rotation: :"180"}

      chart = ScatterPlot.build(data, config)

      # Invalid rotation is ignored and defaults to :auto
      assert chart.options[:axis_label_rotation] == :auto
    end

    test "accepts map config and converts to struct" do
      data = [
        %{x: 1, y: 10}
      ]

      config_map = %{title: "Test Chart", colours: ["#ff0000"]}

      chart = ScatterPlot.build(data, config_map)

      assert %Contex.PointPlot{} = chart
    end

    test "uses default color palette when no colors specified" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %ScatterChartConfig{}

      chart = ScatterPlot.build(data, config)

      assert chart.options[:colour_palette] == :default
    end

    test "handles negative coordinates" do
      data = [
        %{x: -5, y: -10},
        %{x: -2, y: 5},
        %{x: 3, y: 15}
      ]

      config = %ScatterChartConfig{}

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "handles zero values" do
      data = [
        %{x: 0, y: 0},
        %{x: 1, y: 10}
      ]

      config = %ScatterChartConfig{}

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "handles very precise float values" do
      data = [
        %{x: 1.23456789, y: 10.98765432},
        %{x: 2.34567890, y: 15.87654321}
      ]

      config = %ScatterChartConfig{}

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end
  end

  describe "validate/1" do
    test "validates correct x/y data" do
      data = [
        %{x: 1.5, y: 10.2},
        %{x: 2.3, y: 15.7},
        %{x: 3.1, y: 12.5}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "validates integer coordinates" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20},
        %{x: 3, y: 15}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "validates data with string keys" do
      data = [
        %{"x" => 1.5, "y" => 10.2},
        %{"x" => 2.3, "y" => 15.7}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "validates data with zero values" do
      data = [
        %{x: 0, y: 0},
        %{x: 1, y: 10}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "validates data with negative values" do
      data = [
        %{x: -10, y: -5},
        %{x: -5, y: 0},
        %{x: 0, y: 5},
        %{x: 5, y: 10}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "validates data with mixed integer and float values" do
      data = [
        %{x: 1, y: 10.5},
        %{x: 2.5, y: 20},
        %{x: 3.7, y: 15.3}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "validates single data point" do
      data = [
        %{x: 1, y: 10}
      ]

      assert :ok = ScatterPlot.validate(data)
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = ScatterPlot.validate([])
    end

    test "rejects non-list data" do
      assert {:error, "Data must be a list"} = ScatterPlot.validate(%{x: 1, y: 10})
      assert {:error, "Data must be a list"} = ScatterPlot.validate("invalid")
      assert {:error, "Data must be a list"} = ScatterPlot.validate(42)
    end

    test "rejects data with missing x field" do
      data = [
        %{y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with missing y field" do
      data = [
        %{x: 1}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with non-numeric x values" do
      data = [
        %{x: "one", y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with non-numeric y values" do
      data = [
        %{x: 1, y: "ten"}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with nil x values" do
      data = [
        %{x: nil, y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with nil y values" do
      data = [
        %{x: 1, y: nil}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects mixed valid and invalid data points" do
      data = [
        %{x: 1, y: 10},
        %{x: "two", y: 20},
        %{x: 3, y: 30}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with atoms as numeric values" do
      data = [
        %{x: :one, y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end

    test "rejects data with Date values (not supported for scatter)" do
      data = [
        %{x: ~D[2024-01-01], y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = ScatterPlot.validate(data)
    end
  end

  describe "real-world scenarios" do
    test "handles price vs demand correlation" do
      data = [
        %{x: 10.0, y: 100},
        %{x: 12.5, y: 85},
        %{x: 15.0, y: 70},
        %{x: 17.5, y: 60},
        %{x: 20.0, y: 45},
        %{x: 22.5, y: 35},
        %{x: 25.0, y: 25}
      ]

      assert :ok = ScatterPlot.validate(data)

      config = %ScatterChartConfig{
        title: "Price vs Demand",
        colours: ["#2196F3"]
      }

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
      assert length(chart.dataset.data) == 7
    end

    test "handles height vs weight correlation" do
      data = [
        %{x: 150, y: 50},
        %{x: 160, y: 58},
        %{x: 165, y: 62},
        %{x: 170, y: 68},
        %{x: 175, y: 72},
        %{x: 180, y: 78},
        %{x: 185, y: 85},
        %{x: 190, y: 90}
      ]

      assert :ok = ScatterPlot.validate(data)

      config = %ScatterChartConfig{
        title: "Height (cm) vs Weight (kg)",
        colours: ["#4CAF50"]
      }

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "handles temperature vs ice cream sales" do
      data = [
        %{x: 15.0, y: 200},
        %{x: 18.5, y: 280},
        %{x: 22.0, y: 350},
        %{x: 25.5, y: 420},
        %{x: 28.0, y: 500},
        %{x: 30.5, y: 580},
        %{x: 33.0, y: 650},
        %{x: 35.5, y: 720}
      ]

      assert :ok = ScatterPlot.validate(data)

      config = %ScatterChartConfig{
        title: "Temperature (°C) vs Ice Cream Sales",
        colours: ["#FF9800"]
      }

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "handles study hours vs test scores" do
      data = [
        %{x: 2.0, y: 55},
        %{x: 3.5, y: 62},
        %{x: 4.0, y: 68},
        %{x: 5.5, y: 75},
        %{x: 6.0, y: 78},
        %{x: 7.5, y: 85},
        %{x: 8.0, y: 88},
        %{x: 9.5, y: 92},
        %{x: 10.0, y: 95}
      ]

      assert :ok = ScatterPlot.validate(data)

      config = %ScatterChartConfig{
        title: "Study Hours vs Test Scores",
        colours: ["#9C27B0"]
      }

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "handles age vs response time" do
      data = [
        %{x: 20, y: 0.25},
        %{x: 25, y: 0.27},
        %{x: 30, y: 0.30},
        %{x: 35, y: 0.33},
        %{x: 40, y: 0.38},
        %{x: 45, y: 0.42},
        %{x: 50, y: 0.48},
        %{x: 55, y: 0.55},
        %{x: 60, y: 0.62}
      ]

      assert :ok = ScatterPlot.validate(data)

      config = %ScatterChartConfig{
        title: "Age vs Response Time (seconds)",
        colours: ["#F44336"]
      }

      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end
  end

  describe "edge cases" do
    test "handles single data point" do
      data = [
        %{x: 42, y: 100}
      ]

      assert :ok = ScatterPlot.validate(data)

      config = %ScatterChartConfig{}
      chart = ScatterPlot.build(data, config)

      assert %Contex.PointPlot{} = chart
    end

    test "handles two data points" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles very large coordinate values" do
      data = [
        %{x: 999_999_999, y: 999_999_999}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles very small decimal values" do
      data = [
        %{x: 0.0001, y: 0.0002},
        %{x: 0.0003, y: 0.0004}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles many data points" do
      data =
        for i <- 1..1000 do
          %{x: i * 1.0, y: :rand.uniform() * 100}
        end

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
      assert length(chart.dataset.data) == 1000
    end

    test "handles all points at same x coordinate (vertical line)" do
      data = [
        %{x: 5, y: 10},
        %{x: 5, y: 20},
        %{x: 5, y: 30},
        %{x: 5, y: 40}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles all points at same y coordinate (horizontal line)" do
      data = [
        %{x: 10, y: 50},
        %{x: 20, y: 50},
        %{x: 30, y: 50},
        %{x: 40, y: 50}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles clustered points" do
      # Multiple points very close together
      data = [
        %{x: 10.0, y: 20.0},
        %{x: 10.1, y: 20.1},
        %{x: 10.05, y: 20.05},
        %{x: 10.15, y: 19.95}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles scattered outliers" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 11},
        %{x: 3, y: 12},
        %{x: 4, y: 13},
        %{x: 100, y: 500}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles negative x and positive y" do
      data = [
        %{x: -10, y: 10},
        %{x: -5, y: 15},
        %{x: -2, y: 20}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles positive x and negative y" do
      data = [
        %{x: 10, y: -10},
        %{x: 15, y: -5},
        %{x: 20, y: -2}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles all negative coordinates" do
      data = [
        %{x: -10, y: -10},
        %{x: -5, y: -5},
        %{x: -2, y: -2}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles origin point" do
      data = [
        %{x: 0, y: 0}
      ]

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles perfect linear correlation" do
      data =
        for i <- 1..10 do
          %{x: i * 1.0, y: i * 2.0}
        end

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end

    test "handles no correlation (random scatter)" do
      data =
        for i <- 1..20 do
          %{x: :rand.uniform() * 100, y: :rand.uniform() * 100}
        end

      assert :ok = ScatterPlot.validate(data)

      chart = ScatterPlot.build(data, %ScatterChartConfig{})

      assert %Contex.PointPlot{} = chart
    end
  end
end
