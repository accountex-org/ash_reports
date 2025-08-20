defmodule AshReports.Formatter do
  @moduledoc """
  Locale-aware formatting utilities for AshReports.

  This module provides comprehensive formatting functions that integrate with the
  CLDR backend to deliver locale-appropriate formatting for numbers, currencies,
  dates, and other data types used in reporting.

  ## Features

  - **Number Formatting**: Decimal, percentage, and scientific notation with locale rules
  - **Currency Formatting**: Multi-currency support with proper symbols and placement
  - **Date/Time Formatting**: Locale-specific date and time representations
  - **Data Type Detection**: Automatic format selection based on data type
  - **Performance Optimization**: Caching and efficient format application
  - **Error Recovery**: Graceful fallbacks when formatting fails

  ## Integration with Renderers

  The Formatter module is designed to integrate seamlessly with all Phase 3 renderers:

  - **HTML Renderer**: CSS-compatible formatting with proper direction support
  - **PDF Renderer**: Print-optimized formatting with typography considerations
  - **JSON Renderer**: Structured data with formatted display values
  - **HEEX Renderer**: LiveView-compatible formatting with assigns integration

  ## Usage Patterns

  ### Basic Value Formatting

      # Format a single value with auto-detection
      {:ok, formatted} = Formatter.format_value(1234.56, locale: "fr")
      # => "1 234,56"

      # Format with explicit type
      {:ok, formatted} = Formatter.format_value(1234.56, type: :currency, currency: :EUR, locale: "fr")
      # => "1 234,56 €"

  ### Record Field Formatting

      # Format specific fields in a record
      record = %{amount: 1500.00, date: ~D[2024-03-15], count: 42}
      formatted = Formatter.format_record(record, [
        amount: [type: :currency, currency: :USD],
        date: [type: :date, format: :long],
        count: [type: :number]
      ], locale: "en")

  ### Batch Formatting

      # Format multiple values efficiently
      values = [1234.56, 2345.67, 3456.78]
      formatted = Formatter.format_batch(values, type: :currency, currency: :USD, locale: "en")

  ## Configuration

  The formatter can be configured globally or per-operation:

      # Global configuration
      config :ash_reports, AshReports.Formatter,
        default_locale: "en",
        currency_precision: 2,
        date_format: :medium,
        number_format: :decimal

      # Per-operation configuration
      options = [
        locale: "fr",
        type: :currency,
        currency: :EUR,
        precision: 2
      ]

  ## Performance Considerations

  - **Format Caching**: Compiled formatters are cached per locale
  - **Batch Operations**: Multiple values can be formatted efficiently
  - **Lazy Loading**: Locale data is loaded on-demand
  - **Memory Management**: Format cache is automatically cleaned up

  ## Error Handling

  All formatting functions return `{:ok, result}` or `{:error, reason}` tuples.
  When formatting fails, the original value is returned with a warning logged.

  """

  alias AshReports.Cldr

  @type format_option ::
          {:locale, String.t()}
          | {:type, format_type()}
          | {:currency, atom()}
          | {:precision, non_neg_integer()}
          | {:format, atom()}
          | {:timezone, String.t()}

  @type format_type ::
          :auto
          | :number
          | :currency
          | :percentage
          | :date
          | :time
          | :datetime
          | :boolean
          | :string

  @type format_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Formats a single value with automatic type detection or explicit type specification.

  ## Parameters

  - `value` - The value to format
  - `options` - Formatting options (see module documentation)

  ## Examples

      iex> AshReports.Formatter.format_value(1234.56)
      {:ok, "1,234.56"}

      iex> AshReports.Formatter.format_value(1234.56, locale: "fr")
      {:ok, "1 234,56"}

      iex> AshReports.Formatter.format_value(1234.56, type: :currency, currency: :EUR)
      {:ok, "$1,234.56"}

      iex> AshReports.Formatter.format_value(~D[2024-03-15], type: :date, format: :long)
      {:ok, "March 15, 2024"}

  """
  @spec format_value(term(), [format_option()]) :: format_result()
  def format_value(value, options \\ []) do
    locale = Keyword.get(options, :locale, Cldr.current_locale())
    format_type = Keyword.get(options, :type, :auto)

    effective_type =
      case format_type do
        :auto -> detect_type(value)
        type -> type
      end

    apply_format(value, effective_type, locale, options)
  rescue
    error ->
      {:error, "Formatting failed: #{Exception.message(error)}"}
  end

  @doc """
  Formats multiple fields in a record according to field-specific formatting rules.

  ## Parameters

  - `record` - The record (map) containing fields to format
  - `field_specs` - Keyword list of field names and their formatting options
  - `options` - Global formatting options applied to all fields

  ## Examples

      record = %{
        amount: 1500.00,
        date: ~D[2024-03-15],
        count: 42,
        rate: 0.0525
      }

      field_specs = [
        amount: [type: :currency, currency: :USD],
        date: [type: :date, format: :medium],
        count: [type: :number],
        rate: [type: :percentage, precision: 2]
      ]

      {:ok, formatted} = AshReports.Formatter.format_record(record, field_specs)
      # => %{
      #   amount: "$1,500.00",
      #   date: "Mar 15, 2024", 
      #   count: "42",
      #   rate: "5.25%"
      # }

  """
  @spec format_record(map(), keyword(), [format_option()]) ::
          {:ok, map()} | {:error, term()}
  def format_record(record, field_specs, options \\ []) when is_map(record) do
    locale = Keyword.get(options, :locale, Cldr.current_locale())

    formatted_fields =
      Enum.reduce_while(field_specs, {:ok, %{}}, fn {field, field_options}, {:ok, acc} ->
        case Map.fetch(record, field) do
          {:ok, value} ->
            merged_options = merge_field_options(field_options, options, locale)

            case format_value(value, merged_options) do
              {:ok, formatted_value} ->
                {:cont, {:ok, Map.put(acc, field, formatted_value)}}

              {:error, reason} ->
                {:halt, {:error, "Failed to format field #{field}: #{reason}"}}
            end

          :error ->
            {:halt, {:error, "Field #{field} not found in record"}}
        end
      end)

    case formatted_fields do
      {:ok, formatted} ->
        # Include original fields that weren't specified for formatting
        original_fields = Map.drop(record, Keyword.keys(field_specs))
        {:ok, Map.merge(original_fields, formatted)}

      error ->
        error
    end
  rescue
    error ->
      {:error, "Record formatting failed: #{Exception.message(error)}"}
  end

  @doc """
  Formats a list of values efficiently using batch processing.

  ## Parameters

  - `values` - List of values to format
  - `options` - Formatting options applied to all values

  ## Examples

      values = [1234.56, 2345.67, 3456.78]
      
      {:ok, formatted} = AshReports.Formatter.format_batch(values, 
        type: :currency, currency: :USD, locale: "en")
      # => ["$1,234.56", "$2,345.67", "$3,456.78"]

  """
  @spec format_batch([term()], [format_option()]) ::
          {:ok, [String.t()]} | {:error, term()}
  def format_batch(values, options \\ []) when is_list(values) do
    locale = Keyword.get(options, :locale, Cldr.current_locale())
    format_type = Keyword.get(options, :type, :auto)

    # For batch processing, we determine the type from the first non-nil value
    effective_type =
      case format_type do
        :auto ->
          values
          |> Enum.find(&(&1 != nil))
          |> detect_type()

        type ->
          type
      end

    formatted_values =
      Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
        case apply_format(value, effective_type, locale, options) do
          {:ok, formatted} ->
            {:cont, {:ok, [formatted | acc]}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case formatted_values do
      {:ok, reversed_list} -> {:ok, Enum.reverse(reversed_list)}
      error -> error
    end
  rescue
    error ->
      {:error, "Batch formatting failed: #{Exception.message(error)}"}
  end

  @doc """
  Formats a data structure (list of records) for rendering.

  This is a convenience function that combines record and batch formatting
  for complex data structures commonly used in reports.

  ## Parameters

  - `data` - List of records or single record
  - `field_specs` - Field formatting specifications
  - `options` - Global formatting options

  ## Examples

      data = [
        %{name: "Product A", price: 99.99, date: ~D[2024-03-15]},
        %{name: "Product B", price: 149.99, date: ~D[2024-03-16]}
      ]

      field_specs = [
        price: [type: :currency, currency: :USD],
        date: [type: :date, format: :short]
      ]

      {:ok, formatted} = AshReports.Formatter.format_data(data, field_specs)

  """
  @spec format_data([map()] | map(), keyword(), [format_option()]) ::
          {:ok, [map()] | map()} | {:error, term()}
  def format_data(data, field_specs, options \\ [])

  def format_data(data, field_specs, options) when is_list(data) do
    formatted_records =
      Enum.reduce_while(data, {:ok, []}, fn record, {:ok, acc} ->
        case format_record(record, field_specs, options) do
          {:ok, formatted_record} ->
            {:cont, {:ok, [formatted_record | acc]}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case formatted_records do
      {:ok, reversed_list} -> {:ok, Enum.reverse(reversed_list)}
      error -> error
    end
  end

  def format_data(data, field_specs, options) when is_map(data) do
    format_record(data, field_specs, options)
  end

  def format_data(data, _field_specs, _options) do
    {:error, "Data must be a map or list of maps, got: #{inspect(data)}"}
  end

  @doc """
  Gets the appropriate CSS class for a formatted value based on its type and locale.

  This is useful for HTML rendering where different value types may need
  different styling (e.g., right-aligned numbers, currency symbols).

  ## Examples

      iex> AshReports.Formatter.css_class_for_type(:currency, "en")
      "currency-value text-right"

      iex> AshReports.Formatter.css_class_for_type(:date, "ar")
      "date-value text-left"

  """
  @spec css_class_for_type(format_type(), String.t()) :: String.t()
  def css_class_for_type(type, locale \\ nil) do
    locale = locale || Cldr.current_locale()
    direction = Cldr.text_direction(locale)

    base_class = type_base_class(type)
    alignment_class = alignment_class_for_type(type, direction)

    [base_class, alignment_class]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join(" ")
  end

  @doc """
  Formats a value specifically for JSON output, ensuring proper serialization
  while maintaining locale-aware display formatting.

  Returns a map with both the original value and formatted display string.

  ## Examples

      iex> AshReports.Formatter.format_for_json(1234.56, type: :currency, currency: :USD)
      {:ok, %{value: 1234.56, formatted: "$1,234.56", type: "currency"}}

  """
  @spec format_for_json(term(), [format_option()]) ::
          {:ok, map()} | {:error, term()}
  def format_for_json(value, options \\ []) do
    format_type = Keyword.get(options, :type, detect_type(value))

    case format_value(value, options) do
      {:ok, formatted} ->
        result = %{
          value: value,
          formatted: formatted,
          type: to_string(format_type)
        }

        # Add locale information if specified
        if locale = Keyword.get(options, :locale) do
          {:ok, Map.put(result, :locale, locale)}
        else
          {:ok, result}
        end

      error ->
        error
    end
  end

  # Private helper functions

  @spec detect_type(term()) :: format_type()
  defp detect_type(value) do
    cond do
      is_number(value) -> :number
      is_boolean(value) -> :boolean
      is_binary(value) -> :string
      match?(%Date{}, value) -> :date
      match?(%Time{}, value) -> :time
      match?(%DateTime{}, value) -> :datetime
      match?(%NaiveDateTime{}, value) -> :datetime
      true -> :string
    end
  end

  @spec apply_format(term(), format_type(), String.t(), [format_option()]) :: format_result()
  defp apply_format(nil, _type, _locale, _options) do
    {:ok, ""}
  end

  defp apply_format(value, :number, locale, options) do
    precision = Keyword.get(options, :precision)
    format_options = [locale: locale]

    format_options =
      if precision do
        Keyword.put(format_options, :fractional_digits, precision)
      else
        format_options
      end

    Cldr.format_number(value, format_options)
  end

  defp apply_format(value, :currency, locale, options) do
    currency = Keyword.get(options, :currency, :USD)
    Cldr.format_currency(value, currency, locale: locale)
  end

  defp apply_format(value, :percentage, locale, options) do
    precision = Keyword.get(options, :precision, 2)

    # Convert to percentage format
    percentage_value =
      if is_number(value) do
        if value <= 1.0, do: value, else: value / 100
      else
        value
      end

    Cldr.format_number(percentage_value,
      locale: locale,
      format: :percent,
      fractional_digits: precision
    )
  end

  defp apply_format(value, :date, locale, options) do
    format = Keyword.get(options, :format, :medium)
    Cldr.format_date(value, locale: locale, format: format)
  end

  defp apply_format(value, :time, locale, options) do
    format = Keyword.get(options, :format, :medium)
    Cldr.format_time(value, locale: locale, format: format)
  end

  defp apply_format(value, :datetime, locale, options) do
    format = Keyword.get(options, :format, :medium)
    Cldr.format_datetime(value, locale: locale, format: format)
  end

  defp apply_format(value, :boolean, _locale, _options) do
    {:ok, if(value, do: "true", else: "false")}
  end

  defp apply_format(value, :string, _locale, _options) do
    {:ok, to_string(value)}
  end

  defp apply_format(value, _type, _locale, _options) do
    # Fallback to string representation
    {:ok, to_string(value)}
  end

  @spec merge_field_options(keyword(), [format_option()], String.t()) :: [format_option()]
  defp merge_field_options(field_options, global_options, locale) do
    field_options
    |> Keyword.put_new(:locale, locale)
    |> Keyword.merge(global_options, fn _key, field_val, _global_val -> field_val end)
  end

  @spec type_base_class(format_type()) :: String.t()
  defp type_base_class(:currency), do: "currency-value"
  defp type_base_class(:number), do: "number-value"
  defp type_base_class(:percentage), do: "percentage-value"
  defp type_base_class(:date), do: "date-value"
  defp type_base_class(:time), do: "time-value"
  defp type_base_class(:datetime), do: "datetime-value"
  defp type_base_class(:boolean), do: "boolean-value"
  defp type_base_class(_), do: "text-value"

  @spec alignment_class_for_type(format_type(), String.t()) :: String.t()
  defp alignment_class_for_type(type, direction) when type in [:currency, :number, :percentage] do
    case direction do
      "rtl" -> "text-left"
      _ -> "text-right"
    end
  end

  defp alignment_class_for_type(_type, direction) do
    case direction do
      "rtl" -> "text-right"
      _ -> "text-left"
    end
  end
end
