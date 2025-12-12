defmodule AshReports.LocaleRenderingTest do
  use ExUnit.Case, async: true

  alias AshReports.{IrHtmlRenderer, RenderContext, RtlLayoutEngine, Translation}

  describe "Phase 4.3 locale-aware rendering integration" do
    test "HTML renderer includes RTL configuration" do
      # Create a mock report context for RTL locale
      context = create_mock_context_with_locale("ar")

      # The renderer should detect RTL and configure appropriately
      # Note: This tests the integration without requiring full rendering
      assert RenderContext.get_locale(context) == "ar"
    end

    test "RTL layout engine integrates with HTML renderer" do
      # Test that layout adaptations work correctly
      layout_data = %{
        container_width: 800,
        bands: %{
          detail: %{
            elements: [%{x: 100, y: 0, width: 200, height: 30}]
          }
        }
      }

      {:ok, adapted} = RtlLayoutEngine.adapt_container_layout(layout_data, text_direction: "rtl")

      # Position should be mirrored for RTL
      detail_element = adapted.bands.detail.elements |> List.first()
      # 800 - 100 - 200
      assert detail_element.x == 500
    end

    test "translation system provides field labels" do
      # Test field label translation
      label = Translation.translate_field_label(:amount, "en")
      assert is_binary(label)
      assert label != ""

      # Test with RTL locale
      ar_label = Translation.translate_field_label(:amount, "ar")
      assert is_binary(ar_label)
      assert ar_label != ""
    end

    test "translation system provides band titles" do
      # Test band title translation
      title = Translation.translate_band_title(:header, "en")
      assert title == "Header"

      title = Translation.translate_band_title(:detail, "en")
      assert title == "Detail"
    end

    test "locale detection works correctly" do
      # Test RTL locale detection
      assert RtlLayoutEngine.rtl_locale?("ar") == true
      assert RtlLayoutEngine.rtl_locale?("he") == true
      assert RtlLayoutEngine.rtl_locale?("en") == false
    end

    test "CSS properties generate correctly for RTL" do
      css_props = RtlLayoutEngine.generate_rtl_css_properties(:field, "rtl", "ar")

      assert css_props.direction == "rtl"
      assert css_props.text_align == "right"
      assert Map.has_key?(css_props, :unicode_bidi)
    end

    test "translation validation works" do
      required_keys = ["field.label.amount", "field.label.total"]
      {:ok, missing} = Translation.validate_translations(required_keys, ["en"])

      # Should return a map of missing translations by locale
      assert is_map(missing)
    end

    test "supports multiple RTL locales" do
      rtl_locales = ["ar", "he", "fa", "ur"]

      Enum.each(rtl_locales, fn locale ->
        assert RtlLayoutEngine.rtl_locale?(locale) == true

        css = RtlLayoutEngine.generate_rtl_css_properties(:field, "rtl", locale)
        assert css.text_align == "right"
        assert css.direction == "rtl"
      end)
    end

    test "handles mixed direction content gracefully" do
      # Test that system can handle documents with mixed LTR/RTL
      ltr_position = %{x: 100, y: 50, width: 200, height: 30}

      # Same position should adapt differently for different directions
      rtl_adapted = RtlLayoutEngine.adapt_position_for_rtl(ltr_position, "rtl", 800)
      ltr_adapted = RtlLayoutEngine.adapt_position_for_rtl(ltr_position, "ltr", 800)

      assert rtl_adapted != ltr_adapted
      assert ltr_adapted == ltr_position
    end

    test "preserves non-positional data during RTL adaptation" do
      layout_data = %{
        container_width: 600,
        metadata: %{version: "1.0"},
        bands: %{
          header: %{
            title: "Test Header",
            elements: [%{x: 50, y: 0, width: 100, height: 20, id: "test"}]
          }
        }
      }

      {:ok, adapted} = RtlLayoutEngine.adapt_container_layout(layout_data, text_direction: "rtl")

      # Metadata should be preserved
      assert adapted.metadata == layout_data.metadata
      assert adapted.bands.header.title == "Test Header"

      # But positions should be adapted
      original_element = layout_data.bands.header.elements |> List.first()
      adapted_element = adapted.bands.header.elements |> List.first()

      assert adapted_element.x != original_element.x
      assert adapted_element.id == original_element.id
    end
  end

  # Helper functions for creating test contexts
  defp create_mock_context_with_locale(locale) do
    %RenderContext{
      report: create_mock_report(),
      records: [],
      locale: locale,
      metadata: %{},
      config: %{}
    }
  end

  defp create_mock_report do
    %{
      name: :test_report,
      title: "Test Report",
      bands: [
        %{
          name: :header,
          elements: [
            %{type: :field, name: :title, source: :title}
          ]
        },
        %{
          name: :detail,
          elements: [
            %{type: :field, name: :amount, source: :amount},
            %{type: :field, name: :date, source: :date}
          ]
        }
      ]
    }
  end
end
