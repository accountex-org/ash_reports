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
  alias AshReports.FormatParser
  alias AshReports.FormatSpecification
  alias AshReports.Formattable

  @type format_option ::
          {:locale, String.t()}
          | {:type, format_type()}
          | {:currency, atom()}
          | {:precision, non_neg_integer()}
          | {:format, atom()}
          | {:timezone, String.t()}
          | {:format_spec,
             FormatSpecification.format_spec_name() | FormatSpecification.format_spec()}
          | {:custom_pattern, String.t()}

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
          | :custom

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

      iex> AshReports.Formatter.format_value(1234.56, custom_pattern: "#,##0.000")
      {:ok, "1,234.560"}

  """
  @spec format_value(term(), [format_option()]) :: format_result()
  def format_value(value, options \\ []) do
    locale = Keyword.get(options, :locale, Cldr.current_locale())

    # Check for custom format specifications first
    cond do
      format_spec = Keyword.get(options, :format_spec) ->
        case format_with_spec(value, format_spec, locale, options) do
          {:ok, result} -> {:ok, result}
          # Graceful fallback
          {:error, _} -> {:ok, to_string(value)}
        end

      custom_pattern = Keyword.get(options, :custom_pattern) ->
        format_with_custom_pattern(value, custom_pattern, locale, options)

      true ->
        format_type = Keyword.get(options, :type, :auto)
        effective_type = if format_type == :auto, do: detect_type(value), else: format_type
        apply_format(value, effective_type, locale, options)
    end
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
      Enum.reduce_while(field_specs, {:ok, %{}}, fn field_spec, acc ->
        format_field_in_record(record, field_spec, options, locale, acc)
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

  @doc """
  Formats a value using a custom format specification.

  Provides advanced formatting capabilities through format specifications that
  can include conditional formatting, custom patterns, and complex transformations.

  ## Parameters

  - `value` - The value to format
  - `format_spec` - Format specification name or compiled specification
  - `locale` - Locale for formatting (default: current locale)
  - `options` - Additional formatting options

  ## Examples

      # Using a predefined format specification
      spec = AshReports.FormatSpecification.new(:custom_currency, pattern: "¤ #,##0.00")
      {:ok, compiled} = AshReports.FormatSpecification.compile(spec)
      {:ok, formatted} = AshReports.Formatter.format_with_spec(1234.56, compiled)

      # Using conditional formatting
      spec = AshReports.FormatSpecification.new(:conditional_number)
      |> AshReports.FormatSpecification.add_condition({:>, 1000}, pattern: "#,##0K", color: :green)
      |> AshReports.FormatSpecification.set_default_pattern("#,##0.00")
      {:ok, compiled} = AshReports.FormatSpecification.compile(spec)
      {:ok, formatted} = AshReports.Formatter.format_with_spec(1500, compiled)

  """
  @spec format_with_spec(
          term(),
          FormatSpecification.format_spec_name() | FormatSpecification.format_spec(),
          String.t(),
          [format_option()]
        ) ::
          format_result()
  def format_with_spec(value, format_spec, locale \\ nil, options \\ [])

  def format_with_spec(value, %FormatSpecification{} = spec, locale, options) do
    # Handle nil early
    if is_nil(value) do
      {:ok, ""}
    else
      effective_locale = locale || Cldr.current_locale()
      context = %{locale: effective_locale, options: options}

      with {:ok, compiled_spec} <- FormatSpecification.compile(spec),
           {:ok, {pattern, format_options}} <-
             FormatSpecification.get_effective_format(compiled_spec, value, context) do
        apply_custom_format(value, pattern, effective_locale, format_options)
      else
        {:error, reason} -> {:error, "Format specification error: #{reason}"}
      end
    end
  rescue
    error -> {:error, "Format specification formatting failed: #{Exception.message(error)}"}
  end

  def format_with_spec(value, format_spec_name, locale, options) when is_atom(format_spec_name) do
    case get_registered_format_spec(format_spec_name) do
      {:ok, spec} ->
        format_with_spec(value, spec, locale, options)

      {:error, reason} ->
        {:error, "Format specification '#{format_spec_name}' not found: #{reason}"}
    end
  end

  @doc """
  Formats a value using a custom pattern string.

  Provides direct formatting using pattern strings without requiring
  a formal format specification definition.

  ## Parameters

  - `value` - The value to format
  - `pattern` - The custom format pattern string
  - `locale` - Locale for formatting (default: current locale) 
  - `options` - Additional formatting options

  ## Examples

      iex> AshReports.Formatter.format_with_custom_pattern(1234.56, "#,##0.000")
      {:ok, "1,234.560"}

      iex> AshReports.Formatter.format_with_custom_pattern(1234.56, "¤#,##0.00", "en", currency: :EUR)
      {:ok, "€1,234.56"}

  """
  @spec format_with_custom_pattern(term(), String.t(), String.t(), [format_option()]) ::
          format_result()
  def format_with_custom_pattern(value, pattern, locale \\ nil, options \\ []) do
    effective_locale = locale || Cldr.current_locale()

    case FormatParser.parse(pattern, Keyword.put(options, :locale, effective_locale)) do
      {:ok, compiled_format} ->
        apply_compiled_format(value, compiled_format, effective_locale, options)

      {:error, parse_error} ->
        {:error, "Pattern parsing failed: #{inspect(parse_error)}"}
    end
  rescue
    error -> {:error, "Custom pattern formatting failed: #{Exception.message(error)}"}
  end

  @doc """
  Registers a format specification for reuse by name.

  Allows format specifications to be defined once and referenced by name
  throughout the application, promoting consistency and reusability.

  ## Parameters

  - `name` - Unique name for the format specification
  - `spec` - The format specification to register

  ## Examples

      spec = AshReports.FormatSpecification.new(:company_currency, 
        pattern: "¤ #,##0.00",
        currency: :USD
      )
      AshReports.Formatter.register_format_spec(:company_currency, spec)

  """
  @spec register_format_spec(
          FormatSpecification.format_spec_name(),
          FormatSpecification.format_spec()
        ) ::
          :ok | {:error, term()}
  def register_format_spec(name, %FormatSpecification{} = spec) when is_atom(name) do
    case FormatSpecification.compile(spec) do
      {:ok, compiled_spec} ->
        put_format_spec_registry(name, compiled_spec)
        :ok

      {:error, reason} ->
        {:error, "Failed to register format specification: #{reason}"}
    end
  rescue
    error -> {:error, "Format specification registration failed: #{Exception.message(error)}"}
  end

  @doc """
  Gets a list of all registered format specifications.

  ## Examples

      iex> AshReports.Formatter.list_format_specs()
      [:company_currency, :report_number, :conditional_status]

  """
  @spec list_format_specs() :: [FormatSpecification.format_spec_name()]
  def list_format_specs do
    get_format_spec_registry_keys()
  end

  # Private helper functions

  @doc """
  Formats a value using the Formattable protocol for automatic type detection and formatting.

  This function provides protocol-based formatting as an alternative to the main
  format_value/2 function for simpler use cases.

  ## Examples

      iex> AshReports.Formatter.format_via_protocol(1234.56, locale: "fr")
      {:ok, "1 234,56"}

      iex> AshReports.Formatter.format_via_protocol(~D[2024-03-15], locale: "en")
      {:ok, "Mar 15, 2024"}

  """
  @spec format_via_protocol(term(), [format_option()]) :: format_result()
  def format_via_protocol(value, options \\ []) do
    Formattable.format(value, options)
  rescue
    error ->
      {:error, "Protocol formatting failed: #{Exception.message(error)}"}
  end

  @spec detect_type(term()) :: format_type()
  defp detect_type(value) do
    Formattable.format_type(value)
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

  @spec format_field_in_record(
          map(),
          {atom(), keyword()},
          [format_option()],
          String.t(),
          {:ok, map()}
        ) ::
          {:cont, {:ok, map()}} | {:halt, {:error, term()}}
  defp format_field_in_record(record, {field, field_options}, global_options, locale, {:ok, acc}) do
    case Map.fetch(record, field) do
      {:ok, value} ->
        merged_options = merge_field_options(field_options, global_options, locale)

        case format_value(value, merged_options) do
          {:ok, formatted_value} ->
            {:cont, {:ok, Map.put(acc, field, formatted_value)}}

          {:error, reason} ->
            {:halt, {:error, "Failed to format field #{field}: #{reason}"}}
        end

      :error ->
        {:halt, {:error, "Field #{field} not found in record"}}
    end
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
  defp type_base_class(:custom), do: "custom-value"
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

  # Custom format specification support functions

  @spec apply_custom_format(term(), String.t(), String.t(), keyword()) :: format_result()
  defp apply_custom_format(value, pattern, locale, options) when is_binary(pattern) do
    # Use the format parser to handle the custom pattern
    case FormatParser.parse(pattern, Keyword.put(options, :locale, locale)) do
      {:ok, compiled_format} ->
        apply_compiled_format(value, compiled_format, locale, options)

      {:error, _parse_error} ->
        # Fallback to standard formatting if pattern parsing fails
        format_type = FormatParser.detect_type(pattern)
        apply_format(value, format_type, locale, options)
    end
  end

  defp apply_custom_format(value, _pattern, locale, options) do
    # Fallback when no pattern is provided
    format_type = detect_type(value)
    apply_format(value, format_type, locale, options)
  end

  @spec apply_compiled_format(term(), FormatParser.compiled_format(), String.t(), keyword()) ::
          format_result()
  defp apply_compiled_format(value, %{formatter: formatter_fn}, locale, options)
       when is_function(formatter_fn) do
    # Apply the compiled formatter function
    formatter_options = Keyword.put(options, :locale, locale)
    formatter_fn.(value, formatter_options)
  rescue
    error -> {:error, "Compiled format application failed: #{Exception.message(error)}"}
  end

  defp apply_compiled_format(value, compiled_format, locale, options) do
    # Fallback if compiled format is invalid
    format_type = Map.get(compiled_format, :type, detect_type(value))
    apply_format(value, format_type, locale, options)
  end

  # Format specification registry functions (simplified implementation)

  @spec get_registered_format_spec(FormatSpecification.format_spec_name()) ::
          {:ok, FormatSpecification.format_spec()} | {:error, String.t()}
  defp get_registered_format_spec(name) do
    case Process.get({:format_spec_registry, name}) do
      nil ->
        {:error, "Format specification not registered"}

      spec ->
        {:ok, spec}
    end
  end

  @spec put_format_spec_registry(
          FormatSpecification.format_spec_name(),
          FormatSpecification.format_spec()
        ) :: :ok
  defp put_format_spec_registry(name, spec) do
    Process.put({:format_spec_registry, name}, spec)
    :ok
  end

  @spec get_format_spec_registry_keys() :: [FormatSpecification.format_spec_name()]
  defp get_format_spec_registry_keys do
    Process.get()
    |> Enum.filter(fn
      {{:format_spec_registry, _name}, _spec} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:format_spec_registry, name}, _spec} -> name end)
  end
end
