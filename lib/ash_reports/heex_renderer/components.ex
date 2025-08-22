defmodule AshReports.HeexRenderer.Components do
  @moduledoc """
  Phoenix Component library for AshReports HEEX rendering.

  This module provides a comprehensive set of Phoenix components for rendering
  AshReports in HEEX templates with full LiveView compatibility and interactive
  features.

  ## Component Categories

  - **Container Components**: Report layout and structure
  - **Band Components**: Different band types (header, detail, footer)
  - **Element Components**: Individual report elements (label, field, etc.)
  - **Interactive Components**: User interaction and real-time updates
  - **Layout Components**: Positioning and responsive design

  ## Usage

  Components can be used directly in HEEX templates:

      <.report_container report={@report}>
        <.band :for={band <- @report.bands} band={band} records={@records}>
          <.element :for={element <- band.elements} element={element} />
        </.band>
      </.report_container>

  Or programmatically through the render functions:

      {:ok, heex} = Components.render_single_component(:report_header, assigns, context)

  """

  use Phoenix.Component

  alias AshReports.{Band, Report}
  alias AshReports.Element.{Aggregate, Box, Expression, Field, Image, Label, Line}

  # Container Components

  @doc """
  Main report container component that wraps the entire report.

  ## Attributes

  - `report` (required) - The report struct
  - `config` - Render configuration
  - `class` - Additional CSS classes
  - `data_report` - Data attribute for the report name

  ## Examples

      <.report_container report={@report} class="custom-report">
        <%= render_slot(@inner_block) %>
      </.report_container>

  """
  attr(:report, Report, required: true, doc: "The report struct")
  attr(:config, :map, default: %{}, doc: "Render configuration")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:data_report, :string, default: nil, doc: "Data attribute for report name")
  attr(:rest, :global, doc: "Additional HTML attributes")

  slot(:inner_block, required: true, doc: "Report content")

  def report_container(assigns) do
    assigns =
      assigns
      |> assign_new(:data_report, fn -> assigns.report.name end)
      |> assign(:base_classes, "ash-report-container")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <div
      class={@final_classes}
      data-report={@data_report}
      data-format="heex"
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Report header component for displaying report metadata and title.

  ## Attributes

  - `title` (required) - Report title
  - `metadata` - Additional metadata to display
  - `show_timestamp` - Whether to show generation timestamp
  - `class` - Additional CSS classes

  """
  attr(:title, :string, required: true, doc: "Report title")
  attr(:metadata, :map, default: %{}, doc: "Additional metadata")
  attr(:show_timestamp, :boolean, default: true, doc: "Show generation timestamp")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def report_header(assigns) do
    assigns =
      assigns
      |> assign(:base_classes, "ash-report-header")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))
      |> assign_new(:current_time, fn -> DateTime.utc_now() end)

    ~H"""
    <header class={@final_classes} {@rest}>
      <div class="ash-report-title">
        <h1><%= @title %></h1>
      </div>

      <%= if @show_timestamp do %>
        <div class="ash-report-timestamp">
          Generated: <%= format_datetime(@current_time) %>
        </div>
      <% end %>

      <%= if map_size(@metadata) > 0 do %>
        <div class="ash-report-metadata">
          <dl>
            <%= for {key, value} <- @metadata do %>
              <dt class="metadata-key">
                <%= humanize_key(key) %>:
              </dt>
              <dd class="metadata-value">
                <%= format_metadata_value(value) %>
              </dd>
            <% end %>
          </dl>
        </div>
      <% end %>
    </header>
    """
  end

  @doc """
  Report content area component that contains all bands.
  """
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  slot(:inner_block, required: true, doc: "Report bands")

  def report_content(assigns) do
    assigns =
      assigns
      |> assign(:base_classes, "ash-report-content")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <main class={@final_classes} {@rest}>
      <%= render_slot(@inner_block) %>
    </main>
    """
  end

  @doc """
  Report footer component for displaying generation info and page numbers.
  """
  attr(:timestamp, DateTime, default: nil, doc: "Generation timestamp")
  attr(:metadata, :map, default: %{}, doc: "Footer metadata")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def report_footer(assigns) do
    assigns =
      assigns
      |> assign_new(:timestamp, fn -> DateTime.utc_now() end)
      |> assign(:base_classes, "ash-report-footer")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <footer class={@final_classes} {@rest}>
      <div class="ash-footer-content">
        <div class="ash-footer-timestamp">
          Generated by AshReports at <%= format_datetime(@timestamp) %>
        </div>

        <%= if map_size(@metadata) > 0 do %>
          <div class="ash-footer-metadata">
            <%= for {key, value} <- @metadata do %>
              <span class="metadata-item">
                <%= humanize_key(key) %>: <%= format_metadata_value(value) %>
              </span>
            <% end %>
          </div>
        <% end %>
      </div>
    </footer>
    """
  end

  # Band Components

  @doc """
  Band group component that manages a collection of bands.
  """
  attr(:band, Band, required: true, doc: "Band definition")
  attr(:records, :list, required: true, doc: "Data records")
  attr(:variables, :map, default: %{}, doc: "Variable values")
  attr(:layout_state, :map, default: %{}, doc: "Layout state")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  slot(:inner_block, required: true, doc: "Band content")

  def band_group(assigns) do
    assigns =
      assigns
      |> assign(:base_classes, "ash-band-group")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <div
      class={@final_classes}
      data-band-group={@band.name}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Individual band component for rendering a single report band.

  ## Attributes

  - `band` (required) - Band definition
  - `current_record` - Current record being processed
  - `class` - Additional CSS classes
  - `data_band` - Data attribute for band name

  """
  attr(:band, Band, required: true, doc: "Band definition")
  attr(:current_record, :map, default: nil, doc: "Current record")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:data_band, :string, default: nil, doc: "Data attribute for band name")
  attr(:rest, :global, doc: "Additional HTML attributes")

  slot(:inner_block, required: true, doc: "Band elements")

  def band(assigns) do
    assigns =
      assigns
      |> assign_new(:data_band, fn -> assigns.band.name end)
      |> assign(:base_classes, band_classes(assigns.band))
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <section
      class={@final_classes}
      data-band={@data_band}
      data-band-type={@band.type}
      style={band_styles(@band)}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </section>
    """
  end

  # Element Components

  @doc """
  Universal element component that renders different element types.

  ## Attributes

  - `element` (required) - Element definition
  - `record` - Current record for data binding
  - `variables` - Variable values
  - `class` - Additional CSS classes
  - `data_element` - Data attribute for element name

  """
  attr(:element, :map, required: true, doc: "Element definition")
  attr(:record, :map, default: nil, doc: "Current record")
  attr(:variables, :map, default: %{}, doc: "Variable values")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:data_element, :string, default: nil, doc: "Data attribute for element name")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def element(assigns) do
    assigns =
      assigns
      |> assign_new(:data_element, fn -> assigns.element.name end)
      |> assign(
        :element_value,
        resolve_element_value(assigns.element, assigns.record, assigns.variables)
      )
      |> assign(:base_classes, element_classes(assigns.element))
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <div
      class={@final_classes}
      data-element={@data_element}
      data-element-type={element_type(@element)}
      style={element_styles(@element)}
      {@rest}
    >
      <%= render_element_content(@element, @element_value, assigns) %>
    </div>
    """
  end

  @doc """
  Label element component for static text display.
  """
  attr(:element, Label, required: true, doc: "Label element definition")
  attr(:value, :string, default: nil, doc: "Label text value")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def label_element(assigns) do
    assigns =
      assigns
      |> assign_new(:value, fn -> assigns.element.text || assigns.element.name end)
      |> assign(:base_classes, "ash-element-label")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <span class={@final_classes} {@rest}>
      <%= @value %>
    </span>
    """
  end

  @doc """
  Field element component for data field display.
  """
  attr(:element, Field, required: true, doc: "Field element definition")
  attr(:value, :any, default: nil, doc: "Field value")
  attr(:record, :map, default: nil, doc: "Current record")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def field_element(assigns) do
    assigns =
      assigns
      |> assign(:formatted_value, format_field_value(assigns.value, assigns.element))
      |> assign(:base_classes, "ash-element-field")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <span class={@final_classes} data-field={@element.source} {@rest}>
      <%= @formatted_value %>
    </span>
    """
  end

  @doc """
  Image element component for image display.
  """
  attr(:element, Image, required: true, doc: "Image element definition")
  attr(:src, :string, required: true, doc: "Image source URL")
  attr(:alt, :string, default: "", doc: "Alternative text")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def image_element(assigns) do
    assigns =
      assigns
      |> assign_new(:alt, fn -> "Report image" end)
      |> assign(:base_classes, "ash-element-image")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <img
      src={@src}
      alt={@alt}
      class={@final_classes}
      style={image_styles(@element)}
      {@rest}
    />
    """
  end

  @doc """
  Line element component for drawing lines and borders.
  """
  attr(:element, Line, required: true, doc: "Line element definition")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def line_element(assigns) do
    assigns =
      assigns
      |> assign(:base_classes, "ash-element-line")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <hr
      class={@final_classes}
      style={line_styles(@element)}
      {@rest}
    />
    """
  end

  @doc """
  Box element component for rectangular containers.
  """
  attr(:element, Box, required: true, doc: "Box element definition")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  slot(:inner_block, doc: "Box content")

  def box_element(assigns) do
    assigns =
      assigns
      |> assign(:base_classes, "ash-element-box")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <div
      class={@final_classes}
      style={box_styles(@element)}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Aggregate element component for calculated values.
  """
  attr(:element, Aggregate, required: true, doc: "Aggregate element definition")
  attr(:value, :any, required: true, doc: "Calculated value")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def aggregate_element(assigns) do
    assigns =
      assigns
      |> assign(:formatted_value, format_aggregate_value(assigns.value, assigns.element))
      |> assign(:base_classes, "ash-element-aggregate")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <span
      class={@final_classes}
      data-aggregate={@element.function}
      {@rest}
    >
      <%= @formatted_value %>
    </span>
    """
  end

  @doc """
  Expression element component for calculated expressions.
  """
  attr(:element, Expression, required: true, doc: "Expression element definition")
  attr(:value, :any, required: true, doc: "Expression result")
  attr(:class, :string, default: "", doc: "Additional CSS classes")
  attr(:rest, :global, doc: "Additional HTML attributes")

  def expression_element(assigns) do
    assigns =
      assigns
      |> assign(:formatted_value, format_expression_value(assigns.value, assigns.element))
      |> assign(:base_classes, "ash-element-expression")
      |> assign(:final_classes, build_classes([assigns.base_classes, assigns.class]))

    ~H"""
    <span
      class={@final_classes}
      data-expression={@element.expression}
      {@rest}
    >
      <%= @formatted_value %>
    </span>
    """
  end

  # Public API Functions

  @doc """
  Renders a single component programmatically.

  ## Examples

      {:ok, heex} = Components.render_single_component(:report_header, assigns, context)

  """
  @spec render_single_component(atom(), map(), map()) :: {:ok, String.t()} | {:error, term()}
  def render_single_component(component_type, assigns, _context) do
    case get_component_renderer(component_type) do
      {:ok, renderer} -> {:ok, render_to_string(renderer, assigns)}
      error -> error
    end
  rescue
    error -> {:error, error}
  end

  defp get_component_renderer(component_type) do
    case component_type do
      :report_container -> {:ok, &report_container/1}
      :report_header -> {:ok, &report_header/1}
      :report_content -> {:ok, &report_content/1}
      :report_footer -> {:ok, &report_footer/1}
      :band_group -> {:ok, &band_group/1}
      :band -> {:ok, &band/1}
      :element -> {:ok, &element/1}
      _ -> {:error, {:unknown_component, component_type}}
    end
  end

  @doc """
  Cleans up component cache and temporary resources.
  """
  @spec cleanup_component_cache() :: :ok
  def cleanup_component_cache do
    # Implementation would clean up any cached component data
    :ok
  end

  # Private helper functions

  defp build_classes(class_list) do
    class_list
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp band_classes(band) do
    base = "ash-band"
    type_class = "ash-band-#{band.type}"
    [base, type_class]
  end

  defp band_styles(band) do
    styles = []

    styles =
      if band.height do
        ["height: #{band.height}px" | styles]
      else
        styles
      end

    styles =
      if band.background_color do
        ["background-color: #{band.background_color}" | styles]
      else
        styles
      end

    Enum.join(styles, "; ")
  end

  defp element_classes(element) do
    base = "ash-element"
    type_class = "ash-element-#{element_type(element)}"
    [base, type_class]
  end

  defp element_styles(element) do
    position = element.position || %{}
    style = element.style || %{}

    []
    |> add_position_styles(position)
    |> add_dimension_styles(position)
    |> add_appearance_styles(style)
    |> Enum.join("; ")
  end

  defp add_position_styles(styles, position) do
    if position[:x] && position[:y] do
      ["position: absolute", "left: #{position[:x]}px", "top: #{position[:y]}px" | styles]
    else
      styles
    end
  end

  defp add_dimension_styles(styles, position) do
    styles = if position[:width], do: ["width: #{position[:width]}px" | styles], else: styles
    if position[:height], do: ["height: #{position[:height]}px" | styles], else: styles
  end

  defp add_appearance_styles(styles, style) do
    styles = if style[:color], do: ["color: #{style[:color]}" | styles], else: styles

    styles =
      if style[:background_color],
        do: ["background-color: #{style[:background_color]}" | styles],
        else: styles

    if style[:font_size], do: ["font-size: #{style[:font_size]}px" | styles], else: styles
  end

  defp element_type(%Label{}), do: "label"
  defp element_type(%Field{}), do: "field"
  defp element_type(%Image{}), do: "image"
  defp element_type(%Line{}), do: "line"
  defp element_type(%Box{}), do: "box"
  defp element_type(%Aggregate{}), do: "aggregate"
  defp element_type(%Expression{}), do: "expression"
  defp element_type(_), do: "unknown"

  defp resolve_element_value(element, record, variables) do
    case element do
      %Label{text: text} -> text || element.name
      %Field{source: source} -> get_field_value(record, source)
      %Aggregate{} -> calculate_aggregate_value(element, record, variables)
      %Expression{} -> evaluate_expression(element, record, variables)
      _ -> nil
    end
  end

  defp get_field_value(nil, _field), do: nil
  defp get_field_value(record, field) when is_map(record), do: Map.get(record, field)
  defp get_field_value(_record, _field), do: nil

  defp calculate_aggregate_value(_element, _record, _variables) do
    # Placeholder for aggregate calculation
    0
  end

  defp evaluate_expression(_element, _record, _variables) do
    # Placeholder for expression evaluation
    ""
  end

  defp render_element_content(element, value, assigns) do
    case element do
      %Label{} -> label_element(Map.put(assigns, :value, value))
      %Field{} -> field_element(Map.put(assigns, :value, value))
      %Image{source: source} -> image_element(Map.put(assigns, :src, source))
      %Line{} -> line_element(assigns)
      %Box{} -> box_element(assigns)
      %Aggregate{} -> aggregate_element(Map.put(assigns, :value, value))
      %Expression{} -> expression_element(Map.put(assigns, :value, value))
      _ -> ""
    end
  end

  defp format_field_value(nil, _element), do: ""

  defp format_field_value(value, %Field{format: format}) when not is_nil(format) do
    apply_field_format(value, format)
  end

  defp format_field_value(value, _element), do: to_string(value)

  defp apply_field_format(value, format) do
    # Placeholder for field formatting
    case format do
      :currency -> "$#{value}"
      :percentage -> "#{value}%"
      :date -> format_date(value)
      _ -> to_string(value)
    end
  end

  defp format_aggregate_value(value, _element), do: to_string(value)
  defp format_expression_value(value, _element), do: to_string(value)

  defp image_styles(element) do
    styles = element_styles(element)
    style = element.style || %{}

    additional =
      if style[:scale] do
        "transform: scale(#{style[:scale]})"
      else
        ""
      end

    [styles, additional]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp line_styles(element) do
    styles = element_styles(element)
    style_map = element.style || %{}

    additional = []

    additional =
      if element.thickness do
        ["border-width: #{element.thickness}px" | additional]
      else
        additional
      end

    additional =
      if style_map[:color] do
        ["border-color: #{style_map[:color]}" | additional]
      else
        additional
      end

    additional =
      if style_map[:border_style] do
        ["border-style: #{style_map[:border_style]}" | additional]
      else
        ["border-style: solid" | additional]
      end

    [styles | additional]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp box_styles(element) do
    styles = element_styles(element)
    border = element.border || %{}
    fill = element.fill || %{}

    additional = []

    additional =
      if border[:width] do
        ["border-width: #{border[:width]}px" | additional]
      else
        additional
      end

    additional =
      if border[:color] do
        ["border-color: #{border[:color]}" | additional]
      else
        additional
      end

    additional =
      if fill[:color] do
        ["background-color: #{fill[:color]}" | additional]
      else
        additional
      end

    [styles | additional]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_datetime(_), do: ""

  defp format_date(%Date{} = date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d")
  end

  defp format_date(_), do: ""

  defp humanize_key(key) when is_atom(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_key(key), do: to_string(key)

  defp format_metadata_value(value) when is_list(value) do
    Enum.join(value, ", ")
  end

  defp format_metadata_value(value), do: to_string(value)

  # Helper function for rendering components to string
  defp render_to_string(component_fun, assigns) do
    # This would use Phoenix.Component's internal rendering mechanism
    # For now, we'll return a placeholder
    apply(component_fun, [assigns])
  end
end
