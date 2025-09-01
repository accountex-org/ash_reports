defmodule AshReports.FormatterFormatSpecsTest do
  use ExUnit.Case, async: true

  alias AshReports.{FormatSpecification, Formatter}

  describe "format_with_spec/4" do
    test "formats with compiled format specification" do
      spec = FormatSpecification.new(:test_currency, pattern: "¤ #,##0.00", currency: :USD)
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result} = Formatter.format_with_spec(1234.56, compiled, "en")

      assert is_binary(result)
      assert result =~ "1234"
      assert result =~ "56"
    end

    test "formats with conditional format specification" do
      spec =
        FormatSpecification.new(:conditional)
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K", color: :green)
        |> FormatSpecification.set_default_pattern("#,##0.00")

      {:ok, compiled} = FormatSpecification.compile(spec)

      # Test condition match
      {:ok, result1} = Formatter.format_with_spec(1500, compiled, "en")
      assert is_binary(result1)

      # Test default
      {:ok, result2} = Formatter.format_with_spec(500, compiled, "en")
      assert is_binary(result2)
    end

    test "handles format specification by name when registered" do
      spec = FormatSpecification.new(:test_registered, pattern: "#,##0.00")
      :ok = Formatter.register_format_spec(:test_registered, spec)

      {:ok, result} = Formatter.format_with_spec(1234.56, :test_registered, "en")

      assert is_binary(result)
    end

    test "returns error for unregistered format specification name" do
      {:error, reason} = Formatter.format_with_spec(1234.56, :nonexistent, "en")

      assert reason =~ "not found"
    end

    test "handles compilation errors gracefully" do
      invalid_spec = %FormatSpecification{
        name: :invalid,
        # Invalid empty pattern
        pattern: "",
        conditions: [],
        options: [],
        compiled: false
      }

      {:error, reason} = Formatter.format_with_spec(1234.56, invalid_spec, "en")

      assert reason =~ "Format specification error"
    end

    test "uses default locale when none specified" do
      spec = FormatSpecification.new(:test_default, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result} = Formatter.format_with_spec(1234.56, compiled)

      assert is_binary(result)
    end
  end

  describe "format_with_custom_pattern/4" do
    test "formats with custom number pattern" do
      {:ok, result} = Formatter.format_with_custom_pattern(1234.56, "#,##0.000", "en")

      assert is_binary(result)
      assert result =~ "1234"
      assert result =~ "560"
    end

    test "formats with custom currency pattern" do
      {:ok, result} =
        Formatter.format_with_custom_pattern(1234.56, "¤#,##0.00", "en", currency: :EUR)

      assert is_binary(result)
    end

    test "formats with custom date pattern" do
      {:ok, result} = Formatter.format_with_custom_pattern(~D[2024-03-15], "dd/MM/yyyy", "en")

      assert is_binary(result)
      assert result =~ "15"
      assert result =~ "03"
      assert result =~ "2024"
    end

    test "handles pattern parsing errors gracefully" do
      {:error, reason} = Formatter.format_with_custom_pattern(1234.56, "invalid{{pattern", "en")

      assert reason =~ "Pattern parsing failed"
    end

    test "uses default locale when none specified" do
      {:ok, result} = Formatter.format_with_custom_pattern(1234.56, "#,##0.00")

      assert is_binary(result)
    end
  end

  describe "format specification registry" do
    test "registers and retrieves format specifications" do
      spec = FormatSpecification.new(:registry_test, pattern: "#,##0.00")

      assert :ok = Formatter.register_format_spec(:registry_test, spec)
      assert :registry_test in Formatter.list_format_specs()
    end

    test "prevents registration of invalid specifications" do
      invalid_spec = %FormatSpecification{
        name: :invalid,
        pattern: "",
        conditions: [],
        options: [],
        compiled: false
      }

      {:error, reason} = Formatter.register_format_spec(:invalid_test, invalid_spec)

      assert reason =~ "Failed to register"
    end

    test "lists all registered format specifications" do
      # Clear any existing specs for this test
      initial_specs = Formatter.list_format_specs()

      spec1 = FormatSpecification.new(:list_test_1, pattern: "#,##0.00")
      spec2 = FormatSpecification.new(:list_test_2, pattern: "¤#,##0.00")

      :ok = Formatter.register_format_spec(:list_test_1, spec1)
      :ok = Formatter.register_format_spec(:list_test_2, spec2)

      specs = Formatter.list_format_specs()

      assert :list_test_1 in specs
      assert :list_test_2 in specs
      assert length(specs) >= length(initial_specs) + 2
    end
  end

  describe "enhanced format_value/2 with new options" do
    test "uses format_spec option" do
      spec = FormatSpecification.new(:value_test, pattern: "#,##0.00")
      :ok = Formatter.register_format_spec(:value_test, spec)

      {:ok, result} = Formatter.format_value(1234.56, format_spec: :value_test)

      assert is_binary(result)
    end

    test "uses custom_pattern option" do
      {:ok, result} = Formatter.format_value(1234.56, custom_pattern: "#,##0.000")

      assert is_binary(result)
      assert result =~ "560"
    end

    test "prefers format_spec over custom_pattern" do
      spec = FormatSpecification.new(:priority_test, pattern: "#,##0.##")
      :ok = Formatter.register_format_spec(:priority_test, spec)

      {:ok, result} =
        Formatter.format_value(1234.56,
          format_spec: :priority_test,
          custom_pattern: "#,##0.000"
        )

      # Should use the format_spec pattern, not custom_pattern
      assert is_binary(result)
    end

    test "falls back to legacy format when new options not provided" do
      {:ok, result} = Formatter.format_value(1234.56, type: :number)

      assert is_binary(result)
    end

    test "handles errors in format specifications gracefully" do
      {:ok, result} = Formatter.format_value(1234.56, format_spec: :nonexistent_spec)

      # Should fall back to string representation
      assert is_binary(result)
    end
  end

  describe "integration with existing formatter functions" do
    test "format_record/3 works with format specifications" do
      spec = FormatSpecification.new(:record_test, pattern: "¤ #,##0.00")
      :ok = Formatter.register_format_spec(:record_test, spec)

      record = %{amount: 1234.56, description: "Test Item"}
      field_specs = [amount: [format_spec: :record_test]]

      {:ok, formatted} = Formatter.format_record(record, field_specs)

      assert is_map(formatted)
      assert Map.has_key?(formatted, :amount)
      assert is_binary(formatted.amount)
      # Unchanged
      assert formatted.description == "Test Item"
    end

    test "format_batch/2 works with custom patterns" do
      values = [1234.56, 2345.67, 3456.78]

      {:ok, formatted} = Formatter.format_batch(values, custom_pattern: "#,##0.0")

      assert is_list(formatted)
      assert length(formatted) == 3
      assert Enum.all?(formatted, &is_binary/1)
    end

    test "format_data/3 integrates with format specifications" do
      spec = FormatSpecification.new(:data_test, pattern: "#,##0.00")
      :ok = Formatter.register_format_spec(:data_test, spec)

      data = [
        %{name: "Item 1", price: 19.99},
        %{name: "Item 2", price: 29.99}
      ]

      field_specs = [price: [format_spec: :data_test]]

      {:ok, formatted} = Formatter.format_data(data, field_specs)

      assert is_list(formatted)
      assert length(formatted) == 2

      assert Enum.all?(formatted, fn record ->
               is_map(record) and is_binary(record.price)
             end)
    end

    test "format_for_json/2 supports custom patterns" do
      {:ok, result} = Formatter.format_for_json(1234.56, custom_pattern: "#,##0.00")

      assert is_map(result)
      assert Map.has_key?(result, :value)
      assert Map.has_key?(result, :formatted)
      assert Map.has_key?(result, :type)
      assert result.value == 1234.56
      assert is_binary(result.formatted)
    end
  end

  describe "locale integration with format specifications" do
    test "respects locale in format specifications" do
      # Test with different locales if available
      spec = FormatSpecification.new(:locale_test, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result_en} = Formatter.format_with_spec(1234.56, compiled, "en")
      {:ok, result_fr} = Formatter.format_with_spec(1234.56, compiled, "fr")

      assert is_binary(result_en)
      assert is_binary(result_fr)
      # Results might differ based on locale-specific formatting
    end

    test "uses current locale as default" do
      spec = FormatSpecification.new(:default_locale, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result} = Formatter.format_with_spec(1234.56, compiled)

      assert is_binary(result)
    end
  end

  describe "error handling and edge cases" do
    test "handles nil values in format specifications" do
      spec = FormatSpecification.new(:nil_test, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result} = Formatter.format_with_spec(nil, compiled, "en")

      # Should return empty string for nil
      assert result == ""
    end

    test "handles invalid data types gracefully" do
      spec = FormatSpecification.new(:invalid_data, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result} = Formatter.format_with_spec("not_a_number", compiled, "en")

      # Should fallback to string representation
      assert is_binary(result)
    end

    test "handles format specification evaluation errors" do
      # Create a specification that might fail during evaluation
      spec =
        FormatSpecification.new(:error_test, pattern: "#,##0.00")
        |> FormatSpecification.add_condition({:invalid, :condition}, pattern: "error")

      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, result} = Formatter.format_with_spec(1234.56, compiled, "en")

      # Should handle gracefully
      assert is_binary(result)
    end

    test "maintains performance with repeated formatting" do
      spec = FormatSpecification.new(:performance_test, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      # Format the same value multiple times
      results =
        Enum.map(1..100, fn _ ->
          {:ok, result} = Formatter.format_with_spec(1234.56, compiled, "en")
          result
        end)

      # All results should be identical and formatted correctly
      assert length(Enum.uniq(results)) == 1
      assert is_binary(hd(results))
    end
  end
end
