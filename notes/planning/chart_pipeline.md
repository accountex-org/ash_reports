# Chart Pipeline Integration - Implementation Plan

**Project**: AshReports
**Feature**: Chart Pipeline Integration
**Timeline**: 8 Weeks (4 Phases)
**Status**: Planning

## Overview

This document outlines the implementation plan for integrating charts into the AshReports pipeline architecture. Currently, charts use imperative `data_source(fn -> ... end)` callbacks that bypass the DataLoader, QueryBuilder, and pipeline infrastructure, forcing users to manually handle N+1 problems. This integration will unify charts and reports under a single declarative architecture.

## Objectives

1. Enable declarative chart definitions using `driving_resource` and `transform` DSL
2. Eliminate N+1 query problems through automatic relationship optimization
3. Provide backwards compatibility with existing imperative charts
4. Achieve 60%+ code reduction in chart definitions
5. Enable streaming support for large datasets
6. Maintain <10ms pipeline overhead for simple charts

## Prerequisites

- Existing `AshReports.DataLoader` module
- Existing `AshReports.QueryBuilder` module
- Existing `AshReports.Charts.DataSourceHelpers` module
- Current chart generation infrastructure (`AshReports.Charts.generate/4`)

---

# Phase 1: Foundation (Weeks 1-2)

**Goal**: Enable basic declarative charts through pipeline with backwards compatibility

## 1.1 Chart DataLoader Module

- [ ] **Create AshReports.Charts.DataLoader module**

### 1.1.1 Core Module Setup

- [ ] **Task 1.1.1.1: Create module structure**
  - Create `lib/ash_reports/charts/data_loader.ex`
  - Define public API: `load_chart_data/3` accepting (domain, chart, params)
  - Define public API: `load_chart_data/4` with options for streaming, batch_size
  - Document module with examples and usage patterns

- [ ] **Task 1.1.1.2: Chart definition parsing**
  - Detect declarative vs imperative chart definitions
  - Extract `driving_resource` from chart struct
  - Extract `scope` function if present
  - Validate chart has either `driving_resource` or `data_source` function

- [ ] **Task 1.1.1.3: Error handling**
  - Return `{:error, :missing_data_source}` for invalid definitions
  - Return `{:error, {:invalid_driving_resource, reason}}` for bad resources
  - Provide clear error messages for user debugging

### 1.1.2 QueryBuilder Integration

- [ ] **Task 1.1.2.1: Leverage existing QueryBuilder**
  - Import and call `AshReports.QueryBuilder.build_query/3`
  - Pass chart's driving_resource as the base resource
  - Apply scope function if provided by chart
  - Handle query building errors gracefully

- [ ] **Task 1.1.2.2: Scope function integration**
  - Execute chart's `scope` function with parameters
  - Merge scope filters with base query
  - Validate scope returns valid `Ash.Query.t()`
  - Support scope functions that accept empty params

### 1.1.3 Query Execution

- [ ] **Task 1.1.3.1: Execute optimized queries**
  - Use `AshReports.DataLoader.Executor` for query execution
  - Pass domain from chart context
  - Handle streaming vs non-streaming execution
  - Return records with metadata (count, execution_time)

- [ ] **Task 1.1.3.2: Relationship detection**
  - Analyze transform block for relationship references
  - Extract relationships like `expr(product.category.name)`
  - Build list of relationships to preload
  - Pass relationships to QueryBuilder for optimization

### 1.1.4 Unit Tests

- [ ] Test: `load_chart_data/3` returns `{:ok, {records, metadata}}`
- [ ] Test: Driving resource queries execute correctly
- [ ] Test: Scope functions are applied to queries
- [ ] Test: Invalid chart definitions return clear errors
- [ ] Test: Relationship detection finds nested fields
- [ ] Test: Metadata includes source_records count

## 1.2 Transform DSL Implementation

- [ ] **Create Transform DSL for data aggregation**

### 1.2.1 DSL Module Structure

- [ ] **Task 1.2.1.1: Create transform module**
  - Create `lib/ash_reports/charts/transform.ex`
  - Define struct: `%Transform{group_by: [], aggregates: [], mappings: [], filters: []}`
  - Create parser: `parse/1` to convert DSL block to struct
  - Create executor: `execute/2` to apply transform to records

- [ ] **Task 1.2.1.2: Spark DSL integration**
  - Add `transform` section to chart entity schemas
  - Define `group_by/1` macro accepting field or expression
  - Define `aggregate/2` and `aggregate/3` macros
  - Define mapping macros: `as_category/1`, `as_value/1`, `as_x/1`, `as_y/1`

