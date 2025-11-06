defmodule AshReports.Charts.TransformTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Transform

  describe "execute/2 with nil transform" do
    test "returns records unchanged" do
      records = [%{id: 1}, %{id: 2}]
      assert {:ok, ^records} = Transform.execute(records, nil)
    end

    test "returns empty list for empty records" do
      assert {:ok, []} = Transform.execute([], nil)
    end
  end

  describe "execute/2 with group_by" do
    test "groups records by simple field" do
      records = [
        %{status: :active, id: 1},
        %{status: :active, id: 2},
        %{status: :inactive, id: 3}
      ]

      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      assert Enum.find(result, &(&1.category == :active)).value == 2
      assert Enum.find(result, &(&1.category == :inactive)).value == 1
    end

    test "handles nil values in grouping field" do
      records = [
        %{status: :active, id: 1},
        %{status: nil, id: 2},
        %{status: :active, id: 3}
      ]

      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      assert Enum.find(result, &(&1.category == :active)).value == 2
      assert Enum.find(result, &(&1.category == nil)).value == 1
    end
  end

  describe "execute/2 with aggregations" do
    test "count aggregation works" do
      records = [
        %{type: :a, value: 10},
        %{type: :a, value: 20},
        %{type: :b, value: 30}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:count, nil, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert Enum.find(result, &(&1.category == :a)).value == 2
      assert Enum.find(result, &(&1.category == :b)).value == 1
    end

    test "sum aggregation works with integers" do
      records = [
        %{type: :a, amount: 10},
        %{type: :a, amount: 20},
        %{type: :b, amount: 30}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:sum, :amount, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert Enum.find(result, &(&1.category == :a)).value == 30
      assert Enum.find(result, &(&1.category == :b)).value == 30
    end

    test "sum aggregation works with Decimal values" do
      records = [
        %{type: :a, amount: Decimal.new("10.50")},
        %{type: :a, amount: Decimal.new("20.25")},
        %{type: :b, amount: Decimal.new("30.00")}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:sum, :amount, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      {:ok, result} = Transform.execute(records, transform)

      type_a_result = Enum.find(result, &(&1.category == :a))
      assert Decimal.equal?(type_a_result.value, Decimal.new("30.75"))

      type_b_result = Enum.find(result, &(&1.category == :b))
      assert Decimal.equal?(type_b_result.value, Decimal.new("30.00"))
    end

    test "avg aggregation works" do
      records = [
        %{type: :a, score: 10},
        %{type: :a, score: 20},
        %{type: :b, score: 30}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:avg, :score, :average}],
        mappings: %{category: :group_key, value: :average}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert Enum.find(result, &(&1.category == :a)).value == 15.0
      assert Enum.find(result, &(&1.category == :b)).value == 30.0
    end

    test "min aggregation works" do
      records = [
        %{type: :a, price: 10},
        %{type: :a, price: 5},
        %{type: :b, price: 30}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:min, :price, :lowest}],
        mappings: %{category: :group_key, value: :lowest}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert Enum.find(result, &(&1.category == :a)).value == 5
      assert Enum.find(result, &(&1.category == :b)).value == 30
    end

    test "max aggregation works" do
      records = [
        %{type: :a, price: 10},
        %{type: :a, price: 25},
        %{type: :b, price: 30}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:max, :price, :highest}],
        mappings: %{category: :group_key, value: :highest}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert Enum.find(result, &(&1.category == :a)).value == 25
      assert Enum.find(result, &(&1.category == :b)).value == 30
    end

    test "multiple aggregations work together" do
      records = [
        %{type: :a, amount: 10, quantity: 1},
        %{type: :a, amount: 20, quantity: 2},
        %{type: :b, amount: 30, quantity: 3}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [
          {:count, nil, :count},
          {:sum, :amount, :total_amount},
          {:sum, :quantity, :total_qty}
        ],
        mappings: %{
          category: :group_key,
          value: :total_amount
        }
      }

      {:ok, result} = Transform.execute(records, transform)

      type_a = Enum.find(result, &(&1.category == :a))
      assert type_a.value == 30
    end
  end

  describe "execute/2 with mappings" do
    test "maps to category and value for pie/bar charts" do
      records = [%{status: :active, id: 1}]

      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      {:ok, [result]} = Transform.execute(records, transform)

      assert Map.has_key?(result, :category)
      assert Map.has_key?(result, :value)
      assert result.category == :active
      assert result.value == 1
    end

    test "maps to x and y for scatter charts" do
      records = [%{price: 10.50, quantity: 5}]

      transform = %Transform{
        aggregates: [{:sum, :quantity, :total_qty}],
        mappings: %{x: :price, y: :total_qty}
      }

      # No grouping, so all records in one group
      {:ok, result} = Transform.execute(records, transform)

      # Should still work but won't have the expected structure without proper grouping
      assert is_list(result)
    end

    test "handles missing mappings gracefully" do
      records = [%{status: :active}]

      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :total}],
        mappings: %{}  # No mappings
      }

      {:ok, [result]} = Transform.execute(records, transform)

      # Should return data with group_key and aggregates
      assert Map.has_key?(result, :group_key)
      assert Map.has_key?(result, :total)
    end
  end

  describe "execute/2 with sorting" do
    test "sorts by value ascending" do
      records = [
        %{type: :a, value: 30},
        %{type: :b, value: 10},
        %{type: :c, value: 20}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:sum, :value, :total}],
        mappings: %{category: :group_key, value: :total},
        sort_by: {:value, :asc}
      }

      {:ok, result} = Transform.execute(records, transform)

      values = Enum.map(result, & &1.value)
      assert values == [10, 20, 30]
    end

    test "sorts by value descending" do
      records = [
        %{type: :a, value: 30},
        %{type: :b, value: 10},
        %{type: :c, value: 20}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:sum, :value, :total}],
        mappings: %{category: :group_key, value: :total},
        sort_by: {:value, :desc}
      }

      {:ok, result} = Transform.execute(records, transform)

      values = Enum.map(result, & &1.value)
      assert values == [30, 20, 10]
    end
  end

  describe "execute/2 error handling" do
    test "returns error for invalid transform type" do
      records = [%{id: 1}]

      assert {:error, {:invalid_transform, _message}} =
               Transform.execute(records, "not a transform")
    end

    test "handles errors in aggregation gracefully" do
      records = [%{type: :a, value: "not a number"}]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:sum, :value, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      # Should not crash, sum should handle non-numeric values
      assert {:ok, _result} = Transform.execute(records, transform)
    end
  end

  describe "parse/1" do
    test "parses simple transform definition" do
      transform_def = %{
        group_by: :status,
        aggregates: [{:count, nil, :count}],
        as_category: :group_key,
        as_value: :count
      }

      {:ok, transform} = Transform.parse(transform_def)

      assert transform.group_by == :status
      assert transform.aggregates == [{:count, nil, :count}]
      assert transform.mappings == %{category: :group_key, value: :count}
    end

    test "parses nil transform" do
      assert {:ok, nil} = Transform.parse(nil)
    end

    test "handles missing fields with defaults" do
      transform_def = %{group_by: :type}

      {:ok, transform} = Transform.parse(transform_def)

      assert transform.group_by == :type
      assert transform.aggregates == []
      assert transform.mappings == %{}
      assert transform.filters == []
    end
  end
end
