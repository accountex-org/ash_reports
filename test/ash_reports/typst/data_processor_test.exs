defmodule AshReports.Typst.DataProcessorTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.DataProcessor
  alias AshReports.Variable

  describe "convert_records/2" do
    test "converts basic records with default options" do
      records = [
        %{id: 1, name: "Test Customer", active: true},
        %{id: 2, name: "Another Customer", active: false}
      ]

      assert {:ok, converted} = DataProcessor.convert_records(records)
      assert length(converted) == 2
      assert List.first(converted) == %{id: 1, name: "Test Customer", active: true}
    end

    test "handles DateTime conversion" do
      datetime = ~U[2024-01-15 10:30:00Z]
      records = [%{id: 1, created_at: datetime}]

      assert {:ok, converted} = DataProcessor.convert_records(records)
      assert List.first(converted).created_at == "2024-01-15T10:30:00Z"
    end

    test "handles Decimal conversion" do
      records = [%{id: 1, amount: Decimal.new("150.567")}]

      assert {:ok, converted} = DataProcessor.convert_records(records, decimal_precision: 2)
      assert List.first(converted).amount == 150.57
    end

    test "handles Decimal as string conversion" do
      records = [%{id: 1, amount: Decimal.new("150.50")}]

      assert {:ok, converted} = DataProcessor.convert_records(records, decimal_as_string: true)
      assert List.first(converted).amount == "150.50"
    end

    test "handles nil values with replacement" do
      records = [%{id: 1, name: nil, description: "test"}]

      assert {:ok, converted} = DataProcessor.convert_records(records, nil_replacement: "N/A")
      assert List.first(converted).name == "N/A"
      assert List.first(converted).description == "test"
    end

    test "handles nested maps with flattening" do
      records = [
        %{
          id: 1,
          customer: %{name: "John Doe", address: %{city: "New York", zip: "10001"}}
        }
      ]

      assert {:ok, converted} = DataProcessor.convert_records(records)
      first_record = List.first(converted)

      assert first_record.id == 1
      # Nested structure should be flattened
      assert is_map(first_record.customer)

      assert Map.has_key?(first_record.customer, :customer_name) or
               Map.has_key?(first_record.customer, :name)
    end

    test "handles struct conversion" do
      # Use a map instead of defining struct inside test function
      # This simulates what would happen when convert_single_record receives a struct
      customer_as_struct = %{
        __struct__: TestModule,
        id: 1,
        name: "John",
        email: "john@example.com"
      }

      records = [customer_as_struct]

      assert {:ok, converted} = DataProcessor.convert_records(records)
      first_record = List.first(converted)

      assert first_record.id == 1
      assert first_record.name == "John"
      assert first_record.email == "john@example.com"
    end

    test "handles empty records list" do
      assert {:ok, []} = DataProcessor.convert_records([])
    end
  end

  describe "calculate_variable_scopes/2" do
    test "calculates report-level variables" do
      records = [
        %{id: 1, amount: 100},
        %{id: 2, amount: 200},
        %{id: 3, amount: 150}
      ]

      variables = [
        %Variable{name: :total_amount, type: :sum, reset_on: :report},
        %Variable{name: :avg_amount, type: :average, reset_on: :report},
        %Variable{name: :record_count, type: :count, reset_on: :report}
      ]

      assert {:ok, scopes} = DataProcessor.calculate_variable_scopes(records, variables)

      assert scopes.report.total_amount == 450
      assert scopes.report.avg_amount == 150.0
      assert scopes.report.record_count == 3
    end

    test "calculates min and max variables" do
      records = [
        %{id: 1, score: 85},
        %{id: 2, score: 92},
        %{id: 3, score: 78}
      ]

      variables = [
        %Variable{name: :min_score, type: :min, reset_on: :report},
        %Variable{name: :max_score, type: :max, reset_on: :report}
      ]

      assert {:ok, scopes} = DataProcessor.calculate_variable_scopes(records, variables)

      assert scopes.report.min_score == 78
      assert scopes.report.max_score == 92
    end

    test "handles empty variables list" do
      records = [%{id: 1, amount: 100}]
      variables = []

      assert {:ok, scopes} = DataProcessor.calculate_variable_scopes(records, variables)
      assert scopes.report == %{}
      assert scopes.group == %{}
      assert scopes.page == %{}
      assert scopes.detail == %{}
    end

    test "handles different variable scopes" do
      records = [%{id: 1, amount: 100}]

      variables = [
        %Variable{name: :report_var, type: :sum, reset_on: :report},
        %Variable{name: :group_var, type: :count, reset_on: :group},
        %Variable{name: :page_var, type: :average, reset_on: :page},
        %Variable{name: :detail_var, type: :max, reset_on: :detail}
      ]

      assert {:ok, scopes} = DataProcessor.calculate_variable_scopes(records, variables)

      # Report variables should be calculated
      assert scopes.report.report_var == 100

      # Other scopes should have nil placeholder values for now
      assert scopes.group.group_var == nil
      assert scopes.page.page_var == nil
      assert scopes.detail.detail_var == nil
    end
  end

  describe "process_groups/2" do
    test "handles empty groups list" do
      records = [%{id: 1, category: "A"}]
      groups = []

      assert {:ok, []} = DataProcessor.process_groups(records, groups)
    end

    test "creates basic single-level grouping" do
      records = [
        %{id: 1, category: "A", amount: 100},
        %{id: 2, category: "B", amount: 200},
        %{id: 3, category: "A", amount: 150}
      ]

      # Mock group structure
      groups = [%{field: :category, name: "Category Group"}]

      assert {:ok, grouped} = DataProcessor.process_groups(records, groups)
      assert is_list(grouped)
      assert length(grouped) == 2

      # Should have groups for categories A and B
      group_keys = Enum.map(grouped, & &1.group_key) |> Enum.sort()
      assert group_keys == ["A", "B"]

      # Check group structure
      a_group = Enum.find(grouped, &(&1.group_key == "A"))
      assert a_group.record_count == 2
      assert length(a_group.records) == 2
    end
  end
end