### 1.2.2 Core Transform Operations

- [ ] **Task 1.2.2.1: Implement group_by**
  - Support field atoms (`:status`)
  - Support Ash expressions (`expr(product.category.name)`)
  - Use `Enum.group_by/2` for in-memory grouping
  - Handle nil values in grouping field

- [ ] **Task 1.2.2.2: Implement aggregations**
  - Support `:count` aggregation (count records in group)
  - Support `:sum` aggregation with field parameter
  - Support `:avg` aggregation with field parameter
  - Support `:min` and `:max` aggregations with field
  - Return aggregated values in group results

### 1.2.3 Data Mapping

- [ ] **Task 1.2.3.1: Implement chart format mapping**
  - Map grouped data to chart-specific formats
  - Support `as_category` for pie/bar charts (`:category` field)
  - Support `as_value` for pie/bar charts (`:value` field)
  - Support `as_x` and `as_y` for line/scatter charts
  - Handle missing or nil mapped values

### 1.2.4 Transform Execution Pipeline

- [ ] **Task 1.2.4.1: Create execution engine**
  - Process records through transform steps in order
  - Apply group_by first to create groups
  - Apply aggregations to each group
  - Apply mappings to format for chart type
  - Return `{:ok, chart_data}` or `{:error, reason}`

- [ ] **Task 1.2.4.2: Relationship value resolution**
  - Resolve nested field access (e.g., `product.category.name`)
  - Handle `%Ash.NotLoaded{}` relationships gracefully
  - Use `Map.get/2` and `Access` for field traversal
  - Return nil for unloaded or missing relationships

### 1.2.5 Unit Tests

- [ ] Test: `group_by` with simple field works
- [ ] Test: `group_by` with Ash expression works
- [ ] Test: `:count` aggregation returns correct counts
- [ ] Test: `:sum` aggregation totals values correctly
- [ ] Test: `as_category` and `as_value` map data correctly
- [ ] Test: Nested relationship access resolves properly
- [ ] Test: Missing relationships handled gracefully
- [ ] Test: Transform execution returns valid chart data format

## 1.3 Pipeline Integration

- [ ] **Integrate charts into existing pipeline**

### 1.3.1 Chart Runner Updates

- [ ] **Task 1.3.1.1: Update chart execution logic**
  - Modify chart viewer or runner to detect declarative charts
  - Call `AshReports.Charts.DataLoader.load_chart_data/3` for declarative
  - Call legacy `data_source.()` for imperative charts
  - Preserve metadata from data loading stage

- [ ] **Task 1.3.1.2: Transform integration**
  - After data loading, check for transform block
  - Call `AshReports.Charts.Transform.execute/2` with records
  - Pass transformed data to `AshReports.Charts.generate/4`
  - Merge metadata from loading and transform stages

### 1.3.2 Chart Definition Detection

- [ ] **Task 1.3.2.1: Implement detection logic**
  - Check if chart struct has `driving_resource` field
  - If present → declarative, use pipeline
  - If absent and `data_source` is function → imperative, use legacy
  - Return error if neither is present

- [ ] **Task 1.3.2.2: Add configuration**
  - Add application config: `config :ash_reports, :chart_mode, :declarative`
  - Support `:auto` mode (detect based on chart definition)
  - Support `:legacy` mode (force imperative for testing)
  - Document configuration options

### 1.3.3 Telemetry Integration

- [ ] **Task 1.3.3.1: Add pipeline telemetry events**
  - Emit `[:ash_reports, :charts, :data_loading, :start]`
  - Emit `[:ash_reports, :charts, :data_loading, :stop]` with duration
  - Emit `[:ash_reports, :charts, :transform, :start]`
  - Emit `[:ash_reports, :charts, :transform, :stop]` with record_count
  - Include metadata: chart_name, chart_type, mode (:declarative/:imperative)

### 1.3.4 Unit Tests

- [ ] Test: Declarative charts use DataLoader
- [ ] Test: Imperative charts use legacy data_source
- [ ] Test: Transform is applied after data loading
- [ ] Test: Telemetry events are emitted correctly
- [ ] Test: Metadata flows through pipeline stages
- [ ] Test: Configuration modes work as expected

## 1.4 Backwards Compatibility Layer

- [ ] **Ensure seamless backwards compatibility**

### 1.4.1 Legacy Chart Support

