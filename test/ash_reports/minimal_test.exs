defmodule AshReports.MinimalTest do
  @moduledoc """
  Minimal test to verify test infrastructure works.
  """

  use ExUnit.Case, async: true

  alias AshReports.Info

  describe "basic DSL parsing" do
    test "parses minimal valid report" do
      reports = Info.reports(AshReports.Test.MinimalDomain)

      assert length(reports) == 1
      report = hd(reports)
      assert report.name == :test_report
      assert report.title == "Test Report"
      assert report.driving_resource == AshReports.Test.Customer
    end
  end
end
