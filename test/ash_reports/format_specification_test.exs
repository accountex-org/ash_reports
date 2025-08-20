defmodule AshReports.FormatSpecificationTest do
  use ExUnit.Case, async: true

  alias AshReports.FormatSpecification

  describe "format specification creation" do
    test "creates a new format specification with default options" do
      spec = FormatSpecification.new(:test_format)

      assert spec.name == :test_format
      assert spec.pattern == nil
      assert spec.conditions == []
      assert spec.options == []
      assert spec.compiled == false
    end

    test "creates a format specification with pattern" do
      spec = FormatSpecification.new(:number_format, pattern: "#,##0.00")

      assert spec.name == :number_format
      assert spec.pattern == "#,##0.00"
    end

    test "creates a format specification with conditions" do
      conditions = [{:>, 1000}, {:pattern, "#,##0K"}]
      spec = FormatSpecification.new(:conditional, conditions: conditions)

      assert spec.name == :conditional
      assert spec.conditions == conditions
    end
  end

  describe "condition handling" do
    test "adds conditions to a format specification" do
      spec =
        FormatSpecification.new(:test)
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K", color: :green)
        |> FormatSpecification.add_condition({:<, 0}, pattern: "(#,##0)", color: :red)

      assert length(spec.conditions) == 2
      assert {{:>, 1000}, [pattern: "#,##0K", color: :green]} in spec.conditions
      assert {{:<, 0}, [pattern: "(#,##0)", color: :red]} in spec.conditions
    end

    test "sets default pattern" do
      spec =
        FormatSpecification.new(:test)
        |> FormatSpecification.set_default_pattern("#,##0.00")

      assert spec.pattern == "#,##0.00"
    end
  end

  describe "format specification compilation" do
    test "compiles a simple format specification" do
      spec = FormatSpecification.new(:simple, pattern: "#,##0.00")

      {:ok, compiled} = FormatSpecification.compile(spec)

      assert compiled.compiled == true
      assert compiled.pattern == "#,##0.00"
    end

    test "compiles format specification with conditions" do
      spec =
        FormatSpecification.new(:conditional, pattern: "#,##0.00")
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K")

      {:ok, compiled} = FormatSpecification.compile(spec)

      assert compiled.compiled == true
      assert length(compiled.conditions) == 1
    end

    test "returns error for invalid pattern" do
      spec = FormatSpecification.new(:invalid, pattern: "")

      {:error, reason} = FormatSpecification.compile(spec)

      assert reason =~ "compilation failed"
    end

    test "does not recompile already compiled specification" do
      spec = FormatSpecification.new(:test, pattern: "#,##0.00")
      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, same_compiled} = FormatSpecification.compile(compiled)

      assert same_compiled == compiled
    end
  end

  describe "format specification validation" do
    test "validates a valid format specification" do
      spec = FormatSpecification.new(:valid, pattern: "#,##0.00")

      assert FormatSpecification.validate(spec) == :ok
    end

    test "validates format specification with conditions" do
      spec =
        FormatSpecification.new(:conditional, pattern: "#,##0.00")
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K")

      assert FormatSpecification.validate(spec) == :ok
    end

    test "returns error for empty pattern" do
      spec = FormatSpecification.new(:empty, pattern: "")

      {:error, reason} = FormatSpecification.validate(spec)

      assert reason =~ "Pattern cannot be empty"
    end

    test "returns error for invalid pattern syntax" do
      spec = FormatSpecification.new(:invalid, pattern: "{{invalid}}")

      {:error, reason} = FormatSpecification.validate(spec)

      assert reason =~ "Invalid pattern syntax"
    end
  end

  describe "effective format determination" do
    test "returns default pattern when no conditions match" do
      spec =
        FormatSpecification.new(:test, pattern: "#,##0.00")
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K")

      {:ok, compiled} = FormatSpecification.compile(spec)
      {:ok, {pattern, options}} = FormatSpecification.get_effective_format(compiled, 500, %{})

      assert pattern == "#,##0.00"
      assert is_list(options)
    end

    test "returns condition pattern when condition matches" do
      spec =
        FormatSpecification.new(:test, pattern: "#,##0.00")
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K", color: :green)

      {:ok, compiled} = FormatSpecification.compile(spec)
      {:ok, {pattern, options}} = FormatSpecification.get_effective_format(compiled, 1500, %{})

      assert pattern == "#,##0K"
      assert Keyword.get(options, :color) == :green
    end

    test "evaluates multiple conditions in order" do
      spec =
        FormatSpecification.new(:test, pattern: "#,##0.00")
        |> FormatSpecification.add_condition({:>, 10000}, pattern: "#,##0K", color: :blue)
        |> FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0", color: :green)

      {:ok, compiled} = FormatSpecification.compile(spec)

      # Should match second condition
      {:ok, {pattern, options}} = FormatSpecification.get_effective_format(compiled, 5000, %{})
      assert pattern == "#,##0"
      assert Keyword.get(options, :color) == :green

      # Should match first condition  
      {:ok, {pattern, options}} = FormatSpecification.get_effective_format(compiled, 15000, %{})
      assert pattern == "#,##0K"
      assert Keyword.get(options, :color) == :blue
    end

    test "requires compilation before use" do
      spec = FormatSpecification.new(:test, pattern: "#,##0.00")

      {:error, reason} = FormatSpecification.get_effective_format(spec, 1000, %{})

      assert reason == "Format specification must be compiled before use"
    end
  end

  describe "edge cases and error handling" do
    test "handles nil pattern gracefully" do
      spec = FormatSpecification.new(:nil_pattern)

      assert FormatSpecification.validate(spec) == :ok
    end

    test "handles non-string pattern" do
      spec = %FormatSpecification{
        name: :invalid,
        pattern: 123,
        conditions: [],
        options: [],
        compiled: false
      }

      {:error, reason} = FormatSpecification.validate(spec)

      assert reason =~ "Pattern must be a string"
    end

    test "handles invalid conditions format" do
      spec = %FormatSpecification{
        name: :invalid,
        pattern: "#,##0.00",
        conditions: "invalid",
        options: [],
        compiled: false
      }

      {:error, reason} = FormatSpecification.validate(spec)

      assert reason =~ "Conditions must be a list"
    end

    test "handles invalid options format" do
      spec = %FormatSpecification{
        name: :invalid,
        pattern: "#,##0.00",
        conditions: [],
        options: "invalid",
        compiled: false
      }

      {:error, reason} = FormatSpecification.validate(spec)

      assert reason =~ "Options must be a keyword list"
    end
  end

  describe "integration with real format patterns" do
    test "handles number format patterns" do
      spec = FormatSpecification.new(:number, pattern: "#,##0.00")

      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, {pattern, _options}} =
        FormatSpecification.get_effective_format(compiled, 1234.56, %{})

      assert pattern == "#,##0.00"
    end

    test "handles currency format patterns" do
      spec = FormatSpecification.new(:currency, pattern: "¤#,##0.00", currency: :USD)

      {:ok, compiled} = FormatSpecification.compile(spec)
      {:ok, {pattern, options}} = FormatSpecification.get_effective_format(compiled, 1234.56, %{})

      assert pattern == "¤#,##0.00"
      assert Keyword.get(options, :currency) == :USD
    end

    test "handles percentage format patterns" do
      spec = FormatSpecification.new(:percentage, pattern: "#0.##%")

      {:ok, compiled} = FormatSpecification.compile(spec)
      {:ok, {pattern, _options}} = FormatSpecification.get_effective_format(compiled, 0.1234, %{})

      assert pattern == "#0.##%"
    end

    test "handles date format patterns" do
      spec = FormatSpecification.new(:date, pattern: "yyyy-MM-dd")

      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, {pattern, _options}} =
        FormatSpecification.get_effective_format(compiled, ~D[2024-03-15], %{})

      assert pattern == "yyyy-MM-dd"
    end

    test "handles text format patterns with transformations" do
      spec =
        FormatSpecification.new(:text, pattern: "%{value}", transform: :uppercase, max_length: 20)

      {:ok, compiled} = FormatSpecification.compile(spec)

      {:ok, {pattern, options}} =
        FormatSpecification.get_effective_format(compiled, "hello world", %{})

      assert pattern == "%{value}"
      assert Keyword.get(options, :transform) == :uppercase
      assert Keyword.get(options, :max_length) == 20
    end
  end
end