- [ ] **Task 1.4.1.1: Preserve imperative data_source**
  - Keep existing `data_source(fn -> ... end)` working
  - No breaking changes to imperative charts
  - Continue to support `{:ok, data, metadata}` return format
  - Support plain `data` or `{:ok, data}` return formats

- [ ] **Task 1.4.1.2: Add deprecation warnings**
  - Log warning when imperative chart is executed
  - Warning message: "Imperative data_source is deprecated, consider using declarative style with driving_resource"
  - Include link to migration guide in warning
  - Only log warning once per chart per application boot

### 1.4.2 Migration Path Documentation

- [ ] **Task 1.4.2.1: Create migration guide**
  - Document imperative vs declarative patterns
  - Provide side-by-side examples for each chart type
  - Explain benefits of declarative approach
  - Show common imperative → declarative conversions

- [ ] **Task 1.4.2.2: Update chart documentation**
  - Mark imperative style as deprecated in guides
  - Show declarative as primary approach in examples
  - Update graphs-and-visualizations.md guide
  - Add "Migrating from Imperative Charts" section

### 1.4.3 Compatibility Testing

- [ ] **Task 1.4.3.1: Test existing demo charts**
  - Verify all 8 demo charts continue to work
  - Run full chart suite with imperative definitions
  - Ensure no breaking changes to outputs
  - Verify metadata is preserved

### 1.4.4 Unit Tests

- [ ] Test: Imperative charts execute without errors
- [ ] Test: Deprecation warning is logged exactly once
- [ ] Test: Both imperative and declarative charts work in same app
- [ ] Test: Chart output matches between modes for same data
- [ ] Test: Metadata format is consistent across modes

## 1.5 Phase 1 Integration Tests

- [ ] **End-to-end validation of Phase 1**

### 1.5.1 Simple Declarative Chart Test

- [ ] Test: Pie chart with `driving_resource` and `group_by` executes successfully
- [ ] Test: Bar chart with count aggregation produces correct output
- [ ] Test: Chart data format matches expectations for Contex rendering

### 1.5.2 Backwards Compatibility Test

- [ ] Test: All 8 demo charts work without modification
- [ ] Test: New declarative chart and old imperative chart in same domain
- [ ] Test: Migration guide examples work as documented

### 1.5.3 Performance Test

- [ ] Test: Declarative chart with 325K records completes in <5s
- [ ] Test: Pipeline overhead for simple chart <50ms
- [ ] Test: Memory usage comparable to imperative style

---

# Phase 2: Advanced Transformations (Weeks 3-4)

**Goal**: Support complex aggregations and automatic relationship optimization

## 2.1 Relationship Loading Optimization

- [ ] **Implement automatic relationship optimization**

### 2.1.1 Relationship Detection

- [ ] **Task 2.1.1.1: Parse transform for relationships**
  - Scan `group_by` expressions for relationship access
  - Scan `aggregate` field parameters for relationships
  - Scan mapping expressions for relationships
  - Build comprehensive list of required relationships

- [ ] **Task 2.1.1.2: Integration with QueryBuilder**
  - Pass relationship list to `QueryBuilder.extract_relationships/1`
  - Leverage existing relationship detection logic
  - Get optimized relationship loading plan from QueryBuilder
  - Apply relationship loading to query before execution

### 2.1.2 Batch Loading Implementation

- [ ] **Task 2.1.2.1: Use DataSourceHelpers patterns**
  - Load records without relationships first
  - Extract unique foreign key IDs from records
  - Load related records in single batch query
  - Build lookup maps for O(1) joining

- [ ] **Task 2.1.2.2: Automatic join execution**
  - Join records with relationships in memory
  - Use lookup maps during transform execution
  - Handle missing relationships gracefully
  - Preserve all metadata through joining

### 2.1.3 Explicit Relationship Declaration

- [ ] **Task 2.1.3.1: Add load_relationships DSL**
  - Add `load_relationships` option to chart DSL
  - Accept list of atoms: `[:product]`
  - Accept nested relationships: `[product: :category]`
  - Override automatic detection when present

- [ ] **Task 2.1.3.2: Relationship validation**
  - Verify relationships exist on driving resource
  - Return clear error for invalid relationship names
  - Warn if declared relationship is not used in transform
  - Document relationship declaration in guides

### 2.1.4 Unit Tests

- [ ] Test: Relationships detected from `group_by expr(product.name)`
- [ ] Test: Nested relationships detected: `expr(product.category.name)`
- [ ] Test: Batch loading reduces queries (1 + N → 3 queries)
- [ ] Test: `load_relationships` declaration works
- [ ] Test: Invalid relationship names return errors
- [ ] Test: Optimization works for 325K records in <1s

