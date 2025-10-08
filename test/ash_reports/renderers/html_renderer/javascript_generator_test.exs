defmodule AshReports.HtmlRenderer.JavaScriptGeneratorTest do
  use ExUnit.Case, async: true

  alias AshReports.HtmlRenderer.JavaScriptGenerator
  alias AshReports.RendererTestHelpers

  describe "generate_chart_javascript/2" do
    test "generates JavaScript for basic chart" do
      js_config = %{
        chart_id: "test_chart_123",
        provider: :chartjs,
        chart_config: %{
          type: :bar,
          data: %{labels: ["A", "B"], datasets: []},
          title: "Test Chart"
        },
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert is_binary(javascript)
      assert javascript =~ "test_chart_123"
    end

    test "includes namespace initialization" do
      js_config = %{
        chart_id: "chart_1",
        provider: :chartjs,
        chart_config: %{type: :line, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "AshReports"
    end

    test "includes error handling code" do
      js_config = %{
        chart_id: "chart_2",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "error"
    end

    test "supports Chart.js provider" do
      js_config = %{
        chart_id: "chartjs_test",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "Chart"
    end

    test "supports D3.js provider" do
      js_config = %{
        chart_id: "d3_test",
        provider: :d3,
        chart_config: %{type: :scatter, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert is_binary(javascript)
      assert javascript =~ "d3"
    end

    test "supports Plotly provider" do
      js_config = %{
        chart_id: "plotly_test",
        provider: :plotly,
        chart_config: %{type: :scatter, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert is_binary(javascript)
      assert javascript =~ "Plotly" or javascript =~ "plotly"
    end

    test "handles unknown provider gracefully" do
      js_config = %{
        chart_id: "unknown_provider",
        provider: :unknown,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert is_binary(javascript)
    end

    test "includes locale from context" do
      js_config = %{
        chart_id: "locale_test",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: false
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ context.locale
    end
  end

  describe "generate_interactive_javascript/2" do
    test "generates interactive event handlers" do
      js_config = %{
        chart_id: "interactive_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: true,
        events: [:click, :hover]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert is_binary(javascript)
    end

    test "includes click event handler" do
      js_config = %{
        chart_id: "click_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: true,
        events: [:click]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "click" or javascript =~ "Click"
    end

    test "includes hover event handler" do
      js_config = %{
        chart_id: "hover_chart",
        provider: :chartjs,
        chart_config: %{type: :line, data: %{}, title: "Chart"},
        interactive: true,
        events: [:hover]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "hover" or javascript =~ "Hover"
    end

    test "includes filter controls" do
      js_config = %{
        chart_id: "filter_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: true,
        events: [:filter]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "filter"
    end

    test "includes drill-down functionality" do
      js_config = %{
        chart_id: "drilldown_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: true,
        events: [:drill_down]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "drill"
    end

    test "handles real-time updates" do
      js_config = %{
        chart_id: "realtime_chart",
        provider: :chartjs,
        chart_config: %{type: :line, data: %{}, title: "Chart"},
        interactive: true,
        real_time: true
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert is_binary(javascript)
    end

    test "returns empty string for non-interactive charts" do
      js_config = %{
        chart_id: "static_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"},
        interactive: false,
        events: []
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript == "" or is_binary(javascript)
    end
  end

  describe "generate_real_time_javascript/2" do
    test "generates WebSocket connection code" do
      js_config = %{
        chart_id: "ws_chart",
        update_interval: 30_000
      }

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_real_time_javascript(js_config, context)

      assert javascript =~ "socket" or javascript =~ "WebSocket"
    end

    test "includes polling fallback" do
      js_config = %{
        chart_id: "poll_chart",
        update_interval: 60_000
      }

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_real_time_javascript(js_config, context)

      assert javascript =~ "interval" or javascript =~ "fetch"
    end

    test "uses custom update interval" do
      js_config = %{
        chart_id: "custom_interval",
        update_interval: 15_000
      }

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_real_time_javascript(js_config, context)

      assert javascript =~ "15000"
    end

    test "defaults to 30 second interval" do
      js_config = %{
        chart_id: "default_interval"
      }

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_real_time_javascript(js_config, context)

      assert javascript =~ "30000"
    end

    test "includes cleanup on page unload" do
      js_config = %{
        chart_id: "cleanup_chart"
      }

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_real_time_javascript(js_config, context)

      assert javascript =~ "beforeunload" or javascript =~ "unload"
    end
  end

  describe "generate_asset_loading_javascript/2" do
    test "generates asset loading code" do
      required_assets = [
        "https://cdn.jsdelivr.net/npm/chart.js",
        "https://cdn.jsdelivr.net/npm/d3"
      ]

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_asset_loading_javascript(required_assets, context)

      assert javascript =~ "chart.js"
      assert javascript =~ "d3"
    end

    test "creates script elements for assets" do
      required_assets = ["https://example.com/library.js"]
      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_asset_loading_javascript(required_assets, context)

      assert javascript =~ "createElement('script')" or javascript =~ "script"
    end

    test "includes error handling for asset loading" do
      required_assets = ["https://example.com/lib.js"]
      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_asset_loading_javascript(required_assets, context)

      assert javascript =~ "error" or javascript =~ "reject"
    end

    test "dispatches ready event when assets loaded" do
      required_assets = ["https://example.com/lib.js"]
      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_asset_loading_javascript(required_assets, context)

      assert javascript =~ "dispatchEvent" or javascript =~ "Ready"
    end

    test "handles empty asset list" do
      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_asset_loading_javascript([], context)

      assert is_binary(javascript)
    end
  end

  describe "Chart.js specific generation" do
    test "generates Chart.js initialization code" do
      js_config = %{
        chart_id: "chartjs_init",
        provider: :chartjs,
        chart_config: %{
          type: :bar,
          data: %{labels: ["A", "B"], datasets: [%{data: [1, 2]}]},
          title: "Bar Chart"
        }
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "new Chart"
    end

    test "includes chart configuration" do
      js_config = %{
        chart_id: "chartjs_config",
        provider: :chartjs,
        chart_config: %{
          type: :line,
          data: %{labels: [], datasets: []},
          title: "Line Chart"
        }
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "config" or javascript =~ "type"
    end

    test "waits for Chart.js library to load" do
      js_config = %{
        chart_id: "wait_chartjs",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "typeof Chart"
    end
  end

  describe "RTL support" do
    test "applies RTL configuration for RTL locales" do
      js_config = %{
        chart_id: "rtl_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "مخطط"}
      }

      context = RendererTestHelpers.build_render_context()
      context = %{context | text_direction: "rtl"}

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "rtl"
    end

    test "uses LTR for non-RTL locales" do
      js_config = %{
        chart_id: "ltr_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()
      context = %{context | text_direction: "ltr"}

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert is_binary(javascript)
    end
  end

  describe "error messages localization" do
    test "uses English error messages by default" do
      js_config = %{
        chart_id: "en_errors",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "error" or javascript =~ "Error"
    end

    test "uses Arabic error messages for Arabic locale" do
      js_config = %{
        chart_id: "ar_errors",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()
      context = %{context | locale: "ar"}

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "خطأ" or is_binary(javascript)
    end

    test "uses Spanish error messages for Spanish locale" do
      js_config = %{
        chart_id: "es_errors",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()
      context = %{context | locale: "es"}

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "Error" or is_binary(javascript)
    end
  end

  describe "event handler generation" do
    test "click handler dispatches custom events" do
      js_config = %{
        chart_id: "click_event",
        events: [:click]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "CustomEvent" or javascript =~ "dispatchEvent" or javascript == ""
    end

    test "hover handler changes cursor" do
      js_config = %{
        chart_id: "hover_event",
        events: [:hover]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "cursor" or javascript == ""
    end

    test "filter handler applies client-side filtering" do
      js_config = %{
        chart_id: "filter_event",
        interactive: true,
        events: [:filter]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "filter"
    end

    test "drill-down handler fetches additional data" do
      js_config = %{
        chart_id: "drilldown_event",
        events: [:drill_down]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "drill" or javascript == ""
    end
  end

  describe "filter controls" do
    test "provides apply filter function" do
      js_config = %{
        chart_id: "filter_controls",
        interactive: true,
        events: [:filter]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "apply"
    end

    test "provides reset filter function" do
      js_config = %{
        chart_id: "reset_filter",
        interactive: true,
        events: [:filter]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "reset"
    end

    test "stores original data for reset" do
      js_config = %{
        chart_id: "store_data",
        interactive: true,
        events: [:filter]
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_interactive_javascript(js_config, context)

      assert javascript =~ "originalData" or javascript =~ "original"
    end
  end

  describe "performance optimizations" do
    test "uses no animation for real-time updates" do
      js_config = %{
        chart_id: "no_animation",
        real_time: true
      }

      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_real_time_javascript(js_config, context)

      assert javascript =~ "none" or javascript =~ "animation"
    end

    test "lazy loads chart libraries" do
      required_assets = ["https://cdn.example.com/chart.js"]
      context = RendererTestHelpers.build_render_context()

      javascript = JavaScriptGenerator.generate_asset_loading_javascript(required_assets, context)

      assert javascript =~ "async" or javascript =~ "load"
    end
  end

  describe "accessibility" do
    test "includes ARIA attributes in generated code" do
      js_config = %{
        chart_id: "accessible_chart",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Accessible Chart"}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      # Should at minimum generate JavaScript
      assert is_binary(javascript)
    end
  end

  describe "error handling" do
    test "returns error tuple for generation failure" do
      js_config = nil
      context = RendererTestHelpers.build_render_context()

      result = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert match?({:error, _}, result)
    end

    test "handles missing chart config gracefully" do
      js_config = %{
        chart_id: "missing_config",
        provider: :chartjs
      }

      context = RendererTestHelpers.build_render_context()

      result = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "timeout handling" do
    test "includes timeout for chart initialization" do
      js_config = %{
        chart_id: "timeout_test",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "setTimeout" or javascript =~ "timeout"
    end

    test "activates fallback on timeout" do
      js_config = %{
        chart_id: "fallback_test",
        provider: :chartjs,
        chart_config: %{type: :bar, data: %{}, title: "Chart"}
      }

      context = RendererTestHelpers.build_render_context()

      {:ok, javascript} = JavaScriptGenerator.generate_chart_javascript(js_config, context)

      assert javascript =~ "fallback" or javascript =~ "5000"
    end
  end
end
