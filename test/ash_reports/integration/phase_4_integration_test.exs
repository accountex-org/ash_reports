defmodule AshReports.Integration.Phase4IntegrationTest do
  @moduledoc """
  Integration tests for AshReports Phase 4 components working together.

  Tests the integration between:
  - Phase 4.1: CLDR Integration (locale detection, number/date formatting)
  - Phase 4.2: Format Specifications (advanced customization)
  - Phase 4.3: Locale-aware Rendering (RTL support, translations)
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshReports.{Cldr, Formatter, RtlLayoutEngine, Translation}
  alias AshReports.Integration.TestHelpers
  alias AshReports.TestHelpers, as: BaseTestHelpers

  @moduletag :integration

  describe "Phase 4.1 + 4.2 Integration (CLDR + Format Specifications)" do
    test "CLDR formatting works with custom format specifications" do
      # Test various locales with custom format specs
      test_cases = [
        {"en", 1234.56, %{type: :currency, precision: 2, currency: "USD"}},
        {"ar", 9876.54, %{type: :currency, precision: 2, currency: "SAR"}},
        {"de", 5555.55, %{type: :decimal, precision: 3, grouping: true}},
        {"ja", 123_456_789, %{type: :number, grouping: true, format: :long}}
      ]

      for {locale, value, format_spec} <- test_cases do
        context = TestHelpers.create_integration_context(locale, format_spec)

        # Apply CLDR formatting
        {:ok, cldr_result} = Cldr.format_number(value, locale, format_spec)

        # Apply custom format specification enhancement
        {:ok, final_result} = Formatter.apply_format_spec(cldr_result, format_spec, context)

        assert is_binary(final_result)
        assert String.length(final_result) > 0

        # Verify locale-specific formatting was applied
        case locale do
          # SAR currency symbol
          "ar" -> assert String.contains?(final_result, "ر.س")
          # German decimal separator
          "de" -> assert String.contains?(final_result, ",")
          _ -> assert String.length(final_result) > String.length(inspect(value))
        end
      end
    end

    test "date formatting integration with custom format specifications" do
      test_date = ~D[2024-03-15]

      format_specs = [
        %{type: :date, format: :long, calendar: :gregorian},
        %{type: :date, format: :medium, show_weekday: true},
        %{type: :date, format: :short, separator: "/"}
      ]

      for locale <- ["en", "ar", "es", "fr"] do
        for format_spec <- format_specs do
          context = TestHelpers.create_integration_context(locale, format_spec)

          {:ok, cldr_formatted} = Cldr.format_date(test_date, locale)

          {:ok, spec_formatted} =
            Formatter.apply_format_spec(cldr_formatted, format_spec, context)

          assert is_binary(spec_formatted)
          assert spec_formatted != inspect(test_date)

          # Verify format specification was applied
          if format_spec.separator do
            assert String.contains?(spec_formatted, format_spec.separator)
          end
        end
      end
    end
  end

  describe "Phase 4.2 + 4.3 Integration (Format Specifications + RTL/Translation)" do
    test "custom format specifications work with RTL layouts" do
      rtl_locales = TestHelpers.rtl_locales()

      for locale <- rtl_locales do
        context = TestHelpers.create_rtl_context(locale)
        format_spec = %{type: :currency, precision: 2, rtl_aware: true}

        value = 12345.67
        {:ok, cldr_result} = Cldr.format_currency(value, locale, "SAR")
        {:ok, formatted} = Formatter.apply_format_spec(cldr_result, format_spec, context)
        {:ok, rtl_adapted} = RtlLayoutEngine.adapt_formatted_content(formatted, context)

        assert is_binary(rtl_adapted)
        # Should contain RTL direction markers or formatting
        assert TestHelpers.contains_rtl_markers?(rtl_adapted)
      end
    end

    test "translated format specifications apply correctly" do
      locale = "ar"
      context = TestHelpers.create_translation_context(locale, AshReports.HtmlRenderer)

      format_spec = %{
        type: :currency,
        precision: 2,
        currency: "SAR",
        show_label: true,
        label_key: "currency.label.total"
      }

      value = 999.99
      {:ok, cldr_result} = Cldr.format_currency(value, locale, "SAR")
      {:ok, formatted} = Formatter.apply_format_spec(cldr_result, format_spec, context)

      # Should contain translated label
      assert is_binary(formatted)
      # Should not contain untranslated key
      refute String.contains?(formatted, "currency.label.total")
    end
  end

  describe "Phase 4.1 + 4.3 Integration (CLDR + RTL/Translation)" do
    test "CLDR formatting integrates with translation system" do
      test_cases = [
        {"ar", "currency.format.total", 1500.50, "SAR"},
        {"he", "number.format.count", 42, nil},
        {"fa", "percentage.format.rate", 0.85, nil}
      ]

      for {locale, translation_key, value, currency} <- test_cases do
        context = TestHelpers.create_full_phase4_context(locale)

        # Get translated format template
        {:ok, format_template} = Translation.translate_ui(translation_key, [], locale)

        # Apply CLDR formatting
        formatted_value =
          if currency do
            {:ok, result} = Cldr.format_currency(value, locale, currency)
            result
          else
            {:ok, result} = Cldr.format_number(value, locale)
            result
          end

        # Combine translation with formatting
        final_result = String.replace(format_template, "{value}", formatted_value)

        assert is_binary(final_result)
        assert String.contains?(final_result, formatted_value)
        refute String.contains?(final_result, "{value}")
      end
    end

    test "RTL text direction works with CLDR number formatting" do
      for locale <- TestHelpers.rtl_locales() do
        context = TestHelpers.create_rtl_context(locale)

        numbers = [123.45, 9876.54, 0.123, 999_999.99]

        for number <- numbers do
          {:ok, cldr_formatted} = Cldr.format_number(number, locale)
          {:ok, rtl_adapted} = RtlLayoutEngine.adapt_number_formatting(cldr_formatted, context)

          assert is_binary(rtl_adapted)
          # RTL numbers should maintain proper formatting
          assert String.length(rtl_adapted) >= String.length(cldr_formatted)
        end
      end
    end
  end

  describe "Full Phase 4 Integration (4.1 + 4.2 + 4.3)" do
    test "all Phase 4 components work together seamlessly" do
      locale = "ar"
      context = TestHelpers.create_full_phase4_context(locale)

      # Complex scenario: RTL report with CLDR formatting and custom format specs
      report_data = %{
        title_key: "report.customer.title",
        customers: TestHelpers.create_arabic_test_data(),
        total_amount: 15750.25,
        currency: "SAR",
        generated_date: Date.utc_today()
      }

      format_specs = %{
        currency: %{type: :currency, precision: 2, show_symbol: true},
        date: %{type: :date, format: :long, rtl_aware: true}
      }

      # Step 1: Translate report title
      {:ok, translated_title} = Translation.translate_ui(report_data.title_key, [], locale)

      # Step 2: Apply CLDR formatting to amounts and dates
      {:ok, formatted_amount} =
        Cldr.format_currency(report_data.total_amount, locale, report_data.currency)

      {:ok, formatted_date} = Cldr.format_date(report_data.generated_date, locale)

      # Step 3: Apply custom format specifications
      {:ok, spec_amount} =
        Formatter.apply_format_spec(formatted_amount, format_specs.currency, context)

      {:ok, spec_date} = Formatter.apply_format_spec(formatted_date, format_specs.date, context)

      # Step 4: Apply RTL layout adaptations
      {:ok, rtl_title} = RtlLayoutEngine.adapt_text_content(translated_title, context)
      {:ok, rtl_amount} = RtlLayoutEngine.adapt_formatted_content(spec_amount, context)
      {:ok, rtl_date} = RtlLayoutEngine.adapt_formatted_content(spec_date, context)

      # Verify all components worked together
      assert is_binary(rtl_title) and String.length(rtl_title) > 0
      assert is_binary(rtl_amount) and TestHelpers.contains_rtl_markers?(rtl_amount)
      assert is_binary(rtl_date) and TestHelpers.contains_rtl_markers?(rtl_date)

      # Verify no component corrupted the others
      assert not String.contains?(rtl_title, "translation.missing")
      # SAR currency symbol
      assert String.contains?(rtl_amount, "ر.س")
      assert not String.contains?(rtl_date, "ERROR")
    end

    property "Phase 4 integration works across various inputs" do
      check all(
              locale <- member_of(TestHelpers.locales()),
              amount <- float(min: 0.01, max: 999_999.99),
              precision <- integer(0..4),
              50
            ) do
        context = TestHelpers.create_full_phase4_context(locale)

        format_spec = %{
          type: :currency,
          precision: precision,
          grouping: true,
          currency: if(locale in TestHelpers.rtl_locales(), do: "SAR", else: "USD")
        }

        # Apply full Phase 4 pipeline
        {:ok, cldr_result} = Cldr.format_currency(amount, locale, format_spec.currency)
        {:ok, spec_result} = Formatter.apply_format_spec(cldr_result, format_spec, context)

        final_result =
          if locale in TestHelpers.rtl_locales() do
            {:ok, rtl_result} = RtlLayoutEngine.adapt_formatted_content(spec_result, context)
            rtl_result
          else
            spec_result
          end

        # Verify pipeline completed successfully
        assert is_binary(final_result)
        assert String.length(final_result) > 0

        # Verify locale-specific adaptations
        if locale in TestHelpers.rtl_locales() do
          assert TestHelpers.contains_rtl_markers?(final_result) or
                   String.length(final_result) >= String.length(spec_result)
        end
      end
    end
  end

  describe "Error Handling Integration" do
    test "Phase 4 components handle errors gracefully together" do
      # Test error scenarios where one component fails but others continue
      error_scenarios = [
        %{
          locale: "invalid_locale",
          context_override: %{fallback_enabled: true},
          expected_behavior: :graceful_fallback
        },
        %{
          locale: "ar",
          context_override: %{rtl_layout_engine: nil},
          expected_behavior: :rtl_disabled_but_other_features_work
        },
        %{
          locale: "en",
          context_override: %{format_specifications: %{invalid: "spec"}},
          expected_behavior: :default_formatting_used
        }
      ]

      for scenario <- error_scenarios do
        context = TestHelpers.create_full_phase4_context(scenario.locale)
        context = Map.merge(context, scenario.context_override)

        # Should not crash, should handle gracefully
        result =
          try do
            value = 123.45
            {:ok, cldr_result} = Cldr.format_number(value, scenario.locale)

            {:ok, formatted} =
              Formatter.apply_format_spec(cldr_result, %{type: :decimal}, context)

            final =
              if scenario.locale in TestHelpers.rtl_locales() and context.rtl_layout_engine do
                {:ok, rtl} = RtlLayoutEngine.adapt_formatted_content(formatted, context)
                rtl
              else
                formatted
              end

            {:ok, final}
          rescue
            error -> {:error, error}
          catch
            :exit, reason -> {:exit, reason}
            thrown -> {:throw, thrown}
          end

        # Should either succeed or fail gracefully
        case result do
          {:ok, output} ->
            assert is_binary(output)
            assert String.length(output) > 0

          {:error, _error} ->
            # Error should be expected and handled
            assert scenario.expected_behavior in [:graceful_fallback, :expected_error]
        end
      end
    end
  end
end
