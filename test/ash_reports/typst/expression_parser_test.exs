defmodule AshReports.Typst.ExpressionParserTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.ExpressionParser

  describe "extract_field/1" do
    test "extracts field from simple atom" do
      assert {:ok, :region} = ExpressionParser.extract_field(:region)
      assert {:ok, :status} = ExpressionParser.extract_field(:status)
      assert {:ok, :customer_name} = ExpressionParser.extract_field(:customer_name)
    end

    test "extracts field from tuple notation {:field, field_name}" do
      assert {:ok, :region} = ExpressionParser.extract_field({:field, :region})
      assert {:ok, :status} = ExpressionParser.extract_field({:field, :status})
    end

    test "extracts terminal field from nested {:field, relationship, field}" do
      assert {:ok, :region} = ExpressionParser.extract_field({:field, :customer, :region})
      assert {:ok, :state} = ExpressionParser.extract_field({:field, :address, :state})
      assert {:ok, :name} = ExpressionParser.extract_field({:field, :company, :name})
    end

    test "extracts terminal field from multi-level nested tuples" do
      assert {:ok, :region} = ExpressionParser.extract_field({:field, :order, :customer, :region})

      assert {:ok, :field_name} =
               ExpressionParser.extract_field({:field, :rel1, :rel2, :field_name})

      assert {:ok, :name} =
               ExpressionParser.extract_field({:field, :order, :customer, :company, :name})
    end

    test "extracts field from Ash.Expr with simple ref" do
      ash_expr = %{__struct__: Ash.Expr, expression: {:ref, [], :region}}
      assert {:ok, :region} = ExpressionParser.extract_field(ash_expr)

      ash_expr = %{__struct__: Ash.Expr, expression: {:ref, [], :status}}
      assert {:ok, :status} = ExpressionParser.extract_field(ash_expr)
    end

    test "extracts field from Ash.Expr with direct atom" do
      ash_expr = %{__struct__: Ash.Expr, expression: :region}
      assert {:ok, :region} = ExpressionParser.extract_field(ash_expr)

      ash_expr = %{__struct__: Ash.Expr, expression: :customer_name}
      assert {:ok, :customer_name} = ExpressionParser.extract_field(ash_expr)
    end

    test "extracts terminal field from Ash.Expr with get_path" do
      # Simulating customer.region
      ash_expr = %{
        __struct__: Ash.Expr,
        expression:
          {:get_path, [], [%{__struct__: Ash.Expr, expression: {:ref, [], :customer}}, :region]}
      }

      assert {:ok, :region} = ExpressionParser.extract_field(ash_expr)
    end

    test "extracts field from complex nested Ash.Expr" do
      # Nested Ash.Expr that contains another expression
      nested_expr = %{__struct__: Ash.Expr, expression: {:ref, [], :field_name}}
      ash_expr = %{__struct__: Ash.Expr, expression: nested_expr.expression}
      assert {:ok, :field_name} = ExpressionParser.extract_field(ash_expr)
    end

    test "returns error for nil" do
      assert {:error, :unrecognized_expression_format} = ExpressionParser.extract_field(nil)
    end

    test "returns error for unrecognized format" do
      assert {:error, :unrecognized_expression_format} =
               ExpressionParser.extract_field("string")

      assert {:error, :unrecognized_expression_format} = ExpressionParser.extract_field(123)

      assert {:error, :unrecognized_expression_format} =
               ExpressionParser.extract_field({:unknown, "format"})
    end

    test "returns error for invalid tuple with non-atom field" do
      assert {:error, _} = ExpressionParser.extract_field({:field, :rel, "not_an_atom"})
    end

    test "handles empty get_path gracefully" do
      ash_expr = %{__struct__: Ash.Expr, expression: {:get_path, [], []}}
      assert {:error, _} = ExpressionParser.extract_field(ash_expr)
    end
  end

  describe "extract_field_path/1" do
    test "extracts single element path from simple atom" do
      assert {:ok, [:region]} = ExpressionParser.extract_field_path(:region)
      assert {:ok, [:status]} = ExpressionParser.extract_field_path(:status)
    end

    test "extracts single element path from tuple notation" do
      assert {:ok, [:region]} = ExpressionParser.extract_field_path({:field, :region})
    end

    test "extracts full path from nested field" do
      assert {:ok, [:customer, :region]} =
               ExpressionParser.extract_field_path({:field, :customer, :region})

      assert {:ok, [:address, :state]} =
               ExpressionParser.extract_field_path({:field, :address, :state})
    end

    test "extracts full path from multi-level nested tuples" do
      assert {:ok, [:order, :customer, :region]} =
               ExpressionParser.extract_field_path({:field, :order, :customer, :region})

      assert {:ok, [:rel1, :rel2, :field_name]} =
               ExpressionParser.extract_field_path({:field, :rel1, :rel2, :field_name})
    end

    test "extracts path from Ash.Expr with simple ref" do
      ash_expr = %{__struct__: Ash.Expr, expression: {:ref, [], :region}}
      assert {:ok, [:region]} = ExpressionParser.extract_field_path(ash_expr)
    end

    test "extracts path from Ash.Expr with get_path" do
      # Simulating customer.region
      ash_expr = %{
        __struct__: Ash.Expr,
        expression:
          {:get_path, [], [%{__struct__: Ash.Expr, expression: {:ref, [], :customer}}, :region]}
      }

      assert {:ok, [:customer, :region]} = ExpressionParser.extract_field_path(ash_expr)
    end

    test "returns error for unrecognized format" do
      assert {:error, :unrecognized_expression_format} =
               ExpressionParser.extract_field_path("string")

      assert {:error, :unrecognized_expression_format} =
               ExpressionParser.extract_field_path(nil)
    end

    test "returns error for tuple with non-atom elements" do
      assert {:error, :non_atom_in_path} =
               ExpressionParser.extract_field_path({:field, "string", :field})
    end
  end

  describe "validate_expression/1" do
    test "validates simple atom expressions" do
      assert {:ok, :region} = ExpressionParser.validate_expression(:region)
      assert {:ok, :status} = ExpressionParser.validate_expression(:status)
    end

    test "validates tuple notation" do
      assert {:ok, :region} = ExpressionParser.validate_expression({:field, :region})

      assert {:ok, :region} =
               ExpressionParser.validate_expression({:field, :customer, :region})
    end

    test "validates Ash.Expr" do
      ash_expr = %{__struct__: Ash.Expr, expression: {:ref, [], :region}}
      assert {:ok, :region} = ExpressionParser.validate_expression(ash_expr)
    end

    test "returns error for invalid expressions" do
      assert {:error, _} = ExpressionParser.validate_expression(nil)
      assert {:error, _} = ExpressionParser.validate_expression("invalid")
      assert {:error, _} = ExpressionParser.validate_expression({:unknown, "format"})
    end
  end

  describe "extract_field_with_fallback/2" do
    test "returns extracted field when parsing succeeds" do
      assert {:ok, :region} =
               ExpressionParser.extract_field_with_fallback(:region, :fallback)

      assert {:ok, :region} =
               ExpressionParser.extract_field_with_fallback(
                 {:field, :customer, :region},
                 :fallback
               )

      ash_expr = %{__struct__: Ash.Expr, expression: {:ref, [], :status}}
      assert {:ok, :status} = ExpressionParser.extract_field_with_fallback(ash_expr, :fallback)
    end

    test "returns fallback when parsing fails" do
      assert {:ok, :fallback_name} =
               ExpressionParser.extract_field_with_fallback(nil, :fallback_name)

      assert {:ok, :default_group} =
               ExpressionParser.extract_field_with_fallback("invalid", :default_group)

      assert {:ok, :group_1} =
               ExpressionParser.extract_field_with_fallback({:unknown, "format"}, :group_1)
    end

    test "always returns ok tuple even with invalid input" do
      result = ExpressionParser.extract_field_with_fallback(%{invalid: "map"}, :fallback)
      assert {:ok, :fallback} = result
    end
  end

  describe "real-world expression patterns" do
    test "handles typical report group expression" do
      # Pattern from test/support/test_helpers.ex
      expression = {:field, :customer, :region}
      assert {:ok, :region} = ExpressionParser.extract_field(expression)
      assert {:ok, [:customer, :region]} = ExpressionParser.extract_field_path(expression)
    end

    test "handles Ash query-style expressions" do
      # Pattern that might come from Ash.Expr parsing
      ash_expr = %{
        __struct__: Ash.Expr,
        expression:
          {:get_path, [], [%{__struct__: Ash.Expr, expression: {:ref, [], :order}}, :status]}
      }

      assert {:ok, :status} = ExpressionParser.extract_field(ash_expr)
    end

    test "handles multi-level relationship traversal" do
      # order.customer.company.name
      expression = {:field, :order, :customer, :company, :name}
      assert {:ok, :name} = ExpressionParser.extract_field(expression)

      assert {:ok, [:order, :customer, :company, :name]} =
               ExpressionParser.extract_field_path(expression)
    end
  end

  describe "edge cases" do
    test "handles atom-only expressions correctly" do
      assert {:ok, :single_field} = ExpressionParser.extract_field(:single_field)
      assert {:ok, [:single_field]} = ExpressionParser.extract_field_path(:single_field)
    end

    test "rejects expressions with invalid types in path" do
      # Non-atom in field position
      assert {:error, _} = ExpressionParser.extract_field({:field, :rel, 123})
      assert {:error, _} = ExpressionParser.extract_field({:field, :rel, "string"})
    end

    test "handles deeply nested Ash.Expr structures" do
      # Edge case: Ash.Expr wrapping another Ash.Expr
      inner = %{__struct__: Ash.Expr, expression: :field_name}
      outer = %{__struct__: Ash.Expr, expression: inner.expression}
      assert {:ok, :field_name} = ExpressionParser.extract_field(outer)
    end

    test "extract_field_with_fallback never fails" do
      # Should always return {:ok, _} even with bizarre inputs
      assert {:ok, _} = ExpressionParser.extract_field_with_fallback(%{}, :fallback)
      assert {:ok, _} = ExpressionParser.extract_field_with_fallback([], :fallback)
      assert {:ok, _} = ExpressionParser.extract_field_with_fallback(fn -> :x end, :fallback)
    end
  end
end
