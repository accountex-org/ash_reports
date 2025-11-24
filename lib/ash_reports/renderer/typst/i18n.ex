defmodule AshReports.Renderer.Typst.I18n do
  @moduledoc """
  Internationalization module for locale-aware formatting.

  Provides locale-specific formatting for currency, numbers, dates, and times.
  Supports configurable locales per report with sensible defaults.

  ## Supported Locales

  - `"en-US"` - English (United States) - default
  - `"en-GB"` - English (United Kingdom)
  - `"de-DE"` - German (Germany)
  - `"fr-FR"` - French (France)
  - `"es-ES"` - Spanish (Spain)
  - `"ja-JP"` - Japanese (Japan)
  - `"zh-CN"` - Chinese (China)

  ## Examples

      iex> I18n.format_currency(1234.56, "USD", locale: "en-US")
      "$1,234.56"

      iex> I18n.format_currency(1234.56, "EUR", locale: "de-DE")
      "1.234,56 €"

      iex> I18n.format_number(1234.56, locale: "de-DE")
      "1.234,56"

      iex> I18n.format_date(~D[2025-01-15], locale: "de-DE")
      "15.01.2025"
  """

  @default_locale "en-US"

  # Locale configuration for different regions
  @locale_config %{
    "en-US" => %{
      decimal_separator: ".",
      thousand_separator: ",",
      currency_symbol_position: :before,
      date_format: :mdy,
      time_format: :twelve_hour
    },
    "en-GB" => %{
      decimal_separator: ".",
      thousand_separator: ",",
      currency_symbol_position: :before,
      date_format: :dmy,
      time_format: :twenty_four_hour
    },
    "de-DE" => %{
      decimal_separator: ",",
      thousand_separator: ".",
      currency_symbol_position: :after,
      date_format: :dmy_dot,
      time_format: :twenty_four_hour
    },
    "fr-FR" => %{
      decimal_separator: ",",
      thousand_separator: " ",
      currency_symbol_position: :after,
      date_format: :dmy_slash,
      time_format: :twenty_four_hour
    },
    "es-ES" => %{
      decimal_separator: ",",
      thousand_separator: ".",
      currency_symbol_position: :after,
      date_format: :dmy_slash,
      time_format: :twenty_four_hour
    },
    "ja-JP" => %{
      decimal_separator: ".",
      thousand_separator: ",",
      currency_symbol_position: :before,
      date_format: :ymd,
      time_format: :twenty_four_hour
    },
    "zh-CN" => %{
      decimal_separator: ".",
      thousand_separator: ",",
      currency_symbol_position: :before,
      date_format: :ymd,
      time_format: :twenty_four_hour
    }
  }

  # Currency configuration
  @currency_config %{
    "USD" => %{symbol: "$", decimal_places: 2},
    "EUR" => %{symbol: "€", decimal_places: 2},
    "GBP" => %{symbol: "£", decimal_places: 2},
    "JPY" => %{symbol: "¥", decimal_places: 0},
    "CNY" => %{symbol: "¥", decimal_places: 2},
    "CHF" => %{symbol: "CHF", decimal_places: 2},
    "CAD" => %{symbol: "CA$", decimal_places: 2},
    "AUD" => %{symbol: "A$", decimal_places: 2},
    "MXN" => %{symbol: "MX$", decimal_places: 2},
    "BRL" => %{symbol: "R$", decimal_places: 2}
  }

  @doc """
  Returns the default locale.
  """
  @spec default_locale() :: String.t()
  def default_locale, do: @default_locale

  @doc """
  Returns a list of supported locales.
  """
  @spec supported_locales() :: [String.t()]
  def supported_locales, do: Map.keys(@locale_config)

  @doc """
  Returns a list of supported currency codes.
  """
  @spec supported_currencies() :: [String.t()]
  def supported_currencies, do: Map.keys(@currency_config)

  @doc """
  Formats a number according to the specified locale.

  ## Options

  - `:locale` - The locale to use (default: "en-US")
  - `:decimal_places` - Number of decimal places (default: 2)

  ## Examples

      iex> I18n.format_number(1234.56, locale: "en-US")
      "1,234.56"

      iex> I18n.format_number(1234.56, locale: "de-DE")
      "1.234,56"

      iex> I18n.format_number(1234, locale: "fr-FR", decimal_places: 0)
      "1 234"
  """
  @spec format_number(number(), keyword()) :: String.t()
  def format_number(number, opts \\ []) do
    locale = Keyword.get(opts, :locale, @default_locale)
    decimal_places = opts |> Keyword.get(:decimal_places, 2) |> clamp_decimal_places()
    config = get_locale_config(locale)

    format_with_separators(number, decimal_places, config)
  end

  @doc """
  Formats a currency value according to the specified locale and currency.

  ## Options

  - `:locale` - The locale to use (default: "en-US")

  ## Examples

      iex> I18n.format_currency(1234.56, "USD", locale: "en-US")
      "$1,234.56"

      iex> I18n.format_currency(1234.56, "EUR", locale: "de-DE")
      "1.234,56 €"

      iex> I18n.format_currency(1234, "JPY", locale: "ja-JP")
      "¥1,234"
  """
  @spec format_currency(number(), String.t(), keyword()) :: String.t()
  def format_currency(amount, currency_code, opts \\ []) do
    locale = Keyword.get(opts, :locale, @default_locale)
    locale_config = get_locale_config(locale)
    currency_config = get_currency_config(currency_code)

    formatted_number = format_with_separators(
      amount,
      currency_config.decimal_places,
      locale_config
    )

    place_currency_symbol(
      formatted_number,
      currency_config.symbol,
      locale_config.currency_symbol_position
    )
  end

  @doc """
  Formats a date according to the specified locale.

  ## Options

  - `:locale` - The locale to use (default: "en-US")

  ## Examples

      iex> I18n.format_date(~D[2025-01-15], locale: "en-US")
      "01/15/2025"

      iex> I18n.format_date(~D[2025-01-15], locale: "de-DE")
      "15.01.2025"

      iex> I18n.format_date(~D[2025-01-15], locale: "ja-JP")
      "2025/01/15"
  """
  @spec format_date(Date.t(), keyword()) :: String.t()
  def format_date(%Date{} = date, opts \\ []) do
    locale = Keyword.get(opts, :locale, @default_locale)
    config = get_locale_config(locale)

    format_date_with_pattern(date, config.date_format)
  end

  @doc """
  Formats a time according to the specified locale.

  ## Options

  - `:locale` - The locale to use (default: "en-US")

  ## Examples

      iex> I18n.format_time(~T[14:30:00], locale: "en-US")
      "2:30 PM"

      iex> I18n.format_time(~T[14:30:00], locale: "de-DE")
      "14:30"
  """
  @spec format_time(Time.t(), keyword()) :: String.t()
  def format_time(%Time{} = time, opts \\ []) do
    locale = Keyword.get(opts, :locale, @default_locale)
    config = get_locale_config(locale)

    format_time_with_pattern(time, config.time_format)
  end

  @doc """
  Formats a datetime according to the specified locale.

  ## Options

  - `:locale` - The locale to use (default: "en-US")

  ## Examples

      iex> I18n.format_datetime(~N[2025-01-15 14:30:00], locale: "en-US")
      "01/15/2025 2:30 PM"

      iex> I18n.format_datetime(~N[2025-01-15 14:30:00], locale: "de-DE")
      "15.01.2025 14:30"
  """
  @spec format_datetime(NaiveDateTime.t() | DateTime.t(), keyword()) :: String.t()
  def format_datetime(datetime, opts \\ []) do
    date = get_date_from_datetime(datetime)
    time = get_time_from_datetime(datetime)

    formatted_date = format_date(date, opts)
    formatted_time = format_time(time, opts)

    "#{formatted_date} #{formatted_time}"
  end

  @doc """
  Formats a percentage according to the specified locale.

  ## Options

  - `:locale` - The locale to use (default: "en-US")
  - `:decimal_places` - Number of decimal places (default: 1)

  ## Examples

      iex> I18n.format_percent(0.125, locale: "en-US")
      "12.5%"

      iex> I18n.format_percent(0.125, locale: "de-DE")
      "12,5%"
  """
  @spec format_percent(number(), keyword()) :: String.t()
  def format_percent(value, opts \\ []) do
    locale = Keyword.get(opts, :locale, @default_locale)
    decimal_places = opts |> Keyword.get(:decimal_places, 1) |> clamp_decimal_places()
    config = get_locale_config(locale)

    percentage = value * 100
    formatted = format_with_separators(percentage, decimal_places, config)

    "#{formatted}%"
  end

  @doc """
  Returns the currency symbol for a given currency code.

  ## Examples

      iex> I18n.get_currency_symbol("USD")
      "$"

      iex> I18n.get_currency_symbol("EUR")
      "€"

      iex> I18n.get_currency_symbol("UNKNOWN")
      "UNKNOWN"
  """
  @spec get_currency_symbol(String.t()) :: String.t()
  def get_currency_symbol(currency_code) do
    case Map.get(@currency_config, currency_code) do
      nil -> currency_code
      config -> config.symbol
    end
  end

  @doc """
  Returns the decimal places for a given currency code.

  ## Examples

      iex> I18n.get_currency_decimal_places("USD")
      2

      iex> I18n.get_currency_decimal_places("JPY")
      0
  """
  @spec get_currency_decimal_places(String.t()) :: non_neg_integer()
  def get_currency_decimal_places(currency_code) do
    case Map.get(@currency_config, currency_code) do
      nil -> 2
      config -> config.decimal_places
    end
  end

  @doc """
  Returns the locale configuration for a given locale.

  Falls back to default locale if the specified locale is not supported.
  """
  @spec get_locale_config(String.t()) :: map()
  def get_locale_config(locale) do
    Map.get(@locale_config, locale, Map.get(@locale_config, @default_locale))
  end

  # Private helper functions

  defp get_currency_config(currency_code) do
    Map.get(@currency_config, currency_code, %{symbol: currency_code, decimal_places: 2})
  end

  defp clamp_decimal_places(value) when is_integer(value), do: max(0, min(value, 15))
  defp clamp_decimal_places(_value), do: 2

  defp format_with_separators(number, decimal_places, config) do
    # Round to specified decimal places
    rounded = Float.round(number * 1.0, decimal_places)

    # Split into integer and decimal parts
    {integer_part, decimal_part} = split_number(rounded, decimal_places)

    # Format integer part with thousand separators
    formatted_integer = format_integer_with_separators(integer_part, config.thousand_separator)

    # Combine with decimal part
    if decimal_places > 0 do
      "#{formatted_integer}#{config.decimal_separator}#{decimal_part}"
    else
      formatted_integer
    end
  end

  defp split_number(number, decimal_places) do
    integer_part = trunc(abs(number))

    decimal_part =
      if decimal_places > 0 do
        decimal_value = abs(number) - integer_part
        decimal_string = :erlang.float_to_binary(decimal_value, decimals: decimal_places)
        # Remove "0." prefix
        String.slice(decimal_string, 2..-1//1)
      else
        ""
      end

    sign = if number < 0, do: "-", else: ""
    {"#{sign}#{integer_part}", decimal_part}
  end

  defp format_integer_with_separators(integer_string, separator) do
    # Handle negative sign
    {sign, digits} =
      if String.starts_with?(integer_string, "-") do
        {"-", String.slice(integer_string, 1..-1//1)}
      else
        {"", integer_string}
      end

    formatted =
      digits
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(separator)
      |> String.reverse()

    "#{sign}#{formatted}"
  end

  defp place_currency_symbol(formatted_number, symbol, :before) do
    "#{symbol}#{formatted_number}"
  end

  defp place_currency_symbol(formatted_number, symbol, :after) do
    "#{formatted_number} #{symbol}"
  end

  defp format_date_with_pattern(%Date{year: year, month: month, day: day}, pattern) do
    month_str = String.pad_leading(Integer.to_string(month), 2, "0")
    day_str = String.pad_leading(Integer.to_string(day), 2, "0")
    year_str = Integer.to_string(year)

    case pattern do
      :mdy -> "#{month_str}/#{day_str}/#{year_str}"
      :dmy -> "#{day_str}/#{month_str}/#{year_str}"
      :dmy_dot -> "#{day_str}.#{month_str}.#{year_str}"
      :dmy_slash -> "#{day_str}/#{month_str}/#{year_str}"
      :ymd -> "#{year_str}/#{month_str}/#{day_str}"
    end
  end

  defp format_time_with_pattern(%Time{hour: hour, minute: minute}, :twelve_hour) do
    {display_hour, period} =
      cond do
        hour == 0 -> {12, "AM"}
        hour < 12 -> {hour, "AM"}
        hour == 12 -> {12, "PM"}
        true -> {hour - 12, "PM"}
      end

    minute_str = String.pad_leading(Integer.to_string(minute), 2, "0")
    "#{display_hour}:#{minute_str} #{period}"
  end

  defp format_time_with_pattern(%Time{hour: hour, minute: minute}, :twenty_four_hour) do
    hour_str = String.pad_leading(Integer.to_string(hour), 2, "0")
    minute_str = String.pad_leading(Integer.to_string(minute), 2, "0")
    "#{hour_str}:#{minute_str}"
  end

  defp get_date_from_datetime(%NaiveDateTime{} = ndt) do
    NaiveDateTime.to_date(ndt)
  end

  defp get_date_from_datetime(%DateTime{} = dt) do
    DateTime.to_date(dt)
  end

  defp get_time_from_datetime(%NaiveDateTime{} = ndt) do
    NaiveDateTime.to_time(ndt)
  end

  defp get_time_from_datetime(%DateTime{} = dt) do
    DateTime.to_time(dt)
  end
end
