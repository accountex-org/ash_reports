defmodule AshReports.Renderer.Html.StackTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Stack
  alias AshReports.Layout.IR

  describe "render/2" do
    test "renders empty stack with Flexbox display" do
      ir = IR.stack(properties: %{dir: :ttb})
      result = Stack.render(ir)

      assert String.contains?(result, ~s(class="ash-stack"))
      assert String.contains?(result, "display: flex")
    end

    test "renders stack with default column direction" do
      ir = IR.stack(properties: %{})
      result = Stack.render(ir)

      assert String.contains?(result, "flex-direction: column")
    end

    test "renders stack with ttb direction as column" do
      ir = IR.stack(properties: %{dir: :ttb})
      result = Stack.render(ir)

      assert String.contains?(result, "flex-direction: column")
    end

    test "renders stack with btt direction as column-reverse" do
      ir = IR.stack(properties: %{dir: :btt})
      result = Stack.render(ir)

      assert String.contains?(result, "flex-direction: column-reverse")
    end

    test "renders stack with ltr direction as row" do
      ir = IR.stack(properties: %{dir: :ltr})
      result = Stack.render(ir)

      assert String.contains?(result, "flex-direction: row")
    end

    test "renders stack with rtl direction as row-reverse" do
      ir = IR.stack(properties: %{dir: :rtl})
      result = Stack.render(ir)

      assert String.contains?(result, "flex-direction: row-reverse")
    end

    test "renders stack with spacing as gap" do
      ir = IR.stack(properties: %{
        dir: :ttb,
        spacing: "10pt"
      })
      result = Stack.render(ir)

      assert String.contains?(result, "gap: 10px")
    end

    test "renders stack with numeric spacing" do
      ir = IR.stack(properties: %{
        dir: :ltr,
        spacing: 20
      })
      result = Stack.render(ir)

      assert String.contains?(result, "gap: 20px")
    end

    test "renders nested grid in stack" do
      nested_grid = IR.grid(properties: %{columns: ["1fr", "1fr"]})
      ir = IR.stack(
        properties: %{dir: :ttb},
        children: [nested_grid]
      )
      result = Stack.render(ir)

      assert String.contains?(result, ~s(class="ash-stack"))
      assert String.contains?(result, ~s(class="ash-grid"))
    end

    test "renders nested table in stack" do
      nested_table = IR.table(properties: %{columns: ["1fr"]})
      ir = IR.stack(
        properties: %{dir: :ttb},
        children: [nested_table]
      )
      result = Stack.render(ir)

      assert String.contains?(result, ~s(class="ash-stack"))
      assert String.contains?(result, ~s(class="ash-table"))
    end

    test "renders nested stack in stack" do
      nested_stack = IR.stack(properties: %{dir: :ltr, spacing: "5px"})
      ir = IR.stack(
        properties: %{dir: :ttb},
        children: [nested_stack]
      )
      result = Stack.render(ir)

      # Should have two ash-stack divs
      matches = Regex.scan(~r/class="ash-stack"/, result)
      assert length(matches) == 2
    end

    test "renders label content" do
      ir = IR.stack(
        properties: %{dir: :ttb},
        children: [%{text: "Hello World"}]
      )
      result = Stack.render(ir)

      assert String.contains?(result, ~s(<span class="ash-label">Hello World</span>))
    end

    test "renders field content" do
      ir = IR.stack(
        properties: %{dir: :ttb},
        children: [%{value: 42}]
      )
      result = Stack.render(ir)

      assert String.contains?(result, ~s(<span class="ash-field">42</span>))
    end
  end

  describe "build_styles/1" do
    test "builds style string with direction and spacing" do
      properties = %{dir: :ltr, spacing: "15px"}
      styles = Stack.build_styles(properties)

      assert String.contains?(styles, "display: flex")
      assert String.contains?(styles, "flex-direction: row")
      assert String.contains?(styles, "gap: 15px")
    end

    test "returns default styles for empty properties" do
      styles = Stack.build_styles(%{})

      assert String.contains?(styles, "display: flex")
      assert String.contains?(styles, "flex-direction: column")
    end
  end

  describe "render_direction/1" do
    test "renders :ttb as column" do
      assert Stack.render_direction(:ttb) == "column"
    end

    test "renders :btt as column-reverse" do
      assert Stack.render_direction(:btt) == "column-reverse"
    end

    test "renders :ltr as row" do
      assert Stack.render_direction(:ltr) == "row"
    end

    test "renders :rtl as row-reverse" do
      assert Stack.render_direction(:rtl) == "row-reverse"
    end

    test "renders string directions" do
      assert Stack.render_direction("ttb") == "column"
      assert Stack.render_direction("ltr") == "row"
    end

    test "defaults unknown directions to column" do
      assert Stack.render_direction(:unknown) == "column"
    end
  end

  describe "render_length/1" do
    test "renders :auto" do
      assert Stack.render_length(:auto) == "auto"
    end

    test "converts pt to px" do
      assert Stack.render_length("10pt") == "10px"
    end

    test "passes through px values" do
      assert Stack.render_length("20px") == "20px"
    end

    test "renders numbers as pixels" do
      assert Stack.render_length(15) == "15px"
    end
  end

  describe "escape_html/1" do
    test "escapes ampersand" do
      assert Stack.escape_html("A & B") == "A &amp; B"
    end

    test "escapes less than" do
      assert Stack.escape_html("a < b") == "a &lt; b"
    end

    test "escapes greater than" do
      assert Stack.escape_html("a > b") == "a &gt; b"
    end

    test "escapes double quotes" do
      assert Stack.escape_html(~s("hello")) == "&quot;hello&quot;"
    end

    test "escapes single quotes" do
      assert Stack.escape_html("it's") == "it&#39;s"
    end

    test "escapes multiple special characters" do
      input = "<script>alert('XSS & attack')</script>"
      expected = "&lt;script&gt;alert(&#39;XSS &amp; attack&#39;)&lt;/script&gt;"
      assert Stack.escape_html(input) == expected
    end
  end
end
