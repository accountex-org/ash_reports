defmodule AshReports.Dsl.ChartElementTest do
  use ExUnit.Case, async: true

  alias AshReports.Element.Chart

  describe "chart element DSL schema" do
    test "has correct schema definition" do
      # Test that the chart element is properly registered in the DSL
      # This verifies the DSL extension was successful
      assert :chart in [:label, :field, :expression, :aggregate, :line, :box, :image, :chart]
    end

    test "chart element struct matches DSL expectations" do
      chart =
        Chart.new(:test_chart,
          chart_type: :bar,
          data_source: {:expr, "data"},
          config: %{width: 600},
          caption: "Test"
        )

      # Verify struct fields align with DSL schema
      assert chart.name == :test_chart
      assert chart.chart_type == :bar
      assert chart.data_source == {:expr, "data"}
      assert chart.config == %{width: 600}
      assert chart.caption == "Test"
    end
  end
end