## 2.2 Complex Aggregations

- [ ] **Extend transform DSL for advanced aggregations**

### 2.2.1 Additional Aggregate Types

- [ ] **Task 2.2.1.1: Implement avg aggregation**
  - Calculate average of numeric field values
  - Handle `Decimal` types correctly
  - Return float for chart rendering
  - Handle division by zero gracefully

- [ ] **Task 2.2.1.2: Implement min/max aggregations**
  - Find minimum value in group
  - Find maximum value in group
  - Support Date, DateTime, and numeric types
  - Convert to appropriate format for charts

### 2.2.2 Multi-Field Aggregations

- [ ] **Task 2.2.2.1: Support multiple aggregates**
  - Allow multiple `aggregate` declarations in transform
  - Store results with `:as` names
  - Example: `aggregate :sum, field: :quantity, as: :total_qty`
  - Example: `aggregate :sum, field: :line_total, as: :revenue`

- [ ] **Task 2.2.2.2: Reference aggregates in mappings**
  - Use aggregate names in `as_value`
  - Choose which aggregate to use for chart
  - Support calculations between aggregates
  - Example: `as_value expr(revenue / total_qty)` for average price

### 2.2.3 Custom Expressions

- [ ] **Task 2.2.3.1: Support Ash expressions in aggregates**
  - Accept `expr(...)` in aggregate field parameter
  - Evaluate expressions during aggregation
  - Support field calculations: `expr(quantity * price)`
  - Support conditional expressions

- [ ] **Task 2.2.3.2: Expression evaluation**
  - Use `AshReports.DataLoader.CalculationEngine` for evaluation
  - Support standard Ash expression operators
  - Handle evaluation errors gracefully
  - Return nil for failed expressions

### 2.2.4 Unit Tests

- [ ] Test: `:avg` aggregation calculates correctly
- [ ] Test: `:min` and `:max` find correct values
- [ ] Test: Multiple aggregates in single transform
- [ ] Test: Aggregate results used in mappings
- [ ] Test: Ash expressions in aggregate field
- [ ] Test: Complex calculations between aggregates

## 2.3 Chart-Specific Features

- [ ] **Add chart rendering enhancements**

### 2.3.1 Post-Aggregation Operations

- [ ] **Task 2.3.1.1: Implement sort_by**
  - Add `sort_by` to transform DSL
  - Support ascending/descending: `sort_by :value, :desc`
  - Apply after aggregations and mappings
  - Support sorting by multiple fields

- [ ] **Task 2.3.1.2: Implement limit**
  - Add `limit` to transform DSL
  - Limit results after sorting: `limit 10`
  - Useful for "Top N" charts
  - Document use case: "Top 10 Products"

- [ ] **Task 2.3.1.3: Implement filter**
  - Add `filter` to transform DSL
  - Filter groups after aggregation
  - Example: `filter expr(count > 0)`
  - Support comparison operators

### 2.3.2 Data Formatting

- [ ] **Task 2.3.2.1: Type conversions**
  - Convert `Decimal` to float automatically
  - Format Date/DateTime for chart labels
  - Truncate long strings for labels
  - Handle nil values in data

- [ ] **Task 2.3.2.2: Label formatting**
  - Add `format_label` option to mappings
  - Support custom formatting functions
  - Provide common formatters: currency, percentage, date
  - Apply formatting during mapping stage

### 2.3.3 Multi-Series Support

- [ ] **Task 2.3.3.1: Design series_by DSL**
  - Add `series_by` to transform for line/area charts
  - Group data by series dimension
  - Generate multiple data series for chart
  - Map series to chart colors

- [ ] **Task 2.3.3.2: Series data structure**
  - Define series format for Contex
  - Support multiple Y values per X
  - Handle missing data points
  - Document series requirements per chart type

### 2.3.4 Unit Tests

- [ ] Test: `sort_by :value, :desc` orders correctly
- [ ] Test: `limit 10` returns only 10 results
- [ ] Test: `filter` removes unwanted groups
- [ ] Test: Decimal values converted to float
- [ ] Test: Long strings truncated for labels
- [ ] Test: `series_by` creates multiple series

## 2.4 Phase 2 Integration Tests

- [ ] **End-to-end validation of Phase 2**

### 2.4.1 Complex Chart Tests

- [ ] Test: Bar chart with relationship traversal (product → category)
- [ ] Test: Scatter chart with two aggregates (price, quantity)
- [ ] Test: Line chart with multiple series by region
- [ ] Test: Top 10 chart with sort_by and limit

