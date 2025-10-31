defmodule AshReports.Charts.Theme do
  @moduledoc """
  Chart theming system for consistent visual styling.

  Provides predefined themes and utilities for applying theme-based configurations
  to charts. Themes define colors, fonts, and other visual properties.

  ## Predefined Themes

  - `:default` - Clean, modern palette suitable for general use
  - `:corporate` - Professional business theme with muted colors
  - `:minimal` - Simple black and white with minimal styling
  - `:vibrant` - Bold, saturated colors for impactful visualizations

  ## Usage

      # Get a theme configuration
      theme_config = Theme.get(:corporate)

      # Apply theme to existing config
      config = %BarChartConfig{title: "Sales"}
      themed_config = Theme.apply(config, :corporate)

      # Merge theme with custom overrides
      config = Theme.apply(base_config, :corporate, %{
        colours: ["#custom", "#colors"]
      })
  """

  # Type-specific config structs are used instead of generic Config

  @type theme_name :: :default | :corporate | :minimal | :vibrant

  @doc """
  Gets theme configuration for a given theme name.

  Returns a map of configuration values that define the theme.

  ## Parameters

    - `theme_name` - Name of the predefined theme

  ## Returns

  Map of theme configuration values

  ## Examples

      Theme.get(:corporate)
      # => %{
      #   colours: ["#2C3E50", "#34495E", "#7F8C8D", ...],
      #   font_family: "Arial, sans-serif",
      #   font_size: 12,
      #   show_grid: true
      # }
  """
  @spec get(theme_name()) :: map()
  def get(:default) do
    %{
      colours: ["#4285F4", "#EA4335", "#FBBC04", "#34A853", "#FF6D01", "#46BDC6"],
      font_family: "sans-serif",
      font_size: 12,
      show_grid: true,
      show_legend: true,
      legend_position: :right
    }
  end

  def get(:corporate) do
    %{
      colours: [
        "#2C3E50",
        "#34495E",
        "#7F8C8D",
        "#95A5A6",
        "#BDC3C7",
        "#3498DB",
        "#2980B9",
        "#1ABC9C",
        "#16A085"
      ],
      font_family: "Arial, sans-serif",
      font_size: 11,
      show_grid: true,
      show_legend: true,
      legend_position: :bottom
    }
  end

  def get(:minimal) do
    %{
      colours: [
        "#000000",
        "#333333",
        "#666666",
        "#999999",
        "#CCCCCC"
      ],
      font_family: "Helvetica, sans-serif",
      font_size: 10,
      show_grid: false,
      show_legend: false,
      legend_position: :right
    }
  end

  def get(:vibrant) do
    %{
      colours: [
        "#E74C3C",
        "#9B59B6",
        "#3498DB",
        "#1ABC9C",
        "#F39C12",
        "#E67E22",
        "#ECF0F1",
        "#95A5A6"
      ],
      font_family: "Verdana, sans-serif",
      font_size: 13,
      show_grid: true,
      show_legend: true,
      legend_position: :top
    }
  end

  @doc """
  Applies a theme to a chart configuration.

  Merges theme values with existing config, with config values taking precedence
  over theme defaults. Optionally accepts override values that take highest precedence.

  ## Parameters

    - `config` - Base Config struct
    - `theme_name` - Name of theme to apply
    - `overrides` - Optional map of values to override theme (default: %{})

  ## Returns

  Updated Config struct with theme applied

  ## Examples

      config = %Config{title: "Sales"}
      Theme.apply(config, :corporate)

      # With overrides
      Theme.apply(config, :corporate, %{colours: ["#FF0000"]})
  """
  @spec apply(map(), theme_name(), map()) :: map()
  def apply(config, theme_name, overrides \\ %{}) do
    theme_config = get(theme_name)

    config_map = if is_struct(config), do: Map.from_struct(config), else: config

    # Merge: theme defaults < user-set config < overrides
    merged_attrs =
      theme_config
      |> Map.merge(config_map)
      |> Map.merge(overrides)

    # Return merged config (as map or reconstruct struct if original was struct)
    if is_struct(config) do
      struct(config, merged_attrs)
    else
      merged_attrs
    end
  end

  @doc """
  Lists all available theme names.

  ## Returns

  List of theme name atoms

  ## Examples

      Theme.list_themes()
      # => [:default, :corporate, :minimal, :vibrant]
  """
  @spec list_themes() :: [theme_name()]
  def list_themes do
    [:default, :corporate, :minimal, :vibrant]
  end

  @doc """
  Checks if a theme exists.

  ## Parameters

    - `theme_name` - Name to check

  ## Returns

  Boolean indicating if theme exists

  ## Examples

      Theme.exists?(:corporate)
      # => true

      Theme.exists?(:unknown)
      # => false
  """
  @spec exists?(atom()) :: boolean()
  def exists?(theme_name) when theme_name in [:default, :corporate, :minimal, :vibrant], do: true
  def exists?(_), do: false
end
