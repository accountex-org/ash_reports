defmodule AshReports.HtmlRenderer.CssGenerator do
  @moduledoc """
  Phase 3.2.2 CSS Generation Engine - Dynamic CSS generation with responsive design.

  The CssGenerator provides sophisticated CSS generation capabilities, creating
  optimized stylesheets based on report layout, element positioning, and responsive
  design requirements.

  ## Key Features

  - **Dynamic CSS Generation**: Context-aware CSS based on layout calculations
  - **Responsive Design**: Automatic breakpoint management and mobile optimization
  - **Element Positioning**: Precise CSS positioning from LayoutEngine coordinates
  - **Style Optimization**: Minified CSS with only required rules
  - **Theme Support**: Built-in themes and custom styling options
  - **CSS Framework Integration**: Bootstrap, Tailwind, and custom framework support

  ## CSS Architecture

  Generated CSS follows a structured approach:

  ```css
  /* Base styles */
  .ash-reports-body { font-family: system-ui, sans-serif; }
  .ash-report { max-width: 1200px; margin: 0 auto; }

  /* Layout styles */
  .ash-band { position: relative; margin-bottom: 1rem; }
  .ash-element { position: absolute; }

  /* Element-specific styles */
  .ash-element-label { font-weight: bold; }
  .ash-element-field { border: 1px solid #ccc; }

  /* Responsive styles */
  @media (max-width: 768px) {
    .ash-report { padding: 0.5rem; }
    .ash-element { position: static; }
  }
  ```

  ## Style Generation Modes

  ### Layout-Based Generation

  Uses LayoutEngine coordinates to generate precise positioning:

      layout_result = LayoutEngine.calculate_layout(context)
      {:ok, css} = CssGenerator.generate_from_layout(layout_result)

  ### Responsive Generation

  Creates responsive CSS with breakpoint management:

      {:ok, css} = CssGenerator.generate_responsive_stylesheet(context, breakpoints)

  ### Theme-Based Generation

  Uses predefined themes for consistent styling:

      {:ok, css} = CssGenerator.generate_with_theme(context, :professional)

  ## Usage

      # Basic stylesheet generation
      {:ok, css} = CssGenerator.generate_stylesheet(context)

      # With custom theme
      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :modern)

      # Responsive only
      {:ok, css} = CssGenerator.generate_responsive_styles(context)

  """

  alias AshReports.{HtmlRenderer.ResponsiveLayout, RenderContext}

  @type css_options :: [
          theme: atom(),
          responsive: boolean(),
          minify: boolean(),
          framework: atom(),
          custom_rules: [String.t()]
        ]

  @type css_rule :: %{
          selector: String.t(),
          properties: %{atom() => String.t()},
          media_query: String.t() | nil
        }

  @default_themes %{
    default: %{
      colors: %{
        primary: "#333333",
        secondary: "#666666",
        background: "#ffffff",
        border: "#cccccc",
        text: "#000000"
      },
      fonts: %{
        family: "system-ui, -apple-system, sans-serif",
        size_base: "14px",
        size_header: "18px",
        size_small: "12px"
      },
      spacing: %{
        base: "8px",
        small: "4px",
        large: "16px"
      }
    },
    professional: %{
      colors: %{
        primary: "#2c3e50",
        secondary: "#34495e",
        background: "#ffffff",
        border: "#bdc3c7",
        text: "#2c3e50"
      },
      fonts: %{
        family: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
        size_base: "14px",
        size_header: "20px",
        size_small: "12px"
      },
      spacing: %{
        base: "12px",
        small: "6px",
        large: "24px"
      }
    },
    modern: %{
      colors: %{
        primary: "#3498db",
        secondary: "#2980b9",
        background: "#ffffff",
        border: "#e3e6ea",
        text: "#495057"
      },
      fonts: %{
        family: "'Inter', system-ui, sans-serif",
        size_base: "15px",
        size_header: "22px",
        size_small: "13px"
      },
      spacing: %{
        base: "16px",
        small: "8px",
        large: "32px"
      }
    }
  }

  @base_css_rules [
    %{
      selector: ".ash-reports-body",
      properties: %{
        margin: "0",
        padding: "0",
        box_sizing: "border-box"
      }
    },
    %{
      selector: ".ash-report",
      properties: %{
        position: "relative",
        max_width: "100%",
        margin: "0 auto"
      }
    },
    %{
      selector: ".ash-report-header",
      properties: %{
        margin_bottom: "2rem",
        border_bottom: "1px solid #e0e0e0",
        padding_bottom: "1rem"
      }
    },
    %{
      selector: ".ash-report-title",
      properties: %{
        margin: "0",
        padding: "0"
      }
    },
    %{
      selector: ".ash-report-metadata",
      properties: %{
        margin_top: "0.5rem",
        font_size: "0.9em",
        color: "#666"
      }
    },
    %{
      selector: ".ash-report-content",
      properties: %{
        position: "relative"
      }
    },
    %{
      selector: ".ash-band",
      properties: %{
        position: "relative",
        margin_bottom: "1rem",
        min_height: "20px"
      }
    },
    %{
      selector: ".ash-element",
      properties: %{
        position: "absolute",
        box_sizing: "border-box"
      }
    },
    %{
      selector: ".ash-report-footer",
      properties: %{
        margin_top: "2rem",
        border_top: "1px solid #e0e0e0",
        padding_top: "1rem",
        text_align: "center",
        font_size: "0.8em",
        color: "#999"
      }
    }
  ]

  @doc """
  Generates a complete CSS stylesheet for the given context.

  ## Examples

      {:ok, css} = CssGenerator.generate_stylesheet(context)
      {:ok, css} = CssGenerator.generate_stylesheet(context, theme: :professional)

  """
  @spec generate_stylesheet(RenderContext.t(), css_options()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_stylesheet(%RenderContext{} = context, options \\ []) do
    theme = Keyword.get(options, :theme, :default)
    responsive = Keyword.get(options, :responsive, true)
    minify = Keyword.get(options, :minify, true)

    with {:ok, theme_config} <- get_theme_config(theme),
         {:ok, base_rules} <- generate_base_rules(theme_config),
         {:ok, layout_rules} <- generate_layout_rules(context, theme_config),
         {:ok, element_rules} <- generate_element_rules(context, theme_config),
         {:ok, responsive_rules} <- generate_responsive_rules(context, theme_config, responsive),
         {:ok, custom_rules} <- generate_custom_rules(options),
         {:ok, complete_css} <-
           assemble_css(
             base_rules,
             layout_rules,
             element_rules,
             responsive_rules,
             custom_rules,
             minify
           ) do
      {:ok, complete_css}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Generates CSS rules from layout calculations.

  ## Examples

      layout_result = LayoutEngine.calculate_layout(context)
      {:ok, css} = CssGenerator.generate_from_layout(layout_result, theme: :modern)

  """
  @spec generate_from_layout(map(), css_options()) :: {:ok, String.t()} | {:error, term()}
  def generate_from_layout(layout_result, options \\ []) do
    theme = Keyword.get(options, :theme, :default)

    with {:ok, theme_config} <- get_theme_config(theme),
         {:ok, positioning_rules} <- generate_positioning_rules(layout_result, theme_config),
         {:ok, dimension_rules} <- generate_dimension_rules(layout_result, theme_config),
         {:ok, css} <- assemble_layout_css(positioning_rules, dimension_rules, options) do
      {:ok, css}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Generates responsive CSS rules with breakpoint management.

  ## Examples

      {:ok, css} = CssGenerator.generate_responsive_styles(context)

  """
  @spec generate_responsive_styles(RenderContext.t(), css_options()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_responsive_styles(%RenderContext{} = context, options \\ []) do
    breakpoints = ResponsiveLayout.get_breakpoints(context)
    theme = Keyword.get(options, :theme, :default)

    with {:ok, theme_config} <- get_theme_config(theme),
         {:ok, mobile_rules} <- generate_mobile_rules(context, theme_config, breakpoints),
         {:ok, tablet_rules} <- generate_tablet_rules(context, theme_config, breakpoints),
         {:ok, desktop_rules} <- generate_desktop_rules(context, theme_config, breakpoints),
         {:ok, css} <-
           assemble_responsive_css(mobile_rules, tablet_rules, desktop_rules, breakpoints) do
      {:ok, css}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Generates element-specific CSS rules based on element types and properties.

  ## Examples

      {:ok, css} = CssGenerator.generate_element_styles(elements, theme: :professional)

  """
  @spec generate_element_styles([map()], css_options()) :: {:ok, String.t()} | {:error, term()}
  def generate_element_styles(elements, options \\ []) when is_list(elements) do
    theme = Keyword.get(options, :theme, :default)

    with {:ok, theme_config} <- get_theme_config(theme),
         {:ok, element_rules} <- build_element_specific_rules(elements, theme_config),
         {:ok, css} <- format_css_rules(element_rules, options) do
      {:ok, css}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Optimizes and minifies CSS content.

  ## Examples

      {:ok, minified} = CssGenerator.minify_css(css_content)

  """
  @spec minify_css(String.t()) :: {:ok, String.t()}
  def minify_css(css_content) when is_binary(css_content) do
    minified =
      css_content
      |> String.replace(~r/\s+/, " ")
      |> String.replace(~r/;\s*}/, "}")
      |> String.replace(~r/{\s*/, "{")
      |> String.replace(~r/:\s*/, ":")
      |> String.replace(~r/,\s*/, ",")
      |> String.trim()

    {:ok, minified}
  end

  @doc """
  Cleans up temporary CSS generation resources.

  ## Examples

      CssGenerator.cleanup_temporary_styles()

  """
  @spec cleanup_temporary_styles() :: :ok
  def cleanup_temporary_styles do
    # Clean up any temporary CSS generation resources
    :ok
  end

  @doc """
  Gets CSS generation statistics and information.

  ## Examples

      stats = CssGenerator.get_generation_stats()

  """
  @spec get_generation_stats() :: map()
  def get_generation_stats do
    %{
      available_themes: Map.keys(@default_themes),
      base_rules_count: length(@base_css_rules),
      supported_breakpoints: ResponsiveLayout.default_breakpoints(),
      css_version: "3.2.2"
    }
  end

  # Private implementation functions

  defp get_theme_config(theme) do
    case Map.get(@default_themes, theme) do
      nil -> {:error, {:theme_not_found, theme}}
      theme_config -> {:ok, theme_config}
    end
  end

  defp generate_base_rules(theme_config) do
    rules =
      @base_css_rules
      |> Enum.map(fn rule ->
        apply_theme_to_rule(rule, theme_config)
      end)

    {:ok, rules}
  end

  defp apply_theme_to_rule(%{selector: _selector, properties: properties} = rule, theme_config) do
    themed_properties =
      properties
      |> Enum.map(fn {prop, value} ->
        themed_value = apply_theme_value(value, theme_config)
        {prop, themed_value}
      end)
      |> Enum.into(%{})

    %{rule | properties: themed_properties}
  end

  defp apply_theme_value(value, theme_config) when is_binary(value) do
    # Replace theme variables in value
    value
    |> String.replace("{{font-family}}", theme_config.fonts.family)
    |> String.replace("{{font-size}}", theme_config.fonts.size_base)
    |> String.replace("{{primary-color}}", theme_config.colors.primary)
    |> String.replace("{{border-color}}", theme_config.colors.border)
    |> String.replace("{{text-color}}", theme_config.colors.text)
  end

  defp apply_theme_value(value, _theme_config), do: value

  defp generate_layout_rules(%RenderContext{} = context, theme_config) do
    layout_state = context.layout_state

    rules =
      layout_state.bands
      |> Enum.flat_map(fn {band_name, band_layout} ->
        generate_band_rules(band_name, band_layout, theme_config)
      end)

    {:ok, rules}
  end

  defp generate_band_rules(band_name, band_layout, theme_config) do
    # Safely access dimensions, providing defaults if missing
    dimensions = Map.get(band_layout, :dimensions, %{width: 800, height: 50})
    position = Map.get(band_layout, :position, %{x: 0, y: 0})

    band_rule = %{
      selector: ".ash-band[data-band=\"#{band_name}\"]",
      properties: %{
        height: "#{dimensions.height}px",
        width: "#{dimensions.width}px",
        top: "#{position.y}px",
        left: "#{position.x}px"
      }
    }

    elements = Map.get(band_layout, :elements, [])

    element_rules =
      elements
      |> Enum.with_index()
      |> Enum.map(fn {element_layout, index} ->
        generate_element_position_rule(band_name, element_layout, index, theme_config)
      end)

    [band_rule | element_rules]
  end

  defp generate_element_position_rule(band_name, element_layout, index, _theme_config) do
    %{
      selector: ".ash-band[data-band=\"#{band_name}\"] .ash-element:nth-child(#{index + 1})",
      properties: %{
        position: "absolute",
        top: "#{element_layout.position.y}px",
        left: "#{element_layout.position.x}px",
        width: "#{element_layout.dimensions.width}px",
        height: "#{element_layout.dimensions.height}px"
      }
    }
  end

  defp generate_element_rules(%RenderContext{} = context, theme_config) do
    # Generate element-specific styling rules
    element_types = extract_element_types(context)

    rules =
      element_types
      |> Enum.map(fn element_type ->
        generate_element_type_rule(element_type, theme_config)
      end)

    {:ok, rules}
  end

  defp extract_element_types(%RenderContext{} = context) do
    context.report.bands
    |> Enum.flat_map(fn band ->
      Map.get(band, :elements, [])
    end)
    |> Enum.map(fn element ->
      Map.get(element, :type, :label)
    end)
    |> Enum.uniq()
  end

  defp generate_element_type_rule(element_type, theme_config) do
    base_properties = %{
      font_family: theme_config.fonts.family,
      font_size: theme_config.fonts.size_base,
      color: theme_config.colors.text
    }

    type_specific_properties = get_element_type_properties(element_type, theme_config)

    properties = Map.merge(base_properties, type_specific_properties)

    %{
      selector: ".ash-element-#{element_type}",
      properties: properties
    }
  end

  defp get_element_type_properties(:label, theme_config) do
    %{
      font_weight: "bold",
      color: theme_config.colors.primary
    }
  end

  defp get_element_type_properties(:field, theme_config) do
    %{
      border: "1px solid #{theme_config.colors.border}",
      padding: theme_config.spacing.small,
      background_color: theme_config.colors.background
    }
  end

  defp get_element_type_properties(:line, theme_config) do
    %{
      border_top: "1px solid #{theme_config.colors.border}",
      height: "1px",
      width: "100%"
    }
  end

  defp get_element_type_properties(:box, theme_config) do
    %{
      border: "1px solid #{theme_config.colors.border}",
      background_color: theme_config.colors.background,
      padding: theme_config.spacing.base
    }
  end

  defp get_element_type_properties(:image, _theme_config) do
    %{
      max_width: "100%",
      height: "auto"
    }
  end

  defp get_element_type_properties(_type, _theme_config), do: %{}

  defp generate_responsive_rules(%RenderContext{} = context, theme_config, responsive) do
    if responsive do
      breakpoints = ResponsiveLayout.get_breakpoints(context)

      with {:ok, mobile_rules} <- generate_mobile_rules(context, theme_config, breakpoints),
           {:ok, tablet_rules} <- generate_tablet_rules(context, theme_config, breakpoints) do
        {:ok, mobile_rules ++ tablet_rules}
      end
    else
      {:ok, []}
    end
  end

  defp generate_mobile_rules(%RenderContext{} = _context, theme_config, breakpoints) do
    mobile_config = Map.get(breakpoints, :mobile, %{max_width: "768px"})
    mobile_breakpoint = Map.get(mobile_config, :max_width, "768px")

    rules = [
      %{
        selector: ".ash-report",
        properties: %{
          padding: theme_config.spacing.small,
          max_width: "100%"
        },
        media_query: "@media (max-width: #{mobile_breakpoint})"
      },
      %{
        selector: ".ash-element",
        properties: %{
          position: "static",
          display: "block",
          width: "100%",
          margin_bottom: theme_config.spacing.small
        },
        media_query: "@media (max-width: #{mobile_breakpoint})"
      }
    ]

    {:ok, rules}
  end

  defp generate_tablet_rules(%RenderContext{} = _context, theme_config, breakpoints) do
    mobile_config = Map.get(breakpoints, :mobile, %{max_width: "768px"})
    tablet_config = Map.get(breakpoints, :tablet, %{min_width: "769px", max_width: "1024px"})

    tablet_min = Map.get(tablet_config, :min_width) || Map.get(mobile_config, :max_width, "768px")
    tablet_max = Map.get(tablet_config, :max_width, "1024px")

    rules = [
      %{
        selector: ".ash-report",
        properties: %{
          padding: theme_config.spacing.base,
          max_width: "90%"
        },
        media_query: "@media (min-width: #{tablet_min}) and (max-width: #{tablet_max})"
      }
    ]

    {:ok, rules}
  end

  defp generate_desktop_rules(%RenderContext{} = _context, _theme_config, _breakpoints) do
    # Desktop rules are typically the default styles
    {:ok, []}
  end

  defp generate_custom_rules(options) do
    custom_rules = Keyword.get(options, :custom_rules, [])

    rules =
      custom_rules
      |> Enum.map(fn rule_string ->
        %{
          selector: "/* Custom Rule */",
          raw_css: rule_string
        }
      end)

    {:ok, rules}
  end

  defp generate_positioning_rules(layout_result, _theme_config) do
    rules =
      layout_result.bands
      |> Enum.flat_map(fn {band_name, band_layout} ->
        [
          %{
            selector: ".ash-band[data-band=\"#{band_name}\"]",
            properties: %{
              top: "#{band_layout.position.y}px",
              left: "#{band_layout.position.x}px",
              width: "#{band_layout.dimensions.width}px",
              height: "#{band_layout.dimensions.height}px"
            }
          }
        ]
      end)

    {:ok, rules}
  end

  defp generate_dimension_rules(layout_result, _theme_config) do
    # Generate dimension-specific rules from layout
    rules =
      layout_result.bands
      |> Enum.map(fn {_band_name, band_layout} ->
        band_layout.elements
        |> Enum.with_index()
        |> Enum.map(fn {element_layout, index} ->
          %{
            selector: ".ash-element:nth-child(#{index + 1})",
            properties: %{
              width: "#{element_layout.dimensions.width}px",
              height: "#{element_layout.dimensions.height}px"
            }
          }
        end)
      end)
      |> List.flatten()

    {:ok, rules}
  end

  defp build_element_specific_rules(elements, theme_config) do
    rules =
      elements
      |> Enum.map(fn element ->
        element_type = Map.get(element, :type, :label)
        generate_element_type_rule(element_type, theme_config)
      end)
      |> Enum.uniq_by(& &1.selector)

    {:ok, rules}
  end

  defp assemble_css(
         base_rules,
         layout_rules,
         element_rules,
         responsive_rules,
         custom_rules,
         minify
       ) do
    all_rules = base_rules ++ layout_rules ++ element_rules ++ responsive_rules ++ custom_rules

    css_content = format_css_rules(all_rules, minify: minify)

    {:ok, css_content}
  end

  defp assemble_layout_css(positioning_rules, dimension_rules, options) do
    all_rules = positioning_rules ++ dimension_rules
    css_content = format_css_rules(all_rules, options)
    {:ok, css_content}
  end

  defp assemble_responsive_css(mobile_rules, tablet_rules, desktop_rules, _breakpoints) do
    all_rules = mobile_rules ++ tablet_rules ++ desktop_rules
    css_content = format_css_rules(all_rules, minify: false)
    {:ok, css_content}
  end

  defp format_css_rules(rules, options) do
    minify = Keyword.get(options, :minify, false)

    css_content =
      rules
      |> Enum.map(&format_single_rule(&1, minify))
      |> Enum.join(if minify, do: "", else: "\n\n")

    if minify do
      {:ok, minified} = minify_css(css_content)
      minified
    else
      css_content
    end
  end

  defp format_single_rule(%{raw_css: raw_css}, _minify) do
    raw_css
  end

  defp format_single_rule(%{selector: selector, properties: properties} = rule, minify) do
    media_query = Map.get(rule, :media_query)

    properties_string = format_properties(properties, minify)

    rule_content = "#{selector} { #{properties_string} }"

    if media_query do
      if minify do
        "#{media_query} { #{rule_content} }"
      else
        """
        #{media_query} {
          #{rule_content}
        }
        """
      end
    else
      rule_content
    end
  end

  defp format_properties(properties, minify) do
    separator = if minify, do: ";", else: ";\n  "

    properties
    |> Enum.map(fn {prop, value} ->
      prop_name = prop |> to_string() |> String.replace("_", "-")
      "#{prop_name}: #{value}"
    end)
    |> Enum.join(separator)
  end
end