### 2.4.2 Relationship Optimization Tests

- [ ] Test: 325K records with N+1 relationships optimized (<1s)
- [ ] Test: Query count: 3 queries for relationship loading
- [ ] Test: Memory usage remains constant with optimization
- [ ] Test: Same results as imperative with manual optimization

### 2.4.3 Aggregate Accuracy Tests

- [ ] Test: Sum aggregation matches SQL aggregate
- [ ] Test: Average aggregation handles decimals correctly
- [ ] Test: Min/max find correct extreme values
- [ ] Test: Multiple aggregates return independent results

---

# Phase 3: Parameters & Variables (Weeks 5-6)

**Goal**: Add report-like features (parameters, variables, streaming)

## 3.1 Parameter Support

- [ ] **Enable chart parameterization**

### 3.1.1 Parameter DSL

- [ ] **Task 3.1.1.1: Add parameter declaration**
  - Add `parameter` macro to chart DSL
  - Match report parameter syntax exactly
  - Support types: `:string`, `:atom`, `:integer`, `:decimal`, `:boolean`
  - Support constraints: `:one_of`, `:min`, `:max`

- [ ] **Task 3.1.1.2: Parameter validation**
  - Validate parameter types before execution
  - Validate constraints (one_of, ranges)
  - Return clear validation errors
  - Support default values

### 3.1.2 Scope Integration

- [ ] **Task 3.1.2.1: Pass parameters to scope**
  - Make parameters available in scope function
  - Example: `scope fn params -> filter(query, region == ^params[:region]) end`
  - Handle missing optional parameters
  - Validate required parameters present

- [ ] **Task 3.1.2.2: Dynamic filtering**
  - Build conditional filters based on parameters
  - Use `then/2` for conditional query modification
  - Support multiple parameter-based filters
  - Document parameter patterns

### 3.1.3 Parameter Examples

- [ ] **Task 3.1.3.1: Update demo charts**
  - Add parameters to 2-3 demo charts
  - Show filtering use case
  - Show value-based filtering (min_value parameter)
  - Show region/category selection parameters

### 3.1.4 Unit Tests

- [ ] Test: Parameter declaration parsed correctly
- [ ] Test: Type validation rejects invalid types
- [ ] Test: Constraints enforced (one_of, min, max)
- [ ] Test: Default values applied when parameter missing
- [ ] Test: Parameters accessible in scope function
- [ ] Test: Invalid parameters return clear errors

## 3.2 Variable Integration

- [ ] **Add variable support to charts**

### 3.2.1 Variable Declaration

- [ ] **Task 3.2.1.1: Add variable DSL to charts**
  - Add `variable` macro matching report syntax
  - Support types: `:count`, `:sum`, `:avg`, `:min`, `:max`
  - Support expressions: `expression expr(1)` for count
  - Support reset_on: `:report`, `:group`

- [ ] **Task 3.2.1.2: Variable calculation**
  - Integrate with `AshReports.DataLoader.VariableState`
  - Calculate variables during data loading
  - Store variable values in metadata
  - Support variable references in chart config

### 3.2.2 Variable Interpolation

- [ ] **Task 3.2.2.1: Title/label interpolation**
  - Support `[variable_name]` syntax in chart titles
  - Replace with calculated values during rendering
  - Example: `title "Customer Distribution - [total_customers] Total"`
  - Document interpolation syntax

- [ ] **Task 3.2.2.2: Metadata variables**
  - Include variables in chart metadata
  - Return in `{:ok, svg, metadata}` format
  - Display variable values in chart viewer UI
  - Format variables appropriately (numbers, currency)

### 3.2.3 Variable Use Cases

- [ ] **Task 3.2.3.1: Demonstrate variable benefits**
  - Show total count in title
  - Show aggregate values (sum, average) in subtitle
  - Use variables for dynamic chart annotations
  - Document common variable patterns

### 3.2.4 Unit Tests

- [ ] Test: Variable declaration parsed correctly
- [ ] Test: Variables calculated during data loading
- [ ] Test: `[variable_name]` replaced in titles
- [ ] Test: Variables included in metadata
- [ ] Test: Multiple variables supported in single chart
- [ ] Test: Variable reset_on :group vs :report

## 3.3 Streaming Support

- [ ] **Enable streaming for large datasets**

### 3.3.1 Streaming Infrastructure

