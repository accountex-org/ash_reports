defmodule AshReportsDemoWeb.ReportBuilderLive.CustomizationIntegrationTest do
  use ExUnit.Case, async: true

  alias AshReports.Customization.Config
  alias AshReportsDemoWeb.ReportBuilderLive.Index, as: ReportBuilderLive

  describe "report builder with customization workflow" do
    test "progresses through all 5 steps including customization" do
      # Test that the wizard has 5 steps
      steps = ReportBuilderLive.steps()
      assert length(steps) == 5
      assert "Customize" in steps
    end

    test "customization step is at position 3" do
      steps = ReportBuilderLive.steps()
      assert Enum.at(steps, 2) == "Customize"
    end

    test "step order is correct" do
      steps = ReportBuilderLive.steps()

      assert steps == [
               "Select Template",
               "Configure Data",
               "Customize",
               "Preview",
               "Generate"
             ]
    end
  end

  describe "customization config persistence" do
    test "config includes customization field" do
      config = %{
        template: "sales_report",
        data_source: %{resource: "Sales"},
        customization: Config.new(theme_id: :corporate, brand_colors: %{primary: "#123456"})
      }

      assert config.customization.theme_id == :corporate
      assert config.customization.brand_colors.primary == "#123456"
    end

    test "customization can be updated in config" do
      initial_config = %{
        template: "sales_report",
        customization: Config.new()
      }

      updated_customization = Config.set_theme(Config.new(), :vibrant)
      updated_config = Map.put(initial_config, :customization, updated_customization)

      assert updated_config.customization.theme_id == :vibrant
    end

    test "effective theme is calculated from config" do
      customization =
        Config.new(
          theme_id: :minimal,
          brand_colors: %{primary: "#ff5500"}
        )

      effective_theme = Config.get_effective_theme(customization)

      assert effective_theme.id == :minimal
      assert effective_theme.colors.primary == "#ff5500"
    end
  end

  describe "workflow validation" do
    test "step 3 (customization) allows progression without customization" do
      # Customization is optional, so step 3 should always pass validation
      config = %{template: "sales_report", data_source: %{resource: "Sales"}}

      assert :ok = ReportBuilderLive.validate_step(3, config)
    end

    test "step 3 allows progression with customization" do
      config = %{
        template: "sales_report",
        data_source: %{resource: "Sales"},
        customization: Config.new(theme_id: :corporate)
      }

      assert :ok = ReportBuilderLive.validate_step(3, config)
    end

    test "all validation steps work correctly" do
      # Step 1: requires template
      assert {:error, %{template: _}} = ReportBuilderLive.validate_step(1, %{})
      assert :ok = ReportBuilderLive.validate_step(1, %{template: "sales_report"})

      # Step 2: requires data source
      assert {:error, %{data_source: _}} =
               ReportBuilderLive.validate_step(2, %{template: "sales_report"})

      assert :ok =
               ReportBuilderLive.validate_step(2, %{
                 template: "sales_report",
                 data_source: %{resource: "Sales"}
               })

      # Step 3: customization optional
      assert :ok = ReportBuilderLive.validate_step(3, %{})

      # Step 4: preview - no validation
      assert :ok = ReportBuilderLive.validate_step(4, %{})
    end
  end

  describe "navigation logic" do
    test "can proceed checks validation for each step" do
      # Cannot proceed from step 1 without template
      refute ReportBuilderLive.can_proceed?(1, %{}, %{})

      # Can proceed from step 1 with template
      assert ReportBuilderLive.can_proceed?(1, %{template: "sales_report"}, %{})

      # Cannot proceed from step 2 without data source
      refute ReportBuilderLive.can_proceed?(2, %{template: "sales_report"}, %{})

      # Can proceed from step 2 with data source
      assert ReportBuilderLive.can_proceed?(2, %{
               template: "sales_report",
               data_source: %{resource: "Sales"}
             }, %{})

      # Can always proceed from step 3 (customization optional)
      assert ReportBuilderLive.can_proceed?(3, %{}, %{})

      # Can always proceed from step 4 (preview)
      assert ReportBuilderLive.can_proceed?(4, %{}, %{})
    end

    test "errors prevent progression" do
      config = %{template: "sales_report"}
      errors = %{some_field: "has an error"}

      refute ReportBuilderLive.can_proceed?(1, config, errors)
    end
  end
end
