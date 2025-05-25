defmodule AshReports.Formatter do
  @moduledoc """
  Provides locale-aware formatting functions for report data using CLDR.
  
  This module handles the formatting of numbers, currencies, dates, times,
  and other data types according to locale-specific conventions.
  """
  
  alias AshReports.Cldr
  
  @doc """
  Formats a number according to the specified locale and options.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:precision` - Number of decimal places
  * `:minimum_grouping_digits` - Minimum digits before grouping separators are added
  * `:format` - A CLDR number format string
  
  ## Examples
  
      iex> AshReports.Formatter.format_number(1234.56, locale: "en")
      {:ok, "1,234.56"}
      
      iex> AshReports.Formatter.format_number(1234.56, locale: "de")
      {:ok, "1.234,56"}
  """
  @spec format_number(number(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format_number(value, opts \\ []) when is_number(value) do
    locale = Keyword.get(opts, :locale, "en")
    cldr_opts = Keyword.take(opts, [:precision, :minimum_grouping_digits, :format])
    
    Cldr.Number.to_string(value, [locale: locale, backend: Cldr] ++ cldr_opts)
  end
  
  @doc """
  Formats a currency value according to the specified locale and currency.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:currency` - The currency code (e.g., "USD", "EUR")
  * `:format` - :standard, :accounting, :short, or :narrow
  * `:fractional_digits` - Override default fractional digits for the currency
  
  ## Examples
  
      iex> AshReports.Formatter.format_currency(1234.56, currency: "USD", locale: "en")
      {:ok, "$1,234.56"}
      
      iex> AshReports.Formatter.format_currency(1234.56, currency: "EUR", locale: "de")
      {:ok, "1.234,56 €"}
  """
  @spec format_currency(number(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format_currency(value, opts \\ []) when is_number(value) do
    locale = Keyword.get(opts, :locale, "en")
    currency = Keyword.get(opts, :currency, "USD")
    cldr_opts = Keyword.take(opts, [:format, :fractional_digits])
    
    Cldr.Number.to_string(value, [locale: locale, backend: Cldr, currency: currency] ++ cldr_opts)
  end
  
  @doc """
  Formats a percentage value according to the specified locale.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:precision` - Number of decimal places
  * `:multiply` - Whether to multiply by 100 (default: true)
  
  ## Examples
  
      iex> AshReports.Formatter.format_percentage(0.1234, locale: "en")
      {:ok, "12.34%"}
      
      iex> AshReports.Formatter.format_percentage(12.34, multiply: false, locale: "en")
      {:ok, "12.34%"}
  """
  @spec format_percentage(number(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format_percentage(value, opts \\ []) when is_number(value) do
    locale = Keyword.get(opts, :locale, "en")
    multiply = Keyword.get(opts, :multiply, true)
    precision = Keyword.get(opts, :precision, 2)
    
    percentage_value = if multiply, do: value * 100, else: value
    
    Cldr.Number.to_string(percentage_value, [
      locale: locale,
      backend: Cldr,
      format: "#,##0.##%",
      precision: precision
    ])
  end
  
  @doc """
  Formats a date according to the specified locale and format.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:format` - :short, :medium, :long, :full, or a format string
  
  ## Examples
  
      iex> AshReports.Formatter.format_date(~D[2024-01-15], locale: "en")
      {:ok, "Jan 15, 2024"}
      
      iex> AshReports.Formatter.format_date(~D[2024-01-15], locale: "de", format: :long)
      {:ok, "15. Januar 2024"}
  """
  @spec format_date(Date.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format_date(%Date{} = date, opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")
    format = Keyword.get(opts, :format, :medium)
    
    Cldr.Date.to_string(date, [locale: locale, backend: Cldr, format: format])
  end
  
  @doc """
  Formats a datetime according to the specified locale and format.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:format` - :short, :medium, :long, :full, or a format string
  * `:time_zone` - Time zone for display (for DateTime)
  
  ## Examples
  
      iex> AshReports.Formatter.format_datetime(~U[2024-01-15 14:30:00Z], locale: "en")
      {:ok, "Jan 15, 2024, 2:30:00 PM"}
      
      iex> AshReports.Formatter.format_datetime(~N[2024-01-15 14:30:00], locale: "fr", format: :short)
      {:ok, "15/01/2024 14:30"}
  """
  @spec format_datetime(DateTime.t() | NaiveDateTime.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format_datetime(datetime, opts \\ [])
  
  def format_datetime(%DateTime{} = datetime, opts) do
    locale = Keyword.get(opts, :locale, "en")
    format = Keyword.get(opts, :format, :medium)
    time_zone = Keyword.get(opts, :time_zone)
    
    cldr_opts = [locale: locale, backend: Cldr, format: format]
    cldr_opts = if time_zone, do: cldr_opts ++ [time_zone: time_zone], else: cldr_opts
    
    Cldr.DateTime.to_string(datetime, cldr_opts)
  end
  
  def format_datetime(%NaiveDateTime{} = datetime, opts) do
    locale = Keyword.get(opts, :locale, "en")
    format = Keyword.get(opts, :format, :medium)
    
    Cldr.DateTime.to_string(datetime, [locale: locale, backend: Cldr, format: format])
  end
  
  @doc """
  Formats a time according to the specified locale and format.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:format` - :short, :medium, :long, :full, or a format string
  
  ## Examples
  
      iex> AshReports.Formatter.format_time(~T[14:30:00], locale: "en")
      {:ok, "2:30:00 PM"}
      
      iex> AshReports.Formatter.format_time(~T[14:30:00], locale: "de", format: :short)
      {:ok, "14:30"}
  """
  @spec format_time(Time.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def format_time(%Time{} = time, opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")
    format = Keyword.get(opts, :format, :medium)
    
    Cldr.Time.to_string(time, [locale: locale, backend: Cldr, format: format])
  end
  
  @doc """
  Formats a boolean value according to locale conventions.
  
  ## Options
  
  * `:locale` - The locale to use for formatting (default: "en")
  * `:true_text` - Override text for true values
  * `:false_text` - Override text for false values
  * `:nil_text` - Override text for nil values
  
  ## Examples
  
      iex> AshReports.Formatter.format_boolean(true, locale: "en")
      {:ok, "Yes"}
      
      iex> AshReports.Formatter.format_boolean(false, locale: "es")
      {:ok, "No"}
  """
  @spec format_boolean(boolean() | nil, keyword()) :: {:ok, String.t()}
  def format_boolean(value, opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")
    
    # Use custom text if provided, otherwise use locale defaults
    text = case value do
      true -> Keyword.get(opts, :true_text, translate_boolean(true, locale))
      false -> Keyword.get(opts, :false_text, translate_boolean(false, locale))
      nil -> Keyword.get(opts, :nil_text, "")
    end
    
    {:ok, text}
  end
  
  # Private helper for boolean translations
  defp translate_boolean(true, "en"), do: "Yes"
  defp translate_boolean(false, "en"), do: "No"
  defp translate_boolean(true, "es"), do: "Sí"
  defp translate_boolean(false, "es"), do: "No"
  defp translate_boolean(true, "fr"), do: "Oui"
  defp translate_boolean(false, "fr"), do: "Non"
  defp translate_boolean(true, "de"), do: "Ja"
  defp translate_boolean(false, "de"), do: "Nein"
  defp translate_boolean(true, "pt"), do: "Sim"
  defp translate_boolean(false, "pt"), do: "Não"
  defp translate_boolean(true, _), do: "Yes"
  defp translate_boolean(false, _), do: "No"
  
  @doc """
  Returns the text direction for a given locale.
  
  ## Examples
  
      iex> AshReports.Formatter.text_direction("en")
      :ltr
      
      iex> AshReports.Formatter.text_direction("ar")
      :rtl
  """
  @spec text_direction(String.t()) :: :ltr | :rtl
  def text_direction(locale) when locale in ["ar", "he", "fa", "ur"], do: :rtl
  def text_direction(_), do: :ltr
  
  @doc """
  Returns available locales configured in the CLDR backend.
  """
  @spec available_locales() :: [String.t()]
  def available_locales do
    Cldr.known_locale_names()
  end
  
  @doc """
  Validates if a locale is available.
  """
  @spec locale_available?(String.t()) :: boolean()
  def locale_available?(locale) do
    locale in available_locales()
  end
end