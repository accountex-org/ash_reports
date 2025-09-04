# Phase 8.1: Complete Data Integration System Implementation Plan

**Feature**: Connect existing QueryBuilder, DataLoader, VariableState, and GroupProcessor components to work with real data  
**Priority**: Critical - Required for functional demo  
**Estimated Time**: 3-4 days  

## Overview

Phase 8.1 transforms the existing placeholder data integration components into a fully functional system that can:
- Build real Ash queries from report definitions
- Fetch actual data from demo resources
- Calculate variables from real record values
- Process multi-level grouping with actual field data
- Connect the complete pipeline for end-to-end report execution

## Current State Analysis

### Existing Components (Placeholder/Incomplete):
- ✅ `AshReports.QueryBuilder` - exists but doesn't integrate with real reports
- ✅ `AshReports.DataLoader` - exists but returns mock data
- ✅ `AshReports.VariableState` - exists but not connected to real records
- ✅ `AshReports.GroupProcessor` - exists but not used in practice

### Missing Integration:
- ❌ QueryBuilder doesn't process actual report.scope functions
- ❌ DataLoader doesn't execute real Ash.read operations
- ❌ VariableState doesn't evaluate expressions against real record fields
- ❌ GroupProcessor doesn't handle actual relationship data
- ❌ No pipeline connecting these components

## Implementation Tasks

### Task 8.1.1: QueryBuilder Real Report Integration

**Goal**: Make QueryBuilder.build_query work with actual AshReports.Report structs

#### Subtasks:
- [ ] 8.1.1.1 Update build_query to accept AshReports.Report struct
- [ ] 8.1.1.2 Implement report.scope function execution
- [ ] 8.1.1.3 Add parameter substitution in scope functions
- [ ] 8.1.1.4 Add required relationship loading based on report bands/elements
- [ ] 8.1.1.5 Handle group ordering requirements

#### Implementation Details:
```elixir
# Enhanced lib/ash_reports/query_builder.ex
def build_query(%AshReports.Report{} = report, params \\ %{}) do
  base_query = Ash.Query.new(report.driving_resource)
  
  base_query
  |> apply_report_scope(report.scope, params)
  |> apply_parameter_filters(report.parameters, params)
  |> apply_required_loads(report)
  |> apply_group_sorting(report.groups)
end

defp apply_report_scope(query, nil, _params), do: query
defp apply_report_scope(query, scope_fn, params) when is_function(scope_fn, 1) do
  scope_fn.(params) |> case do
    %Ash.Query{} = scoped_query -> 
      Ash.Query.merge_query(query, scoped_query)
    _ -> 
      raise "Scope function must return Ash.Query"
  end
end

defp apply_required_loads(query, %AshReports.Report{bands: bands}) do
  required_loads = extract_relationship_paths(bands)
  Ash.Query.load(query, required_loads)
end
```

#### Unit Tests:
```elixir
# test/ash_reports/query_builder_real_integration_test.exs
test "builds query from customer summary report definition" do
  report = AshReports.Info.report(AshReportsDemo.Domain, :customer_summary)
  params = %{region: "CA"}
  
  query = AshReports.QueryBuilder.build_query(report, params)
  
  assert query.resource == AshReportsDemo.Customer
  assert query.load != nil  # Should load relationships needed by bands
end
```

### Task 8.1.2: DataLoader Real Data Fetching

**Goal**: Make DataLoader.load_report fetch and process actual data from Ash resources

#### Subtasks:
- [ ] 8.1.2.1 Implement load_report with real Ash.read operations
- [ ] 8.1.2.2 Connect to QueryBuilder for query generation
- [ ] 8.1.2.3 Add error handling for query execution failures
- [ ] 8.1.2.4 Process returned data for band/variable consumption

#### Implementation Details:
```elixir
# Enhanced lib/ash_reports/data_loader.ex
def load_report(domain, report_name, params \\ %{}) do
  with {:ok, report} <- get_report(domain, report_name),
       {:ok, query} <- AshReports.QueryBuilder.build_query(report, params),
       {:ok, records} <- execute_query(domain, query),
       {:ok, processed_data} <- process_for_reporting(report, records) do
    {:ok, %{
      report: report,
      records: processed_data.records,
      raw_records: records,  # Keep original for debugging
      metadata: %{
        record_count: length(records),
        query_time_ms: processed_data.query_time,
        processed_at: DateTime.utc_now()
      }
    }}
  end
end

defp execute_query(domain, query) do
  start_time = System.monotonic_time(:millisecond)
  
  case Ash.read(query, domain: domain) do
    {:ok, records} ->
      end_time = System.monotonic_time(:millisecond)
      {:ok, records, end_time - start_time}
    {:error, error} ->
      {:error, "Data loading failed: #{inspect(error)}"}
  end
end
```

### Task 8.1.3: VariableState Real Calculation Integration

**Goal**: Make VariableState calculate from actual record field values

