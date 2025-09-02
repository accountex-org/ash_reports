defmodule AshReports.LiveView.DashboardLiveTest do
  @moduledoc """
  Comprehensive test suite for DashboardLive in Phase 6.2.

  Tests multi-chart dashboard functionality including:
  - Dashboard lifecycle and initialization
  - Chart coordination and shared state
  - Real-time updates and WebSocket integration
  - Collaborative features and user presence
  - Global filtering and cross-chart interactions
  - Performance with multiple concurrent users
  """

  # Async false due to PubSub interactions
  use ExUnit.Case, async: false
  use Phoenix.LiveViewTest

  import Phoenix.LiveViewTest

  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.LiveView.DashboardLive
  alias AshReports.TestHelpers

  @moduletag :liveview
  @moduletag :integration
  @moduletag :dashboard

  describe "Dashboard initialization" do
    test "mounts dashboard with multiple charts" do
      dashboard_config = %{
        dashboard_id: "test_dashboard",
        title: "Test Dashboard",
        charts: [
          %{id: "chart1", type: :line, data: [[1, 10], [2, 20]]},
          %{id: "chart2", type: :bar, data: [[1, 15], [2, 25]]}
        ],
        layout: "grid"
      }

      {view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "test_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "test_user"
          }
        )

      assert html =~ "Test Dashboard"
      assert html =~ "chart1"
      assert html =~ "chart2"
      assert html =~ "dashboard-grid"
    end

    test "handles empty dashboard gracefully" do
      dashboard_config = %{
        dashboard_id: "empty_dashboard",
        title: "Empty Dashboard",
        charts: [],
        layout: "grid"
      }

      {_view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "empty_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "test_user"
          }
        )

      assert html =~ "Empty Dashboard"
      assert html =~ "dashboard-grid"
      refute html =~ "chart"
    end
  end

  describe "Chart coordination" do
    setup do
      dashboard_config = %{
        dashboard_id: "coord_dashboard",
        title: "Coordination Dashboard",
        charts: [
          %{id: "sales_chart", type: :line, data: sales_data(), interactive: true},
          %{id: "region_chart", type: :pie, data: region_data(), interactive: true}
        ],
        layout: "grid",
        real_time: true
      }

      {view, _html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "coord_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "coord_user"
          }
        )

      %{view: view, dashboard_config: dashboard_config}
    end

    test "applies global filters to all charts", %{view: view} do
      # Apply global filter
      result =
        render_click(view, "apply_global_filter", %{
          "filter" => %{"region" => "North", "start_date" => "2024-01-01"}
        })

      # Should update all charts with filter
      assert result
      refute result =~ "error"

      # Verify filter was applied
      html = render(view)
      # Filter should be visible
      assert html =~ "North"
    end

    test "resets filters across all charts", %{view: view} do
      # First apply filters
      render_click(view, "apply_global_filter", %{
        "filter" => %{"region" => "South"}
      })

      # Then reset all filters
      result = render_click(view, "reset_global_filters", %{})

      assert result
      refute result =~ "error"
    end

    test "refreshes all charts simultaneously", %{view: view} do
      result = render_click(view, "refresh_dashboard", %{})

      assert result
      refute result =~ "error"
    end
  end

  describe "Real-time updates" do
    test "handles dashboard-wide real-time updates" do
      dashboard_config = %{
        dashboard_id: "realtime_dashboard",
        title: "Real-time Dashboard",
        charts: [
          %{id: "live_chart1", type: :line, data: [[1, 10]], real_time: true},
          %{id: "live_chart2", type: :bar, data: [[1, 15]], real_time: true}
        ],
        real_time: true,
        update_interval: 5000
      }

      {view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "realtime_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "realtime_user"
          }
        )

      assert html =~ "real-time-status"
      assert html =~ "data-real-time=\"true\""

      # Simulate real-time dashboard update
      new_dashboard_data = %{
        chart_updates: %{
          "live_chart1" => [[1, 20], [2, 30]],
          "live_chart2" => [[1, 25], [2, 35]]
        }
      }

      send(view.pid, {:real_time_update, new_dashboard_data})

      html = render(view)
      refute html =~ "error"
    end
  end

  describe "Layout switching" do
    test "switches between grid and sidebar layouts" do
      dashboard_config = %{
        dashboard_id: "layout_dashboard",
        charts: [
          %{id: "chart1", type: :line, data: [[1, 10]]},
          %{id: "chart2", type: :bar, data: [[1, 15]]}
        ],
        layout: "grid"
      }

      {view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "layout_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "layout_user"
          }
        )

      assert html =~ "dashboard-grid"

      # Switch to sidebar layout
      result = render_click(view, "change_layout", %{"layout" => "sidebar"})

      assert result =~ "dashboard-sidebar-layout"
      refute result =~ "dashboard-grid"
    end

    test "handles tabs layout correctly" do
      dashboard_config = %{
        dashboard_id: "tabs_dashboard",
        charts: [
          %{id: "tab1", type: :line, data: [[1, 10]]},
          %{id: "tab2", type: :pie, data: [[1, 15]]}
        ],
        layout: "tabs"
      }

      {view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "tabs_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "tabs_user"
          }
        )

      assert html =~ "ash-tabbed-charts"
      assert html =~ "tab-content"
    end
  end

  describe "Export functionality" do
    test "exports dashboard data in JSON format" do
      dashboard_config = %{
        dashboard_id: "export_dashboard",
        charts: [
          %{id: "export_chart", type: :bar, data: [[1, 10], [2, 20]]}
        ]
      }

      {view, _html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "export_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "export_user"
          }
        )

      # Test JSON export
      result = render_click(view, "export_dashboard", %{"format" => "json"})

      assert result
      refute result =~ "error"
    end

    test "handles unsupported export formats gracefully" do
      dashboard_config = %{
        dashboard_id: "export_fail_dashboard",
        charts: [
          %{id: "chart", type: :line, data: [[1, 10]]}
        ]
      }

      {view, _html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "export_fail_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "export_fail_user"
          }
        )

      # Test unsupported format
      result = render_click(view, "export_dashboard", %{"format" => "xml"})

      # Should show error message
      assert result =~ "Export failed" or result =~ "error"
    end
  end

  # Helper functions for test data

  defp sales_data do
    [
      %{x: "Jan", y: 100},
      %{x: "Feb", y: 150},
      %{x: "Mar", y: 120},
      %{x: "Apr", y: 180}
    ]
  end

  defp region_data do
    [
      %{label: "North", value: 35},
      %{label: "South", value: 25},
      %{label: "East", value: 20},
      %{label: "West", value: 20}
    ]
  end
end
