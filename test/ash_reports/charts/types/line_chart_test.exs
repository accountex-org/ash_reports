defmodule AshReports.Charts.Types.LineChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.LineChart
  alias AshReports.Charts.LineChartConfig

  describe "build/2" do
    test "builds simple line chart with x/y data" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 15},
        %{x: 3, y: 12},
        %{x: 4, y: 18}
      ]

      config = %LineChartConfig{title: "Simple Trend"}

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert chart.dataset
    end

    test "builds line chart with date/value format" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      config = %LineChartConfig{title: "Time Series"}

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert chart.dataset
    end

    test "builds line chart with string keys" do
      data = [
        %{"x" => 1, "y" => 10},
        %{"x" => 2, "y" => 20}
      ]

      config = %LineChartConfig{}

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "builds multi-series line chart" do
      data = [
        %{x: 1, series: "Product A", y: 10},
        %{x: 1, series: "Product B", y: 15},
        %{x: 2, series: "Product A", y: 12},
        %{x: 2, series: "Product B", y: 18},
        %{x: 3, series: "Product A", y: 15},
        %{x: 3, series: "Product B", y: 20}
      ]

      config = %LineChartConfig{}

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "applies custom colors" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %LineChartConfig{colours: ["#ff6384", "#36a2eb"]}

      chart = LineChart.build(data, config)

      assert chart.options[:colour_palette] == ["ff6384", "36a2eb"]
    end

    test "applies smoothed lines when configured" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20},
        %{x: 3, y: 15}
      ]

      config = %LineChartConfig{smoothed: true}

      chart = LineChart.build(data, config)

      # Smoothed is default true and included in options
      assert chart.options[:smoothed] == true
    end

    test "disables smoothed lines when configured" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %LineChartConfig{smoothed: false}

      chart = LineChart.build(data, config)

      assert chart.options[:smoothed] == false
    end

    test "applies custom stroke width" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %LineChartConfig{stroke_width: "3"}

      chart = LineChart.build(data, config)

      assert chart.options[:stroke_width] == "3"
    end

    test "uses default stroke width when not specified" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %LineChartConfig{}

      chart = LineChart.build(data, config)

      # Default stroke_width of "2" is included in options
      assert chart.options[:stroke_width] == "2"
    end

    test "applies 45 degree axis label rotation" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %LineChartConfig{axis_label_rotation: :"45"}

      chart = LineChart.build(data, config)

      assert chart.options[:axis_label_rotation] == :"45"
    end

    test "applies 90 degree axis label rotation" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %LineChartConfig{axis_label_rotation: :"90"}

      chart = LineChart.build(data, config)

      assert chart.options[:axis_label_rotation] == :"90"
    end

    test "handles auto axis label rotation" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %LineChartConfig{axis_label_rotation: :auto}

      chart = LineChart.build(data, config)

      # :auto is included in options
      assert chart.options[:axis_label_rotation] == :auto
    end

    test "ignores invalid axis label rotation values" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %LineChartConfig{axis_label_rotation: :"180"}

      chart = LineChart.build(data, config)

      # Invalid rotation is ignored and defaults to :auto
      assert chart.options[:axis_label_rotation] == :auto
    end

    test "accepts map config and converts to struct" do
      data = [
        %{x: 1, y: 10}
      ]

      config_map = %{title: "Test Chart", colours: ["#ff0000"]}

      chart = LineChart.build(data, config_map)

      assert %Contex.LinePlot{} = chart
    end

    test "uses default color palette when no colors specified" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %LineChartConfig{}

      chart = LineChart.build(data, config)

      assert chart.options[:colour_palette] == :default
    end

    test "handles DateTime in date field" do
      data = [
        %{date: ~U[2024-01-01 00:00:00Z], value: 100},
        %{date: ~U[2024-01-02 00:00:00Z], value: 150}
      ]

      config = %LineChartConfig{}

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "handles float values for x and y" do
      data = [
        %{x: 1.5, y: 10.2},
        %{x: 2.3, y: 15.7},
        %{x: 3.1, y: 12.5}
      ]

      config = %LineChartConfig{}

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end
  end

  describe "validate/1" do
    test "validates correct x/y data" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20},
        %{x: 3, y: 15}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates date/value format" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates DateTime/value format" do
      data = [
        %{date: ~U[2024-01-01 00:00:00Z], value: 100},
        %{date: ~U[2024-01-02 00:00:00Z], value: 150}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates data with string keys" do
      data = [
        %{"x" => 1, "y" => 10},
        %{"x" => 2, "y" => 20}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates data with string keys for date/value" do
      data = [
        %{"date" => ~D[2024-01-01], "value" => 100},
        %{"date" => ~D[2024-01-02], "value" => 150}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates data with zero values" do
      data = [
        %{x: 1, y: 0},
        %{x: 2, y: 10}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates data with negative values" do
      data = [
        %{x: 1, y: -10},
        %{x: 2, y: 20},
        %{x: 3, y: -5}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "validates data with float coordinates" do
      data = [
        %{x: 1.5, y: 10.25},
        %{x: 2.7, y: 20.75}
      ]

      assert :ok = LineChart.validate(data)
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = LineChart.validate([])
    end

    test "rejects non-list data" do
      assert {:error, "Data must be a list"} = LineChart.validate(%{x: 1, y: 10})
      assert {:error, "Data must be a list"} = LineChart.validate("invalid")
      assert {:error, "Data must be a list"} = LineChart.validate(42)
    end

    test "rejects data with missing x field" do
      data = [
        %{y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects data with missing y field" do
      data = [
        %{x: 1}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects data with non-numeric x values" do
      data = [
        %{x: "one", y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects data with non-numeric y values" do
      data = [
        %{x: 1, y: "ten"}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects data with nil values" do
      data = [
        %{x: nil, y: 10}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects mixed valid and invalid data points" do
      data = [
        %{x: 1, y: 10},
        %{x: "two", y: 20},
        %{x: 3, y: 30}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects date/value with non-Date date" do
      data = [
        %{date: "2024-01-01", value: 100}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end

    test "rejects date/value with non-numeric value" do
      data = [
        %{date: ~D[2024-01-01], value: "hundred"}
      ]

      assert {:error, "All data points must have x and y coordinates"} = LineChart.validate(data)
    end
  end

  describe "real-world scenarios" do
    test "handles stock price over time" do
      data = [
        %{date: ~D[2024-01-01], value: 150.25},
        %{date: ~D[2024-01-02], value: 152.10},
        %{date: ~D[2024-01-03], value: 149.80},
        %{date: ~D[2024-01-04], value: 153.45},
        %{date: ~D[2024-01-05], value: 155.20}
      ]

      assert :ok = LineChart.validate(data)

      config = %LineChartConfig{
        title: "Stock Price",
        smoothed: true,
        stroke_width: "2",
        colours: ["#2196F3"]
      }

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 5
    end

    test "handles temperature readings over 24 hours" do
      data =
        for hour <- 0..23 do
          %{x: hour, y: 20 + :math.sin(hour / 4) * 5}
        end

      assert :ok = LineChart.validate(data)

      config = %LineChartConfig{
        title: "Temperature (°C)",
        smoothed: true,
        colours: ["#FF9800"]
      }

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 24
    end

    test "handles multi-product sales comparison" do
      data = [
        %{x: 1, series: "Product A", y: 100},
        %{x: 1, series: "Product B", y: 80},
        %{x: 1, series: "Product C", y: 60},
        %{x: 2, series: "Product A", y: 120},
        %{x: 2, series: "Product B", y: 85},
        %{x: 2, series: "Product C", y: 70},
        %{x: 3, series: "Product A", y: 110},
        %{x: 3, series: "Product B", y: 90},
        %{x: 3, series: "Product C", y: 75}
      ]

      assert :ok = LineChart.validate(data)

      config = %LineChartConfig{
        title: "Product Sales Trends",
        colours: ["#4CAF50", "#2196F3", "#FF9800"],
        smoothed: true
      }

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "handles website traffic over months" do
      data = [
        %{date: ~D[2024-01-01], value: 45000},
        %{date: ~D[2024-02-01], value: 52000},
        %{date: ~D[2024-03-01], value: 48000},
        %{date: ~D[2024-04-01], value: 61000},
        %{date: ~D[2024-05-01], value: 58000},
        %{date: ~D[2024-06-01], value: 67000}
      ]

      assert :ok = LineChart.validate(data)

      config = %LineChartConfig{
        title: "Monthly Traffic",
        smoothed: false,
        stroke_width: "3",
        colours: ["#9C27B0"]
      }

      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 6
    end
  end

  describe "edge cases" do
    test "handles single data point" do
      data = [
        %{x: 1, y: 42}
      ]

      assert :ok = LineChart.validate(data)

      config = %LineChartConfig{}
      chart = LineChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "handles two data points (minimum for a line)" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      assert :ok = LineChart.validate(data)

      chart = LineChart.build(data, %LineChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles very large coordinate values" do
      data = [
        %{x: 999_999_999, y: 999_999_999}
      ]

      assert :ok = LineChart.validate(data)

      chart = LineChart.build(data, %LineChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles very small decimal values" do
      data = [
        %{x: 0.0001, y: 0.0002}
      ]

      assert :ok = LineChart.validate(data)

      chart = LineChart.build(data, %LineChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles many data points" do
      data =
        for i <- 1..1000 do
          %{x: i, y: :math.sin(i / 10) * 100}
        end

      assert :ok = LineChart.validate(data)

      chart = LineChart.build(data, %LineChartConfig{})

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 1000
    end

    test "handles negative x coordinates" do
      data = [
        %{x: -10, y: 5},
        %{x: -5, y: 10},
        %{x: 0, y: 15},
        %{x: 5, y: 10},
        %{x: 10, y: 5}
      ]

      assert :ok = LineChart.validate(data)

      chart = LineChart.build(data, %LineChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles constant y values (flat line)" do
      data = [
        %{x: 1, y: 100},
        %{x: 2, y: 100},
        %{x: 3, y: 100},
        %{x: 4, y: 100}
      ]

      assert :ok = LineChart.validate(data)

      chart = LineChart.build(data, %LineChartConfig{})

      assert %Contex.LinePlot{} = chart
    end
  end
end
