defmodule AshReports.Typst.StreamingPipeline.ChartDataCollectorTest do
  use ExUnit.Case, async: true

  alias AshReports.{Band, Report}
  alias AshReports.Element.Chart
  alias AshReports.Typst.StreamingPipeline.ChartDataCollector

  describe "extract_chart_configs/1" do
    test "extracts aggregation-based chart configurations" do
      # Create a chart element with aggregation data source
      chart_element = Chart.new(:sales_chart,
        chart_type: :bar,
        # This would be an Ash.Expr in real usage
        data_source: {:aggregation, nil, [:region, :sum, :amount]},
        config: %{width: 600, height: 400},
        embed_options: %{width: "100%"}
      )

      report = %Report{
        name: :test_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart_element]
          }
        ]
      }

      configs = ChartDataCollector.extract_chart_configs(report)

      assert length(configs) == 1
      [config] = configs

      assert config.name == :sales_chart
      assert config.chart_type == :bar
      assert config.aggregation_ref.group_by == :region
      assert config.aggregation_ref.aggregation_type == :sum
      assert config.aggregation_ref.field == :amount
    end

    test "ignores non-aggregation charts" do
      # Chart with static data
      chart_element = Chart.new(:static_chart,
        chart_type: :bar,
        data_source: [%{category: "A", value: 10}],
        config: %{}
      )

      report = %Report{
        name: :test_report,
        bands: [%Band{type: :header, name: :header, elements: [chart_element]}]
      }

      configs = ChartDataCollector.extract_chart_configs(report)

      # Static data charts are filtered out (not aggregation-based)
      assert configs == []
    end

    test "handles reports with no charts" do
      report = %Report{
        name: :test_report,
        bands: [%Band{type: :header, name: :header, elements: []}]
      }

      configs = ChartDataCollector.extract_chart_configs(report)

      assert configs == []
    end
  end

  describe "convert_aggregations_to_charts/2" do
    test "converts sum aggregation to bar chart data" do
      # Simulate aggregation state from ProducerConsumer
      grouped_aggregation_state = %{
        [:region] => %{
          "North" => %{sum: %{amount: 15000}, count: 50},
          "South" => %{sum: %{amount: 12000}, count: 40},
          "East" => %{sum: %{amount: 18000}, count: 60}
        }
      }

      chart_config = %{
        name: :sales_by_region,
        chart_type: :bar,
        aggregation_ref: %{
          group_by: :region,
          aggregation_type: :sum,
          field: :amount
        },
        chart_config: %{width: 600, height: 400},
        embed_options: %{}
      }

      result = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        [chart_config]
      )

      assert Map.has_key?(result, :sales_by_region)
      chart_data = result[:sales_by_region]

      assert chart_data.name == :sales_by_region
      assert chart_data.chart_type == :bar
      assert is_binary(chart_data.svg)
      assert is_binary(chart_data.embedded_code)
      assert is_nil(chart_data.error)
    end

    test "converts count aggregation to pie chart data" do
      grouped_aggregation_state = %{
        [:category] => %{
          "Electronics" => %{count: 150},
          "Clothing" => %{count: 200},
          "Food" => %{count: 100}
        }
      }

      chart_config = %{
        name: :orders_by_category,
        chart_type: :pie,
        aggregation_ref: %{
          group_by: :category,
          aggregation_type: :count,
          field: nil
        },
        chart_config: %{width: 500, height: 500},
        embed_options: %{}
      }

      result = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        [chart_config]
      )

      chart_data = result[:orders_by_category]

      assert chart_data.chart_type == :pie
      assert is_binary(chart_data.svg)
      assert is_nil(chart_data.error)
    end

    test "converts average aggregation to line chart data" do
      grouped_aggregation_state = %{
        [:month] => %{
          "Jan" => %{avg: %{sum: %{price: 5000}, count: 50}},
          "Feb" => %{avg: %{sum: %{price: 6000}, count: 60}},
          "Mar" => %{avg: %{sum: %{price: 5500}, count: 55}}
        }
      }

      chart_config = %{
        name: :avg_price_trend,
        chart_type: :line,
        aggregation_ref: %{
          group_by: :month,
          aggregation_type: :avg,
          field: :price
        },
        chart_config: %{width: 800, height: 400},
        embed_options: %{}
      }

      result = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        [chart_config]
      )

      chart_data = result[:avg_price_trend]

      assert chart_data.chart_type == :line
      assert is_binary(chart_data.svg)
      assert is_nil(chart_data.error)
    end

    test "handles multi-field grouping" do
      grouped_aggregation_state = %{
        [:region, :quarter] => %{
          {"North", "Q1"} => %{sum: %{amount: 4000}, count: 15},
          {"North", "Q2"} => %{sum: %{amount: 5000}, count: 18},
          {"South", "Q1"} => %{sum: %{amount: 3500}, count: 12}
        }
      }

      chart_config = %{
        name: :regional_quarterly_sales,
        chart_type: :bar,
        aggregation_ref: %{
          group_by: [:region, :quarter],
          aggregation_type: :sum,
          field: :amount
        },
        chart_config: %{width: 700, height: 450},
        embed_options: %{}
      }

      result = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        [chart_config]
      )

      chart_data = result[:regional_quarterly_sales]

      assert is_binary(chart_data.svg)
      assert is_binary(chart_data.embedded_code)
      # Multi-field groups are formatted as "North - Q1" in the SVG data
      assert chart_data.svg =~ "North"
      assert is_nil(chart_data.error)
    end

    test "generates error placeholder when aggregation not found" do
      # Empty aggregation state
      grouped_aggregation_state = %{}

      chart_config = %{
        name: :missing_chart,
        chart_type: :bar,
        aggregation_ref: %{
          group_by: :region,
          aggregation_type: :sum,
          field: :amount
        },
        chart_config: %{},
        embed_options: %{}
      }

      result = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        [chart_config]
      )

      chart_data = result[:missing_chart]

      assert chart_data.error == :aggregation_not_found
      assert chart_data.embedded_code =~ "Chart Error"
      assert chart_data.embedded_code =~ "missing_chart"
      assert is_nil(chart_data.svg)
    end

    test "handles multiple charts" do
      grouped_aggregation_state = %{
        [:region] => %{
          "North" => %{sum: %{amount: 15000}, count: 50}
        },
        [:category] => %{
          "Electronics" => %{count: 150}
        }
      }

      chart_configs = [
        %{
          name: :chart1,
          chart_type: :bar,
          aggregation_ref: %{group_by: :region, aggregation_type: :sum, field: :amount},
          chart_config: %{},
          embed_options: %{}
        },
        %{
          name: :chart2,
          chart_type: :pie,
          aggregation_ref: %{group_by: :category, aggregation_type: :count, field: nil},
          chart_config: %{},
          embed_options: %{}
        }
      ]

      result = ChartDataCollector.convert_aggregations_to_charts(
        grouped_aggregation_state,
        chart_configs
      )

      assert Map.has_key?(result, :chart1)
      assert Map.has_key?(result, :chart2)
      assert is_nil(result[:chart1].error)
      assert is_nil(result[:chart2].error)
    end
  end
end
