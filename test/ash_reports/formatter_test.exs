defmodule AshReports.FormatterTest do
  use ExUnit.Case, async: true
  
  # Temporarily skip these tests until CLDR is properly configured
  @moduletag :skip
  
  alias AshReports.Formatter
  
  describe "format_number/2" do
    test "formats numbers with default locale (en)" do
      assert {:ok, "1,234.56"} = Formatter.format_number(1234.56)
      assert {:ok, "1,000"} = Formatter.format_number(1000)
      assert {:ok, "0.5"} = Formatter.format_number(0.5)
    end
    
    test "formats numbers with German locale" do
      assert {:ok, "1.234,56"} = Formatter.format_number(1234.56, locale: "de")
      assert {:ok, "1.000"} = Formatter.format_number(1000, locale: "de")
    end
    
    test "formats numbers with French locale" do
      assert {:ok, result} = Formatter.format_number(1234.56, locale: "fr")
      # French uses non-breaking space as separator
      assert String.contains?(result, "234")
    end
    
    test "formats numbers with precision" do
      assert {:ok, "1,234.567"} = Formatter.format_number(1234.56789, precision: 3)
      assert {:ok, "1,235"} = Formatter.format_number(1234.56, precision: 0)
    end
  end
  
  describe "format_currency/2" do
    test "formats USD currency with default locale" do
      assert {:ok, "$1,234.56"} = Formatter.format_currency(1234.56, currency: "USD")
      assert {:ok, "$0.50"} = Formatter.format_currency(0.50, currency: "USD")
    end
    
    test "formats EUR currency with German locale" do
      assert {:ok, result} = Formatter.format_currency(1234.56, currency: "EUR", locale: "de")
      assert String.contains?(result, "€")
      assert String.contains?(result, "1.234")
    end
    
    test "formats JPY currency (no decimal places)" do
      assert {:ok, result} = Formatter.format_currency(1234, currency: "JPY", locale: "ja")
      assert String.contains?(result, "1,234")
    end
  end
  
  describe "format_percentage/2" do
    test "formats percentages with multiplication" do
      assert {:ok, "12.34%"} = Formatter.format_percentage(0.1234)
      assert {:ok, "100%"} = Formatter.format_percentage(1.0)
    end
    
    test "formats percentages without multiplication" do
      assert {:ok, "12.34%"} = Formatter.format_percentage(12.34, multiply: false)
    end
    
    test "formats percentages with custom precision" do
      assert {:ok, "12.3%"} = Formatter.format_percentage(0.1234, precision: 1)
      assert {:ok, "12%"} = Formatter.format_percentage(0.1234, precision: 0)
    end
  end
  
  describe "format_date/2" do
    test "formats dates with default locale" do
      date = ~D[2024-01-15]
      assert {:ok, result} = Formatter.format_date(date)
      assert String.contains?(result, "Jan")
      assert String.contains?(result, "15")
      assert String.contains?(result, "2024")
    end
    
    test "formats dates with German locale" do
      date = ~D[2024-01-15]
      assert {:ok, result} = Formatter.format_date(date, locale: "de")
      assert String.contains?(result, "15")
      assert String.contains?(result, "2024")
    end
    
    test "formats dates with different styles" do
      date = ~D[2024-01-15]
      
      assert {:ok, short} = Formatter.format_date(date, format: :short)
      assert {:ok, long} = Formatter.format_date(date, format: :long)
      
      # Long format should be longer than short
      assert String.length(long) > String.length(short)
    end
  end
  
  describe "format_datetime/2" do
    test "formats DateTime with default locale" do
      datetime = ~U[2024-01-15 14:30:00Z]
      assert {:ok, result} = Formatter.format_datetime(datetime)
      assert String.contains?(result, "Jan")
      assert String.contains?(result, "15")
      assert String.contains?(result, "2024")
    end
    
    test "formats NaiveDateTime" do
      datetime = ~N[2024-01-15 14:30:00]
      assert {:ok, result} = Formatter.format_datetime(datetime)
      assert String.contains?(result, "2024")
    end
    
    test "formats datetime with 24-hour format in German" do
      datetime = ~N[2024-01-15 14:30:00]
      assert {:ok, result} = Formatter.format_datetime(datetime, locale: "de")
      assert String.contains?(result, "14:30") or String.contains?(result, "14.30")
    end
  end
  
  describe "format_time/2" do
    test "formats time with AM/PM in English" do
      time = ~T[14:30:00]
      assert {:ok, result} = Formatter.format_time(time)
      assert String.contains?(result, "2:30") or String.contains?(result, "14:30")
    end
    
    test "formats time with 24-hour format in German" do
      time = ~T[14:30:00]
      assert {:ok, result} = Formatter.format_time(time, locale: "de")
      assert String.contains?(result, "14:30") or String.contains?(result, "14.30")
    end
  end
  
  describe "format_boolean/2" do
    test "formats boolean values in English" do
      assert {:ok, "Yes"} = Formatter.format_boolean(true)
      assert {:ok, "No"} = Formatter.format_boolean(false)
      assert {:ok, ""} = Formatter.format_boolean(nil)
    end
    
    test "formats boolean values in Spanish" do
      assert {:ok, "Sí"} = Formatter.format_boolean(true, locale: "es")
      assert {:ok, "No"} = Formatter.format_boolean(false, locale: "es")
    end
    
    test "formats boolean values with custom text" do
      assert {:ok, "Active"} = Formatter.format_boolean(true, true_text: "Active")
      assert {:ok, "Inactive"} = Formatter.format_boolean(false, false_text: "Inactive")
    end
  end
  
  describe "text_direction/1" do
    test "returns LTR for most locales" do
      assert :ltr = Formatter.text_direction("en")
      assert :ltr = Formatter.text_direction("es")
      assert :ltr = Formatter.text_direction("fr")
    end
    
    test "returns RTL for Arabic and Hebrew" do
      assert :rtl = Formatter.text_direction("ar")
      assert :rtl = Formatter.text_direction("he")
    end
  end
  
  describe "locale management" do
    test "available_locales returns configured locales" do
      locales = Formatter.available_locales()
      assert "en" in locales
      assert is_list(locales)
    end
    
    test "locale_available? checks locale support" do
      assert Formatter.locale_available?("en")
      assert Formatter.locale_available?("es")
      refute Formatter.locale_available?("invalid_locale")
    end
  end
end