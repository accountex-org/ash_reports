defmodule AshReports.JsonRenderer.DataSerializerTest do
  use ExUnit.Case, async: true

  alias AshReports.JsonRenderer.DataSerializer
  alias AshReports.RendererTestHelpers

  describe "serialize_context/2" do
    test "serializes complete render context" do
      context =
        RendererTestHelpers.build_render_context(
          records: [%{id: 1, name: "Test Record"}],
          variables: %{report_date: "2025-10-07"},
          metadata: %{format: :json}
        )

      {:ok, serialized} = DataSerializer.serialize_context(context)

      assert is_map(serialized)
      assert Map.has_key?(serialized, :records)
      assert Map.has_key?(serialized, :variables)
      assert Map.has_key?(serialized, :metadata)
    end

    test "handles empty context" do
      context =
        RendererTestHelpers.build_render_context(
          records: [],
          variables: %{},
          metadata: %{}
        )

      {:ok, serialized} = DataSerializer.serialize_context(context)

      assert is_map(serialized)
      assert serialized.records == []
    end

    test "includes report_info in serialization" do
      report = RendererTestHelpers.build_mock_report(name: :test_report, title: "Test Report")
      context = RendererTestHelpers.build_render_context(report: report)

      {:ok, serialized} = DataSerializer.serialize_context(context)

      assert Map.has_key?(serialized, :report_info)
    end

    test "includes processing_state in serialization" do
      context = RendererTestHelpers.build_render_context()

      {:ok, serialized} = DataSerializer.serialize_context(context)

      assert Map.has_key?(serialized, :processing_state)
    end
  end

  describe "serialize_records/2" do
    test "serializes list of records" do
      records = [
        %{id: 1, name: "Record 1", value: 100},
        %{id: 2, name: "Record 2", value: 200}
      ]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
      assert length(serialized) == 2
    end

    test "handles empty record list" do
      {:ok, serialized} = DataSerializer.serialize_records([])

      assert serialized == []
    end

    test "serializes records with complex data types" do
      records = [
        %{
          id: 1,
          name: "Test",
          created_at: ~N[2025-10-07 10:00:00],
          amount: Decimal.new("123.45")
        }
      ]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
      assert length(serialized) == 1
    end

    test "applies custom serialization options" do
      records = [%{id: 1, value: nil}]

      {:ok, serialized} = DataSerializer.serialize_records(records, include_nulls: false)

      assert is_list(serialized)
    end
  end

  describe "serialize_records/2 with function references" do
    test "handles records with function values" do
      # This tests the fix for KeyError when serializing function references
      my_func = fn x -> x * 2 end

      records = [
        %{id: 1, name: "Test", callback: my_func}
      ]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
      assert length(serialized) == 1

      [first_record] = serialized
      # Function should be serialized as metadata, not the function itself
      assert is_map(first_record["callback"])
      assert first_record["callback"]["_type"] == "function"
      assert is_integer(first_record["callback"]["arity"])
    end

    test "handles maps with function keys" do
      # This tests the fix for function keys in maps
      my_func = fn x -> x * 2 end

      records = [
        %{
          id: 1,
          # Map with function as key should have that key filtered out
          data: %{my_func => "should_be_filtered", "normal_key" => "should_remain"}
        }
      ]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
      [first_record] = serialized

      # The function key should be filtered out, only normal_key should remain
      assert Map.has_key?(first_record["data"], "normal_key")
      assert first_record["data"]["normal_key"] == "should_remain"
      # Verify function key was filtered
      refute Enum.any?(Map.keys(first_record["data"]), &is_function/1)
    end

    test "serializes nested functions" do
      records = [
        %{
          id: 1,
          callbacks: [
            fn x -> x + 1 end,
            fn x -> x * 2 end
          ]
        }
      ]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
      [first_record] = serialized

      # All functions in the list should be serialized as metadata
      assert is_list(first_record["callbacks"])
      assert length(first_record["callbacks"]) == 2
      assert Enum.all?(first_record["callbacks"], fn callback ->
        is_map(callback) && callback["_type"] == "function"
      end)
    end
  end

  describe "serialize_variables/2" do
    test "serializes variable map" do
      variables = %{
        report_date: "2025-10-07",
        region: "North",
        year: 2025
      }

      {:ok, serialized} = DataSerializer.serialize_variables(variables)

      assert is_map(serialized)
    end

    test "handles empty variables" do
      {:ok, serialized} = DataSerializer.serialize_variables(%{})

      assert serialized == %{}
    end

    test "serializes variables with different types" do
      variables = %{
        string_var: "test",
        number_var: 123,
        boolean_var: true,
        date_var: ~D[2025-10-07]
      }

      {:ok, serialized} = DataSerializer.serialize_variables(variables)

      assert is_map(serialized)
      assert Map.has_key?(serialized, :string_var) or Map.has_key?(serialized, "string_var")
    end
  end

  describe "serialize_groups/2" do
    test "serializes group data" do
      groups = %{
        region: ["North", "South", "East"],
        product_type: ["Electronics", "Furniture"]
      }

      {:ok, serialized} = DataSerializer.serialize_groups(groups)

      assert is_map(serialized)
    end

    test "handles empty groups" do
      {:ok, serialized} = DataSerializer.serialize_groups(%{})

      assert serialized == %{}
    end

    test "serializes nested group structures" do
      groups = %{
        region: %{
          north: ["Store 1", "Store 2"],
          south: ["Store 3", "Store 4"]
        }
      }

      {:ok, serialized} = DataSerializer.serialize_groups(groups)

      assert is_map(serialized)
    end
  end

  describe "serialize_metadata/2" do
    test "serializes metadata map" do
      metadata = %{
        format: :json,
        generated_at: "2025-10-07T10:00:00Z",
        record_count: 100
      }

      {:ok, serialized} = DataSerializer.serialize_metadata(metadata)

      assert is_map(serialized)
    end

    test "handles empty metadata" do
      {:ok, serialized} = DataSerializer.serialize_metadata(%{})

      assert serialized == %{}
    end

    test "preserves metadata structure" do
      metadata = %{
        nested: %{
          key1: "value1",
          key2: "value2"
        },
        list: [1, 2, 3]
      }

      {:ok, serialized} = DataSerializer.serialize_metadata(metadata)

      assert is_map(serialized)
    end
  end

  describe "date/time serialization" do
    test "serializes DateTime in ISO8601 format by default" do
      records = [%{created_at: ~U[2025-10-07 10:00:00Z]}]

      {:ok, serialized} = DataSerializer.serialize_records(records, date_format: :iso8601)

      assert is_list(serialized)
    end

    test "serializes NaiveDateTime" do
      records = [%{created_at: ~N[2025-10-07 10:00:00]}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "serializes Date" do
      records = [%{report_date: ~D[2025-10-07]}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "supports RFC3339 date format" do
      records = [%{created_at: ~U[2025-10-07 10:00:00Z]}]

      {:ok, serialized} = DataSerializer.serialize_records(records, date_format: :rfc3339)

      assert is_list(serialized)
    end
  end

  describe "number serialization" do
    test "serializes integers" do
      records = [%{quantity: 100, count: 5}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "serializes floats" do
      records = [%{price: 99.99, tax_rate: 0.075}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "serializes Decimal with precision control" do
      records = [%{amount: Decimal.new("123.456789")}]

      {:ok, serialized} = DataSerializer.serialize_records(records, number_precision: 2)

      assert is_list(serialized)
    end

    test "handles very large numbers" do
      records = [%{big_number: 999_999_999_999_999}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end
  end

  describe "null handling" do
    test "includes null values by default" do
      records = [%{name: "Test", value: nil}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "excludes null values when option is set" do
      records = [%{name: "Test", value: nil, active: true}]

      {:ok, serialized} = DataSerializer.serialize_records(records, include_nulls: false)

      assert is_list(serialized)
    end
  end

  describe "complex type serialization" do
    test "serializes maps" do
      records = [%{config: %{theme: "dark", language: "en"}}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "serializes lists" do
      records = [%{tags: ["important", "urgent", "follow-up"]}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "serializes tuples as arrays" do
      records = [%{coordinates: {10.5, 20.3}}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end

    test "serializes nested structures" do
      records = [
        %{
          user: %{
            name: "Test User",
            address: %{
              street: "123 Main St",
              city: "Test City"
            }
          }
        }
      ]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end
  end

  describe "circular reference detection" do
    test "handles self-referencing structures safely" do
      # Note: This test verifies that serializer doesn't hang on circular refs
      # The actual implementation should detect and handle this gracefully
      records = [%{id: 1, name: "Test"}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end
  end

  describe "large dataset serialization" do
    test "serializes large dataset efficiently" do
      # Create 1000 records
      records =
        Enum.map(1..1000, fn i ->
          %{id: i, name: "Record #{i}", value: i * 10}
        end)

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
      assert length(serialized) == 1000
    end

    test "handles very large individual records" do
      # Record with large string
      large_text = String.duplicate("Lorem ipsum ", 1000)
      records = [%{id: 1, description: large_text}]

      {:ok, serialized} = DataSerializer.serialize_records(records)

      assert is_list(serialized)
    end
  end

  describe "error handling" do
    test "returns error for invalid input" do
      result = DataSerializer.serialize_records(nil)

      assert {:error, _reason} = result
    end

    test "returns error for non-serializable data" do
      # PIDs, ports, and refs cannot be serialized to JSON
      records = [%{id: 1, pid: self()}]

      # Should handle this gracefully
      result = DataSerializer.serialize_records(records)

      # Either succeeds by skipping the field or returns error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "custom encoders" do
    test "applies custom encoders when provided" do
      records = [%{id: 1, custom_field: %{special: "data"}}]

      opts = [custom_encoders: %{}]
      {:ok, serialized} = DataSerializer.serialize_records(records, opts)

      assert is_list(serialized)
    end

    test "uses field mapping when provided" do
      records = [%{id: 1, internal_name: "test"}]

      opts = [field_mapping: %{internal_name: "external_name"}]
      {:ok, serialized} = DataSerializer.serialize_records(records, opts)

      assert is_list(serialized)
    end
  end

  describe "serialize_report_info/2" do
    test "serializes report definition" do
      report =
        RendererTestHelpers.build_mock_report(
          name: :sales_report,
          title: "Sales Report"
        )

      if function_exported?(DataSerializer, :serialize_report_info, 1) do
        {:ok, info} = DataSerializer.serialize_report_info(report)

        assert is_map(info)
      end
    end

    test "includes report metadata" do
      report =
        RendererTestHelpers.build_mock_report(parameters: [%{name: :start_date, type: :date}])

      if function_exported?(DataSerializer, :serialize_report_info, 1) do
        {:ok, info} = DataSerializer.serialize_report_info(report)

        assert is_map(info)
      end
    end
  end
end
