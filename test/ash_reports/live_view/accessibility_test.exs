defmodule AshReports.LiveView.AccessibilityTest do
  @moduledoc """
  Accessibility compliance tests for AshReports Phase 6.2 LiveView components.

  Tests accessibility features including:
  - ARIA attributes and roles
  - Keyboard navigation support
  - Screen reader compatibility
  - Color contrast and visual accessibility
  - Focus management and tab order
  - Voice control compatibility
  """

  use ExUnit.Case, async: true

  # Conditional import - only load if Phoenix.LiveView is available
  if Code.ensure_loaded?(Phoenix.LiveViewTest) do
    import Phoenix.LiveViewTest
  end

  alias AshReports.ChartEngine.ChartConfig
  alias AshReports.LiveView.{ChartLiveComponent, DashboardLive}

  @moduletag :accessibility
  @moduletag :a11y
  # Skip until LiveView dependency available
  @moduletag :skip

  describe "ARIA compliance" do
    test "chart components have proper ARIA attributes" do
      chart_config = %ChartConfig{
        type: :bar,
        data: [[1, 10], [2, 20], [3, 30]],
        title: "Accessibility Test Chart",
        interactive: true
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "aria_chart",
          chart_config: chart_config,
          locale: "en"
        })

      # Should have proper ARIA attributes
      assert html =~ ~r/role="img"/
      assert html =~ ~r/aria-label="[^"]+"/
      assert html =~ ~r/aria-describedby="[^"]+"/

      # Interactive charts should be focusable
      assert html =~ ~r/tabindex="0"/
    end

    test "dashboard has proper document structure" do
      dashboard_config = %{
        dashboard_id: "aria_dashboard",
        title: "ARIA Dashboard",
        charts: [
          %{id: "chart1", type: :line, data: [[1, 10]]},
          %{id: "chart2", type: :pie, data: [[1, 20]]}
        ]
      }

      {_view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "aria_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "aria_user"
          }
        )

      # Should have proper heading structure
      assert html =~ ~r/<h1[^>]*>.*<\/h1>/
      assert html =~ ~r/<h3[^>]*>.*<\/h3>/

      # Should have main content area
      assert html =~ ~r/class="dashboard-content"/
    end

    test "error messages have proper alert roles" do
      invalid_config = %ChartConfig{
        type: :invalid,
        data: nil,
        title: "Error Chart"
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "error_chart",
          chart_config: invalid_config,
          locale: "en"
        })

      # Error messages should have alert role
      assert html =~ ~r/role="alert"/
    end
  end

  describe "Keyboard navigation" do
    test "charts are keyboard accessible" do
      chart_config = %ChartConfig{
        type: :bar,
        data: [[1, 10], [2, 20]],
        title: "Keyboard Chart",
        interactive: true
      }

      {view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "keyboard_chart",
          chart_config: chart_config,
          locale: "en"
        })

      # Should have proper tabindex for keyboard navigation
      assert html =~ ~r/tabindex="0"/

      # Interactive elements should be focusable
      if html =~ "interactive-controls" do
        assert html =~ ~r/<button[^>]*>/ or html =~ ~r/<input[^>]*>/
      end
    end

    test "dashboard controls have logical tab order" do
      dashboard_config = %{
        dashboard_id: "keyboard_dashboard",
        charts: [
          %{id: "chart1", type: :line, data: [[1, 10]], interactive: true}
        ],
        show_filters: true
      }

      {_view, html} =
        live_isolated(
          DashboardLive,
          %{
            "dashboard_id" => "keyboard_dashboard"
          },
          session: %{
            "dashboard_config" => dashboard_config,
            "user_id" => "keyboard_user"
          }
        )

      # Should have logical tabindex order
      # Dashboard title should come first
      assert html =~ ~r/<h1[^>]*class="dashboard-title"/

      # Filter controls should be accessible
      if html =~ "dashboard-filters" do
        assert html =~ ~r/<input[^>]*name="filter/
        assert html =~ ~r/<button[^>]*type="submit"/
      end

      # Charts should be accessible
      assert html =~ ~r/tabindex="0"/
    end
  end

  describe "Screen reader support" do
    test "provides meaningful text alternatives for charts" do
      chart_config = %ChartConfig{
        type: :pie,
        data: [
          %{label: "Sales", value: 60},
          %{label: "Marketing", value: 25},
          %{label: "Support", value: 15}
        ],
        title: "Department Distribution",
        interactive: true
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "screen_reader_chart",
          chart_config: chart_config,
          locale: "en"
        })

      # Should provide meaningful descriptions
      assert html =~ "Department Distribution"
      assert html =~ ~r/aria-label="[^"]*Department Distribution[^"]*"/

      # Should have fallback content for screen readers
      assert html =~ "chart-fallback" or html =~ "chart-description"
    end

    test "loading states are announced to screen readers" do
      chart_config = %ChartConfig{
        type: :line,
        data: [[1, 10], [2, 20]],
        title: "Loading Chart"
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "loading_chart",
          chart_config: chart_config,
          locale: "en"
        })

      # Loading states should be announced
      if html =~ "chart-loading" do
        assert html =~ ~r/aria-live="polite"/ or html =~ ~r/role="status"/
      end
    end
  end

  describe "Color accessibility" do
    test "charts work without color dependence" do
      # Test that charts are accessible without relying solely on color
      chart_config = %ChartConfig{
        type: :bar,
        data: [
          %{x: "Category A", y: 25},
          %{x: "Category B", y: 50},
          %{x: "Category C", y: 75}
        ],
        title: "Color Accessibility Chart"
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "color_chart",
          chart_config: chart_config,
          locale: "en"
        })

      # Should have text labels and not rely solely on color
      assert html =~ "Category A"
      assert html =~ "Category B"
      assert html =~ "Category C"
    end
  end

  describe "Focus management" do
    test "maintains focus correctly during updates" do
      chart_config = %ChartConfig{
        type: :line,
        data: [[1, 10], [2, 20]],
        title: "Focus Chart",
        interactive: true,
        real_time: true
      }

      {view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "focus_chart",
          chart_config: chart_config,
          locale: "en"
        })

      # Should handle focus properly
      assert html =~ ~r/tabindex="0"/

      # Simulate real-time update
      send_update(view, ChartLiveComponent,
        id: "focus_chart",
        chart_data: [[1, 15], [2, 25], [3, 35]]
      )

      updated_html = render(view)

      # Focus should be maintained after update
      assert updated_html =~ ~r/tabindex="0"/
    end
  end

  describe "Internationalization accessibility" do
    test "RTL layout maintains accessibility" do
      chart_config = %ChartConfig{
        type: :bar,
        data: [[1, 10], [2, 20]],
        # Arabic chart title
        title: "مخطط عربي",
        interactive: true
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "rtl_chart",
          chart_config: chart_config,
          locale: "ar"
        })

      # Should have RTL attributes
      assert html =~ ~r/data-rtl="true"/
      assert html =~ ~r/dir="rtl"/ or html =~ ~r/direction: rtl/

      # Should maintain accessibility in RTL
      assert html =~ ~r/role="img"/
      assert html =~ ~r/aria-label="/
    end

    test "multilingual error messages are accessible" do
      invalid_config = %ChartConfig{
        type: :invalid,
        data: nil,
        title: "Test Error"
      }

      locales = ["en", "ar", "es", "fr"]

      for locale <- locales do
        {_view, html} =
          live_isolated_component(ChartLiveComponent, %{
            id: "error_#{locale}",
            chart_config: invalid_config,
            locale: locale
          })

        # Error should be accessible in all locales
        assert html =~ ~r/role="alert"/ or html =~ ~r/class="[^"]*error[^"]*"/

        # Should have locale-appropriate error text
        case locale do
          "ar" -> assert html =~ "خطأ"
          "es" -> assert html =~ "Error"
          "fr" -> assert html =~ "Erreur"
          _ -> assert html =~ "Error"
        end
      end
    end
  end

  describe "Mobile accessibility" do
    test "touch targets are appropriately sized" do
      chart_config = %ChartConfig{
        type: :pie,
        data: [[1, 10], [2, 20], [3, 30]],
        title: "Mobile Chart",
        interactive: true
      }

      {_view, html} =
        live_isolated_component(ChartLiveComponent, %{
          id: "mobile_chart",
          chart_config: chart_config,
          locale: "en",
          mobile_optimized: true
        })

      # Should include mobile-friendly classes
      assert html =~ "ash-live-chart"

      # Interactive controls should be present for mobile
      if html =~ "interactive-controls" do
        assert html =~ ~r/<button[^>]*class="[^"]*btn[^"]*"/
      end
    end
  end
end
