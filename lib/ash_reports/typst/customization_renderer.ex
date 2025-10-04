defmodule AshReports.Typst.CustomizationRenderer do
  @moduledoc """
  Renders customization configuration as Typst styling code.

  Converts AshReports.Customization.Config into Typst `set` rules for:
  - Typography (font family, sizes)
  - Colors (theme colors applied to elements)
  - Page layout adjustments

  ## Usage

      customization = Config.new(theme_id: :corporate, brand_colors: %{primary: "#1e3a8a"})
      typst_styles = CustomizationRenderer.render_styles(customization)
  """

  alias AshReports.Customization.Config

  @doc """
  Generates Typst styling code from customization configuration.

  Returns a string of Typst `set` rules that apply the customization theme,
  colors, and typography to the report.

  ## Parameters

    * `customization` - AshReports.Customization.Config struct, or nil

  ## Returns

  String of Typst code to insert into the template for styling.

  ## Examples

      iex> config = Config.new(theme_id: :corporate)
      iex> CustomizationRenderer.render_styles(config)
      "  // Theme: Corporate\\n  set text(\\n    font: \\"Inter, system-ui, sans-serif\\",\\n    ..."

  """
  @spec render_styles(Config.t() | nil) :: String.t()
  def render_styles(nil), do: ""

  def render_styles(%Config{} = customization) do
    effective_theme = Config.get_effective_theme(customization)

    if effective_theme do
      """
        // Theme: #{effective_theme.name}
        #{render_typography(effective_theme)}
        #{render_colors(effective_theme)}
      """
      |> String.trim()
    else
      ""
    end
  end

  @doc """
  Renders typography settings as Typst `set text()` rules.
  """
  @spec render_typography(map()) :: String.t()
  def render_typography(theme) do
    typography = theme.typography

    """
      set text(
        font: "#{typography.font_family}",
        size: #{typography.body_size}
      )

      // Heading styles
      set heading(numbering: none)
      show heading.where(level: 1): it => text(
        size: #{typography.heading_size},
        weight: "bold",
        fill: rgb("#{theme.colors.primary}"),
        it.body
      )
    """
    |> String.trim()
  end

  @doc """
  Renders color scheme as Typst color definitions.

  Creates color variables that can be referenced throughout the template.
  """
  @spec render_colors(map()) :: String.t()
  def render_colors(theme) do
    colors = theme.colors

    """
      // Theme colors
      #let primary-color = rgb("#{colors.primary}")
      #let secondary-color = rgb("#{colors.secondary}")
      #let accent-color = rgb("#{colors.accent}")
      #let text-color = rgb("#{colors.text}")
      #let border-color = rgb("#{colors.border}")
    """
    |> String.trim()
  end

  @doc """
  Renders table styling based on theme.
  """
  @spec render_table_styles(map()) :: String.t()
  def render_table_styles(theme) do
    styles = theme.styles

    """
      // Table styling
      set table(
        stroke: (paint: rgb("#{styles.table_border}"), thickness: 0.5pt),
        fill: (x, y) => if y == 0 { rgb("#{styles.table_header_bg}") }
      )

      set table.cell(inset: 8pt)
    """
    |> String.trim()
  end

  @doc """
  Generates page setup with customization applied.

  This replaces the default page setup with theme-aware styling.
  """
  @spec render_page_setup(map(), map()) :: String.t()
  def render_page_setup(report, customization) do
    effective_theme = Config.get_effective_theme(customization)

    base_setup = """
      // Page configuration
      set page(
        paper: "a4",
        margin: (x: 2cm, y: 2cm),
        footer: [Page #counter(page).display() of #counter(page).final().at(0)]
      )

      // Document properties
      set document(
        title: "#{report.title || report.name}",
        author: "AshReports"
      )
    """

    if effective_theme do
      """
      #{base_setup}

      #{render_typography(effective_theme)}

      #{render_colors(effective_theme)}

      #{render_table_styles(effective_theme)}
      """
      |> String.trim()
    else
      """
      #{base_setup}

      // Default text formatting
      set text(
        font: "Liberation Serif",
        size: 11pt
      )
      """
      |> String.trim()
    end
  end
end
