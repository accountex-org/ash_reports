defmodule AshReports.Typst.CustomizationRendererTest do
  use ExUnit.Case, async: true

  alias AshReports.Customization.Config
  alias AshReports.Typst.CustomizationRenderer

  describe "render_styles/1" do
    test "returns empty string when customization is nil" do
      assert CustomizationRenderer.render_styles(nil) == ""
    end

    test "returns empty string when no theme is selected" do
      config = Config.new()
      assert CustomizationRenderer.render_styles(config) == ""
    end

    test "renders typography and colors when theme is set" do
      config = Config.new(theme_id: :corporate)
      result = CustomizationRenderer.render_styles(config)

      assert result =~ "// Theme: Corporate"
      assert result =~ "set text("
      assert result =~ "font:"
      assert result =~ "size:"
      assert result =~ "#let primary-color"
      assert result =~ "#let secondary-color"
    end

    test "applies brand color overrides" do
      config = Config.new(theme_id: :minimal, brand_colors: %{primary: "#ff5500"})
      result = CustomizationRenderer.render_styles(config)

      assert result =~ ~s[#let primary-color = rgb("#ff5500")]
    end
  end

  describe "render_typography/1" do
    test "renders typography settings from theme" do
      theme = %{
        name: "Test Theme",
        typography: %{
          font_family: "Arial, sans-serif",
          body_size: "12pt",
          heading_size: "24pt"
        },
        colors: %{primary: "#000000"}
      }

      result = CustomizationRenderer.render_typography(theme)

      assert result =~ ~s[font: "Arial, sans-serif"]
      assert result =~ "size: 12pt"
      assert result =~ "size: 24pt"
      assert result =~ "show heading.where(level: 1)"
    end

    test "applies primary color to headings" do
      theme = %{
        typography: %{
          font_family: "Georgia",
          body_size: "11pt",
          heading_size: "20pt"
        },
        colors: %{primary: "#1e3a8a"}
      }

      result = CustomizationRenderer.render_typography(theme)

      assert result =~ ~s[fill: rgb("#1e3a8a")]
    end
  end

  describe "render_colors/1" do
    test "renders all theme colors as Typst variables" do
      theme = %{
        colors: %{
          primary: "#1e3a8a",
          secondary: "#64748b",
          accent: "#3b82f6",
          text: "#1e293b",
          border: "#e2e8f0"
        }
      }

      result = CustomizationRenderer.render_colors(theme)

      assert result =~ ~s[#let primary-color = rgb("#1e3a8a")]
      assert result =~ ~s[#let secondary-color = rgb("#64748b")]
      assert result =~ ~s[#let accent-color = rgb("#3b82f6")]
      assert result =~ ~s[#let text-color = rgb("#1e293b")]
      assert result =~ ~s[#let border-color = rgb("#e2e8f0")]
    end
  end

  describe "render_table_styles/1" do
    test "renders table styling with theme colors" do
      theme = %{
        styles: %{
          table_border: "#cbd5e1",
          table_header_bg: "#f1f5f9"
        }
      }

      result = CustomizationRenderer.render_table_styles(theme)

      assert result =~ "set table("
      assert result =~ ~s[rgb("#cbd5e1")]
      assert result =~ ~s[rgb("#f1f5f9")]
      assert result =~ "stroke:"
      assert result =~ "fill:"
    end
  end

  describe "render_page_setup/2" do
    test "renders page setup with customization applied" do
      report = %{name: :test_report, title: "Test Report"}

      config = Config.new(theme_id: :corporate)

      result = CustomizationRenderer.render_page_setup(report, config)

      assert result =~ "set page("
      assert result =~ ~s[title: "Test Report"]
      assert result =~ "set text("
      assert result =~ "set table("
      assert result =~ "#let primary-color"
    end

    test "renders default setup when no customization theme" do
      report = %{name: :test_report, title: "Test Report"}
      config = Config.new()

      result = CustomizationRenderer.render_page_setup(report, config)

      assert result =~ "set page("
      assert result =~ ~s[title: "Test Report"]
      assert result =~ ~s[font: "Liberation Serif"]
      assert result =~ "size: 11pt"
    end

    test "uses report name when title is nil" do
      report = %{name: :my_report, title: nil}
      config = Config.new()

      result = CustomizationRenderer.render_page_setup(report, config)

      assert result =~ ~s[title: "my_report"]
    end
  end

  describe "integration with Config" do
    test "renders complete customization from config with overrides" do
      config =
        Config.new(
          theme_id: :minimal,
          brand_colors: %{primary: "#custom1", secondary: "#custom2"},
          theme_overrides: %{
            typography: %{heading_size: "28pt"}
          }
        )

      result = CustomizationRenderer.render_styles(config)

      # Should have custom brand colors
      assert result =~ ~s[#let primary-color = rgb("#custom1")]
      assert result =~ ~s[#let secondary-color = rgb("#custom2")]

      # Should have overridden heading size
      assert result =~ "size: 28pt"
    end
  end
end
