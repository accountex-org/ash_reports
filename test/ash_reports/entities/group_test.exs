defmodule AshReports.Entities.GroupTest do
  @moduledoc """
  Tests for AshReports.Group entity structure and validation.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Group, Info}

  describe "Group struct creation" do
    test "creates group with required fields" do
      group = %Group{
        name: :by_region,
        level: 1,
        expression: :region
      }

      assert group.name == :by_region
      assert group.level == 1
      assert group.expression == :region
    end

    test "creates group with all optional fields" do
      group = %Group{
        name: :by_customer,
        level: 2,
        expression: {:field, :customer, :name},
        sort: :desc
      }

      assert group.name == :by_customer
      assert group.level == 2
      assert group.expression == {:field, :customer, :name}
      assert group.sort == :desc
    end
  end

  describe "Group field validation" do
    test "parses group with all options" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_status = Enum.find(report.groups, &(&1.name == :by_status))
      assert by_status.level == 2
      assert by_status.expression == :status
      assert by_status.sort == :desc
    end

    test "sets default sort value" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_region = Enum.find(report.groups, &(&1.name == :by_region))
      # Default sort value is :asc
      assert by_region.sort == :asc
    end
  end

  describe "Group expression types" do
    test "simple field expressions" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_region = Enum.find(report.groups, &(&1.name == :by_region))
      assert by_region.expression == :region
    end

    test "complex expressions" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_status = Enum.find(report.groups, &(&1.name == :by_status))
      assert by_status.expression == :status
    end
  end

  describe "Group level hierarchy" do
    test "multi-level grouping hierarchy" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      groups = report.groups
      assert length(groups) == 2

      level_1_group = Enum.find(groups, &(&1.level == 1))
      assert level_1_group.name == :by_region

      level_2_group = Enum.find(groups, &(&1.level == 2))
      assert level_2_group.name == :by_status
    end
  end

  describe "Group sorting and ordering" do
    test "ascending sort groups" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_region = Enum.find(report.groups, &(&1.name == :by_region))
      assert by_region.sort == :asc
    end

    test "descending sort groups" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      by_status = Enum.find(report.groups, &(&1.name == :by_status))
      assert by_status.sort == :desc
    end
  end

  describe "Group extraction" do
    test "extracts group entities correctly" do
      reports = Info.reports(AshReports.Test.GroupsDomain)
      report = hd(reports)

      groups = report.groups
      assert length(groups) == 2

      by_region = Enum.find(groups, &(&1.name == :by_region))
      assert by_region.level == 1
      assert by_region.expression == :region

      by_status = Enum.find(groups, &(&1.name == :by_status))
      assert by_status.level == 2
      assert by_status.expression == :status
    end
  end
end
