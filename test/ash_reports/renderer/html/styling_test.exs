defmodule AshReports.Renderer.Html.StylingTest do
  use ExUnit.Case, async: true

  alias AshReports.Renderer.Html.Styling

  describe "render_track_size/1" do
    test "renders :auto" do
      assert Styling.render_track_size(:auto) == "auto"
    end

    test "renders string auto" do
      assert Styling.render_track_size("auto") == "auto"
    end

    test "renders fractional units" do
      assert Styling.render_track_size({:fr, 1}) == "1fr"
      assert Styling.render_track_size({:fr, 2}) == "2fr"
      assert Styling.render_track_size({:fr, 0.5}) == "0.5fr"
    end

    test "renders minmax" do
      assert Styling.render_track_size({:minmax, "100px", "1fr"}) == "minmax(100px, 1fr)"
      assert Styling.render_track_size({:minmax, :auto, {:fr, 1}}) == "minmax(auto, 1fr)"
    end

    test "renders min-content and max-content" do
      assert Styling.render_track_size({:min_content}) == "min-content"
      assert Styling.render_track_size({:max_content}) == "max-content"
    end

    test "renders fit-content" do
      assert Styling.render_track_size({:fit_content, "200px"}) == "fit-content(200px)"
    end

    test "passes through string values" do
      assert Styling.render_track_size("100pt") == "100pt"
      assert Styling.render_track_size("20%") == "20%"
      assert Styling.render_track_size("1fr") == "1fr"
    end

    test "renders numbers as pixels" do
      assert Styling.render_track_size(100) == "100px"
      assert Styling.render_track_size(50.5) == "50.5px"
    end
  end

  describe "render_track_sizes/1" do
    test "renders list of track sizes" do
      assert Styling.render_track_sizes(["1fr", "2fr"]) == "1fr 2fr"
      assert Styling.render_track_sizes([:auto, {:fr, 1}, "100px"]) == "auto 1fr 100px"
    end

    test "renders empty list" do
      assert Styling.render_track_sizes([]) == ""
    end

    test "renders mixed types" do
      tracks = [{:fr, 1}, :auto, "100pt", 50]
      assert Styling.render_track_sizes(tracks) == "1fr auto 100pt 50px"
    end
  end

  describe "render_length/1" do
    test "converts pt to px" do
      assert Styling.render_length("10pt") == "10px"
      assert Styling.render_length("12.5pt") == "12.5px"
    end

    test "passes through px values" do
      assert Styling.render_length("20px") == "20px"
    end

    test "passes through other units" do
      assert Styling.render_length("50%") == "50%"
      assert Styling.render_length("2em") == "2em"
      assert Styling.render_length("1rem") == "1rem"
    end

    test "renders numbers as pixels" do
      assert Styling.render_length(15) == "15px"
      assert Styling.render_length(10.5) == "10.5px"
    end

    test "renders :auto" do
      assert Styling.render_length(:auto) == "auto"
      assert Styling.render_length("auto") == "auto"
    end
  end

  describe "render_text_align/1" do
    test "renders horizontal alignments" do
      assert Styling.render_text_align(:left) == "left"
      assert Styling.render_text_align(:center) == "center"
      assert Styling.render_text_align(:right) == "right"
      assert Styling.render_text_align(:justify) == "justify"
    end

    test "extracts horizontal from tuple" do
      assert Styling.render_text_align({:left, :top}) == "left"
      assert Styling.render_text_align({:center, :middle}) == "center"
      assert Styling.render_text_align({:right, :bottom}) == "right"
    end

    test "passes through strings" do
      assert Styling.render_text_align("center") == "center"
    end

    test "defaults unknown to left" do
      assert Styling.render_text_align(:unknown) == "left"
    end
  end

  describe "render_vertical_align/1" do
    test "renders vertical alignments" do
      assert Styling.render_vertical_align(:top) == "top"
      assert Styling.render_vertical_align(:middle) == "middle"
      assert Styling.render_vertical_align(:bottom) == "bottom"
    end

    test "passes through strings" do
      assert Styling.render_vertical_align("middle") == "middle"
    end

    test "defaults unknown to middle" do
      assert Styling.render_vertical_align(:unknown) == "middle"
    end
  end

  describe "render_justify_items/1" do
    test "maps horizontal to CSS Grid values" do
      assert Styling.render_justify_items(:left) == "start"
      assert Styling.render_justify_items(:center) == "center"
      assert Styling.render_justify_items(:right) == "end"
    end

    test "passes through start/end" do
      assert Styling.render_justify_items(:start) == "start"
      assert Styling.render_justify_items(:end) == "end"
    end
  end

  describe "render_align_items/1" do
    test "maps vertical to CSS Grid values" do
      assert Styling.render_align_items(:top) == "start"
      assert Styling.render_align_items(:middle) == "center"
      assert Styling.render_align_items(:bottom) == "end"
    end

    test "passes through start/end" do
      assert Styling.render_align_items(:start) == "start"
      assert Styling.render_align_items(:end) == "end"
    end
  end

  describe "parse_alignment/1" do
    test "parses tuple alignment" do
      assert Styling.parse_alignment({:left, :top}) == {:left, :top}
      assert Styling.parse_alignment({:center, :middle}) == {:center, :middle}
    end

    test "parses horizontal alignment" do
      assert Styling.parse_alignment(:left) == {:left, nil}
      assert Styling.parse_alignment(:center) == {:center, nil}
      assert Styling.parse_alignment(:right) == {:right, nil}
    end

    test "parses vertical alignment" do
      assert Styling.parse_alignment(:top) == {nil, :top}
      assert Styling.parse_alignment(:middle) == {nil, :middle}
      assert Styling.parse_alignment(:bottom) == {nil, :bottom}
    end

    test "returns nil for unknown" do
      assert Styling.parse_alignment(:unknown) == {nil, nil}
    end
  end

  describe "render_color/1" do
    test "passes through hex colors" do
      assert Styling.render_color("#ff0000") == "#ff0000"
      assert Styling.render_color("#fff") == "#fff"
    end

    test "passes through named colors" do
      assert Styling.render_color("red") == "red"
      assert Styling.render_color("blue") == "blue"
    end

    test "converts atom colors to strings" do
      assert Styling.render_color(:red) == "red"
      assert Styling.render_color(:blue) == "blue"
    end

    test "renders :none as transparent" do
      assert Styling.render_color(:none) == "transparent"
    end

    test "renders nil as transparent" do
      assert Styling.render_color(nil) == "transparent"
    end
  end

  describe "evaluate_fill/2" do
    test "returns static colors unchanged" do
      assert Styling.evaluate_fill("#ff0000", %{}) == "#ff0000"
      assert Styling.evaluate_fill(:red, %{}) == :red
    end

    test "returns nil unchanged" do
      assert Styling.evaluate_fill(nil, %{}) == nil
    end

    test "returns :none unchanged" do
      assert Styling.evaluate_fill(:none, %{}) == :none
    end

    test "evaluates zero-arity functions" do
      fun = fn -> "#eee" end
      assert Styling.evaluate_fill(fun, %{}) == "#eee"
    end

    test "evaluates context functions" do
      fun = fn ctx -> if ctx.row_index == 0, do: "#eee", else: "#fff" end
      assert Styling.evaluate_fill(fun, %{row_index: 0}) == "#eee"
      assert Styling.evaluate_fill(fun, %{row_index: 1}) == "#fff"
    end

    test "handles function errors gracefully" do
      fun = fn _ctx -> raise "error" end
      assert Styling.evaluate_fill(fun, %{}) == nil
    end
  end

  describe "render_stroke/1" do
    test "renders :none" do
      assert Styling.render_stroke(:none) == "none"
    end

    test "renders nil as none" do
      assert Styling.render_stroke(nil) == "none"
    end

    test "passes through string strokes" do
      assert Styling.render_stroke("1px solid black") == "1px solid black"
    end

    test "renders stroke with thickness and paint" do
      stroke = %{thickness: "2pt", paint: "#000"}
      assert Styling.render_stroke(stroke) == "2px solid #000"
    end

    test "renders stroke with thickness only" do
      stroke = %{thickness: "1pt"}
      assert Styling.render_stroke(stroke) == "1px solid currentColor"
    end

    test "renders stroke with dash style" do
      stroke = %{thickness: "1pt", dash: :dashed}
      assert Styling.render_stroke(stroke) == "1px dashed currentColor"
    end

    test "renders stroke with all properties" do
      stroke = %{thickness: "2pt", paint: "red", dash: :dotted}
      assert Styling.render_stroke(stroke) == "2px dotted red"
    end

    test "defaults to 1px solid currentColor" do
      assert Styling.render_stroke(%{}) == "1px solid currentColor"
    end
  end

  describe "render_dash_style/1" do
    test "renders standard styles" do
      assert Styling.render_dash_style(:solid) == "solid"
      assert Styling.render_dash_style(:dashed) == "dashed"
      assert Styling.render_dash_style(:dotted) == "dotted"
      assert Styling.render_dash_style(:double) == "double"
    end

    test "renders string styles" do
      assert Styling.render_dash_style("solid") == "solid"
      assert Styling.render_dash_style("dashed") == "dashed"
      assert Styling.render_dash_style("dotted") == "dotted"
    end

    test "maps dash-dot to dashed" do
      assert Styling.render_dash_style("dash-dot") == "dashed"
    end

    test "defaults unknown to solid" do
      assert Styling.render_dash_style(:unknown) == "solid"
    end
  end

  describe "render_font_weight/1" do
    test "renders named weights" do
      assert Styling.render_font_weight(:normal) == "normal"
      assert Styling.render_font_weight(:bold) == "bold"
    end

    test "renders numeric weight keywords" do
      assert Styling.render_font_weight(:light) == "300"
      assert Styling.render_font_weight(:medium) == "500"
      assert Styling.render_font_weight(:semibold) == "600"
    end

    test "passes through string weights" do
      assert Styling.render_font_weight("700") == "700"
    end

    test "renders numeric weights" do
      assert Styling.render_font_weight(400) == "400"
      assert Styling.render_font_weight(700) == "700"
    end

    test "defaults unknown to normal" do
      assert Styling.render_font_weight(:unknown) == "normal"
    end
  end

  describe "render_direction/1" do
    test "renders atom directions" do
      assert Styling.render_direction(:ttb) == "column"
      assert Styling.render_direction(:btt) == "column-reverse"
      assert Styling.render_direction(:ltr) == "row"
      assert Styling.render_direction(:rtl) == "row-reverse"
    end

    test "renders string directions" do
      assert Styling.render_direction("ttb") == "column"
      assert Styling.render_direction("btt") == "column-reverse"
      assert Styling.render_direction("ltr") == "row"
      assert Styling.render_direction("rtl") == "row-reverse"
    end

    test "defaults unknown to column" do
      assert Styling.render_direction(:unknown) == "column"
    end
  end

  describe "escape_html/1" do
    test "escapes ampersand" do
      assert Styling.escape_html("A & B") == "A &amp; B"
    end

    test "escapes less than" do
      assert Styling.escape_html("a < b") == "a &lt; b"
    end

    test "escapes greater than" do
      assert Styling.escape_html("a > b") == "a &gt; b"
    end

    test "escapes double quotes" do
      assert Styling.escape_html(~s("hello")) == "&quot;hello&quot;"
    end

    test "escapes single quotes" do
      assert Styling.escape_html("it's") == "it&#39;s"
    end

    test "escapes multiple special characters" do
      input = "<script>alert('XSS & attack')</script>"
      expected = "&lt;script&gt;alert(&#39;XSS &amp; attack&#39;)&lt;/script&gt;"
      assert Styling.escape_html(input) == expected
    end

    test "handles non-string input" do
      assert Styling.escape_html(123) == "123"
      assert Styling.escape_html(:atom) == "atom"
    end
  end

  describe "sanitize_css_value/1" do
    test "passes through safe CSS values" do
      assert Styling.sanitize_css_value("#ff0000") == "#ff0000"
      assert Styling.sanitize_css_value("10px") == "10px"
      assert Styling.sanitize_css_value("red") == "red"
      assert Styling.sanitize_css_value("1fr") == "1fr"
      assert Styling.sanitize_css_value("100%") == "100%"
    end

    test "passes through CSS functions" do
      assert Styling.sanitize_css_value("rgb(255, 0, 0)") == "rgb(255, 0, 0)"
      assert Styling.sanitize_css_value("rgba(0, 0, 0, 0.5)") == "rgba(0, 0, 0, 0.5)"
    end

    test "removes semicolons to prevent property injection" do
      assert Styling.sanitize_css_value("red; display: none") == "red display none"
    end

    test "removes curly braces to prevent rule injection" do
      assert Styling.sanitize_css_value("red } .admin { display: none") == "red  .admin  display none"
    end

    test "removes colons in values" do
      assert Styling.sanitize_css_value("url(javascript:alert(1))") == "url(javascriptalert(1))"
    end

    test "removes angle brackets" do
      assert Styling.sanitize_css_value("<style>") == "style"
      assert Styling.sanitize_css_value("</style>") == "/style"
    end

    test "removes CSS comment markers" do
      assert Styling.sanitize_css_value("red /* comment */ blue") == "red  comment  blue"
    end

    test "removes backslashes" do
      assert Styling.sanitize_css_value("\\0041") == "0041"
    end

    test "handles complex injection attempts" do
      # Attempt to inject new CSS rule
      malicious = "red; } .admin { display: none; } .x {"
      sanitized = Styling.sanitize_css_value(malicious)
      refute String.contains?(sanitized, ";")
      refute String.contains?(sanitized, "{")
      refute String.contains?(sanitized, "}")
    end

    test "sanitization is applied by render_color" do
      # render_color should sanitize string colors
      result = Styling.render_color("red; display: none")
      refute String.contains?(result, ";")
    end

    test "sanitization is applied by render_stroke" do
      # render_stroke should sanitize string strokes
      result = Styling.render_stroke("1px solid black; display: none")
      refute String.contains?(result, ";")
    end

    test "sanitization is applied by render_length" do
      # render_length should sanitize string lengths
      result = Styling.render_length("10px; display: none")
      refute String.contains?(result, ";")
    end

    test "sanitization is applied by render_track_size" do
      # render_track_size should sanitize string sizes
      result = Styling.render_track_size("1fr; display: none")
      refute String.contains?(result, ";")
    end

    test "handles non-string input" do
      assert Styling.sanitize_css_value(123) == "123"
      assert Styling.sanitize_css_value(:atom) == "atom"
    end
  end
end
