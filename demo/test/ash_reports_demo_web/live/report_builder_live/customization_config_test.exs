defmodule AshReportsDemoWeb.ReportBuilderLive.CustomizationConfigTest do
  use ExUnit.Case, async: true

  alias AshReports.Customization.{Config, Theme}

  describe "Config module integration" do
    test "creates config with theme" do
      config = Config.new(theme_id: :corporate)

      assert config.theme_id == :corporate
      assert config.brand_colors == %{}
    end

    test "sets brand colors" do
      config = Config.new(theme_id: :minimal)
      updated = Config.set_brand_colors(config, %{primary: "#ff0000"})

      assert updated.brand_colors.primary == "#ff0000"
    end

    test "gets effective theme with brand color overrides" do
      config =
        Config.new(
          theme_id: :vibrant,
          brand_colors: %{primary: "#abcdef"}
        )

      theme = Config.get_effective_theme(config)

      assert theme.id == :vibrant
      assert theme.colors.primary == "#abcdef"
    end
  end

  describe "Theme module integration" do
    test "lists all available themes" do
      themes = Theme.list_themes()

      assert length(themes) == 5
      theme_ids = Enum.map(themes, & &1.id)
      assert :corporate in theme_ids
      assert :minimal in theme_ids
      assert :vibrant in theme_ids
      assert :classic in theme_ids
      assert :modern in theme_ids
    end

    test "gets specific theme by ID" do
      theme = Theme.get_theme(:corporate)

      assert theme.id == :corporate
      assert theme.name == "Corporate"
      assert theme.colors.primary == "#1e3a8a"
    end

    test "validates theme IDs" do
      assert Theme.valid_theme?(:corporate) == true
      assert Theme.valid_theme?(:minimal) == true
      assert Theme.valid_theme?(:invalid) == false
    end
  end

  describe "customization workflow" do
    test "full customization flow from theme selection to brand colors" do
      # Start with empty config
      config = Config.new()
      assert config.theme_id == nil

      # Select a theme
      config = Config.set_theme(config, :corporate)
      assert config.theme_id == :corporate

      # Customize brand colors
      config = Config.set_brand_colors(config, %{primary: "#123456", accent: "#fedcba"})

      # Verify effective theme has customizations applied
      effective_theme = Config.get_effective_theme(config)
      assert effective_theme.colors.primary == "#123456"
      assert effective_theme.colors.accent == "#fedcba"
      # Secondary should still be from base corporate theme
      assert effective_theme.colors.secondary == "#64748b"
    end

    test "customization can override theme settings" do
      config =
        Config.new(
          theme_id: :minimal,
          theme_overrides: %{
            colors: %{primary: "#ff0000"}
          }
        )

      effective_theme = Config.get_effective_theme(config)

      # Override should be applied
      assert effective_theme.colors.primary == "#ff0000"
    end

    test "serialization and deserialization maintains config" do
      original =
        Config.new(
          theme_id: :vibrant,
          brand_colors: %{primary: "#abc123"},
          logo_url: "https://example.com/logo.png"
        )

      # Convert to map and back
      map = Config.to_map(original)
      restored = Config.from_map(map)

      assert restored.theme_id == original.theme_id
      assert restored.brand_colors == original.brand_colors
      assert restored.logo_url == original.logo_url
    end
  end

  describe "validation" do
    test "validates valid configuration" do
      config = Config.new(theme_id: :corporate, brand_colors: %{primary: "#ff0000"})

      assert {:ok, ^config} = Config.validate(config)
    end

    test "rejects invalid theme ID" do
      config = Config.new(theme_id: :invalid_theme)

      assert {:error, errors} = Config.validate(config)
      assert errors.theme_id == "invalid theme"
    end

    test "rejects invalid color format" do
      config = Config.new(brand_colors: %{primary: "red"})

      assert {:error, errors} = Config.validate(config)
      assert errors.brand_colors == "invalid color format"
    end

    test "rejects invalid logo URL" do
      config = Config.new(logo_url: "not-a-url")

      assert {:error, errors} = Config.validate(config)
      assert errors.logo_url == "invalid URL format"
    end
  end
end
