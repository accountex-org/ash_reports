defmodule AshReports.Renderer.Typst.ContentTest do
  @moduledoc """
  Tests for the Typst Content renderer.
  """

  use ExUnit.Case, async: true

  alias AshReports.Layout.IR
  alias AshReports.Layout.IR.Content
  alias AshReports.Layout.IR.Style
  alias AshReports.Renderer.Typst.Content, as: ContentRenderer

  describe "render/2 - labels" do
    test "renders plain label text" do
      label = Content.label("Hello World")
      result = ContentRenderer.render(label)

      assert result == "Hello World"
    end

    test "renders label with styling" do
      style = Style.new(font_weight: :bold)
      label = Content.label("Important", style: style)
      result = ContentRenderer.render(label)

      assert result =~ "#text(weight: \"bold\")"
      assert result =~ "[Important]"
    end

    test "renders label with multiple styles" do
      style = Style.new(font_size: "14pt", font_weight: :bold, color: "red")
      label = Content.label("Styled", style: style)
      result = ContentRenderer.render(label)

      assert result =~ "size: 14pt"
      assert result =~ "weight: \"bold\""
      assert result =~ "fill: red"
    end

    test "renders label with hex color" do
      style = Style.new(color: "#ff0000")
      label = Content.label("Red", style: style)
      result = ContentRenderer.render(label)

      assert result =~ "fill: rgb(\"#ff0000\")"
    end

    test "renders label with font family" do
      style = Style.new(font_family: "Arial")
      label = Content.label("Custom font", style: style)
      result = ContentRenderer.render(label)

      assert result =~ "font: \"Arial\""
    end

    test "renders label with italic style" do
      style = Style.new(font_style: :italic)
      label = Content.label("Italic", style: style)
      result = ContentRenderer.render(label)

      assert result =~ "style: \"italic\""
    end

    test "skips empty style" do
      style = Style.new()
      label = Content.label("Plain", style: style)
      result = ContentRenderer.render(label)

      assert result == "Plain"
    end
  end

  describe "render/2 - fields" do
    test "renders field value from data" do
      field = Content.field(:name)
      result = ContentRenderer.render(field, data: %{name: "Alice"})

      assert result == "Alice"
    end

    test "renders nested field path" do
      field = Content.field([:user, :name])
      result = ContentRenderer.render(field, data: %{user: %{name: "Bob"}})

      assert result == "Bob"
    end

    test "renders empty for missing field" do
      field = Content.field(:missing)
      result = ContentRenderer.render(field, data: %{})

      assert result == ""
    end

    test "renders field with number format" do
      field = Content.field(:amount, format: :number, decimal_places: 2)
      result = ContentRenderer.render(field, data: %{amount: 1234.5})

      assert result == "1234.50"
    end

    test "renders field with currency format" do
      field = Content.field(:price, format: :currency, decimal_places: 2)
      result = ContentRenderer.render(field, data: %{price: 99.99})

      # Dollar sign is escaped for Typst
      assert result == "\\$99.99"
    end

    test "renders field with percent format" do
      field = Content.field(:rate, format: :percent, decimal_places: 1)
      result = ContentRenderer.render(field, data: %{rate: 0.125})

      assert result == "12.5%"
    end

    test "renders field with date format" do
      field = Content.field(:date, format: :date)
      result = ContentRenderer.render(field, data: %{date: ~D[2025-01-15]})

      assert result == "2025-01-15"
    end

    test "renders field with datetime format" do
      field = Content.field(:timestamp, format: :datetime)
      result = ContentRenderer.render(field, data: %{timestamp: ~N[2025-01-15 10:30:00]})

      assert result =~ "2025-01-15"
      assert result =~ "10:30:00"
    end

    test "renders field with styling" do
      style = Style.new(font_weight: :bold)
      field = Content.field(:value, style: style)
      result = ContentRenderer.render(field, data: %{value: 100})

      assert result =~ "#text(weight: \"bold\")"
      assert result =~ "[100]"
    end
  end

  describe "render/2 - nested layouts" do
    test "renders nested grid" do
      grid = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      nested = Content.nested_layout(grid)
      result = ContentRenderer.render(nested)

      assert result =~ "#grid("
      assert result =~ "columns: (1fr, 1fr)"
    end

    test "renders nested table" do
      table = IR.table(properties: %{columns: ["1fr"]})
      nested = Content.nested_layout(table)
      result = ContentRenderer.render(nested)

      assert result =~ "#table("
    end

    test "renders nested stack" do
      stack = IR.stack(properties: %{dir: :ttb})
      nested = Content.nested_layout(stack)
      result = ContentRenderer.render(nested)

      assert result =~ "#stack("
      assert result =~ "dir: ttb"
    end
  end

  describe "render/2 - legacy formats" do
    test "renders map with text key" do
      result = ContentRenderer.render(%{text: "Legacy"})
      assert result == "Legacy"
    end

    test "renders map with value key" do
      result = ContentRenderer.render(%{value: 42})
      assert result == "42"
    end
  end

  describe "escape_typst/1" do
    test "escapes hash character" do
      result = ContentRenderer.escape_typst("Item #5")
      assert result == "Item \\#5"
    end

    test "escapes dollar sign" do
      result = ContentRenderer.escape_typst("Price: $100")
      assert result == "Price: \\$100"
    end

    test "escapes at symbol" do
      result = ContentRenderer.escape_typst("email@example.com")
      assert result == "email\\@example.com"
    end

    test "escapes asterisk" do
      result = ContentRenderer.escape_typst("*bold*")
      assert result == "\\*bold\\*"
    end

    test "escapes underscore" do
      result = ContentRenderer.escape_typst("_italic_")
      assert result == "\\_italic\\_"
    end

    test "escapes brackets" do
      result = ContentRenderer.escape_typst("[content]")
      assert result == "\\[content\\]"
    end

    test "escapes braces" do
      result = ContentRenderer.escape_typst("{code}")
      assert result == "\\{code\\}"
    end

    test "escapes angle brackets" do
      result = ContentRenderer.escape_typst("<label>")
      assert result == "\\<label\\>"
    end

    test "escapes backslash" do
      result = ContentRenderer.escape_typst("path\\to\\file")
      assert result == "path\\\\to\\\\file"
    end

    test "escapes multiple special characters" do
      result = ContentRenderer.escape_typst("Price: $100 #5 @home")
      assert result == "Price: \\$100 \\#5 \\@home"
    end
  end

  describe "wrap_with_style/2" do
    test "wraps text with text function" do
      style = Style.new(font_weight: :bold)
      result = ContentRenderer.wrap_with_style("Hello", style)

      assert result == "#text(weight: \"bold\")[Hello]"
    end

    test "combines multiple style parameters" do
      style = Style.new(font_size: "12pt", color: "blue")
      result = ContentRenderer.wrap_with_style("Styled", style)

      assert result =~ "#text("
      assert result =~ "size: 12pt"
      assert result =~ "fill: blue"
      assert result =~ ")[Styled]"
    end

    test "returns plain text for empty style" do
      style = Style.new()
      result = ContentRenderer.wrap_with_style("Plain", style)

      assert result == "Plain"
    end
  end

  describe "render_font_weight/1" do
    test "renders normal as regular" do
      assert ContentRenderer.render_font_weight(:normal) == "\"regular\""
    end

    test "renders bold" do
      assert ContentRenderer.render_font_weight(:bold) == "\"bold\""
    end

    test "renders light" do
      assert ContentRenderer.render_font_weight(:light) == "\"light\""
    end

    test "renders medium" do
      assert ContentRenderer.render_font_weight(:medium) == "\"medium\""
    end

    test "renders semibold" do
      assert ContentRenderer.render_font_weight(:semibold) == "\"semibold\""
    end

    test "renders string weight" do
      assert ContentRenderer.render_font_weight("600") == "\"600\""
    end
  end

  describe "render_color/1" do
    test "renders color name" do
      assert ContentRenderer.render_color("red") == "red"
    end

    test "renders hex color as rgb" do
      assert ContentRenderer.render_color("#ff0000") == "rgb(\"#ff0000\")"
    end

    test "renders atom color" do
      assert ContentRenderer.render_color(:blue) == "blue"
    end
  end

  describe "format_value/3" do
    test "formats nil as empty" do
      assert ContentRenderer.format_value(nil, :number, 2) == ""
    end

    test "formats empty string as empty" do
      assert ContentRenderer.format_value("", :number, 2) == ""
    end

    test "formats without format as string" do
      assert ContentRenderer.format_value(42, nil, nil) == "42"
    end

    test "formats number with decimal places" do
      assert ContentRenderer.format_value(100, :number, 0) == "100"
      assert ContentRenderer.format_value(100.5, :number, 2) == "100.50"
    end

    test "formats currency" do
      # Note: format_value returns unescaped, escaping happens in render
      assert ContentRenderer.format_value(50, :currency, 2) == "$50.00"
    end

    test "formats percent" do
      assert ContentRenderer.format_value(0.5, :percent, 0) == "50%"
    end
  end
end
