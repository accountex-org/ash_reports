defmodule AshReports.Charts.AggregatorTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Aggregator

  describe "sum/2" do
    test "calculates sum of numeric values" do
      data = [
        %{amount: 100},
        %{amount: 200},
        %{amount: 150}
      ]

      assert Aggregator.sum(data, :amount) == 450
    end

    test "handles nil values" do
      data = [
        %{amount: 100},
        %{amount: nil},
        %{amount: 200}
      ]

      assert Aggregator.sum(data, :amount) == 300
    end

    test "returns 0 for empty data" do
      assert Aggregator.sum([], :amount) == 0
    end
  end

  describe "count/2" do
    test "counts non-nil values" do
      data = [
        %{amount: 100},
        %{amount: 200},
        %{amount: 150}
      ]

      assert Aggregator.count(data, :amount) == 3
    end

    test "excludes nil values" do
      data = [
        %{amount: 100},
        %{amount: nil},
        %{amount: 200}
      ]

      assert Aggregator.count(data, :amount) == 2
    end
  end

  describe "avg/2" do
    test "calculates average" do
      data = [
        %{amount: 10},
        %{amount: 20},
        %{amount: 30}
      ]

      assert Aggregator.avg(data, :amount) == 20.0
    end

    test "returns 0.0 for empty data" do
      assert Aggregator.avg([], :amount) == 0.0
    end
  end

  describe "field_min/2" do
    test "finds minimum value" do
      data = [
        %{amount: 100},
        %{amount: 50},
        %{amount: 200}
      ]

      assert Aggregator.field_min(data, :amount) == 50
    end

    test "returns nil for empty data" do
      assert Aggregator.field_min([], :amount) == nil
    end
  end

  describe "field_max/2" do
    test "finds maximum value" do
      data = [
        %{amount: 100},
        %{amount: 50},
        %{amount: 200}
      ]

      assert Aggregator.field_max(data, :amount) == 200
    end

    test "returns nil for empty data" do
      assert Aggregator.field_max([], :amount) == nil
    end
  end

  describe "group_by/4" do
    test "groups and aggregates data" do
      data = [
        %{category: "A", amount: 100},
        %{category: "B", amount: 200},
        %{category: "A", amount: 50}
      ]

      result = Aggregator.group_by(data, :category, :amount, :sum)

      assert length(result) == 2
      assert Enum.find(result, &(&1.category == "A")).value == 150
      assert Enum.find(result, &(&1.category == "B")).value == 200
    end

    test "supports different aggregations" do
      data = [
        %{category: "A", amount: 100},
        %{category: "A", amount: 200}
      ]

      result = Aggregator.group_by(data, :category, :amount, :avg)
      assert Enum.find(result, &(&1.category == "A")).value == 150.0
    end
  end

  describe "aggregate/2" do
    test "applies multiple aggregations" do
      data = [
        %{amount: 100},
        %{amount: 200},
        %{amount: 300}
      ]

      result =
        Aggregator.aggregate(data, [
          {:total, :amount, :sum},
          {:average, :amount, :avg},
          {:count, :amount, :count}
        ])

      assert result.total == 600
      assert result.average == 200.0
      assert result.count == 3
    end
  end
end