- [ ] **Task 3.3.1.1: Add streaming option**
  - Accept `streaming: true` option in chart execution
  - Accept `chunk_size` option (default: 500)
  - Use `AshReports.DataLoader` streaming support
  - Return stream of aggregated results

- [ ] **Task 3.3.1.2: Streaming aggregation**
  - Aggregate data in chunks
  - Maintain running totals for aggregates
  - Merge chunk results progressively
  - Emit partial results for UI updates

### 3.3.2 Transform Streaming

- [ ] **Task 3.3.2.1: Streaming-compatible transforms**
  - Identify transforms that work with streaming
  - Group-by and aggregations support streaming
  - Sort/limit require full dataset (buffer)
  - Document streaming limitations

- [ ] **Task 3.3.2.2: Memory management**
  - Use Stream module for lazy evaluation
  - Process chunks without loading all records
  - Clean up processed chunks
  - Monitor memory usage in tests

### 3.3.3 Streaming UI Integration

- [ ] **Task 3.3.3.1: Progressive rendering**
  - Show loading indicator during streaming
  - Update chart as chunks arrive
  - Display "Processing X of Y records..."
  - Show final chart when complete

- [ ] **Task 3.3.3.2: Error handling**
  - Handle stream errors gracefully
  - Show partial results if stream fails
  - Allow retry of failed chunks
  - Document error recovery patterns

### 3.3.4 Unit Tests

- [ ] Test: Streaming option enables chunked loading
- [ ] Test: Large dataset (1M records) streams successfully
- [ ] Test: Memory usage stays constant during streaming
- [ ] Test: Aggregation results match non-streaming mode
- [ ] Test: Stream errors handled gracefully
- [ ] Test: Streaming incompatible with sort_by + limit

## 3.4 Phase 3 Integration Tests

- [ ] **End-to-end validation of Phase 3**

### 3.4.1 Parameter Tests

- [ ] Test: Chart with region parameter filters correctly
- [ ] Test: Invalid parameter value rejected with clear error
- [ ] Test: Default parameter values applied
- [ ] Test: Multiple parameters work together

### 3.4.2 Variable Tests

- [ ] Test: Variable interpolated in chart title
- [ ] Test: Multiple variables in metadata
- [ ] Test: Variables calculated correctly with aggregations
- [ ] Test: Variables match report variable behavior

### 3.4.3 Streaming Tests

- [ ] Test: Chart with 1M records streams successfully
- [ ] Test: Memory usage <100MB for streaming 1M records
- [ ] Test: Streaming results match non-streaming results
- [ ] Test: UI shows progressive updates during streaming

---

# Phase 4: Migration & Documentation (Weeks 7-8)

**Goal**: Complete migration tooling, documentation, and demo

## 4.1 Migration Tooling

- [ ] **Create automated migration tools**

### 4.1.1 Mix Task Implementation

- [ ] **Task 4.1.1.1: Create mix task**
  - Create `lib/mix/tasks/ash_reports.migrate_charts.ex`
  - Implement `mix ash_reports.migrate_charts` command
  - Accept options: `--domain`, `--chart`, `--dry-run`
  - Output migration suggestions and diffs

- [ ] **Task 4.1.1.2: Pattern detection**
  - Parse existing chart DSL blocks
  - Detect `data_source(fn -> ... end)` patterns
  - Identify driving resource from `Ash.read!` calls
  - Detect simple grouping and aggregation patterns

### 4.1.2 Code Transformation

- [ ] **Task 4.1.2.1: AST manipulation**
  - Use Elixir AST parsing to analyze chart definitions
  - Detect `Ash.Query.load` for relationship usage
  - Detect `Enum.group_by` for group_by conversion
  - Detect `Enum.map` + `length` for count aggregation

- [ ] **Task 4.1.2.2: Generate declarative code**
  - Generate `driving_resource` declaration
  - Generate `load_relationships` if needed
  - Generate `transform` block with detected operations
  - Preserve `config` block unchanged

### 4.1.3 Migration Validation

- [ ] **Task 4.1.3.1: Verification mode**
  - Run both imperative and declarative versions
  - Compare outputs for equivalence
  - Warn about differences in results
  - Suggest manual review if outputs differ

- [ ] **Task 4.1.3.2: Safety checks**
  - Never overwrite files without confirmation
  - Create backup of original definitions
  - Support `--dry-run` to preview changes
  - Log all transformations for audit

### 4.1.4 Unit Tests

- [ ] Test: Mix task finds all charts in domain
- [ ] Test: Simple pie chart converted correctly
- [ ] Test: Bar chart with relationships converted correctly
- [ ] Test: Complex chart suggests manual migration
- [ ] Test: Dry-run mode doesn't modify files
- [ ] Test: Backup files created before modification

