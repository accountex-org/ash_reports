defmodule AshReports.Renderer.Html.InterpolationTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Interpolation

  describe "interpolate/2" do
    test "replaces simple variables" do
      result = Interpolation.interpolate("Hello [name]!", %{name: "World"})
      assert result == "Hello World!"
    end

    test "replaces multiple variables" do
      result = Interpolation.interpolate("[greeting] [name]!", %{greeting: "Hi", name: "Bob"})
      assert result == "Hi Bob!"
    end

    test "replaces nested variables" do
      data = %{user: %{name: "Alice"}}
      result = Interpolation.interpolate("Hello [user.name]!", data)
      assert result == "Hello Alice!"
    end

    test "replaces deeply nested variables" do
      data = %{order: %{customer: %{address: %{city: "NYC"}}}}
      result = Interpolation.interpolate("City: [order.customer.address.city]", data)
      assert result == "City: NYC"
    end

    test "preserves missing variables" do
      result = Interpolation.interpolate("Hello [unknown]!", %{})
      assert result == "Hello [unknown]!"
    end

    test "escapes HTML in interpolated values" do
      result = Interpolation.interpolate("Code: [code]", %{code: "<script>alert('XSS')</script>"})
      assert result == "Code: &lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;"
    end

    test "escapes ampersand in values" do
      result = Interpolation.interpolate("Name: [name]", %{name: "A & B"})
      assert result == "Name: A &amp; B"
    end

    test "handles integer values" do
      result = Interpolation.interpolate("Count: [count]", %{count: 42})
      assert result == "Count: 42"
    end

    test "handles float values with 2 decimal places" do
      result = Interpolation.interpolate("Total: [total]", %{total: 99.999})
      assert result == "Total: 100.00"
    end

    test "handles Date values" do
      result = Interpolation.interpolate("Date: [date]", %{date: ~D[2024-01-15]})
      assert result == "Date: 2024-01-15"
    end

    test "handles DateTime values" do
      dt = ~U[2024-01-15 10:30:00Z]
      result = Interpolation.interpolate("Time: [time]", %{time: dt})
      assert String.contains?(result, "2024-01-15")
    end

    test "handles NaiveDateTime values" do
      result = Interpolation.interpolate("Time: [time]", %{time: ~N[2024-01-15 10:30:00]})
      assert String.contains?(result, "2024-01-15")
      assert String.contains?(result, "10:30:00")
    end

    test "handles atom values" do
      result = Interpolation.interpolate("Status: [status]", %{status: :active})
      assert result == "Status: active"
    end

    test "handles nil data" do
      result = Interpolation.interpolate("Hello [name]!", nil)
      assert result == "Hello [name]!"
    end

    test "handles non-string input" do
      result = Interpolation.interpolate(123, %{})
      assert result == "123"
    end

    test "supports string keys in data" do
      result = Interpolation.interpolate("Hello [name]!", %{"name" => "World"})
      assert result == "Hello World!"
    end

    test "handles empty string" do
      result = Interpolation.interpolate("", %{name: "Test"})
      assert result == ""
    end

    test "handles text without variables" do
      result = Interpolation.interpolate("Hello World!", %{name: "Test"})
      assert result == "Hello World!"
    end
  end

  describe "interpolate_raw/2" do
    test "replaces variables without escaping" do
      result = Interpolation.interpolate_raw("Code: [code]", %{code: "<b>bold</b>"})
      assert result == "Code: <b>bold</b>"
    end

    test "preserves HTML in values" do
      result = Interpolation.interpolate_raw("Test [html]", %{html: "<div>test</div>"})
      assert result == "Test <div>test</div>"
    end
  end

  describe "has_variables?/1" do
    test "returns true for text with variables" do
      assert Interpolation.has_variables?("Hello [name]!")
      assert Interpolation.has_variables?("[a] [b] [c]")
    end

    test "returns false for text without variables" do
      refute Interpolation.has_variables?("Hello World!")
      refute Interpolation.has_variables?("")
    end

    test "returns false for non-string input" do
      refute Interpolation.has_variables?(123)
      refute Interpolation.has_variables?(nil)
    end
  end

  describe "extract_variables/1" do
    test "extracts single variable" do
      assert Interpolation.extract_variables("Hello [name]!") == ["name"]
    end

    test "extracts multiple variables" do
      result = Interpolation.extract_variables("[a] [b] [c]")
      assert result == ["a", "b", "c"]
    end

    test "extracts nested variable names" do
      result = Interpolation.extract_variables("[user.name] [order.id]")
      assert result == ["user.name", "order.id"]
    end

    test "returns empty list for no variables" do
      assert Interpolation.extract_variables("Hello World!") == []
    end

    test "returns empty list for non-string input" do
      assert Interpolation.extract_variables(nil) == []
    end
  end

  describe "get_variable_value/2" do
    test "gets simple value with escaping" do
      result = Interpolation.get_variable_value(%{name: "<b>test</b>"}, "name")
      assert result == "&lt;b&gt;test&lt;/b&gt;"
    end

    test "gets nested value" do
      result = Interpolation.get_variable_value(%{user: %{name: "Alice"}}, "user.name")
      assert result == "Alice"
    end

    test "returns placeholder for missing value" do
      result = Interpolation.get_variable_value(%{}, "missing")
      assert result == "[missing]"
    end
  end

  describe "get_variable_value_raw/2" do
    test "gets value without escaping" do
      result = Interpolation.get_variable_value_raw(%{html: "<b>test</b>"}, "html")
      assert result == "<b>test</b>"
    end
  end

  describe "format_value/3" do
    test "formats nil as empty string" do
      assert Interpolation.format_value(nil, :number, 2) == ""
    end

    test "formats without format as string" do
      assert Interpolation.format_value("hello", nil, nil) == "hello"
      assert Interpolation.format_value(42, nil, nil) == "42"
    end

    test "formats number with decimal places" do
      result = Interpolation.format_value(1234.567, :number, 2)
      assert result == "1,234.57"
    end

    test "formats number with zero decimal places" do
      result = Interpolation.format_value(1234.567, :number, 0)
      assert result == "1,235"
    end

    test "formats currency with dollar sign and commas" do
      result = Interpolation.format_value(1234.5, :currency, 2)
      assert result == "$1,234.50"
    end

    test "formats large currency values" do
      result = Interpolation.format_value(1234567.89, :currency, 2)
      assert result == "$1,234,567.89"
    end

    test "formats percent with symbol" do
      result = Interpolation.format_value(0.156, :percent, 1)
      assert result == "15.6%"
    end

    test "formats percent with zero decimal places" do
      result = Interpolation.format_value(0.5, :percent, 0)
      assert result == "50%"
    end

    test "formats Date" do
      result = Interpolation.format_value(~D[2024-12-25], :date, nil)
      assert result == "2024-12-25"
    end

    test "formats DateTime" do
      dt = ~U[2024-12-25 14:30:00Z]
      result = Interpolation.format_value(dt, :datetime, nil)
      assert String.contains?(result, "2024-12-25")
    end

    test "formats NaiveDateTime" do
      result = Interpolation.format_value(~N[2024-12-25 14:30:00], :datetime, nil)
      assert String.contains?(result, "2024-12-25")
      assert String.contains?(result, "14:30:00")
    end

    test "formats date_short" do
      result = Interpolation.format_value(~D[2024-12-25], :date_short, nil)
      assert result == "12/25/2024"
    end

    test "formats boolean true" do
      assert Interpolation.format_value(true, :boolean, nil) == "Yes"
    end

    test "formats boolean false" do
      assert Interpolation.format_value(false, :boolean, nil) == "No"
    end

    test "handles unknown format" do
      result = Interpolation.format_value("test", :unknown, nil)
      assert result == "test"
    end
  end

  describe "format_value_safe/3" do
    test "formats and escapes value" do
      result = Interpolation.format_value_safe("<b>100</b>", nil, nil)
      assert result == "&lt;b&gt;100&lt;/b&gt;"
    end

    test "formats currency and escapes" do
      result = Interpolation.format_value_safe(1234.5, :currency, 2)
      assert result == "$1,234.50"
    end

    test "handles nil" do
      result = Interpolation.format_value_safe(nil, :number, 2)
      assert result == ""
    end
  end

  describe "number formatting with commas" do
    test "formats small numbers without commas" do
      result = Interpolation.format_value(123, :number, 0)
      assert result == "123"
    end

    test "formats thousands" do
      result = Interpolation.format_value(1234, :number, 0)
      assert result == "1,234"
    end

    test "formats millions" do
      result = Interpolation.format_value(1234567, :number, 0)
      assert result == "1,234,567"
    end

    test "formats with decimals" do
      result = Interpolation.format_value(1234567.89, :number, 2)
      assert result == "1,234,567.89"
    end
  end

  describe "XSS prevention" do
    test "escapes script tags" do
      result = Interpolation.interpolate("[x]", %{x: "<script>alert(1)</script>"})
      refute String.contains?(result, "<script>")
      assert String.contains?(result, "&lt;script&gt;")
    end

    test "escapes angle brackets in attributes" do
      input = "<img src=x>"
      result = Interpolation.interpolate("[x]", %{x: input})
      assert String.contains?(result, "&lt;img")
      assert String.contains?(result, "&gt;")
    end

    test "escapes quotes in values" do
      input = "test with \"quotes\""
      result = Interpolation.interpolate("[x]", %{x: input})
      assert String.contains?(result, "&quot;")
    end
  end
end
