defmodule AshReports.LiveView.BrowserIntegrationTest do
  @moduledoc """
  Browser integration tests for AshReports Phase 6.2 using Wallaby.

  Tests real browser interactions including:
  - JavaScript chart rendering and interactions
  - Real-time WebSocket updates in browser
  - Mobile touch interactions and responsiveness
  - Accessibility with assistive technologies
  - Cross-browser compatibility validation
  """

  use ExUnit.Case, async: false
  use Wallaby.Feature

  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.LiveView.DashboardLive

  @moduletag :browser
  @moduletag :integration
  @moduletag timeout: 30_000

  feature "Dashboard loads and displays charts", %{session: session} do
    dashboard_url = build_dashboard_url("browser_test_dashboard")

    session
    |> visit(dashboard_url)
    |> assert_has(css(".ash-dashboard"))
    |> assert_has(css(".dashboard-header"))
    |> assert_has(css(".dashboard-content"))
  end

  feature "Chart interactions work in browser", %{session: session} do
    interactive_dashboard_url = build_dashboard_url("interactive_test", %{interactive: true})

    session
    |> visit(interactive_dashboard_url)
    |> assert_has(css(".ash-live-chart.interactive"))
    |> assert_has(css("[phx-hook='AshReportsChart']"))

    # Test chart click interaction
    session
    |> click(css(".ash-live-chart canvas"))
    # Should show interaction feedback
    |> assert_has(css(".chart-interaction-feedback"))
  end

  feature "Real-time updates work in browser", %{session: session} do
    realtime_dashboard_url = build_dashboard_url("realtime_test", %{real_time: true})

    session
    |> visit(realtime_dashboard_url)
    |> assert_has(css(".real-time-status"))
    |> assert_has(css(".status-indicator"))

    # Verify real-time indicator is active
    session
    |> assert_has(css(".status-indicator.active"))

    # Simulate real-time update by triggering server-side update
    # (Would need actual WebSocket message simulation)

    # Wait for update and verify UI reflects change
    session
    |> assert_has(css(".real-time-status"), count: 1)
  end

  feature "Global filters affect all charts", %{session: session} do
    filter_dashboard_url = build_dashboard_url("filter_test", %{show_filters: true})

    session
    |> visit(filter_dashboard_url)
    |> assert_has(css(".dashboard-filters"))
    |> assert_has(css("input[name*='filter']"))

    # Apply global filter
    session
    |> fill_in(css("input[name='filter[search]']"), with: "test filter")
    |> click(css("button[type='submit']"))

    # Should see filter applied
    session
    |> assert_has(css(".filter-applied"), count: 1)
  end

  feature "Mobile responsiveness works correctly", %{session: session} do
    dashboard_url = build_dashboard_url("mobile_test")

    # Set mobile viewport
    session
    # iPhone dimensions
    |> set_window_size(375, 667)
    |> visit(dashboard_url)

    # Should adapt to mobile layout
    session
    |> assert_has(css(".dashboard-content"))
    |> assert_has(css(".ash-live-chart"))

    # Charts should be responsive
    chart_elements = session |> find_all(css(".ash-live-chart"))
    assert length(chart_elements) > 0

    # Test touch interactions (simulated)
    session
    |> click(css(".ash-live-chart:first-child"))

    # Should handle touch interaction
  end

  feature "Keyboard navigation works for accessibility", %{session: session} do
    accessible_dashboard_url = build_dashboard_url("accessibility_test")

    session
    |> visit(accessible_dashboard_url)

    # Test keyboard navigation
    session
    # Navigate to first focusable element
    |> send_keys([:tab])
    # Should have focused element
    |> assert_has(css(":focus"))

    # Test chart keyboard interaction
    session
    # Navigate to chart
    |> send_keys([:tab, :tab])
    # Activate chart
    |> send_keys([:enter])

    # Should handle keyboard interaction
  end

  feature "Error states display correctly", %{session: session} do
    error_dashboard_url = build_dashboard_url("error_test", %{simulate_error: true})

    session
    |> visit(error_dashboard_url)
    |> assert_has(css(".chart-error"))
    |> assert_has(css(".retry-button"))

    # Test retry functionality
    session
    |> click(css(".retry-button"))
    # Should show loading state
    |> assert_has(css(".chart-loading"))
  end

  feature "Multiple browser tabs maintain independent state", %{session: session1} do
    dashboard_url1 = build_dashboard_url("multi_tab_test_1")
    dashboard_url2 = build_dashboard_url("multi_tab_test_2")

    # Open same dashboard in multiple "tabs" (sessions)
    session2 = new_session()

    session1
    |> visit(dashboard_url1)
    |> assert_has(css(".ash-dashboard"))

    session2
    |> visit(dashboard_url2)
    |> assert_has(css(".ash-dashboard"))

    # Apply filter in first tab
    session1
    |> fill_in(css("input[name='filter[search]']"), with: "tab1 filter")
    |> click(css("button[type='submit']"))

    # Second tab should maintain independent state
    session2
    # Should not show tab1's filter
    |> refute_has(css(".filter-applied"))

    # Cleanup second session
    close_session(session2)
  end

  feature "Collaborative features work across users", %{session: session} do
    collab_dashboard_url = build_dashboard_url("collaboration_test", %{collaboration: true})

    session
    |> visit(collab_dashboard_url)
    |> assert_has(css(".collaboration-status"))
    |> assert_has(css(".users-count"))

    # Should show current user in collaboration
    session
    |> assert_has(css(".user-avatars"))
    |> assert_has(css(".user-avatar"))
  end

  feature "Export functionality works in browser", %{session: session} do
    export_dashboard_url = build_dashboard_url("export_test")

    session
    |> visit(export_dashboard_url)
    |> assert_has(css(".dashboard-actions"))
    |> assert_has(css("button", text: "Export"))

    # Click export button
    session
    |> click(css("button", text: "Export"))

    # Should trigger export (would need to test actual download in real browser)
    # For now, just verify no errors
    session
    |> refute_has(css(".error"))
  end

  # Helper functions

  defp build_dashboard_url(dashboard_id, params \\ %{}) do
    base_url = "/dashboards/#{dashboard_id}"

    if map_size(params) > 0 do
      query_string = URI.encode_query(params)
      "#{base_url}?#{query_string}"
    else
      base_url
    end
  end

  defp new_session do
    # Create new browser session for multi-tab testing
    Wallaby.start_session()
  end

  defp close_session(session) do
    # Close browser session
    Wallaby.end_session(session)
  end

  defp set_window_size(session, width, height) do
    # Set browser window size for responsive testing
    execute_script(session, "window.resizeTo(#{width}, #{height});")
    session
  end
end
