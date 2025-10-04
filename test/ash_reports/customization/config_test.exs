defmodule AshReports.Customization.ConfigTest do
  use ExUnit.Case, async: true

  alias AshReports.Customization.Config
  alias AshReports.Customization.Theme

  describe "new/1" do
    test "creates config with default values" do
      config = Config.new()

      assert config.theme_id == nil
      assert config.theme_overrides == %{}
      assert config.logo_url == nil
      assert config.brand_colors == %{}
      assert config.custom_fonts == %{}
      assert config.custom_styles == nil
    end

    test "creates config with provided attributes" do
      config = Config.new(theme_id: :corporate, logo_url: "https://example.com/logo.png")

      assert config.theme_id == :corporate
      assert config.logo_url == "https://example.com/logo.png"
    end
  end

  describe "validate/1" do
    test "validates config with valid theme" do
      config = Config.new(theme_id: :corporate)

      assert {:ok, ^config} = Config.validate(config)
    end

    test "returns error for invalid theme" do
      config = Config.new(theme_id: :invalid_theme)

      assert {:error, errors} = Config.validate(config)
      assert errors.theme_id == "invalid theme"
    end

    test "validates logo URL format" do
      config = Config.new(logo_url: "https://example.com/logo.png")

      assert {:ok, ^config} = Config.validate(config)
    end

    test "returns error for invalid logo URL" do
      config = Config.new(logo_url: "not-a-url")

      assert {:error, errors} = Config.validate(config)
      assert errors.logo_url == "invalid URL format"
    end

    test "validates hex color format in brand colors" do
      config = Config.new(brand_colors: %{primary: "#ff0000", secondary: "#00ff00"})

      assert {:ok, ^config} = Config.validate(config)
    end

    test "returns error for invalid color format" do
      config = Config.new(brand_colors: %{primary: "red"})

      assert {:error, errors} = Config.validate(config)
      assert errors.brand_colors == "invalid color format"
    end

    test "validates config with no customizations" do
      config = Config.new()

      assert {:ok, ^config} = Config.validate(config)
    end
  end

  describe "set_theme/2" do
    test "sets theme ID" do
      config = Config.new()
      updated = Config.set_theme(config, :minimal)

      assert updated.theme_id == :minimal
    end
  end

  describe "set_theme_overrides/2" do
    test "sets theme overrides" do
      config = Config.new()

      updated =
        Config.set_theme_overrides(config, %{
          colors: %{primary: "#ff0000"}
        })

      assert updated.theme_overrides == %{colors: %{primary: "#ff0000"}}
    end

    test "merges with existing overrides" do
      config = Config.new(theme_overrides: %{colors: %{primary: "#ff0000"}})

      updated =
        Config.set_theme_overrides(config, %{
          typography: %{heading_size: "30pt"}
        })

      assert updated.theme_overrides.colors.primary == "#ff0000"
      assert updated.theme_overrides.typography.heading_size == "30pt"
    end
  end

  describe "set_logo/2" do
    test "sets logo URL" do
      config = Config.new()
      updated = Config.set_logo(config, "https://example.com/logo.png")

      assert updated.logo_url == "https://example.com/logo.png"
    end
  end

  describe "set_brand_colors/2" do
    test "sets brand colors" do
      config = Config.new()
      updated = Config.set_brand_colors(config, %{primary: "#123456"})

      assert updated.brand_colors == %{primary: "#123456"}
    end

    test "merges with existing brand colors" do
      config = Config.new(brand_colors: %{primary: "#111111"})
      updated = Config.set_brand_colors(config, %{secondary: "#222222"})

      assert updated.brand_colors.primary == "#111111"
      assert updated.brand_colors.secondary == "#222222"
    end
  end

  describe "set_custom_fonts/2" do
    test "sets custom fonts" do
      config = Config.new()
      updated = Config.set_custom_fonts(config, %{heading: "Arial"})

      assert updated.custom_fonts == %{heading: "Arial"}
    end
  end

  describe "set_custom_styles/2" do
    test "sets custom styles" do
      config = Config.new()
      updated = Config.set_custom_styles(config, ".custom { color: red; }")

      assert updated.custom_styles == ".custom { color: red; }"
    end
  end

  describe "get_effective_theme/1" do
    test "returns nil when no theme is set" do
      config = Config.new()

      assert Config.get_effective_theme(config) == nil
    end

    test "returns theme when theme ID is set" do
      config = Config.new(theme_id: :corporate)
      theme = Config.get_effective_theme(config)

      assert theme.id == :corporate
      assert is_struct(theme, Theme)
    end

    test "applies theme overrides to base theme" do
      config =
        Config.new(
          theme_id: :corporate,
          theme_overrides: %{
            colors: %{primary: "#ff0000"}
          }
        )

      theme = Config.get_effective_theme(config)

      assert theme.colors.primary == "#ff0000"
      assert theme.colors.secondary == "#64748b"
    end

    test "applies brand colors to theme" do
      config =
        Config.new(
          theme_id: :minimal,
          brand_colors: %{primary: "#abcdef", accent: "#fedcba"}
        )

      theme = Config.get_effective_theme(config)

      assert theme.colors.primary == "#abcdef"
      assert theme.colors.accent == "#fedcba"
    end

    test "returns nil for invalid theme ID" do
      config = Config.new(theme_id: :invalid)

      assert Config.get_effective_theme(config) == nil
    end
  end

  describe "to_map/1 and from_map/1" do
    test "converts config to map and back" do
      config =
        Config.new(
          theme_id: :vibrant,
          logo_url: "https://example.com/logo.png",
          brand_colors: %{primary: "#ff0000"}
        )

      map = Config.to_map(config)
      restored = Config.from_map(map)

      assert restored.theme_id == config.theme_id
      assert restored.logo_url == config.logo_url
      assert restored.brand_colors == config.brand_colors
    end

    test "to_map creates plain map" do
      config = Config.new(theme_id: :modern)
      map = Config.to_map(config)

      assert is_map(map)
      assert map.theme_id == :modern
      refute is_struct(map)
    end

    test "from_map creates config struct" do
      map = %{
        theme_id: :classic,
        logo_url: "https://test.com/logo.png"
      }

      config = Config.from_map(map)

      assert is_struct(config, Config)
      assert config.theme_id == :classic
      assert config.logo_url == "https://test.com/logo.png"
    end
  end
end
