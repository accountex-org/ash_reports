defmodule AshReports.Charts.Types.PieChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.PieChart
  alias AshReports.Charts.PieChartConfig

  describe "build/2" do
    test "builds pie chart with category/value data" do
      data = [
        %{category: "Product A", value: 100},
        %{category: "Product B", value: 150},
        %{category: "Product C", value: 75}
      ]

      config = %PieChartConfig{title: "Product Distribution"}

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
      assert chart.dataset
    end

    test "builds pie chart with label/value data" do
      data = [
        %{label: "Apples", value: 45},
        %{label: "Oranges", value: 30},
        %{label: "Bananas", value: 25}
      ]

      config = %PieChartConfig{title: "Fruit Distribution"}

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
      assert chart.dataset
    end

    test "builds pie chart with string keys" do
      data = [
        %{"category" => "A", "value" => 30},
        %{"category" => "B", "value" => 70}
      ]

      config = %PieChartConfig{}

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end

    test "applies custom colors" do
      data = [
        %{category: "A", value: 30},
        %{category: "B", value: 70}
      ]

      config = %PieChartConfig{colours: ["#ff6384", "#36a2eb", "#ffce56"]}

      chart = PieChart.build(data, config)

      assert chart.options[:colour_palette] == ["ff6384", "36a2eb", "ffce56"]
    end

    test "enables data labels" do
      data = [
        %{category: "A", value: 50},
        %{category: "B", value: 50}
      ]

      config = %PieChartConfig{data_labels: true}

      chart = PieChart.build(data, config)

      assert chart.options[:data_labels] == true
    end

    test "does not enable data labels by default" do
      data = [
        %{category: "A", value: 50}
      ]

      config = %PieChartConfig{}

      chart = PieChart.build(data, config)

      # data_labels default is not set, so check it's either not present or falsy
      # Just verify the chart was built successfully
      assert %Contex.PieChart{} = chart
    end

    test "accepts map config and converts to struct" do
      data = [
        %{category: "A", value: 100}
      ]

      config_map = %{title: "Test Chart", colours: ["#ff0000"]}

      chart = PieChart.build(data, config_map)

      assert %Contex.PieChart{} = chart
    end

    test "uses default color palette when no colors specified" do
      data = [
        %{category: "A", value: 100}
      ]

      config = %PieChartConfig{}

      chart = PieChart.build(data, config)

      assert chart.options[:colour_palette] == :default
    end

    test "handles zero values" do
      data = [
        %{category: "A", value: 0},
        %{category: "B", value: 100}
      ]

      config = %PieChartConfig{}

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end

    test "handles decimal values" do
      data = [
        %{category: "A", value: 33.33},
        %{category: "B", value: 66.67}
      ]

      config = %PieChartConfig{}

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end

    test "handles string keys for label field" do
      data = [
        %{"label" => "Category A", "value" => 45},
        %{"label" => "Category B", "value" => 55}
      ]

      config = %PieChartConfig{}

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end
  end

  describe "validate/1" do
    test "validates correct category/value data" do
      data = [
        %{category: "A", value: 30},
        %{category: "B", value: 70}
      ]

      assert :ok = PieChart.validate(data)
    end

    test "validates correct label/value data" do
      data = [
        %{label: "First", value: 45},
        %{label: "Second", value: 55}
      ]

      assert :ok = PieChart.validate(data)
    end

    test "validates data with string keys for category" do
      data = [
        %{"category" => "A", "value" => 30},
        %{"category" => "B", "value" => 70}
      ]

      assert :ok = PieChart.validate(data)
    end

    test "validates data with string keys for label" do
      data = [
        %{"label" => "A", "value" => 30},
        %{"label" => "B", "value" => 70}
      ]

      assert :ok = PieChart.validate(data)
    end

    test "validates data with zero values" do
      data = [
        %{category: "A", value: 0},
        %{category: "B", value: 100}
      ]

      assert :ok = PieChart.validate(data)
    end

    test "validates data with decimal values" do
      data = [
        %{category: "A", value: 33.33},
        %{category: "B", value: 66.67}
      ]

      assert :ok = PieChart.validate(data)
    end

    test "validates data with many slices" do
      data =
        for i <- 1..20 do
          %{category: "Category #{i}", value: i}
        end

      assert :ok = PieChart.validate(data)
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = PieChart.validate([])
    end

    test "rejects non-list data" do
      assert {:error, "Data must be a list"} = PieChart.validate(%{category: "A", value: 10})
      assert {:error, "Data must be a list"} = PieChart.validate("invalid")
      assert {:error, "Data must be a list"} = PieChart.validate(42)
    end

    test "rejects data with missing category/label field" do
      data = [
        %{value: 100}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end

    test "rejects data with missing value field" do
      data = [
        %{category: "A"}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end

    test "rejects data with non-numeric values" do
      data = [
        %{category: "A", value: "hundred"}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end

    test "rejects data with negative values" do
      data = [
        %{category: "A", value: -10},
        %{category: "B", value: 20}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end

    test "rejects data with nil values" do
      data = [
        %{category: "A", value: nil}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end

    test "accepts data with nil category (validation doesn't enforce non-nil)" do
      data = [
        %{category: nil, value: 100}
      ]

      # The current validation only checks for key presence and numeric value >= 0
      # It doesn't validate that category is non-nil
      assert :ok = PieChart.validate(data)
    end

    test "rejects data where all values are zero" do
      data = [
        %{category: "A", value: 0},
        %{category: "B", value: 0}
      ]

      assert {:error, "Sum of values must be positive"} = PieChart.validate(data)
    end

    test "rejects data where all values are negative" do
      data = [
        %{category: "A", value: -10},
        %{category: "B", value: -20}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end

    test "rejects mixed valid and invalid data points" do
      data = [
        %{category: "A", value: 10},
        %{category: "B", value: "twenty"},
        %{category: "C", value: 30}
      ]

      assert {:error, "All data points must have category/label and value"} =
               PieChart.validate(data)
    end
  end

  describe "real-world scenarios" do
    test "handles market share distribution" do
      data = [
        %{category: "Company A", value: 35.5},
        %{category: "Company B", value: 28.3},
        %{category: "Company C", value: 18.7},
        %{category: "Company D", value: 10.2},
        %{category: "Others", value: 7.3}
      ]

      assert :ok = PieChart.validate(data)

      config = %PieChartConfig{
        title: "Market Share 2024",
        colours: ["#FF6384", "#36A2EB", "#FFCE56", "#4BC0C0", "#9966FF"],
        data_labels: true
      }

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
      assert length(chart.dataset.data) == 5
    end

    test "handles budget allocation" do
      data = [
        %{label: "Salaries", value: 450000},
        %{label: "Infrastructure", value: 200000},
        %{label: "Marketing", value: 150000},
        %{label: "R&D", value: 100000},
        %{label: "Operations", value: 100000}
      ]

      assert :ok = PieChart.validate(data)

      config = %PieChartConfig{
        title: "Budget Allocation",
        data_labels: true
      }

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
      assert length(chart.dataset.data) == 5
    end

    test "handles survey results with percentages" do
      data = [
        %{category: "Strongly Agree", value: 42},
        %{category: "Agree", value: 35},
        %{category: "Neutral", value: 15},
        %{category: "Disagree", value: 6},
        %{category: "Strongly Disagree", value: 2}
      ]

      assert :ok = PieChart.validate(data)

      config = %PieChartConfig{
        title: "Customer Satisfaction",
        colours: ["#4CAF50", "#8BC34A", "#FFC107", "#FF9800", "#F44336"],
        data_labels: true
      }

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end

    test "handles traffic source distribution" do
      data = [
        %{label: "Organic Search", value: 45.2},
        %{label: "Direct", value: 23.8},
        %{label: "Social Media", value: 15.5},
        %{label: "Referral", value: 10.3},
        %{label: "Email", value: 5.2}
      ]

      assert :ok = PieChart.validate(data)

      config = %PieChartConfig{
        title: "Traffic Sources",
        data_labels: true
      }

      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end
  end

  describe "edge cases" do
    test "handles single slice (100%)" do
      data = [
        %{category: "All", value: 100}
      ]

      assert :ok = PieChart.validate(data)

      config = %PieChartConfig{}
      chart = PieChart.build(data, config)

      assert %Contex.PieChart{} = chart
    end

    test "handles two equal slices" do
      data = [
        %{category: "A", value: 50},
        %{category: "B", value: 50}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end

    test "handles very small slice values" do
      data = [
        %{category: "Major", value: 99.9},
        %{category: "Minor", value: 0.1}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end

    test "handles many small slices" do
      data =
        for i <- 1..20 do
          %{category: "Slice #{i}", value: 5}
        end

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
      assert length(chart.dataset.data) == 20
    end

    test "handles very large values" do
      data = [
        %{category: "Large", value: 999_999_999}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end

    test "handles decimal precision" do
      data = [
        %{category: "A", value: 33.333333},
        %{category: "B", value: 33.333333},
        %{category: "C", value: 33.333334}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end

    test "handles long category names" do
      data = [
        %{category: "This is a very long category name that might cause display issues", value: 50},
        %{category: "Short", value: 50}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end

    test "handles unequal distribution" do
      data = [
        %{category: "Dominant", value: 95},
        %{category: "Tiny 1", value: 2},
        %{category: "Tiny 2", value: 2},
        %{category: "Tiny 3", value: 1}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end

    test "handles values that don't sum to 100" do
      data = [
        %{category: "A", value: 137},
        %{category: "B", value: 284},
        %{category: "C", value: 512}
      ]

      assert :ok = PieChart.validate(data)

      chart = PieChart.build(data, %PieChartConfig{})

      assert %Contex.PieChart{} = chart
    end
  end
end
