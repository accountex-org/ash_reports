defmodule AshReports.LayoutEngine do
  @moduledoc """
  Band layout calculation and element positioning algorithms for AshReports.

  The LayoutEngine is responsible for calculating precise positioning of bands and
  elements within a report layout, managing page breaks, handling overflow, and
  optimizing space utilization. This is a core component of the Phase 3.1 Renderer
  Interface that provides sophisticated layout algorithms for various report formats.

  ## Key Features

  - **Band Layout**: Automatic calculation of band heights and positions
  - **Element Positioning**: Precise placement of elements within bands
  - **Page Management**: Intelligent page break detection and handling
  - **Overflow Detection**: Automatic detection and resolution of layout overflow
  - **Space Optimization**: Efficient utilization of available space
  - **Multi-Format Support**: Layout calculations for different output formats

  ## Layout Algorithms

  ### Band Positioning Algorithm

  1. Calculate band content requirements
  2. Determine optimal band heights
  3. Position bands sequentially with proper spacing
  4. Handle page breaks when necessary

  ### Element Positioning Algorithm

  1. Analyze element dimensions and constraints
  2. Calculate positions based on layout rules
  3. Handle element overflow and wrapping
  4. Optimize spacing and alignment

  ## Usage Patterns

  ### Basic Layout Calculation

      layout = LayoutEngine.calculate_layout(context)

  ### Band-Specific Layout

      band_layout = LayoutEngine.calculate_band_layout(band, context)

  ### Element Positioning

      positions = LayoutEngine.position_elements(elements, band_layout)

  ### Page Break Detection

      if LayoutEngine.requires_page_break?(context, next_band) do
        handle_page_break()
      end

  ## Integration with RenderContext

  The LayoutEngine works seamlessly with RenderContext:

      context = RenderContext.new(report, data_result, config)
      layout_result = LayoutEngine.calculate_layout(context)
      updated_context = RenderContext.update_layout_state(context, layout_result)

  """

  alias AshReports.{Band, RenderContext}

  @type layout_result :: %{
          bands: %{atom() => band_layout()},
          total_height: number(),
          page_breaks: [page_break()],
          overflow_elements: [map()],
          warnings: [map()]
        }

  @type band_layout :: %{
          band: Band.t(),
          position: %{x: number(), y: number()},
          dimensions: %{width: number(), height: number()},
          elements: [element_layout()],
          page_number: pos_integer(),
          overflow?: boolean()
        }

  @type element_layout :: %{
          element: map(),
          position: %{x: number(), y: number()},
          dimensions: %{width: number(), height: number()},
          visible?: boolean(),
          overflow?: boolean()
        }

  @type page_break :: %{
          before_band: atom(),
          page_number: pos_integer(),
          reason: atom(),
          position: number()
        }

  @type layout_options :: [
          strict_bounds: boolean(),
          allow_overflow: boolean(),
          optimize_space: boolean(),
          min_band_height: number(),
          element_spacing: number()
        ]

  @doc """
  Calculates the complete layout for a report context.

  This is the main entry point for layout calculation, providing a comprehensive
  layout solution for all bands and elements in the report.

  ## Examples

      layout_result = LayoutEngine.calculate_layout(context)

  """
  @spec calculate_layout(RenderContext.t(), layout_options()) :: layout_result()
  def calculate_layout(%RenderContext{} = context, options \\ []) do
    start_time = System.monotonic_time(:microsecond)

    options = merge_default_options(options)

    layout_result =
      context
      |> extract_bands()
      |> calculate_bands_layout(context, options)
      |> detect_page_breaks(context, options)
      |> detect_overflow(context, options)
      |> optimize_layout(context, options)

    end_time = System.monotonic_time(:microsecond)
    calculation_time = end_time - start_time

    Map.put(layout_result, :calculation_time_us, calculation_time)
  end

  @doc """
  Calculates the layout for a specific band.

  ## Examples

      band_layout = LayoutEngine.calculate_band_layout(band, context)

  """
  @spec calculate_band_layout(Band.t(), RenderContext.t(), layout_options()) :: band_layout()
  def calculate_band_layout(%Band{} = band, %RenderContext{} = context, options \\ []) do
    options = merge_default_options(options)

    {content_width, content_height} = get_content_dimensions(context)
    current_y = get_current_y_position(context)

    # Calculate element layouts first
    element_layouts = calculate_elements_layout(band.elements || [], context, options)

    # Determine band dimensions based on content
    band_height = calculate_band_height(band, element_layouts, options)
    band_width = content_width

    %{
      band: band,
      position: %{x: 0, y: current_y},
      dimensions: %{width: band_width, height: band_height},
      elements: element_layouts,
      page_number: get_current_page(context),
      overflow?: check_band_overflow(band_height, current_y, content_height)
    }
  end

  @doc """
  Positions elements within a band layout.

  ## Examples

      element_positions = LayoutEngine.position_elements(elements, band_layout)

  """
  @spec position_elements([map()], band_layout(), layout_options()) :: [element_layout()]
  def position_elements(elements, band_layout, options \\ []) do
    options = merge_default_options(options)

    elements
    |> Enum.with_index()
    |> Enum.map(fn {element, index} ->
      calculate_element_layout(element, index, band_layout, options)
    end)
  end

  @doc """
  Checks if a page break is required before adding a band.

  ## Examples

      if LayoutEngine.requires_page_break?(context, next_band) do
        handle_page_break()
      end

  """
  @spec requires_page_break?(RenderContext.t(), Band.t(), layout_options()) :: boolean()
  def requires_page_break?(%RenderContext{} = context, %Band{} = band, options \\ []) do
    options = merge_default_options(options)

    {_content_width, content_height} = get_content_dimensions(context)
    current_y = get_current_y_position(context)

    # Estimate band height
    estimated_height = estimate_band_height(band, context, options)

    # Check if band would exceed page bounds
    current_y + estimated_height > content_height
  end

  @doc """
  Optimizes the layout for better space utilization.

  ## Examples

      optimized_layout = LayoutEngine.optimize_layout(layout_result, context)

  """
  @spec optimize_layout(layout_result(), RenderContext.t(), layout_options()) :: layout_result()
  def optimize_layout(layout_result, %RenderContext{} = context, options \\ []) do
    if options[:optimize_space] do
      layout_result
      |> compress_vertical_space(context, options)
      |> align_elements(context, options)
      |> balance_columns(context, options)
    else
      layout_result
    end
  end

  @doc """
  Validates a layout result for correctness.

  ## Examples

      case LayoutEngine.validate_layout(layout_result, context) do
        :ok -> proceed_with_rendering(layout_result)
        {:error, issues} -> handle_layout_issues(issues)
      end

  """
  @spec validate_layout(layout_result(), RenderContext.t()) :: :ok | {:error, [map()]}
  def validate_layout(layout_result, %RenderContext{} = context) do
    issues =
      []
      |> validate_bounds(layout_result, context)
      |> validate_overlaps(layout_result)
      |> validate_readability(layout_result)

    if issues == [] do
      :ok
    else
      {:error, issues}
    end
  end

  @doc """
  Gets the dimensions of a layout element.

  ## Examples

      {width, height} = LayoutEngine.get_element_dimensions(element, context)

  """
  @spec get_element_dimensions(map(), RenderContext.t()) :: {number(), number()}
  def get_element_dimensions(element, %RenderContext{} = context) when is_map(element) do
    # Get base dimensions from element or defaults
    position = Map.get(element, :position, %{})
    element_type = Map.get(element, :type, :label)
    base_width = Map.get(position, :width, get_default_element_width(element_type))
    base_height = Map.get(position, :height, get_default_element_height(element_type))

    # Apply scaling based on context configuration
    scale_factor = get_scale_factor(context)

    {base_width * scale_factor, base_height * scale_factor}
  end

  @doc """
  Calculates the available space in a band.

  ## Examples

      available_space = LayoutEngine.get_available_space(band_layout)

  """
  @spec get_available_space(band_layout()) :: %{width: number(), height: number()}
  def get_available_space(band_layout) do
    band_dimensions = band_layout.dimensions

    # Calculate space used by elements
    used_space = calculate_used_space(band_layout.elements)

    %{
      width: band_dimensions.width - used_space.width,
      height: band_dimensions.height - used_space.height
    }
  end

  # Private implementation functions

  defp merge_default_options(options) do
    defaults = [
      strict_bounds: true,
      allow_overflow: false,
      optimize_space: true,
      min_band_height: 20,
      element_spacing: 5
    ]

    Keyword.merge(defaults, options)
  end

  defp extract_bands(%RenderContext{report: %{bands: bands}}) when is_list(bands) do
    bands
  end

  defp extract_bands(%RenderContext{report: report}) do
    # Handle case where bands might be in a different structure
    Map.get(report, :bands, [])
  end

  defp calculate_bands_layout(bands, context, options) do
    current_y = 0

    {band_layouts, _final_y} =
      Enum.reduce(bands, {%{}, current_y}, fn band, {acc_layouts, y_pos} ->
        # Update context with current position
        temp_context = RenderContext.update_position(context, %{x: 0, y: y_pos})

        band_layout = calculate_band_layout(band, temp_context, options)
        new_y = y_pos + band_layout.dimensions.height

        {Map.put(acc_layouts, band.name, band_layout), new_y}
      end)

    %{
      bands: band_layouts,
      total_height: calculate_total_height(band_layouts),
      page_breaks: [],
      overflow_elements: [],
      warnings: []
    }
  end

  defp calculate_elements_layout(elements, context, options) do
    elements
    |> Enum.with_index()
    |> Enum.map(fn {element, index} ->
      calculate_element_layout(
        element,
        index,
        %{dimensions: get_content_dimensions_map(context)},
        options
      )
    end)
  end

  defp calculate_element_layout(element, index, band_layout, options) when is_map(element) do
    # Calculate position based on element properties and band layout
    position = Map.get(element, :position, %{})
    # Default spacing if no x specified
    element_x = Map.get(position, :x, index * 100)
    element_y = Map.get(position, :y, 0)

    {element_width, element_height} = calculate_element_dimensions(element, band_layout, options)

    %{
      element: element,
      position: %{x: element_x, y: element_y},
      dimensions: %{width: element_width, height: element_height},
      visible?: true,
      overflow?:
        check_element_overflow(element_x, element_y, element_width, element_height, band_layout)
    }
  end

  defp calculate_element_dimensions(element, band_layout, _options) when is_map(element) do
    # Use element dimensions if specified, otherwise calculate based on content
    position = Map.get(element, :position, %{})
    element_type = Map.get(element, :type, :label)
    width = Map.get(position, :width, get_default_element_width(element_type))
    height = Map.get(position, :height, get_default_element_height(element_type))

    # Ensure element fits within band
    max_width = band_layout.dimensions.width
    max_height = band_layout.dimensions.height

    {min(width, max_width), min(height, max_height)}
  end

  defp calculate_band_height(%Band{} = band, element_layouts, options) do
    # Use explicit height if provided
    if band.height do
      band.height
    else
      # Calculate height based on content
      max_element_bottom =
        element_layouts
        |> Enum.map(fn layout ->
          layout.position.y + layout.dimensions.height
        end)
        |> Enum.max(fn -> 0 end)

      max(max_element_bottom, options[:min_band_height])
    end
  end

  defp detect_page_breaks(layout_result, context, _options) do
    {_content_width, content_height} = get_content_dimensions(context)

    page_breaks =
      layout_result.bands
      |> Enum.reduce([], fn {band_name, band_layout}, acc ->
        if band_layout.position.y + band_layout.dimensions.height > content_height do
          page_break = %{
            before_band: band_name,
            page_number: band_layout.page_number,
            reason: :height_overflow,
            position: band_layout.position.y
          }

          [page_break | acc]
        else
          acc
        end
      end)
      |> Enum.reverse()

    %{layout_result | page_breaks: page_breaks}
  end

  defp detect_overflow(layout_result, _context, options) do
    if options[:allow_overflow] do
      layout_result
    else
      overflow_elements =
        layout_result.bands
        |> Enum.flat_map(fn {_band_name, band_layout} ->
          Enum.filter(band_layout.elements, & &1.overflow?)
        end)
        |> Enum.map(& &1.element)

      %{layout_result | overflow_elements: overflow_elements}
    end
  end

  defp compress_vertical_space(layout_result, _context, _options) do
    # Implement vertical space compression algorithm
    layout_result
  end

  defp align_elements(layout_result, _context, _options) do
    # Implement element alignment algorithm
    layout_result
  end

  defp balance_columns(layout_result, _context, _options) do
    # Implement column balancing algorithm
    layout_result
  end

  defp validate_bounds(issues, layout_result, context) do
    {content_width, content_height} = get_content_dimensions(context)

    layout_result.bands
    |> Enum.reduce(issues, fn {band_name, band_layout}, acc ->
      if band_layout.position.x + band_layout.dimensions.width > content_width or
           band_layout.position.y + band_layout.dimensions.height > content_height do
        issue = %{
          type: :bounds_violation,
          band: band_name,
          message: "Band exceeds content bounds"
        }

        [issue | acc]
      else
        acc
      end
    end)
  end

  defp validate_overlaps(issues, layout_result) do
    # Check for element overlaps within bands
    layout_result.bands
    |> Enum.reduce(issues, fn {band_name, band_layout}, acc ->
      overlaps = detect_element_overlaps(band_layout.elements)

      overlap_issues =
        Enum.map(overlaps, fn {elem1, elem2} ->
          %{
            type: :element_overlap,
            band: band_name,
            elements: [elem1.element.name, elem2.element.name],
            message: "Elements overlap in band #{band_name}"
          }
        end)

      overlap_issues ++ acc
    end)
  end

  defp validate_readability(issues, _layout_result) do
    # Add readability validation logic here
    issues
  end

  defp get_content_dimensions(%RenderContext{} = context) do
    page_dims = context.page_dimensions

    # Apply margins (simplified - would need to read from config)
    # {top, right, bottom, left}
    margins = {0.5, 0.5, 0.5, 0.5}
    {top, right, bottom, left} = margins

    content_width = page_dims.width - left - right
    content_height = page_dims.height - top - bottom

    {content_width, content_height}
  end

  defp get_content_dimensions_map(context) do
    {width, height} = get_content_dimensions(context)
    %{width: width, height: height}
  end

  defp get_current_y_position(%RenderContext{current_position: position}) do
    position.y
  end

  defp get_current_page(%RenderContext{layout_state: layout_state}) do
    Map.get(layout_state, :current_page, 1)
  end

  defp check_band_overflow(band_height, current_y, content_height) do
    current_y + band_height > content_height
  end

  defp check_element_overflow(x, y, width, height, band_layout) do
    element_right = x + width
    element_bottom = y + height
    band_width = band_layout.dimensions.width
    band_height = band_layout.dimensions.height

    element_right > band_width or element_bottom > band_height
  end

  defp estimate_band_height(%Band{height: height}, _context, _options) when is_number(height) do
    height
  end

  defp estimate_band_height(%Band{elements: elements}, _context, options)
       when is_list(elements) do
    # Estimate based on elements
    estimated_height =
      elements
      |> Enum.map(fn element ->
        element_type = Map.get(element, :type, :label)
        get_default_element_height(element_type)
      end)
      |> Enum.max(fn -> options[:min_band_height] end)

    max(estimated_height, options[:min_band_height])
  end

  defp estimate_band_height(_band, _context, options) do
    options[:min_band_height]
  end

  defp calculate_total_height(band_layouts) do
    band_layouts
    |> Enum.map(fn {_name, layout} ->
      layout.position.y + layout.dimensions.height
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp calculate_used_space(element_layouts) do
    total_width =
      element_layouts
      |> Enum.map(fn layout -> layout.position.x + layout.dimensions.width end)
      |> Enum.max(fn -> 0 end)

    total_height =
      element_layouts
      |> Enum.map(fn layout -> layout.position.y + layout.dimensions.height end)
      |> Enum.max(fn -> 0 end)

    %{width: total_width, height: total_height}
  end

  defp detect_element_overlaps(element_layouts) do
    # Simple O(n²) overlap detection
    for {elem1, i} <- Enum.with_index(element_layouts),
        {elem2, j} <- Enum.with_index(element_layouts),
        i < j,
        elements_overlap?(elem1, elem2) do
      {elem1, elem2}
    end
  end

  defp elements_overlap?(elem1, elem2) do
    # Check if two elements overlap
    elem1_right = elem1.position.x + elem1.dimensions.width
    elem1_bottom = elem1.position.y + elem1.dimensions.height
    elem2_right = elem2.position.x + elem2.dimensions.width
    elem2_bottom = elem2.position.y + elem2.dimensions.height

    not (elem1_right <= elem2.position.x or
           elem2_right <= elem1.position.x or
           elem1_bottom <= elem2.position.y or
           elem2_bottom <= elem1.position.y)
  end

  defp get_default_element_width(:label), do: 100
  defp get_default_element_width(:field), do: 150
  defp get_default_element_width(:line), do: 200
  defp get_default_element_width(:box), do: 100
  defp get_default_element_width(:image), do: 100
  defp get_default_element_width(_), do: 100

  defp get_default_element_height(:label), do: 20
  defp get_default_element_height(:field), do: 20
  defp get_default_element_height(:line), do: 1
  defp get_default_element_height(:box), do: 50
  defp get_default_element_height(:image), do: 100
  defp get_default_element_height(_), do: 20

  defp get_scale_factor(%RenderContext{config: config}) do
    Map.get(config, :scale_factor, 1.0)
  end
end
