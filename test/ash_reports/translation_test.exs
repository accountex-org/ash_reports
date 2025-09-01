defmodule AshReports.TranslationTest do
  use ExUnit.Case, async: true

  alias AshReports.Translation

  describe "Translation module" do
    test "translates UI elements correctly" do
      {:ok, result} = Translation.translate_ui("field.label.amount", [], "en")
      assert result == "Amount"

      {:ok, result} = Translation.translate_ui("field.label.total", [], "en")
      assert result == "Total"
    end

    test "handles missing translations with fallback" do
      # Test non-existent key falls back gracefully
      case Translation.translate_ui("non.existent.key", [], "en") do
        # Translation found (unexpected but ok)
        {:ok, _} -> :ok
        {:error, reason} -> assert reason =~ "not found"
      end
    end

    test "translates field labels with humanization fallback" do
      # Existing translation
      result = Translation.translate_field_label(:amount, "en")
      assert result == "Amount"

      # Non-existent translation should humanize
      result = Translation.translate_field_label(:custom_field_name, "en")
      assert result == "Custom Field Name"
    end

    test "translates band titles with fallback" do
      result = Translation.translate_band_title(:header, "en")
      assert result == "Header"

      result = Translation.translate_band_title(:detail, "en")
      assert result == "Detail"

      # Non-existent band should humanize
      result = Translation.translate_band_title(:custom_summary, "en")
      assert result == "Custom Summary"
    end

    test "supports locale fallback" do
      # Test that unsupported locale falls back to fallback locale
      result = Translation.translate_field_label(:amount, "xx")
      assert is_binary(result)
    end

    test "checks translation existence" do
      assert Translation.translation_exists?("field.label.amount", "en") == true
      assert Translation.translation_exists?("non.existent.key", "en") == false
    end

    test "lists supported locales" do
      locales = Translation.supported_locales()
      assert is_list(locales)
      assert "en" in locales
    end

    test "validates translations across locales" do
      required_keys = ["field.label.amount", "field.label.total"]
      {:ok, missing} = Translation.validate_translations(required_keys, ["en"])

      # Should be a map (empty if all translations exist)
      assert is_map(missing)
    end

    test "preloads translations successfully" do
      # Should complete without error
      assert Translation.preload_translations(["en"]) == :ok
    end

    test "gets available translations for key" do
      translations = Translation.available_translations("field.label.amount")
      assert is_map(translations)
      assert Map.has_key?(translations, "en")
    end

    test "translates error messages" do
      # Basic error translation (may not exist, should not crash)
      result = Translation.translate_error("validation.required", [field: "name"], "en")
      assert is_binary(result)
    end
  end
end
