defmodule AshReports.RtlLayoutEngineTest do
  use ExUnit.Case, async: true

  alias AshReports.RtlLayoutEngine

  describe "RTL layout engine" do
    test "adapts position for RTL correctly" do
      position = %{x: 100, y: 50, width: 200, height: 30}
      container_width = 800

      # RTL should mirror horizontally
      rtl_position = RtlLayoutEngine.adapt_position_for_rtl(position, "rtl", container_width)
      # 800 - 100 - 200 = 500
      expected_x = container_width - position.x - position.width

      assert rtl_position.x == expected_x
      # Y should not change
      assert rtl_position.y == position.y
      assert rtl_position.width == position.width
      assert rtl_position.height == position.height
    end

    test "preserves position for LTR" do
      position = %{x: 100, y: 50, width: 200, height: 30}
      container_width = 800

      # LTR should not change position
      ltr_position = RtlLayoutEngine.adapt_position_for_rtl(position, "ltr", container_width)

      assert ltr_position == position
    end

    test "gets correct text alignment for RTL locales" do
      # Arabic should be right-aligned
      assert RtlLayoutEngine.get_text_alignment("ar", :field) == "right"
      assert RtlLayoutEngine.get_text_alignment("he", :label) == "right"

      # English should be left-aligned
      assert RtlLayoutEngine.get_text_alignment("en", :field) == "left"
      assert RtlLayoutEngine.get_text_alignment("fr", :label) == "left"
    end

    test "detects RTL locales correctly" do
      # RTL locales
      assert RtlLayoutEngine.rtl_locale?("ar") == true
      assert RtlLayoutEngine.rtl_locale?("he") == true
      assert RtlLayoutEngine.rtl_locale?("fa") == true
      assert RtlLayoutEngine.rtl_locale?("ur") == true

      # LTR locales
      assert RtlLayoutEngine.rtl_locale?("en") == false
      assert RtlLayoutEngine.rtl_locale?("fr") == false
      assert RtlLayoutEngine.rtl_locale?("de") == false
    end

    test "adapts container layout for RTL" do
      layout_data = %{
        container_width: 800,
        bands: %{
          header: %{
            elements: [
              %{x: 100, y: 0, width: 200, height: 30},
              %{x: 400, y: 0, width: 150, height: 30}
            ]
          },
          detail: %{
            elements: [
              %{x: 50, y: 40, width: 300, height: 20}
            ]
          }
        }
      }

      {:ok, adapted_layout} =
        RtlLayoutEngine.adapt_container_layout(layout_data, text_direction: "rtl")

      # Check that positions were adapted
      header_elements = adapted_layout.bands.header.elements
      first_element = Enum.at(header_elements, 0)

      # Original x: 100, width: 200, container: 800
      # Expected RTL x: 800 - 100 - 200 = 500
      assert first_element.x == 500
      # Y unchanged
      assert first_element.y == 0
    end

    test "preserves layout for LTR" do
      layout_data = %{
        container_width: 800,
        bands: %{
          header: %{
            elements: [%{x: 100, y: 0, width: 200, height: 30}]
          }
        }
      }

      {:ok, adapted_layout} =
        RtlLayoutEngine.adapt_container_layout(layout_data, text_direction: "ltr")

      # Layout should be unchanged for LTR
      original_element = layout_data.bands.header.elements |> List.first()
      adapted_element = adapted_layout.bands.header.elements |> List.first()

      assert adapted_element == original_element
    end

    test "generates RTL CSS properties correctly" do
      css_props = RtlLayoutEngine.generate_rtl_css_properties(:field, "rtl", "ar")

      assert css_props.direction == "rtl"
      assert css_props.text_align == "right"
      assert Map.has_key?(css_props, :unicode_bidi)
    end

    test "generates LTR CSS properties correctly" do
      css_props = RtlLayoutEngine.generate_rtl_css_properties(:field, "ltr", "en")

      assert css_props.direction == "ltr"
      assert css_props.text_align == "left"
    end

    test "adapts band ordering for RTL" do
      bands = [
        %{name: :header, elements: [%{id: 1}, %{id: 2}, %{id: 3}]},
        %{name: :detail, elements: [%{id: 4}, %{id: 5}]}
      ]

      adapted_bands = RtlLayoutEngine.adapt_band_ordering(bands, "rtl")

      # Elements within bands should be reordered for RTL
      header_band = Enum.find(adapted_bands, &(&1.name == :header))
      assert length(header_band.elements) == 3

      # Elements should have rtl_order metadata
      assert Enum.all?(header_band.elements, &Map.has_key?(&1, :rtl_order))
    end

    test "preserves band ordering for LTR" do
      bands = [
        %{name: :header, elements: [%{id: 1}, %{id: 2}]},
        %{name: :detail, elements: [%{id: 3}]}
      ]

      adapted_bands = RtlLayoutEngine.adapt_band_ordering(bands, "ltr")

      # Bands should be unchanged for LTR
      assert adapted_bands == bands
    end

    test "handles edge cases gracefully" do
      # Empty position
      result = RtlLayoutEngine.adapt_position_for_rtl(%{}, "rtl", 800)
      assert is_map(result)

      # Zero container width
      position = %{x: 100, y: 50, width: 200, height: 30}
      result = RtlLayoutEngine.adapt_position_for_rtl(position, "rtl", 0)
      # This is correct: 0 - 100 - 200 = -300
      assert result.x == -300

      # Invalid direction
      result = RtlLayoutEngine.adapt_position_for_rtl(position, "invalid", 800)
      assert result == position
    end
  end
end
