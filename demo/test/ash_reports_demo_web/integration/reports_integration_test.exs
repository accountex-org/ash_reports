defmodule AshReportsDemoWeb.ReportsIntegrationTest do
  use AshReportsDemoWeb.ConnCase

  import PhoenixTest

  describe "Reports page navigation" do
    test "user can navigate to reports index", %{conn: conn} do
      conn
      |> visit("/")
      |> click_link("Reports Demo")
      |> assert_has("h1", text: "Available Reports")
      |> assert_path("/reports")
    end

    test "reports index displays available reports", %{conn: conn} do
      conn
      |> visit("/reports")
      |> assert_has("h1", text: "Available Reports")
      |> assert_has("text", text: "Simple Report")
      |> assert_has("text", text: "Complex Report")
      |> assert_has("text", text: "Interactive Report")
    end

    test "user can access simple report", %{conn: conn} do
      conn
      |> visit("/reports")
      |> click_link("View Report", at: 0)
      |> assert_has("h1", text: "Simple Customer Report")
      |> assert_path("/reports/simple")
    end
  end

  describe "Simple report functionality" do
    test "simple report displays customer table structure", %{conn: conn} do
      conn
      |> visit("/reports/simple")
      |> assert_has("table")
      |> assert_has("th", text: "Name")
      |> assert_has("th", text: "Email")
      |> assert_has("th", text: "Phone")
      |> assert_has("th", text: "Type")
    end

    test "user can refresh simple report", %{conn: conn} do
      conn
      |> visit("/reports/simple")
      |> click_button("Refresh Report")
      |> assert_has("text", text: "Report refreshed!")
    end

    test "user can navigate back from simple report", %{conn: conn} do
      conn
      |> visit("/reports/simple")
      |> click_link("← Back to Reports")
      |> assert_path("/reports")
      |> assert_has("h1", text: "Available Reports")
    end
  end

  describe "Data generation functionality" do
    test "user can regenerate sample data from reports index", %{conn: conn} do
      conn
      |> visit("/reports")
      |> click_button("Regenerate Sample Data")
      |> assert_has("text", text: "Sample data regenerated successfully!")
    end
  end

  describe "Navigation flow" do
    test "complete user journey through reports", %{conn: conn} do
      # Start from home page
      conn
      |> visit("/")
      |> assert_has("h1", text: "Welcome to AshReports Demo")
      
      # Navigate to reports
      |> click_link("Reports Demo")
      |> assert_path("/reports")
      |> assert_has("h1", text: "Available Reports")
      
      # Generate sample data
      |> click_button("Regenerate Sample Data")
      |> assert_has("text", text: "Sample data regenerated successfully!")
      
      # View simple report
      |> click_link("View Report", at: 0)
      |> assert_path("/reports/simple")
      |> assert_has("h1", text: "Simple Customer Report")
      
      # Refresh the report
      |> click_button("Refresh Report")
      |> assert_has("text", text: "Report refreshed!")
      
      # Navigate back
      |> click_link("← Back to Reports")
      |> assert_path("/reports")
      |> assert_has("h1", text: "Available Reports")
    end
  end
end