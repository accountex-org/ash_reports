defmodule AshReports.Customization.ThemeTest do
  use ExUnit.Case, async: true

  alias AshReports.Customization.Theme

  describe "list_themes/0" do
    test "returns all predefined themes" do
      themes = Theme.list_themes()

      assert length(themes) == 5
      assert Enum.all?(themes, &is_struct(&1, Theme))

      theme_ids = Enum.map(themes, & &1.id)
      assert :corporate in theme_ids
      assert :minimal in theme_ids
      assert :vibrant in theme_ids
      assert :classic in theme_ids
      assert :modern in theme_ids
    end

    test "each theme has required fields" do
      themes = Theme.list_themes()

      Enum.each(themes, fn theme ->
        assert theme.id
        assert theme.name
        assert theme.description
        assert is_map(theme.colors)
        assert is_map(theme.typography)
        assert is_map(theme.styles)
      end)
    end
  end

  describe "get_theme/1" do
    test "returns theme for valid atom ID" do
      theme = Theme.get_theme(:corporate)

      assert theme.id == :corporate
      assert theme.name == "Corporate"
      assert theme.colors.primary == "#1e3a8a"
    end

    test "returns theme for valid string ID" do
      theme = Theme.get_theme("minimal")

      assert theme.id == :minimal
      assert theme.name == "Minimal"
    end

    test "returns nil for invalid atom ID" do
      assert Theme.get_theme(:invalid) == nil
    end

    test "returns nil for invalid string ID" do
      assert Theme.get_theme("invalid") == nil
    end

    test "vibrant theme has correct colors" do
      theme = Theme.get_theme(:vibrant)

      assert theme.colors.primary == "#dc2626"
      assert theme.colors.accent == "#f59e0b"
    end

    test "classic theme has serif typography" do
      theme = Theme.get_theme(:classic)

      assert String.contains?(theme.typography.font_family, "Georgia")
    end
  end

  describe "theme_ids/0" do
    test "returns list of theme IDs" do
      ids = Theme.theme_ids()

      assert :corporate in ids
      assert :minimal in ids
      assert :vibrant in ids
      assert :classic in ids
      assert :modern in ids
      assert length(ids) == 5
    end
  end

  describe "valid_theme?/1" do
    test "returns true for valid atom theme ID" do
      assert Theme.valid_theme?(:corporate) == true
      assert Theme.valid_theme?(:minimal) == true
    end

    test "returns true for valid string theme ID" do
      assert Theme.valid_theme?("vibrant") == true
      assert Theme.valid_theme?("modern") == true
    end

    test "returns false for invalid atom theme ID" do
      assert Theme.valid_theme?(:invalid) == false
    end

    test "returns false for invalid string theme ID" do
      assert Theme.valid_theme?("invalid") == false
    end
  end

  describe "merge_overrides/2" do
    test "merges color overrides into theme" do
      theme = Theme.get_theme(:corporate)

      updated =
        Theme.merge_overrides(theme, %{
          colors: %{primary: "#ff0000", accent: "#00ff00"}
        })

      assert updated.colors.primary == "#ff0000"
      assert updated.colors.accent == "#00ff00"
      assert updated.colors.secondary == theme.colors.secondary
    end

    test "merges typography overrides" do
      theme = Theme.get_theme(:minimal)

      updated =
        Theme.merge_overrides(theme, %{
          typography: %{heading_size: "30pt"}
        })

      assert updated.typography.heading_size == "30pt"
      assert updated.typography.body_size == theme.typography.body_size
    end

    test "merges style overrides" do
      theme = Theme.get_theme(:vibrant)

      updated =
        Theme.merge_overrides(theme, %{
          styles: %{section_spacing: "20pt"}
        })

      assert updated.styles.section_spacing == "20pt"
    end

    test "handles empty overrides" do
      theme = Theme.get_theme(:modern)
      updated = Theme.merge_overrides(theme, %{})

      assert updated == theme
    end

    test "preserves theme structure with partial overrides" do
      theme = Theme.get_theme(:classic)

      updated =
        Theme.merge_overrides(theme, %{
          colors: %{primary: "#123456"}
        })

      assert is_map(updated.colors)
      assert is_map(updated.typography)
      assert is_map(updated.styles)
      assert map_size(updated.colors) == map_size(theme.colors)
    end
  end
end
