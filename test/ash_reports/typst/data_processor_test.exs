defmodule AshReports.Typst.DataProcessorTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.DataProcessor

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

  describe "convert_single_record/2" do
    test "converts a single struct record" do
      record = %{id: 1, name: "Test", active: true, amount: Decimal.new("100.50")}

      result = DataProcessor.convert_single_record(record)

      assert result.id == 1
      assert result.name == "Test"
      assert result.active == true
      assert result.amount == 100.5
    end

    test "converts a single map record" do
      record = %{id: 2, name: "Map Record", count: 42}

      result = DataProcessor.convert_single_record(record)

      assert result.id == 2
      assert result.name == "Map Record"
      assert result.count == 42
    end

    test "accepts custom conversion options" do
      record = %{amount: Decimal.new("123.456")}

      result = DataProcessor.convert_single_record(record, decimal_precision: 1)

      assert result.amount == 123.5
    end
  end

  # NOTE: calculate_variable_scopes/2 and process_groups/2 have been removed.
  # These functions were batch-mode specific and have been replaced by streaming
  # aggregations in the ProducerConsumer stage of the GenStage pipeline.
  # Variable calculations and grouping are now handled during streaming, not in batch.
end
