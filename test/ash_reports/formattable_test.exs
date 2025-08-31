defmodule AshReports.FormattableTest do
  use ExUnit.Case, async: true

  alias AshReports.Formattable

  describe "Formattable protocol" do
    test "detects format types correctly" do
      assert Formattable.format_type(123) == :number
      assert Formattable.format_type(123.45) == :number
      assert Formattable.format_type(~D[2024-03-15]) == :date
      assert Formattable.format_type(~T[14:30:00]) == :time
      assert Formattable.format_type(~U[2024-03-15 14:30:00Z]) == :datetime
      assert Formattable.format_type(true) == :boolean
      assert Formattable.format_type(false) == :boolean
      assert Formattable.format_type("hello") == :string
      assert Formattable.format_type(:atom_value) == :string
    end

    test "formats values using protocol" do
      {:ok, result} = Formattable.format(123, [])
      assert is_binary(result)

      {:ok, result} = Formattable.format(123.45, [])
      assert is_binary(result)

      {:ok, result} = Formattable.format(true, [])
      assert result == "true"

      {:ok, result} = Formattable.format(false, [])
      assert result == "false"

      {:ok, result} = Formattable.format("hello", [])
      assert result == "hello"
    end

    test "handles different data types consistently" do
      values = [123, 123.45, ~D[2024-03-15], true, "test"]

      results =
        Enum.map(values, fn value ->
          case Formattable.format(value, []) do
            {:ok, formatted} -> {Formattable.format_type(value), formatted}
            {:error, _} -> {Formattable.format_type(value), "error"}
          end
        end)

      assert length(results) == 5

      assert Enum.all?(results, fn {type, formatted} ->
               is_atom(type) and is_binary(formatted)
             end)
    end
  end
end
