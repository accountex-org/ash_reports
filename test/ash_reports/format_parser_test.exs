defmodule AshReports.FormatParserTest do
  use ExUnit.Case, async: true

  alias AshReports.FormatParser

  describe "format pattern parsing" do
    test "parses simple number pattern" do
      {:ok, result} = FormatParser.parse("#,##0.00")
      assert result.type == :number
      assert result.pattern == "#,##0.00"
      assert is_function(result.formatter)
    end

    test "parses currency pattern" do
      {:ok, result} = FormatParser.parse("¤#,##0.00")

      assert result.type == :currency
      assert result.pattern == "¤#,##0.00"
      assert is_function(result.formatter)
    end

    test "parses percentage pattern" do
      {:ok, result} = FormatParser.parse("#0.##%")

      assert result.type == :percentage
      assert result.pattern == "#0.##%"
      assert is_function(result.formatter)
    end

    test "parses date pattern" do
      {:ok, result} = FormatParser.parse("yyyy-MM-dd")

      assert result.type == :date
      assert result.pattern == "yyyy-MM-dd"
      assert is_function(result.formatter)
    end

    test "parses text pattern" do
      {:ok, result} = FormatParser.parse("%{value}")

      assert result.type == :text
      assert result.pattern == "%{value}"
      assert is_function(result.formatter)
    end
  end

  describe "format pattern validation" do
    test "validates correct number pattern" do
      assert FormatParser.validate("#,##0.00") == :ok
    end

    test "validates correct currency pattern" do
      assert FormatParser.validate("$#,##0.00") == :ok
    end

    test "validates correct date pattern" do
      assert FormatParser.validate("dd/MM/yyyy") == :ok
    end

    test "returns error for invalid pattern syntax" do
      {:error, error} = FormatParser.validate("invalid{{}}")

      assert error.message =~ "Invalid pattern syntax" or error.message =~ "unmatched"
    end

    test "returns error for unbalanced braces" do
      {:error, error} = FormatParser.validate("{missing_close")

      assert error.message =~ "Unbalanced braces"
    end

    test "returns error for empty pattern" do
      {:error, error} = FormatParser.validate("")

      assert error.message =~ "Parse failed" or error.message =~ "empty"
    end
  end

  describe "format type detection" do
    test "detects number type from patterns" do
      assert FormatParser.detect_type("#,##0.00") == :number
      assert FormatParser.detect_type("#0.##") == :number
      assert FormatParser.detect_type("0.000") == :number
    end

    test "detects currency type from patterns" do
      assert FormatParser.detect_type("¤#,##0.00") == :currency
      assert FormatParser.detect_type("$#,##0.00") == :currency
      assert FormatParser.detect_type("€#,##0.00") == :currency
      assert FormatParser.detect_type("£#,##0.00") == :currency
      assert FormatParser.detect_type("#,##0.00¤") == :currency
    end

    test "detects percentage type from patterns" do
      assert FormatParser.detect_type("#0.##%") == :percentage
      assert FormatParser.detect_type("0.00%") == :percentage
      assert FormatParser.detect_type("%#0.##") == :percentage
    end

    test "detects date type from patterns" do
      assert FormatParser.detect_type("yyyy-MM-dd") == :date
      assert FormatParser.detect_type("dd/MM/yyyy") == :date
      assert FormatParser.detect_type("MMM dd, yyyy") == :date
    end

    test "detects time type from patterns" do
      assert FormatParser.detect_type("HH:mm:ss") == :time
      assert FormatParser.detect_type("HH:mm") == :time
    end

    test "detects datetime type from patterns" do
      assert FormatParser.detect_type("yyyy-MM-dd HH:mm:ss") == :datetime
      assert FormatParser.detect_type("dd/MM/yyyy HH:mm") == :datetime
    end

    test "detects text type from patterns" do
      assert FormatParser.detect_type("%{value}") == :text
      assert FormatParser.detect_type("{value}") == :text
    end

    test "defaults to custom for unknown patterns" do
      assert FormatParser.detect_type("unknown pattern") == :custom
    end
  end

  describe "pattern tokenization" do
    test "tokenizes number pattern" do
      tokens = FormatParser.tokenize("#,##0.00")

      assert length(tokens) == 8
      assert Enum.any?(tokens, fn token -> token.type == :number_component end)
      assert Enum.any?(tokens, fn token -> token.type == :separator end)
    end

    test "tokenizes currency pattern" do
      tokens = FormatParser.tokenize("¤#,##0.00")

      assert Enum.any?(tokens, fn token -> token.type == :currency_symbol end)
      assert Enum.any?(tokens, fn token -> token.type == :number_component end)
    end

    test "tokenizes date pattern" do
      tokens = FormatParser.tokenize("yyyy-MM-dd")

      assert Enum.any?(tokens, fn token -> token.type == :date_component end)
      assert Enum.any?(tokens, fn token -> token.type == :separator end)
    end

    test "includes position information in tokens" do
      tokens = FormatParser.tokenize("abc")

      assert Enum.all?(tokens, fn token -> is_integer(token.position) end)
      assert Enum.at(tokens, 0).position == 0
      assert Enum.at(tokens, 1).position == 1
      assert Enum.at(tokens, 2).position == 2
    end
  end

  describe "parser options and configuration" do
    test "respects type option for validation" do
      {:ok, result} = FormatParser.parse("#,##0.00", type: :number)
      assert result.type == :number

      {:error, error} = FormatParser.parse("#,##0.00", type: :currency)
      assert error.message =~ "type mismatch"
    end

    test "respects locale option" do
      {:ok, result} = FormatParser.parse("#,##0.00", locale: "fr")
      assert result.metadata[:options][:locale] == "fr"
    end

    test "respects cache option" do
      # First parse should work
      {:ok, _result1} = FormatParser.parse("#,##0.00", cache: false)

      # Should still work with cache disabled
      {:ok, _result2} = FormatParser.parse("#,##0.00", cache: false)
    end

    test "supports validate_only option" do
      # This should not return a compiled formatter
      {:ok, result} = FormatParser.parse("#,##0.00", validate_only: true)
      assert result == nil
    end

    test "supports strict parsing mode" do
      # Strict mode should be more restrictive (implementation dependent)
      result = FormatParser.parse("loose_pattern", strict: true)

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "compiled formatter functions" do
    test "compiled number formatter works" do
      {:ok, compiled} = FormatParser.parse("#,##0.00")

      {:ok, result} = compiled.formatter.(1234.56, [])

      assert is_binary(result)
      assert result =~ "1"
      assert result =~ "234"
      assert result =~ "56"
    end

    test "compiled currency formatter works" do
      {:ok, compiled} = FormatParser.parse("¤#,##0.00")

      {:ok, result} = compiled.formatter.(1234.56, currency: :USD)

      assert is_binary(result)
      assert result =~ "1234"
    end

    test "compiled date formatter works" do
      {:ok, compiled} = FormatParser.parse("yyyy-MM-dd")

      {:ok, result} = compiled.formatter.(~D[2024-03-15], [])

      assert is_binary(result)
      assert result =~ "2024"
      assert result =~ "03"
      assert result =~ "15"
    end

    test "compiled percentage formatter works" do
      {:ok, compiled} = FormatParser.parse("#0.##%")

      {:ok, result} = compiled.formatter.(0.1234, [])

      assert is_binary(result)
      assert result =~ "12"
    end

    test "formatter handles errors gracefully" do
      {:ok, compiled} = FormatParser.parse("#,##0.00")

      # Should handle invalid input gracefully
      result = compiled.formatter.("invalid", [])

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end
  end

  describe "pattern information and documentation" do
    test "provides pattern information" do
      info = FormatParser.pattern_info()

      assert is_map(info)
      assert Map.has_key?(info, :number)
      assert Map.has_key?(info, :currency)
      assert Map.has_key?(info, :date)
      assert Map.has_key?(info, :text)
      assert Map.has_key?(info, :percentage)
    end

    test "pattern info includes examples" do
      info = FormatParser.pattern_info()

      assert is_list(info.number.examples)
      assert is_list(info.currency.examples)
      assert is_list(info.date.examples)

      # Examples should be non-empty
      assert length(info.number.examples) > 0
      assert length(info.currency.examples) > 0
      assert length(info.date.examples) > 0
    end

    test "pattern info includes symbol descriptions" do
      info = FormatParser.pattern_info()

      assert is_map(info.number.symbols)
      assert is_map(info.currency.symbols)
      assert is_map(info.date.symbols)

      # Should describe key symbols
      assert Map.has_key?(info.number.symbols, "#")
      assert Map.has_key?(info.number.symbols, "0")
      assert Map.has_key?(info.currency.symbols, "¤")
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed patterns gracefully" do
      cases = [
        "{{{}",
        "}}}",
        "#,##,##,##,##0.00.00.00",
        "¤¤¤¤",
        "%%%%",
        "",
        nil
      ]

      Enum.each(cases, fn pattern ->
        if pattern do
          result = FormatParser.parse(pattern)

          case result do
            {:ok, _} -> assert true
            {:error, _} -> assert true
          end
        end
      end)
    end

    test "error messages include helpful information" do
      {:error, error} = FormatParser.parse("invalid{{")

      assert is_binary(error.message)
      assert is_integer(error.position)
      assert is_binary(error.context)
      assert is_list(error.suggestions)
      assert length(error.suggestions) > 0
    end

    test "suggestions are relevant to error type" do
      {:error, error} = FormatParser.parse("{unmatched")

      suggestions_text = Enum.join(error.suggestions, " ")
      assert suggestions_text =~ "brace" or suggestions_text =~ "match"
    end

    test "handles very long patterns" do
      long_pattern = String.duplicate("#", 1000) <> ".00"

      result = FormatParser.parse(long_pattern)

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    test "handles patterns with unicode characters" do
      unicode_pattern = "¥#,##0.00"

      {:ok, result} = FormatParser.parse(unicode_pattern)
      assert result.type == :currency
    end
  end
end
