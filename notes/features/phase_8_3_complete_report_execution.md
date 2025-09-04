# Phase 8.3: Complete Report Execution Engine - Implementation Plan

**Implementation Date**: January 2025  
**Feature**: Complete Report Execution Engine  
**Status**: 🔄 **IN PROGRESS**  
**Branch**: `feature/phase-8.3-complete-report-execution`

## Overview

Phase 8.3 implements the complete report execution engine that connects all existing components (QueryBuilder, DataLoader, VariableState, GroupProcessor) with all four renderers (HTML, PDF, HEEX, JSON) to provide a fully functional end-to-end reporting system.

## Goals

1. **Complete Runner Implementation**: Make `AshReports.Runner.run_report` work with real data processing
2. **DataLoader Integration**: Connect Runner to DataLoader for actual data fetching
3. **Variable Integration**: Integrate variable calculation with band processing
4. **Renderer Integration**: Connect processed data to all 4 renderers
5. **End-to-End Testing**: Comprehensive test suite validating complete workflows

## Current State Analysis

### Existing Components ✅
- **QueryBuilder**: Phase 8.1 - Works with real report definitions
- **DataLoader**: Phase 8.1 - Fetches real data from ETS and processes variables/groups
- **VariableState**: Phase 8.1 - Calculates real values from record data
- **GroupProcessor**: Phase 8.1 - Handles real field-based grouping
- **DataGenerator**: Phase 8.2 - Creates realistic test data
- **4 Renderers**: Original implementation - HTML, PDF, HEEX, JSON renderers exist

### Missing Integration 🔥
- **Runner.run_report**: Currently returns placeholder data instead of using DataLoader
- **RenderContext**: Needs enhancement to work with real processed data
- **Band Processing**: Variables need to be integrated with band rendering
- **Error Handling**: End-to-end error handling throughout the pipeline
- **Performance**: Streaming and performance optimization for large datasets

## Implementation Plan

### 8.3.1: Enhanced Runner Implementation

#### Current Runner Issues
```elixir
# lib/ash_reports/runner.ex - Current problematic implementation
def run_report(domain, report_name, params \\ %{}, opts \\ []) do
  # TODO: This currently returns mock data instead of real processing
  {:ok, %{content: "Mock report", metadata: %{format: format}}}
end
```

#### Target Implementation
```elixir
# lib/ash_reports/runner.ex - Target implementation
defmodule AshReports.Runner do
  alias AshReports.{DataLoader, RenderContext, Renderer}

  @doc """
  Runs a complete report with real data processing and rendering.
  
  ## Parameters
  - domain: The Ash domain containing the report definition
  - report_name: The name of the report to run (atom)
  - params: Parameters to pass to the report (map)
  - opts: Options including :format, :streaming, :performance (keyword list)
  
  ## Returns
  {:ok, %{content: binary(), metadata: map(), format: atom()}} | {:error, reason}
  """
  def run_report(domain, report_name, params \\ %{}, opts \\ []) do
    format = Keyword.get(opts, :format, :html)
    
    with {:ok, data_result} <- DataLoader.load_report(domain, report_name, params),
         {:ok, render_context} <- build_render_context(data_result, opts),
         {:ok, rendered_result} <- render_report(render_context, format, opts) do
      {:ok, %{
        content: rendered_result.content,
        metadata: merge_metadata(data_result.metadata, rendered_result.metadata),
        format: format
      }}
    else
      {:error, reason} -> {:error, "Report execution failed: #{reason}"}
    end
  end
  
  defp build_render_context(data_result, opts) do
    context = RenderContext.new(data_result.report, data_result, opts)
    {:ok, context}
  end

  defp render_report(context, format, opts) do
    renderer = get_renderer_for_format(format)
    
    case renderer do
      {:error, reason} -> {:error, reason}
      renderer_module -> renderer_module.render_with_context(context, opts)
    end
  end

  defp get_renderer_for_format(:html), do: AshReports.HtmlRenderer
  defp get_renderer_for_format(:pdf), do: AshReports.PdfRenderer  
  defp get_renderer_for_format(:heex), do: AshReports.HeexRenderer
  defp get_renderer_for_format(:json), do: AshReports.JsonRenderer
  defp get_renderer_for_format(format), do: {:error, "Unknown format: #{format}"}
  
  defp merge_metadata(data_metadata, render_metadata) do
    Map.merge(data_metadata, render_metadata)
    |> Map.put(:pipeline_completed_at, DateTime.utc_now())
  end
end
```

