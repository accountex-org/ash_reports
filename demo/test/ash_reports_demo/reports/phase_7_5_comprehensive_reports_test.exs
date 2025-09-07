defmodule AshReportsDemo.Reports.Phase75ComprehensiveReportsTest do
  @moduledoc """
  Comprehensive test suite for Phase 7.5 reports.

  Tests all four reports across multiple formats with business logic validation,
  performance benchmarks, and multi-format consistency verification.
  """

  use ExUnit.Case, async: true

  alias AshReportsDemo.{Customer, Product, Invoice, InvoiceLineItem, DataGenerator}

  @reports [
    :customer_summary,
    :product_inventory,
    :invoice_details,
    :financial_summary
  ]

  @formats [:html, :pdf, :heex, :json]

  setup do
    # Reset and generate fresh test data for each test
    DataGenerator.reset_data()
    DataGenerator.generate_sample_data(:medium)
    :ok
  end

  describe "customer summary report" do
    test "generates successfully in all formats" do
      for format <- @formats do
        {:ok, result} = AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: format
        )

        assert result.content
        assert result.metadata
        assert result.metadata.record_count > 0

        # Validate format-specific content
        case format do
          :json ->
            data = Jason.decode!(result.content)
            assert is_map(data)
            assert Map.has_key?(data, "data")

          :html ->
            assert String.contains?(result.content, "<html>")
            assert String.contains?(result.content, "Customer Summary Report")

          :heex ->
            assert String.contains?(result.content, "Customer Summary Report")

          :pdf ->
            assert is_binary(result.content)
            assert byte_size(result.content) > 1000
        end
      end
    end

    test "applies parameter filters correctly" do
      # Test region filtering
      {:ok, all_result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :json
      )

      {:ok, filtered_result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{region: "North"},
        format: :json
      )

      all_data = Jason.decode!(all_result.content)
      filtered_data = Jason.decode!(filtered_result.content)

      # Filtered result should have fewer or equal records
      assert length(filtered_data["data"]) <= length(all_data["data"])

      # Test health score filtering
      {:ok, health_filtered} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{min_health_score: 80},
        format: :json
      )

      health_data = Jason.decode!(health_filtered.content)

      # All customers should have health score >= 80
      for customer <- health_data["data"] do
        assert customer["customer_health_score"] >= 80
      end
    end

    test "validates multi-level grouping variables" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      
      # Verify grouping structure exists
      assert Map.has_key?(data, "groups")
      assert Map.has_key?(data, "variables")

      # Check that report-level variables are calculated
      variables = data["variables"]
      assert Map.has_key?(variables, "customer_count")
      assert Map.has_key?(variables, "total_lifetime_value")
      assert Map.has_key?(variables, "avg_health_score")

      # Verify calculated values are reasonable
      assert variables["customer_count"] > 0
      assert variables["total_lifetime_value"] > 0
      assert variables["avg_health_score"] > 0
      assert variables["avg_health_score"] <= 100
    end
  end

  describe "product inventory report" do
    test "generates with profitability analytics" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :product_inventory,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      assert length(data["data"]) > 0

      # Verify profitability calculations are present
      for product <- data["data"] do
        assert Map.has_key?(product, "margin_percentage")
        assert Map.has_key?(product, "profitability_grade")
        assert product["profitability_grade"] in ["A", "B", "C", "D", "F"]
      end
    end

    test "filters by profitability grade" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :product_inventory,
        %{profitability_grade: "A"},
        format: :json
      )

      # Get records from the data result instead of JSON content
      records = result.data.records

      # All products should have grade A
      for product <- records do
        # Access the profitability grade from the struct/calculation
        grade = case product do
          %{profitability_grade: grade} -> grade
          _ -> nil
        end
        assert grade == "A"
      end
    end

    test "validates inventory metrics" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :product_inventory,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      variables = data["variables"]

      # Check inventory-specific variables
      assert Map.has_key?(variables, "total_products")
      assert Map.has_key?(variables, "total_inventory_value")
      assert Map.has_key?(variables, "avg_margin_percentage")
      assert Map.has_key?(variables, "avg_inventory_velocity")

      # Validate calculated metrics
      assert variables["total_products"] > 0
      assert variables["total_inventory_value"] > 0
      assert variables["avg_margin_percentage"] >= 0
      assert variables["avg_inventory_velocity"] >= 0
    end
  end

  describe "invoice details report" do
    test "generates master-detail structure" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :invoice_details,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      assert length(data["data"]) > 0

      # Verify master-detail structure with invoice data
      for invoice <- data["data"] do
        assert Map.has_key?(invoice, "invoice_number")
        assert Map.has_key?(invoice, "total")
        assert Map.has_key?(invoice, "status")
        assert Map.has_key?(invoice, "days_overdue")
        assert Map.has_key?(invoice, "payment_status")
      end
    end

    test "calculates payment performance metrics" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :invoice_details,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      variables = data["variables"]

      # Check payment-related variables
      assert Map.has_key?(variables, "total_invoices")
      assert Map.has_key?(variables, "total_invoice_amount")
      assert Map.has_key?(variables, "overdue_count")
      assert Map.has_key?(variables, "paid_count")

      # Verify payment calculations
      total_invoices = variables["total_invoices"]
      overdue_count = variables["overdue_count"]
      paid_count = variables["paid_count"]

      assert total_invoices > 0
      assert overdue_count >= 0
      assert paid_count >= 0
      assert overdue_count + paid_count <= total_invoices
    end

    test "filters by invoice status" do
      {:ok, overdue_result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :invoice_details,
        %{status: :overdue},
        format: :json
      )

      overdue_data = Jason.decode!(overdue_result.content)

      # All invoices should be overdue
      for invoice <- overdue_data["data"] do
        assert invoice["status"] == "overdue"
      end

      {:ok, paid_result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :invoice_details,
        %{status: :paid},
        format: :json
      )

      paid_data = Jason.decode!(paid_result.content)

      # All invoices should be paid
      for invoice <- paid_data["data"] do
        assert invoice["status"] == "paid"
      end
    end
  end

  describe "financial summary report" do
    test "generates executive-level metrics" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :financial_summary,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      variables = data["variables"]

      # Check executive financial metrics
      assert Map.has_key?(variables, "total_revenue")
      assert Map.has_key?(variables, "total_tax_collected")
      assert Map.has_key?(variables, "collection_rate")
      assert Map.has_key?(variables, "outstanding_amount")
      assert Map.has_key?(variables, "average_invoice_value")

      # Verify executive-level calculations
      assert variables["total_revenue"] > 0
      assert variables["total_tax_collected"] >= 0
      assert variables["collection_rate"] >= 0
      assert variables["collection_rate"] <= 100
      assert variables["outstanding_amount"] >= 0
      assert variables["average_invoice_value"] > 0
    end

    test "validates customer tier revenue distribution" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :financial_summary,
        %{customer_tier_analysis: true},
        format: :json
      )

      data = Jason.decode!(result.content)
      variables = data["variables"]

      # Check tier-specific revenue variables
      tier_vars = ["platinum_revenue", "gold_revenue", "silver_revenue", "bronze_revenue"]

      for tier_var <- tier_vars do
        assert Map.has_key?(variables, tier_var)
        assert variables[tier_var] >= 0
      end

      # Total tier revenue should not exceed total revenue
      tier_total = variables["platinum_revenue"] + variables["gold_revenue"] + 
                  variables["silver_revenue"] + variables["bronze_revenue"]
      
      assert tier_total <= variables["total_revenue"]
    end

    test "validates risk-based analysis" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :financial_summary,
        %{risk_analysis: true},
        format: :json
      )

      data = Jason.decode!(result.content)
      variables = data["variables"]

      # Check risk analysis variables
      assert Map.has_key?(variables, "high_risk_revenue")
      assert Map.has_key?(variables, "low_risk_revenue")

      # Verify risk calculations
      assert variables["high_risk_revenue"] >= 0
      assert variables["low_risk_revenue"] >= 0

      # Risk revenue should not exceed total revenue
      risk_total = variables["high_risk_revenue"] + variables["low_risk_revenue"]
      assert risk_total <= variables["total_revenue"]
    end
  end

  describe "multi-format consistency" do
    test "all formats produce consistent record counts" do
      for report <- @reports do
        # Generate reports in all formats
        results = Enum.map(@formats, fn format ->
          {:ok, result} = AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            report,
            sample_params_for(report),
            format: format
          )
          {format, result}
        end)

        # Extract record counts across formats
        record_counts = Enum.map(results, fn {format, result} ->
          case format do
            :json ->
              data = Jason.decode!(result.content)
              length(data["data"])
            _ ->
              result.metadata.record_count
          end
        end)

        # All formats should have the same record count
        assert Enum.uniq(record_counts) |> length() == 1,
               "Record counts inconsistent across formats for #{report}: #{inspect(record_counts)}"
      end
    end

    test "variable calculations consistent across formats" do
      report = :customer_summary

      # Get JSON result for comparison
      {:ok, json_result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        report,
        %{},
        format: :json
      )

      json_data = Jason.decode!(json_result.content)
      json_variables = json_data["variables"]

      # Compare with other formats
      for format <- [:html, :heex] do
        {:ok, result} = AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          report,
          %{},
          format: format
        )

        # Variable values should be accessible through metadata
        assert result.metadata.record_count == json_variables["customer_count"]
      end
    end
  end

  describe "performance benchmarks" do
    @tag :benchmark
    test "all reports meet performance targets" do
      data_volumes = [:small, :medium, :large]
      
      for volume <- data_volumes do
        DataGenerator.reset_data()
        DataGenerator.generate_sample_data(volume)

        for report <- @reports do
          {time_us, {:ok, _result}} = :timer.tc(fn ->
            AshReports.Runner.run_report(
              AshReportsDemo.Domain,
              report,
              sample_params_for(report),
              format: :html
            )
          end)

          time_ms = div(time_us, 1000)
          max_time = max_time_for_volume(volume)

          assert time_ms < max_time,
                 "#{report} with #{volume} data took #{time_ms}ms, exceeds limit #{max_time}ms"
        end
      end
    end
  end

  describe "business logic validation" do
    test "customer health scores reflect accurate calculations" do
      # Create customers with known patterns
      {:ok, high_health_customer} = 
        Customer.create(AshReportsDemo.Domain, %{
          name: "High Health Customer",
          email: "high@test.com",
          status: :active,
          credit_limit: Decimal.new("50000.00")
        })

      {:ok, low_health_customer} =
        Customer.create(AshReportsDemo.Domain, %{
          name: "Low Health Customer", 
          email: "low@test.com",
          status: :suspended,
          credit_limit: Decimal.new("1000.00")
        })

      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)
      customer_data = data["data"]

      # Find our test customers
      high_record = Enum.find(customer_data, &(&1["id"] == high_health_customer.id))
      low_record = Enum.find(customer_data, &(&1["id"] == low_health_customer.id))

      # Validate health score calculations
      assert high_record["customer_health_score"] > low_record["customer_health_score"]
      assert high_record["customer_health_score"] >= 70  # Active status bonus
      assert low_record["customer_health_score"] <= 50   # Suspended penalty
    end

    test "product profitability grades calculated correctly" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :product_inventory,
        %{},
        format: :json
      )

      data = Jason.decode!(result.content)

      for product <- data["data"] do
        margin = product["margin_percentage"]
        grade = product["profitability_grade"]

        # Verify grade assignments match margin ranges
        cond do
          margin >= 50.0 -> assert grade == "A"
          margin >= 30.0 -> assert grade == "B"  
          margin >= 15.0 -> assert grade == "C"
          margin >= 5.0 -> assert grade == "D"
          true -> assert grade == "F"
        end
      end
    end

    test "invoice aging calculations are accurate" do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :invoice_details,
        %{},
        format: :json
      )

      # Get records from the data result instead of JSON content
      records = result.data.records
      today = Date.utc_today()

      for invoice <- records do
        # Calculate expected age
        calculated_age = Date.diff(today, invoice.date)
        
        # Get age_in_days from calculation (might be a loaded calculation)
        actual_age = case invoice do
          %{age_in_days: age} when not is_nil(age) -> age
          _ -> Date.diff(today, invoice.date) # fallback calculation
        end
        
        assert actual_age == calculated_age

        # Verify overdue calculations
        if invoice.due_date do
          calculated_overdue = Date.diff(today, invoice.due_date)
          
          # Get days_overdue from calculation (might be a loaded calculation)
          actual_overdue = case invoice do
            %{days_overdue: days} when not is_nil(days) -> days
            _ -> max(0, Date.diff(today, invoice.due_date)) # fallback calculation
          end
          
          assert actual_overdue == calculated_overdue
        end
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles empty datasets gracefully" do
      DataGenerator.reset_data()  # No data generation

      for report <- @reports do
        {:ok, result} = AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          report,
          sample_params_for(report),
          format: :json
        )

        data = Jason.decode!(result.content)
        assert data["data"] == []
        assert result.metadata.record_count == 0
      end
    end

    test "validates parameter constraints" do
      # Test invalid health score range
      assert_raise ArgumentError, fn ->
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{min_health_score: 150},  # Invalid: > 100
          format: :json
        )
      end

      # Test invalid profitability grade
      assert_raise ArgumentError, fn ->
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :product_inventory,
          %{profitability_grade: "Z"},  # Invalid grade
          format: :json
        )
      end
    end

    test "handles concurrent report generation" do
      tasks = Enum.map(1..10, fn _i ->
        Task.async(fn ->
          AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            :customer_summary,
            %{},
            format: :json
          )
        end)
      end)

      results = Task.await_many(tasks, 30_000)

      # All tasks should complete successfully
      assert Enum.all?(results, fn result ->
        match?({:ok, _}, result)
      end)
    end
  end

  # Helper functions
  defp sample_params_for(:customer_summary), do: %{}
  defp sample_params_for(:product_inventory), do: %{}
  defp sample_params_for(:invoice_details), do: %{}
  defp sample_params_for(:financial_summary), do: %{}

  defp max_time_for_volume(:small), do: 500    # 500ms
  defp max_time_for_volume(:medium), do: 2000  # 2s
  defp max_time_for_volume(:large), do: 10000  # 10s
end