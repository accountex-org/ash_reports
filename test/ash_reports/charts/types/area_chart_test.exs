defmodule AshReports.Charts.Types.AreaChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.AreaChart
  alias AshReports.Charts.AreaChartConfig

  describe "build/2" do
    test "builds simple area chart with x/y data" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 15},
        %{x: 3, y: 12},
        %{x: 4, y: 18}
      ]

      config = %AreaChartConfig{title: "Trend Over Time"}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert chart.dataset
      # Area chart stores metadata for post-processing
      assert chart.area_chart_meta.mode == :simple
      assert chart.area_chart_meta.opacity == 0.7
    end

    test "builds area chart with date/value format" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      config = %AreaChartConfig{title: "Time Series"}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert chart.dataset
    end

    test "builds area chart with string keys" do
      data = [
        %{"x" => 1, "y" => 10},
        %{"x" => 2, "y" => 20},
        %{"x" => 3, "y" => 15}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "builds stacked area chart with series" do
      data = [
        %{x: 1, series: "Product A", y: 10},
        %{x: 1, series: "Product B", y: 15},
        %{x: 2, series: "Product A", y: 12},
        %{x: 2, series: "Product B", y: 18},
        %{x: 3, series: "Product A", y: 15},
        %{x: 3, series: "Product B", y: 20}
      ]

      config = %AreaChartConfig{mode: :stacked}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert chart.area_chart_meta.mode == :stacked
    end

    test "applies custom colors" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %AreaChartConfig{colours: ["#ff6384", "#36a2eb"]}

      chart = AreaChart.build(data, config)

      assert chart.options[:colour_palette] == ["ff6384", "36a2eb"]
    end

    test "applies custom opacity" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %AreaChartConfig{opacity: 0.5}

      chart = AreaChart.build(data, config)

      assert chart.area_chart_meta.opacity == 0.5
    end

    test "uses default opacity when not specified" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert chart.area_chart_meta.opacity == 0.7
    end

    test "applies smooth lines when configured" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20},
        %{x: 3, y: 15}
      ]

      config = %AreaChartConfig{smooth_lines: true}

      chart = AreaChart.build(data, config)

      # smooth_lines is default true and included in options
      assert chart.options[:smoothed] == true
    end

    test "disables smooth lines when configured" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %AreaChartConfig{smooth_lines: false}

      chart = AreaChart.build(data, config)

      assert chart.options[:smoothed] == false
    end

    test "automatically sorts data by x values" do
      # Data in unsorted order
      data = [
        %{x: 3, y: 12},
        %{x: 1, y: 10},
        %{x: 2, y: 15}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      # Data should be sorted internally
      assert chart.dataset.data == [
               %{x: 1, y: 10},
               %{x: 2, y: 15},
               %{x: 3, y: 12}
             ]
    end

    test "handles DateTime in date field" do
      data = [
        %{date: ~U[2024-01-01 00:00:00Z], value: 100},
        %{date: ~U[2024-01-02 00:00:00Z], value: 150}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "handles float values" do
      data = [
        %{x: 1.5, y: 10.2},
        %{x: 2.3, y: 15.7},
        %{x: 3.1, y: 12.5}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "accepts map config and converts to struct" do
      data = [
        %{x: 1, y: 10}
      ]

      config_map = %{title: "Test Chart", colours: ["#ff0000"], opacity: 0.8}

      chart = AreaChart.build(data, config_map)

      assert %Contex.LinePlot{} = chart
      assert chart.area_chart_meta.opacity == 0.8
    end

    test "uses default color palette when no colors specified" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert chart.options[:colour_palette] == :default
    end

    test "uses simple mode by default" do
      data = [
        %{x: 1, y: 10}
      ]

      config = %AreaChartConfig{}

      chart = AreaChart.build(data, config)

      assert chart.area_chart_meta.mode == :simple
    end
  end

  describe "validate/1" do
    test "validates correct x/y data that is time-ordered" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20},
        %{x: 3, y: 15}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates date/value format that is time-ordered" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-02], value: 150},
        %{date: ~D[2024-01-03], value: 120}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates DateTime/value format" do
      data = [
        %{date: ~U[2024-01-01 00:00:00Z], value: 100},
        %{date: ~U[2024-01-02 00:00:00Z], value: 150}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates series-based data" do
      data = [
        %{x: 1, series: "A", y: 10},
        %{x: 1, series: "B", y: 12},
        %{x: 2, series: "A", y: 15}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates data with string keys" do
      data = [
        %{"x" => 1, "y" => 10},
        %{"x" => 2, "y" => 20}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates data with zero values" do
      data = [
        %{x: 1, y: 0},
        %{x: 2, y: 10}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates data with negative values" do
      data = [
        %{x: 1, y: -10},
        %{x: 2, y: 20},
        %{x: 3, y: -5}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "validates data with float coordinates" do
      data = [
        %{x: 1.5, y: 10.25},
        %{x: 2.7, y: 20.75}
      ]

      assert :ok = AreaChart.validate(data)
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = AreaChart.validate([])
    end

    test "rejects non-list data" do
      assert {:error, "Data must be a list"} = AreaChart.validate(%{x: 1, y: 10})
      assert {:error, "Data must be a list"} = AreaChart.validate("invalid")
      assert {:error, "Data must be a list"} = AreaChart.validate(42)
    end

    test "rejects data with missing x field" do
      data = [
        %{y: 10}
      ]

      assert {:error, "All data points must have x/y coordinates or date/value pairs"} =
               AreaChart.validate(data)
    end

    test "rejects data with missing y field" do
      data = [
        %{x: 1}
      ]

      assert {:error, "All data points must have x/y coordinates or date/value pairs"} =
               AreaChart.validate(data)
    end

    test "rejects data with non-numeric x values" do
      data = [
        %{x: "one", y: 10}
      ]

      assert {:error, "All data points must have x/y coordinates or date/value pairs"} =
               AreaChart.validate(data)
    end

    test "rejects data with non-numeric y values" do
      data = [
        %{x: 1, y: "ten"}
      ]

      assert {:error, "All data points must have x/y coordinates or date/value pairs"} =
               AreaChart.validate(data)
    end

    test "rejects data that is not time-ordered" do
      data = [
        %{x: 1, y: 10},
        %{x: 3, y: 15},
        %{x: 2, y: 20}
      ]

      assert {:error, "Area chart data must be sorted by x values or dates"} =
               AreaChart.validate(data)
    end

    test "rejects date/value data that is not time-ordered" do
      data = [
        %{date: ~D[2024-01-01], value: 100},
        %{date: ~D[2024-01-03], value: 120},
        %{date: ~D[2024-01-02], value: 150}
      ]

      assert {:error, "Area chart data must be sorted by x values or dates"} =
               AreaChart.validate(data)
    end

    test "rejects data with nil values" do
      data = [
        %{x: nil, y: 10}
      ]

      assert {:error, "All data points must have x/y coordinates or date/value pairs"} =
               AreaChart.validate(data)
    end

    test "rejects mixed valid and invalid data points" do
      data = [
        %{x: 1, y: 10},
        %{x: "two", y: 20},
        %{x: 3, y: 30}
      ]

      assert {:error, "All data points must have x/y coordinates or date/value pairs"} =
               AreaChart.validate(data)
    end
  end

  describe "real-world scenarios" do
    test "handles cumulative revenue over time" do
      data = [
        %{date: ~D[2024-01-01], value: 10000},
        %{date: ~D[2024-02-01], value: 25000},
        %{date: ~D[2024-03-01], value: 42000},
        %{date: ~D[2024-04-01], value: 61000},
        %{date: ~D[2024-05-01], value: 83000},
        %{date: ~D[2024-06-01], value: 108000}
      ]

      assert :ok = AreaChart.validate(data)

      config = %AreaChartConfig{
        title: "Cumulative Revenue",
        smooth_lines: true,
        opacity: 0.6,
        colours: ["#4CAF50"]
      }

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 6
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

      assert :ok = AreaChart.validate(data)

      config = %AreaChartConfig{
        title: "Monthly Traffic",
        smooth_lines: true,
        colours: ["#2196F3"]
      }

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "handles stacked area chart for multiple products" do
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

      assert :ok = AreaChart.validate(data)

      config = %AreaChartConfig{
        mode: :stacked,
        title: "Product Sales Trends",
        colours: ["#4CAF50", "#2196F3", "#FF9800"],
        opacity: 0.8
      }

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert chart.area_chart_meta.mode == :stacked
    end

    test "handles temperature readings over 24 hours" do
      data =
        for hour <- 0..23 do
          %{x: hour, y: 20 + :math.sin(hour / 4) * 5}
        end

      assert :ok = AreaChart.validate(data)

      config = %AreaChartConfig{
        title: "Temperature (°C)",
        smooth_lines: true,
        colours: ["#FF5722"],
        opacity: 0.5
      }

      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 24
    end
  end

  describe "edge cases" do
    test "handles single data point" do
      data = [
        %{x: 1, y: 42}
      ]

      assert :ok = AreaChart.validate(data)

      config = %AreaChartConfig{}
      chart = AreaChart.build(data, config)

      assert %Contex.LinePlot{} = chart
    end

    test "handles two data points (minimum for meaningful area)" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles very large coordinate values" do
      data = [
        %{x: 1, y: 999_999_999},
        %{x: 2, y: 999_999_998}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles very small decimal values" do
      data = [
        %{x: 0.001, y: 0.0001},
        %{x: 0.002, y: 0.0002}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles many data points" do
      data =
        for i <- 1..1000 do
          %{x: i, y: :math.sin(i / 10) * 100}
        end

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
      assert length(chart.dataset.data) == 1000
    end

    test "handles negative x coordinates in order" do
      data = [
        %{x: -10, y: 5},
        %{x: -5, y: 10},
        %{x: 0, y: 15},
        %{x: 5, y: 10},
        %{x: 10, y: 5}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles all zero values" do
      data = [
        %{x: 1, y: 0},
        %{x: 2, y: 0},
        %{x: 3, y: 0}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles sharp spikes in data" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 10},
        %{x: 3, y: 100},
        %{x: 4, y: 10},
        %{x: 5, y: 10}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles identical consecutive values" do
      data = [
        %{x: 1, y: 50},
        %{x: 2, y: 50},
        %{x: 3, y: 50},
        %{x: 4, y: 50}
      ]

      assert :ok = AreaChart.validate(data)

      chart = AreaChart.build(data, %AreaChartConfig{})

      assert %Contex.LinePlot{} = chart
    end

    test "handles full opacity (no transparency)" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %AreaChartConfig{opacity: 1.0}

      chart = AreaChart.build(data, config)

      assert chart.area_chart_meta.opacity == 1.0
    end

    test "handles minimal opacity" do
      data = [
        %{x: 1, y: 10},
        %{x: 2, y: 20}
      ]

      config = %AreaChartConfig{opacity: 0.1}

      chart = AreaChart.build(data, config)

      assert chart.area_chart_meta.opacity == 0.1
    end
  end
end
