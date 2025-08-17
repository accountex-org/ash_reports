defmodule AshReports.MinimalTest do
  @moduledoc """
  Minimal test to verify test infrastructure works.
  """

  use ExUnit.Case, async: true

  import AshReports.TestHelpers

  describe "basic DSL parsing" do
    test "parses minimal valid report" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          driving_resource AshReports.Test.Customer
        end
      end
      """

      assert_dsl_valid(dsl_content)
    end

    test "handles DSL parsing errors" do
      dsl_content = """
      reports do
        report :test_report do
          title "Test Report"
          # missing driving_resource
        end
      end
      """

      assert_dsl_error(dsl_content, "required")
    end
  end
end