## 4.2 Documentation Updates

- [ ] **Comprehensive documentation overhaul**

### 4.2.1 Chart Guide Updates

- [ ] **Task 4.2.1.1: Update graphs-and-visualizations.md**
  - Mark imperative style as deprecated
  - Show declarative as primary approach
  - Add "Declarative vs Imperative" comparison section
  - Update all examples to use declarative style

- [ ] **Task 4.2.1.2: Add declarative examples**
  - Complete example for each chart type (7 types)
  - Show simple and complex versions
  - Include relationship loading examples
  - Include parameter examples

### 4.2.2 Migration Guide

- [ ] **Task 4.2.2.1: Create migration guide**
  - Create `guides/user/migrating-charts.md`
  - Explain why declarative is better
  - Show step-by-step conversion process
  - Provide before/after for common patterns

- [ ] **Task 4.2.2.2: Migration patterns catalog**
  - Document 10+ common imperative patterns
  - Show declarative equivalent for each
  - Include edge cases and workarounds
  - Link to mix task documentation

### 4.2.3 Performance Guide Updates

- [ ] **Task 4.2.3.1: Update performance-optimization.md**
  - Add "Declarative Charts" section
  - Explain automatic optimization
  - Show when manual optimization still needed
  - Update DataSourceHelpers section (now internal)

- [ ] **Task 4.2.3.2: Benchmarking guide**
  - Document how to benchmark charts
  - Show telemetry integration
  - Provide performance expectations
  - Include case studies (325K records example)

### 4.2.4 API Documentation

- [ ] **Task 4.2.4.1: Module documentation**
  - Add extensive `@moduledoc` to new modules
  - Include usage examples in docs
  - Document all public functions with `@doc`
  - Add `@spec` typespecs for all functions

- [ ] **Task 4.2.4.2: Generate HexDocs**
  - Ensure all modules have proper docs
  - Add guides to HexDocs structure
  - Include diagrams for architecture
  - Review generated docs for completeness

### 4.2.5 Unit Tests

- [ ] Test: All code examples in docs are valid
- [ ] Test: Migration guide examples execute successfully
- [ ] Test: Links between guides work correctly
- [ ] Test: HexDocs build without warnings

## 4.3 Demo Migration

- [ ] **Migrate all demo charts to declarative style**

### 4.3.1 Chart Conversions

- [ ] **Task 4.3.1.1: Migrate simple charts**
  - Customer Status Distribution (pie chart)
  - Monthly Revenue (line chart)
  - Inventory Levels Over Time (area chart)
  - Customer Health Trend (sparkline)

- [ ] **Task 4.3.1.2: Migrate relationship charts**
  - Product Sales by Category (bar chart with relationships)
  - Top Products by Revenue (bar chart with relationships)
  - Price vs Quantity Analysis (scatter chart with relationships)
  - Invoice Payment Timeline (gantt chart)

### 4.3.2 Demo Enhancements

- [ ] **Task 4.3.2.1: Add parameters to demo charts**
  - Add region parameter to customer charts
  - Add category parameter to product charts
  - Add status parameter to invoice charts
  - Show parameter UI in demo

- [ ] **Task 4.3.2.2: Add variables to demo charts**
  - Add total_customers variable to pie chart
  - Add total_revenue variable to bar charts
  - Show variables in chart titles
  - Display variables in metadata panel

### 4.3.3 Performance Benchmarks

- [ ] **Task 4.3.3.1: Create benchmark suite**
  - Benchmark each demo chart with :large dataset
  - Compare declarative vs imperative performance
  - Measure query counts for each approach
  - Document results in README

- [ ] **Task 4.3.3.2: Add :huge dataset option**
  - Create 1M+ record dataset option
  - Test streaming with huge dataset
  - Demonstrate memory efficiency
  - Show progressive rendering in UI

### 4.3.4 Unit Tests

- [ ] Test: All 8 demo charts work with declarative style
- [ ] Test: Demo chart parameters function correctly
- [ ] Test: Demo chart variables display properly
- [ ] Test: Performance meets targets (<1s for 325K records)
- [ ] Test: Streaming works with :huge dataset

## 4.4 Phase 4 Integration Tests

- [ ] **End-to-end validation of Phase 4**

### 4.4.1 Migration Tool Tests

- [ ] Test: Migration tool converts all 8 demo charts
- [ ] Test: Converted charts produce identical results
- [ ] Test: Complex charts suggest manual review
- [ ] Test: Dry-run mode shows accurate previews

