defmodule AshReports.Integration.TestHelpers do
  @moduledoc """
  Helper functions for AshReports Phase 4 integration tests.

  Provides utilities for testing cross-component integration scenarios,
  multi-renderer consistency, and complex internationalization features.
  """

  alias AshReports.{HeexRenderer, IrHtmlRenderer, JsonRenderer, PdfRenderer}
  alias AshReports.Test.Customer
  alias AshReports.TestHelpers

  @locales ["en", "ar", "he", "fa", "ur", "es", "fr", "de", "ja", "zh"]
  @rtl_locales ["ar", "he", "fa", "ur"]
  @renderers [IrHtmlRenderer, HeexRenderer, PdfRenderer, JsonRenderer]

  # Test Data Generation

  def create_multilingual_test_data do
    [
      %Customer{
        id: 1,
        name: "John Smith",
        email: "john@example.com",
        region: "North America",
        created_at: DateTime.from_naive!(~N[2024-01-15 10:00:00], "Etc/UTC")
      },
      %Customer{
        id: 2,
        # Ahmed Mohammed in Arabic
        name: "أحمد محمد",
        email: "ahmed@example.com",
        region: "Middle East",
        created_at: DateTime.from_naive!(~N[2024-02-20 10:00:00], "Etc/UTC")
      },
      %Customer{
        id: 3,
        # David Cohen in Hebrew
        name: "דוד כהן",
        email: "david@example.com",
        region: "Middle East",
        created_at: DateTime.from_naive!(~N[2024-03-10 10:00:00], "Etc/UTC")
      }
    ]
  end

  def create_arabic_test_data do
    [
      %Customer{
        id: 1,
        name: "محمد أحمد السعودي",
        email: "mohammed@example.sa",
        region: "Saudi Arabia",
        created_at: DateTime.from_naive!(~N[2024-01-15 10:00:00], "Etc/UTC")
      },
      %Customer{
        id: 2,
        name: "فاطمة علي المصري",
        email: "fatima@example.eg",
        region: "Egypt",
        created_at: DateTime.from_naive!(~N[2024-02-20 10:00:00], "Etc/UTC")
      }
    ]
  end

  def create_hebrew_test_data do
    [
      %Customer{
        id: 1,
        name: "דוד כהן",
        email: "david@example.il",
        region: "Israel",
        created_at: DateTime.from_naive!(~N[2024-01-15 10:00:00], "Etc/UTC")
      },
      %Customer{
        id: 2,
        name: "רחל לוי",
        email: "rachel@example.il",
        region: "Israel",
        created_at: DateTime.from_naive!(~N[2024-02-20 10:00:00], "Etc/UTC")
      }
    ]
  end

  # Context Creation

  def create_integration_context(locale, custom_format \\ nil) do
    %AshReports.RenderContext{
      locale: locale,
      text_direction: if(locale in @rtl_locales, do: "rtl", else: "ltr"),
      locale_metadata: %{
        cldr_locale: locale,
        format_specifications: custom_format || default_format_specs(),
        translation_domain: AshReports.Translation,
        rtl_enabled: locale in @rtl_locales
      },
      config: %{
        renderer_config: %{},
        performance_metrics: %{}
      }
    }
  end

  def create_cldr_context(locale) do
    context = create_integration_context(locale)

    metadata =
      Map.merge(context.locale_metadata, %{
        cldr_enabled: true,
        number_formatting: true,
        currency_formatting: true
      })

    %{context | locale_metadata: metadata}
  end

  def create_rtl_context(locale) when locale in @rtl_locales do
    context = create_integration_context(locale)

    metadata =
      Map.merge(context.locale_metadata, %{
        rtl_layout_enabled: true,
        element_mirroring: true,
        text_alignment: "right"
      })

    %{context | locale_metadata: metadata}
  end

  def create_translation_context(locale, renderer) do
    context = create_integration_context(locale)

    metadata =
      Map.merge(context.locale_metadata, %{
        translation_enabled: true,
        renderer: renderer,
        fallback_locale: "en"
      })

    %{context | locale_metadata: metadata}
  end

  def create_full_phase4_context(locale) do
    context = create_integration_context(locale)

    metadata =
      Map.merge(context.locale_metadata, %{
        cldr_enabled: true,
        format_specifications_enabled: true,
        translation_enabled: true,
        rtl_enabled: locale in @rtl_locales,
        performance_tracking: true
      })

    %{context | locale_metadata: metadata}
  end

  # Report Building

  def build_rtl_test_report do
    TestHelpers.build_simple_report()
    # "Customer Report" in Arabic
    |> Map.put(:title, "تقرير العملاء")
    |> Map.put(:supports_rtl, true)
    |> Map.put(:formats, [:html, :heex, :pdf])
  end

  def build_translatable_report do
    TestHelpers.build_simple_report()
    |> Map.put(:translatable_fields, [:title, :field_labels, :band_headers])
    |> Map.put(:translation_keys, %{
      title: "report.customer.title",
      name_field: "field.customer.name",
      email_field: "field.customer.email"
    })
  end

  def build_phase4_enhanced_report do
    TestHelpers.build_simple_report()
    |> Map.put(:cldr_formatting, true)
    |> Map.put(:custom_format_specs, true)
    |> Map.put(:rtl_support, true)
    |> Map.put(:translation_support, true)
    |> Map.put(:all_renderers, @renderers)
  end

  # Format Specification Generation

  def default_format_specs do
    %{
      currency: %{
        type: :currency,
        precision: 2,
        grouping: true,
        currency_symbol: true
      },
      decimal: %{
        type: :decimal,
        precision: 2,
        grouping: true
      },
      percentage: %{
        type: :percentage,
        precision: 1
      }
    }
  end

  def generate_format_spec do
    # For property-based testing
    %{
      type: Enum.random([:currency, :decimal, :percentage]),
      precision: Enum.random(0..6),
      grouping: Enum.random([true, false]),
      currency_symbol: Enum.random([true, false])
    }
  end

  # Validation Helpers

  def contains_rtl_markers?(content) when is_binary(content) do
    String.contains?(content, ["dir=\"rtl\"", "direction: rtl", "text-align: right"]) or
      String.contains?(content, ["rtl-", "arabic-", "hebrew-"])
  end

  def validates_rtl_output?(result, renderer) do
    case renderer do
      IrHtmlRenderer ->
        String.contains?(result, "dir=\"rtl\"")

      HeexRenderer ->
        String.contains?(result, "dir={@text_direction}")

      PdfRenderer ->
        # PDF should have RTL layout markers
        String.contains?(result, "rtl_layout")

      JsonRenderer ->
        # JSON should contain RTL metadata
        String.contains?(result, "text_direction")
    end
  end

  def consistent_rtl_behavior?(results) do
    # Check that all renderers handle RTL consistently
    rtl_indicators =
      Enum.map(results, fn {renderer, result} ->
        {renderer, contains_rtl_markers?(result)}
      end)

    # All should either have RTL markers or none should
    rtl_values = Enum.map(rtl_indicators, fn {_, has_rtl} -> has_rtl end)
    Enum.all?(rtl_values, & &1) or Enum.all?(rtl_values, &(not &1))
  end

  def contains_translations?(result, locale, _renderer) do
    # Basic check - should not contain untranslated keys
    # Should contain locale-appropriate content
    not String.contains?(result, ["translation.missing", "gettext.not_found"]) and
      case locale do
        # Arabic text
        "ar" -> String.contains?(result, ["العملاء", "التقرير"])
        # Hebrew text
        "he" -> String.contains?(result, ["לקוחות", "דוח"])
        # Spanish text
        "es" -> String.contains?(result, ["Clientes", "Informe"])
        _ -> String.length(result) > 0
      end
  end

  def valid_output?(result, renderer) do
    case renderer do
      IrHtmlRenderer -> String.starts_with?(result, ["<", "<!DOCTYPE"])
      HeexRenderer -> String.contains?(result, ["<", "phx-"])
      PdfRenderer -> String.starts_with?(result, "%PDF-")
      JsonRenderer -> String.starts_with?(result, ["{", "["])
    end
  end

  def contains_fallback_text?(result) do
    # Check for fallback content when translations are missing
    # English fallbacks
    String.contains?(result, ["Name", "Email", "Customer"])
  end

  def contains_error_markers?(result) do
    String.contains?(result, ["error", "ERROR", "exception", "crash"])
  end

  def contains_error_handling_output?(result) do
    # Should contain graceful error handling, not raw errors
    contains_fallback_text?(result) and not contains_error_markers?(result)
  end

  # Error Context Generation

  def create_context_with_missing_translations(locale \\ "invalid_locale") do
    create_integration_context(locale)
    |> Map.put(:translation_domain, NonExistentModule)
    |> Map.put(:fallback_enabled, true)
  end

  def create_context_with_invalid_rtl_config do
    create_integration_context("ar")
    |> Map.put(:text_direction, "invalid")
    |> Map.put(:rtl_layout_data, :corrupted)
  end

  def create_context_with_missing_rtl_data do
    create_integration_context("ar")
    |> Map.put(:rtl_layout_engine, nil)
    |> Map.put(:element_positions, [])
  end

  def create_context_with_corrupted_layout_data do
    create_integration_context("ar")
    |> Map.put(:layout_calculations, %{invalid: "data"})
  end

  def create_error_prone_context(value, locale, format_spec) do
    create_integration_context(locale)
    |> Map.put(:test_value, value)
    |> Map.put(:format_specifications, format_spec)
    |> Map.put(:error_handling_mode, :graceful)
  end

  # Performance Helpers

  def create_performance_test_data(size \\ 100) do
    1..size
    |> Enum.map(fn i ->
      %Customer{
        id: i,
        name: "Customer #{i}",
        email: "customer#{i}@example.com",
        region: "Region #{rem(i, 5) + 1}",
        created_at:
          DateTime.from_naive!(~N[2024-01-01 10:00:00], "Etc/UTC") |> DateTime.add(i, :day)
      }
    end)
  end

  def measure_memory_usage(fun) do
    {memory_before, _} = :erlang.process_info(self(), :memory)
    result = fun.()
    {memory_after, _} = :erlang.process_info(self(), :memory)
    {result, memory_after - memory_before}
  end

  # Getters

  def locales, do: @locales
  def rtl_locales, do: @rtl_locales
  def renderers, do: @renderers
end
