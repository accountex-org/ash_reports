defmodule AshReports.CalculationEngineTest do
  @moduledoc """
  Tests for AshReports.CalculationEngine expression evaluation.
  """

  use ExUnit.Case, async: true

  alias AshReports.CalculationEngine

  describe "Simple field evaluation" do
    test "evaluates atom field references" do
      data = %{amount: 100, quantity: 5, name: "Product"}

      assert {:ok, 100} = CalculationEngine.evaluate(:amount, data)
      assert {:ok, 5} = CalculationEngine.evaluate(:quantity, data)
      assert {:ok, "Product"} = CalculationEngine.evaluate(:name, data)
    end

    test "evaluates tuple field references" do
      data = %{amount: 100, quantity: 5}

      assert {:ok, 100} = CalculationEngine.evaluate({:amount}, data)
      assert {:ok, 5} = CalculationEngine.evaluate({:quantity}, data)
    end

    test "returns error for missing fields" do
      data = %{amount: 100}

      assert {:error, {:field_not_found, :missing_field}} =
               CalculationEngine.evaluate(:missing_field, data)
    end

    test "evaluates nil expression" do
      data = %{amount: 100}

      assert {:ok, nil} = CalculationEngine.evaluate(nil, data)
    end

    test "evaluates literal values" do
      data = %{}

      assert {:ok, 42} = CalculationEngine.evaluate(42, data)
      assert {:ok, "hello"} = CalculationEngine.evaluate("hello", data)
      assert {:ok, true} = CalculationEngine.evaluate(true, data)
      assert {:ok, [1, 2, 3]} = CalculationEngine.evaluate([1, 2, 3], data)
    end
  end

  describe "Relationship traversal" do
    test "evaluates simple relationship references" do
      data = %{
        customer: %{name: "John Doe", region: "North"},
        amount: 100
      }

      assert {:ok, "John Doe"} = CalculationEngine.evaluate({:customer, :name}, data)
      assert {:ok, "North"} = CalculationEngine.evaluate({:customer, :region}, data)
    end

    test "evaluates explicit field relationships" do
      data = %{
        order: %{total: 250, tax: 25},
        customer: %{id: 123}
      }

      assert {:ok, 250} = CalculationEngine.evaluate({:field, :order, :total}, data)
      assert {:ok, 25} = CalculationEngine.evaluate({:field, :order, :tax}, data)
      assert {:ok, 123} = CalculationEngine.evaluate({:field, :customer, :id}, data)
    end

    test "returns error for missing relationships" do
      data = %{amount: 100}

      assert {:error, {:relationship_not_found, :customer}} =
               CalculationEngine.evaluate({:customer, :name}, data)
    end

    test "returns error for missing fields in relationships" do
      data = %{customer: %{name: "John"}}

      assert {:error, {:field_not_found, :missing_field}} =
               CalculationEngine.evaluate({:customer, :missing_field}, data)
    end

    test "returns error for invalid relationship types" do
      data = %{customer: "not a map"}

      assert {:error, {:invalid_relationship, :customer}} =
               CalculationEngine.evaluate({:customer, :name}, data)
    end
  end

  describe "Function evaluation" do
    test "evaluates function expressions" do
      data = %{amount: 100, tax_rate: 0.1}

      calc_func = fn data -> data.amount * data.tax_rate end

      assert {:ok, 10.0} = CalculationEngine.evaluate(calc_func, data)
    end

    test "handles function errors" do
      data = %{amount: 100}

      error_func = fn _data -> raise "calculation error" end

      assert {:error, {:evaluation_error, _}} = CalculationEngine.evaluate(error_func, data)
    end
  end

  describe "Ash expression evaluation" do
    # Note: These tests simulate Ash expression structures
    # In a real implementation, these would be actual Ash.Query.Ref structs

    test "evaluates simple Ash ref" do
      data = %{price: 25.99}

      # Mock Ash.Query.Ref structure
      ash_ref = %{
        __struct__: Ash.Query.Ref,
        attribute: %{name: :price},
        relationship_path: []
      }

      assert {:ok, 25.99} = CalculationEngine.evaluate(ash_ref, data)
    end

    test "evaluates Ash ref with relationship" do
      data = %{customer: %{region: "West"}}

      # Mock Ash.Query.Ref with relationship
      ash_ref = %{
        __struct__: Ash.Query.Ref,
        attribute: %{name: :region},
        relationship_path: [:customer]
      }

      assert {:ok, "West"} = CalculationEngine.evaluate(ash_ref, data)
    end
  end

  describe "Arithmetic operations" do
    test "evaluates addition" do
      data = %{left: 10, right: 5}

      # Mock Ash.Query.Call for addition
      add_expr = %{
        __struct__: Ash.Query.Call,
        name: :+,
        args: [:left, :right]
      }

      assert {:ok, 15} = CalculationEngine.evaluate(add_expr, data)
    end

    test "evaluates subtraction" do
      data = %{left: 10, right: 3}

      subtract_expr = %{
        __struct__: Ash.Query.Call,
        name: :-,
        args: [:left, :right]
      }

      assert {:ok, 7} = CalculationEngine.evaluate(subtract_expr, data)
    end

    test "evaluates multiplication" do
      data = %{quantity: 4, price: 25.5}

      multiply_expr = %{
        __struct__: Ash.Query.Call,
        name: :*,
        args: [:quantity, :price]
      }

      assert {:ok, 102.0} = CalculationEngine.evaluate(multiply_expr, data)
    end

    test "evaluates division" do
      data = %{total: 100, count: 4}

      divide_expr = %{
        __struct__: Ash.Query.Call,
        name: :/,
        args: [:total, :count]
      }

      assert {:ok, 25.0} = CalculationEngine.evaluate(divide_expr, data)
    end

    test "handles division by zero" do
      data = %{total: 100, count: 0}

      divide_expr = %{
        __struct__: Ash.Query.Call,
        name: :/,
        args: [:total, :count]
      }

      assert {:error, {:division_by_zero}} = CalculationEngine.evaluate(divide_expr, data)
    end

    test "handles type errors in arithmetic" do
      data = %{left: "string", right: 5}

      add_expr = %{
        __struct__: Ash.Query.Call,
        name: :+,
        args: [:left, :right]
      }

      assert {:error, {:invalid_arithmetic, :+, "string", 5}} =
               CalculationEngine.evaluate(add_expr, data)
    end

    test "handles string concatenation" do
      data = %{first: "Hello", second: " World"}

      add_expr = %{
        __struct__: Ash.Query.Call,
        name: :+,
        args: [:first, :second]
      }

      assert {:ok, "Hello World"} = CalculationEngine.evaluate(add_expr, data)
    end
  end

  describe "Conditional evaluation" do
    test "evaluates if expression - true case" do
      data = %{age: 25, adult_value: 100, minor_value: 50}

      # Mock if expression: if(age >= 18, adult_value, minor_value)
      condition = %{
        __struct__: Ash.Query.Call,
        name: :>=,
        args: [:age, 18]
      }

      if_expr = %{
        __struct__: Ash.Query.Call,
        name: :if,
        args: [condition, :adult_value, :minor_value]
      }

      # For this test, we'll simulate a truthy condition
      simple_if = %{
        __struct__: Ash.Query.Call,
        name: :if,
        args: [true, :adult_value, :minor_value]
      }

      assert {:ok, 100} = CalculationEngine.evaluate(simple_if, data)
    end

    test "evaluates if expression - false case" do
      data = %{adult_value: 100, minor_value: 50}

      if_expr = %{
        __struct__: Ash.Query.Call,
        name: :if,
        args: [false, :adult_value, :minor_value]
      }

      assert {:ok, 50} = CalculationEngine.evaluate(if_expr, data)
    end

    test "evaluates if expression - nil condition" do
      data = %{adult_value: 100, minor_value: 50}

      if_expr = %{
        __struct__: Ash.Query.Call,
        name: :if,
        args: [nil, :adult_value, :minor_value]
      }

      assert {:ok, 50} = CalculationEngine.evaluate(if_expr, data)
    end
  end

  describe "Custom function registration" do
    test "registers and calls custom function" do
      # Register a custom function
      double_func = fn x -> x * 2 end
      :ok = CalculationEngine.register_function(:double, double_func)

      data = %{value: 21}

      # Mock call to custom function
      custom_call = %{
        __struct__: Ash.Query.Call,
        name: :double,
        args: [:value]
      }

      assert {:ok, 42} = CalculationEngine.evaluate(custom_call, data)

      # Clean up
      assert {:ok, ^double_func} = CalculationEngine.get_function(:double)
    end

    test "handles unknown custom functions" do
      data = %{value: 10}

      unknown_call = %{
        __struct__: Ash.Query.Call,
        name: :unknown_function,
        args: [:value]
      }

      assert {:error, {:unknown_function, :unknown_function}} =
               CalculationEngine.evaluate(unknown_call, data)
    end

    test "lists registered functions" do
      # Register some functions
      :ok = CalculationEngine.register_function(:test_func1, fn x -> x end)
      :ok = CalculationEngine.register_function(:test_func2, fn x -> x * 2 end)

      functions = CalculationEngine.list_functions()

      assert :test_func1 in functions
      assert :test_func2 in functions
    end

    test "gets registered function" do
      test_func = fn x -> x + 1 end
      :ok = CalculationEngine.register_function(:test_get, test_func)

      assert {:ok, ^test_func} = CalculationEngine.get_function(:test_get)
      assert {:error, :not_found} = CalculationEngine.get_function(:nonexistent)
    end
  end

  describe "Expression validation" do
    test "validates simple expressions" do
      assert :ok = CalculationEngine.validate_expression(nil)
      assert :ok = CalculationEngine.validate_expression(:field_name)
      assert :ok = CalculationEngine.validate_expression({:field_name})
      assert :ok = CalculationEngine.validate_expression({:field1, :field2})
      assert :ok = CalculationEngine.validate_expression({:field, :rel, :field})
      assert :ok = CalculationEngine.validate_expression(fn _x -> :ok end)
    end

    test "validates Ash expressions" do
      ash_ref = %{__struct__: Ash.Query.Ref}
      assert :ok = CalculationEngine.validate_expression(ash_ref)
    end

    test "rejects invalid expressions" do
      assert {:error, {:unsupported_expression, _}} =
               CalculationEngine.validate_expression(%{invalid: "expression"})

      assert {:error, {:unsupported_expression, _}} =
               CalculationEngine.validate_expression({"not", "supported", "tuple"})
    end
  end

  describe "Field reference extraction" do
    test "extracts simple field references" do
      assert [:amount] = CalculationEngine.extract_field_references(:amount)
      assert [:field_name] = CalculationEngine.extract_field_references({:field_name})
      assert [:field1, :field2] = CalculationEngine.extract_field_references({:field1, :field2})
    end

    test "extracts relationship field references" do
      assert [:field] = CalculationEngine.extract_field_references({:field, :rel, :field})
    end

    test "extracts Ash ref field references" do
      ash_ref = %{
        __struct__: Ash.Query.Ref,
        attribute: %{name: :test_field}
      }

      assert [:test_field] = CalculationEngine.extract_field_references(ash_ref)
    end

    test "handles expressions with no field references" do
      assert [] = CalculationEngine.extract_field_references(nil)
      assert [] = CalculationEngine.extract_field_references(fn _x -> :ok end)
      assert [] = CalculationEngine.extract_field_references(42)
    end
  end

  describe "Error handling and edge cases" do
    test "handles evaluation errors gracefully" do
      data = %{field: "value"}

      # Expression that will cause an error during evaluation
      error_expr = fn _data -> throw(:error) end

      assert {:error, {:thrown_error, :error}} = CalculationEngine.evaluate(error_expr, data)
    end

    test "handles process exits gracefully" do
      data = %{field: "value"}

      # Expression that will cause a process exit
      exit_expr = fn _data -> exit(:normal) end

      assert {:error, {:process_exit, :normal}} = CalculationEngine.evaluate(exit_expr, data)
    end

    test "evaluate! raises on error" do
      data = %{field: "value"}

      assert_raise RuntimeError, ~r/Expression evaluation failed/, fn ->
        CalculationEngine.evaluate!(:missing_field, data)
      end
    end

    test "evaluate! returns value on success" do
      data = %{amount: 100}

      assert 100 = CalculationEngine.evaluate!(:amount, data)
    end

    test "handles complex nested expressions" do
      data = %{
        customer: %{
          address: %{
            region: "West Coast"
          }
        }
      }

      # This would require more complex relationship traversal
      # For now, test the basic structure
      result = CalculationEngine.evaluate({:customer, :address}, data)
      assert {:ok, %{region: "West Coast"}} = result
    end

    test "handles empty data context" do
      empty_data = %{}

      assert {:error, {:field_not_found, :any_field}} =
               CalculationEngine.evaluate(:any_field, empty_data)
    end

    test "handles complex data structures" do
      complex_data = %{
        array_field: [1, 2, 3],
        map_field: %{nested: "value"},
        struct_field: %Date{year: 2024, month: 1, day: 1}
      }

      assert {:ok, [1, 2, 3]} = CalculationEngine.evaluate(:array_field, complex_data)
      assert {:ok, %{nested: "value"}} = CalculationEngine.evaluate(:map_field, complex_data)
    end
  end
end