#### Subtasks:
- [ ] 8.1.3.1 Implement expression evaluation against real records
- [ ] 8.1.3.2 Add field path resolution (e.g., customer.addresses.state)
- [ ] 8.1.3.3 Handle calculation errors gracefully
- [ ] 8.1.3.4 Integrate with group-level resets

#### Implementation Details:
```elixir
# Enhanced lib/ash_reports/variable_state.ex
def update_from_record(state, variable_name, record) do
  variable = get_variable(state, variable_name)
  
  case evaluate_expression(variable.expression, record) do
    {:ok, value} ->
      new_value = AshReports.Variable.calculate_next_value(
        variable, 
        get_current_value(state, variable_name), 
        value
      )
      put_value(state, variable_name, new_value)
    
    {:error, _reason} ->
      # Log error but continue processing
      state
  end
end

defp evaluate_expression(expr, record) do
  # Implement Ash expression evaluation against record
  case expr do
    atom when is_atom(atom) ->
      {:ok, Map.get(record, atom)}
    {:field, path} when is_list(path) ->
      {:ok, get_in(record, path)}
    _ ->
      # Use Ash.Expr.eval when available
      {:error, "Complex expression evaluation not implemented"}
  end
end
```

### Task 8.1.4: GroupProcessor Real Data Integration

**Goal**: Make GroupProcessor work with actual field values from loaded records

#### Subtasks:
- [ ] 8.1.4.1 Implement group value extraction from real records
- [ ] 8.1.4.2 Add group break detection with actual field changes
- [ ] 8.1.4.3 Handle relationship-based grouping (e.g., customer.region)
- [ ] 8.1.4.4 Integrate with variable reset functionality

### Task 8.1.5: Integration Pipeline

**Goal**: Connect all components in a working data processing pipeline

#### Subtasks:
- [ ] 8.1.5.1 Create unified data processing workflow
- [ ] 8.1.5.2 Add comprehensive error handling throughout pipeline
- [ ] 8.1.5.3 Implement performance monitoring
- [ ] 8.1.5.4 Add debug logging for troubleshooting

#### Implementation Details:
```elixir
# lib/ash_reports/data_integration_pipeline.ex (new)
defmodule AshReports.DataIntegrationPipeline do
  alias AshReports.{QueryBuilder, DataLoader, VariableState, GroupProcessor}

  def execute(domain, report_name, params) do
    with {:ok, report} <- AshReports.Info.report(domain, report_name),
         {:ok, query} <- QueryBuilder.build_query(report, params),
         {:ok, records} <- DataLoader.execute_query(domain, query),
         {:ok, processed_result} <- process_records(report, records) do
      {:ok, %{
        report: report,
        records: records,
        variables: processed_result.variables,
        groups: processed_result.groups,
        metadata: processed_result.metadata
      }}
    end
  end

  defp process_records(report, records) do
    # Initialize processing state
    variable_state = VariableState.new(report.variables)
    group_processor = GroupProcessor.new(report.groups)
    
    # Process each record
    final_state = Enum.reduce(records, 
      %{variables: variable_state, groups: %{}, current_group: nil},
      &process_single_record(report, &1, &2, group_processor)
    )
    
    {:ok, %{
      variables: VariableState.get_all_values(final_state.variables),
      groups: final_state.groups,
      metadata: %{
        record_count: length(records),
        processed_at: DateTime.utc_now()
      }
    }}
  end
end
```

## Testing Strategy

### Unit Tests (Each Component):
1. **QueryBuilder Tests**: Verify query generation from real report definitions
2. **DataLoader Tests**: Test actual data fetching from demo resources
3. **VariableState Tests**: Validate calculations with real record values
4. **GroupProcessor Tests**: Test grouping with actual field data

### Integration Tests (Complete Pipeline):
1. **Pipeline Tests**: End-to-end data flow validation
2. **Report Tests**: Each demo report works with real data
3. **Performance Tests**: Realistic data volume processing
4. **Error Handling Tests**: Graceful failure scenarios

## Success Criteria

- [ ] All 4 demo reports can fetch real data from ETS resources
- [ ] Variables calculate actual totals from record field values  
- [ ] Grouping works with real customer.region, invoice.status, etc.
- [ ] Parameters correctly filter returned data
- [ ] Pipeline handles errors gracefully
- [ ] Performance meets requirements (<2s for medium datasets)
- [ ] Zero compilation errors or warnings
- [ ] All Credo issues resolved
- [ ] Comprehensive test coverage (>95%)

## Implementation Order

1. **QueryBuilder Enhancement**: Core query building from reports
2. **DataLoader Real Execution**: Actual Ash.read operations
3. **VariableState Integration**: Real field value calculations
4. **GroupProcessor Integration**: Actual grouping with field data
5. **Pipeline Integration**: Connect all components
6. **Comprehensive Testing**: Validate complete functionality
7. **Code Quality**: Fix Credo and compilation issues

This will establish the foundation for the complete functional demo system.