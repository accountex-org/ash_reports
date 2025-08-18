defmodule AshReports.HeexRenderer.Helpers do
  @moduledoc """
  HEEX template helpers for layout positioning, styling, and utility functions.

  This module provides helper functions for working with HEEX templates in
  AshReports, including CSS class generation, inline styling, responsive
  layout utilities, and data formatting.

  ## Helper Categories

  - **Layout Helpers**: Positioning, sizing, and responsive layout
  - **Style Helpers**: CSS class generation and inline styling
  - **Format Helpers**: Data formatting and display utilities
  - **Utility Helpers**: Common template operations and transformations

  ## Usage

  Helpers can be imported and used in HEEX templates:

      import AshReports.HeexRenderer.Helpers

      <div class={element_classes(element, "custom-class")}>
        <%= format_currency(amount) %>
      </div>

  Or called directly from the module:

      class_string = Helpers.build_css_classes(["base", "modifier"])

  """

  alias AshReports.{Band, Element, Report}
  alias AshReports.Element.{Aggregate, Box, Expression, Field, Image, Label, Line}

  # Layout Helpers

  @doc """
  Generates CSS classes for report elements based on their properties.

  ## Examples

      element_classes(element)
      #=> "ash-element ash-element-label position-absolute"

      element_classes(element, "custom-class")
      #=> "ash-element ash-element-label position-absolute custom-class"

  """
  @spec element_classes(Element.t(), String.t()) :: String.t()
  def element_classes(element, additional_classes \\ "") do
    base_classes = [
      "ash-element",
      "ash-element-#{element_type(element)}",
      positioning_class(element),
      sizing_class(element)
    ]

    build_css_classes(base_classes ++ [additional_classes])
  end

  @doc """
  Generates CSS classes for report bands based on their properties.

  ## Examples

      band_classes(band)
      #=> "ash-band ash-band-header layout-horizontal"

  """
  @spec band_classes(Band.t(), String.t()) :: String.t()
  def band_classes(band, additional_classes \\ "") do
    base_classes = [
      "ash-band",
      "ash-band-#{band.type}",
      layout_class(band),
      height_class(band)
    ]

    build_css_classes(base_classes ++ [additional_classes])
  end

  @doc """
  Generates CSS classes for the report container.

  ## Examples

      report_classes(report, config)
      #=> "ash-report responsive modern-theme"

  """
  @spec report_classes(Report.t(), map(), String.t()) :: String.t()
  def report_classes(_report, config \\ %{}, additional_classes \\ "") do
    base_classes = [
      "ash-report",
      theme_class(config),
      responsive_class(config),
      layout_mode_class(config)
    ]

    build_css_classes(base_classes ++ [additional_classes])
  end

  @doc """
  Builds a CSS class string from a list of classes, filtering out nil and empty values.

  ## Examples

      build_css_classes(["base", nil, "modifier", ""])
      #=> "base modifier"

  """
  @spec build_css_classes([String.t() | nil]) :: String.t()
  def build_css_classes(classes) when is_list(classes) do
    classes
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  def build_css_classes(_), do: ""

  # Style Helpers

  @doc """
  Generates inline CSS styles for elements based on their position and dimensions.

  ## Examples

      element_styles(element)
      #=> "position: absolute; left: 100px; top: 50px; width: 200px;"

  """
  @spec element_styles(Element.t()) :: String.t()
  def element_styles(element) do
    styles = []

    styles = add_position_styles(styles, element)
    styles = add_dimension_styles(styles, element)
    styles = add_appearance_styles(styles, element)

    build_style_string(styles)
  end

  @doc """
  Generates inline CSS styles for bands.

  ## Examples

      band_styles(band)
      #=> "height: 50px; background-color: #f5f5f5;"

  """
  @spec band_styles(Band.t()) :: String.t()
  def band_styles(band) do
    styles = []

    styles = if band.height do
      ["height: #{band.height}px" | styles]
    else
      styles
    end

    styles = if band.background_color do
      ["background-color: #{band.background_color}" | styles]
    else
      styles
    end

    styles = if band.padding do
      ["padding: #{band.padding}px" | styles]
    else
      styles
    end

    build_style_string(styles)
  end

  @doc """
  Builds a CSS style string from a list of style declarations.

  ## Examples

      build_style_string(["color: red", "font-size: 14px"])
      #=> "color: red; font-size: 14px;"

  """
  @spec build_style_string([String.t()]) :: String.t()
  def build_style_string(styles) when is_list(styles) do
    styles
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
    |> case do
      "" -> ""
      style_string -> style_string <> ";"
    end
  end

  def build_style_string(_), do: ""

  # Format Helpers

  @doc """
  Formats a currency value with proper symbol and precision.

  ## Examples

      format_currency(1234.56)
      #=> "$1,234.56"

      format_currency(1234.56, "€")
      #=> "€1,234.56"

  """
  @spec format_currency(number(), String.t()) :: String.t()
  def format_currency(amount, symbol \\ "$")

  def format_currency(amount, symbol) when is_number(amount) do
    formatted =
      amount
      |> :erlang.float_to_binary([{:decimals, 2}])
      |> add_thousands_separator()

    "#{symbol}#{formatted}"
  end

  def format_currency(_, _), do: ""

  @doc """
  Formats a percentage value.

  ## Examples

      format_percentage(0.1234)
      #=> "12.34%"

      format_percentage(0.1234, 1)
      #=> "12.3%"

  """
  @spec format_percentage(number(), non_neg_integer()) :: String.t()
  def format_percentage(value, precision \\ 2)

  def format_percentage(value, precision) when is_number(value) do
    percentage = value * 100
    formatted = :erlang.float_to_binary(percentage, [{:decimals, precision}])
    "#{formatted}%"
  end

  def format_percentage(_, _), do: ""

  @doc """
  Formats a date value according to the specified format.

  ## Examples

      format_date(~D[2023-12-25])
      #=> "2023-12-25"

      format_date(~D[2023-12-25], :short)
      #=> "12/25/23"

  """
  @spec format_date(Date.t() | DateTime.t() | nil, atom()) :: String.t()
  def format_date(nil, _format), do: ""

  def format_date(%Date{} = date, format) do
    case format do
      :short -> Calendar.strftime(date, "%m/%d/%y")
      :medium -> Calendar.strftime(date, "%b %d, %Y")
      :long -> Calendar.strftime(date, "%B %d, %Y")
      _ -> Calendar.strftime(date, "%Y-%m-%d")
    end
  end

  def format_date(%DateTime{} = datetime, format) do
    Date.from_iso8601!(Date.to_iso8601(DateTime.to_date(datetime)))
    |> format_date(format)
  end

  def format_date(_, _), do: ""

  @doc """
  Formats a datetime value according to the specified format.

  ## Examples

      format_datetime(~U[2023-12-25 15:30:00Z])
      #=> "2023-12-25 15:30:00 UTC"

      format_datetime(~U[2023-12-25 15:30:00Z], :short)
      #=> "12/25/23 3:30 PM"

  """
  @spec format_datetime(DateTime.t() | nil, atom()) :: String.t()
  def format_datetime(nil, _format), do: ""

  def format_datetime(%DateTime{} = datetime, format) do
    case format do
      :short -> Calendar.strftime(datetime, "%m/%d/%y %I:%M %p")
      :medium -> Calendar.strftime(datetime, "%b %d, %Y %I:%M %p")
      :long -> Calendar.strftime(datetime, "%B %d, %Y %I:%M:%S %p %Z")
      _ -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
    end
  end

  def format_datetime(_, _), do: ""

  @doc """
  Formats a number with thousands separators.

  ## Examples

      format_number(1234567)
      #=> "1,234,567"

      format_number(1234.56, 2)
      #=> "1,234.56"

  """
  @spec format_number(number(), non_neg_integer()) :: String.t()
  def format_number(number, precision \\ 0)

  def format_number(number, precision) when is_number(number) do
    if precision > 0 do
      :erlang.float_to_binary(number / 1, [{:decimals, precision}])
    else
      Integer.to_string(trunc(number))
    end
    |> add_thousands_separator()
  end

  def format_number(_, _), do: ""

  # Utility Helpers

  @doc """
  Safely retrieves a field value from a record with optional default.

  ## Examples

      get_field_value(record, :customer_name)
      #=> "John Doe"

      get_field_value(record, :missing_field, "N/A")
      #=> "N/A"

  """
  @spec get_field_value(map() | nil, atom(), term()) :: term()
  def get_field_value(record, field, default \\ nil)

  def get_field_value(nil, _field, default), do: default
  def get_field_value(record, field, default) when is_map(record) do
    Map.get(record, field, default)
  end
  def get_field_value(_, _, default), do: default

  @doc """
  Safely retrieves a nested field value from a record.

  ## Examples

      get_nested_field(record, [:customer, :address, :city])
      #=> "New York"

  """
  @spec get_nested_field(map() | nil, [atom()], term()) :: term()
  def get_nested_field(nil, _path, default), do: default
  def get_nested_field(record, [], _default), do: record
  def get_nested_field(record, [field | rest], default) when is_map(record) do
    case Map.get(record, field) do
      nil -> default
      value -> get_nested_field(value, rest, default)
    end
  end
  def get_nested_field(_, _, default), do: default

  @doc """
  Generates a unique HTML ID for an element.

  ## Examples

      element_id(element)
      #=> "ash-element-customer-name-123"

  """
  @spec element_id(Element.t()) :: String.t()
  def element_id(element) do
    base = "ash-element-#{element.name}"
    timestamp = System.system_time(:microsecond)
    "#{base}-#{timestamp}"
  end

  @doc """
  Generates a unique HTML ID for a band.

  ## Examples

      band_id(band)
      #=> "ash-band-header-456"

  """
  @spec band_id(Band.t()) :: String.t()
  def band_id(band) do
    base = "ash-band-#{band.name}"
    timestamp = System.system_time(:microsecond)
    "#{base}-#{timestamp}"
  end

  @doc """
  Determines if an element should be visible based on conditions.

  ## Examples

      element_visible?(element, record, variables)
      #=> true

  """
  @spec element_visible?(Element.t(), map(), map()) :: boolean()
  def element_visible?(element, record, variables) do
    case element.visible_when do
      nil -> true
      condition -> evaluate_visibility_condition(condition, record, variables)
    end
  end

  @doc """
  Generates responsive CSS classes based on configuration.

  ## Examples

      responsive_classes(config)
      #=> "responsive md:w-1/2 lg:w-1/3"

  """
  @spec responsive_classes(map()) :: String.t()
  def responsive_classes(config) do
    classes = []

    classes = if config[:responsive] do
      ["responsive" | classes]
    else
      classes
    end

    classes = if config[:mobile_first] do
      ["mobile-first" | classes]
    else
      classes
    end

    build_css_classes(classes)
  end

  @doc """
  Generates accessibility attributes for elements.

  ## Examples

      accessibility_attrs(element)
      #=> %{role: "text", "aria-label" => "Customer Name"}

  """
  @spec accessibility_attrs(Element.t()) :: map()
  def accessibility_attrs(element) do
    attrs = %{}

    attrs = case element_type(element) do
      "label" -> Map.put(attrs, :role, "text")
      "field" -> Map.put(attrs, :role, "text")
      "image" -> Map.put(attrs, :role, "img")
      _ -> attrs
    end

    attrs = if element.description do
      Map.put(attrs, "aria-label", element.description)
    else
      attrs
    end

    attrs
  end

  # Private helper functions

  defp element_type(%Label{}), do: "label"
  defp element_type(%Field{}), do: "field"
  defp element_type(%Image{}), do: "image"
  defp element_type(%Line{}), do: "line"
  defp element_type(%Box{}), do: "box"
  defp element_type(%Aggregate{}), do: "aggregate"
  defp element_type(%Expression{}), do: "expression"
  defp element_type(_), do: "unknown"

  defp positioning_class(element) do
    position = element.position || %{}
    if position[:x] && position[:y] do
      "position-absolute"
    else
      "position-relative"
    end
  end

  defp sizing_class(element) do
    position = element.position || %{}
    cond do
      position[:width] && position[:height] -> "sized-fixed"
      position[:width] -> "sized-width"
      position[:height] -> "sized-height"
      true -> "sized-auto"
    end
  end

  defp layout_class(band) do
    case band.layout || :horizontal do
      :horizontal -> "layout-horizontal"
      :vertical -> "layout-vertical"
      :grid -> "layout-grid"
      _ -> "layout-default"
    end
  end

  defp height_class(band) do
    if band.height do
      "height-fixed"
    else
      "height-auto"
    end
  end

  defp theme_class(config) do
    case config[:theme] do
      :modern -> "theme-modern"
      :classic -> "theme-classic"
      :minimal -> "theme-minimal"
      _ -> "theme-default"
    end
  end

  defp responsive_class(config) do
    if config[:responsive] do
      "responsive"
    else
      "fixed-layout"
    end
  end

  defp layout_mode_class(config) do
    case config[:layout_mode] do
      :fluid -> "layout-fluid"
      :fixed -> "layout-fixed"
      :hybrid -> "layout-hybrid"
      _ -> "layout-default"
    end
  end

  defp add_position_styles(styles, element) do
    position = element.position || %{}
    if position[:x] && position[:y] do
      [
        "position: absolute",
        "left: #{position[:x]}px",
        "top: #{position[:y]}px" | styles
      ]
    else
      styles
    end
  end

  defp add_dimension_styles(styles, element) do
    position = element.position || %{}
    styles = if position[:width] do
      ["width: #{position[:width]}px" | styles]
    else
      styles
    end

    if position[:height] do
      ["height: #{position[:height]}px" | styles]
    else
      styles
    end
  end

  defp add_appearance_styles(styles, element) do
    style = element.style || %{}
    styles = if style[:color] do
      ["color: #{style[:color]}" | styles]
    else
      styles
    end

    styles = if style[:background_color] do
      ["background-color: #{style[:background_color]}" | styles]
    else
      styles
    end

    if style[:font_size] do
      ["font-size: #{style[:font_size]}px" | styles]
    else
      styles
    end
  end

  defp add_thousands_separator(number_string) do
    case String.split(number_string, ".") do
      [integer_part] ->
        add_commas_to_integer(integer_part)
      [integer_part, decimal_part] ->
        "#{add_commas_to_integer(integer_part)}.#{decimal_part}"
    end
  end

  defp add_commas_to_integer(integer_string) do
    integer_string
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(3)
    |> Enum.map(&List.to_string/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp evaluate_visibility_condition(_condition, _record, _variables) do
    # Placeholder for condition evaluation
    # This would implement the actual condition logic
    true
  end
end
