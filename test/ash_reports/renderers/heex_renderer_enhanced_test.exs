defmodule AshReports.HeexRendererEnhancedTest do
  @moduledoc """
  Test suite for the HeexRendererEnhanced module.

  Tests enhanced HEEX rendering with LiveView chart component integration,
  code generation, and asset management features.
  """

  use ExUnit.Case, async: true

  alias AshReports.HeexRendererEnhanced
  alias AshReports.{RenderContext, Report, Band}
  alias AshReports.Element.Label

  # Test helper functions

  defp build_test_context(opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")
    text_direction = Keyword.get(opts, :text_direction, "ltr")
    charts = Keyword.get(opts, :charts, [])

    report = %Report{
      name: :test_report,
      title: "Test Report",
      bands: [
        %Band{
          name: :header,
          type: :header,
          elements: [
            %Label{name: :title, text: "Test"}
          ]
        }
      ]
    }

    data_result = %{
      records: [%{name: "Test", value: 100}],
      variables: %{},
      metadata: %{chart_configs: charts}
    }

    config = %{
      format: :heex_enhanced,
      locale: locale,
      text_direction: text_direction,
      charts: charts
    }

    RenderContext.new(report, data_result, config)
    |> Map.put(:locale, locale)
    |> Map.put(:text_direction, text_direction)
  end

  defp build_test_chart_config do
    %{
      type: :bar,
      data: [%{label: "Q1", value: 100}],
      title: "Test Chart",
      interactive: true,
      real_time: false,
      interactions: [:click, :hover],
      update_interval: 30_000
    }
  end

  describe "render_with_context/2 - enhanced rendering" do
    test "renders with LiveView chart components" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert is_binary(result.content)
      assert is_map(result.metadata)
      assert is_map(result.components)
    end

    test "integrates with base HEEX renderer" do
      context = build_test_context()

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      # Should have base HEEX content
      assert String.contains?(result.content, "ash-report")
    end

    test "adds LiveView-specific metadata" do
      context = build_test_context()

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      metadata = result.metadata
      assert metadata.renderer == :heex_enhanced
      assert metadata.chart_integration == true
      assert metadata.liveview_components == true
      assert metadata.real_time_capable == true
      assert metadata.interactive_features == true
    end

    test "generates proper hooks registration" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      # Should include assets section with hooks
      assert String.contains?(result.content, "LiveView Chart Assets")
    end

    test "includes chart CSS assets" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert String.contains?(result.content, "<style>")
    end

    test "handles multiple charts" do
      chart1 = %{build_test_chart_config() | title: "Chart 1"}
      chart2 = %{build_test_chart_config() | title: "Chart 2"}
      context = build_test_context(charts: [chart1, chart2])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert result.components.count == 2
      assert length(result.components.components) == 2
    end

    test "preserves base template structure" do
      context = build_test_context()

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      # Should maintain HEEX structure
      assert is_binary(result.content)
      assert String.length(result.content) > 0
    end

    test "adds real-time capabilities" do
      chart = %{build_test_chart_config() | real_time: true}
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert result.metadata.real_time_capable == true
    end

    test "handles missing chart configs gracefully" do
      context = build_test_context(charts: [])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert result.components.count == 0
      assert result.components.components == []
    end

    test "generates unique component IDs" do
      chart1 = build_test_chart_config()
      chart2 = build_test_chart_config()
      context = build_test_context(charts: [chart1, chart2])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      content = Enum.join(result.components.components, "\n")
      assert String.contains?(content, "chart_0")
      assert String.contains?(content, "chart_1")
    end
  end

  describe "generate_liveview_mount/1" do
    test "generates valid mount/3 function" do
      dashboard_config = %{real_time: true}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      assert is_binary(result)
      assert String.contains?(result, "def mount")
      assert String.contains?(result, "_params, _session, socket")
    end

    test "includes dashboard initialization" do
      dashboard_config = %{title: "My Dashboard"}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      assert String.contains?(result, "assign(:dashboard_config")
      assert String.contains?(result, "assign(:charts")
      assert String.contains?(result, "assign(:real_time_enabled")
    end

    test "sets up PubSub subscriptions" do
      dashboard_config = %{real_time: true}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      assert String.contains?(result, "Phoenix.PubSub.subscribe")
      assert String.contains?(result, "dashboard_updates")
    end

    test "configures real-time updates" do
      dashboard_config = %{real_time: true}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      assert String.contains?(result, "real_time_enabled, true")
    end

    test "handles missing dashboard config" do
      dashboard_config = %{}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      assert is_binary(result)
      assert String.contains?(result, "def mount")
      assert String.contains?(result, "real_time_enabled, false")
    end

    test "preserves Elixir syntax" do
      dashboard_config = %{real_time: true}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      # Should be valid Elixir code structure
      assert String.contains?(result, "def ")
      assert String.contains?(result, "end")
      assert String.contains?(result, "socket")
    end

    test "formats code properly" do
      dashboard_config = %{real_time: true}

      result = HeexRendererEnhanced.generate_liveview_mount(dashboard_config)

      # Should have proper indentation
      assert String.contains?(result, "  ")
      # Should have line breaks
      assert String.contains?(result, "\n")
    end
  end

  describe "generate_liveview_handle_info/0" do
    test "generates handle_info for chart updates" do
      result = HeexRendererEnhanced.generate_liveview_handle_info()

      assert is_binary(result)
      assert String.contains?(result, "def handle_info({:chart_data_update")
    end

    test "generates handle_info for dashboard updates" do
      result = HeexRendererEnhanced.generate_liveview_handle_info()

      assert String.contains?(result, "def handle_info({:dashboard_update")
    end

    test "generates handle_info for errors" do
      result = HeexRendererEnhanced.generate_liveview_handle_info()

      assert String.contains?(result, "def handle_info({:chart_error")
    end

    test "includes send_update calls" do
      result = HeexRendererEnhanced.generate_liveview_handle_info()

      assert String.contains?(result, "send_update")
      assert String.contains?(result, "AshReports.LiveView.ChartLiveComponent")
    end

    test "preserves Elixir syntax" do
      result = HeexRendererEnhanced.generate_liveview_handle_info()

      assert String.contains?(result, "def handle_info")
      assert String.contains?(result, "end")
      assert String.contains?(result, "{:noreply, socket}")
    end
  end

  describe "chart component generation" do
    test "generates single chart component" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      components = result.components.components
      assert length(components) == 1
      component_heex = List.first(components)
      assert String.contains?(component_heex, "live_component")
    end

    test "includes proper chart_config attributes" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
      assert String.contains?(component_heex, "chart_config:")
      assert String.contains?(component_heex, "type: :bar")
    end

    test "sets interactive flag" do
      chart = %{build_test_chart_config() | interactive: true}
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
      assert String.contains?(component_heex, "interactive: true")
    end

    test "sets real-time flag" do
      chart = %{build_test_chart_config() | real_time: true}
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
      assert String.contains?(component_heex, "real_time: true")
    end

    test "assigns unique IDs" do
      charts = [build_test_chart_config(), build_test_chart_config()]
      context = build_test_context(charts: charts)

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      [component1, component2] = result.components.components
      assert String.contains?(component1, "id: \"chart_0\"")
      assert String.contains?(component2, "id: \"chart_1\"")
    end

    test "preserves locale settings" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart], locale: "fr")

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
      assert String.contains?(component_heex, "locale: \"fr\"")
    end

    test "handles chart provider selection" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
    end

    test "includes update_interval for real-time" do
      chart = %{build_test_chart_config() | real_time: true, update_interval: 5000}
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
      assert String.contains?(component_heex, "update_interval: 5000")
    end

    test "generates valid HEEX syntax" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      component_heex = List.first(result.components.components)
      assert String.contains?(component_heex, "<%=")
      assert String.contains?(component_heex, "%>")
    end
  end

  describe "asset integration" do
    test "adds chart CSS to template" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert String.contains?(result.content, "<style>")
    end

    test "adds hook registration JavaScript" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert String.contains?(result.content, "<script type=\"module\">")
    end

    test "includes module type for JS" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert String.contains?(result.content, "type=\"module\"")
    end

    test "generates proper style tags" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert String.contains?(result.content, "</style>")
    end

    test "preserves existing assets" do
      context = build_test_context()

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      # Base content should be preserved
      assert is_binary(result.content)
      assert String.length(result.content) > 0
    end

    test "handles RTL layouts" do
      chart = build_test_chart_config()
      context = build_test_context(charts: [chart], text_direction: "rtl")

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      # Should include RTL-aware content
      assert String.contains?(result.content, "rtl")
    end
  end

  describe "error handling" do
    test "handles base renderer gracefully with nil report" do
      # Create a context with nil report
      invalid_context = %RenderContext{
        report: nil,
        records: [],
        config: %{},
        variables: %{},
        metadata: %{}
      }

      # Base renderer doesn't fail, it just creates empty content
      assert {:ok, result} = HeexRendererEnhanced.render_with_context(invalid_context)
      assert is_binary(result.content)
    end

    test "handles invalid chart config" do
      # Chart config with missing required fields will cause KeyError
      invalid_chart = %{type: nil, data: nil}
      context = build_test_context(charts: [invalid_chart])

      # This will raise KeyError due to missing :title field
      # Test that it fails predictably
      assert_raise KeyError, fn ->
        HeexRendererEnhanced.render_with_context(context)
      end
    end

    test "handles charts with complete but empty config" do
      # Chart config with all fields but empty/nil values
      empty_chart = %{
        type: :bar,
        data: [],
        title: nil,
        interactive: false,
        real_time: false,
        interactions: [],
        update_interval: 30_000
      }

      context = build_test_context(charts: [empty_chart])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)
      assert is_map(result.components)
      assert result.components.count == 1
    end

    test "gracefully degrades without charts" do
      context = build_test_context(charts: [])

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)

      assert result.components.count == 0
      # Should still have base content
      assert is_binary(result.content)
    end
  end

  describe "renderer behavior callbacks" do
    test "render/3 provides backward compatibility" do
      report = build_test_context().report
      data = [%{name: "Test", value: 100}]

      assert {:ok, content} = HeexRendererEnhanced.render(report, data, [])
      assert is_binary(content)
    end

    test "content_type/0 returns text/html" do
      assert HeexRendererEnhanced.content_type() == "text/html"
    end

    test "file_extension/0 returns heex" do
      assert HeexRendererEnhanced.file_extension() == "heex"
    end

    test "supports_streaming?/0 returns true" do
      assert HeexRendererEnhanced.supports_streaming?() == true
    end
  end

  describe "realistic data integration" do
    setup do
      AshReports.RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
    end

    test "renders customer data with LiveView integration" do
      customers = AshReports.RealisticTestHelpers.list_customers(limit: 10)
      simple_customers = AshReports.RealisticTestHelpers.to_simple_maps(customers)

      context = build_test_context(%{records: simple_customers})

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)
      assert is_binary(result.content)
      assert String.contains?(result.content, "ash-report")
    end

    test "handles chart data from realistic invoices" do
      invoices = AshReports.RealisticTestHelpers.list_invoices(limit: 15)

      chart_data =
        invoices
        |> Enum.map(fn inv ->
          %{x: Date.to_string(inv.date), y: Decimal.to_float(inv.total)}
        end)

      chart_config = build_test_chart_config(%{data: chart_data})
      context = build_test_context(%{chart_configs: [chart_config]})

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context)
      assert result.metadata.chart_count > 0
    end

    test "renders product list with enhanced features" do
      products = AshReports.RealisticTestHelpers.list_products(limit: 20, load: [:category])
      simple_products = AshReports.RealisticTestHelpers.to_simple_maps(products)

      context = build_test_context(%{records: simple_products})

      assert {:ok, result} = HeexRendererEnhanced.render_with_context(context, [])
      assert is_binary(result.content)
      assert result.metadata.live_view_required == true
    end
  end
end
