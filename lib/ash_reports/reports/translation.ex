defmodule AshReports.Translation do
  @moduledoc """
  Translation infrastructure for AshReports internationalization.

  This module provides comprehensive translation capabilities for AshReports,
  integrating with the gettext library to deliver locale-aware UI elements,
  error messages, and report content across all supported languages.

  ## Features

  - **UI Element Translation**: Translate field labels, band titles, and navigation elements
  - **Error Message Localization**: Provide localized error messages and warnings
  - **Fallback Mechanisms**: Graceful degradation when translations are missing
  - **Performance Optimization**: Efficient translation caching and lookup
  - **RTL Integration**: Seamless integration with RTL layout and text direction
  - **Dynamic Loading**: Support for runtime translation updates

  ## Configuration

  Configure the translation system in your application config:

      config :ash_reports, AshReports.Translation,
        default_locale: "en",
        locales: ~w(en ar he fa ur es fr de ja zh),
        fallback_locale: "en",
        cache_translations: true

  ## Usage Examples

  ### Basic Translation

      # Translate a UI element
      {:ok, translated} = Translation.translate_ui("field.label.amount", [], "ar")
      # => {:ok, "المبلغ"}

      # Translate with bindings
      {:ok, translated} = Translation.translate_ui(
        "status.records_found", 
        [count: 42], 
        "en"
      )
      # => {:ok, "42 records found"}

  ### Field Label Translation

      # Translate field labels with automatic fallback
      label = Translation.translate_field_label(:total_amount, "ar")
      # => "المبلغ الإجمالي" (or fallback if not found)

  ### Band Title Translation

      # Translate band titles
      title = Translation.translate_band_title(:summary, "he")
      # => "סיכום"

  ## Integration with Renderers

  The Translation module integrates seamlessly with all AshReports renderers:

  - **HTML Renderer**: Localized HTML attributes and content
  - **HEEX Renderer**: LiveView-compatible translation helpers
  - **PDF Renderer**: Locale-aware text positioning and font selection
  - **JSON Renderer**: Translated metadata and field descriptors

  """

  use Gettext.Backend, otp_app: :ash_reports

  alias AshReports.Cldr

  @typedoc "Translation key"
  @type translation_key :: String.t()

  @typedoc "Translation bindings"
  @type translation_bindings :: keyword()

  @typedoc "Translation result"
  @type translation_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Translates a UI element key to the specified locale.

  ## Parameters

  - `key` - The translation key to look up
  - `bindings` - Variable bindings for interpolation (default: [])
  - `locale` - Target locale (default: current locale)

  ## Examples

      iex> AshReports.Translation.translate_ui("field.label.amount")
      {:ok, "Amount"}

      iex> AshReports.Translation.translate_ui("field.label.amount", [], "ar")
      {:ok, "المبلغ"}

      iex> AshReports.Translation.translate_ui("status.records_found", [count: 5])
      {:ok, "5 records found"}

  """
  @spec translate_ui(translation_key(), translation_bindings(), String.t() | nil) ::
          translation_result()
  def translate_ui(key, bindings \\ [], locale \\ nil) when is_binary(key) do
    effective_locale = locale || Cldr.current_locale()

    try do
      Gettext.with_locale(__MODULE__, effective_locale, fn ->
        translated = Gettext.gettext(__MODULE__, key, bindings)
        {:ok, translated}
      end)
    rescue
      Gettext.Error ->
        handle_translation_fallback(key, bindings, effective_locale)

      error ->
        {:error, "Translation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Translates a field label with automatic fallback to humanized field names.

  ## Parameters

  - `field_name` - The field name (atom or string)
  - `locale` - Target locale (default: current locale)

  ## Examples

      iex> AshReports.Translation.translate_field_label(:total_amount)
      "Total Amount"

      iex> AshReports.Translation.translate_field_label("user_name", "ar")
      "اسم المستخدم"

  """
  @spec translate_field_label(atom() | String.t(), String.t() | nil) :: String.t()
  def translate_field_label(field_name, locale \\ nil) do
    effective_locale = locale || Cldr.current_locale()
    field_string = to_string(field_name)
    translation_key = "field.label.#{field_string}"

    case translate_ui(translation_key, [], effective_locale) do
      {:ok, translated} ->
        # Check if we got the key back (meaning no translation found)
        if translated == translation_key do
          humanize_field_name(field_string)
        else
          translated
        end

      {:error, _} ->
        # Fallback to humanized field name
        humanize_field_name(field_string)
    end
  end

  @doc """
  Translates a band title with fallback to default titles.

  ## Parameters

  - `band_name` - The band name (atom or string)
  - `locale` - Target locale (default: current locale)

  ## Examples

      iex> AshReports.Translation.translate_band_title(:header)
      "Header"

      iex> AshReports.Translation.translate_band_title(:summary, "ar")
      "ملخص"

  """
  @spec translate_band_title(atom() | String.t(), String.t() | nil) :: String.t()
  def translate_band_title(band_name, locale \\ nil) do
    effective_locale = locale || Cldr.current_locale()
    band_string = to_string(band_name)
    translation_key = "band.title.#{band_string}"

    case translate_ui(translation_key, [], effective_locale) do
      {:ok, translated} ->
        # Check if we got the key back (meaning no translation found)
        if translated == translation_key do
          humanize_field_name(band_string)
        else
          translated
        end

      {:error, _} ->
        # Fallback to humanized band name
        humanize_field_name(band_string)
    end
  end

  @doc """
  Translates an error message with appropriate error context.

  ## Parameters

  - `error_key` - The error message key
  - `bindings` - Error-specific bindings
  - `locale` - Target locale (default: current locale)

  ## Examples

      iex> AshReports.Translation.translate_error("validation.required", [field: "name"])
      "Name is required"

  """
  @spec translate_error(translation_key(), translation_bindings(), String.t() | nil) ::
          String.t()
  def translate_error(error_key, bindings \\ [], locale \\ nil) do
    effective_locale = locale || Cldr.current_locale()
    full_key = "error.#{error_key}"

    case translate_ui(full_key, bindings, effective_locale) do
      {:ok, translated} -> translated
      {:error, _} -> "Error: #{error_key}"
    end
  end

  @doc """
  Gets available translations for a specific key across all locales.

  ## Parameters

  - `key` - The translation key to check

  ## Examples

      iex> AshReports.Translation.available_translations("field.label.amount")
      %{"en" => "Amount", "ar" => "المبلغ", "he" => "סכום"}

  """
  @spec available_translations(translation_key()) :: map()
  def available_translations(key) when is_binary(key) do
    supported_locales()
    |> Enum.reduce(%{}, fn locale, acc ->
      case translate_ui(key, [], locale) do
        {:ok, translated} -> Map.put(acc, locale, translated)
        {:error, _} -> acc
      end
    end)
  end

  @doc """
  Checks if a translation exists for the given key and locale.

  ## Parameters

  - `key` - The translation key
  - `locale` - The locale to check (default: current locale)

  ## Examples

      iex> AshReports.Translation.translation_exists?("field.label.amount", "ar")
      true

      iex> AshReports.Translation.translation_exists?("non.existent.key", "en")
      false

  """
  @spec translation_exists?(translation_key(), String.t() | nil) :: boolean()
  def translation_exists?(key, locale \\ nil) do
    effective_locale = locale || Cldr.current_locale()

    case translate_ui(key, [], effective_locale) do
      {:ok, translated} ->
        # Check if we got the key back (no translation found)
        translated != key

      {:error, _} ->
        false
    end
  end

  @doc """
  Gets a list of all supported locales for translation.

  ## Examples

      iex> AshReports.Translation.supported_locales()
      ["en", "ar", "he", "fa", "ur", "es", "fr", "de", "ja", "zh"]

  """
  @spec supported_locales() :: [String.t()]
  def supported_locales do
    Application.get_env(:ash_reports, __MODULE__, [])
    |> Keyword.get(:locales, ["en"])
  end

  @doc """
  Gets the fallback locale for missing translations.

  ## Examples

      iex> AshReports.Translation.fallback_locale()
      "en"

  """
  @spec fallback_locale() :: String.t()
  def fallback_locale do
    Application.get_env(:ash_reports, __MODULE__, [])
    |> Keyword.get(:fallback_locale, "en")
  end

  @doc """
  Preloads translations for the specified locales to improve performance.

  ## Parameters

  - `locales` - List of locales to preload (default: all supported)

  ## Examples

      AshReports.Translation.preload_translations(["en", "ar", "he"])

  """
  @spec preload_translations([String.t()]) :: :ok
  def preload_translations(locales \\ nil) do
    target_locales = locales || supported_locales()

    # Preload common translation keys for better performance
    common_keys = [
      "field.label.total",
      "field.label.amount",
      "field.label.date",
      "field.label.name",
      "band.title.header",
      "band.title.detail",
      "band.title.footer",
      "status.loading",
      "status.complete"
    ]

    Enum.each(target_locales, fn locale ->
      Enum.each(common_keys, fn key ->
        # Trigger translation loading
        translate_ui(key, [], locale)
      end)
    end)

    :ok
  end

  @doc """
  Validates that all required translations exist for the specified locales.

  ## Parameters

  - `required_keys` - List of translation keys that must exist
  - `locales` - List of locales to validate (default: all supported)

  ## Examples

      keys = ["field.label.amount", "band.title.header"]
      {:ok, missing} = AshReports.Translation.validate_translations(keys)

  """
  @spec validate_translations([translation_key()], [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def validate_translations(required_keys, locales \\ nil) do
    target_locales = locales || supported_locales()

    missing_translations =
      Enum.reduce(target_locales, %{}, fn locale, acc ->
        missing_in_locale =
          Enum.filter(required_keys, fn key ->
            not translation_exists?(key, locale)
          end)

        if missing_in_locale == [] do
          acc
        else
          Map.put(acc, locale, missing_in_locale)
        end
      end)

    if map_size(missing_translations) == 0 do
      {:ok, %{}}
    else
      {:ok, missing_translations}
    end
  rescue
    error ->
      {:error, "Translation validation failed: #{Exception.message(error)}"}
  end

  # Private helper functions

  defp handle_translation_fallback(key, bindings, locale) do
    fallback_locale = fallback_locale()

    if locale != fallback_locale do
      # Try fallback locale
      case translate_ui(key, bindings, fallback_locale) do
        {:ok, translated} -> {:ok, translated}
        {:error, _} -> {:error, "Translation not found: #{key}"}
      end
    else
      {:error, "Translation not found: #{key}"}
    end
  end

  defp humanize_field_name(field_string) do
    field_string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
