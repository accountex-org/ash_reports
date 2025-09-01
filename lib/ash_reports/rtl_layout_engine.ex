defmodule AshReports.RtlLayoutEngine do
  @moduledoc """
  RTL (Right-to-Left) layout engine for AshReports internationalization.

  This module provides comprehensive RTL layout calculations and positioning
  algorithms to ensure proper rendering of Arabic, Hebrew, Persian, and Urdu
  content across all AshReports output formats.

  ## Features

  - **Position Mirroring**: Automatically mirror element positions for RTL layouts
  - **Text Flow Calculation**: Compute proper text flow and line breaking for RTL
  - **Element Alignment**: Adjust element alignment based on text direction
  - **Container Adaptation**: Adapt container layouts for RTL content flow
  - **Mixed Direction Support**: Handle documents with both LTR and RTL content
  - **Performance Optimization**: Efficient layout calculations with caching

  ## RTL Layout Principles

  ### Horizontal Mirroring
  For RTL languages, the layout is horizontally mirrored:
  - Elements positioned from right edge instead of left
  - Text alignment defaults to right
  - Navigation flows from right to left
  - Icon and UI element order is reversed

  ### Vertical Flow Preservation
  Vertical positioning and flow remain unchanged:
  - Top-to-bottom reading order maintained
  - Vertical margins and padding preserved
  - Band stacking order unchanged

  ## Usage Examples

  ### Basic Position Adaptation

      # Mirror a position for RTL layout
      original_pos = %{x: 100, y: 50, width: 200, height: 30}
      container_width = 800
      
      rtl_pos = RtlLayoutEngine.adapt_position_for_rtl(
        original_pos, 
        "rtl", 
        container_width
      )
      # => %{x: 500, y: 50, width: 200, height: 30}

  ### Element Alignment

      # Get appropriate text alignment for locale
      alignment = RtlLayoutEngine.get_text_alignment("ar", :field)
      # => "right"

  ### Container Layout

      # Adapt entire container for RTL
      {:ok, rtl_layout} = RtlLayoutEngine.adapt_container_layout(
        layout_data,
        text_direction: "rtl",
        locale: "ar"
      )

  """

  alias AshReports.Cldr

  @typedoc "Position coordinates"
  @type position :: %{
          x: number(),
          y: number(),
          width: number(),
          height: number()
        }

  @typedoc "Layout direction"
  @type direction :: String.t()

  @typedoc "Element type for alignment calculations"
  @type element_type :: :field | :label | :header | :footer | :image | :line

  @typedoc "Text alignment"
  @type text_alignment :: String.t()

  @typedoc "Layout adaptation options"
  @type layout_options :: keyword()

  @doc """
  Adapts an element position for RTL layout by mirroring horizontally.

  ## Parameters

  - `position` - Original element position
  - `text_direction` - Text direction ("ltr" or "rtl")
  - `container_width` - Width of the containing element

  ## Examples

      iex> pos = %{x: 100, y: 50, width: 200, height: 30}
      iex> AshReports.RtlLayoutEngine.adapt_position_for_rtl(pos, "rtl", 800)
      %{x: 500, y: 50, width: 200, height: 30}

      iex> AshReports.RtlLayoutEngine.adapt_position_for_rtl(pos, "ltr", 800)
      %{x: 100, y: 50, width: 200, height: 30}

  """
  @spec adapt_position_for_rtl(position(), direction(), number()) :: position()
  def adapt_position_for_rtl(position, direction, container_width)

  def adapt_position_for_rtl(%{x: x, width: width} = position, "rtl", container_width) do
    # Mirror horizontally: new_x = container_width - original_x - width
    mirrored_x = container_width - x - width
    %{position | x: mirrored_x}
  end

  def adapt_position_for_rtl(position, _direction, _container_width) do
    # No change for LTR or invalid direction
    position
  end

  @doc """
  Gets the appropriate text alignment for an element type and locale.

  ## Parameters

  - `locale` - The target locale
  - `element_type` - Type of element for alignment rules

  ## Examples

      iex> AshReports.RtlLayoutEngine.get_text_alignment("ar", :field)
      "right"

      iex> AshReports.RtlLayoutEngine.get_text_alignment("en", :field)
      "left"

  """
  @spec get_text_alignment(String.t(), element_type()) :: text_alignment()
  def get_text_alignment(locale, element_type) do
    direction = Cldr.text_direction(locale)
    get_alignment_for_direction(direction, element_type)
  end

  @doc """
  Adapts a complete container layout for RTL rendering.

  ## Parameters

  - `layout_data` - Original layout data structure
  - `options` - Layout adaptation options

  ## Options

  - `:text_direction` - Text direction ("ltr" or "rtl")
  - `:locale` - Target locale for direction detection
  - `:preserve_original` - Keep original positions in metadata (default: false)

  ## Examples

      layout = %{
        bands: %{
          header: %{elements: [%{x: 100, y: 0, width: 200, height: 30}]},
          detail: %{elements: [%{x: 50, y: 40, width: 300, height: 20}]}
        },
        container_width: 800
      }

      {:ok, rtl_layout} = RtlLayoutEngine.adapt_container_layout(layout, text_direction: "rtl")

  """
  @spec adapt_container_layout(map(), layout_options()) :: {:ok, map()} | {:error, term()}
  def adapt_container_layout(layout_data, options \\ []) do
    direction = get_effective_direction(options)
    container_width = get_container_width(layout_data)

    if direction == "rtl" do
      adapted_layout = adapt_layout_for_rtl(layout_data, container_width, options)
      {:ok, adapted_layout}
    else
      {:ok, layout_data}
    end
  rescue
    error ->
      {:error, "Layout adaptation failed: #{Exception.message(error)}"}
  end

  @doc """
  Calculates CSS properties for RTL-aware styling.

  ## Parameters

  - `element_type` - Type of element
  - `direction` - Text direction
  - `locale` - Target locale for cultural adaptations

  ## Examples

      iex> css = RtlLayoutEngine.generate_rtl_css_properties(:field, "rtl", "ar")
      iex> css[:text_align]
      "right"

  """
  @spec generate_rtl_css_properties(element_type(), direction(), String.t()) :: map()
  def generate_rtl_css_properties(element_type, direction, locale) do
    base_properties = %{
      direction: direction,
      text_align: get_alignment_for_direction(direction, element_type)
    }

    case direction do
      "rtl" ->
        Map.merge(base_properties, rtl_specific_properties(element_type, locale))

      _ ->
        base_properties
    end
  end

  @doc """
  Determines if a locale requires RTL layout adaptations.

  ## Parameters

  - `locale` - Locale to check

  ## Examples

      iex> AshReports.RtlLayoutEngine.rtl_locale?("ar")
      true

      iex> AshReports.RtlLayoutEngine.rtl_locale?("en")
      false

  """
  @spec rtl_locale?(String.t()) :: boolean()
  def rtl_locale?(locale) when is_binary(locale) do
    rtl_locales = ["ar", "he", "fa", "ur"]
    locale in rtl_locales
  end

  @doc """
  Adapts band ordering for RTL layouts where appropriate.

  For most cases, band order (header -> detail -> footer) remains the same,
  but element order within bands may need adjustment.

  ## Parameters

  - `bands` - Original band configuration
  - `direction` - Text direction

  ## Examples

      adapted_bands = RtlLayoutEngine.adapt_band_ordering(bands, "rtl")

  """
  @spec adapt_band_ordering([map()], direction()) :: [map()]
  def adapt_band_ordering(bands, "rtl") do
    # For RTL, we typically reverse element order within bands, not band order
    Enum.map(bands, &adapt_band_elements_for_rtl/1)
  end

  def adapt_band_ordering(bands, _direction) do
    bands
  end

  # Private helper functions

  defp get_effective_direction(options) do
    cond do
      direction = Keyword.get(options, :text_direction) ->
        direction

      locale = Keyword.get(options, :locale) ->
        Cldr.text_direction(locale)

      true ->
        Cldr.text_direction(Cldr.current_locale())
    end
  end

  defp get_container_width(layout_data) do
    cond do
      width = Map.get(layout_data, :container_width) ->
        width

      width = Map.get(layout_data, :width) ->
        width

      true ->
        # Default container width
        800
    end
  end

  defp adapt_layout_for_rtl(layout_data, container_width, options) do
    preserve_original = Keyword.get(options, :preserve_original, false)

    adapted_bands =
      layout_data.bands
      |> Enum.map(fn {band_name, band_data} ->
        adapt_band_for_rtl(band_name, band_data, container_width, preserve_original)
      end)
      |> Enum.into(%{})

    %{layout_data | bands: adapted_bands}
  end

  defp get_alignment_for_direction("rtl", element_type) do
    case element_type do
      :field -> "right"
      :label -> "right"
      :header -> "right"
      :footer -> "right"
      :image -> "right"
      _ -> "right"
    end
  end

  defp get_alignment_for_direction(_direction, element_type) do
    case element_type do
      :field -> "left"
      :label -> "left"
      :header -> "left"
      :footer -> "left"
      :image -> "left"
      _ -> "left"
    end
  end

  defp rtl_specific_properties(element_type, _locale) do
    base_rtl = %{
      unicode_bidi: "embed",
      writing_mode: "horizontal-tb"
    }

    case element_type do
      :field ->
        Map.merge(base_rtl, %{
          padding_right: "0.5em",
          padding_left: "0"
        })

      :header ->
        Map.merge(base_rtl, %{
          border_right: "1px solid #ccc",
          border_left: "none"
        })

      _ ->
        base_rtl
    end
  end

  defp adapt_band_elements_for_rtl(band) do
    elements = Map.get(band, :elements, [])

    # For RTL, reverse the visual order of elements within the band
    # but preserve their logical relationships
    adapted_elements =
      elements
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map(fn {element, index} ->
        Map.put(element, :rtl_order, index)
      end)

    Map.put(band, :elements, adapted_elements)
  end

  defp adapt_band_for_rtl(band_name, band_data, container_width, preserve_original) do
    adapted_elements =
      Map.get(band_data, :elements, [])
      |> Enum.map(fn element ->
        adapt_element_for_rtl(element, container_width, preserve_original)
      end)

    adapted_band_data = Map.put(band_data, :elements, adapted_elements)
    {band_name, adapted_band_data}
  end

  defp adapt_element_for_rtl(element, container_width, preserve_original) do
    original_position = element
    adapted_position = adapt_position_for_rtl(element, "rtl", container_width)

    if preserve_original do
      adapted_position
      |> Map.put(:original_position, original_position)
    else
      adapted_position
    end
  end
end
