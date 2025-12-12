defmodule AshReports.Integration.MultiRendererConsistencyTest do
  @moduledoc """
  Tests to ensure Phase 4 features work consistently across all renderers.

  Validates that CLDR formatting, format specifications, RTL support, and 
  translations behave identically across HTML, HEEX, PDF, and JSON renderers.
  """

  use ExUnit.Case, async: true

  alias AshReports.{HeexRenderer, IrHtmlRenderer, JsonRenderer, PdfRenderer}
  alias AshReports.Integration.TestHelpers

  @moduletag :integration
  @moduletag :multi_renderer

  @renderers [IrHtmlRenderer, HeexRenderer, PdfRenderer, JsonRenderer]

  describe "RTL Support Consistency" do
    test "RTL text direction handled consistently across all renderers" do
      _report = TestHelpers.build_rtl_test_report()
      _data = TestHelpers.create_arabic_test_data()

      results =
        Enum.map(@renderers, fn renderer ->
          context = TestHelpers.create_rtl_context("ar")
          context = Map.put(context, :renderer, renderer)

          {:ok, result} = renderer.render_with_context(context)
          {renderer, result}
        end)

      # Verify all renderers handle RTL correctly
      Enum.each(results, fn {renderer, result} ->
        assert TestHelpers.validates_rtl_output?(result, renderer),
               "#{renderer} did not generate valid RTL output"
      end)

      # Verify consistency across renderers
      assert TestHelpers.consistent_rtl_behavior?(results),
             "RTL behavior is not consistent across renderers"
    end

    test "RTL layout calculations consistent across visual renderers" do
      # HTML and PDF should have similar RTL layout adaptations
      visual_renderers = [IrHtmlRenderer, PdfRenderer]
      _report = TestHelpers.build_rtl_test_report()
      _data = TestHelpers.create_arabic_test_data()

      visual_results =
        Enum.map(visual_renderers, fn renderer ->
          context =
            TestHelpers.create_rtl_context("ar")
            |> Map.put(:renderer, renderer)
            |> Map.put(:include_layout_data, true)

          {:ok, result} = renderer.render_with_context(context)
          {renderer, extract_layout_data(result, renderer)}
        end)

      [{_, html_layout}, {_, pdf_layout}] = visual_results

      # Both should have RTL layout calculations
      assert html_layout.text_direction == "rtl"
      assert pdf_layout.text_direction == "rtl"

      # Element positions should be mirrored consistently
      assert length(html_layout.element_positions) > 0
      assert length(pdf_layout.element_positions) > 0
    end
  end

  describe "Translation Integration Consistency" do
    test "translations work consistently across all renderers" do
      _report = TestHelpers.build_translatable_report()

      for locale <- ["en", "ar", "es"] do
        results =
          Enum.map(@renderers, fn renderer ->
            context = TestHelpers.create_translation_context(locale, renderer)
            {:ok, result} = renderer.render_with_context(context)
            {renderer, result}
          end)

        # Verify translations appear correctly in all renderers
        Enum.each(results, fn {renderer, result} ->
          assert TestHelpers.contains_translations?(result, locale, renderer),
                 "#{renderer} missing translations for locale #{locale}"
        end)

        # Verify consistency of translated content
        translated_content = extract_translated_content(results, locale)

        assert consistent_translations?(translated_content),
               "Translation content not consistent across renderers for #{locale}"
      end
    end

    test "translation fallbacks work consistently" do
      # Test with missing translations
      _report = TestHelpers.build_translatable_report()
      invalid_locale = "xx_INVALID"

      results =
        Enum.map(@renderers, fn renderer ->
          context =
            TestHelpers.create_context_with_missing_translations(invalid_locale)
            |> Map.put(:renderer, renderer)
            |> Map.put(:fallback_locale, "en")

          {:ok, result} = renderer.render_with_context(context)
          {renderer, result}
        end)

      # All renderers should fall back gracefully
      Enum.each(results, fn {renderer, result} ->
        assert TestHelpers.contains_fallback_text?(result),
               "#{renderer} did not provide fallback translations"

        refute TestHelpers.contains_error_markers?(result),
               "#{renderer} contains error markers instead of clean fallbacks"
      end)
    end
  end

  describe "CLDR Formatting Consistency" do
    test "number formatting consistent across renderers" do
      test_numbers = [1234.56, 9_876_543.21, 0.123, 99_999_999.99]
      locales = ["en", "ar", "de", "fr"]

      for locale <- locales do
        for number <- test_numbers do
          results =
            Enum.map(@renderers, fn renderer ->
              context =
                TestHelpers.create_cldr_context(locale)
                |> Map.put(:renderer, renderer)
                |> Map.put(:test_number, number)

              {:ok, result} = renderer.render_with_context(context)
              formatted_number = extract_formatted_number(result, renderer, number)
              {renderer, formatted_number}
            end)

          # Verify all renderers produce the same formatted number
          formatted_values = Enum.map(results, fn {_, formatted} -> formatted end)
          unique_values = Enum.uniq(formatted_values)

          assert length(unique_values) == 1,
                 "Number formatting inconsistent across renderers for #{number} in #{locale}: #{inspect(formatted_values)}"
        end
      end
    end

    test "currency formatting consistent across renderers" do
      test_cases = [
        {1500.25, "USD", "en"},
        {9876.54, "SAR", "ar"},
        {1234.00, "EUR", "de"}
      ]

      for {amount, currency, locale} <- test_cases do
        results =
          Enum.map(@renderers, fn renderer ->
            context =
              TestHelpers.create_cldr_context(locale)
              |> Map.put(:renderer, renderer)
              |> Map.put(:test_currency, %{amount: amount, currency: currency})

            {:ok, result} = renderer.render_with_context(context)
            formatted_currency = extract_formatted_currency(result, renderer, amount, currency)
            {renderer, formatted_currency}
          end)

        # Currency symbols and formatting should be consistent
        currency_formats = Enum.map(results, fn {_, formatted} -> formatted end)

        # All should contain the currency symbol
        Enum.each(currency_formats, fn formatted ->
          assert String.contains?(formatted, get_currency_symbol(currency)),
                 "Missing currency symbol in #{formatted}"
        end)

        # Numeric values should be identical after normalization
        normalized_values = Enum.map(currency_formats, &normalize_currency_value/1)
        unique_normalized = Enum.uniq(normalized_values)

        assert length(unique_normalized) == 1,
               "Currency value formatting inconsistent: #{inspect(currency_formats)}"
      end
    end
  end

  describe "Format Specification Consistency" do
    test "custom format specifications applied consistently" do
      format_specs = [
        %{type: :currency, precision: 0, grouping: false},
        %{type: :decimal, precision: 3, grouping: true},
        %{type: :percentage, precision: 1}
      ]

      test_value = 1234.567

      for format_spec <- format_specs do
        results =
          Enum.map(@renderers, fn renderer ->
            context =
              TestHelpers.create_integration_context("en", format_spec)
              |> Map.put(:renderer, renderer)
              |> Map.put(:test_value, test_value)

            {:ok, result} = renderer.render_with_context(context)
            formatted_value = extract_formatted_value(result, renderer, format_spec.type)
            {renderer, formatted_value}
          end)

        # Format specifications should be applied consistently
        formatted_values = Enum.map(results, fn {_, formatted} -> formatted end)

        # Verify format spec characteristics are present
        case format_spec.type do
          :currency ->
            if format_spec.grouping do
              Enum.each(formatted_values, &assert(String.contains?(&1, ",")))
            end

          :decimal ->
            if format_spec.precision == 3 do
              Enum.each(
                formatted_values,
                &assert(
                  String.contains?(&1, ".") and
                    String.length(String.split(&1, ".") |> List.last()) == 3
                )
              )
            end

          :percentage ->
            Enum.each(formatted_values, &assert(String.contains?(&1, "%")))
        end
      end
    end
  end

  describe "Error Handling Consistency" do
    test "error scenarios handled consistently across renderers" do
      error_scenarios = [
        %{
          type: :invalid_locale,
          context_fn: &TestHelpers.create_context_with_missing_translations/0
        },
        %{
          type: :invalid_rtl_config,
          context_fn: &TestHelpers.create_context_with_invalid_rtl_config/0
        },
        %{
          type: :missing_format_spec,
          context_fn: fn -> TestHelpers.create_integration_context("en", nil) end
        }
      ]

      for scenario <- error_scenarios do
        results =
          Enum.map(@renderers, fn renderer ->
            context =
              scenario.context_fn.()
              |> Map.put(:renderer, renderer)

            result =
              try do
                {:ok, output} = renderer.render_with_context(context)
                {:ok, output}
              rescue
                error -> {:error, error}
              catch
                :exit, reason -> {:exit, reason}
              end

            {renderer, result}
          end)

        # All renderers should handle the error consistently
        error_types =
          Enum.map(results, fn {_, result} ->
            case result do
              {:ok, _} -> :success
              {:error, _} -> :error
              {:exit, _} -> :exit
            end
          end)

        unique_error_types = Enum.uniq(error_types)

        assert length(unique_error_types) == 1,
               "Inconsistent error handling for #{scenario.type}: #{inspect(error_types)}"

        # If successful, should contain error handling indicators
        successful_results =
          results
          |> Enum.filter(fn {_, result} -> match?({:ok, _}, result) end)
          |> Enum.map(fn {renderer, {:ok, output}} -> {renderer, output} end)

        if length(successful_results) > 0 do
          Enum.each(successful_results, fn {renderer, output} ->
            assert TestHelpers.contains_error_handling_output?(output),
                   "#{renderer} did not provide proper error handling output"
          end)
        end
      end
    end
  end

  # Helper functions for extracting data from different renderer outputs

  defp extract_layout_data(output, IrHtmlRenderer) do
    # Extract CSS and HTML structure data
    %{
      text_direction: extract_css_direction(output),
      element_positions: extract_html_positions(output)
    }
  end

  defp extract_layout_data(output, PdfRenderer) do
    # Extract PDF layout metadata
    %{
      text_direction: extract_pdf_direction(output),
      element_positions: extract_pdf_positions(output)
    }
  end

  defp extract_layout_data(_output, _renderer), do: %{text_direction: nil, element_positions: []}

  defp extract_css_direction(html_output) do
    if String.contains?(html_output, "dir=\"rtl\"") or
         String.contains?(html_output, "direction: rtl") do
      "rtl"
    else
      "ltr"
    end
  end

  defp extract_html_positions(html_output) do
    # Simple extraction of positioned elements
    html_output
    |> String.split("<")
    |> Enum.filter(&String.contains?(&1, "style="))
    |> length()
  end

  defp extract_pdf_direction(pdf_output) do
    if String.contains?(pdf_output, "rtl") do
      "rtl"
    else
      "ltr"
    end
  end

  defp extract_pdf_positions(pdf_output) do
    # Count positioned elements in PDF
    pdf_output
    |> String.split(" ")
    |> Enum.filter(&String.contains?(&1, "pos"))
    |> length()
  end

  defp extract_translated_content(results, locale) do
    Enum.map(results, fn {renderer, output} ->
      case locale do
        "ar" -> extract_arabic_content(output, renderer)
        "es" -> extract_spanish_content(output, renderer)
        "en" -> extract_english_content(output, renderer)
        _ -> ""
      end
    end)
  end

  defp extract_arabic_content(output, _renderer) do
    # Look for Arabic words - using common Arabic words in test data
    arabic_words = ["عميل", "تقرير", "مجموع", "تاريخ"]
    Enum.find(arabic_words, fn word -> String.contains?(output, word) end) || ""
  end

  defp extract_spanish_content(output, _renderer) do
    # Look for Spanish words
    spanish_words = ["Cliente", "Informe", "Total", "Fecha"]
    Enum.find(spanish_words, fn word -> String.contains?(output, word) end) || ""
  end

  defp extract_english_content(output, _renderer) do
    # Look for English words
    english_words = ["Customer", "Report", "Total", "Date"]
    Enum.find(english_words, fn word -> String.contains?(output, word) end) || ""
  end

  defp consistent_translations?(translated_content) do
    non_empty_content = Enum.filter(translated_content, &(String.length(&1) > 0))
    length(Enum.uniq(non_empty_content)) <= 1
  end

  defp extract_formatted_number(output, _renderer, number) do
    # Look for the formatted version of the number in the output
    number_str = to_string(number)
    base_digits = String.replace(number_str, ".", "")

    # Find formatted version containing the digits
    output
    |> String.split()
    |> Enum.find("", &String.contains?(&1, base_digits))
  end

  defp extract_formatted_currency(output, _renderer, amount, currency) do
    # Look for currency formatted value
    amount_str = :erlang.float_to_binary(amount, decimals: 2)

    output
    |> String.split()
    |> Enum.find("", fn part ->
      String.contains?(part, get_currency_symbol(currency)) or
        String.contains?(part, amount_str)
    end)
  end

  defp extract_formatted_value(output, _renderer, type) do
    case type do
      :currency ->
        output
        |> String.split()
        |> Enum.find("", &(String.contains?(&1, "$") or String.contains?(&1, "USD")))

      :decimal ->
        output
        |> String.split()
        |> Enum.find("", &String.contains?(&1, "."))

      :percentage ->
        output
        |> String.split()
        |> Enum.find("", &String.contains?(&1, "%"))
    end
  end

  defp get_currency_symbol("USD"), do: "$"
  defp get_currency_symbol("EUR"), do: "€"
  defp get_currency_symbol("SAR"), do: "ر.س"
  defp get_currency_symbol(_), do: ""

  defp normalize_currency_value(formatted) do
    # Remove currency symbols and normalize spacing
    formatted
    |> String.replace(~r/[$€ر\.س]/, "")
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end
end
