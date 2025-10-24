defmodule AshReports.Entities.VariableTest do
  @moduledoc """
  Tests for AshReports.Variable entity structure and validation.
  """

  use ExUnit.Case, async: true

  alias AshReports.{Variable, Info}

  describe "Variable struct creation" do
    test "creates variable with required fields" do
      variable = %Variable{
        name: :total_sales,
        type: :sum,
        expression: :total_amount
      }

      assert variable.name == :total_sales
      assert variable.type == :sum
      assert variable.expression == :total_amount
    end

    test "creates variable with all optional fields" do
      variable = %Variable{
        name: :group_total,
        type: :sum,
        expression: {:multiply, :quantity, :price},
        reset_on: :group,
        reset_group: 2,
        initial_value: 0
      }

      assert variable.name == :group_total
      assert variable.type == :sum
      assert variable.expression == {:multiply, :quantity, :price}
      assert variable.reset_on == :group
      assert variable.reset_group == 2
      assert variable.initial_value == 0
    end
  end

  describe "Variable field validation" do
    test "parses variable with all options" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_sales = Enum.find(report.variables, &(&1.name == :total_sales))
      assert total_sales.type == :sum
      assert total_sales.expression == :total_amount
      assert total_sales.reset_on == :group
      assert total_sales.reset_group == 1
      assert total_sales.initial_value == 0
    end

    test "sets default values correctly" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_count = Enum.find(report.variables, &(&1.name == :total_count))
      # Default reset_on value is :report
      assert total_count.reset_on == :report
    end
  end

  describe "Variable type-specific behavior" do
    test "sum variable with expressions" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_sales = Enum.find(report.variables, &(&1.name == :total_sales))
      assert total_sales.type == :sum
      assert total_sales.expression == :total_amount
    end

    test "count variable with field references" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_count = Enum.find(report.variables, &(&1.name == :total_count))
      assert total_count.type == :count
      assert total_count.expression == :id
    end
  end

  describe "Variable reset behavior" do
    test "group reset variables with group levels" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_sales = Enum.find(report.variables, &(&1.name == :total_sales))
      assert total_sales.reset_on == :group
      assert total_sales.reset_group == 1
    end

    test "report reset variables" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      total_count = Enum.find(report.variables, &(&1.name == :total_count))
      assert total_count.reset_on == :report
    end
  end

  describe "Variable extraction" do
    test "extracts variable entities correctly" do
      reports = Info.reports(AshReports.Test.VariablesDomain)
      report = hd(reports)

      variables = report.variables
      assert length(variables) == 2

      total_count = Enum.find(variables, &(&1.name == :total_count))
      assert total_count.type == :count
      assert total_count.expression == :id

      total_sales = Enum.find(variables, &(&1.name == :total_sales))
      assert total_sales.type == :sum
      assert total_sales.expression == :total_amount
      assert total_sales.reset_on == :group
      assert total_sales.reset_group == 1
      assert total_sales.initial_value == 0
    end
  end
end
