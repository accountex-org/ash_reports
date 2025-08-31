defmodule AshReports.FormatSpecificationBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.FormatSpecificationBuilder

  describe "FormatSpecificationBuilder" do
    test "creates builder with basic configuration" do
      builder = FormatSpecificationBuilder.new(:test_format)

      assert builder.name == :test_format
      assert builder.pattern == nil
      assert builder.conditions == []
      assert builder.options == []
    end

    test "sets pattern via builder" do
      builder =
        FormatSpecificationBuilder.new(:test)
        |> FormatSpecificationBuilder.set_pattern("#,##0.00")

      assert builder.pattern == "#,##0.00"
    end

    test "adds currency formatting configuration" do
      builder =
        FormatSpecificationBuilder.new(:price)
        |> FormatSpecificationBuilder.add_currency_formatting(:EUR)

      assert Keyword.get(builder.options, :type) == :currency
      assert Keyword.get(builder.options, :currency) == :EUR
      assert Keyword.get(builder.options, :locale_aware) == true
    end

    test "adds conditional formatting rules" do
      builder =
        FormatSpecificationBuilder.new(:amount)
        |> FormatSpecificationBuilder.add_condition(
          {:>, 1000},
          pattern: "#,##0K",
          color: :green
        )

      assert length(builder.conditions) == 1
      assert {{:>, 1000}, [pattern: "#,##0K", color: :green]} in builder.conditions
    end

    test "builds uncompiled specification" do
      spec =
        FormatSpecificationBuilder.new(:test)
        |> FormatSpecificationBuilder.set_pattern("#,##0.00")
        |> FormatSpecificationBuilder.add_currency_formatting(:USD)
        |> FormatSpecificationBuilder.build_uncompiled()

      assert spec.name == :test
      assert spec.pattern == "#,##0.00"
      assert Keyword.get(spec.options, :currency) == :USD
    end

    test "builds and compiles specification" do
      {:ok, compiled_spec} =
        FormatSpecificationBuilder.new(:test)
        |> FormatSpecificationBuilder.set_pattern("#,##0.00")
        |> FormatSpecificationBuilder.build()

      assert compiled_spec.name == :test
      assert compiled_spec.compiled == true
    end

    test "handles builder validation" do
      # Test with no pattern
      builder = FormatSpecificationBuilder.new(:invalid)

      {:ok, _spec} = FormatSpecificationBuilder.build(builder)
      # Should succeed even without pattern (nil pattern is valid)
    end

    test "supports fluent interface chaining" do
      {:ok, spec} =
        FormatSpecificationBuilder.new(:complex_format)
        |> FormatSpecificationBuilder.add_currency_formatting(:EUR)
        |> FormatSpecificationBuilder.add_condition({:>, 1000}, pattern: "#,##0K")
        |> FormatSpecificationBuilder.set_default(pattern: "#,##0.00")
        |> FormatSpecificationBuilder.build()

      assert spec.name == :complex_format
      assert length(spec.conditions) == 1
      assert Keyword.get(spec.options, :currency) == :EUR
    end
  end
end
