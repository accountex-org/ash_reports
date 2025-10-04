defmodule AshReports.ReportBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.ReportBuilder

  describe "validate_config/1" do
    test "validates a valid configuration" do
      config = %{
        template: :sales_report,
        data_source: %{},
        field_mappings: %{},
        visualizations: []
      }

      assert {:ok, validated} = ReportBuilder.validate_config(config)
      assert validated.template == :sales_report
      assert Map.has_key?(validated, :metadata)
    end

    test "returns error when template is missing" do
      config = %{data_source: %{}}

      assert {:error, errors} = ReportBuilder.validate_config(config)
      assert {:template, "is required"} in Map.to_list(errors)
    end

    test "adds metadata to config if not present" do
      config = %{template: :test_report}

      assert {:ok, validated} = ReportBuilder.validate_config(config)
      assert Map.has_key?(validated, :metadata)
      assert is_map(validated.metadata)
    end
  end

  describe "select_template/1" do
    test "selects template by atom" do
      assert {:ok, config} = ReportBuilder.select_template(:sales_report)
      assert config.template == :sales_report
      assert config.data_source == nil
      assert config.field_mappings == %{}
      assert config.visualizations == []
    end

    test "selects template by string" do
      assert {:ok, config} = ReportBuilder.select_template("sales_report")
      assert config.template == :sales_report
    end

    test "returns error for invalid template name" do
      assert {:error, :invalid_template_name} =
               ReportBuilder.select_template("NonExistentTemplate123")
    end

    test "includes created_at timestamp in metadata" do
      {:ok, config} = ReportBuilder.select_template(:test_report)

      assert %DateTime{} = config.metadata.created_at
    end
  end

  describe "configure_data_source/2" do
    setup do
      config = %{template: :test_report}
      {:ok, config: config}
    end

    test "configures data source with valid resource", %{config: config} do
      # Using AshReports.Report as a known Ash resource module
      data_source_params = %{
        resource: AshReports.Report,
        filters: %{status: "active"}
      }

      assert {:ok, updated_config} =
               ReportBuilder.configure_data_source(config, data_source_params)

      assert updated_config.data_source.resource == AshReports.Report
      assert updated_config.data_source.filters == %{status: "active"}
      assert updated_config.data_source.relationships == []
    end

    test "includes relationships when specified", %{config: config} do
      data_source_params = %{
        resource: AshReports.Report,
        relationships: [:bands, :variables]
      }

      assert {:ok, updated_config} =
               ReportBuilder.configure_data_source(config, data_source_params)

      assert updated_config.data_source.relationships == [:bands, :variables]
    end

    test "returns error when resource is nil", %{config: config} do
      data_source_params = %{resource: nil}

      assert {:error, :resource_required} =
               ReportBuilder.configure_data_source(config, data_source_params)
    end

    test "returns error when resource is invalid", %{config: config} do
      data_source_params = %{resource: NonExistentModule}

      assert {:error, :invalid_resource} =
               ReportBuilder.configure_data_source(config, data_source_params)
    end

    test "defaults filters to empty map when not provided", %{config: config} do
      data_source_params = %{resource: AshReports.Report}

      assert {:ok, updated_config} =
               ReportBuilder.configure_data_source(config, data_source_params)

      assert updated_config.data_source.filters == %{}
    end
  end

  describe "generate_preview/2" do
    setup do
      config = %{
        template: :test_report,
        data_source: %{resource: AshReports.Report}
      }

      {:ok, config: config}
    end

    test "generates preview data", %{config: config} do
      assert {:ok, preview_data} = ReportBuilder.generate_preview(config)
      assert is_list(preview_data)
      assert length(preview_data) > 0
    end

    test "respects limit option", %{config: config} do
      assert {:ok, preview_data} = ReportBuilder.generate_preview(config, limit: 1)
      assert length(preview_data) <= 1
    end

    test "returns preview data with expected structure", %{config: config} do
      {:ok, [first_record | _]} = ReportBuilder.generate_preview(config)

      assert is_map(first_record)
      # Check for some expected keys in preview data
      assert Map.has_key?(first_record, :id)
    end

    test "returns error for invalid config" do
      invalid_config = %{template: nil}

      assert {:error, _} = ReportBuilder.generate_preview(invalid_config)
    end
  end

  describe "start_generation/2" do
    setup do
      config = %{
        template: :test_report,
        data_source: %{resource: AshReports.Report}
      }

      {:ok, config: config}
    end

    test "starts report generation", %{config: config} do
      assert {:ok, stream_id} = ReportBuilder.start_generation(config)
      assert is_binary(stream_id)
      assert String.starts_with?(stream_id, "stream_")
    end

    test "generates unique stream IDs", %{config: config} do
      {:ok, stream_id1} = ReportBuilder.start_generation(config)
      {:ok, stream_id2} = ReportBuilder.start_generation(config)

      assert stream_id1 != stream_id2
    end

    test "accepts async option", %{config: config} do
      assert {:ok, _stream_id} = ReportBuilder.start_generation(config, async: true)
    end

    test "returns error for invalid config" do
      invalid_config = %{template: nil}

      assert {:error, _} = ReportBuilder.start_generation(invalid_config)
    end
  end

  describe "export_as_dsl/1" do
    test "exports configuration as DSL code" do
      config = %{
        template: :sales_report,
        data_source: %{resource: AshReports.Report}
      }

      assert {:ok, dsl_code} = ReportBuilder.export_as_dsl(config)
      assert is_binary(dsl_code)
      assert String.contains?(dsl_code, "report :sales_report")
    end

    test "includes resource information in DSL" do
      config = %{
        template: :test_report,
        data_source: %{resource: AshReports.Report}
      }

      {:ok, dsl_code} = ReportBuilder.export_as_dsl(config)
      assert String.contains?(dsl_code, "AshReports.Report")
    end

    test "returns error for invalid config" do
      invalid_config = %{template: nil}

      assert {:error, _} = ReportBuilder.export_as_dsl(invalid_config)
    end
  end
end
