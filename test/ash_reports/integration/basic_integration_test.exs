defmodule AshReports.Integration.BasicIntegrationTest do
  @moduledoc """
  Basic integration tests to verify Phase 4 integration test framework.

  Simple tests to ensure the integration test helpers and infrastructure work correctly.
  """

  use ExUnit.Case, async: true

  alias AshReports.Integration.TestHelpers

  @moduletag :integration

  describe "Integration Test Framework" do
    test "can create test data" do
      data = TestHelpers.create_multilingual_test_data()

      assert is_list(data)
      assert length(data) == 3

      [customer1, customer2, customer3] = data

      # Verify structure
      assert customer1.name == "John Smith"
      assert customer1.email == "john@example.com"
      assert customer1.region == "North America"

      # Arabic customer
      assert customer2.name == "أحمد محمد"
      assert customer2.region == "Middle East"

      # Hebrew customer
      assert customer3.name == "דוד כהן"
      assert customer3.region == "Middle East"
    end

    test "can create integration contexts" do
      context = TestHelpers.create_integration_context("en")

      assert context.locale == "en"
      assert context.text_direction == "ltr"
      assert is_map(context.locale_metadata)
      assert is_map(context.config)
    end

    test "can create RTL contexts" do
      context = TestHelpers.create_rtl_context("ar")

      assert context.locale == "ar"
      assert context.text_direction == "rtl"
      assert context.locale_metadata.rtl_enabled == true
      assert context.locale_metadata.element_mirroring == true
    end

    test "can create CLDR contexts" do
      context = TestHelpers.create_cldr_context("en")

      assert context.locale == "en"
      assert context.locale_metadata.cldr_enabled == true
      assert context.locale_metadata.number_formatting == true
      assert context.locale_metadata.currency_formatting == true
    end

    test "can create full Phase 4 contexts" do
      context = TestHelpers.create_full_phase4_context("ar")

      assert context.locale == "ar"
      assert context.text_direction == "rtl"
      assert context.locale_metadata.cldr_enabled == true
      assert context.locale_metadata.translation_enabled == true
      assert context.locale_metadata.rtl_enabled == true
    end
  end

  describe "Test Data Validation" do
    test "RTL locale detection works correctly" do
      rtl_locales = TestHelpers.rtl_locales()

      assert "ar" in rtl_locales
      assert "he" in rtl_locales
      assert "fa" in rtl_locales
      assert "ur" in rtl_locales

      refute "en" in rtl_locales
      refute "es" in rtl_locales
    end

    test "validation helpers work" do
      # Test RTL marker detection
      rtl_content = "This has dir=\"rtl\" in it"
      ltr_content = "This is normal content"

      assert TestHelpers.contains_rtl_markers?(rtl_content)
      refute TestHelpers.contains_rtl_markers?(ltr_content)

      # Test fallback text detection
      fallback_content = "Name: Customer"
      error_content = "ERROR: Something failed"

      assert TestHelpers.contains_fallback_text?(fallback_content)
      refute TestHelpers.contains_error_markers?(fallback_content)

      assert TestHelpers.contains_error_markers?(error_content)
    end

    test "can create performance test data" do
      small_data = TestHelpers.create_performance_test_data(10)

      assert is_list(small_data)
      assert length(small_data) == 10

      [first_customer | _] = small_data
      assert first_customer.id == 1
      assert first_customer.name == "Customer 1"
      assert String.contains?(first_customer.email, "customer1@")
    end
  end
end