### 8.3.2: Enhanced RenderContext Integration

#### Current RenderContext Issues
The current RenderContext may not properly handle the rich data structure from DataLoader.

#### Target RenderContext Enhancement
```elixir
# lib/ash_reports/render_context.ex - Enhanced implementation
defmodule AshReports.RenderContext do
  defstruct [
    :report,
    :records,
    :variables,
    :groups,
    :metadata,
    :params,
    :format,
    :locale,
    :timezone,
    :options
  ]

  def new(report, data_result, opts \\ []) do
    %__MODULE__{
      report: report,
      records: data_result.records,
      variables: data_result.variables,
      groups: data_result.groups,
      metadata: data_result.metadata,
      params: Map.get(data_result, :params, %{}),
      format: Keyword.get(opts, :format, :html),
      locale: Keyword.get(opts, :locale, "en"),
      timezone: Keyword.get(opts, :timezone, "UTC"),
      options: opts
    }
  end
  
  def get_variable_value(context, variable_name) do
    Map.get(context.variables, variable_name)
  end
  
  def get_group_data(context, group_name) do
    Map.get(context.groups, group_name, [])
  end
  
  def get_records_for_band(context, band_type) do
    # Filter records based on band requirements
    case band_type do
      :detail -> context.records
      :group_header -> get_group_header_records(context)
      :group_footer -> get_group_footer_records(context)
      _ -> []
    end
  end
  
  defp get_group_header_records(context) do
    # Extract group break records for headers
    Enum.map(context.groups, fn {_group_name, group_data} ->
      Map.get(group_data, :header_record, %{})
    end)
  end
  
  defp get_group_footer_records(context) do
    # Extract group summary records for footers
    Enum.map(context.groups, fn {_group_name, group_data} ->
      Map.get(group_data, :summary_record, %{})
    end)
  end
end
```

### 8.3.3: Enhanced Renderer Integration

#### Target: All Renderers Accept RenderContext
Each renderer needs to be updated to work with the enhanced RenderContext:

```elixir
# Each renderer needs render_with_context/2 function
defmodule AshReports.HtmlRenderer do
  @behaviour AshReports.Renderer
  
  def render_with_context(%RenderContext{} = context, opts \\ []) do
    with {:ok, processed_bands} <- process_bands_with_variables(context),
         {:ok, html_content} <- render_bands_to_html(processed_bands, context),
         {:ok, final_html} <- apply_styling_and_assets(html_content, context) do
      {:ok, %{
        content: final_html,
        metadata: %{
          format: :html,
          band_count: length(processed_bands),
          record_count: length(context.records),
          rendered_at: DateTime.utc_now()
        }
      }}
    end
  end
  
  defp process_bands_with_variables(context) do
    # Process each band type with variable substitution
    bands = for band <- context.report.bands do
      process_band_with_context(band, context)
    end
    
    {:ok, bands}
  end
  
  defp process_band_with_context(band, context) do
    # Get records for this band type
    band_records = RenderContext.get_records_for_band(context, band.type)
    
    # Process elements with variable substitution
    processed_elements = for element <- band.elements do
      case element do
        %{type: :label, text: text} ->
          # Substitute variables in text
          substituted_text = substitute_variables(text, context)
          %{element | text: substituted_text}
          
        %{type: :field, field: field_name} ->
          # Add current field values
          field_values = extract_field_values(field_name, band_records)
          Map.put(element, :values, field_values)
          
        %{type: :variable, name: var_name} ->
          # Add current variable value
          var_value = RenderContext.get_variable_value(context, var_name)
          Map.put(element, :current_value, var_value)
          
        _ -> element
      end
    end
    
    %{band | elements: processed_elements, records: band_records}
  end
end
```

### 8.3.4: Comprehensive Error Handling

#### Target: Pipeline Error Handling
```elixir
# Enhanced error handling throughout pipeline
defmodule AshReports.Runner do
  defp handle_pipeline_error({:error, {stage, reason}}) do
    error_details = %{
      stage: stage,
      reason: reason,
      timestamp: DateTime.utc_now(),
      suggested_action: suggest_action_for_error(stage, reason)
    }
    
    {:error, error_details}
  end
  
  defp suggest_action_for_error(:query_building, reason) do
    "Check report definition and parameters. Ensure all required parameters are provided."
  end
  
  defp suggest_action_for_error(:data_loading, reason) do
    "Verify data exists and domain/resources are properly configured."
  end
  
  defp suggest_action_for_error(:rendering, reason) do
    "Check renderer configuration and template validity."
  end
  
  defp suggest_action_for_error(_, _) do
    "Review error details and check system configuration."
  end
end
```

