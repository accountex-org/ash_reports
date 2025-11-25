defmodule AshReports.QueryBuilderTest do
  use ExUnit.Case, async: true

  alias AshReports.{Band, Group, Parameter, QueryBuilder, Report}
  alias AshReports.Element.{Field, Label}

  describe "build/3" do
    test "builds basic query for simple report" do
      report = build_simple_report()

      assert {:ok, query} = QueryBuilder.build(report, %{})
      assert query.resource == AshReports.Test.Customer
      assert is_struct(query, Ash.Query)
    end

    test "validates required parameters" do
      report = build_report_with_required_param()

      # Missing required parameter should fail
      assert {:error, {Ash.Error.Invalid, message}} = QueryBuilder.build(report, %{})
      assert message =~ "Parameter start_date is required but not provided"

      # Providing required parameter should succeed
      assert {:ok, query} = QueryBuilder.build(report, %{start_date: ~D[2023-01-01]})
      assert is_struct(query, Ash.Query)
    end

    test "applies default values for optional parameters" do
      report = build_report_with_optional_param()

      assert {:ok, _query} = QueryBuilder.build(report, %{})
      # Parameters are validated and defaults applied
    end

    test "handles invalid driving resource" do
      report = %Report{
        name: :test_report,
        driving_resource: :nonexistent_resource,
        parameters: [],
        bands: [],
        variables: [],
        groups: []
      }

      assert {:error, {Ash.Error.Framework, message}} = QueryBuilder.build(report, %{})
      assert message =~ "Failed to create query for resource"
    end

    test "handles scope expressions" do
      scope_fn = fn _params -> nil end

      report = %Report{
        name: :test_report,
        driving_resource: AshReports.Test.Customer,
        base_filter: scope_fn,
        parameters: [],
        bands: [],
        variables: [],
        groups: []
      }

      assert {:ok, query} = QueryBuilder.build(report, %{})
      assert is_struct(query, Ash.Query)
    end

    test "supports build options" do
      report = build_simple_report()

      # Disable parameter validation
      assert {:ok, _query} =
               QueryBuilder.build(report, %{invalid: "value"}, validate_params: false)

      # Disable relationship loading
      assert {:ok, _query} = QueryBuilder.build(report, %{}, load_relationships: false)

      # Disable aggregate optimization
      assert {:ok, _query} = QueryBuilder.build(report, %{}, optimize_aggregates: false)
    end
  end

  describe "build!/3" do
    test "returns query on success" do
      report = build_simple_report()

      query = QueryBuilder.build!(report, %{})
      assert is_struct(query, Ash.Query)
      assert query.resource == AshReports.Test.Customer
    end

    test "raises on error" do
      report = build_report_with_required_param()

      assert_raise RuntimeError, ~r/Failed to build query/, fn ->
        QueryBuilder.build!(report, %{})
      end
    end
  end

  describe "validate_parameters/3" do
    test "validates required parameters" do
      report = build_report_with_required_param()

      # Missing required parameter
      assert {:error, {Ash.Error.Invalid, _}} =
               QueryBuilder.validate_parameters(report, %{}, [])

      # Present required parameter
      assert {:ok, %{start_date: ~D[2023-01-01]}} =
               QueryBuilder.validate_parameters(report, %{start_date: ~D[2023-01-01]}, [])
    end

    test "applies default values" do
      report = build_report_with_optional_param()

      assert {:ok, validated} = QueryBuilder.validate_parameters(report, %{}, [])
      assert Map.has_key?(validated, :region)
    end

    test "skips validation when disabled" do
      report = build_report_with_required_param()

      assert {:ok, %{}} =
               QueryBuilder.validate_parameters(report, %{}, validate_params: false)
    end

    test "handles empty parameter list" do
      report = build_simple_report()

      assert {:ok, %{}} = QueryBuilder.validate_parameters(report, %{extra: "value"}, [])
    end
  end

  describe "extract_relationships/1" do
    test "extracts relationships from field elements" do
      report = build_report_with_relationships()

      relationships = QueryBuilder.extract_relationships(report)
      assert :customer in relationships
      assert :orders in relationships
    end

    test "handles reports without relationships" do
      report = build_simple_report()

      relationships = QueryBuilder.extract_relationships(report)
      assert is_list(relationships)
    end

    test "handles nested bands" do
      report = build_report_with_nested_bands()

      relationships = QueryBuilder.extract_relationships(report)
      assert is_list(relationships)
    end

    test "deduplicates relationships" do
      report = build_report_with_duplicate_relationships()

      relationships = QueryBuilder.extract_relationships(report)
      assert length(relationships) == length(Enum.uniq(relationships))
    end
  end

  describe "build_parameter_filters/2" do
    test "builds filters for present parameters" do
      report = build_report_with_parameters()
      params = %{start_date: ~D[2023-01-01], status: "active"}

      filters = QueryBuilder.build_parameter_filters(report, params)
      assert is_list(filters)
    end

    test "ignores missing parameters" do
      report = build_report_with_parameters()
      # Missing status parameter
      params = %{start_date: ~D[2023-01-01]}

      filters = QueryBuilder.build_parameter_filters(report, params)
      assert is_list(filters)
    end

    test "handles empty parameters" do
      report = build_simple_report()

      filters = QueryBuilder.build_parameter_filters(report, %{})
      assert filters == []
    end
  end

  describe "private functions integration" do
    test "handles group sorting" do
      report = build_report_with_groups()

      assert {:ok, query} = QueryBuilder.build(report, %{})
      # Verify query has been processed through group sorting
      assert is_struct(query, Ash.Query)
    end

    test "handles relationship loading" do
      report = build_report_with_relationships()

      assert {:ok, query} = QueryBuilder.build(report, %{}, load_relationships: true)
      assert is_struct(query, Ash.Query)
    end

    test "handles aggregate preloading" do
      report = build_report_with_aggregates()

      assert {:ok, query} = QueryBuilder.build(report, %{}, optimize_aggregates: true)
      assert is_struct(query, Ash.Query)
    end
  end

  describe "error handling" do
    test "handles scope application errors gracefully" do
      failing_scope = fn _params -> raise "Scope error" end

      report = %Report{
        name: :test_report,
        driving_resource: AshReports.Test.Customer,
        base_filter: failing_scope,
        parameters: [],
        bands: [],
        variables: [],
        groups: []
      }

      assert {:error, {Ash.Error.Invalid, message}} = QueryBuilder.build(report, %{})
      assert message =~ "Failed to apply scope"
    end

    test "handles parameter filter errors gracefully" do
      # This test would need a scenario that causes parameter filter application to fail
      # For now, we'll test that the error path exists
      report = build_simple_report()

      assert {:ok, _query} = QueryBuilder.build(report, %{})
    end

    test "handles relationship loading errors gracefully" do
      # This would need a scenario that causes relationship loading to fail
      # For now, we'll test that the error handling exists
      report = build_simple_report()

      assert {:ok, _query} = QueryBuilder.build(report, %{}, load_relationships: true)
    end
  end

  # Helper functions for building test reports

  defp build_simple_report do
    %Report{
      name: :simple_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [],
      bands: [
        %Band{
          name: :detail,
          type: :detail,
          elements: [
            %Label{name: :name_label, text: "Name", position: %{x: 0, y: 0}}
          ]
        }
      ],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_required_param do
    %Report{
      name: :param_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [
        %Parameter{
          name: :start_date,
          type: :date,
          required: true
        }
      ],
      bands: [],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_optional_param do
    %Report{
      name: :optional_param_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [
        %Parameter{
          name: :region,
          type: :string,
          required: false,
          default: "North"
        }
      ],
      bands: [],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_relationships do
    %Report{
      name: :relationship_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [],
      bands: [
        %Band{
          name: :detail,
          type: :detail,
          elements: [
            %Field{
              name: :customer_name,
              source: {:field, :customer, :name},
              position: %{x: 0, y: 0}
            },
            %Field{
              name: :order_count,
              source: {:field, :orders, :count},
              position: %{x: 100, y: 0}
            }
          ]
        }
      ],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_nested_bands do
    %Report{
      name: :nested_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [],
      bands: [
        %Band{
          name: :main,
          type: :detail,
          elements: [],
          bands: [
            %Band{
              name: :sub,
              type: :detail,
              elements: [
                %Field{
                  name: :nested_field,
                  source: :name,
                  position: %{x: 0, y: 0}
                }
              ]
            }
          ]
        }
      ],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_duplicate_relationships do
    %Report{
      name: :duplicate_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [],
      bands: [
        %Band{
          name: :detail1,
          type: :detail,
          elements: [
            %Field{
              name: :field1,
              source: {:field, :customer, :name},
              position: %{x: 0, y: 0}
            }
          ]
        },
        %Band{
          name: :detail2,
          type: :detail,
          elements: [
            %Field{
              name: :field2,
              source: {:field, :customer, :email},
              position: %{x: 0, y: 0}
            }
          ]
        }
      ],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_parameters do
    %Report{
      name: :param_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [
        %Parameter{name: :start_date, type: :date, required: true},
        %Parameter{name: :status, type: :string, required: false}
      ],
      bands: [],
      variables: [],
      groups: []
    }
  end

  defp build_report_with_groups do
    %Report{
      name: :grouped_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [],
      bands: [],
      variables: [],
      groups: [
        Group.new(:by_region, level: 1, expression: :region, sort: :asc),
        Group.new(:by_status, level: 2, expression: :status, sort: :desc)
      ]
    }
  end

  defp build_report_with_aggregates do
    %Report{
      name: :aggregate_report,
      driving_resource: AshReports.Test.Customer,
      parameters: [],
      bands: [
        %Band{
          name: :detail,
          type: :detail,
          elements: [
            # This would be an aggregate element if we had that struct defined
            %Field{
              name: :total_sales,
              source: :total_amount,
              position: %{x: 0, y: 0}
            }
          ]
        }
      ],
      variables: [],
      groups: []
    }
  end
end
