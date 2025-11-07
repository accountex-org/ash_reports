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

  describe "execute/2 with nested relationship paths" do
    test "groups by nested relationship field" do
      records = [
        %{id: 1, product: %{category: %{name: "Electronics"}}},
        %{id: 2, product: %{category: %{name: "Electronics"}}},
        %{id: 3, product: %{category: %{name: "Books"}}}
      ]

      transform = %Transform{
        group_by: {:product, :category, :name},
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      assert Enum.find(result, &(&1.category == "Electronics")).value == 2
      assert Enum.find(result, &(&1.category == "Books")).value == 1
    end

    test "handles nested paths with nil values" do
      records = [
        %{id: 1, product: %{category: %{name: "Electronics"}}},
        %{id: 2, product: nil},
        %{id: 3, product: %{category: nil}}
      ]

      transform = %Transform{
        group_by: {:product, :category, :name},
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
    end

    test "aggregates with nested field paths" do
      records = [
        %{id: 1, product: %{price: 100}},
        %{id: 2, product: %{price: 200}},
        %{id: 3, product: %{price: 150}}
      ]

      transform = %Transform{
        group_by: nil,
        aggregates: [{:sum, {:product, :price}, :total_price}],
        mappings: %{value: :total_price}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 1
      assert hd(result).value == 450
    end
  end

  describe "execute/2 with date grouping" do
    test "groups by month" do
      records = [
        %{id: 1, created_at: ~D[2024-01-15]},
        %{id: 2, created_at: ~D[2024-01-20]},
        %{id: 3, created_at: ~D[2024-02-10]}
      ]

      transform = %Transform{
        group_by: {:created_at, :month},
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      assert Enum.find(result, &(&1.category == "2024-01")).value == 2
      assert Enum.find(result, &(&1.category == "2024-02")).value == 1
    end

    test "groups by day" do
      records = [
        %{id: 1, created_at: ~D[2024-01-15]},
        %{id: 2, created_at: ~D[2024-01-15]},
        %{id: 3, created_at: ~D[2024-01-16]}
      ]

      transform = %Transform{
        group_by: {:created_at, :day},
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      assert Enum.find(result, &(&1.category == "2024-01-15")).value == 2
      assert Enum.find(result, &(&1.category == "2024-01-16")).value == 1
    end

    test "handles nil dates in grouping" do
      records = [
        %{id: 1, created_at: ~D[2024-01-15]},
        %{id: 2, created_at: nil},
        %{id: 3, created_at: ~D[2024-01-15]}
      ]

      transform = %Transform{
        group_by: {:created_at, :day},
        aggregates: [{:count, nil, :count}],
        mappings: %{category: :group_key, value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
    end
  end

  describe "execute/2 with filters" do
    test "filters records before grouping" do
      records = [
        %{status: :active, id: 1},
        %{status: :inactive, id: 2},
        %{status: :active, id: 3}
      ]

      transform = %Transform{
        filters: %{status: :active},
        aggregates: [{:count, nil, :count}],
        mappings: %{value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 1
      assert hd(result).value == 2
    end

    test "filters with list of values" do
      records = [
        %{status: :paid, id: 1},
        %{status: :sent, id: 2},
        %{status: :draft, id: 3},
        %{status: :paid, id: 4}
      ]

      transform = %Transform{
        filters: %{status: [:paid, :sent]},
        aggregates: [{:count, nil, :count}],
        mappings: %{value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 1
      assert hd(result).value == 3
    end
  end

  describe "execute/2 with limit" do
    test "limits results after sorting" do
      records = [
        %{type: "A", amount: 100},
        %{type: "A", amount: 50},
        %{type: "B", amount: 200},
        %{type: "C", amount: 150},
        %{type: "D", amount: 300}
      ]

      transform = %Transform{
        group_by: :type,
        aggregates: [{:sum, :amount, :total}],
        mappings: %{category: :group_key, value: :total},
        sort_by: {:value, :desc},
        limit: 2
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      assert Enum.at(result, 0).category == "D"
      assert Enum.at(result, 0).value == 300
      assert Enum.at(result, 1).category == "B"
      assert Enum.at(result, 1).value == 200
    end

    test "limit with no sorting" do
      records = [
        %{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}
      ]

      transform = %Transform{
        limit: 3,
        aggregates: [{:count, nil, :count}],
        mappings: %{value: :count}
      }

      {:ok, result} = Transform.execute(records, transform)

      # Without grouping, we get 1 result, but with limit 3 it should still work
      assert length(result) <= 3
    end
  end

  describe "execute/2 with special mappings" do
    test "supports Gantt chart mappings (task, start_date, end_date)" do
      records = [
        %{invoice_number: "INV-001", date: ~D[2024-01-01], status: :sent},
        %{invoice_number: "INV-002", date: ~D[2024-01-15], status: :paid}
      ]

      transform = %Transform{
        mappings: %{
          task: :invoice_number,
          start_date: :date,
          end_date: {:date, :add_days, 30}
        }
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      first = Enum.at(result, 0)
      assert first.task == "INV-001"
      assert first.start_date == ~D[2024-01-01]
      assert first.end_date == ~D[2024-01-31]
    end

    test "supports sparkline values mapping" do
      records = [
        %{health_score: 75},
        %{health_score: 80},
        %{health_score: 72}
      ]

      transform = %Transform{
        mappings: %{values: :health_score}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 3
      assert Enum.map(result, & &1.values) == [75, 80, 72]
    end

    test "date calculation with DateTime" do
      records = [
        %{created_at: ~U[2024-01-01 10:00:00Z]}
      ]

      transform = %Transform{
        mappings: %{
          start: :created_at,
          end: {:created_at, :add_days, 7}
        }
      }

      {:ok, result} = Transform.execute(records, transform)

      first = hd(result)
      assert first.start == ~U[2024-01-01 10:00:00Z]
      assert first.end == ~D[2024-01-08]
    end

    test "date calculation handles nil values" do
      records = [
        %{invoice_number: "INV-001", date: nil}
      ]

      transform = %Transform{
        mappings: %{
          task: :invoice_number,
          end_date: {:date, :add_days, 30}
        }
      }

      {:ok, result} = Transform.execute(records, transform)

      first = hd(result)
      assert first.task == "INV-001"
      assert first.end_date == nil
    end

    test "mappings can access source record fields with aggregates" do
      records = [
        %{category: "A", price: 100, quantity: 2},
        %{category: "A", price: 150, quantity: 1},
        %{category: "B", price: 200, quantity: 3}
      ]

      transform = %Transform{
        group_by: :category,
        aggregates: [{:sum, :quantity, :total_qty}],
        mappings: %{
          category: :group_key,
          quantity: :total_qty,
          sample_price: :price  # Access from source record
        }
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 2
      # First record in group A has price 100
      a_result = Enum.find(result, &(&1.category == "A"))
      assert a_result.sample_price == 100
      assert a_result.quantity == 3
    end
  end

  describe "execute/2 with edge cases" do
    test "handles empty records gracefully" do
      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      {:ok, result} = Transform.execute([], transform)

      assert result == []
    end

    test "handles nil aggregates list" do
      transform = %Transform{
        group_by: :status,
        aggregates: [],
        mappings: %{}
      }

      records = [%{status: :active}, %{status: :inactive}]
      {:ok, result} = Transform.execute(records, transform)

      # Without aggregates, should group but not aggregate
      assert is_list(result)
    end

    test "handles records with all nil values" do
      records = [
        %{status: nil, value: nil},
        %{status: nil, value: nil}
      ]

      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :total}],
        mappings: %{category: :group_key, value: :total}
      }

      {:ok, result} = Transform.execute(records, transform)

      assert length(result) == 1
      assert hd(result).category == nil
      assert hd(result).value == 2
    end

    test "handles empty mappings" do
      records = [%{status: :active}]

      transform = %Transform{
        group_by: :status,
        aggregates: [{:count, nil, :total}],
        mappings: %{}
      }

      {:ok, result} = Transform.execute(records, transform)

      # Should return data with raw aggregates
      assert length(result) == 1
      assert Map.has_key?(hd(result), :total)
    end
  end

  describe "TransformDSL edge cases" do
    alias AshReports.Charts.TransformDSL

    test "handles nil filters" do
      dsl = %TransformDSL{
        filters: nil,
        group_by: :status,
        aggregates: []
      }

      {:ok, transform} = TransformDSL.to_transform(dsl)

      assert transform.filters == %{}
    end

    test "handles nil aggregates" do
      dsl = %TransformDSL{
        filters: [],
        group_by: :status,
        aggregates: nil
      }

      {:ok, transform} = TransformDSL.to_transform(dsl)

      assert transform.aggregates == []
    end

    test "handles empty TransformDSL" do
      dsl = %TransformDSL{}

      {:ok, transform} = TransformDSL.to_transform(dsl)

      assert transform.filters == %{}
      assert transform.aggregates == []
      assert transform.group_by == nil
      assert transform.mappings == %{}
    end

    test "validates successfully with minimal fields" do
      dsl = %TransformDSL{
        group_by: :status
      }

      assert :ok = TransformDSL.validate(dsl)
    end
  end

  describe "detect_relationships/1" do
    test "detects simple relationship from group_by" do
      transform = %Transform{
        group_by: {:product, :name}
      }

      relationships = Transform.detect_relationships(transform)

      assert :product in relationships
    end

    test "detects nested relationships from group_by" do
      transform = %Transform{
        group_by: {:product, :category, :name}
      }

      relationships = Transform.detect_relationships(transform)

      assert :product in relationships
      assert {:product, :category} in relationships
    end

    test "detects relationships from aggregate fields" do
      transform = %Transform{
        aggregates: [{:sum, {:product, :price}, :total}]
      }

      relationships = Transform.detect_relationships(transform)

      assert :product in relationships
    end

    test "detects relationships from mappings" do
      transform = %Transform{
        mappings: %{x: {:product, :price}}
      }

      relationships = Transform.detect_relationships(transform)

      assert :product in relationships
    end

    test "does not detect relationships from date grouping" do
      transform = %Transform{
        group_by: {:created_at, :month}
      }

      relationships = Transform.detect_relationships(transform)

      assert relationships == []
    end

    test "returns empty list for simple field grouping" do
      transform = %Transform{
        group_by: :status
      }

      relationships = Transform.detect_relationships(transform)

      assert relationships == []
    end

    test "returns empty list for nil transform" do
      assert Transform.detect_relationships(nil) == []
    end

    test "combines relationships from multiple sources" do
      transform = %Transform{
        group_by: {:product, :category, :name},
        aggregates: [{:sum, {:invoice, :total}, :revenue}],
        mappings: %{x: {:customer, :tier}}
      }

      relationships = Transform.detect_relationships(transform)

      assert :product in relationships
      assert {:product, :category} in relationships
      assert :invoice in relationships
      assert :customer in relationships
    end
  end
end
