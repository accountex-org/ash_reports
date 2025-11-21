defmodule AshReports.Renderer.Typst.StylingTest do
  @moduledoc """
  Tests for the Typst Styling module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR.Style
  alias AshReports.Renderer.Typst.Styling

  describe "apply_style/2" do
    test "returns text unchanged when style is nil" do
      result = Styling.apply_style("Hello", nil)
      assert result == "Hello"
    end

    test "returns text unchanged when style is empty" do
      style = %Style{}
      result = Styling.apply_style("Hello", style)
      assert result == "Hello"
    end

    test "wraps text with #text() when style has properties" do
      style = %Style{font_weight: :bold}
      result = Styling.apply_style("Hello", style)
      assert result == "#text(weight: \"bold\")[Hello]"
    end

    test "applies font size" do
      style = %Style{font_size: "14pt"}
      result = Styling.apply_style("Text", style)
      assert result == "#text(size: 14pt)[Text]"
    end

    test "applies color" do
      style = %Style{color: "red"}
      result = Styling.apply_style("Text", style)
      assert result == "#text(fill: red)[Text]"
    end

    test "applies font family" do
      style = %Style{font_family: "Arial"}
      result = Styling.apply_style("Text", style)
      assert result == "#text(font: \"Arial\")[Text]"
    end

    test "applies italic style" do
      style = %Style{font_style: :italic}
      result = Styling.apply_style("Text", style)
      assert result == "#text(style: \"italic\")[Text]"
    end

    test "ignores normal font style" do
      style = %Style{font_style: :normal}
      result = Styling.apply_style("Text", style)
      assert result == "Text"
    end

    test "combines multiple style properties" do
      style = %Style{
        font_size: "24pt",
        font_weight: :bold,
        color: "blue"
      }
      result = Styling.apply_style("Important", style)

      assert result =~ "#text("
      assert result =~ "size: 24pt"
      assert result =~ "weight: \"bold\""
      assert result =~ "fill: blue"
      assert result =~ ")[Important]"
    end

    test "combines all style properties" do
      style = %Style{
        font_size: "18pt",
        font_weight: :semibold,
        font_style: :italic,
        color: "#ff0000",
        font_family: "Georgia"
      }
      result = Styling.apply_style("Text", style)

      assert result =~ "size: 18pt"
      assert result =~ "weight: \"semibold\""
      assert result =~ "style: \"italic\""
      assert result =~ "fill: rgb(\"#ff0000\")"
      assert result =~ "font: \"Georgia\""
    end
  end

  describe "wrap_with_text/2" do
    test "wraps text with #text() and parameters" do
      style = %Style{font_weight: :bold}
      result = Styling.wrap_with_text("Hello", style)
      assert result == "#text(weight: \"bold\")[Hello]"
    end

    test "returns original text when no parameters" do
      style = %Style{}
      result = Styling.wrap_with_text("Hello", style)
      assert result == "Hello"
    end
  end

  describe "build_style_parameters/1" do
    test "returns empty string for empty style" do
      style = %Style{}
      result = Styling.build_style_parameters(style)
      assert result == ""
    end

    test "builds font size parameter" do
      style = %Style{font_size: "12pt"}
      result = Styling.build_style_parameters(style)
      assert result == "size: 12pt"
    end

    test "builds font weight parameter" do
      style = %Style{font_weight: :bold}
      result = Styling.build_style_parameters(style)
      assert result == "weight: \"bold\""
    end

    test "builds font style parameter" do
      style = %Style{font_style: :italic}
      result = Styling.build_style_parameters(style)
      assert result == "style: \"italic\""
    end

    test "builds color parameter" do
      style = %Style{color: "red"}
      result = Styling.build_style_parameters(style)
      assert result == "fill: red"
    end

    test "builds font family parameter" do
      style = %Style{font_family: "Times New Roman"}
      result = Styling.build_style_parameters(style)
      assert result == "font: \"Times New Roman\""
    end

    test "builds multiple parameters in order" do
      style = %Style{
        font_size: "14pt",
        font_weight: :medium,
        color: "gray"
      }
      result = Styling.build_style_parameters(style)

      # Parameters should be comma-separated
      assert result =~ "size: 14pt"
      assert result =~ "weight: \"medium\""
      assert result =~ "fill: gray"
      assert String.contains?(result, ", ")
    end
  end

  describe "render_font_weight/1" do
    test "renders :normal as regular" do
      assert Styling.render_font_weight(:normal) == "\"regular\""
    end

    test "renders :bold as bold" do
      assert Styling.render_font_weight(:bold) == "\"bold\""
    end

    test "renders :light as light" do
      assert Styling.render_font_weight(:light) == "\"light\""
    end

    test "renders :medium as medium" do
      assert Styling.render_font_weight(:medium) == "\"medium\""
    end

    test "renders :semibold as semibold" do
      assert Styling.render_font_weight(:semibold) == "\"semibold\""
    end

    test "renders :thin as thin" do
      assert Styling.render_font_weight(:thin) == "\"thin\""
    end

    test "renders :black as black" do
      assert Styling.render_font_weight(:black) == "\"black\""
    end

    test "renders :extrabold as extrabold" do
      assert Styling.render_font_weight(:extrabold) == "\"extrabold\""
    end

    test "renders :extralight as extralight" do
      assert Styling.render_font_weight(:extralight) == "\"extralight\""
    end

    test "renders numeric weight without quotes" do
      assert Styling.render_font_weight(400) == "400"
      assert Styling.render_font_weight(700) == "700"
    end

    test "renders string weight with quotes" do
      assert Styling.render_font_weight("custom") == "\"custom\""
    end

    test "renders unknown atom weight with quotes" do
      assert Styling.render_font_weight(:custom) == "\"custom\""
    end
  end

  describe "render_color/1" do
    test "renders named color directly" do
      assert Styling.render_color("red") == "red"
      assert Styling.render_color("blue") == "blue"
      assert Styling.render_color("lightgray") == "lightgray"
    end

    test "renders hex color as rgb()" do
      assert Styling.render_color("#ff0000") == "rgb(\"#ff0000\")"
      assert Styling.render_color("#fff") == "rgb(\"#fff\")"
      assert Styling.render_color("#00ff00ff") == "rgb(\"#00ff00ff\")"
    end

    test "renders atom color as string" do
      assert Styling.render_color(:red) == "red"
      assert Styling.render_color(:blue) == "blue"
      assert Styling.render_color(:gray) == "gray"
    end
  end

  describe "has_styling?/1" do
    test "returns false for nil" do
      refute Styling.has_styling?(nil)
    end

    test "returns false for empty style" do
      refute Styling.has_styling?(%Style{})
    end

    test "returns true when font_size is set" do
      assert Styling.has_styling?(%Style{font_size: "14pt"})
    end

    test "returns true when font_weight is set" do
      assert Styling.has_styling?(%Style{font_weight: :bold})
    end

    test "returns true when color is set" do
      assert Styling.has_styling?(%Style{color: "red"})
    end

    test "returns true when font_family is set" do
      assert Styling.has_styling?(%Style{font_family: "Arial"})
    end

    test "returns true when font_style is set" do
      assert Styling.has_styling?(%Style{font_style: :italic})
    end
  end

  describe "integration scenarios" do
    test "styles report title" do
      style = %Style{
        font_size: "24pt",
        font_weight: :bold,
        color: "#333333"
      }
      result = Styling.apply_style("Monthly Sales Report", style)

      assert result =~ "#text("
      assert result =~ "size: 24pt"
      assert result =~ "weight: \"bold\""
      assert result =~ "fill: rgb(\"#333333\")"
      assert result =~ ")[Monthly Sales Report]"
    end

    test "styles column header" do
      style = %Style{
        font_weight: :semibold,
        color: "gray"
      }
      result = Styling.apply_style("Product Name", style)

      assert result =~ "weight: \"semibold\""
      assert result =~ "fill: gray"
    end

    test "styles footer text" do
      style = %Style{
        font_size: "8pt",
        color: "#666666",
        font_style: :italic
      }
      result = Styling.apply_style("Page 1 of 5", style)

      assert result =~ "size: 8pt"
      assert result =~ "fill: rgb(\"#666666\")"
      assert result =~ "style: \"italic\""
    end
  end
end
