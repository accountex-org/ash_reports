defmodule AshReports.Customization.Config do
  @moduledoc """
  Configuration management for report customization.

  Stores and validates customization settings including theme, branding,
  typography, and custom styles.
  """

  alias AshReports.Customization.Theme

  @type t :: %__MODULE__{
          theme_id: atom() | nil,
          theme_overrides: map(),
          logo_url: String.t() | nil,
          brand_colors: map(),
          custom_fonts: map(),
          custom_styles: String.t() | nil
        }

  defstruct theme_id: nil,
            theme_overrides: %{},
            logo_url: nil,
            brand_colors: %{},
            custom_fonts: %{},
            custom_styles: nil

  @doc """
  Creates a new customization config.

  ## Examples

      iex> Config.new()
      %Config{theme_id: nil, ...}

      iex> Config.new(theme_id: :corporate)
      %Config{theme_id: :corporate, ...}
  """
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Validates a customization config.

  Returns `{:ok, config}` if valid, or `{:error, errors}` if invalid.
  """
  def validate(%__MODULE__{} = config) do
    errors = []

    errors =
      if config.theme_id && !Theme.valid_theme?(config.theme_id) do
        [{:theme_id, "invalid theme"} | errors]
      else
        errors
      end

    errors =
      if config.logo_url && !valid_url?(config.logo_url) do
        [{:logo_url, "invalid URL format"} | errors]
      else
        errors
      end

    errors =
      if config.brand_colors != %{} && !valid_colors?(config.brand_colors) do
        [{:brand_colors, "invalid color format"} | errors]
      else
        errors
      end

    if Enum.empty?(errors) do
      {:ok, config}
    else
      {:error, Map.new(errors)}
    end
  end

  @doc """
  Sets the theme for a config.
  """
  def set_theme(%__MODULE__{} = config, theme_id) when is_atom(theme_id) do
    %{config | theme_id: theme_id}
  end

  @doc """
  Sets theme overrides.
  """
  def set_theme_overrides(%__MODULE__{} = config, overrides) when is_map(overrides) do
    %{config | theme_overrides: Map.merge(config.theme_overrides, overrides)}
  end

  @doc """
  Sets the logo URL.
  """
  def set_logo(%__MODULE__{} = config, logo_url) when is_binary(logo_url) do
    %{config | logo_url: logo_url}
  end

  @doc """
  Sets brand colors.
  """
  def set_brand_colors(%__MODULE__{} = config, colors) when is_map(colors) do
    %{config | brand_colors: Map.merge(config.brand_colors, colors)}
  end

  @doc """
  Sets custom fonts.
  """
  def set_custom_fonts(%__MODULE__{} = config, fonts) when is_map(fonts) do
    %{config | custom_fonts: Map.merge(config.custom_fonts, fonts)}
  end

  @doc """
  Sets custom styles.
  """
  def set_custom_styles(%__MODULE__{} = config, styles) when is_binary(styles) do
    %{config | custom_styles: styles}
  end

  @doc """
  Gets the effective theme with overrides applied.
  """
  def get_effective_theme(%__MODULE__{theme_id: nil}), do: nil

  def get_effective_theme(%__MODULE__{} = config) do
    case Theme.get_theme(config.theme_id) do
      nil ->
        nil

      theme ->
        theme
        |> Theme.merge_overrides(config.theme_overrides)
        |> apply_brand_colors(config.brand_colors)
    end
  end

  @doc """
  Exports config to a map for storage.
  """
  def to_map(%__MODULE__{} = config) do
    Map.from_struct(config)
  end

  @doc """
  Imports config from a map.
  """
  def from_map(map) when is_map(map) do
    struct(__MODULE__, map)
  end

  # Private Functions

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme != nil && uri.host != nil
  rescue
    _ -> false
  end

  defp valid_colors?(colors) do
    Enum.all?(colors, fn {_key, value} ->
      valid_hex_color?(value)
    end)
  end

  defp valid_hex_color?(color) when is_binary(color) do
    Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color)
  end

  defp valid_hex_color?(_), do: false

  defp apply_brand_colors(theme, brand_colors) when map_size(brand_colors) == 0, do: theme

  defp apply_brand_colors(theme, brand_colors) do
    updated_colors = Map.merge(theme.colors, brand_colors)
    %{theme | colors: updated_colors}
  end
end
