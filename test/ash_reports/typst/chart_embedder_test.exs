defmodule AshReports.Typst.ChartEmbedderTest do
  use ExUnit.Case, async: false

  alias AshReports.Charts
  alias AshReports.Charts.Config
  alias AshReports.Typst.ChartEmbedder

  @simple_svg "<svg width=\"100\" height=\"100\"><circle cx=\"50\" cy=\"50\" r=\"40\"/></svg>"

  describe "embed/2" do
    test "embeds SVG with base64 encoding by default" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg)

      assert typst =~ "#image.decode("
      assert typst =~ "format: \"svg\""
      # Shouldn't use file path
      refute typst =~ "#image("
    end

    test "embeds SVG with width option" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, width: "100%")

      assert typst =~ "width: 100%"
    end

    test "embeds SVG with height option" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, height: "400pt")

      assert typst =~ "height: 400pt"
    end

    test "embeds SVG with both width and height" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, width: "50%", height: "300pt")

      assert typst =~ "width: 50%"
      assert typst =~ "height: 300pt"
    end

    test "converts numeric dimensions to points" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, width: 600, height: 400)

      assert typst =~ "width: 600pt"
      assert typst =~ "height: 400pt"
    end

    test "adds title when provided" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, title: "Sales Report")

      assert typst =~ "#text(size: 14pt, weight: \"bold\")[Sales Report]"
    end

    test "adds caption when provided" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, caption: "Figure 1: Annual Sales")

      assert typst =~ "#text(size: 10pt, style: \"italic\")[Figure 1: Annual Sales]"
    end

    test "adds both title and caption" do
      {:ok, typst} =
        ChartEmbedder.embed(@simple_svg,
          title: "Sales Report",
          caption: "Figure 1: Data from Q1-Q4"
        )

      assert typst =~ "Sales Report"
      assert typst =~ "Figure 1: Data from Q1-Q4"
    end

    test "escapes special characters in title" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, title: "Q1 \"Actual\" #1")

      assert typst =~ "Q1 \\\"Actual\\\" \\#1"
    end

    test "escapes special characters in caption" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, caption: "[Important] Data #1")

      assert typst =~ "\\[Important\\] Data \\#1"
    end

    test "uses file encoding when explicitly requested" do
      {:ok, typst} = ChartEmbedder.embed(@simple_svg, encoding: :file)

      assert typst =~ "#image(\""
      assert typst =~ ".svg\")"
      refute typst =~ "#image.decode("
    end

    test "returns error for invalid SVG input" do
      assert {:error, :invalid_svg} = ChartEmbedder.embed(nil)
      assert {:error, :invalid_svg} = ChartEmbedder.embed(123)
      assert {:error, :invalid_svg} = ChartEmbedder.embed(%{})
    end

    test "uses file encoding for very large SVGs" do
      # Create a large SVG (>1MB)
      large_svg = String.duplicate(@simple_svg, 50_000)
      {:ok, typst} = ChartEmbedder.embed(large_svg)

      # Should fall back to file encoding
      assert typst =~ "#image(\""
      refute typst =~ "#image.decode("
    end
  end

  describe "embed_grid/2" do
    test "embeds multiple charts in grid layout" do
      charts = [
        {@simple_svg, [caption: "Chart 1"]},
        {@simple_svg, [caption: "Chart 2"]}
      ]

      {:ok, grid} = ChartEmbedder.embed_grid(charts)

      assert grid =~ "#grid("
      assert grid =~ "columns:"
      assert grid =~ "Chart 1"
      assert grid =~ "Chart 2"
    end

    test "uses custom column count" do
      charts = [
        {@simple_svg, []},
        {@simple_svg, []},
        {@simple_svg, []}
      ]

      {:ok, grid} = ChartEmbedder.embed_grid(charts, columns: 3)

      assert grid =~ "columns: (1fr, 1fr, 1fr)"
    end

    test "uses custom gutter" do
      charts = [
        {@simple_svg, []},
        {@simple_svg, []}
      ]

      {:ok, grid} = ChartEmbedder.embed_grid(charts, gutter: "20pt")

      assert grid =~ "gutter: 20pt"
    end

    test "uses custom column widths" do
      charts = [
        {@simple_svg, []},
        {@simple_svg, []}
      ]

      {:ok, grid} = ChartEmbedder.embed_grid(charts, column_widths: ["2fr", "1fr"])

      assert grid =~ "columns: (2fr, 1fr)"
    end

    test "preserves individual chart options in grid" do
      charts = [
        {@simple_svg, [title: "First", width: "100%"]},
        {@simple_svg, [title: "Second", width: "100%"]}
      ]

      {:ok, grid} = ChartEmbedder.embed_grid(charts)

      assert grid =~ "First"
      assert grid =~ "Second"
      assert grid =~ "width: 100%"
    end
  end

  describe "embed_flow/2" do
    test "embeds multiple charts in flow layout" do
      charts = [
        {@simple_svg, [caption: "Q1 Results"]},
        {@simple_svg, [caption: "Q2 Results"]}
      ]

      {:ok, flow} = ChartEmbedder.embed_flow(charts)

      assert flow =~ "Q1 Results"
      assert flow =~ "Q2 Results"
      # Default spacing
      assert flow =~ "#v(20pt)"
    end

    test "uses custom spacing" do
      charts = [
        {@simple_svg, []},
        {@simple_svg, []}
      ]

      {:ok, flow} = ChartEmbedder.embed_flow(charts, spacing: "30pt")

      assert flow =~ "#v(30pt)"
    end

    test "stacks charts vertically with spacing" do
      charts = [
        {@simple_svg, [title: "Chart 1"]},
        {@simple_svg, [title: "Chart 2"]},
        {@simple_svg, [title: "Chart 3"]}
      ]

      {:ok, flow} = ChartEmbedder.embed_flow(charts, spacing: "15pt")

      lines = String.split(flow, "\n")
      # Should have charts interspersed with spacing
      assert Enum.any?(lines, &String.contains?(&1, "Chart 1"))
      assert Enum.any?(lines, &String.contains?(&1, "Chart 2"))
      assert Enum.any?(lines, &String.contains?(&1, "Chart 3"))
      assert Enum.count(lines, &(&1 == "#v(15pt)")) == 2
    end
  end

  describe "generate_and_embed/4" do
    test "generates chart and embeds in one operation" do
      data = [%{category: "A", value: 10}, %{category: "B", value: 20}]
      config = %Config{title: "Test Chart", width: 600, height: 400}

      {:ok, typst} =
        ChartEmbedder.generate_and_embed(:bar, data, config, width: "100%", caption: "Sales Data")

      assert typst =~ "#image.decode("
      assert typst =~ "width: 100%"
      assert typst =~ "Sales Data"
    end

    test "passes chart generation errors through" do
      # Invalid chart type
      assert {:error, :not_found} =
               ChartEmbedder.generate_and_embed(:invalid, [], %Config{})
    end

    test "works with different chart types" do
      data = [%{x: 1, y: 10}, %{x: 2, y: 20}]
      config = %Config{width: 400, height: 300}

      {:ok, typst} = ChartEmbedder.generate_and_embed(:line, data, config, width: "80%")

      assert typst =~ "#image.decode("
      assert typst =~ "width: 80%"
    end

    test "works with chart config maps" do
      data = [%{category: "A", value: 10}]
      config = %{title: "Test", width: 500, height: 300}

      {:ok, typst} = ChartEmbedder.generate_and_embed(:bar, data, config, caption: "Figure 1")

      assert typst =~ "#image.decode("
      assert typst =~ "Figure 1"
    end
  end

  describe "integration" do
    test "full pipeline: generate chart with theme and embed with title and caption" do
      data = [
        %{category: "Q1", value: 1000},
        %{category: "Q2", value: 1500},
        %{category: "Q3", value: 1200}
      ]

      config = %Config{
        title: "Quarterly Sales",
        width: 600,
        height: 400,
        theme_name: :corporate
      }

      {:ok, typst} =
        ChartEmbedder.generate_and_embed(:bar, data, config,
          width: "100%",
          title: "Sales Performance",
          caption: "Figure 1: Quarterly sales for 2024"
        )

      # Should have Typst image code
      assert typst =~ "#image.decode("

      # Should have sizing
      assert typst =~ "width: 100%"

      # Should have title and caption
      assert typst =~ "Sales Performance"
      assert typst =~ "Figure 1: Quarterly sales for 2024"
    end

    test "multi-chart grid with different chart types" do
      bar_data = [%{category: "A", value: 10}]
      line_data = [%{x: 1, y: 10}, %{x: 2, y: 20}]
      config = %Config{width: 400, height: 300}

      {:ok, bar_svg} = Charts.generate(:bar, bar_data, config)
      {:ok, line_svg} = Charts.generate(:line, line_data, config)

      charts = [
        {bar_svg, [caption: "Bar Chart", width: "100%"]},
        {line_svg, [caption: "Line Chart", width: "100%"]}
      ]

      {:ok, grid} = ChartEmbedder.embed_grid(charts, columns: 2)

      assert grid =~ "#grid("
      assert grid =~ "Bar Chart"
      assert grid =~ "Line Chart"
    end
  end

  describe "SVG sanitization" do
    test "removes script tags from SVG" do
      malicious_svg = """
      <svg width="100" height="100">
        <script>alert('XSS')</script>
        <circle cx="50" cy="50" r="40"/>
      </svg>
      """

      {:ok, typst} = ChartEmbedder.embed(malicious_svg)
      decoded = Base.decode64!(extract_base64(typst))

      refute decoded =~ "<script>"
      refute decoded =~ "alert"
      assert decoded =~ "<circle"
    end

    test "removes event handler attributes" do
      malicious_svg = """
      <svg width="100" height="100">
        <circle cx="50" cy="50" r="40" onclick="alert('XSS')" onload="doEvil()"/>
      </svg>
      """

      {:ok, typst} = ChartEmbedder.embed(malicious_svg)
      decoded = Base.decode64!(extract_base64(typst))

      refute decoded =~ "onclick"
      refute decoded =~ "onload"
      refute decoded =~ "alert"
      assert decoded =~ "<circle"
    end

    test "removes javascript: protocol in hrefs" do
      malicious_svg = """
      <svg width="100" height="100">
        <a href="javascript:alert('XSS')">
          <circle cx="50" cy="50" r="40"/>
        </a>
      </svg>
      """

      {:ok, typst} = ChartEmbedder.embed(malicious_svg)
      decoded = Base.decode64!(extract_base64(typst))

      refute decoded =~ "javascript:"
      assert decoded =~ "<circle"
    end

    test "removes data:text/html URIs" do
      malicious_svg = """
      <svg width="100" height="100">
        <a href="data:text/html,<script>alert('XSS')</script>">
          <circle cx="50" cy="50" r="40"/>
        </a>
      </svg>
      """

      {:ok, typst} = ChartEmbedder.embed(malicious_svg)
      decoded = Base.decode64!(extract_base64(typst))

      refute decoded =~ "data:text/html"
      assert decoded =~ "<circle"
    end

    test "removes foreignObject elements" do
      malicious_svg = """
      <svg width="100" height="100">
        <foreignObject>
          <body xmlns="http://www.w3.org/1999/xhtml">
            <script>alert('XSS')</script>
          </body>
        </foreignObject>
        <circle cx="50" cy="50" r="40"/>
      </svg>
      """

      {:ok, typst} = ChartEmbedder.embed(malicious_svg)
      decoded = Base.decode64!(extract_base64(typst))

      refute decoded =~ "foreignObject"
      refute decoded =~ "alert"
      assert decoded =~ "<circle"
    end

    test "preserves safe SVG content" do
      safe_svg = """
      <svg width="200" height="200">
        <rect x="10" y="10" width="100" height="100" fill="blue"/>
        <text x="50" y="150" font-size="20">Safe Text</text>
        <path d="M 10 10 L 100 100" stroke="red"/>
      </svg>
      """

      {:ok, typst} = ChartEmbedder.embed(safe_svg)
      decoded = Base.decode64!(extract_base64(typst))

      assert decoded =~ "<rect"
      assert decoded =~ "<text"
      assert decoded =~ "<path"
      assert decoded =~ "Safe Text"
    end
  end

  # Helper to extract base64 from Typst image.decode() call
  defp extract_base64(typst) do
    # Extract base64 string from: #image.decode("BASE64", format: "svg")
    case Regex.run(~r/#image\.decode\("([^"]+)"/, typst) do
      [_, base64] -> base64
      _ -> raise "Could not extract base64 from: #{typst}"
    end
  end
end
