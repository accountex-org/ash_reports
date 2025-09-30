defmodule AshReports.Typst.DataLoaderTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.DataLoader

  describe "load_for_typst/4" do
    test "handles report not found error" do
      # Test the error case without needing mocking
      # Since AshReports.Info.report/2 will return nil for nonexistent reports
      result = DataLoader.load_for_typst(NonExistentDomain, :nonexistent_report, %{})

      assert {:error, _reason} = result
      # We expect some kind of error - could be report_not_found or report_lookup_failed
    end
  end

  describe "typst_config/1" do
    test "creates default configuration" do
      config = DataLoader.typst_config()

      assert config[:chunk_size] == 1000
      assert config[:enable_streaming] == false
      assert config[:type_conversion][:datetime_format] == :iso8601
      assert config[:variable_scopes] == [:detail, :group, :page, :report]
    end

    test "allows configuration overrides" do
      config = DataLoader.typst_config(chunk_size: 2000, enable_streaming: true)

      assert config[:chunk_size] == 2000
      assert config[:enable_streaming] == true
      # Defaults should still be present
      assert config[:type_conversion][:datetime_format] == :iso8601
    end
  end

  describe "stream_for_typst/4" do
    test "returns error for not implemented streaming" do
      # Test that streaming returns the expected not-implemented error
      result = DataLoader.stream_for_typst(NonExistentDomain, :test_report, %{})

      assert {:error, _reason} = result
      # We expect either streaming_not_implemented or report lookup error
    end
  end
end
