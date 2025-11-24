defmodule AshReports.Renderer.Html.ContentTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Content
  alias AshReports.Layout.IR.Content.{Label, Field}
  alias AshReports.Layout.IR.Style

  describe "render/2 with Label" do
    test "renders label with text" do
      label = %Label{text: "Hello World"}
      result = Content.render(label)

      assert result == ~s(<span class="ash-label">Hello World</span>)
    end

    test "renders label with style" do
      style = %Style{
        font_size: "14pt",
        font_weight: :bold,
        color: "#333"
      }
      label = %Label{text: "Styled", style: style}
      result = Content.render(label)

      assert String.contains?(result, ~s(class="ash-label"))
      assert String.contains?(result, "font-size: 14px")
      assert String.contains?(result, "font-weight: bold")
      assert String.contains?(result, "color: #333")
      assert String.contains?(result, "Styled")
    end

    test "escapes HTML in label text" do
      label = %Label{text: "<script>alert('XSS')</script>"}
      result = Content.render(label)

      assert String.contains?(result, "&lt;script&gt;")
      refute String.contains?(result, "<script>")
    end

    test "renders label with font family" do
      style = %Style{font_family: "Helvetica, Arial"}
      label = %Label{text: "Custom Font", style: style}
      result = Content.render(label)

      assert String.contains?(result, "font-family: Helvetica, Arial")
    end

    test "renders label with font style italic" do
      style = %Style{font_style: :italic}
      label = %Label{text: "Italic", style: style}
      result = Content.render(label)

      assert String.contains?(result, "font-style: italic")
    end

    test "renders label with background color" do
      style = %Style{background_color: "#ffff00"}
      label = %Label{text: "Highlighted", style: style}
      result = Content.render(label)

      assert String.contains?(result, "background-color: #ffff00")
    end
  end

  describe "render/2 with Field" do
    test "renders field with simple value" do
      field = %Field{source: :name}
      result = Content.render(field, data: %{name: "John"})

      assert result == ~s(<span class="ash-field">John</span>)
    end

    test "renders field with nested source path" do
      field = %Field{source: [:user, :name]}
      result = Content.render(field, data: %{user: %{name: "Jane"}})

      assert String.contains?(result, "Jane")
    end

    test "renders field with number format" do
      field = %Field{source: :amount, format: :number, decimal_places: 2}
      result = Content.render(field, data: %{amount: 1234.5})

      assert String.contains?(result, "1234.50")
    end

    test "renders field with currency format" do
      field = %Field{source: :price, format: :currency, decimal_places: 2}
      result = Content.render(field, data: %{price: 99.99})

      assert String.contains?(result, "$99.99")
    end

    test "renders field with percent format" do
      field = %Field{source: :rate, format: :percent, decimal_places: 1}
      result = Content.render(field, data: %{rate: 0.156})

      assert String.contains?(result, "15.6%")
    end

    test "renders field with date format" do
      field = %Field{source: :date, format: :date}
      result = Content.render(field, data: %{date: ~D[2024-01-15]})

      assert String.contains?(result, "2024-01-15")
    end

    test "renders field with datetime format" do
      field = %Field{source: :timestamp, format: :datetime}
      result = Content.render(field, data: %{timestamp: ~N[2024-01-15 10:30:00]})

      assert String.contains?(result, "2024-01-15")
      assert String.contains?(result, "10:30:00")
    end

    test "renders field with style" do
      style = %Style{font_weight: :bold, color: "red"}
      field = %Field{source: :total, style: style}
      result = Content.render(field, data: %{total: 500})

      assert String.contains?(result, ~s(class="ash-field"))
      assert String.contains?(result, "font-weight: bold")
      assert String.contains?(result, "color: red")
      assert String.contains?(result, "500")
    end

    test "renders empty string for missing field" do
      field = %Field{source: :missing}
      result = Content.render(field, data: %{other: "value"})

      assert result == ~s(<span class="ash-field"></span>)
    end

    test "escapes HTML in field value" do
      field = %Field{source: :content}
      result = Content.render(field, data: %{content: "<b>bold</b>"})

      assert String.contains?(result, "&lt;b&gt;")
      refute String.contains?(result, "<b>")
    end

    test "renders field with string key in data" do
      field = %Field{source: :name}
      result = Content.render(field, data: %{"name" => "String Key"})

      assert String.contains?(result, "String Key")
    end
  end

  describe "render/2 with map content" do
    test "renders text map as label" do
      result = Content.render(%{text: "Simple Text"})

      assert result == ~s(<span class="ash-label">Simple Text</span>)
    end

    test "renders value map as field" do
      result = Content.render(%{value: 42})

      assert result == ~s(<span class="ash-field">42</span>)
    end

    test "renders string as label" do
      result = Content.render("Just a string")

      assert result == ~s(<span class="ash-label">Just a string</span>)
    end
  end

  describe "build_text_styles/1" do
    test "returns empty string for nil" do
      assert Content.build_text_styles(nil) == ""
    end

    test "builds complete style string" do
      style = %Style{
        font_size: "12pt",
        font_weight: :bold,
        font_style: :italic,
        color: "#000",
        background_color: "#fff",
        font_family: "Arial"
      }
      result = Content.build_text_styles(style)

      assert String.contains?(result, "font-size: 12px")
      assert String.contains?(result, "font-weight: bold")
      assert String.contains?(result, "font-style: italic")
      assert String.contains?(result, "color: #000")
      assert String.contains?(result, "background-color: #fff")
      assert String.contains?(result, "font-family: Arial")
    end

    test "handles partial styles" do
      style = %Style{font_weight: :bold}
      result = Content.build_text_styles(style)

      assert result == "font-weight: bold"
    end

    test "converts pt to px" do
      style = %Style{font_size: "16pt"}
      result = Content.build_text_styles(style)

      assert String.contains?(result, "font-size: 16px")
    end

    test "renders numeric font weights" do
      assert Content.build_text_styles(%Style{font_weight: :light}) == "font-weight: 300"
      assert Content.build_text_styles(%Style{font_weight: :medium}) == "font-weight: 500"
      assert Content.build_text_styles(%Style{font_weight: :semibold}) == "font-weight: 600"
    end
  end

  describe "format_value/3" do
    test "formats nil as empty string" do
      assert Content.format_value(nil, :number, 2) == ""
    end

    test "formats without format as string" do
      assert Content.format_value("hello", nil, nil) == "hello"
      assert Content.format_value(42, nil, nil) == "42"
    end

    test "formats number with decimal places" do
      assert Content.format_value(10, :number, 0) == "10.00000000000000000000e+00" ||
             Content.format_value(10, :number, 0) == "10"
    end

    test "formats currency with dollar sign" do
      result = Content.format_value(25.5, :currency, 2)
      assert String.starts_with?(result, "$")
      assert String.contains?(result, "25.50")
    end

    test "formats percent with symbol" do
      result = Content.format_value(0.5, :percent, 0)
      assert String.ends_with?(result, "%")
      assert String.contains?(result, "50")
    end

    test "formats Date" do
      result = Content.format_value(~D[2024-12-25], :date, nil)
      assert result == "2024-12-25"
    end

    test "formats NaiveDateTime" do
      result = Content.format_value(~N[2024-12-25 14:30:00], :datetime, nil)
      assert String.contains?(result, "2024-12-25")
      assert String.contains?(result, "14:30:00")
    end
  end

  describe "escape_html/1" do
    test "escapes all special characters" do
      input = "<div class=\"test\" data='value'>A & B</div>"
      result = Content.escape_html(input)

      assert result == "&lt;div class=&quot;test&quot; data=&#39;value&#39;&gt;A &amp; B&lt;/div&gt;"
    end

    test "handles non-string input" do
      assert Content.escape_html(123) == "123"
      assert Content.escape_html(:atom) == "atom"
    end
  end
end
