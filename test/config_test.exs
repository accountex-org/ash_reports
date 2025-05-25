defmodule AshReports.ConfigTest do
  use ExUnit.Case, async: true

  test "AshReports configuration is loaded" do
    config = Application.get_all_env(:ash_reports)
    
    assert config[:default_formats] == [:html, :pdf]
    assert config[:report_storage_path] in ["priv/reports", "tmp/reports", "tmp/test_reports"]
    assert is_integer(config[:cache_ttl]) or config[:cache_ttl] == false
    assert is_integer(config[:worker_pool_size])
    assert is_integer(config[:max_concurrent_reports])
  end

  test "Spark formatter configuration includes AshReports sections" do
    spark_config = Application.get_env(:spark, :formatter)
    
    resource_sections = spark_config[:"Ash.Resource"][:section_order]
    assert :reportable in resource_sections
    
    domain_sections = spark_config[:"Ash.Domain"][:section_order]
    assert :reports in domain_sections
  end

  test "test environment configuration is applied" do
    if Mix.env() == :test do
      config = Application.get_all_env(:ash_reports)
      
      assert config[:report_storage_path] == "tmp/test_reports"
      assert config[:cache_enabled] == false
      assert config[:worker_pool_size] == 1
      assert config[:max_concurrent_reports] == 1
    end
  end
end