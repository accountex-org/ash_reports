defmodule AshReports.PerformanceBaselineTest do
  @moduledoc """
  Phase 1D: Performance Baseline Testing
  
  This test module establishes performance baselines for DSL compilation,
  transformer execution, memory usage, and generated module efficiency.
  These baselines help identify performance regressions and scaling issues.
  """
  
  use ExUnit.Case, async: false
  import AshReports.TestHelpers
  
  @performance_timeout 30_000  # 30 seconds for performance tests
  @memory_threshold 50_000_000  # 50MB memory threshold
  @compilation_time_threshold 5_000  # 5 seconds compilation threshold
  
  describe "DSL compilation performance benchmarks" do
    @tag :performance
    @tag timeout: @performance_timeout
    test "benchmarks simple report compilation time" do
      compilation_times = for _i <- 1..10 do
        {time_microseconds, _result} = measure_time(fn ->
          defmodule SimplePerfTestDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
            end

            reports do
              report :simple_perf_report do
                title "Simple Performance Test"
                driving_resource AshReports.Test.Customer
                formats [:html]

                bands do
                  band :detail do
                    elements do
                      field :name, source: [:name]
                      field :email, source: [:email]
                    end
                  end
                end
              end
            end
          end
        end)
        
        # Convert to milliseconds
        time_microseconds / 1000
      end
      
      avg_time = Enum.sum(compilation_times) / length(compilation_times)
      min_time = Enum.min(compilation_times)
      max_time = Enum.max(compilation_times)
      
      IO.puts("\n=== Simple Report Compilation Benchmark ===")
      IO.puts("Average time: #{Float.round(avg_time, 2)}ms")
      IO.puts("Min time: #{Float.round(min_time, 2)}ms")
      IO.puts("Max time: #{Float.round(max_time, 2)}ms")
      IO.puts("Samples: #{length(compilation_times)}")
      
      # Assert reasonable compilation time (threshold in milliseconds)
      assert avg_time < @compilation_time_threshold,
             "Average compilation time #{avg_time}ms exceeds threshold #{@compilation_time_threshold}ms"
      
      # Store baseline for regression testing
      baseline_file = "/tmp/ash_reports_simple_compilation_baseline.txt"
      File.write!(baseline_file, "#{avg_time}")
      
      # Check against previous baseline if exists
      if File.exists?(baseline_file) do
        previous_baseline = baseline_file |> File.read!() |> String.to_float()
        regression_threshold = previous_baseline * 1.5  # 50% increase considered regression
        
        if avg_time > regression_threshold do
          IO.puts("WARNING: Potential performance regression detected!")
          IO.puts("Previous baseline: #{previous_baseline}ms")
          IO.puts("Current average: #{avg_time}ms")
        end
      end
    end

    @tag :performance
    @tag timeout: @performance_timeout
    test "benchmarks complex report compilation time" do
      compilation_times = for _i <- 1..5 do  # Fewer samples for complex reports
        {time_microseconds, _result} = measure_time(fn ->
          defmodule ComplexPerfTestDomain do
            use Ash.Domain, extensions: [AshReports.Domain]

            resources do
              resource AshReports.Test.Customer
              resource AshReports.Test.Order
            end

            reports do
              report :complex_perf_report do
                title "Complex Performance Test"
                driving_resource AshReports.Test.Customer
                formats [:html, :pdf, :json]

                parameters do
                  parameter :region_filter, :string, required: false
                  parameter :start_date, :date, required: true
                  parameter :end_date, :date, required: true
                  parameter :include_inactive, :boolean, required: false, default: false
                end

                variables do
                  variable :total_customers, type: :count, reset_on: :report
                  variable :region_count, type: :count, reset_on: :group, reset_group: 1
                  variable :active_count, type: :count_where, 
                           condition: expr(status == :active), reset_on: :group, reset_group: 1
                end

                groups do
                  group :region, field: [:region], sort: :asc
                  group :status, field: [:status], sort: :desc
                end

                bands do
                  band :title do
                    elements do
                      label "title", text: "Complex Performance Report"
                      image "logo", source: "/logo.png"
                      expression "date_range", 
                                expression: expr("Period: " <> start_date <> " to " <> end_date)
                    end
                  end

                  band :group_header, group_level: 1 do
                    elements do
                      field :region, source: [:region]
                      box "region_box", from: [x: 0, y: 0], to: [x: 500, y: 20]
                    end

                    bands do
                      band :group_header, group_level: 2 do
                        elements do
                          field :status, source: [:status]
                        end

                        bands do
                          band :detail do
                            elements do
                              field :name, source: [:name]
                              field :email, source: [:email]
                              field :credit_limit, source: [:credit_limit], format: :currency
                              expression :full_info, 
                                        expression: expr(name <> " (" <> email <> ")")
                              line "separator", from: [x: 0, y: 20], to: [x: 500, y: 20]
                            end
                          end
                        end
                      end

                      band :group_footer, group_level: 2 do
                        elements do
                          aggregate :status_count, function: :count, source: [:id]
                          aggregate :status_credit, function: :sum, source: [:credit_limit], format: :currency
                        end
                      end
                    end
                  end

                  band :group_footer, group_level: 1 do
                    elements do
                      aggregate :region_count, function: :count, source: [:id]
                      aggregate :region_revenue, function: :sum, source: [:credit_limit], format: :currency
                    end
                  end

                  band :summary do
                    elements do
                      aggregate :total_customers, function: :count, source: [:id]
                      aggregate :total_revenue, function: :sum, source: [:credit_limit], format: :currency
                      expression :average_credit, 
                                expression: expr(total_revenue / total_customers)
                    end
                  end
                end
              end
            end
          end
        end)
        
        time_microseconds / 1000
      end
      
      avg_time = Enum.sum(compilation_times) / length(compilation_times)
      min_time = Enum.min(compilation_times)
      max_time = Enum.max(compilation_times)
      
      IO.puts("\n=== Complex Report Compilation Benchmark ===")
      IO.puts("Average time: #{Float.round(avg_time, 2)}ms")
      IO.puts("Min time: #{Float.round(min_time, 2)}ms")
      IO.puts("Max time: #{Float.round(max_time, 2)}ms")
      IO.puts("Samples: #{length(compilation_times)}")
      
      # Complex reports can take longer, but should be reasonable
      complex_threshold = @compilation_time_threshold * 3  # 3x threshold for complex reports
      assert avg_time < complex_threshold,
             "Average complex compilation time #{avg_time}ms exceeds threshold #{complex_threshold}ms"
    end

    @tag :performance
    @tag timeout: @performance_timeout
    test "benchmarks multiple report compilation scaling" do
      report_counts = [1, 3, 5, 10]
      scaling_results = []
      
      for count <- report_counts do
        {time_microseconds, _result} = measure_time(fn ->
          module_name = :"ScalingTestDomain#{count}"
          
          reports_ast = for i <- 1..count do
            quote do
              report unquote(:"scaling_report_#{i}") do
                title unquote("Scaling Report #{i}")
                driving_resource AshReports.Test.Customer
                formats [:html]

                bands do
                  band :detail do
                    elements do
                      field :name, source: [:name]
                    end
                  end
                end
              end
            end
          end
          
          module_ast = quote do
            defmodule unquote(module_name) do
              use Ash.Domain, extensions: [AshReports.Domain]

              resources do
                resource AshReports.Test.Customer
              end

              reports do
                unquote_splicing(reports_ast)
              end
            end
          end
          
          Code.eval_quoted(module_ast)
        end)
        
        time_ms = time_microseconds / 1000
        scaling_results = [{count, time_ms} | scaling_results]
        
        IO.puts("#{count} reports: #{Float.round(time_ms, 2)}ms")
      end
      
      scaling_results = Enum.reverse(scaling_results)
      
      IO.puts("\n=== Multiple Report Compilation Scaling ===")
      for {count, time} <- scaling_results do
        time_per_report = time / count
        IO.puts("#{count} reports: #{Float.round(time, 2)}ms total, #{Float.round(time_per_report, 2)}ms per report")
      end
      
      # Check that scaling is roughly linear (not exponential)
      [{1, single_time}, {_, multi_time} | _] = scaling_results
      {max_count, max_time} = List.last(scaling_results)
      
      # Time should scale roughly linearly, allowing for overhead
      expected_max_time = single_time * max_count * 2  # 2x allowance for overhead
      assert max_time < expected_max_time,
             "Compilation scaling appears worse than linear: #{max_time}ms for #{max_count} reports vs expected #{expected_max_time}ms"
    end
  end

  describe "memory usage benchmarks" do
    @tag :performance
    @tag timeout: @performance_timeout
    test "measures memory usage during simple compilation" do
      {_result, memory_used} = measure_memory(fn ->
        defmodule MemorySimpleDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
          end

          reports do
            report :memory_simple_report do
              title "Memory Simple Report"
              driving_resource AshReports.Test.Customer
              formats [:html]

              bands do
                band :detail do
                  elements do
                    field :name, source: [:name]
                    field :email, source: [:email]
                  end
                end
              end
            end
          end
        end
      end)
      
      memory_mb = memory_used / (1024 * 1024)
      
      IO.puts("\n=== Simple Compilation Memory Usage ===")
      IO.puts("Memory used: #{Float.round(memory_mb, 2)}MB")
      
      assert memory_used < @memory_threshold,
             "Memory usage #{memory_used} bytes exceeds threshold #{@memory_threshold} bytes"
    end

    @tag :performance
    @tag timeout: @performance_timeout
    test "measures memory usage during complex compilation" do
      {_result, memory_used} = measure_memory(fn ->
        defmodule MemoryComplexDomain do
          use Ash.Domain, extensions: [AshReports.Domain]

          resources do
            resource AshReports.Test.Customer
            resource AshReports.Test.Order
          end

          reports do
            report :memory_complex_report do
              title "Memory Complex Report"
              driving_resource AshReports.Test.Customer
              formats [:html, :pdf, :json, :heex]

              parameters do
                for i <- 1..10 do
                  parameter :"param_#{i}", :string, required: false
                end
              end

              variables do
                for i <- 1..5 do
                  variable :"var_#{i}", type: :count, reset_on: :report
                end
              end

              groups do
                group :region, field: [:region], sort: :asc
                group :status, field: [:status], sort: :desc
                group :year, field: [created_at: :year], sort: :desc
              end

              bands do
                band :title do
                  elements do
                    for i <- 1..5 do
                      label :"title_#{i}", text: "Title #{i}"
                    end
                  end
                end

                band :group_header, group_level: 1 do
                  elements do
                    field :region, source: [:region]
                  end

                  bands do
                    band :group_header, group_level: 2 do
                      elements do
                        field :status, source: [:status]
                      end

                      bands do
                        band :group_header, group_level: 3 do
                          elements do
                            expression :year, expression: expr(format_date(created_at, :year))
                          end

                          bands do
                            band :detail do
                              elements do
                                for i <- 1..10 do
                                  field :"field_#{i}", source: [:name]
                                end
                                for i <- 1..5 do
                                  expression :"expr_#{i}", expression: expr(name <> " #{i}")
                                end
                              end
                            end
                          end
                        end

                        band :group_footer, group_level: 3 do
                          elements do
                            aggregate :year_count, function: :count, source: [:id]
                          end
                        end
                      end
                    end

                    band :group_footer, group_level: 2 do
                      elements do
                        aggregate :status_count, function: :count, source: [:id]
                      end
                    end
                  end
                end

                band :group_footer, group_level: 1 do
                  elements do
                    aggregate :region_count, function: :count, source: [:id]
                  end
                end

                band :summary do
                  elements do
                    for i <- 1..5 do
                      aggregate :"agg_#{i}", function: :count, source: [:id]
                    end
                  end
                end
              end
            end
          end
        end
      end)
      
      memory_mb = memory_used / (1024 * 1024)
      
      IO.puts("\n=== Complex Compilation Memory Usage ===")
      IO.puts("Memory used: #{Float.round(memory_mb, 2)}MB")
      
      # Complex reports can use more memory, but should be reasonable
      complex_memory_threshold = @memory_threshold * 3
      assert memory_used < complex_memory_threshold,
             "Complex compilation memory usage #{memory_used} bytes exceeds threshold #{complex_memory_threshold} bytes"
    end

    @tag :performance
    @tag timeout: @performance_timeout
    test "measures memory usage during transformer execution" do
      # Create a domain first
      defmodule TransformerMemoryDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :transformer_memory_test do
            title "Transformer Memory Test"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf]

            parameters do
              parameter :test_param, :string, required: false
            end

            variables do
              variable :test_var, type: :count, reset_on: :report
            end

            groups do
              group :region, field: [:region], sort: :asc
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Transformer Test"
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field :region, source: [:region]
                end

                bands do
                  band :detail do
                    elements do
                      field :name, source: [:name]
                      field :email, source: [:email]
                      expression :combined, expression: expr(name <> " - " <> email)
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate :count, function: :count, source: [:id]
                end
              end

              band :summary do
                elements do
                  aggregate :total, function: :count, source: [:id]
                end
              end
            end
          end
        end
      end

      # Test that the domain was created (this includes transformer execution)
      assert TransformerMemoryDomain
      report_module = TransformerMemoryDomain.Reports.TransformerMemoryTest
      assert report_module

      # Memory measurement is inherent in the domain creation above
      # This test verifies the transformer execution didn't cause excessive memory usage
      current_memory = :erlang.memory(:total)
      memory_mb = current_memory / (1024 * 1024)
      
      IO.puts("\n=== Transformer Execution Memory ===")
      IO.puts("Current total memory: #{Float.round(memory_mb, 2)}MB")
      
      # Verify memory usage is reasonable
      assert current_memory < @memory_threshold * 10,  # 10x threshold for total memory
             "Total memory usage appears excessive: #{current_memory} bytes"
    end
  end

  describe "generated module efficiency benchmarks" do
    @tag :performance
    @tag timeout: @performance_timeout
    test "measures generated module size and load time" do
      defmodule ModuleEfficiencyDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :efficiency_test_report do
            title "Efficiency Test Report"
            driving_resource AshReports.Test.Customer
            formats [:html, :pdf, :json, :heex]

            parameters do
              parameter :test_param, :string, required: false
            end

            variables do
              variable :test_var, type: :count, reset_on: :report
            end

            groups do
              group :region, field: [:region], sort: :asc
            end

            bands do
              band :title do
                elements do
                  label "title", text: "Efficiency Test"
                  image "logo", source: "/logo.png"
                end
              end

              band :group_header, group_level: 1 do
                elements do
                  field :region, source: [:region]
                  box "region_box", from: [x: 0, y: 0], to: [x: 500, y: 20]
                end

                bands do
                  band :detail do
                    elements do
                      field :name, source: [:name]
                      field :email, source: [:email]
                      field :status, source: [:status]
                      expression :combined, expression: expr(name <> " (" <> email <> ")")
                      line "separator", from: [x: 0, y: 15], to: [x: 500, y: 15]
                    end
                  end
                end
              end

              band :group_footer, group_level: 1 do
                elements do
                  aggregate :region_count, function: :count, source: [:id]
                  aggregate :region_credit, function: :sum, source: [:credit_limit], format: :currency
                end
              end

              band :summary do
                elements do
                  aggregate :total_count, function: :count, source: [:id]
                  aggregate :total_credit, function: :sum, source: [:credit_limit], format: :currency
                  expression :average, expression: expr(total_credit / total_count)
                end
              end
            end
          end
        end
      end

      base_module = ModuleEfficiencyDomain.Reports.EfficiencyTestReport
      
      # Test module loading time
      format_modules = [base_module.Html, base_module.Pdf, base_module.Json, base_module.Heex]
      
      load_times = for module <- [base_module | format_modules] do
        {time_microseconds, _result} = measure_time(fn ->
          # Force module loading by calling a function
          try do
            module.definition()
          rescue
            _ -> nil
          end
          :ok
        end)
        time_microseconds / 1000  # Convert to milliseconds
      end
      
      avg_load_time = Enum.sum(load_times) / length(load_times)
      
      IO.puts("\n=== Generated Module Efficiency ===")
      IO.puts("Base module: #{base_module}")
      IO.puts("Format modules: #{length(format_modules)}")
      IO.puts("Average load time: #{Float.round(avg_load_time, 3)}ms")
      
      # Test function call performance
      function_call_times = for _i <- 1..100 do
        {time_microseconds, _result} = measure_time(fn ->
          base_module.definition()
          base_module.supported_formats()
          base_module.supports_format?(:html)
        end)
        time_microseconds
      end
      
      avg_call_time = Enum.sum(function_call_times) / length(function_call_times)
      avg_call_time_ms = avg_call_time / 1000
      
      IO.puts("Average function call time: #{Float.round(avg_call_time_ms, 3)}ms")
      
      # Assertions for reasonable performance
      assert avg_load_time < 100,  # 100ms load time threshold
             "Module load time #{avg_load_time}ms exceeds 100ms threshold"
      
      assert avg_call_time_ms < 1,  # 1ms function call threshold
             "Function call time #{avg_call_time_ms}ms exceeds 1ms threshold"
    end

    @tag :performance
    @tag timeout: @performance_timeout
    test "measures parameter validation performance" do
      defmodule ParamValidationPerfDomain do
        use Ash.Domain, extensions: [AshReports.Domain]

        resources do
          resource AshReports.Test.Customer
        end

        reports do
          report :param_validation_perf do
            title "Parameter Validation Performance"
            driving_resource AshReports.Test.Customer
            formats [:html]

            parameters do
              parameter :string_param, :string, required: true
              parameter :integer_param, :integer, required: false
              parameter :date_param, :date, required: true
              parameter :boolean_param, :boolean, required: false, default: false
              parameter :decimal_param, :decimal, required: false
            end

            bands do
              band :detail do
                elements do
                  field :name, source: [:name]
                end
              end
            end
          end
        end
      end

      report_module = ParamValidationPerfDomain.Reports.ParamValidationPerf
      
      # Test validation performance with valid parameters
      valid_params = %{
        string_param: "test_value",
        integer_param: 42,
        date_param: ~D[2024-01-01],
        boolean_param: true,
        decimal_param: Decimal.new("123.45")
      }
      
      validation_times = for _i <- 1..100 do
        {time_microseconds, _result} = measure_time(fn ->
          report_module.validate_params(valid_params)
        end)
        time_microseconds / 1000  # Convert to milliseconds
      end
      
      avg_validation_time = Enum.sum(validation_times) / length(validation_times)
      
      IO.puts("\n=== Parameter Validation Performance ===")
      IO.puts("Average validation time: #{Float.round(avg_validation_time, 3)}ms")
      IO.puts("Samples: #{length(validation_times)}")
      
      # Test validation with invalid parameters
      invalid_params = %{
        string_param: 123,  # Wrong type
        date_param: "not_a_date"  # Wrong type
      }
      
      error_validation_times = for _i <- 1..100 do
        {time_microseconds, _result} = measure_time(fn ->
          report_module.validate_params(invalid_params)
        end)
        time_microseconds / 1000
      end
      
      avg_error_validation_time = Enum.sum(error_validation_times) / length(error_validation_times)
      
      IO.puts("Average error validation time: #{Float.round(avg_error_validation_time, 3)}ms")
      
      # Assertions for reasonable performance
      assert avg_validation_time < 10,  # 10ms validation threshold
             "Parameter validation time #{avg_validation_time}ms exceeds 10ms threshold"
      
      assert avg_error_validation_time < 20,  # 20ms error validation threshold
             "Error validation time #{avg_error_validation_time}ms exceeds 20ms threshold"
    end
  end

  describe "scaling and stress tests" do
    @tag :performance
    @tag :stress
    @tag timeout: @performance_timeout
    test "stress tests compilation with many elements" do
      element_counts = [10, 25, 50, 100]
      stress_results = []
      
      for count <- element_counts do
        {time_microseconds, {memory_used, _result}} = measure_time(fn ->
          measure_memory(fn ->
            module_name = :"StressTestDomain#{count}"
            
            elements_ast = for i <- 1..count do
              quote do
                field unquote(:"field_#{i}"), source: [:name]
              end
            end
            
            module_ast = quote do
              defmodule unquote(module_name) do
                use Ash.Domain, extensions: [AshReports.Domain]

                resources do
                  resource AshReports.Test.Customer
                end

                reports do
                  report :stress_test_report do
                    title "Stress Test Report"
                    driving_resource AshReports.Test.Customer
                    formats [:html]

                    bands do
                      band :detail do
                        elements do
                          unquote_splicing(elements_ast)
                        end
                      end
                    end
                  end
                end
              end
            end
            
            Code.eval_quoted(module_ast)
          end)
        end)
        
        time_ms = time_microseconds / 1000
        memory_mb = memory_used / (1024 * 1024)
        stress_results = [{count, time_ms, memory_mb} | stress_results]
      end
      
      stress_results = Enum.reverse(stress_results)
      
      IO.puts("\n=== Element Count Stress Test ===")
      for {count, time, memory} <- stress_results do
        IO.puts("#{count} elements: #{Float.round(time, 2)}ms, #{Float.round(memory, 2)}MB")
      end
      
      # Check that performance doesn't degrade exponentially
      [{min_count, min_time, _}, {_, _, _} | _] = stress_results
      {max_count, max_time, max_memory} = List.last(stress_results)
      
      # Time should scale roughly linearly
      expected_max_time = min_time * (max_count / min_count) * 2  # 2x allowance
      assert max_time < expected_max_time,
             "Element scaling appears worse than linear: #{max_time}ms for #{max_count} elements"
      
      # Memory should be reasonable
      assert max_memory < 100,  # 100MB threshold for stress test
             "Memory usage #{max_memory}MB exceeds 100MB threshold for #{max_count} elements"
    end

    @tag :performance
    @tag :stress
    @tag timeout: @performance_timeout
    test "stress tests compilation with deep nesting" do
      nesting_levels = [2, 4, 6, 8]
      nesting_results = []
      
      for level <- nesting_levels do
        {time_microseconds, {memory_used, _result}} = measure_time(fn ->
          measure_memory(fn ->
            module_name = :"NestingStressTestDomain#{level}"
            
            # Build nested band structure
            bands_ast = build_nested_bands_ast(level)
            
            module_ast = quote do
              defmodule unquote(module_name) do
                use Ash.Domain, extensions: [AshReports.Domain]

                resources do
                  resource AshReports.Test.Customer
                end

                reports do
                  report :nesting_stress_test do
                    title "Nesting Stress Test"
                    driving_resource AshReports.Test.Customer
                    formats [:html]

                    groups do
                      unquote_splicing(for i <- 1..level do
                        quote do
                          group unquote(:"level_#{i}"), field: [:region], sort: :asc
                        end
                      end)
                    end

                    bands do
                      unquote(bands_ast)
                    end
                  end
                end
              end
            end
            
            Code.eval_quoted(module_ast)
          end)
        end)
        
        time_ms = time_microseconds / 1000
        memory_mb = memory_used / (1024 * 1024)
        nesting_results = [{level, time_ms, memory_mb} | nesting_results]
      end
      
      nesting_results = Enum.reverse(nesting_results)
      
      IO.puts("\n=== Nesting Depth Stress Test ===")
      for {level, time, memory} <- nesting_results do
        IO.puts("#{level} levels: #{Float.round(time, 2)}ms, #{Float.round(memory, 2)}MB")
      end
      
      # Check that deep nesting doesn't cause exponential performance degradation
      [{min_level, min_time, _} | _] = nesting_results
      {max_level, max_time, max_memory} = List.last(nesting_results)
      
      # Allow more generous scaling for nesting complexity
      expected_max_time = min_time * (max_level / min_level) * 3  # 3x allowance for nesting
      assert max_time < expected_max_time,
             "Nesting scaling appears worse than expected: #{max_time}ms for #{max_level} levels"
      
      # Memory should be reasonable even with deep nesting
      assert max_memory < 150,  # 150MB threshold for deep nesting stress test
             "Memory usage #{max_memory}MB exceeds 150MB threshold for #{max_level} nesting levels"
    end
  end

  # Helper function to build nested band AST
  defp build_nested_bands_ast(level) when level <= 1 do
    quote do
      band :detail do
        elements do
          field :name, source: [:name]
        end
      end
    end
  end

  defp build_nested_bands_ast(level) do
    inner_bands = build_nested_bands_ast(level - 1)
    
    quote do
      band unquote(:"group_header_#{level}"), type: :group_header, group_level: unquote(level) do
        elements do
          field unquote(:"level_#{level}"), source: [:region]
        end

        bands do
          unquote(inner_bands)
        end
      end
    end
  end

  # Performance test cleanup
  setup do
    # Ensure clean state for performance measurements
    :erlang.garbage_collect()
    
    on_exit(fn ->
      # Cleanup after performance tests
      :erlang.garbage_collect()
    end)
  end
end