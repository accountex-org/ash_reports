defmodule AshReports.Element.ChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Element.Chart

  describe "new/2" do
    test "creates a chart element with default values" do
      chart = Chart.new(:sales_chart)

      assert chart.name == :sales_chart
      assert chart.type == :chart
      assert chart.chart_type == :bar
      assert chart.embed_options == %{}
    end

    test "creates a chart element with all options" do
      chart =
        Chart.new(:sales_chart,
          chart_type: :line,
          data_source: {:expr, "some_data"},
          config: %{width: 600, height: 400},
          embed_options: %{width: "100%"},
          caption: "Sales Data",
          title: "Monthly Sales",
          conditional: {:expr, "show_chart"}
        )

      assert chart.name == :sales_chart
      assert chart.chart_type == :line
      assert chart.data_source == {:expr, "some_data"}
      assert chart.config == %{width: 600, height: 400}
      assert chart.embed_options == %{width: "100%"}
      assert chart.caption == "Sales Data"
      assert chart.title == "Monthly Sales"
      assert chart.conditional == {:expr, "show_chart"}
    end

    test "supports all chart types" do
      for type <- [:bar, :line, :pie, :area, :scatter] do
        chart = Chart.new(:test_chart, chart_type: type)
        assert chart.chart_type == type
      end
    end
  end
end