### 8.3.5: Performance Optimization

#### Target: Streaming Support
```elixir
# Add streaming support for large reports
defmodule AshReports.Runner do
  def run_report_stream(domain, report_name, params \\ %{}, opts \\ []) do
    # For large datasets, return a stream instead of loading all data
    with {:ok, report} <- AshReports.Info.report(domain, report_name),
         {:ok, query_stream} <- build_streaming_query(report, params) do
      
      query_stream
      |> Stream.chunk_every(100)  # Process in batches
      |> Stream.map(&process_batch(&1, report, opts))
      |> Stream.map(&render_batch(&1, opts))
    end
  end
  
  defp build_streaming_query(report, params) do
    # Build query with streaming configuration
    query = AshReports.QueryBuilder.build(report, params)
    stream = Ash.stream(query, domain: report.domain)
    {:ok, stream}
  end
end
```

## Implementation Steps

### Step 1: Update Runner Core (Day 1)
- [ ] Implement `run_report/4` with real DataLoader integration
- [ ] Add `build_render_context/2` helper
- [ ] Implement `render_report/3` with proper renderer selection
- [ ] Add comprehensive error handling with stage tracking
- [ ] Add metadata merging and pipeline completion tracking

### Step 2: Enhance RenderContext (Day 1)
- [ ] Update RenderContext struct with all required fields
- [ ] Implement `new/3` constructor with data_result integration
- [ ] Add helper functions: `get_variable_value/2`, `get_group_data/2`
- [ ] Implement `get_records_for_band/2` for band-specific data
- [ ] Add group header/footer record extraction functions

### Step 3: Update All Renderers (Day 2)
- [ ] Add `render_with_context/2` to HtmlRenderer
- [ ] Add `render_with_context/2` to PdfRenderer  
- [ ] Add `render_with_context/2` to HeexRenderer
- [ ] Add `render_with_context/2` to JsonRenderer
- [ ] Implement variable substitution in all renderers
- [ ] Add band processing with variable integration

### Step 4: Variable-Band Integration (Day 2)
- [ ] Implement `process_bands_with_variables/1` in each renderer
- [ ] Add `substitute_variables/2` for text element processing
- [ ] Implement `extract_field_values/2` for field elements
- [ ] Add variable value injection for variable elements
- [ ] Handle group-level variable resets during rendering

### Step 5: Comprehensive Testing (Day 3)
- [ ] Create `runner_complete_test.exs` with full pipeline tests
- [ ] Test all 4 formats with real data from DataGenerator
- [ ] Test parameter filtering and variable calculations
- [ ] Test error handling for each pipeline stage
- [ ] Add performance benchmarking tests
- [ ] Test streaming functionality for large datasets

## Test Strategy

### Unit Tests
```elixir
# test/ash_reports/runner_complete_test.exs
defmodule AshReports.RunnerCompleteTest do
  use ExUnit.Case
  
  setup do
    AshReportsDemo.DataGenerator.reset_data()
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    :ok
  end

  test "runs customer summary report with real data in all formats" do
    formats = [:html, :pdf, :heex, :json]
    
    for format <- formats do
      {:ok, result} = AshReports.Runner.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: format
      )
      
      assert result.format == format
      assert result.content != nil
      assert result.metadata.record_count > 0
      assert result.metadata.pipeline_completed_at != nil
    end
  end
  
  test "integrates variables with band processing" do
    {:ok, result} = AshReports.Runner.run_report(
      AshReportsDemo.Domain,
      :financial_summary,
      %{},
      format: :json
    )
    
    {:ok, json_data} = Jason.decode(result.content)
    
    # Verify variables are included
    assert json_data["variables"]["total_revenue"] != nil
    assert json_data["variables"]["invoice_count"] != nil
    
    # Verify bands contain processed data
    bands = json_data["bands"]
    detail_band = Enum.find(bands, &(&1["type"] == "detail"))
    assert length(detail_band["records"]) > 0
  end
  
  test "handles parameters and filtering correctly" do
    # Test with region filter
    {:ok, filtered_result} = AshReports.Runner.run_report(
      AshReportsDemo.Domain,
      :customer_summary,
      %{region: "CA"},
      format: :json
    )
    
    # Test without filter
    {:ok, unfiltered_result} = AshReports.Runner.run_report(
      AshReportsDemo.Domain,
      :customer_summary,
      %{},
      format: :json
    )
    
    # Filtered should have <= records
    assert filtered_result.metadata.record_count <= unfiltered_result.metadata.record_count
  end
  
  test "provides detailed error handling" do
    {:error, error_details} = AshReports.Runner.run_report(
      AshReportsDemo.Domain,
      :nonexistent_report,
      %{},
      format: :html
    )
    
    assert is_map(error_details)
    assert error_details.stage != nil
    assert error_details.suggested_action != nil
  end
end
```

