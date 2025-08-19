unless Code.ensure_loaded?(AshReports.TestHelpers) do
  defmodule AshReports.TestHelpers do
    @moduledoc """
    Standardized test helpers for AshReports testing.

    This module provides utilities for DSL testing, report creation,
    and assertion helpers following the expert-recommended testing patterns.
    """

    import ExUnit.Assertions

    alias Spark.Dsl.Extension

    @doc """
    Parses DSL content and returns the DSL state.

    This helper simulates DSL parsing without full module compilation
    to avoid deadlocks during testing.
    """
    def parse_dsl(dsl_content, extension \\ AshReports) do
      # Create a temporary module for DSL parsing
      module_name = :"TestModule#{:rand.uniform(999_999)}"

      try do
        Code.eval_string("""
        defmodule #{module_name} do
          use Ash.Domain, extensions: [#{extension}]
          
          #{dsl_content}
        end
        """)

        # Extract DSL state using Spark APIs
        dsl_state = Extension.get_persisted(module_name, :dsl_state)
        {:ok, dsl_state}
      rescue
        error -> {:error, error}
      after
        # Clean up the temporary module
        if Code.ensure_loaded?(module_name) do
          :code.delete(module_name)
          :code.purge(module_name)
        end
      end
    end

    @doc """
    Asserts that DSL content is valid and parses correctly.
    """
    def assert_dsl_valid(dsl_content, extension \\ AshReports) do
      case parse_dsl(dsl_content, extension) do
        {:ok, _dsl_state} -> :ok
        {:error, error} -> flunk("Expected DSL to be valid, but got error: #{inspect(error)}")
      end
    end

    @doc """
    Asserts that DSL content produces a specific error.
    """
    def assert_dsl_error(dsl_content, expected_error_message, extension \\ AshReports) do
      case parse_dsl(dsl_content, extension) do
        {:ok, _dsl_state} ->
          flunk("Expected DSL to produce error '#{expected_error_message}', but it was valid")

        {:error, error} ->
          error_string = inspect(error)

          assert String.contains?(error_string, expected_error_message),
                 "Expected error to contain '#{expected_error_message}', but got: #{error_string}"
      end
    end

    @doc """
    Extracts entities from a DSL state for testing.
    """
    def get_dsl_entities(dsl_state, path) do
      Extension.get_entities(dsl_state, path)
    end

    @doc """
    Extracts options from a DSL state for testing.
    """
    def get_dsl_option(dsl_state, path, option_name, default \\ nil) do
      Extension.get_opt(dsl_state, path, option_name, default)
    end

    @doc """
    Creates a simple test report for basic testing scenarios.
    """
    def build_simple_report(opts \\ []) do
      name = Keyword.get(opts, :name, :test_report)
      title = Keyword.get(opts, :title, "Test Report")
      resource = Keyword.get(opts, :resource, AshReports.Test.Customer)

      %AshReports.Report{
        name: name,
        title: title,
        driving_resource: resource,
        bands: [
          %AshReports.Band{
            name: :title,
            type: :title,
            elements: [
              %AshReports.Element.Label{
                name: :title_label,
                text: title,
                position: [x: 0, y: 0]
              }
            ]
          },
          %AshReports.Band{
            name: :detail,
            type: :detail,
            elements: [
              %AshReports.Element.Field{
                name: :name_field,
                source: :name,
                position: [x: 0, y: 0]
              }
            ]
          }
        ]
      }
    end

    @doc """
    Creates a complex test report with multiple bands and elements.
    """
    def build_complex_report(opts \\ []) do
      name = Keyword.get(opts, :name, :complex_test_report)
      title = Keyword.get(opts, :title, "Complex Test Report")
      resource = Keyword.get(opts, :resource, AshReports.Test.Order)

      %AshReports.Report{
        name: name,
        title: title,
        driving_resource: resource,
        parameters: [
          %AshReports.Parameter{
            name: :start_date,
            type: :date,
            required: true
          },
          %AshReports.Parameter{
            name: :end_date,
            type: :date,
            required: true
          }
        ],
        variables: [
          %AshReports.Variable{
            name: :total_sales,
            type: :sum,
            expression: {:sum, :total_amount},
            reset_on: :report
          }
        ],
        groups: [
          %AshReports.Group{
            name: :by_region,
            level: 1,
            expression: {:field, :customer, :region}
          }
        ],
        bands: [
          %AshReports.Band{
            name: :title,
            type: :title,
            elements: [
              %AshReports.Element.Label{
                name: :title_label,
                text: title,
                position: [x: 0, y: 0]
              }
            ]
          },
          %AshReports.Band{
            name: :group_header,
            type: :group_header,
            group_level: 1,
            elements: [
              %AshReports.Element.Field{
                name: :region_field,
                source: {:field, :customer, :region},
                position: [x: 0, y: 0]
              }
            ]
          },
          %AshReports.Band{
            name: :detail,
            type: :detail,
            elements: [
              %AshReports.Element.Field{
                name: :order_number,
                source: :order_number,
                position: [x: 0, y: 0]
              },
              %AshReports.Element.Field{
                name: :total_amount,
                source: :total_amount,
                format: :currency,
                position: [x: 100, y: 0]
              }
            ]
          },
          %AshReports.Band{
            name: :group_footer,
            type: :group_footer,
            group_level: 1,
            elements: [
              %AshReports.Element.Aggregate{
                name: :group_total,
                source: {:sum, :total_amount},
                format: :currency,
                position: [x: 100, y: 0]
              }
            ]
          }
        ]
      }
    end

    @doc """
    Creates test data for the mock resources.
    """
    def create_test_data(resource \\ :all, count \\ 10)

    def create_test_data(:customers, count) do
      Enum.map(1..count, fn i ->
        [
          id: "customer_#{i}",
          name: "Customer #{i}",
          email: "customer#{i}@test.com",
          region: Enum.random(["North", "South", "East", "West"]),
          status: Enum.random([:active, :inactive, :pending]),
          credit_limit: Decimal.new("#{1000 + i * 100}")
        ]
      end)
    end

    def create_test_data(:orders, count) do
      customer_ids = 1..div(count, 2) |> Enum.map(&"customer_#{&1}")

      Enum.map(1..count, fn i ->
        [
          id: "order_#{i}",
          order_number: "ORD-#{String.pad_leading(to_string(i), 6, "0")}",
          order_date: Date.add(Date.utc_today(), -:rand.uniform(365)),
          status: Enum.random([:pending, :processing, :shipped, :delivered, :cancelled]),
          total_amount: Decimal.new("#{100 + :rand.uniform(900)}"),
          shipping_cost: Decimal.new("#{10 + :rand.uniform(20)}"),
          tax_amount: Decimal.new("#{5 + :rand.uniform(15)}"),
          customer_id: Enum.random(customer_ids)
        ]
      end)
    end

    def create_test_data(:products, count) do
      categories = ["Electronics", "Books", "Clothing", "Home", "Sports"]

      Enum.map(1..count, fn i ->
        [
          id: "product_#{i}",
          name: "Product #{i}",
          sku: "SKU-#{String.pad_leading(to_string(i), 4, "0")}",
          description: "Test product #{i} description",
          category: Enum.random(categories),
          price: Decimal.new("#{10 + :rand.uniform(200)}"),
          cost: Decimal.new("#{5 + :rand.uniform(100)}"),
          weight: Decimal.new("#{1 + :rand.uniform(10)}"),
          active: Enum.random([true, false])
        ]
      end)
    end

    def create_test_data(:all, count) do
      %{
        customers: create_test_data(:customers, count),
        orders: create_test_data(:orders, count * 2),
        products: create_test_data(:products, div(count, 2))
      }
    end

    @doc """
    Sets up test data in the mock data layer.
    """
    def setup_test_data(data_map \\ nil) do
      data = data_map || create_test_data(:all, 10)

      if Map.has_key?(data, :customers) do
        AshReports.MockDataLayer.insert_test_data(AshReports.Test.Customer, data.customers)
      end

      if Map.has_key?(data, :orders) do
        AshReports.MockDataLayer.insert_test_data(AshReports.Test.Order, data.orders)
      end

      if Map.has_key?(data, :products) do
        AshReports.MockDataLayer.insert_test_data(AshReports.Test.Product, data.products)
      end

      data
    end

    @doc """
    Cleans up test data from all mock resources.
    """
    def cleanup_test_data do
      AshReports.MockDataLayer.clear_all_test_data()
    end

    @doc """
    Asserts that bands are in the correct order according to type hierarchy.
    """
    def assert_band_order(bands) do
      type_order = [
        :title,
        :page_header,
        :column_header,
        :group_header,
        :detail_header,
        :detail,
        :detail_footer,
        :group_footer,
        :column_footer,
        :page_footer,
        :summary
      ]

      band_types = Enum.map(bands, & &1.type)

      # Check that each band type appears in the correct relative order
      indexed_types = Enum.with_index(band_types)

      for {type, index} <- indexed_types do
        type_index = Enum.find_index(type_order, &(&1 == type))

        # Check that no earlier band types appear after this one
        remaining_types = Enum.drop(band_types, index + 1)

        for remaining_type <- remaining_types do
          remaining_type_index = Enum.find_index(type_order, &(&1 == remaining_type))

          if remaining_type_index < type_index do
            flunk("Band type #{remaining_type} appears after #{type}, but should come before it")
          end
        end
      end
    end

    @doc """
    Asserts that elements are of the expected types.
    """
    def assert_element_types(elements, expected_types) do
      actual_types =
        Enum.map(elements, fn element ->
          case element do
            %AshReports.Element.Field{} -> :field
            %AshReports.Element.Label{} -> :label
            %AshReports.Element.Expression{} -> :expression
            %AshReports.Element.Aggregate{} -> :aggregate
            %AshReports.Element.Line{} -> :line
            %AshReports.Element.Box{} -> :box
            %AshReports.Element.Image{} -> :image
            _ -> :unknown
          end
        end)

      assert actual_types == expected_types,
             "Expected element types #{inspect(expected_types)}, but got #{inspect(actual_types)}"
    end

    @doc """
    Asserts that a module was generated at compile time.
    """
    def assert_module_generated(module_name) do
      assert Code.ensure_loaded?(module_name),
             "Expected module #{module_name} to be generated, but it was not found"
    end

    @doc """
    Asserts that a module was not generated.
    """
    def refute_module_generated(module_name) do
      refute Code.ensure_loaded?(module_name),
             "Expected module #{module_name} to not be generated, but it was found"
    end

    @doc """
    Helper for testing transformer effects on DSL state.
    """
    def apply_transformer(dsl_state, transformer_module) do
      transformer_module.transform(dsl_state)
    end

    @doc """
    Helper for testing verifier validation.
    """
    def apply_verifier(dsl_state, verifier_module) do
      verifier_module.verify(dsl_state)
    end

    @doc """
    Eventually helper for async operations with timeout.
    """
    def eventually(fun, timeout \\ 5000) do
      eventually_loop(fun, timeout, System.monotonic_time(:millisecond))
    end

    defp eventually_loop(fun, timeout, start_time) do
      fun.()
    rescue
      error ->
        current_time = System.monotonic_time(:millisecond)

        if current_time - start_time > timeout do
          reraise error, __STACKTRACE__
        else
          Process.sleep(50)
          eventually_loop(fun, timeout, start_time)
        end
    end

    @doc """
    Memory monitoring helper for performance tests.
    """
    def measure_memory(fun) do
      before_memory = :erlang.memory(:total)
      result = fun.()
      after_memory = :erlang.memory(:total)
      memory_used = after_memory - before_memory

      {result, memory_used}
    end

    @doc """
    Time measurement helper for performance tests.
    """
    def measure_time(fun) do
      :timer.tc(fun)
    end

    @doc """
    Assertion helper for DSL compilation errors with specific path context.
    """
    def assert_dsl_error_at_path(
          dsl_content,
          expected_error,
          expected_path,
          extension \\ AshReports
        ) do
      case parse_dsl(dsl_content, extension) do
        {:ok, _dsl_state} ->
          flunk(
            "Expected DSL to produce error at path #{inspect(expected_path)}, but it was valid"
          )

        {:error, %Spark.Error.DslError{path: path} = error} ->
          assert path == expected_path,
                 "Expected error at path #{inspect(expected_path)}, but got path #{inspect(path)}"

          error_string = inspect(error)

          assert String.contains?(error_string, expected_error),
                 "Expected error to contain '#{expected_error}', but got: #{error_string}"

        {:error, error} ->
          flunk("Expected Spark.Error.DslError, but got: #{inspect(error)}")
      end
    end
  end
end
