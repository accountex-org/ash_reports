defmodule AshReports.Renderer.Typst.I18nTest do
  @moduledoc """
  Tests for the internationalization module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Renderer.Typst.I18n

  describe "default_locale/0" do
    test "returns en-US as default" do
      assert I18n.default_locale() == "en-US"
    end
  end

  describe "supported_locales/0" do
    test "returns list of supported locales" do
      locales = I18n.supported_locales()
      assert "en-US" in locales
      assert "de-DE" in locales
      assert "fr-FR" in locales
      assert "ja-JP" in locales
    end
  end

  describe "supported_currencies/0" do
    test "returns list of supported currencies" do
      currencies = I18n.supported_currencies()
      assert "USD" in currencies
      assert "EUR" in currencies
      assert "GBP" in currencies
      assert "JPY" in currencies
    end
  end

  describe "format_number/2" do
    test "formats number with en-US locale" do
      assert I18n.format_number(1234.56, locale: "en-US") == "1,234.56"
    end

    test "formats number with de-DE locale" do
      assert I18n.format_number(1234.56, locale: "de-DE") == "1.234,56"
    end

    test "formats number with fr-FR locale" do
      assert I18n.format_number(1234.56, locale: "fr-FR") == "1 234,56"
    end

    test "formats number with custom decimal places" do
      assert I18n.format_number(1234, locale: "en-US", decimal_places: 0) == "1,234"
    end

    test "formats number with more decimal places" do
      assert I18n.format_number(1234.5678, locale: "en-US", decimal_places: 4) == "1,234.5678"
    end

    test "formats large numbers" do
      assert I18n.format_number(1_234_567.89, locale: "en-US") == "1,234,567.89"
    end

    test "formats small numbers without thousand separator" do
      assert I18n.format_number(123.45, locale: "en-US") == "123.45"
    end

    test "formats zero" do
      assert I18n.format_number(0, locale: "en-US") == "0.00"
    end

    test "formats negative numbers" do
      assert I18n.format_number(-1234.56, locale: "en-US") == "-1,234.56"
    end

    test "uses default locale when not specified" do
      assert I18n.format_number(1234.56) == "1,234.56"
    end

    test "falls back to default for unknown locale" do
      assert I18n.format_number(1234.56, locale: "unknown") == "1,234.56"
    end
  end

  describe "format_currency/3" do
    test "formats USD with en-US locale" do
      assert I18n.format_currency(1234.56, "USD", locale: "en-US") == "$1,234.56"
    end

    test "formats EUR with de-DE locale" do
      assert I18n.format_currency(1234.56, "EUR", locale: "de-DE") == "1.234,56 €"
    end

    test "formats GBP with en-GB locale" do
      assert I18n.format_currency(1234.56, "GBP", locale: "en-GB") == "£1,234.56"
    end

    test "formats JPY with no decimal places" do
      assert I18n.format_currency(1234, "JPY", locale: "ja-JP") == "¥1,234"
    end

    test "formats EUR with fr-FR locale" do
      assert I18n.format_currency(1234.56, "EUR", locale: "fr-FR") == "1 234,56 €"
    end

    test "formats USD with symbol before number" do
      result = I18n.format_currency(99.99, "USD", locale: "en-US")
      assert String.starts_with?(result, "$")
    end

    test "formats EUR with de-DE symbol after number" do
      result = I18n.format_currency(99.99, "EUR", locale: "de-DE")
      assert String.ends_with?(result, "€")
    end

    test "formats unknown currency with code as symbol" do
      assert I18n.format_currency(100.00, "XYZ", locale: "en-US") == "XYZ100.00"
    end

    test "formats large currency amounts" do
      assert I18n.format_currency(1_000_000.00, "USD", locale: "en-US") == "$1,000,000.00"
    end

    test "formats zero currency" do
      assert I18n.format_currency(0, "USD", locale: "en-US") == "$0.00"
    end
  end

  describe "format_date/2" do
    test "formats date with en-US locale (MDY)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "en-US") == "01/15/2025"
    end

    test "formats date with de-DE locale (DMY with dots)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "de-DE") == "15.01.2025"
    end

    test "formats date with en-GB locale (DMY)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "en-GB") == "15/01/2025"
    end

    test "formats date with fr-FR locale (DMY slash)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "fr-FR") == "15/01/2025"
    end

    test "formats date with ja-JP locale (YMD)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "ja-JP") == "2025/01/15"
    end

    test "formats date with zh-CN locale (YMD)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "zh-CN") == "2025/01/15"
    end

    test "pads single digit months" do
      date = ~D[2025-01-05]
      assert I18n.format_date(date, locale: "en-US") == "01/05/2025"
    end

    test "uses default locale when not specified" do
      date = ~D[2025-12-25]
      assert I18n.format_date(date) == "12/25/2025"
    end
  end

  describe "format_time/2" do
    test "formats time with en-US locale (12-hour)" do
      time = ~T[14:30:00]
      assert I18n.format_time(time, locale: "en-US") == "2:30 PM"
    end

    test "formats time with de-DE locale (24-hour)" do
      time = ~T[14:30:00]
      assert I18n.format_time(time, locale: "de-DE") == "14:30"
    end

    test "formats midnight in 12-hour format" do
      time = ~T[00:00:00]
      assert I18n.format_time(time, locale: "en-US") == "12:00 AM"
    end

    test "formats noon in 12-hour format" do
      time = ~T[12:00:00]
      assert I18n.format_time(time, locale: "en-US") == "12:00 PM"
    end

    test "formats morning time in 12-hour format" do
      time = ~T[09:15:00]
      assert I18n.format_time(time, locale: "en-US") == "9:15 AM"
    end

    test "formats afternoon time in 12-hour format" do
      time = ~T[15:45:00]
      assert I18n.format_time(time, locale: "en-US") == "3:45 PM"
    end

    test "formats time with 24-hour format" do
      time = ~T[23:59:00]
      assert I18n.format_time(time, locale: "de-DE") == "23:59"
    end

    test "pads single digit hours in 24-hour format" do
      time = ~T[09:05:00]
      assert I18n.format_time(time, locale: "de-DE") == "09:05"
    end

    test "uses default locale when not specified" do
      time = ~T[10:30:00]
      assert I18n.format_time(time) == "10:30 AM"
    end
  end

  describe "format_datetime/2" do
    test "formats NaiveDateTime with en-US locale" do
      datetime = ~N[2025-01-15 14:30:00]
      assert I18n.format_datetime(datetime, locale: "en-US") == "01/15/2025 2:30 PM"
    end

    test "formats NaiveDateTime with de-DE locale" do
      datetime = ~N[2025-01-15 14:30:00]
      assert I18n.format_datetime(datetime, locale: "de-DE") == "15.01.2025 14:30"
    end

    test "formats DateTime with en-US locale" do
      {:ok, datetime} = DateTime.new(~D[2025-01-15], ~T[14:30:00], "Etc/UTC")
      assert I18n.format_datetime(datetime, locale: "en-US") == "01/15/2025 2:30 PM"
    end

    test "uses default locale when not specified" do
      datetime = ~N[2025-12-25 09:00:00]
      assert I18n.format_datetime(datetime) == "12/25/2025 9:00 AM"
    end
  end

  describe "format_percent/2" do
    test "formats percent with en-US locale" do
      assert I18n.format_percent(0.125, locale: "en-US") == "12.5%"
    end

    test "formats percent with de-DE locale" do
      assert I18n.format_percent(0.125, locale: "de-DE") == "12,5%"
    end

    test "formats percent with custom decimal places" do
      assert I18n.format_percent(0.12345, locale: "en-US", decimal_places: 2) == "12.35%"
    end

    test "formats zero percent" do
      assert I18n.format_percent(0, locale: "en-US") == "0.0%"
    end

    test "formats 100 percent" do
      assert I18n.format_percent(1.0, locale: "en-US") == "100.0%"
    end

    test "formats percent over 100" do
      assert I18n.format_percent(1.5, locale: "en-US") == "150.0%"
    end

    test "uses default locale when not specified" do
      assert I18n.format_percent(0.5) == "50.0%"
    end
  end

  describe "get_currency_symbol/1" do
    test "returns symbol for USD" do
      assert I18n.get_currency_symbol("USD") == "$"
    end

    test "returns symbol for EUR" do
      assert I18n.get_currency_symbol("EUR") == "€"
    end

    test "returns symbol for GBP" do
      assert I18n.get_currency_symbol("GBP") == "£"
    end

    test "returns symbol for JPY" do
      assert I18n.get_currency_symbol("JPY") == "¥"
    end

    test "returns code for unknown currency" do
      assert I18n.get_currency_symbol("XYZ") == "XYZ"
    end
  end

  describe "get_currency_decimal_places/1" do
    test "returns 2 for USD" do
      assert I18n.get_currency_decimal_places("USD") == 2
    end

    test "returns 0 for JPY" do
      assert I18n.get_currency_decimal_places("JPY") == 0
    end

    test "returns 2 for unknown currency" do
      assert I18n.get_currency_decimal_places("XYZ") == 2
    end
  end

  describe "get_locale_config/1" do
    test "returns config for en-US" do
      config = I18n.get_locale_config("en-US")
      assert config.decimal_separator == "."
      assert config.thousand_separator == ","
      assert config.currency_symbol_position == :before
    end

    test "returns config for de-DE" do
      config = I18n.get_locale_config("de-DE")
      assert config.decimal_separator == ","
      assert config.thousand_separator == "."
      assert config.currency_symbol_position == :after
    end

    test "returns default config for unknown locale" do
      config = I18n.get_locale_config("unknown")
      assert config.decimal_separator == "."
      assert config.thousand_separator == ","
    end
  end

  describe "integration scenarios" do
    test "formats invoice with multiple currencies" do
      # USD in US format
      usd_amount = I18n.format_currency(1234.56, "USD", locale: "en-US")
      assert usd_amount == "$1,234.56"

      # EUR in German format
      eur_amount = I18n.format_currency(1234.56, "EUR", locale: "de-DE")
      assert eur_amount == "1.234,56 €"

      # GBP in UK format
      gbp_amount = I18n.format_currency(1234.56, "GBP", locale: "en-GB")
      assert gbp_amount == "£1,234.56"
    end

    test "formats report with date and time" do
      date = ~D[2025-01-15]
      time = ~T[14:30:00]

      # US format
      us_date = I18n.format_date(date, locale: "en-US")
      us_time = I18n.format_time(time, locale: "en-US")
      assert "#{us_date} #{us_time}" == "01/15/2025 2:30 PM"

      # German format
      de_date = I18n.format_date(date, locale: "de-DE")
      de_time = I18n.format_time(time, locale: "de-DE")
      assert "#{de_date} #{de_time}" == "15.01.2025 14:30"
    end

    test "formats financial report with percentages and numbers" do
      # Growth rate
      growth = I18n.format_percent(0.0825, locale: "en-US", decimal_places: 2)
      assert growth == "8.25%"

      # Revenue
      revenue = I18n.format_currency(1_250_000.00, "USD", locale: "en-US")
      assert revenue == "$1,250,000.00"

      # Expenses
      expenses = I18n.format_number(875_432.50, locale: "en-US")
      assert expenses == "875,432.50"
    end

    test "formats multi-locale report" do
      amount = 9999.99
      date = ~D[2025-06-30]

      # US region
      us_result = %{
        amount: I18n.format_currency(amount, "USD", locale: "en-US"),
        date: I18n.format_date(date, locale: "en-US")
      }
      assert us_result.amount == "$9,999.99"
      assert us_result.date == "06/30/2025"

      # German region
      de_result = %{
        amount: I18n.format_currency(amount, "EUR", locale: "de-DE"),
        date: I18n.format_date(date, locale: "de-DE")
      }
      assert de_result.amount == "9.999,99 €"
      assert de_result.date == "30.06.2025"

      # Japanese region
      jp_result = %{
        amount: I18n.format_currency(round(amount), "JPY", locale: "ja-JP"),
        date: I18n.format_date(date, locale: "ja-JP")
      }
      assert jp_result.amount == "¥10,000"
      assert jp_result.date == "2025/06/30"
    end
  end

  # ============================================================================
  # EXPANDED TEST COVERAGE
  # ============================================================================

  describe "format_currency/3 - negative amounts" do
    test "formats negative USD amount" do
      assert I18n.format_currency(-1234.56, "USD", locale: "en-US") == "$-1,234.56"
    end

    test "formats negative EUR amount with German locale" do
      result = I18n.format_currency(-1234.56, "EUR", locale: "de-DE")
      assert String.contains?(result, "-")
      assert String.contains?(result, "€")
    end

    test "formats negative JPY amount" do
      result = I18n.format_currency(-1000, "JPY", locale: "ja-JP")
      assert String.contains?(result, "-")
      assert String.contains?(result, "¥")
    end

    test "formats zero and near-zero negative values" do
      assert I18n.format_currency(-0.01, "USD", locale: "en-US") == "$-0.01"
    end
  end

  describe "format_percent/2 - negative values" do
    test "formats negative percentage" do
      assert I18n.format_percent(-0.25, locale: "en-US") == "-25.0%"
    end

    test "formats negative percentage with German locale" do
      assert I18n.format_percent(-0.25, locale: "de-DE") == "-25,0%"
    end

    test "formats negative percentage with custom decimal places" do
      assert I18n.format_percent(-0.12345, locale: "en-US", decimal_places: 2) == "-12.35%"
    end

    test "formats large negative percentage (decline > 100%)" do
      assert I18n.format_percent(-1.5, locale: "en-US") == "-150.0%"
    end

    test "formats zero negative percentage" do
      assert I18n.format_percent(-0.0, locale: "en-US") == "0.0%"
    end
  end

  describe "complete currency coverage" do
    test "returns symbol for CHF (Swiss Franc)" do
      assert I18n.get_currency_symbol("CHF") == "CHF"
    end

    test "returns decimal places for CHF" do
      assert I18n.get_currency_decimal_places("CHF") == 2
    end

    test "formats CHF currency" do
      result = I18n.format_currency(1000.00, "CHF", locale: "en-US")
      assert result == "CHF1,000.00"
    end

    test "returns symbol for CAD (Canadian Dollar)" do
      assert I18n.get_currency_symbol("CAD") == "CA$"
    end

    test "returns decimal places for CAD" do
      assert I18n.get_currency_decimal_places("CAD") == 2
    end

    test "formats CAD currency" do
      assert I18n.format_currency(1000.00, "CAD", locale: "en-US") == "CA$1,000.00"
    end

    test "returns symbol for AUD (Australian Dollar)" do
      assert I18n.get_currency_symbol("AUD") == "A$"
    end

    test "returns decimal places for AUD" do
      assert I18n.get_currency_decimal_places("AUD") == 2
    end

    test "formats AUD currency" do
      assert I18n.format_currency(1000.00, "AUD", locale: "en-US") == "A$1,000.00"
    end

    test "returns symbol for MXN (Mexican Peso)" do
      assert I18n.get_currency_symbol("MXN") == "MX$"
    end

    test "returns decimal places for MXN" do
      assert I18n.get_currency_decimal_places("MXN") == 2
    end

    test "formats MXN currency" do
      assert I18n.format_currency(1000.00, "MXN", locale: "en-US") == "MX$1,000.00"
    end

    test "returns symbol for BRL (Brazilian Real)" do
      assert I18n.get_currency_symbol("BRL") == "R$"
    end

    test "returns decimal places for BRL" do
      assert I18n.get_currency_decimal_places("BRL") == 2
    end

    test "formats BRL currency" do
      assert I18n.format_currency(1000.00, "BRL", locale: "en-US") == "R$1,000.00"
    end

    test "returns symbol for CNY (Chinese Yuan)" do
      assert I18n.get_currency_symbol("CNY") == "¥"
    end

    test "returns decimal places for CNY" do
      assert I18n.get_currency_decimal_places("CNY") == 2
    end

    test "formats CNY currency" do
      assert I18n.format_currency(1000.00, "CNY", locale: "en-US") == "¥1,000.00"
    end
  end

  describe "es-ES locale tests" do
    test "formats number with es-ES locale" do
      assert I18n.format_number(1234.56, locale: "es-ES") == "1.234,56"
    end

    test "formats date with es-ES locale (DMY slash)" do
      date = ~D[2025-01-15]
      assert I18n.format_date(date, locale: "es-ES") == "15/01/2025"
    end

    test "formats time with es-ES locale (24-hour)" do
      time = ~T[14:30:00]
      assert I18n.format_time(time, locale: "es-ES") == "14:30"
    end

    test "formats morning time with es-ES locale" do
      time = ~T[09:15:00]
      assert I18n.format_time(time, locale: "es-ES") == "09:15"
    end

    test "formats EUR with es-ES locale" do
      assert I18n.format_currency(1234.56, "EUR", locale: "es-ES") == "1.234,56 €"
    end

    test "formats NaiveDateTime with es-ES locale" do
      datetime = ~N[2025-01-15 14:30:00]
      assert I18n.format_datetime(datetime, locale: "es-ES") == "15/01/2025 14:30"
    end

    test "formats percent with es-ES locale" do
      assert I18n.format_percent(0.125, locale: "es-ES") == "12,5%"
    end
  end

  describe "error handling and edge cases" do
    test "handles empty string locale by using default" do
      result = I18n.format_number(1234.56, locale: "")
      assert is_binary(result)
    end

    test "handles empty string currency code" do
      result = I18n.format_currency(100.0, "", locale: "en-US")
      assert is_binary(result)
    end

    test "handles special characters in unknown locale" do
      result = I18n.format_number(1234.56, locale: "@#$%")
      assert is_binary(result)
    end

    test "decimal_places clamped to valid range" do
      # Very large decimal places should be clamped
      result = I18n.format_number(1234.56, locale: "en-US", decimal_places: 100)
      assert is_binary(result)
      # Should not have 100 decimal places
      assert String.length(result) < 50
    end

    test "negative decimal places clamped to zero" do
      result = I18n.format_number(1234.56, locale: "en-US", decimal_places: -5)
      assert is_binary(result)
    end
  end

  describe "rounding behavior" do
    test "rounds currency to correct decimal places" do
      result = I18n.format_currency(1234.567, "USD", locale: "en-US")
      assert result == "$1,234.57"
    end

    test "rounds down when appropriate" do
      result = I18n.format_currency(1234.564, "USD", locale: "en-US")
      assert result == "$1,234.56"
    end

    test "rounds JPY correctly (zero decimal places)" do
      result = I18n.format_currency(1234.567, "JPY", locale: "ja-JP")
      assert String.contains?(result, "1,235")
    end

    test "rounds percentage correctly" do
      assert I18n.format_percent(0.12345, locale: "en-US", decimal_places: 2) == "12.35%"
    end

    test "rounds percentage down when appropriate" do
      assert I18n.format_percent(0.12344, locale: "en-US", decimal_places: 2) == "12.34%"
    end
  end

  describe "numeric boundary values" do
    test "formats very large numbers (billion scale)" do
      assert I18n.format_number(1_000_000_000.00, locale: "en-US") == "1,000,000,000.00"
    end

    test "formats very large numbers (trillion scale)" do
      assert I18n.format_number(999_999_999_999.99, locale: "en-US") == "999,999,999,999.99"
    end

    test "formats very small decimal numbers" do
      assert I18n.format_number(0.001, locale: "en-US", decimal_places: 3) == "0.001"
    end

    test "formats very small decimal with rounding" do
      assert I18n.format_number(0.0001, locale: "en-US", decimal_places: 3) == "0.000"
    end

    test "formats number with single thousand separator" do
      assert I18n.format_number(1000.00, locale: "en-US") == "1,000.00"
    end
  end

  describe "date boundary values" do
    test "formats year boundary - last day of year" do
      date = ~D[2025-12-31]
      assert I18n.format_date(date, locale: "en-US") == "12/31/2025"
    end

    test "formats year boundary - first day of year" do
      date = ~D[2026-01-01]
      assert I18n.format_date(date, locale: "en-US") == "01/01/2026"
    end

    test "formats leap year date" do
      date = ~D[2024-02-29]
      assert I18n.format_date(date, locale: "en-US") == "02/29/2024"
    end

    test "formats non-leap year February 28" do
      date = ~D[2025-02-28]
      assert I18n.format_date(date, locale: "en-US") == "02/28/2025"
    end

    test "formats century boundary date" do
      date = ~D[2100-01-01]
      assert I18n.format_date(date, locale: "en-US") == "01/01/2100"
    end
  end

  describe "time boundary values" do
    test "formats end of day (23:59)" do
      time = ~T[23:59:00]
      assert I18n.format_time(time, locale: "en-US") == "11:59 PM"
    end

    test "formats start of day next second (00:00:01)" do
      time = ~T[00:00:01]
      assert I18n.format_time(time, locale: "en-US") == "12:00 AM"
    end

    test "formats early morning edge" do
      time = ~T[00:59:00]
      assert I18n.format_time(time, locale: "en-US") == "12:59 AM"
    end
  end

  describe "expanded integration scenarios" do
    test "formats complete financial report with edge case values" do
      revenue = I18n.format_currency(1_000_000.00, "USD", locale: "en-US")
      expenses = I18n.format_currency(-500_000.00, "USD", locale: "en-US")
      profit_margin = I18n.format_percent(0.50, locale: "en-US", decimal_places: 1)
      report_date = I18n.format_date(~D[2025-12-31], locale: "en-US")

      assert revenue == "$1,000,000.00"
      assert String.contains?(expenses, "-")
      assert profit_margin == "50.0%"
      assert report_date == "12/31/2025"
    end

    test "formats multi-locale financial data with all currencies" do
      amounts = %{
        usd: I18n.format_currency(1000.00, "USD", locale: "en-US"),
        eur_de: I18n.format_currency(1000.00, "EUR", locale: "de-DE"),
        gbp: I18n.format_currency(1000.00, "GBP", locale: "en-GB"),
        jpy: I18n.format_currency(1000, "JPY", locale: "ja-JP")
      }

      assert amounts.usd == "$1,000.00"
      assert amounts.eur_de == "1.000,00 €"
      assert amounts.gbp == "£1,000.00"
      assert amounts.jpy == "¥1,000"
    end

    test "formats complete report with all supported locales" do
      locales = ["en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "ja-JP", "zh-CN"]

      Enum.each(locales, fn locale ->
        date = I18n.format_date(~D[2025-06-15], locale: locale)
        time = I18n.format_time(~T[14:30:00], locale: locale)
        number = I18n.format_number(1234.56, locale: locale)

        assert is_binary(date)
        assert is_binary(time)
        assert is_binary(number)
        assert byte_size(date) > 0
        assert byte_size(time) > 0
        assert byte_size(number) > 0
      end)
    end
  end
end
