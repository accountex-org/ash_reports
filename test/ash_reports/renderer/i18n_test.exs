defmodule AshReports.Renderer.I18nTest do
  @moduledoc """
  Tests for the internationalization module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Renderer.I18n

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
end