### Integration Tests
```elixir
# test/ash_reports/end_to_end_pipeline_test.exs
defmodule AshReports.EndToEndPipelineTest do
  use ExUnit.Case
  
  @moduledoc """
  Tests the complete pipeline: DSL → Query → Data → Variables → Groups → Rendering
  """
  
  test "complete pipeline with customer summary report" do
    # Setup data
    AshReportsDemo.DataGenerator.generate_sample_data(:medium)
    
    # Run complete pipeline
    {:ok, result} = AshReports.Runner.run_report(
      AshReportsDemo.Domain,
      :customer_summary,
      %{include_inactive: false},
      format: :html
    )
    
    # Verify complete pipeline worked
    assert result.content =~ "Customer Summary Report"
    assert result.metadata.record_count > 0
    assert result.metadata.pipeline_completed_at != nil
    
    # Verify variables were calculated
    assert result.content =~ "Total Customers:"
    assert result.content =~ "Total Lifetime Value:"
    
    # Verify grouping worked (if report has groups)
    # This would depend on the specific report definition
  end
  
  test "streaming support for large datasets" do
    # Generate large dataset
    AshReportsDemo.DataGenerator.generate_sample_data(:large)
    
    # Test streaming execution
    stream = AshReports.Runner.run_report_stream(
      AshReportsDemo.Domain,
      :customer_summary,
      %{},
      format: :json
    )
    
    # Verify stream works
    results = stream |> Enum.take(5)
    assert length(results) > 0
  end
end
```

## Success Criteria

### Functional Requirements
- [ ] `AshReports.Runner.run_report/4` executes complete pipeline with real data
- [ ] All 4 formats (HTML, PDF, HEEX, JSON) work with processed data
- [ ] Variables are calculated and integrated into rendered output
- [ ] Groups are processed and reflected in band structure
- [ ] Parameters correctly filter data throughout pipeline
- [ ] Error handling provides actionable feedback for each stage

### Performance Requirements  
- [ ] Small dataset reports: <500ms generation time
- [ ] Medium dataset reports: <2s generation time
- [ ] Large dataset reports: <10s generation time
- [ ] Memory usage remains stable during report generation
- [ ] Streaming support for datasets >1000 records

### Quality Requirements
- [ ] Zero compilation errors
- [ ] Zero Credo issues
- [ ] >95% test coverage for new functionality
- [ ] Integration tests validate end-to-end workflows
- [ ] Performance benchmarks meet requirements

## Dependencies

### Required Components (Already Implemented)
- ✅ QueryBuilder (Phase 8.1)
- ✅ DataLoader (Phase 8.1) 
- ✅ VariableState (Phase 8.1)
- ✅ GroupProcessor (Phase 8.1)
- ✅ DataGenerator (Phase 8.2)
- ✅ All 4 Renderers (Original implementation)

### Potential Risks
1. **Renderer Compatibility**: Existing renderers may need significant updates
2. **Performance**: Large dataset processing may require optimization
3. **Memory Usage**: Full data loading may cause memory issues
4. **Complex Variables**: Advanced variable calculations may be complex to integrate

### Mitigation Strategies
1. **Incremental Updates**: Update one renderer at a time
2. **Streaming Support**: Implement batched processing for large datasets
3. **Memory Management**: Add configuration for memory limits
4. **Comprehensive Testing**: Test with various data sizes and complexity

This implementation plan will complete the missing report execution engine and provide the fully functional end-to-end reporting system as specified in the Phase 8 planning document.