### 4.4.2 Documentation Tests

- [ ] Test: All guide examples execute without errors
- [ ] Test: Migration guide successfully converts sample chart
- [ ] Test: HexDocs build and render correctly
- [ ] Test: No broken links in documentation

### 4.4.3 Demo Validation Tests

- [ ] Test: Demo application starts and loads all charts
- [ ] Test: All 8 charts render successfully
- [ ] Test: Parameters can be changed via UI
- [ ] Test: Variables display in chart UI
- [ ] Test: Performance benchmarks meet targets

---

# Success Criteria

## Code Quality

- [ ] All new modules have >90% test coverage
- [ ] All public functions have typespecs and documentation
- [ ] Credo shows no warnings on new code
- [ ] Dialyzer shows no type errors

## Performance

- [ ] Declarative charts with 325K records complete in <1s
- [ ] No N+1 query problems in declarative mode
- [ ] Pipeline overhead <10ms for simple charts
- [ ] Streaming mode uses <100MB for 1M records

## Backwards Compatibility

- [ ] All 8 existing demo charts work without modification
- [ ] Imperative data_source continues to function
- [ ] No breaking changes to chart generation API
- [ ] Deprecation warnings logged appropriately

## User Experience

- [ ] 60%+ reduction in chart code lines (declarative vs imperative)
- [ ] Zero manual optimization code needed for declarative charts
- [ ] Migration tool converts >90% of simple charts automatically
- [ ] Clear error messages for invalid chart definitions

## Documentation

- [ ] Complete migration guide published
- [ ] All chart types have declarative examples
- [ ] Performance guide updated with declarative patterns
- [ ] API documentation complete with examples

## Demo Quality

- [ ] All 8 demo charts migrated to declarative
- [ ] Parameters working in at least 3 charts
- [ ] Variables displayed in chart UI
- [ ] Performance benchmarks documented in README

---

# Key Outputs

## Modules Created

1. `AshReports.Charts.DataLoader` - Chart data loading through pipeline
2. `AshReports.Charts.Transform` - Transform DSL and execution engine
3. `Mix.Tasks.AshReports.MigrateCharts` - Automated migration tool

## Modules Modified

1. `AshReports.Dsl` - Add transform DSL to chart entities
2. `AshReports.Charts` - Integration with pipeline
3. `AshReportsDemo.Domain` - Migrate all 8 demo charts

## Documentation Created

1. `guides/user/migrating-charts.md` - Migration guide
2. `notes/planning/chart_pipeline.md` - This implementation plan
3. `notes/chart-pipeline-integration-design.md` - Architecture design doc

## Documentation Updated

1. `guides/user/graphs-and-visualizations.md` - Declarative examples
2. `guides/user/performance-optimization.md` - Declarative optimization
3. `README.md` - Performance benchmarks and examples

## Tests Created

- [ ] 50+ unit tests across new modules
- [ ] 20+ integration tests for end-to-end scenarios
- [ ] Performance benchmark suite
- [ ] Migration verification tests

---

# Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1 | Weeks 1-2 | DataLoader, Transform DSL, Backwards compatibility |
| Phase 2 | Weeks 3-4 | Relationship optimization, Complex aggregations |
| Phase 3 | Weeks 5-6 | Parameters, Variables, Streaming |
| Phase 4 | Weeks 7-8 | Migration tool, Documentation, Demo |

**Total Duration**: 8 weeks

---

# Dependencies

**Required before starting:**
- Existing `AshReports.DataLoader` module functional
- Existing `AshReports.QueryBuilder` module functional
- Current chart generation infrastructure stable
- Demo application with 8 working imperative charts

**External dependencies:**
- Ash Framework (relationship loading, queries)
- Spark DSL (for DSL extensions)
- Contex (chart rendering - no changes needed)

---

# Risk Mitigation

**Risk**: Pipeline overhead makes simple charts slower
**Mitigation**: Benchmark Phase 1, add fast-path for simple cases if needed

**Risk**: Migration tool can't convert complex charts
**Mitigation**: Focus on 80% common cases, provide manual migration guide

**Risk**: Breaking changes discovered during implementation
**Mitigation**: Extensive backwards compatibility testing, long deprecation period

**Risk**: User adoption is slow
**Mitigation**: Clear documentation, compelling performance benefits, simple migration

---

**Document Status**: Ready for Implementation
**Last Updated**: 2025-01-06
**Next Review**: After Phase 1 completion
