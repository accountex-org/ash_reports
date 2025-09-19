defmodule AshReports.HtmlRenderer.ElementBuilder do
  @moduledoc """
  Phase 3.2.3 HTML Element Builders - Type-specific element factories and builders.

  The ElementBuilder provides comprehensive HTML element generation capabilities,
  converting report elements into semantic HTML with proper styling, accessibility,
  and responsive behavior.

  ## Key Features

  - **Type-Specific Factories**: Specialized builders for each element type
  - **Semantic HTML**: Standards-compliant HTML5 with proper semantics
  - **Accessibility Support**: ARIA labels, alt text, and screen reader compatibility
  - **Context Awareness**: Full access to RenderContext data and variables
  - **Custom Attributes**: Support for custom HTML attributes and data attributes
  - **Content Escaping**: Automatic HTML escaping for security

  ## Supported Element Types

  ### Label Elements

  Text labels with styling and positioning:

  ```elixir
  element = %{type: :label, text: "Customer Name", position: %{x: 10, y: 20}}
  {:ok, html} = ElementBuilder.build_label(element, context)
  # <div class="ash-element ash-element-label" style="...">Customer Name</div>
  ```

  ### Field Elements

  Data fields with value rendering:

  ```elixir
  element = %{type: :field, expression: expr(customer.name)}
  {:ok, html} = ElementBuilder.build_field(element, context)
  # <div class="ash-element ash-element-field" data-field="customer.name">John Doe</div>
  ```

  ### Line Elements

  Horizontal and vertical lines:

  ```elixir
  element = %{type: :line, orientation: :horizontal, width: 200}
  {:ok, html} = ElementBuilder.build_line(element, context)
  # <hr class="ash-element ash-element-line" style="width: 200px;">
  ```

  ### Box Elements

  Rectangular containers with borders:

  ```elixir
  element = %{type: :box, border: true, background: "#f0f0f0"}
  {:ok, html} = ElementBuilder.build_box(element, context)
  # <div class="ash-element ash-element-box" style="..."></div>
  ```

  ### Image Elements

  Images with proper alt text and sizing:

  ```elixir
  element = %{type: :image, src: "logo.png", alt: "Company Logo"}
  {:ok, html} = ElementBuilder.build_image(element, context)
  # <img class="ash-element ash-element-image" src="logo.png" alt="Company Logo">
  ```

  ## Element Context

  All elements have access to full render context:

  - **Current Record**: Access to current data record being processed
  - **Variables**: Calculated variables from Phase 2 processing
  - **Layout Information**: Positioning and sizing from LayoutEngine
  - **Configuration**: Render configuration and options

  ## Usage

      # Build all elements for a context
      {:ok, html_elements} = ElementBuilder.build_all_elements(context)

      # Build specific element
      {:ok, html} = ElementBuilder.build_element(element, context)

      # Check element support
      if ElementBuilder.supports_element?(element) do
        build_element(element, context)
      end

  """

  alias AshReports.{CalculationEngine, RenderContext}

  @type element_html :: %{
          html_content: String.t(),
          element_type: atom(),
          element_name: String.t() | nil,
          band_name: String.t() | nil,
          css_classes: [String.t()],
          attributes: map()
        }

  @type build_options :: [
          escape_html: boolean(),
          include_data_attributes: boolean(),
          responsive: boolean(),
          accessibility: boolean()
        ]

  @supported_elements [
    :label,
    :field,
    :line,
    :box,
    :image,
    :aggregate,
    :expression
  ]

  @doc """
  Builds HTML for all elements in the given context.

  ## Examples

      {:ok, html_elements} = ElementBuilder.build_all_elements(context)

  """
  @spec build_all_elements(RenderContext.t(), build_options()) ::
          {:ok, [element_html()]} | {:error, term()}
  def build_all_elements(%RenderContext{} = context, options \\ []) do
    html_elements =
      context.report.bands
      |> Enum.flat_map(fn band ->
        band_elements = band.elements || []

        band_elements
        |> Enum.map(&build_single_element(&1, context, options, band.name))
        |> Enum.filter(&filter_successful_elements/1)
      end)

    {:ok, html_elements}
  rescue
    error ->
      {:error, {:element_building_failed, error}}
  end

  @doc """
  Builds HTML for a single element.

  ## Examples

      element = %{type: :label, text: "Total Amount"}
      {:ok, html} = ElementBuilder.build_element(element, context)

  """
  @spec build_element(map(), RenderContext.t(), build_options()) ::
          {:ok, element_html()} | {:error, term()}
  def build_element(element, %RenderContext{} = context, options \\ []) when is_map(element) do
    element_type = Map.get(element, :type, :label)

    if supports_element_type?(element_type) do
      case build_element_by_type(element_type, element, context, options) do
        {:ok, html_content} ->
          element_html = %{
            html_content: html_content,
            element_type: element_type,
            element_name: Map.get(element, :name),
            band_name: nil,
            css_classes: build_css_classes(element_type, element),
            attributes: build_attributes(element, options)
          }

          {:ok, element_html}

        {:error, _reason} = error ->
          error
      end
    else
      {:error, {:unsupported_element_type, element_type}}
    end
  end

  @doc """
  Checks if an element type is supported.

  ## Examples

      if ElementBuilder.supports_element?(element) do
        render_element(element)
      end

  """
  @spec supports_element?(map()) :: boolean()
  def supports_element?(element) when is_map(element) do
    element_type = Map.get(element, :type, :label)
    supports_element_type?(element_type)
  end

  @doc """
  Checks if a specific element type is supported.

  ## Examples

      ElementBuilder.supports_element_type?(:label) # true
      ElementBuilder.supports_element_type?(:custom) # false

  """
  @spec supports_element_type?(atom()) :: boolean()
  def supports_element_type?(element_type) do
    element_type in @supported_elements
  end

  @doc """
  Gets the list of all supported element types.

  ## Examples

      supported = ElementBuilder.get_supported_elements()

  """
  @spec get_supported_elements() :: [atom()]
  def get_supported_elements do
    @supported_elements
  end

  # Type-specific builders

  @doc """
  Builds HTML for a label element.

  ## Examples

      element = %{type: :label, text: "Customer Name", font_weight: "bold"}
      {:ok, html} = ElementBuilder.build_label(element, context)

  """
  @spec build_label(map(), RenderContext.t(), build_options()) ::
          {:ok, String.t()} | {:error, term()}
  def build_label(element, %RenderContext{} = context, options \\ []) do
    text = resolve_element_text(element, context)
    position_style = build_position_style(element, context)
    font_style = build_font_style(element)

    attributes = build_html_attributes(element, options)
    escaped_text = maybe_escape_html(text, options)

    html =
      """
      <div class="ash-element ash-element-label"#{attributes} style="#{position_style}#{font_style}">#{escaped_text}</div>
      """
      |> String.trim()

    {:ok, html}
  end

  @doc """
  Builds HTML for a field element.

  ## Examples

      element = %{type: :field, expression: expr(customer.name)}
      {:ok, html} = ElementBuilder.build_field(element, context)

  """
  @spec build_field(map(), RenderContext.t(), build_options()) ::
          {:ok, String.t()} | {:error, term()}
  def build_field(element, %RenderContext{} = context, options \\ []) do
    with {:ok, field_value} <- resolve_field_value(element, context),
         {:ok, formatted_value} <- format_field_value(field_value, element, context) do
      position_style = build_position_style(element, context)
      field_style = build_field_style(element)

      attributes = build_html_attributes(element, options)
      data_attributes = build_field_data_attributes(element)
      escaped_value = maybe_escape_html(formatted_value, options)

      html =
        """
        <div class="ash-element ash-element-field"#{attributes}#{data_attributes} style="#{position_style}#{field_style}">#{escaped_value}</div>
        """
        |> String.trim()

      {:ok, html}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Builds HTML for a line element.

  ## Examples

      element = %{type: :line, orientation: :horizontal, width: 200}
      {:ok, html} = ElementBuilder.build_line(element, context)

  """
  @spec build_line(map(), RenderContext.t(), build_options()) ::
          {:ok, String.t()} | {:error, term()}
  def build_line(element, %RenderContext{} = context, options \\ []) do
    orientation = Map.get(element, :orientation, :horizontal)
    position_style = build_position_style(element, context)
    line_style = build_line_style(element, orientation)

    attributes = build_html_attributes(element, options)

    html =
      case orientation do
        :horizontal ->
          """
          <hr class="ash-element ash-element-line ash-line-horizontal"#{attributes} style="#{position_style}#{line_style}">
          """

        :vertical ->
          """
          <div class="ash-element ash-element-line ash-line-vertical"#{attributes} style="#{position_style}#{line_style}"></div>
          """
      end
      |> String.trim()

    {:ok, html}
  end

  @doc """
  Builds HTML for a box element.

  ## Examples

      element = %{type: :box, border: true, background: "#f0f0f0"}
      {:ok, html} = ElementBuilder.build_box(element, context)

  """
  @spec build_box(map(), RenderContext.t(), build_options()) ::
          {:ok, String.t()} | {:error, term()}
  def build_box(element, %RenderContext{} = context, options \\ []) do
    position_style = build_position_style(element, context)
    box_style = build_box_style(element)

    attributes = build_html_attributes(element, options)
    content = Map.get(element, :content, "")
    escaped_content = maybe_escape_html(content, options)

    html =
      """
      <div class="ash-element ash-element-box"#{attributes} style="#{position_style}#{box_style}">#{escaped_content}</div>
      """
      |> String.trim()

    {:ok, html}
  end

  @doc """
  Builds HTML for an image element.

  ## Examples

      element = %{type: :image, src: "logo.png", alt: "Company Logo"}
      {:ok, html} = ElementBuilder.build_image(element, context)

  """
  @spec build_image(map(), RenderContext.t(), build_options()) ::
          {:ok, String.t()} | {:error, term()}
  def build_image(element, %RenderContext{} = context, options \\ []) do
    src = Map.get(element, :src, "")
    alt = Map.get(element, :alt, "")

    position_style = build_position_style(element, context)
    image_style = build_image_style(element)

    attributes = build_html_attributes(element, options)

    if src == "" do
      {:error, :missing_image_src}
    else
      html =
        """
        <img class="ash-element ash-element-image"#{attributes} src="#{src}" alt="#{alt}" style="#{position_style}#{image_style}">
        """
        |> String.trim()

      {:ok, html}
    end
  end

  # Private implementation functions

  defp build_element_by_type(:label, element, context, options) do
    build_label(element, context, options)
  end

  defp build_element_by_type(:field, element, context, options) do
    build_field(element, context, options)
  end

  defp build_element_by_type(:line, element, context, options) do
    build_line(element, context, options)
  end

  defp build_element_by_type(:box, element, context, options) do
    build_box(element, context, options)
  end

  defp build_element_by_type(:image, element, context, options) do
    build_image(element, context, options)
  end

  defp build_element_by_type(:aggregate, element, context, options) do
    # Aggregate elements are treated as fields with calculated values
    build_field(element, context, options)
  end

  defp build_element_by_type(:expression, element, context, options) do
    # Expression elements are treated as fields with calculated values
    build_field(element, context, options)
  end

  defp build_element_by_type(element_type, _element, _context, _options) do
    {:error, {:unsupported_element_type, element_type}}
  end

  defp resolve_element_text(element, %RenderContext{} = context) do
    case Map.get(element, :text) do
      nil ->
        # Try to get text from expression
        case resolve_field_value(element, context) do
          {:ok, value} -> to_string(value)
          {:error, _} -> ""
        end

      text when is_binary(text) ->
        text

      text ->
        to_string(text)
    end
  end

  defp resolve_field_value(element, %RenderContext{} = context) do
    case Map.get(element, :expression) do
      nil ->
        # Try to get value from data field
        field_name = Map.get(element, :field)

        if field_name do
          value = RenderContext.get_current_record(context, field_name, "")
          {:ok, value}
        else
          {:ok, ""}
        end

      expression ->
        # Use CalculationEngine to evaluate expression
        case CalculationEngine.evaluate(expression, context) do
          {:ok, value} -> {:ok, value}
          {:error, _reason} = error -> error
        end
    end
  end

  defp format_field_value(value, element, %RenderContext{} = context) do
    # Check for new format specification options first
    cond do
      format_spec = Map.get(element, :format_spec) ->
        format_with_specification(value, format_spec, element, context)

      custom_pattern = Map.get(element, :custom_pattern) ->
        format_with_custom_pattern(value, custom_pattern, element, context)

      conditional_format = Map.get(element, :conditional_format) ->
        format_with_conditional_rules(value, conditional_format, element, context)

      true ->
        # Fallback to existing format logic
        format_with_legacy_format(value, element, context)
    end
  end

  # New format specification support functions

  defp format_with_specification(value, format_spec, _element, context) do
    locale = get_locale_from_context(context)

    case AshReports.Formatter.format_with_spec(value, format_spec, locale) do
      {:ok, formatted} ->
        {:ok, formatted}

      {:error, _reason} ->
        # Log warning and fallback to string representation
        {:ok, to_string(value)}
    end
  end

  defp format_with_custom_pattern(value, custom_pattern, _element, context) do
    locale = get_locale_from_context(context)

    case AshReports.Formatter.format_with_custom_pattern(value, custom_pattern, locale) do
      {:ok, formatted} ->
        {:ok, formatted}

      {:error, _reason} ->
        # Log warning and fallback to string representation
        {:ok, to_string(value)}
    end
  end

  defp format_with_conditional_rules(value, conditional_format, element, context) do
    # Convert conditional format rules to format specification conditions
    conditions =
      Enum.map(conditional_format, fn {condition, options} ->
        {condition, options}
      end)

    # Create a temporary format specification with conditions
    spec = AshReports.FormatSpecification.new(:temp_conditional, conditions: conditions)

    case AshReports.FormatSpecification.compile(spec) do
      {:ok, compiled_spec} ->
        apply_compiled_conditional_format(value, compiled_spec, element, context)

      {:error, _reason} ->
        {:ok, to_string(value)}
    end
  end

  defp format_with_legacy_format(value, element, _context) do
    format = Map.get(element, :format)

    formatted_value =
      case format do
        nil ->
          to_string(value)

        :currency ->
          format_currency(value)

        :date ->
          format_date(value)

        :number ->
          format_number(value)

        custom_format when is_binary(custom_format) ->
          apply_custom_format(value, custom_format)

        _ ->
          to_string(value)
      end

    {:ok, formatted_value}
  end

  defp get_locale_from_context(%RenderContext{} = context) do
    # Extract locale from context options or use default
    context
    |> Map.get(:options, %{})
    |> Map.get(:locale, AshReports.Cldr.current_locale())
  end

  defp format_currency(value) when is_number(value) do
    # Simple currency formatting - in real app would use proper money library
    "$#{:erlang.float_to_binary(value / 1.0, decimals: 2)}"
  end

  defp format_currency(value), do: to_string(value)

  defp format_date(%Date{} = date) do
    Date.to_string(date)
  end

  defp format_date(%DateTime{} = datetime) do
    DateTime.to_string(datetime)
  end

  defp format_date(value), do: to_string(value)

  defp format_number(value) when is_number(value) do
    # Simple number formatting
    if is_float(value) do
      :erlang.float_to_binary(value, decimals: 2)
    else
      to_string(value)
    end
  end

  defp format_number(value), do: to_string(value)

  defp apply_custom_format(value, format_string) do
    # Simple format string replacement - in real app would be more sophisticated
    format_string
    |> String.replace("{value}", to_string(value))
  end

  defp build_position_style(element, %RenderContext{} = context) do
    position = case Map.get(element, :position, %{}) do
      pos when is_map(pos) -> pos
      _ -> %{}  # Handle case where position is not a map (like empty list [])
    end

    # Try to get position from layout state if not in element
    layout_position = get_element_layout_position(element, context)
    final_position = Map.merge(layout_position, position)

    x = Map.get(final_position, :x, 0)
    y = Map.get(final_position, :y, 0)
    width = Map.get(final_position, :width)
    height = Map.get(final_position, :height)

    style_parts = [
      "position: absolute",
      "left: #{x}px",
      "top: #{y}px"
    ]

    style_parts =
      if width do
        ["width: #{width}px" | style_parts]
      else
        style_parts
      end

    style_parts =
      if height do
        ["height: #{height}px" | style_parts]
      else
        style_parts
      end

    Enum.join(style_parts, "; ") <> "; "
  end

  defp get_element_layout_position(element, %RenderContext{} = context) do
    element_name = Map.get(element, :name)

    if element_name do
      find_element_in_layout(context.layout_state.bands, element_name)
    else
      %{}
    end
  end

  defp find_element_in_layout(bands, element_name) do
    bands
    |> Enum.find_value(&find_element_in_band(&1, element_name))
    |> convert_element_layout_to_position()
  end

  defp find_element_in_band({_band_name, band_layout}, element_name) do
    Enum.find(band_layout.elements, fn element_layout ->
      element_layout.element.name == element_name
    end)
  end

  defp convert_element_layout_to_position(nil), do: %{}

  defp convert_element_layout_to_position(element_layout) do
    %{
      x: element_layout.position.x,
      y: element_layout.position.y,
      width: element_layout.dimensions.width,
      height: element_layout.dimensions.height
    }
  end

  defp build_font_style(element) do
    font_weight = Map.get(element, :font_weight, "normal")
    font_size = Map.get(element, :font_size)
    color = Map.get(element, :color)

    style_parts = ["font-weight: #{font_weight}"]

    style_parts =
      if font_size do
        ["font-size: #{font_size}" | style_parts]
      else
        style_parts
      end

    style_parts =
      if color do
        ["color: #{color}" | style_parts]
      else
        style_parts
      end

    Enum.join(style_parts, "; ") <> "; "
  end

  defp build_field_style(element) do
    border = Map.get(element, :border)
    background = Map.get(element, :background)
    padding = Map.get(element, :padding, "4px")

    style_parts = ["padding: #{padding}"]

    style_parts =
      if border do
        ["border: #{border}" | style_parts]
      else
        style_parts
      end

    style_parts =
      if background do
        ["background-color: #{background}" | style_parts]
      else
        style_parts
      end

    Enum.join(style_parts, "; ") <> "; "
  end

  defp build_line_style(element, orientation) do
    color = Map.get(element, :color, "#000")
    width = Map.get(element, :width, 1)
    length = Map.get(element, :length, 100)

    case orientation do
      :horizontal ->
        "border-top: #{width}px solid #{color}; width: #{length}px; height: 0; "

      :vertical ->
        "border-left: #{width}px solid #{color}; height: #{length}px; width: 0; "
    end
  end

  defp build_box_style(element) do
    border = Map.get(element, :border, "1px solid #ccc")
    background = Map.get(element, :background, "transparent")
    padding = Map.get(element, :padding, "8px")

    "border: #{border}; background-color: #{background}; padding: #{padding}; "
  end

  defp build_image_style(element) do
    max_width = Map.get(element, :max_width, "100%")
    max_height = Map.get(element, :max_height, "auto")

    "max-width: #{max_width}; max-height: #{max_height}; "
  end

  defp build_css_classes(element_type, element) do
    base_classes = ["ash-element", "ash-element-#{element_type}"]

    custom_classes = Map.get(element, :css_classes, [])

    base_classes ++ custom_classes
  end

  defp build_attributes(element, options) do
    base_attributes = %{}

    # Add data attributes if enabled
    base_attributes =
      if Keyword.get(options, :include_data_attributes, true) do
        data_attrs = build_data_attributes(element)
        Map.merge(base_attributes, data_attrs)
      else
        base_attributes
      end

    # Add accessibility attributes if enabled
    base_attributes =
      if Keyword.get(options, :accessibility, true) do
        aria_attrs = build_aria_attributes(element)
        Map.merge(base_attributes, aria_attrs)
      else
        base_attributes
      end

    # Add custom attributes from element
    custom_attrs = Map.get(element, :attributes, %{})
    Map.merge(base_attributes, custom_attrs)
  end

  defp build_html_attributes(element, options) do
    attributes = build_attributes(element, options)

    attributes
    |> Enum.map(fn {key, value} ->
      " #{key}=\"#{value}\""
    end)
    |> Enum.join("")
  end

  defp build_data_attributes(element) do
    data_attrs = %{}

    data_attrs =
      if element_name = Map.get(element, :name) do
        Map.put(data_attrs, "data-element", element_name)
      else
        data_attrs
      end

    data_attrs =
      if field_name = Map.get(element, :field) do
        Map.put(data_attrs, "data-field", field_name)
      else
        data_attrs
      end

    data_attrs
  end

  defp build_field_data_attributes(element) do
    field_name = Map.get(element, :field)
    expression = Map.get(element, :expression)

    attrs = []

    attrs =
      if field_name do
        [" data-field=\"#{field_name}\"" | attrs]
      else
        attrs
      end

    attrs =
      if expression do
        [" data-expression=\"#{expression}\"" | attrs]
      else
        attrs
      end

    Enum.join(attrs, "")
  end

  defp build_aria_attributes(element) do
    aria_attrs = %{}

    aria_attrs =
      if alt_text = Map.get(element, :alt) do
        Map.put(aria_attrs, "aria-label", alt_text)
      else
        aria_attrs
      end

    aria_attrs =
      if Map.get(element, :type) == :image and not Map.has_key?(element, :alt) do
        Map.put(aria_attrs, "role", "img")
      else
        aria_attrs
      end

    aria_attrs
  end

  defp maybe_escape_html(text, options) do
    if Keyword.get(options, :escape_html, true) do
      escape_html(text)
    else
      text
    end
  end

  defp build_single_element(element, context, options, band_name) do
    case build_element(element, context, options) do
      {:ok, element_html} ->
        Map.put(element_html, :band_name, band_name)

      {:error, reason} ->
        # Log error but continue with other elements
        {:error, reason}
    end
  end

  defp filter_successful_elements(result) do
    case result do
      {:error, _} -> false
      _ -> true
    end
  end

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp escape_html(text), do: to_string(text) |> escape_html()

  defp apply_compiled_conditional_format(value, compiled_spec, element, context) do
    locale = get_locale_from_context(context)
    format_context = %{locale: locale, element: element}

    case AshReports.FormatSpecification.get_effective_format(compiled_spec, value, format_context) do
      {:ok, {pattern, options}} ->
        format_with_pattern_and_options(value, pattern, locale, options)

      {:error, _reason} ->
        {:ok, to_string(value)}
    end
  end

  defp format_with_pattern_and_options(value, pattern, locale, options) do
    case AshReports.Formatter.format_with_custom_pattern(value, pattern, locale, options) do
      {:ok, formatted} -> {:ok, formatted}
      {:error, _reason} -> {:ok, to_string(value)}
    end
  end
end
