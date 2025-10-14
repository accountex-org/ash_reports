defmodule AshReports.HeexRenderer.ChartTemplatesTest do
  @moduledoc """
  Test suite for the ChartTemplates module.

  Tests all template types, localization, and RTL support for HEEX chart
  components in the AshReports system.
  """

  use ExUnit.Case, async: true

  alias AshReports.HeexRenderer.ChartTemplates
  alias AshReports.{RenderContext, Report, Band}
  alias AshReports.Element.Label

  # Test helper functions

  defp build_test_context(opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")
    text_direction = Keyword.get(opts, :text_direction, "ltr")

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
      metadata: %{}
    }

    config = %{
      format: :heex,
      locale: locale,
      text_direction: text_direction
    }

    RenderContext.new(report, data_result, config)
    |> Map.put(:locale, locale)
    |> Map.put(:text_direction, text_direction)
  end

  describe "single_chart/2" do
    test "generates basic chart container" do
      context = build_test_context()
      config = %{chart_id: "test_chart"}

      result = ChartTemplates.single_chart(config, context)

      assert is_binary(result)
      assert String.contains?(result, "ash-single-chart-container")
      assert String.contains?(result, "data-chart-id=\"test_chart\"")
    end

    test "includes chart title when provided" do
      context = build_test_context()
      config = %{chart_id: "sales", title: "Sales Report"}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "chart-header")
      assert String.contains?(result, "chart-title")
      assert String.contains?(result, "Sales Report")
    end

    test "shows real-time indicator when enabled" do
      context = build_test_context()
      config = %{chart_id: "live", real_time: true}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "real-time-indicator")
      assert String.contains?(result, "status-dot")
      assert String.contains?(result, "Live")
    end

    test "hides real-time indicator when disabled" do
      context = build_test_context()
      config = %{chart_id: "static", real_time: false}

      result = ChartTemplates.single_chart(config, context)

      # Template contains conditional HEEX code, check that condition is false
      assert String.contains?(result, "real_time={false}")
    end

    test "includes chart controls when enabled" do
      context = build_test_context()
      config = %{chart_id: "controlled", show_controls: true}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "chart-controls")
    end

    test "hides controls when disabled" do
      context = build_test_context()
      config = %{chart_id: "simple", show_controls: false}

      result = ChartTemplates.single_chart(config, context)

      # Template contains conditional HEEX code, check that condition evaluates to false
      assert String.contains?(result, "<%= if false do %>")
    end

    test "applies RTL class correctly" do
      context = build_test_context(text_direction: "rtl")
      config = %{chart_id: "rtl_test"}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "rtl")
    end

    test "applies LTR class for default direction" do
      context = build_test_context(text_direction: "ltr")
      config = %{chart_id: "ltr_test"}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "ltr")
    end

    test "includes live_component call" do
      context = build_test_context()
      config = %{chart_id: "component_test"}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "live_component")
      assert String.contains?(result, "AshReports.LiveView.ChartLiveComponent")
    end

    test "sets chart_id properly in component" do
      context = build_test_context()
      config = %{chart_id: "my_chart"}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "id={\"my_chart\"}")
    end

    test "preserves locale in component" do
      context = build_test_context(locale: "fr")
      config = %{chart_id: "french"}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "locale=\"fr\"")
    end

    test "handles missing title gracefully" do
      context = build_test_context()
      config = %{chart_id: "no_title"}

      result = ChartTemplates.single_chart(config, context)

      assert is_binary(result)
      assert String.contains?(result, "data-chart-id=\"no_title\"")
    end
  end

  describe "dashboard_grid/2" do
    test "generates grid container" do
      context = build_test_context()
      config = %{charts: [], grid_columns: 12}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "ash-dashboard-grid")
    end

    test "creates grid with specified columns" do
      context = build_test_context()
      config = %{charts: [], grid_columns: 16}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "data-grid-columns=\"16\"")
      assert String.contains?(result, "repeat(16, 1fr)")
    end

    test "renders multiple charts" do
      context = build_test_context()

      config = %{
        charts: [
          %{id: "chart1", type: :line, cols: 6},
          %{id: "chart2", type: :pie, cols: 6}
        ]
      }

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "chart1")
      assert String.contains?(result, "chart2")
    end

    test "applies grid-column spans" do
      context = build_test_context()
      config = %{charts: [%{id: "wide", cols: 12}]}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "span 12")
    end

    test "shows dashboard header" do
      context = build_test_context()
      config = %{title: "My Dashboard", charts: []}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "dashboard-header")
      assert String.contains?(result, "My Dashboard")
    end

    test "includes real-time status when enabled" do
      context = build_test_context()
      config = %{charts: [], real_time: true}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "dashboard-controls")
      assert String.contains?(result, "real-time-status")
      assert String.contains?(result, "status-indicator active")
    end

    test "preserves chart order" do
      context = build_test_context()

      config = %{
        charts: [
          %{id: "first", cols: 4},
          %{id: "second", cols: 4},
          %{id: "third", cols: 4}
        ]
      }

      result = ChartTemplates.dashboard_grid(config, context)

      first_pos = :binary.match(result, "first") |> elem(0)
      second_pos = :binary.match(result, "second") |> elem(0)
      third_pos = :binary.match(result, "third") |> elem(0)

      assert first_pos < second_pos
      assert second_pos < third_pos
    end

    test "handles empty charts array" do
      context = build_test_context()
      config = %{charts: []}

      result = ChartTemplates.dashboard_grid(config, context)

      assert is_binary(result)
      assert String.contains?(result, "dashboard-grid")
    end

    test "applies RTL layout" do
      context = build_test_context(text_direction: "rtl")
      config = %{charts: []}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "rtl")
    end

    test "sets dashboard ID" do
      context = build_test_context()
      config = %{dashboard_id: "main_dashboard", charts: []}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "data-dashboard-id=\"main_dashboard\"")
    end

    test "localizes dashboard title" do
      context = build_test_context(locale: "es")
      config = %{charts: []}

      result = ChartTemplates.dashboard_grid(config, context)

      # Should use "Panel de control" for Spanish
      assert String.contains?(result, "Panel de control")
    end

    test "handles custom grid columns" do
      context = build_test_context()
      config = %{charts: [%{id: "test", cols: 8}], grid_columns: 24}

      result = ChartTemplates.dashboard_grid(config, context)

      assert String.contains?(result, "repeat(24, 1fr)")
      assert String.contains?(result, "span 8")
    end
  end

  describe "filter_dashboard/2" do
    test "generates dashboard with sidebar" do
      context = build_test_context()
      config = %{main_chart: %{id: "main"}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "ash-filter-dashboard")
      assert String.contains?(result, "dashboard-sidebar")
      assert String.contains?(result, "dashboard-main")
    end

    test "positions sidebar left by default" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "sidebar-left")
    end

    test "positions sidebar right when specified" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: [], sidebar_position: :right}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "sidebar-right")
    end

    test "generates date_range filter" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: [:date_range]}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "filter-control date-range")
      assert String.contains?(result, "type=\"date\"")
    end

    test "generates region filter" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: [:region]}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "filter-control region")
      assert String.contains?(result, "<select")
      assert String.contains?(result, "North")
      assert String.contains?(result, "South")
    end

    test "generates category filter" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: [:category]}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "filter-control category")
      assert String.contains?(result, "multiple")
      assert String.contains?(result, "Sales")
      assert String.contains?(result, "Marketing")
    end

    test "generates text_search filter" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: [:text_search]}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "filter-control text-search")
      assert String.contains?(result, "type=\"text\"")
      assert String.contains?(result, "phx-debounce=\"300\"")
    end

    test "includes apply button" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "phx-click=\"apply_filters\"")
      assert String.contains?(result, "Apply")
    end

    test "includes reset button" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "phx-click=\"reset_filters\"")
      assert String.contains?(result, "Reset")
    end

    test "localizes filter labels" do
      context = build_test_context(locale: "fr")
      config = %{main_chart: %{}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "Filtres")
      assert String.contains?(result, "Appliquer")
    end

    test "applies RTL to sidebar" do
      context = build_test_context(text_direction: "rtl")
      config = %{main_chart: %{}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert String.contains?(result, "rtl")
    end

    test "handles empty filters array" do
      context = build_test_context()
      config = %{main_chart: %{}, filters: []}

      result = ChartTemplates.filter_dashboard(config, context)

      assert is_binary(result)
      # Should still have sidebar structure
      assert String.contains?(result, "dashboard-sidebar")
    end
  end

  describe "realtime_dashboard/2" do
    test "shows connection status indicator" do
      context = build_test_context()
      config = %{charts: []}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "connection-status")
      assert String.contains?(result, "status-indicator")
      assert String.contains?(result, "Connected")
    end

    test "displays latency metric when enabled" do
      context = build_test_context()
      config = %{charts: [], show_metrics: true}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "performance-metrics")
      assert String.contains?(result, "Latency")
      assert String.contains?(result, "latency-display")
    end

    test "displays updates count when enabled" do
      context = build_test_context()
      config = %{charts: [], show_metrics: true}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "Updates")
      assert String.contains?(result, "updates-display")
    end

    test "shows last update timestamp" do
      context = build_test_context()
      config = %{charts: []}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "last-update")
      assert String.contains?(result, "Last Update")
      assert String.contains?(result, "last-update-time")
    end

    test "sets update interval" do
      context = build_test_context()
      config = %{charts: [], update_interval: 10000}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "data-update-interval=\"10000\"")
    end

    test "generates real-time chart components" do
      context = build_test_context()
      config = %{charts: [%{id: "rt_chart", type: :line}]}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "rt_chart")
      assert String.contains?(result, "real_time={true}")
    end

    test "applies RTL layout" do
      context = build_test_context(text_direction: "rtl")
      config = %{charts: []}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "rtl")
    end

    test "localizes status text" do
      context = build_test_context(locale: "ar")
      config = %{charts: []}

      result = ChartTemplates.realtime_dashboard(config, context)

      # Should use Arabic translation "متصل"
      assert String.contains?(result, "متصل")
    end

    test "handles missing metrics" do
      context = build_test_context()
      config = %{charts: [], show_metrics: false}

      result = ChartTemplates.realtime_dashboard(config, context)

      # Template contains conditional HEEX code, check that condition is false
      assert String.contains?(result, "<%= if false do %>")
    end

    test "updates status dynamically" do
      context = build_test_context()
      config = %{charts: []}

      result = ChartTemplates.realtime_dashboard(config, context)

      # Should have elements with IDs for dynamic updates
      assert String.contains?(result, "id=\"connection-status\"")
      assert String.contains?(result, "id=\"last-update-time\"")
    end

    test "includes performance metrics section" do
      context = build_test_context()
      config = %{charts: [], show_metrics: true}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "metric-label")
      assert String.contains?(result, "metric-value")
    end

    test "preserves locale settings" do
      context = build_test_context(locale: "es")
      config = %{charts: [%{id: "test"}]}

      result = ChartTemplates.realtime_dashboard(config, context)

      assert String.contains?(result, "locale=\"es\"")
    end
  end

  describe "tabbed_charts/2" do
    test "generates tab headers" do
      context = build_test_context()

      config = %{
        tabs: [
          %{id: "tab1", title: "Overview"},
          %{id: "tab2", title: "Details"}
        ]
      }

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "tabs-header")
      assert String.contains?(result, "tab-header")
    end

    test "generates tab contents" do
      context = build_test_context()
      config = %{tabs: [%{id: "content_test", title: "Test"}]}

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "tabs-content")
      assert String.contains?(result, "tab-content")
    end

    test "sets first tab as active" do
      context = build_test_context()

      config = %{
        tabs: [
          %{id: "first", title: "First"},
          %{id: "second", title: "Second"}
        ]
      }

      result = ChartTemplates.tabbed_charts(config, context)

      # First tab header should have active class
      assert String.contains?(result, "tab-header active")
      # First tab content should have active class
      assert String.contains?(result, "tab-content active")
    end

    test "includes phx-click handlers" do
      context = build_test_context()
      config = %{tabs: [%{id: "click_test", title: "Test"}]}

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "phx-click=\"switch_tab\"")
    end

    test "sets unique tab IDs" do
      context = build_test_context()

      config = %{
        tabs: [
          %{id: "unique1", title: "Tab 1"},
          %{id: "unique2", title: "Tab 2"}
        ]
      }

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "phx-value-tab=\"unique1\"")
      assert String.contains?(result, "phx-value-tab=\"unique2\"")
      assert String.contains?(result, "data-tab=\"unique1\"")
      assert String.contains?(result, "data-tab=\"unique2\"")
    end

    test "preserves tab order" do
      context = build_test_context()

      config = %{
        tabs: [
          %{id: "a", title: "A"},
          %{id: "b", title: "B"},
          %{id: "c", title: "C"}
        ]
      }

      result = ChartTemplates.tabbed_charts(config, context)

      pos_a = :binary.match(result, "data-tab-index=\"0\"") |> elem(0)
      pos_b = :binary.match(result, "data-tab-index=\"1\"") |> elem(0)
      pos_c = :binary.match(result, "data-tab-index=\"2\"") |> elem(0)

      assert pos_a < pos_b
      assert pos_b < pos_c
    end

    test "includes chart config in tabs" do
      context = build_test_context()

      config = %{
        tabs: [
          %{id: "chart_tab", title: "Charts", chart_config: %{type: :bar}}
        ]
      }

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "chart_config")
      assert String.contains?(result, "type: :bar")
    end

    test "applies active class correctly" do
      context = build_test_context()
      config = %{tabs: [%{id: "active_test", title: "Test"}]}

      result = ChartTemplates.tabbed_charts(config, context)

      # Should have exactly one active tab header
      active_headers = Regex.scan(~r/tab-header active/, result)
      assert length(active_headers) == 1

      # Should have exactly one active tab content
      active_contents = Regex.scan(~r/tab-content active/, result)
      assert length(active_contents) == 1
    end

    test "handles empty tabs array" do
      context = build_test_context()
      config = %{tabs: []}

      result = ChartTemplates.tabbed_charts(config, context)

      assert is_binary(result)
      assert String.contains?(result, "ash-tabbed-charts")
    end

    test "localizes tab titles when present" do
      context = build_test_context(locale: "fr")
      config = %{tabs: [%{id: "local", title: "Aperçu"}]}

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "Aperçu")
    end

    test "switches tabs on click" do
      context = build_test_context()

      config = %{
        tabs: [
          %{id: "switchable1", title: "Tab 1"},
          %{id: "switchable2", title: "Tab 2"}
        ]
      }

      result = ChartTemplates.tabbed_charts(config, context)

      # Each tab should have click handler with tab ID
      assert String.contains?(result, "phx-click=\"switch_tab\"")
      assert String.contains?(result, "phx-value-tab=\"switchable1\"")
      assert String.contains?(result, "phx-value-tab=\"switchable2\"")
    end

    test "applies RTL to tabs" do
      context = build_test_context(text_direction: "rtl")
      config = %{tabs: [%{id: "rtl_tab", title: "Test"}]}

      result = ChartTemplates.tabbed_charts(config, context)

      assert String.contains?(result, "rtl")
    end
  end

  describe "localization - English" do
    test "Live text" do
      context = build_test_context(locale: "en")
      config = %{real_time: true}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "Live")
    end

    test "Dashboard text" do
      context = build_test_context(locale: "en")
      result = ChartTemplates.dashboard_grid(%{charts: []}, context)

      assert String.contains?(result, "Dashboard")
    end

    test "Filters text" do
      context = build_test_context(locale: "en")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Filters")
    end

    test "Apply text" do
      context = build_test_context(locale: "en")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Apply")
    end

    test "Reset text" do
      context = build_test_context(locale: "en")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Reset")
    end
  end

  describe "localization - Spanish" do
    test "Live text" do
      context = build_test_context(locale: "es")
      config = %{real_time: true}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "En vivo")
    end

    test "Dashboard text" do
      context = build_test_context(locale: "es")
      result = ChartTemplates.dashboard_grid(%{charts: []}, context)

      assert String.contains?(result, "Panel de control")
    end

    test "Filters text" do
      context = build_test_context(locale: "es")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Filtros")
    end

    test "Apply text" do
      context = build_test_context(locale: "es")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Aplicar")
    end

    test "Reset text" do
      context = build_test_context(locale: "es")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Restablecer")
    end
  end

  describe "localization - French" do
    test "Live text" do
      context = build_test_context(locale: "fr")
      config = %{real_time: true}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "En direct")
    end

    test "Dashboard text" do
      context = build_test_context(locale: "fr")
      result = ChartTemplates.dashboard_grid(%{charts: []}, context)

      assert String.contains?(result, "Tableau de bord")
    end

    test "Filters text" do
      context = build_test_context(locale: "fr")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Filtres")
    end

    test "Apply text" do
      context = build_test_context(locale: "fr")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Appliquer")
    end

    test "Reset text" do
      context = build_test_context(locale: "fr")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "Réinitialiser")
    end
  end

  describe "localization - Arabic" do
    test "Live text" do
      context = build_test_context(locale: "ar")
      config = %{real_time: true}

      result = ChartTemplates.single_chart(config, context)

      assert String.contains?(result, "مباشر")
    end

    test "Dashboard text" do
      context = build_test_context(locale: "ar")
      result = ChartTemplates.dashboard_grid(%{charts: []}, context)

      assert String.contains?(result, "لوحة التحكم")
    end

    test "Filters text" do
      context = build_test_context(locale: "ar")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "المرشحات")
    end

    test "Apply text" do
      context = build_test_context(locale: "ar")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "تطبيق")
    end

    test "Reset text" do
      context = build_test_context(locale: "ar")
      result = ChartTemplates.filter_dashboard(%{main_chart: %{}, filters: []}, context)

      assert String.contains?(result, "إعادة تعيين")
    end
  end

  describe "localization - fallback to English" do
    test "falls back to English for unknown locale" do
      context = build_test_context(locale: "unknown")
      config = %{real_time: true}

      result = ChartTemplates.single_chart(config, context)

      # Should use English as fallback
      assert String.contains?(result, "Live")
    end
  end
end
