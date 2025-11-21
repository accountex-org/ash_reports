defmodule AshReports.Renderer.Typst.InterpolationTest do
  @moduledoc """
  Tests for the Typst Interpolation module.
  """

  use ExUnit.Case, async: true

  alias AshReports.Renderer.Typst.Interpolation

  describe "interpolate/2" do
    test "interpolates simple variable" do
      result = Interpolation.interpolate("Hello [name]!", %{name: "World"})
      assert result == "Hello World!"
    end

    test "interpolates multiple variables" do
      result = Interpolation.interpolate("[greeting] [name]!", %{greeting: "Hi", name: "Bob"})
      assert result == "Hi Bob!"
    end

    test "keeps missing variables as placeholders" do
      result = Interpolation.interpolate("Hello [unknown]!", %{name: "World"})
      assert result == "Hello [unknown]!"
    end

    test "handles empty data map" do
      result = Interpolation.interpolate("Hello [name]!", %{})
      assert result == "Hello [name]!"
    end

    test "returns text unchanged when no variables" do
      result = Interpolation.interpolate("Hello World!", %{name: "Test"})
      assert result == "Hello World!"
    end

    test "handles empty text" do
      result = Interpolation.interpolate("", %{name: "Test"})
      assert result == ""
    end

    test "interpolates nested variable path" do
      result = Interpolation.interpolate("Name: [user.name]", %{user: %{name: "Alice"}})
      assert result == "Name: Alice"
    end

    test "interpolates deeply nested path" do
      data = %{order: %{customer: %{address: %{city: "NYC"}}}}
      result = Interpolation.interpolate("City: [order.customer.address.city]", data)
      assert result == "City: NYC"
    end

    test "handles missing nested path" do
      result = Interpolation.interpolate("Value: [user.missing]", %{user: %{name: "Test"}})
      assert result == "Value: [user.missing]"
    end

    test "handles partial nested path" do
      result = Interpolation.interpolate("Value: [missing.path]", %{other: "test"})
      assert result == "Value: [missing.path]"
    end

    test "formats integer values" do
      result = Interpolation.interpolate("Count: [count]", %{count: 42})
      assert result == "Count: 42"
    end

    test "formats float values with 2 decimals" do
      result = Interpolation.interpolate("Total: [total]", %{total: 99.99})
      assert result == "Total: 99.99"
    end

    test "formats Date values" do
      date = ~D[2025-01-15]
      result = Interpolation.interpolate("Date: [date]", %{date: date})
      assert result == "Date: 2025-01-15"
    end

    test "formats DateTime values" do
      datetime = ~U[2025-01-15 10:30:00Z]
      result = Interpolation.interpolate("Time: [time]", %{time: datetime})
      assert result =~ "2025-01-15"
    end

    test "formats NaiveDateTime values" do
      datetime = ~N[2025-01-15 10:30:00]
      result = Interpolation.interpolate("Time: [time]", %{time: datetime})
      assert result =~ "2025-01-15 10:30:00"
    end

    test "formats atom values" do
      result = Interpolation.interpolate("Status: [status]", %{status: :active})
      assert result == "Status: active"
    end

    test "formats list values with inspect" do
      result = Interpolation.interpolate("Items: [items]", %{items: [1, 2, 3]})
      assert result == "Items: [1, 2, 3]"
    end

    test "handles multiple occurrences of same variable" do
      result = Interpolation.interpolate("[name] says hello to [name]", %{name: "Alice"})
      assert result == "Alice says hello to Alice"
    end

    test "handles adjacent variables" do
      result = Interpolation.interpolate("[first][last]", %{first: "John", last: "Doe"})
      assert result == "JohnDoe"
    end

    test "handles variable at start of text" do
      result = Interpolation.interpolate("[name] is here", %{name: "Bob"})
      assert result == "Bob is here"
    end

    test "handles variable at end of text" do
      result = Interpolation.interpolate("Hello [name]", %{name: "World"})
      assert result == "Hello World"
    end

    test "handles only variable" do
      result = Interpolation.interpolate("[name]", %{name: "Value"})
      assert result == "Value"
    end

    test "handles nil data gracefully" do
      result = Interpolation.interpolate("Hello [name]!", nil)
      assert result == "Hello [name]!"
    end

    test "handles non-binary input" do
      result = Interpolation.interpolate(123, %{})
      assert result == "123"
    end
  end

  describe "has_variables?/1" do
    test "returns true when text has variables" do
      assert Interpolation.has_variables?("Hello [name]!")
    end

    test "returns true when text has multiple variables" do
      assert Interpolation.has_variables?("[a] [b] [c]")
    end

    test "returns true for nested variable" do
      assert Interpolation.has_variables?("Value: [user.name]")
    end

    test "returns false when text has no variables" do
      refute Interpolation.has_variables?("Hello World!")
    end

    test "returns false for empty text" do
      refute Interpolation.has_variables?("")
    end

    test "returns false for non-string input" do
      refute Interpolation.has_variables?(123)
    end

    test "returns false for brackets without variable" do
      refute Interpolation.has_variables?("Array: []")
    end
  end

  describe "extract_variables/1" do
    test "extracts single variable" do
      result = Interpolation.extract_variables("Hello [name]!")
      assert result == ["name"]
    end

    test "extracts multiple variables" do
      result = Interpolation.extract_variables("[greeting] [name]!")
      assert result == ["greeting", "name"]
    end

    test "extracts nested variable paths" do
      result = Interpolation.extract_variables("Name: [user.name], City: [user.address.city]")
      assert result == ["user.name", "user.address.city"]
    end

    test "returns empty list when no variables" do
      result = Interpolation.extract_variables("Hello World!")
      assert result == []
    end

    test "returns empty list for empty text" do
      result = Interpolation.extract_variables("")
      assert result == []
    end

    test "returns empty list for non-string input" do
      result = Interpolation.extract_variables(123)
      assert result == []
    end

    test "extracts duplicates" do
      result = Interpolation.extract_variables("[name] and [name]")
      assert result == ["name", "name"]
    end
  end

  describe "get_variable_value/2" do
    test "gets simple value" do
      result = Interpolation.get_variable_value(%{name: "Alice"}, "name")
      assert result == "Alice"
    end

    test "gets nested value" do
      result = Interpolation.get_variable_value(%{user: %{name: "Bob"}}, "user.name")
      assert result == "Bob"
    end

    test "returns placeholder for missing value" do
      result = Interpolation.get_variable_value(%{}, "missing")
      assert result == "[missing]"
    end

    test "returns placeholder for missing nested value" do
      result = Interpolation.get_variable_value(%{user: %{}}, "user.name")
      assert result == "[user.name]"
    end

    test "formats integer values" do
      result = Interpolation.get_variable_value(%{count: 42}, "count")
      assert result == "42"
    end

    test "formats float values" do
      result = Interpolation.get_variable_value(%{price: 19.99}, "price")
      assert result == "19.99"
    end
  end

  describe "integration scenarios" do
    test "report title with date" do
      data = %{
        report_name: "Sales Report",
        date: ~D[2025-01-15]
      }
      template = "[report_name] - [date]"
      result = Interpolation.interpolate(template, data)

      assert result == "Sales Report - 2025-01-15"
    end

    test "invoice header with customer info" do
      data = %{
        invoice: %{
          number: "INV-001",
          customer: %{
            name: "Acme Corp",
            address: "123 Main St"
          }
        }
      }
      template = "Invoice [invoice.number] for [invoice.customer.name]"
      result = Interpolation.interpolate(template, data)

      assert result == "Invoice INV-001 for Acme Corp"
    end

    test "product listing with price" do
      data = %{
        product: "Widget",
        price: 29.99,
        quantity: 5
      }
      template = "[product] x [quantity] @ $[price]"
      result = Interpolation.interpolate(template, data)

      assert result == "Widget x 5 @ $29.99"
    end
  end
end
