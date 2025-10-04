defmodule AshReports.Customization.Theme do
  @moduledoc """
  Theme management for report customization.

  Provides predefined themes and utilities for managing report visual appearance.
  Each theme includes color palette, typography settings, and style overrides.
  """

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          description: String.t(),
          colors: map(),
          typography: map(),
          styles: map()
        }

  defstruct [:id, :name, :description, :colors, :typography, :styles]

  @themes %{
    corporate: %{
      id: :corporate,
      name: "Corporate",
      description: "Professional theme with navy blue and gray tones",
      colors: %{
        primary: "#1e3a8a",
        secondary: "#64748b",
        accent: "#3b82f6",
        background: "#ffffff",
        text: "#1e293b",
        border: "#e2e8f0"
      },
      typography: %{
        font_family: "Inter, system-ui, sans-serif",
        heading_size: "24pt",
        body_size: "11pt",
        caption_size: "9pt",
        line_height: 1.5
      },
      styles: %{
        table_header_bg: "#f1f5f9",
        table_border: "#cbd5e1",
        section_spacing: "12pt"
      }
    },
    minimal: %{
      id: :minimal,
      name: "Minimal",
      description: "Clean and simple design with ample white space",
      colors: %{
        primary: "#000000",
        secondary: "#6b7280",
        accent: "#059669",
        background: "#ffffff",
        text: "#111827",
        border: "#d1d5db"
      },
      typography: %{
        font_family: "Helvetica, Arial, sans-serif",
        heading_size: "22pt",
        body_size: "10pt",
        caption_size: "8pt",
        line_height: 1.6
      },
      styles: %{
        table_header_bg: "#f9fafb",
        table_border: "#e5e7eb",
        section_spacing: "16pt"
      }
    },
    vibrant: %{
      id: :vibrant,
      name: "Vibrant",
      description: "Bold and colorful theme for impactful reports",
      colors: %{
        primary: "#dc2626",
        secondary: "#ea580c",
        accent: "#f59e0b",
        background: "#ffffff",
        text: "#1f2937",
        border: "#fca5a5"
      },
      typography: %{
        font_family: "Montserrat, system-ui, sans-serif",
        heading_size: "26pt",
        body_size: "11pt",
        caption_size: "9pt",
        line_height: 1.4
      },
      styles: %{
        table_header_bg: "#fee2e2",
        table_border: "#fca5a5",
        section_spacing: "14pt"
      }
    },
    classic: %{
      id: :classic,
      name: "Classic",
      description: "Traditional serif design for formal documents",
      colors: %{
        primary: "#92400e",
        secondary: "#78716c",
        accent: "#d97706",
        background: "#fffbeb",
        text: "#1c1917",
        border: "#d6d3d1"
      },
      typography: %{
        font_family: "Georgia, Times New Roman, serif",
        heading_size: "24pt",
        body_size: "11pt",
        caption_size: "9pt",
        line_height: 1.7
      },
      styles: %{
        table_header_bg: "#fef3c7",
        table_border: "#d6d3d1",
        section_spacing: "15pt"
      }
    },
    modern: %{
      id: :modern,
      name: "Modern",
      description: "Contemporary design with gradient accents",
      colors: %{
        primary: "#7c3aed",
        secondary: "#a855f7",
        accent: "#ec4899",
        background: "#ffffff",
        text: "#18181b",
        border: "#e4e4e7"
      },
      typography: %{
        font_family: "Poppins, system-ui, sans-serif",
        heading_size: "25pt",
        body_size: "11pt",
        caption_size: "9pt",
        line_height: 1.5
      },
      styles: %{
        table_header_bg: "#f5f3ff",
        table_border: "#e9d5ff",
        section_spacing: "13pt"
      }
    }
  }

  @doc """
  Returns all available themes.
  """
  def list_themes do
    Enum.map(@themes, fn {_id, theme} ->
      struct(__MODULE__, theme)
    end)
  end

  @doc """
  Gets a theme by ID.

  ## Examples

      iex> Theme.get_theme(:corporate)
      %Theme{id: :corporate, name: "Corporate", ...}

      iex> Theme.get_theme(:invalid)
      nil
  """
  def get_theme(theme_id) when is_atom(theme_id) do
    case Map.get(@themes, theme_id) do
      nil -> nil
      theme -> struct(__MODULE__, theme)
    end
  end

  def get_theme(theme_id) when is_binary(theme_id) do
    get_theme(String.to_existing_atom(theme_id))
  rescue
    ArgumentError -> nil
  end

  @doc """
  Gets theme IDs.
  """
  def theme_ids do
    Map.keys(@themes)
  end

  @doc """
  Validates if a theme ID exists.
  """
  def valid_theme?(theme_id) when is_atom(theme_id) do
    Map.has_key?(@themes, theme_id)
  end

  def valid_theme?(theme_id) when is_binary(theme_id) do
    theme_id
    |> String.to_existing_atom()
    |> valid_theme?()
  rescue
    ArgumentError -> false
  end

  @doc """
  Merges custom overrides into a theme.

  ## Examples

      iex> theme = Theme.get_theme(:corporate)
      iex> Theme.merge_overrides(theme, %{colors: %{primary: "#ff0000"}})
      %Theme{colors: %{primary: "#ff0000", ...}}
  """
  def merge_overrides(%__MODULE__{} = theme, overrides) when is_map(overrides) do
    %{theme |
      colors: Map.merge(theme.colors, Map.get(overrides, :colors, %{})),
      typography: Map.merge(theme.typography, Map.get(overrides, :typography, %{})),
      styles: Map.merge(theme.styles, Map.get(overrides, :styles, %{}))
    }
  end
end
