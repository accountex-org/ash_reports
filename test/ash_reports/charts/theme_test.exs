defmodule AshReports.Charts.ThemeTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.{Config, Theme}

  describe "get/1" do
    test "returns default theme configuration" do
      theme = Theme.get(:default)

      assert is_map(theme)
      assert theme.font_family == "sans-serif"
      assert theme.font_size == 12
      assert theme.show_grid == true
      assert is_list(theme.colors)
    end

    test "returns corporate theme configuration" do
      theme = Theme.get(:corporate)

      assert is_map(theme)
      assert theme.font_family == "Arial, sans-serif"
      assert theme.font_size == 11
      assert theme.legend_position == :bottom
      assert is_list(theme.colors)
      assert "#2C3E50" in theme.colors
    end

    test "returns minimal theme configuration" do
      theme = Theme.get(:minimal)

      assert is_map(theme)
      assert theme.show_grid == false
      assert theme.show_legend == false
      assert is_list(theme.colors)
    end

    test "returns vibrant theme configuration" do
      theme = Theme.get(:vibrant)

      assert is_map(theme)
      assert theme.font_size == 13
      assert theme.legend_position == :top
      assert is_list(theme.colors)
    end
  end

  describe "apply/3" do
    test "applies theme to config" do
      config = %Config{title: "Test"}
      themed_config = Theme.apply(config, :corporate)

      assert themed_config.title == "Test"
      assert themed_config.font_family == "Arial, sans-serif"
      assert themed_config.font_size == 11
      assert themed_config.legend_position == :bottom
    end

    test "config values override theme defaults" do
      config = %Config{title: "Test", font_size: 20, colors: ["#FF0000"]}
      themed_config = Theme.apply(config, :corporate)

      # Config values preserved
      assert themed_config.font_size == 20
      assert themed_config.colors == ["#FF0000"]

      # Theme values for non-set fields
      assert themed_config.font_family == "Arial, sans-serif"
    end

    test "overrides take highest precedence" do
      config = %Config{title: "Test"}
      themed_config = Theme.apply(config, :corporate, %{font_size: 25})

      assert themed_config.font_size == 25
      assert themed_config.font_family == "Arial, sans-serif"
    end

    test "preserves config title and basic fields" do
      config = %Config{title: "Custom Title", width: 800, height: 600}
      themed_config = Theme.apply(config, :minimal)

      assert themed_config.title == "Custom Title"
      assert themed_config.width == 800
      assert themed_config.height == 600
    end
  end

  describe "list_themes/0" do
    test "returns list of all available themes" do
      themes = Theme.list_themes()

      assert is_list(themes)
      assert :default in themes
      assert :corporate in themes
      assert :minimal in themes
      assert :vibrant in themes
      assert length(themes) == 4
    end
  end

  describe "exists?/1" do
    test "returns true for existing themes" do
      assert Theme.exists?(:default) == true
      assert Theme.exists?(:corporate) == true
      assert Theme.exists?(:minimal) == true
      assert Theme.exists?(:vibrant) == true
    end

    test "returns false for non-existing themes" do
      assert Theme.exists?(:unknown) == false
      assert Theme.exists?(:custom) == false
    end
  end
end
