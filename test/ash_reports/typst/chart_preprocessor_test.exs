defmodule AshReports.Typst.ChartPreprocessorTest do
  use ExUnit.Case, async: true

  alias AshReports.{Band, Report}
  alias AshReports.Element.Chart
  alias AshReports.Typst.ChartPreprocessor

  describe "preprocess/2" do
    test "returns empty map when report has no charts" do
      report = %Report{
        name: :empty_report,
        bands: [
          %Band{
            type: :title,
            name: :title_band,
            elements: []
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      assert {:ok, chart_data} = ChartPreprocessor.preprocess(report, data_context)
      assert chart_data == %{}
    end

    test "processes a single chart with static data" do
      chart_element =
        Chart.new(:sales_chart,
          chart_type: :bar,
          data_source: [
            %{category: "Q1", value: 100},
            %{category: "Q2", value: 150}
          ],
          config: %{width: 600, height: 400}
        )

      report = %Report{
        name: :sales_report,
        bands: [
          %Band{
            type: :header,
            name: :header_band,
            elements: [chart_element]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      assert {:ok, chart_data} = ChartPreprocessor.preprocess(report, data_context)
      assert map_size(chart_data) == 1
      assert Map.has_key?(chart_data, :sales_chart)

      chart = chart_data[:sales_chart]
      assert chart.name == :sales_chart
      assert chart.chart_type == :bar
      assert is_binary(chart.svg)
      assert is_binary(chart.embedded_code)
      assert is_nil(chart.error)
    end

    test "processes multiple charts in different bands" do
      chart1 =
        Chart.new(:chart1,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: %{width: 400, height: 300}
        )

      chart2 =
        Chart.new(:chart2,
          chart_type: :line,
          data_source: [%{x: "Jan", y: 20}],
          config: %{width: 500, height: 350}
        )

      report = %Report{
        name: :multi_chart_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart1]
          },
          %Band{
            type: :detail,
            name: :detail,
            elements: [chart2]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      assert {:ok, chart_data} = ChartPreprocessor.preprocess(report, data_context)
      assert map_size(chart_data) == 2
      assert Map.has_key?(chart_data, :chart1)
      assert Map.has_key?(chart_data, :chart2)

      assert chart_data[:chart1].chart_type == :bar
      assert chart_data[:chart2].chart_type == :line
    end

    test "handles chart with embed options" do
      chart_element =
        Chart.new(:sized_chart,
          chart_type: :pie,
          data_source: [
            %{label: "A", value: 30},
            %{label: "B", value: 70}
          ],
          config: %{width: 500, height: 500},
          embed_options: %{width: "80%", caption: "Revenue Split"}
        )

      report = %Report{
        name: :sized_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart_element]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      assert {:ok, chart_data} = ChartPreprocessor.preprocess(report, data_context)
      chart = chart_data[:sized_chart]

      # Embedded code should contain width specification
      assert chart.embedded_code =~ "width"
      assert is_nil(chart.error)
    end
  end

  describe "process_chart/2" do
    test "processes chart with static list data" do
      chart =
        Chart.new(:test_chart,
          chart_type: :bar,
          data_source: [%{category: "A", value: 100}],
          config: %{width: 600, height: 400}
        )

      data_context = %{records: [], config: %{}, variables: %{}}

      result = ChartPreprocessor.process_chart(chart, data_context)

      assert result.name == :test_chart
      assert result.chart_type == :bar
      assert is_binary(result.svg)
      assert is_binary(result.embedded_code)
      assert is_nil(result.error)
    end

    test "generates error placeholder for missing data source" do
      chart =
        Chart.new(:broken_chart,
          chart_type: :bar,
          data_source: nil,
          config: %{width: 600, height: 400}
        )

      data_context = %{records: [], config: %{}, variables: %{}}

      result = ChartPreprocessor.process_chart(chart, data_context)

      assert result.name == :broken_chart
      assert is_nil(result.svg)
      assert result.embedded_code =~ "Chart Error"
      assert result.embedded_code =~ "broken_chart"
      assert result.error == :missing_data_source
    end

    test "evaluates :records expression" do
      # Create an Ash.Expr-like struct for testing
      expr_struct = %{__struct__: Ash.Expr, expression: :records}

      chart =
        Chart.new(:records_chart,
          chart_type: :bar,
          data_source: expr_struct,
          config: %{width: 600, height: 400}
        )

      records = [
        %{category: "Q1", value: 100},
        %{category: "Q2", value: 200}
      ]

      data_context = %{records: records, config: %{}, variables: %{}}

      result = ChartPreprocessor.process_chart(chart, data_context)

      assert result.name == :records_chart
      assert is_binary(result.svg)
      assert is_nil(result.error)
    end

    test "handles all chart types" do
      data_context = %{records: [], config: %{}, variables: %{}}

      # Bar chart
      bar_chart =
        Chart.new(:bar_chart,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: %{width: 400, height: 300}
        )

      result = ChartPreprocessor.process_chart(bar_chart, data_context)
      assert result.chart_type == :bar
      assert is_binary(result.svg)
      assert is_nil(result.error)

      # Line chart
      line_chart =
        Chart.new(:line_chart,
          chart_type: :line,
          data_source: [%{x: 1, y: 10}],
          config: %{width: 400, height: 300}
        )

      result = ChartPreprocessor.process_chart(line_chart, data_context)
      assert result.chart_type == :line
      assert is_binary(result.svg)
      assert is_nil(result.error)

      # Pie chart
      pie_chart =
        Chart.new(:pie_chart,
          chart_type: :pie,
          data_source: [%{category: "A", value: 30}],
          config: %{width: 400, height: 300}
        )

      result = ChartPreprocessor.process_chart(pie_chart, data_context)
      assert result.chart_type == :pie
      assert is_binary(result.svg)
      assert is_nil(result.error)

      # Area chart
      area_chart =
        Chart.new(:area_chart,
          chart_type: :area,
          data_source: [%{x: 1, y: 10}],
          config: %{width: 400, height: 300}
        )

      result = ChartPreprocessor.process_chart(area_chart, data_context)
      assert result.chart_type == :area
      assert is_binary(result.svg)
      assert is_nil(result.error)

      # Scatter plot
      scatter_chart =
        Chart.new(:scatter_chart,
          chart_type: :scatter,
          data_source: [%{x: 1, y: 10}],
          config: %{width: 400, height: 300}
        )

      result = ChartPreprocessor.process_chart(scatter_chart, data_context)
      assert result.chart_type == :scatter
      assert is_binary(result.svg)
      assert is_nil(result.error)
    end
  end

  describe "evaluate_data_source/2" do
    test "returns static list data as-is" do
      data = [%{category: "A", value: 10}, %{category: "B", value: 20}]
      context = %{records: [], config: %{}, variables: %{}}

      # Call via process_chart to test indirectly
      chart =
        Chart.new(:test,
          chart_type: :bar,
          data_source: data,
          config: %{}
        )

      result = ChartPreprocessor.process_chart(chart, context)
      assert is_nil(result.error)
    end

    test "evaluates :records expression" do
      records = [%{category: "A", value: 10}]
      context = %{records: records, config: %{}, variables: %{}}

      # Create an Ash.Expr-like struct for testing
      expr_struct = %{__struct__: Ash.Expr, expression: :records}

      chart =
        Chart.new(:test,
          chart_type: :bar,
          data_source: expr_struct,
          config: %{}
        )

      result = ChartPreprocessor.process_chart(chart, context)
      assert is_nil(result.error)
      assert is_binary(result.svg)
    end
  end

  describe "evaluate_config/2" do
    test "returns map config as-is" do
      config = %{width: 600, height: 400, title: "Test Chart"}
      context = %{records: [], config: %{}, variables: %{}}

      chart =
        Chart.new(:test,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: config
        )

      result = ChartPreprocessor.process_chart(chart, context)
      assert is_nil(result.error)
    end

    test "handles nil config" do
      context = %{records: [], config: %{}, variables: %{}}

      chart =
        Chart.new(:test,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: nil
        )

      result = ChartPreprocessor.process_chart(chart, context)
      assert is_nil(result.error)
    end
  end

  describe "error handling" do
    test "generates error placeholder for chart generation failure" do
      # Invalid data format that will cause Charts.generate to fail
      chart =
        Chart.new(:invalid_chart,
          chart_type: :bar,
          data_source: "invalid_data_type",
          config: %{width: 600, height: 400}
        )

      data_context = %{records: [], config: %{}, variables: %{}}

      result = ChartPreprocessor.process_chart(chart, data_context)

      # Should have error but still provide embedded code
      assert result.error != nil
      assert is_binary(result.embedded_code)
      assert result.embedded_code =~ "#block"
      assert result.embedded_code =~ "Chart Error"
    end

    test "error placeholder contains chart name" do
      chart =
        Chart.new(:my_broken_chart,
          chart_type: :bar,
          data_source: nil,
          config: %{}
        )

      data_context = %{records: [], config: %{}, variables: %{}}

      result = ChartPreprocessor.process_chart(chart, data_context)

      assert result.embedded_code =~ "my_broken_chart"
      assert result.embedded_code =~ "Chart Error"
    end
  end

  describe "integration with ChartEmbedder" do
    test "embedded code uses ChartEmbedder format" do
      chart =
        Chart.new(:embedded_chart,
          chart_type: :bar,
          data_source: [%{category: "A", value: 100}],
          config: %{width: 600, height: 400},
          embed_options: %{width: "100%"}
        )

      data_context = %{records: [], config: %{}, variables: %{}}

      result = ChartPreprocessor.process_chart(chart, data_context)

      # ChartEmbedder generates #image.decode() calls
      assert result.embedded_code =~ "#image.decode"
      assert is_nil(result.error)
    end
  end

  describe "preprocess_lazy/2" do
    test "returns lazy evaluators for all charts" do
      chart1 =
        Chart.new(:chart1,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: %{width: 400, height: 300}
        )

      chart2 =
        Chart.new(:chart2,
          chart_type: :line,
          data_source: [%{x: 1, y: 20}],
          config: %{width: 500, height: 350}
        )

      report = %Report{
        name: :lazy_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart1, chart2]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      assert {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)
      assert map_size(lazy_charts) == 2
      assert Map.has_key?(lazy_charts, :chart1)
      assert Map.has_key?(lazy_charts, :chart2)

      # Verify they are functions
      assert is_function(lazy_charts[:chart1], 0)
      assert is_function(lazy_charts[:chart2], 0)
    end

    test "lazy evaluators generate charts when called" do
      chart =
        Chart.new(:sales_chart,
          chart_type: :bar,
          data_source: [%{category: "Q1", value: 100}],
          config: %{width: 600, height: 400}
        )

      report = %Report{
        name: :lazy_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)

      # Call the lazy evaluator
      result = lazy_charts[:sales_chart].()

      # Should return the same structure as process_chart
      assert result.name == :sales_chart
      assert result.chart_type == :bar
      assert is_binary(result.svg)
      assert is_binary(result.embedded_code)
      assert is_nil(result.error)
    end

    test "lazy evaluators can be called multiple times" do
      chart =
        Chart.new(:reusable_chart,
          chart_type: :pie,
          data_source: [%{label: "A", value: 30}, %{label: "B", value: 70}],
          config: %{width: 500, height: 500}
        )

      report = %Report{
        name: :lazy_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)

      # Call multiple times
      result1 = lazy_charts[:reusable_chart].()
      result2 = lazy_charts[:reusable_chart].()

      # Both should produce valid results
      assert is_binary(result1.svg)
      assert is_binary(result2.svg)
      assert is_nil(result1.error)
      assert is_nil(result2.error)
    end

    test "lazy evaluators handle errors gracefully" do
      chart =
        Chart.new(:broken_chart,
          chart_type: :bar,
          data_source: nil,
          config: %{width: 600, height: 400}
        )

      report = %Report{
        name: :lazy_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)

      # Call the lazy evaluator - should return error placeholder
      result = lazy_charts[:broken_chart].()

      assert result.error == :missing_data_source
      assert is_binary(result.embedded_code)
      assert result.embedded_code =~ "Chart Error"
    end

    test "lazy evaluation defers chart generation until called" do
      chart =
        Chart.new(:deferred_chart,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: %{width: 400, height: 300}
        )

      report = %Report{
        name: :lazy_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      # Create lazy charts - this should be fast (no SVG generation)
      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)

      # Verify we got a function back, not generated data
      assert is_function(lazy_charts[:deferred_chart], 0)

      # Now call the evaluator - this is when SVG generation happens
      result = lazy_charts[:deferred_chart].()

      # Verify the chart was generated on-demand
      assert is_binary(result.svg)
      assert result.name == :deferred_chart
      assert result.chart_type == :bar
      assert is_nil(result.error)
    end

    test "returns empty map for report with no charts" do
      report = %Report{
        name: :empty_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: []
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      assert {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)
      assert lazy_charts == %{}
    end

    test "supports selective chart generation" do
      chart1 =
        Chart.new(:needed_chart,
          chart_type: :bar,
          data_source: [%{category: "A", value: 10}],
          config: %{width: 400, height: 300}
        )

      chart2 =
        Chart.new(:unused_chart,
          chart_type: :line,
          data_source: [%{x: 1, y: 20}],
          config: %{width: 500, height: 350}
        )

      chart3 =
        Chart.new(:another_needed_chart,
          chart_type: :pie,
          data_source: [%{label: "A", value: 50}],
          config: %{width: 400, height: 400}
        )

      report = %Report{
        name: :selective_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart1, chart2, chart3]
          }
        ]
      }

      data_context = %{records: [], config: %{}, variables: %{}}

      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)

      # Only generate the charts we need
      result1 = lazy_charts[:needed_chart].()
      result3 = lazy_charts[:another_needed_chart].()

      # Verify the generated charts
      assert result1.chart_type == :bar
      assert is_binary(result1.svg)
      assert result3.chart_type == :pie
      assert is_binary(result3.svg)

      # chart2 was never generated, saving resources
      # We can still verify the lazy evaluator exists
      assert is_function(lazy_charts[:unused_chart], 0)
    end

    test "lazy evaluators work with dynamic data sources" do
      # Create an Ash.Expr-like struct for testing
      expr_struct = %{__struct__: Ash.Expr, expression: :records}

      chart =
        Chart.new(:dynamic_chart,
          chart_type: :bar,
          data_source: expr_struct,
          config: %{width: 600, height: 400}
        )

      report = %Report{
        name: :dynamic_report,
        bands: [
          %Band{
            type: :header,
            name: :header,
            elements: [chart]
          }
        ]
      }

      records = [
        %{category: "Q1", value: 100},
        %{category: "Q2", value: 200}
      ]

      data_context = %{records: records, config: %{}, variables: %{}}

      {:ok, lazy_charts} = ChartPreprocessor.preprocess_lazy(report, data_context)

      # Call the lazy evaluator
      result = lazy_charts[:dynamic_chart].()

      # Should successfully use the records from context
      assert result.name == :dynamic_chart
      assert is_binary(result.svg)
      assert is_nil(result.error)
    end
  end
end
