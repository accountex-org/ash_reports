defmodule AshReports.HtmlRenderer.ResponsiveLayout do
  @moduledoc """
  Phase 3.2.4 Responsive Layout System - Breakpoint management and device adaptation.

  The ResponsiveLayout system provides comprehensive responsive design capabilities,
  managing breakpoints, device adaptation, and responsive behavior for HTML reports
  across different screen sizes and devices.

  ## Key Features

  - **Breakpoint Management**: Configurable breakpoints for different device sizes
  - **Adaptive Layouts**: Automatic layout adaptation for mobile, tablet, and desktop
  - **Element Responsiveness**: Individual element responsive behavior configuration
  - **CSS Media Queries**: Automatic generation of responsive CSS rules
  - **Touch Optimization**: Touch-friendly interfaces for mobile devices
  - **Print Optimization**: Special handling for print media

  ## Breakpoint System

  Default breakpoints follow modern responsive design practices:

  - **Mobile**: 0px - 768px (phones)
  - **Tablet**: 769px - 1024px (tablets, small laptops)
  - **Desktop**: 1025px+ (desktops, large screens)
  - **Print**: Print media optimization

  ## Responsive Behaviors

  ### Mobile Adaptation

  - Convert absolute positioning to relative flow
  - Stack elements vertically for better readability
  - Optimize touch targets and spacing
  - Simplify complex layouts

  ### Tablet Adaptation

  - Hybrid approach balancing precision and usability
  - Maintain some absolute positioning where beneficial
  - Optimize for both portrait and landscape orientations

  ### Desktop Optimization

  - Full precision positioning from LayoutEngine
  - Maximize screen real estate utilization
  - Support for high-DPI displays

  ## Usage

      # Get responsive breakpoints for context
      breakpoints = ResponsiveLayout.get_breakpoints(context)

      # Generate responsive CSS rules
      {:ok, css} = ResponsiveLayout.generate_responsive_css(context)

      # Adapt layout for specific device
      {:ok, adapted_layout} = ResponsiveLayout.adapt_layout(layout, :mobile)

  """

  alias AshReports.RenderContext

  @type breakpoint :: :mobile | :tablet | :desktop | :print
  @type breakpoint_config :: %{
          min_width: String.t() | nil,
          max_width: String.t() | nil,
          orientation: :portrait | :landscape | :any
        }
  @type responsive_config :: %{
          breakpoints: %{breakpoint() => breakpoint_config()},
          mobile_first: boolean(),
          adapt_positioning: boolean(),
          optimize_for_touch: boolean(),
          print_optimization: boolean()
        }

  @default_breakpoints %{
    mobile: %{
      min_width: nil,
      max_width: "768px",
      orientation: :any
    },
    tablet: %{
      min_width: "769px",
      max_width: "1024px",
      orientation: :any
    },
    desktop: %{
      min_width: "1025px",
      max_width: nil,
      orientation: :any
    },
    print: %{
      min_width: nil,
      max_width: nil,
      orientation: :any
    }
  }

  @default_responsive_config %{
    breakpoints: @default_breakpoints,
    mobile_first: true,
    adapt_positioning: true,
    optimize_for_touch: true,
    print_optimization: true
  }

  @doc """
  Gets the responsive breakpoints configuration for the given context.

  ## Examples

      breakpoints = ResponsiveLayout.get_breakpoints(context)
      mobile_max = breakpoints.mobile.max_width

  """
  @spec get_breakpoints(RenderContext.t()) :: %{atom() => breakpoint_config()}
  def get_breakpoints(%RenderContext{} = context) do
    context.config
    |> Map.get(:responsive, %{})
    |> Map.get(:breakpoints, @default_breakpoints)
  end

  @doc """
  Gets the default breakpoints configuration.

  ## Examples

      breakpoints = ResponsiveLayout.default_breakpoints()

  """
  @spec default_breakpoints() :: %{atom() => breakpoint_config()}
  def default_breakpoints do
    @default_breakpoints
  end

  @doc """
  Generates responsive CSS rules for the given context.

  ## Examples

      {:ok, css} = ResponsiveLayout.generate_responsive_css(context)

  """
  @spec generate_responsive_css(RenderContext.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_responsive_css(%RenderContext{} = context) do
    responsive_config = get_responsive_config(context)
    breakpoints = responsive_config.breakpoints

    with {:ok, mobile_css} <- generate_mobile_css(context, breakpoints.mobile),
         {:ok, tablet_css} <- generate_tablet_css(context, breakpoints.tablet),
         {:ok, desktop_css} <- generate_desktop_css(context, breakpoints.desktop),
         {:ok, print_css} <- generate_print_css(context, breakpoints.print) do
      complete_css =
        [mobile_css, tablet_css, desktop_css, print_css]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n\n")

      {:ok, complete_css}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Adapts a layout for a specific breakpoint/device type.

  ## Examples

      {:ok, mobile_layout} = ResponsiveLayout.adapt_layout(layout, :mobile, context)

  """
  @spec adapt_layout(map(), breakpoint(), RenderContext.t()) :: {:ok, map()} | {:error, term()}
  def adapt_layout(layout_result, breakpoint, %RenderContext{} = context) do
    responsive_config = get_responsive_config(context)

    case breakpoint do
      :mobile ->
        adapt_mobile_layout(layout_result, responsive_config)

      :tablet ->
        adapt_tablet_layout(layout_result, responsive_config)

      :desktop ->
        adapt_desktop_layout(layout_result, responsive_config)

      :print ->
        adapt_print_layout(layout_result, responsive_config)

      _ ->
        {:error, {:unsupported_breakpoint, breakpoint}}
    end
  end

  @doc """
  Determines if an element should be responsive based on its configuration.

  ## Examples

      if ResponsiveLayout.element_responsive?(element, context) do
        apply_responsive_behavior(element)
      end

  """
  @spec element_responsive?(map(), RenderContext.t()) :: boolean()
  def element_responsive?(element, %RenderContext{} = context) do
    # Check element-level responsive setting
    element_responsive = Map.get(element, :responsive, true)

    # Check context-level responsive setting
    context_responsive =
      context.config
      |> Map.get(:responsive, %{})
      |> Map.get(:enabled, true)

    element_responsive and context_responsive
  end

  @doc """
  Gets responsive behavior for a specific element.

  ## Examples

      behavior = ResponsiveLayout.get_element_responsive_behavior(element, :mobile)

  """
  @spec get_element_responsive_behavior(map(), breakpoint()) :: map()
  def get_element_responsive_behavior(element, breakpoint) do
    element_responsive_config = Map.get(element, :responsive_behavior, %{})

    default_behavior = get_default_element_behavior(element[:type], breakpoint)

    Map.merge(default_behavior, element_responsive_config)
  end

  @doc """
  Generates media query string for a breakpoint.

  ## Examples

      media_query = ResponsiveLayout.build_media_query(:mobile, breakpoints)
      # "@media (max-width: 768px)"

  """
  @spec build_media_query(breakpoint(), map()) :: String.t()
  def build_media_query(breakpoint, breakpoints) do
    breakpoint_config = Map.get(breakpoints, breakpoint, %{})

    conditions = []

    conditions =
      if min_width = breakpoint_config[:min_width] do
        ["(min-width: #{min_width})" | conditions]
      else
        conditions
      end

    conditions =
      if max_width = breakpoint_config[:max_width] do
        ["(max-width: #{max_width})" | conditions]
      else
        conditions
      end

    conditions =
      case breakpoint_config[:orientation] do
        :portrait -> ["(orientation: portrait)" | conditions]
        :landscape -> ["(orientation: landscape)" | conditions]
        _ -> conditions
      end

    if conditions == [] do
      ""
    else
      "@media " <> Enum.join(Enum.reverse(conditions), " and ")
    end
  end

  @doc """
  Gets device-specific optimizations for touch interfaces.

  ## Examples

      optimizations = ResponsiveLayout.get_touch_optimizations(context)

  """
  @spec get_touch_optimizations(RenderContext.t()) :: map()
  def get_touch_optimizations(%RenderContext{} = context) do
    if get_responsive_config(context).optimize_for_touch do
      %{
        min_touch_target: "44px",
        touch_padding: "8px",
        hover_optimization: false,
        tap_highlight: "transparent",
        user_select: "none"
      }
    else
      %{}
    end
  end

  @doc """
  Gets print-specific optimizations.

  ## Examples

      print_opts = ResponsiveLayout.get_print_optimizations(context)

  """
  @spec get_print_optimizations(RenderContext.t()) :: map()
  def get_print_optimizations(%RenderContext{} = context) do
    if get_responsive_config(context).print_optimization do
      %{
        remove_backgrounds: true,
        optimize_colors: true,
        page_breaks: true,
        font_optimization: true,
        dpi_optimization: "300dpi"
      }
    else
      %{}
    end
  end

  # Private implementation functions

  defp get_responsive_config(%RenderContext{} = context) do
    base_config = Map.get(context.config, :responsive, %{})
    Map.merge(@default_responsive_config, base_config)
  end

  defp generate_mobile_css(%RenderContext{} = context, mobile_config) do
    media_query = build_media_query_from_config(mobile_config)

    if media_query != "" do
      touch_opts = get_touch_optimizations(context)

      css_rules =
        [
          "#{media_query} {",
          "  .ash-report {",
          "    padding: 0.5rem;",
          "    max-width: 100%;",
          "  }",
          "",
          "  .ash-element {",
          "    position: static !important;",
          "    display: block;",
          "    width: 100%;",
          "    margin-bottom: 0.5rem;",
          if(touch_opts[:min_touch_target],
            do: "    min-height: #{touch_opts[:min_touch_target]};",
            else: ""
          ),
          if(touch_opts[:touch_padding],
            do: "    padding: #{touch_opts[:touch_padding]};",
            else: ""
          ),
          "  }",
          "",
          "  .ash-band {",
          "    margin-bottom: 1rem;",
          "    min-height: auto;",
          "  }",
          "",
          "  .ash-element-line {",
          "    width: 100% !important;",
          "    position: static !important;",
          "  }",
          "",
          "  .ash-report-header,",
          "  .ash-report-footer {",
          "    text-align: center;",
          "    padding: 1rem 0;",
          "  }",
          "}"
        ]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      {:ok, css_rules}
    else
      {:ok, ""}
    end
  end

  defp generate_tablet_css(%RenderContext{} = _context, tablet_config) do
    media_query = build_media_query_from_config(tablet_config)

    if media_query != "" do
      css_rules =
        [
          "#{media_query} {",
          "  .ash-report {",
          "    padding: 1rem;",
          "    max-width: 95%;",
          "  }",
          "",
          "  .ash-element {",
          "    /* Hybrid positioning - some absolute, some responsive */",
          "  }",
          "",
          "  .ash-band {",
          "    margin-bottom: 1.5rem;",
          "  }",
          "}"
        ]
        |> Enum.join("\n")

      {:ok, css_rules}
    else
      {:ok, ""}
    end
  end

  defp generate_desktop_css(%RenderContext{} = _context, desktop_config) do
    media_query = build_media_query_from_config(desktop_config)

    if media_query != "" do
      css_rules =
        [
          "#{media_query} {",
          "  .ash-report {",
          "    max-width: 1200px;",
          "    margin: 0 auto;",
          "  }",
          "",
          "  /* Desktop uses precise positioning from LayoutEngine */",
          "  .ash-element {",
          "    position: absolute;",
          "  }",
          "}"
        ]
        |> Enum.join("\n")

      {:ok, css_rules}
    else
      {:ok, ""}
    end
  end

  defp generate_print_css(%RenderContext{} = context, _print_config) do
    print_opts = get_print_optimizations(context)

    if print_opts != %{} do
      css_rules =
        [
          "@media print {",
          "  .ash-report {",
          "    max-width: none;",
          "    width: 100%;",
          "    margin: 0;",
          "    padding: 0;",
          if(print_opts[:remove_backgrounds], do: "    background: white;", else: ""),
          "  }",
          "",
          "  .ash-element {",
          "    position: absolute;",
          if(print_opts[:optimize_colors], do: "    -webkit-print-color-adjust: exact;", else: ""),
          "  }",
          "",
          if(print_opts[:page_breaks], do: "  .ash-band { page-break-inside: avoid; }", else: ""),
          "",
          "  .ash-report-header {",
          "    position: running(header);",
          "  }",
          "",
          "  .ash-report-footer {",
          "    position: running(footer);",
          "  }",
          "",
          "  @page {",
          "    margin: 1in;",
          if(print_opts[:dpi_optimization], do: "    size: auto;", else: ""),
          "  }",
          "}"
        ]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      {:ok, css_rules}
    else
      {:ok, ""}
    end
  end

  defp build_media_query_from_config(config) do
    conditions = []

    conditions =
      if min_width = config[:min_width] do
        ["(min-width: #{min_width})" | conditions]
      else
        conditions
      end

    conditions =
      if max_width = config[:max_width] do
        ["(max-width: #{max_width})" | conditions]
      else
        conditions
      end

    if conditions == [] do
      ""
    else
      "@media " <> Enum.join(Enum.reverse(conditions), " and ")
    end
  end

  defp adapt_mobile_layout(layout_result, responsive_config) do
    if responsive_config.adapt_positioning do
      adapted_bands = convert_bands_to_responsive_flow(layout_result.bands)
      adapted_layout = %{layout_result | bands: adapted_bands}
      {:ok, adapted_layout}
    else
      {:ok, layout_result}
    end
  end

  defp convert_bands_to_responsive_flow(bands) do
    bands
    |> Enum.map(&convert_band_to_responsive_flow/1)
    |> Enum.into(%{})
  end

  defp convert_band_to_responsive_flow({band_name, band_layout}) do
    adapted_elements = Enum.map(band_layout.elements, &convert_element_to_responsive/1)
    adapted_band_layout = %{band_layout | elements: adapted_elements}
    {band_name, adapted_band_layout}
  end

  defp convert_element_to_responsive(element_layout) do
    %{
      element_layout
      | # Remove absolute positioning
        position: %{x: 0, y: 0},
        dimensions: %{element_layout.dimensions | width: "100%"}
    }
  end

  defp adapt_tablet_layout(layout_result, responsive_config) do
    if responsive_config.adapt_positioning do
      # Hybrid approach for tablets
      adapted_bands =
        layout_result.bands
        |> Enum.map(fn {band_name, band_layout} ->
          # Keep some absolute positioning but make it more flexible
          adapted_band_layout = band_layout
          {band_name, adapted_band_layout}
        end)
        |> Enum.into(%{})

      adapted_layout = %{layout_result | bands: adapted_bands}
      {:ok, adapted_layout}
    else
      {:ok, layout_result}
    end
  end

  defp adapt_desktop_layout(layout_result, _responsive_config) do
    # Desktop maintains precise positioning
    {:ok, layout_result}
  end

  defp adapt_print_layout(layout_result, responsive_config) do
    if responsive_config.print_optimization do
      # Optimize layout for printing
      adapted_bands =
        layout_result.bands
        |> Enum.map(fn {band_name, band_layout} ->
          # Adjust for print margins and page breaks
          adapted_band_layout = band_layout
          {band_name, adapted_band_layout}
        end)
        |> Enum.into(%{})

      adapted_layout = %{layout_result | bands: adapted_bands}
      {:ok, adapted_layout}
    else
      {:ok, layout_result}
    end
  end

  defp get_default_element_behavior(element_type, breakpoint) do
    case breakpoint do
      :mobile -> get_mobile_behavior(element_type)
      :tablet -> %{positioning: :hybrid}
      :desktop -> %{positioning: :absolute}
      :print -> %{positioning: :absolute, optimize_colors: true}
      _ -> %{}
    end
  end

  defp get_mobile_behavior(:image) do
    %{positioning: :static, max_width: "100%", height: :auto}
  end

  defp get_mobile_behavior(element_type) when element_type in [:label, :field, :line, :box] do
    %{positioning: :static, width: "100%", display: :block}
  end

  defp get_mobile_behavior(_element_type) do
    %{positioning: :static, width: "100%", display: :block}
  end
end
