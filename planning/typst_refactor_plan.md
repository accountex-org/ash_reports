# AshReports Typst Integration Refactor Implementation Plan

## 📋 Overview

This plan implements a complete architectural refactor of AshReports to replace the current rendering system with a modern Typst-based engine. The refactor leverages Typst's **18x faster compilation speed**, native multi-format output support, and seamless integration with Elixir's concurrent processing capabilities.

**Current Status**: AshReports has a complete Spark DSL framework with band-based report definitions, but needs modern Typst integration for performance.

**Target Architecture**: DSL-driven Typst template generation → 18x faster compilation → Modern multi-format output (PDF, PNG, SVG)

**Key Architectural Insight**: Generate Typst templates dynamically from AshReports DSL definitions rather than managing static template files.

---

# Stage 1: Infrastructure Foundation and Typst Integration

**Duration**: 2-3 weeks
**Status**: ✅ **COMPLETED** - All Sections (1.1, 1.2, 1.3, 1.4) Complete
**Goal**: Establish core Typst integration infrastructure and replace basic rendering pipeline

## 1.1 Typst Runtime Integration

### 1.1.1 Elixir Typst Bindings Setup
- [x] Add Typst Elixir bindings dependency (typst 0.1.7) - **COMPLETED**
- [x] Configure Rustler for Typst compilation integration - **COMPLETED**
- [x] Implement basic Typst rendering interface - **COMPLETED**
- [x] Create Typst binary wrapper module - **COMPLETED**
- [x] Add error handling for Typst compilation failures - **COMPLETED**

### 1.1.2 ~~Template Engine Foundation~~ → **ARCHITECTURAL PIVOT**
- [x] ~~Create `AshReports.Typst.TemplateManager` module~~ - **REPLACED with DSL-driven approach**
- [x] ~~Implement file-based template system~~ - **PIVOTED to DSL-to-Typst generation**
- [x] Add template caching with ETS - **REUSED in new architecture**
- [x] Create hot-reloading for development environment - **REUSED for generated templates**
- [x] Implement template validation and compilation checking - **REUSED with BinaryWrapper**

**🔄 ARCHITECTURAL DECISION**: Pivot from manual template files to DSL-driven template generation.
AshReports should generate Typst templates dynamically from Spark DSL report definitions, not load static `.typ` files.

## 1.2 DSL-to-Typst Template Generation **← COMPLETED** ✅

### 1.2.1 DSL Template Generator
- [x] Create `AshReports.Typst.DSLGenerator` module - **COMPLETED**
- [x] Implement AshReports DSL → Typst template conversion - **COMPLETED**
- [x] Map band types (title, header, detail, footer) to Typst structures - **COMPLETED**
- [x] Generate conditional sections and grouping logic - **COMPLETED**
  - **NOTE**: Group header/footer rendering with aggregation statistics (group subtotals) deferred to Stage 2, Section 2.4
- [x] Support element types (field, label, expression, aggregate, line, box, image) - **COMPLETED**

### 1.2.2 Band Architecture Implementation
- [x] Implement Crystal Reports-style band rendering in Typst - **COMPLETED**
- [x] Create hierarchical band processing (nested groups) - **COMPLETED**
- [x] Add support for band positioning and layout - **COMPLETED**
- [x] Implement page break and section flow control - **COMPLETED**
- [x] Create band-specific styling and theming - **COMPLETED**

### 1.2.3 Element Rendering System
- [x] Map AshReports elements to Typst components: - **COMPLETED**
  - `field` → Data field display with formatting
  - `label` → Static text with positioning
  - `expression` → Calculated expressions
  - `aggregate` → Sum, count, avg functions
  - `line` → Graphical separators
  - `box` → Container elements
  - `image` → Image embedding

## 1.3 Ash Resource Data Integration **← COMPLETED** ✅

### 1.3.1 Query to Data Pipeline
- [x] Create `AshReports.Typst.DataLoader` module - **COMPLETED**
- [x] Implement driving_resource query execution - **COMPLETED**
- [x] Handle resource relationships and preloading - **COMPLETED**
- [x] Transform Ash structs to Typst-compatible data - **COMPLETED**
- [x] Support calculated fields and aggregations - **COMPLETED**

### 1.3.2 Data Formatting and Processing
- [x] Implement data type conversion (DateTime, Decimal, Money) - **COMPLETED**
- [x] Create grouping and sorting based on DSL definitions - **COMPLETED**
- [x] Add support for complex relationship traversal - **COMPLETED**
- [x] Implement variable scopes (detail, group, page, report) - **COMPLETED**
- [ ] Handle large dataset streaming with GenStage - **See Stage 2 for implementation**

## 1.4 Integration Testing Infrastructure **← COMPLETED** ✅

### 1.4.1 Test Framework Setup
- [x] Create Typst rendering test helpers - **COMPLETED**
  - `AshReports.TypstTestHelpers` with PDF validation, text extraction, and test utilities
  - 16 tests covering compilation, validation, and PDF generation
- [x] Add performance benchmarking for compilation speed - **COMPLETED**
  - `AshReports.TypstBenchmarkHelpers` using Benchee for performance testing
  - Benchmark suite for simple/medium/complex reports with performance targets
  - 12 tests for benchmarking, validation, and regression detection
- [x] Implement visual regression testing for PDF output - **COMPLETED**
  - `AshReports.TypstVisualRegression` for baseline capture and comparison
  - PDF text extraction and structure comparison
  - 12 tests for baseline management and visual regression detection
- [x] Create mock data generators for complex scenarios - **COMPLETED**
  - `AshReports.TypstMockData` using StreamData for property-based testing
  - Generators for templates, tables, edge cases, and nested structures
  - 14 tests (4 properties, 10 unit tests) for data generation
- [x] Add memory usage monitoring for large reports - **COMPLETED**
  - `AshReports.TypstMemoryMonitor` for memory tracking and leak detection
  - Real-time memory sampling during compilation with GC statistics
  - 15 tests for memory monitoring, leak detection, and limit validation

---

# Stage 2: GenStage Streaming Pipeline for Large Datasets

**Duration**: 3-4 weeks (Section 2.4 adds ~1 week for DSL integration)
**Status**: ✅ **95% COMPLETE** - All Core Implementation Done, Testing Remaining
**Goal**: Implement memory-efficient streaming for reports and visualizations with 10K+ records using GenStage/Flow, with automatic configuration from Report DSL

**Why This Stage**: GenStage streaming provides foundational infrastructure for both full report generation (100K+ records) and chart data aggregation (1M records → 500 datapoints). This must be implemented before visualization work (Stage 3) to enable efficient chart generation from large datasets.

**New in This Stage**: Section 2.4 implements DSL-driven grouped aggregation configuration, automatically parsing Report groups and variables to configure ProducerConsumer streaming aggregations.

**Use Cases**:
- Full report generation with 100K+ records
- Chart data aggregation - stream 1M records → aggregate to 500 chart datapoints for SVG rendering
- Real-time report updates with incremental data loading
- Memory-efficient export for large datasets

## 2.1 GenStage Infrastructure Setup ✅ **COMPLETED**

### 2.1.1 Dependencies and Core Modules ✅
- [x] Add gen_stage dependency to mix.exs (~> 1.2)
- [x] Add flow dependency to mix.exs (~> 1.2)
- [x] Create `AshReports.Typst.StreamingPipeline` module
  - Complete API with start_pipeline, stop_pipeline, pause/resume
  - Comprehensive documentation and examples
- [x] Design producer-consumer architecture
  - Producer → ProducerConsumer → Consumer (Stream)
  - Fully implemented with backpressure and telemetry
- [x] Document streaming API and usage patterns
  - Detailed @moduledoc with architecture diagrams
  - Examples for all common use cases

### 2.1.2 Supervision Tree ✅
- [x] Implement supervision tree for streaming processes
  - `StreamingPipeline.Supervisor` with :one_for_one strategy
  - Max 10 restarts in 60 seconds
- [x] Add dynamic supervisor for concurrent streams
  - `PipelineSupervisor` (DynamicSupervisor)
  - Isolates individual pipeline failures
- [x] Create stream registry for tracking active pipelines
  - `Registry` module with ETS-based tracking
  - Pipeline metadata and status management
- [x] Implement cleanup on process termination
  - Automatic cleanup on pipeline stop
  - Telemetry events for monitoring
- [x] Add health monitoring and restart strategies
  - `HealthMonitor` GenServer with periodic checks
  - Circuit breaker support
  - Automatic restart via supervisor

## 2.2 Producer Implementation ✅

### 2.2.1 Query Execution and Batching ✅
- [x] Create `StreamingProducer` for chunked Ash query execution
- [x] Implement demand-driven query batching
- [x] Handle query pagination with Ash offset/limit
- [x] Add configurable chunk sizes (default: 500-1000 records)
- [x] Implement query result caching for efficiency
  - Created `QueryCache` module with ETS-based caching
  - TTL-based expiration and LRU eviction
  - Query fingerprinting with SHA256
  - Memory-aware cache management

### 2.2.2 Relationship Handling ✅
- [x] Add intelligent preloading for relationships
- [x] Implement lazy loading for optional relationships
- [x] Handle deep relationship traversal efficiently
- [x] Add relationship depth limits to prevent memory issues
- [x] Create preload optimization strategies
  - Created `RelationshipLoader` module
  - Implemented three strategies: :eager, :lazy, :selective
  - Configurable depth limits to prevent excessive memory usage
  - Automatic relationship depth validation

### 2.2.3 Resource Management ✅
- [x] Implement memory monitoring and circuit breakers
- [x] Add automatic backpressure when memory threshold reached
- [x] Create graceful degradation strategies
  - Automatic chunk size reduction in degraded mode
  - Exponential backoff retry logic with configurable max retries
  - Memory usage monitoring with 80% threshold trigger
- [x] Implement resource cleanup on errors
  - Cleanup function with forced garbage collection
  - Proper error handling in fetch loops
- [x] Add configurable memory limits per stream
  - Per-stream memory_limit configuration option
  - Default 500MB per pipeline
  - Integrated with degraded mode detection

## 2.3 Consumer/Transformer Implementation ✅

### 2.3.1 Data Transformation Pipeline ✅
- [x] Create `StreamingConsumer` for data transformation
  - Enhanced ProducerConsumer module with full transformation support
  - DataProcessor integration for type conversion
  - Custom transformer function support
- [x] Integrate with DataProcessor for type conversion
  - Automatic conversion of DateTime, Decimal, Money, UUID types
  - Configurable conversion options
  - Fallback to raw events on conversion failure
- [x] Implement backpressure handling
  - Configurable min_demand and max_demand
  - GenStage automatic backpressure
  - Buffer size monitoring and warnings
- [x] Add configurable buffer management
  - Configurable buffer_size (default: 1000)
  - Buffer fullness tracking (80% threshold warning)
  - Telemetry events for buffer status
- [x] Create transformation error handling
  - Try-rescue blocks for safe transformation
  - Error logging and telemetry
  - Graceful fallback on errors

### 2.3.2 Aggregation Functions ✅
- [x] Implement streaming aggregation functions (sum, count, avg, percentiles)
  - `:sum` - Sum all numeric fields
  - `:count` - Count records processed
  - `:avg` - Average of numeric fields (sum/count)
  - `:min` - Minimum values per field
  - `:max` - Maximum values per field
  - `:running_total` - Cumulative totals
- [ ] Add support for time-series bucketing and grouping (for chart data)
  - Deferred to Stage 3 (visualization integration)
- [ ] Create window-based aggregations (sliding, tumbling)
  - Deferred to future enhancement
- [x] Implement running totals and cumulative calculations
  - Implemented as `:running_total` aggregation
- [ ] Add custom aggregation function support
  - Deferred to future enhancement

### 2.3.3 Monitoring and Telemetry ✅
- [x] Add progress tracking and telemetry
  - `[:ash_reports, :streaming, :producer_consumer, :batch_transformed]`
  - `[:ash_reports, :streaming, :producer_consumer, :aggregation_computed]`
  - `[:ash_reports, :streaming, :producer_consumer, :buffer_full]`
  - `[:ash_reports, :streaming, :producer_consumer, :error]`
- [x] Implement stream throughput monitoring
  - Records in/out tracking
  - Duration measurements per batch
  - Total transformed counter
- [x] Create memory usage tracking per stream
  - Buffer usage tracking
  - Records buffered counter
- [x] Add telemetry events for all streaming operations
  - Comprehensive telemetry coverage
  - Configurable enable_telemetry flag
- [ ] Implement stream health dashboards
  - Deferred to Stage 2.6 or future work

## 2.4 DSL-Driven Grouped Aggregation Configuration

**Goal**: Automatically configure ProducerConsumer grouped aggregations from Report DSL definitions

**Reference**: See `planning/grouped_aggregation_dsl_integration.md` for detailed research and design decisions

### 2.4.1 Expression Parsing and Field Extraction
- [x] Implement expression parser for `Ash.Expr.t()` from group definitions
- [x] Extract field names from group expressions: `expr(customer.region)` → `:region`
- [x] Support nested field access patterns
- [x] Handle relationship traversal in expressions: `{:field, :customer, :region}`
- [x] Add expression validation and error handling
- [x] Create fallback mechanisms for unparseable expressions

### 2.4.2 Variable-to-Aggregation Mapping ✅ **COMPLETED** (except report-level)
- [x] Map DSL variable types to ProducerConsumer aggregation types:
  - `:sum` → `:sum` ✅
  - `:count` → `:count` ✅
  - `:average` → `:avg` ✅
  - `:min` → `:min` ✅
  - `:max` → `:max` ✅
  - Plus: `:first` → `:first`, `:last` → `:last`
  - Implemented in `map_variable_type_to_aggregation/1` (data_loader.ex:501-512)
- [x] Filter variables by `reset_on: :group` scope
  - Implemented in `derive_aggregations_for_group/2` (data_loader.ex:476-478)
- [x] Match variables to group levels via `reset_group` field
  - Fully implemented with group level matching
  - Tested with multi-level grouping scenarios
- [ ] Support report-level variables (`reset_on: :report`) as global aggregations
  - **Deferred**: May use different mechanism or post-streaming calculation
  - Global aggregations currently handled via `:aggregations` option
- [x] Handle multi-level hierarchical grouping (Territory → Customer → Order Type)
  - Fully implemented with cumulative field accumulation
  - Tested with 3-level hierarchy (test: "three-level grouping returns fully cumulative fields")

### 2.4.3 Grouped Aggregation Config Builder
- [x] Create `build_grouped_aggregations_from_dsl/1` function
- [x] Parse report groups (level 1, 2, 3, ...) from DSL
- [x] Generate cumulative grouping configs:
  - Level 1: `group_by: :territory`
  - Level 2: `group_by: [:territory, :customer_name]`
  - Level 3: `group_by: [:territory, :customer_name, :order_type]`
- [x] Extract aggregation types from group-level variables
- [x] Build `grouped_aggregations` list for ProducerConsumer.start_link/1
- [x] Add configuration validation (detect missing fields, invalid expressions)
- [x] Create comprehensive error messages for debugging

### 2.4.4 Integration and Testing
- [x] Integrate with existing test report in `test/support/test_helpers.ex` (lines 129-221)
- [x] Test single-level grouping (by region)
- [x] Test multi-level grouping (region → customer)
- [x] Test variable filtering by `reset_on` and `reset_group`
- [x] Test edge cases:
  - Reports with no groups
  - Reports with groups but no variables
  - Variables with mismatched group levels
  - Complex expressions requiring fallback parsing
- [x] Validate generated config matches expected ProducerConsumer format
- [x] Create comprehensive integration test suite (17 tests)
- [x] Test three-level hierarchical grouping
- [x] Validate ProducerConsumer contract (field types, structure)

**Implementation Location**: `AshReports.Typst.DataLoader` module

**Expected Output Example**:
```elixir
# Input: Report DSL with groups and variables
report.groups = [
  %{level: 1, expression: expr(territory)},
  %{level: 2, expression: expr(customer_name)}
]
report.variables = [
  %{type: :sum, reset_on: :group, reset_group: 1}
]

# Output: ProducerConsumer config
[
  %{group_by: :territory, aggregations: [:sum, :count]},
  %{group_by: [:territory, :customer_name], aggregations: [:sum, :count]}
]
```

## 2.5 DataLoader Integration

**Note**: Uses Section 2.4 DSL parsing to auto-configure streaming pipelines with grouped aggregations

### 2.5.1 API Implementation ✅ **COMPLETED**
- [x] Implement `create_streaming_pipeline/4` function in DataLoader
- [x] Replace error placeholder with actual GenStage pipeline
- [x] Add streaming configuration options (8 new options)
- [x] Integrate `build_grouped_aggregations_from_dsl/1` (from Section 2.4)
- [x] Create unified API (`load_report_data/4` - always streams)
- [x] Document API usage patterns and examples
- [x] Enhance `build_pipeline_opts/7` for comprehensive configuration
- [x] Create comprehensive API tests
- [x] Maintain backward compatibility

### 2.5.2 Streaming-Only Architecture ✅ **COMPLETED**
- [x] Remove batch mode (`load_for_typst/4`) - ~260 lines removed
- [x] Simplify `load_report_data/4` to always use streaming
- [x] Remove mode selection logic and dataset size estimation
- [x] Remove batch-specific DataProcessor functions
- [x] Establish streaming-only architecture for all dataset sizes
- [x] Document streaming-only approach and performance characteristics
- [x] Update tests to reflect streaming-only behavior

**Architectural Decision**: Removed dual-mode (batch/streaming) in favor of streaming-only.
All reports now use GenStage pipeline regardless of size for consistency and memory safety.

### 2.5.3 Stream Control ✅ **COMPLETED**
- [x] Implement stream cancellation support
  - `StreamingPipeline.stop_pipeline/1` implemented
  - Stops Producer and ProducerConsumer stages
  - Updates registry status to `:stopped`
- [x] Add pause/resume functionality
  - `StreamingPipeline.pause_pipeline/1` implemented
  - `StreamingPipeline.resume_pipeline/1` implemented
  - Circuit breaker support via status updates
- [x] Create stream timeout handling
  - Default timeout: 300_000ms (5 minutes)
  - Configurable via `:timeout` option
  - Prevents hung processes
- [x] Implement graceful shutdown
  - Cleanup on process termination
  - Telemetry events on stop
  - Forced garbage collection
- [x] Add stream status queries
  - `StreamingPipeline.get_pipeline_info/1` implemented
  - `StreamingPipeline.list_pipelines/1` with filtering
  - Registry tracks: `:running`, `:paused`, `:stopped`, `:failed`

## 2.6 Testing and Performance Validation

### 2.6.1 Unit and Integration Tests
- [x] Create streaming pipeline unit tests
  - MVP test suite: 16 critical tests covering producer, consumer, aggregations, and end-to-end
  - Test file: `test/ash_reports/typst/streaming_pipeline/streaming_mvp_test.exs`
- [x] Test producer demand handling
  - Basic demand, chunk size respect, backpressure, completion, empty data
- [x] Test consumer backpressure
  - ProducerConsumer maintains backpressure through transformation pipeline
- [x] Test aggregation functions (global and grouped)
  - Sum, count, average, min/max aggregations tested
  - Grouped aggregations by field tested
- [x] Test DSL-driven aggregation config generation (from Section 2.4)
  - Existing tests in `data_loader_test.exs` cover cumulative grouping
- [x] Test error handling and recovery
  - Transformation error handling tested

### 2.6.2 Performance Benchmarks
- [x] Add memory usage benchmarks (target: <1.5x baseline)
  - MVP: 100K records benchmark - 80.19 MB (1.04x baseline of 77.25 MB) ✓ PASS
  - Results: benchmarks/results/memory_mvp.html
- [x] Test with datasets (MVP: 10K records for throughput)
  - Simple streaming: ~197 IPS (~1,970,000 records/sec)
  - With transformations: ~171 IPS (~1,710,000 records/sec)
- [x] Validate throughput (target: 1000+ records/sec)
  - ✓ PASS: Far exceeds target (1.9M+ records/sec)
  - Results: benchmarks/results/throughput_mvp.html
- [x] Test concurrent stream handling
  - MVP: 5 concurrent streams - 830 IPS (1.95x faster than sequential)
  - Results: benchmarks/results/concurrency_mvp.html
  - ✓ PASS: Validates concurrency works efficiently
- [ ] Benchmark aggregation performance (global vs grouped) - Future enhancement
- [ ] Benchmark DSL parsing overhead - Future enhancement

**MVP Benchmark Suite Implemented**:
- Runner script: `benchmarks/streaming_pipeline_benchmarks.exs`
- Main module: `test/support/benchmarks/streaming_benchmarks.ex`
- Validation tests: `test/ash_reports/typst/streaming_pipeline/performance_test.exs`
- All 7 performance validation tests passing

### 2.6.3 Load and Stress Testing
- [x] Test cancellation and error recovery
- [x] Test memory pressure scenarios
- [ ] Test network failures and retries
- [x] Test concurrent multi-stream scenarios
- [x] Test grouped aggregations with many unique groups (memory scaling)
- [x] Create stress testing suite

**Performance Targets**:
- **Memory Usage**: <1.5x baseline regardless of dataset size
- **Throughput**: 1000+ records/second on standard hardware
- **Scalability**: Support datasets from 10K to 1M+ records
- **Latency**: Streaming should start within 100ms
- **Reliability**: Automatic fallback to batch loading on errors
- **Concurrency**: Handle 10+ concurrent streams

**Architecture Overview**:
```
Ash Query → StreamingProducer (chunks of 500-1000 records)
                ↓
         GenStage backpressure
                ↓
      StreamingConsumer (DataProcessor transformation)
                ↓
         Enumerable Stream → Typst Compilation / Chart Aggregation
```

---

# Stage 3: Pure Elixir Visualization System Integration

**Duration**: 2-3 weeks
**Status**: 📋 Planned
**Goal**: Implement comprehensive chart generation using pure Elixir libraries with SVG output for Typst embedding

**Dependencies**: Requires Stage 2 (GenStage Streaming) for large dataset chart aggregation

**🔄 ARCHITECTURAL DECISION**: Use pure Elixir charting libraries (Contex/VegaLite) instead of Node.js D3 service for simpler, more maintainable architecture without external service dependencies.

**Why Pure Elixir Approach**:
- ✅ **No external services** - Eliminates Node.js dependency and HTTP communication overhead
- ✅ **Simpler architecture** - No service orchestration, connection pooling, or failover complexity
- ✅ **Better performance** - Direct SVG generation without network latency
- ✅ **Easier maintenance** - Single language stack (Elixir) for entire system
- ✅ **Native integration** - Seamless Ash resource and GenStage pipeline integration
- ✅ **Production ready** - Contex (pure Elixir) and VegaLite (Elixir bindings) are mature, well-maintained libraries

## 3.1 Elixir Chart Generation Infrastructure ✅ COMPLETED

### 3.1.1 Chart Library Integration ✅ COMPLETED
- [x] Add Contex dependency to mix.exs (~> 0.5.0) for pure Elixir SVG charts
- [x] Create `AshReports.Charts` base module for chart abstraction layer
  - Public API: `generate/3`, `list_types/0`, `type_available?/1`
  - Automatic config normalization (map → struct)
  - Telemetry integration for monitoring
- [x] Implement chart type registry (bar, line, pie)
  - GenServer-based registry with ETS for fast lookups
  - Runtime registration support via `Registry.register/2`
  - Module: `lib/ash_reports/charts/registry.ex`
- [x] Create common chart configuration schema (Ecto embedded schema)
  - Module: `lib/ash_reports/charts/config.ex`
  - Validated fields: dimensions, colors, legend, fonts, axis labels
  - Default color palette with hex validation
- [x] Add chart builder behavior for extensibility
  - Behavior: `AshReports.Charts.Types.Behavior`
  - Callbacks: `build/2`, `validate/1`
  - Allows custom chart type registration

### 3.1.2 SVG Generation Pipeline ✅ COMPLETED
- [x] Create `AshReports.Charts.Renderer` module for SVG output
  - Module: `lib/ash_reports/charts/renderer.ex`
  - Functions: `render/3`, `render_without_cache/3`
  - Integrates with Contex.Plot for SVG generation
- [x] Implement chart-to-SVG conversion using Contex
  - Supports Bar, Line, and Pie charts
  - Uses Contex mapping API (category_col, value_cols, x_col, y_cols)
  - Proper iodata → binary conversion
- [x] Add SVG optimization and minification (remove unnecessary attributes)
  - Basic whitespace optimization in `optimize_svg/1`
  - Removes redundant spacing from SVG output
- [x] Create SVG caching system with ETS (cache compiled charts)
  - Module: `lib/ash_reports/charts/cache.ex`
  - TTL-based expiration (default: 5 minutes)
  - Automatic cleanup with GenServer timer
  - Cache statistics via `get_stats/0`
- [x] Implement error handling and fallback rendering (simple text-based charts)
  - Fallback SVG generation on render failures
  - Validation at chart type level
  - Error telemetry events
- [x] Add telemetry events for chart generation metrics
  - Events: `[:ash_reports, :charts, :generate, :start]`
  - Events: `[:ash_reports, :charts, :generate, :stop]`
  - Metadata: chart_type, data_size, cache_status, svg_size

## 3.2 Chart Data Processing

### 3.2.1 Data Transformation Pipeline ✅ **COMPLETED**
- [x] Create `AshReports.Charts.DataExtractor` for Ash resource queries
  - Smart routing: <10K direct query, ≥10K streaming
  - Module: `lib/ash_reports/charts/data_extractor.ex` (347 lines)
  - Functions: `extract/2`, `extract_stream/2`, `count_records/2`
  - Field mapping and transformation support
- [x] Implement aggregation functions (sum, count, avg, field_min, field_max, grouping)
  - Module: `lib/ash_reports/charts/aggregator.ex` (398 lines)
  - Functions: `sum/2`, `count/2`, `avg/2`, `field_min/2`, `field_max/2`
  - Group-by aggregation: `group_by/4`, `aggregate/2`, `custom/4`
  - Handles Decimal types and nil values
  - 14 comprehensive tests in `test/ash_reports/charts/aggregator_test.exs`
- [x] Add time-series data formatting and time bucketing (daily, weekly, monthly)
  - Module: `lib/ash_reports/charts/time_series.ex` (387 lines)
  - Bucket types: hour, day, week, month, quarter, year
  - Functions: `bucket/4`, `bucket_and_aggregate/6`, `fill_gaps/4`
  - Timex integration for date manipulation
  - Gap filling for continuous time series
- [x] Create multi-dimensional data pivoting for complex charts
  - Module: `lib/ash_reports/charts/pivot.ex` (409 lines)
  - Functions: `pivot/2`, `group_by_multiple/4`, `to_heatmap_format/2`
  - Pivot table generation with row/column transformation
  - Heatmap data format conversion
  - Transpose and flatten utilities
- [x] Implement statistical calculations (percentiles, std deviation, median)
  - Module: `lib/ash_reports/charts/statistics.ex` (375 lines)
  - Functions: `median/2`, `percentile/3`, `quartiles/2`
  - Standard deviation (sample/population): `std_dev/3`
  - Variance (sample/population): `variance/3`
  - Summary statistics: `summary/2`
  - Outlier detection (IQR method): `outliers/3`
  - Uses Erlang `:statistics` library
- [x] Integrate with GenStage streaming for large datasets (>10K records)
  - DataExtractor includes streaming integration
  - References `StreamingPipeline.start_stream/4` (from Stage 2)
  - **Note**: Full integration pending StreamingPipeline API finalization

**Dependencies Added**:
- `statistics ~> 0.6.3` - Erlang statistical functions
- `timex ~> 3.7` - Time manipulation and bucketing

**Implementation Location**: `lib/ash_reports/charts/` (5 new modules, ~1,900 lines)

**Performance Note**: For datasets >10K records, use GenStage streaming pipeline (Stage 2) to perform server-side aggregation before chart generation. Aggregate 1M records → 500-1000 chart datapoints for optimal SVG rendering performance.

### 3.2.2 Chart Type Implementations ✅ **COMPLETED**
- [x] Implement BarChart using Contex (grouped, stacked, horizontal)
  - Module: `lib/ash_reports/charts/types/bar_chart.ex`
  - Supports: simple, grouped, stacked modes
  - Data format: `%{category: string, value: number}`
- [x] Implement LineChart using Contex (single/multi-series, area fill)
  - Module: `lib/ash_reports/charts/types/line_chart.ex`
  - Supports: x/y coordinates, date/value time-series
  - Data format: `%{x: number, y: number}` or `%{date: Date.t(), value: number}`
- [x] Implement PieChart using Contex (with percentage labels)
  - Module: `lib/ash_reports/charts/types/pie_chart.ex`
  - Automatic percentage calculation
  - Data format: `%{category: string, value: number}` or `%{label: string, value: number}`
- [x] Implement AreaChart (stacked areas for time-series)
  - Module: `lib/ash_reports/charts/types/area_chart.ex` (194 lines)
  - SVG post-processing for area fill with configurable opacity
  - Supports simple and stacked modes
  - Time-ordered data validation
  - Data format: `%{x: number, y: number}` or `%{date: Date.t(), value: number}`
  - Enhanced Renderer with area fill SVG generation
- [x] Implement ScatterPlot (basic implementation)
  - Module: `lib/ash_reports/charts/types/scatter_plot.ex` (98 lines)
  - Uses Contex PointPlot for scatter visualization
  - Data format: `%{x: number, y: number}`
  - **Note**: Regression lines deferred to future enhancement
- [ ] Create custom chart builder API for complex visualizations
  - **Deferred**: Can be implemented in Section 3.2.3 or future work
  - Would include SVG primitives helper and builder pattern
  - Example: HeatmapChart as custom implementation

**Implementation Summary**:
- 2 new chart types added (AreaChart, ScatterPlot)
- Enhanced Renderer module with area fill post-processing (~90 lines added)
- All tests passing (12 chart generation tests)
- Total new code: ~290 lines

### 3.2.3 Dynamic Chart Configuration ✅ **COMPLETED** (MVP)
- [x] Create chart theming system (colors, fonts, styles, dimensions)
  - Module: `lib/ash_reports/charts/theme.ex` (200 lines)
  - 4 predefined themes: `:default`, `:corporate`, `:minimal`, `:vibrant`
  - Theme application with cascading config: theme → user config → overrides
  - Smart merging that only overrides user-set values
- [x] Extend Config schema with theme and layout fields
  - Module: `lib/ash_reports/charts/config.ex` (enhanced)
  - New fields: `theme_name`, `responsive`, `show_data_labels`, `min_data_points`
  - Backward compatible with existing code
- [x] Implement conditional chart rendering based on data
  - `min_data_points` validation in chart generation
  - Returns error if insufficient data points
  - Integrated into `Charts.generate/3` pipeline
- [x] Add theme application logic in Charts module
  - Automatic theme application in generation pipeline
  - Theme validation and fallback
  - Config → Theme → Render flow
- [ ] Add runtime chart configuration from Report DSL
  - **Deferred**: Would require DSL element integration (Section 3.3.2)
  - Can be added when implementing chart elements
- [ ] Add chart size and layout options (responsive sizing)
  - **Partial**: `responsive` field added to Config
  - **Deferred**: Implementation logic for dynamic sizing
- [ ] Implement legend and axis customization (labels, ticks, gridlines)
  - **Partial**: Existing fields in Config (show_legend, legend_position, axis labels, show_grid)
  - **Note**: Contex provides limited customization options
- [ ] Add data labels and annotations support
  - **Partial**: `show_data_labels` field added to Config
  - **Deferred**: Rendering logic (would require SVG post-processing)

**Implementation Summary**:
- 1 new module (Theme) with 4 predefined themes
- Config schema extended with 4 new fields
- Chart generation pipeline enhanced with theme application
- Conditional rendering based on data availability
- 51 tests passing (20 new theme/config tests)
- Total new code: ~200 lines

**Future Enhancements**:
- DSL chart element integration
- Responsive sizing implementation
- Data labels rendering
- Annotations and reference lines

## 3.3 Typst Chart Integration

### 3.3.1 SVG Embedding System ✅ **COMPLETED** (MVP)
- [x] Create `AshReports.Typst.ChartEmbedder` module
  - Module: `lib/ash_reports/typst/chart_embedder.ex` (~270 lines)
  - Helper: `lib/ash_reports/typst/chart_embedder/typst_formatter.ex` (~150 lines)
  - Base64 encoding with file fallback for large SVGs (>1MB)
  - Four main functions: `embed/2`, `embed_grid/2`, `embed_flow/2`, `generate_and_embed/4`
- [x] Implement SVG-to-Typst image embedding (`#image()` function)
  - Primary: `#image.decode()` with base64 encoding
  - Fallback: `#image()` with file paths for large charts
  - Automatic encoding selection based on SVG size
- [x] Add chart positioning and layout in Typst templates
  - Width/height support with multiple formats (pt, mm, cm, %, fr)
  - Dimension formatting utilities
  - Maintains aspect ratio when only one dimension specified
- [x] Create caption and title support with Typst formatting
  - Title: `#text(size: 14pt, weight: "bold")[...]`
  - Caption: `#text(size: 10pt, style: "italic")[...]`
  - Special character escaping for Typst safety
- [x] Implement multi-chart page layouts (grid/flow layouts)
  - Grid layout: `#grid()` with configurable columns, gutter, column widths
  - Flow layout: vertical stacking with `#v()` spacing
  - Supports custom layout options per chart
- [x] Add chart scaling and responsive sizing (percentage widths)
  - Supports percentage widths (e.g., "100%", "50%")
  - Fractional widths for grid layouts (e.g., "1fr", "2fr")
  - Numeric values auto-converted to points

**Implementation Summary**:
- 2 modules (ChartEmbedder + TypstFormatter, ~420 lines)
- 18 comprehensive tests, all passing
- Full integration with Charts module
- Supports single and multi-chart layouts
- Caption, title, and sizing support
- Base64 and file encoding strategies

### 3.3.2 DSL Chart Element ✅ **COMPLETED** (Runtime Implementation)
- [x] Extend Report DSL with `chart` element type
  - Module: `lib/ash_reports/element/chart.ex` (~75 lines)
  - Added chart_element_entity and chart_element_schema to DSL
  - Registered in elements list for band definitions
- [x] Add chart configuration in band definitions (header/detail/footer)
  - Charts can be added to any band type
  - Full DSL syntax support for all chart types
  - Config and embed_options support
- [x] Runtime chart generation with ChartPreprocessor
  - Module: `lib/ash_reports/typst/chart_preprocessor.ex` (~240 lines)
  - Server-side SVG generation via Charts.generate/3
  - SVG embedding via ChartEmbedder.embed/2
  - Error handling with fallback placeholders
- [x] Implement chart data binding from report query data
  - Expression evaluation for data_source (:records, static lists)
  - Config evaluation (maps and expressions)
  - Integration with report data context
- [x] Chart preprocessing architecture
  - preprocess/2 extracts and processes all chart elements
  - process_chart/2 handles individual chart generation
  - evaluate_data_source/2 for expression evaluation
  - evaluate_config/2 for configuration processing
  - embed_chart/2 for ChartEmbedder integration
- [x] DSLGenerator integration
  - Updated generate_chart_element/2 to use preprocessed charts
  - generate_preprocessed_chart/3 for embedded SVG code
  - generate_chart_placeholder/2 for fallback
  - Charts injected via context[:charts] map
- [ ] Create chart variable support for dynamic configuration
  - **Deferred**: Advanced expression substitution in config values
  - Basic map configs fully supported
  - param(:name) style references need expansion
- [ ] Add chart conditional rendering (show/hide based on conditions)
  - **Deferred**: Runtime condition evaluation
  - conditional field exists in element struct
  - Needs evaluate_expression enhancement

**Implementation Summary**:
- 1 new element module (Chart, ~75 lines)
- 1 new preprocessor module (ChartPreprocessor, ~240 lines)
- DSL extended with chart element entity and schema (~60 lines)
- DSLGenerator enhanced for preprocessor integration (~70 lines)
- Comprehensive test suite (365 lines, 15 tests)
- **20 tests passing total** (element + DSL + preprocessor)
- All 5 chart types supported (bar, line, pie, area, scatter)
- Full integration with Charts.generate/3 and ChartEmbedder.embed/2
- Foundation for full data binding and dynamic configuration

**Deferred to Future Work**:
- Runtime expression evaluation for data_source
- Variable substitution in chart config
- Conditional rendering based on expressions
- Full documentation with working examples

### 3.3.3 Performance Optimization
- [ ] Implement parallel chart generation with Task.async
- [ ] Add chart result caching (ETS cache for compiled SVG)
- [ ] Create lazy chart loading for complex multi-chart reports
- [ ] Add SVG compression for embedded chart data (gzip)
- [ ] Implement memory-efficient chart processing (streaming aggregation)
- [ ] Add telemetry for chart generation performance tracking

---

# Stage 4: Phoenix LiveView Integration and Real-time Features

**Duration**: 2-3 weeks
**Status**: ✅ **Section 4.1 Complete** (Phases 1-6 Complete with polish and documentation)
**Goal**: Create modern web interface with real-time report generation

## 4.1 LiveView Report Builder ✅ **COMPLETE**

### 4.1.1 Interactive Report Designer
**Phase 1: MVP Foundation** ✅ Complete
- [x] Create `AshReportsWeb.ReportBuilderLive` module (340 lines)
- [x] Implement template selection interface (3 templates: Sales, Customer, Inventory)
- [x] Create business logic context `AshReports.ReportBuilder` (330 lines, 8 functions)
- [x] Add 4-step wizard UI (Template → Data Source → Preview → Generate)
- [x] Implement comprehensive test suite (23 tests, 90%+ coverage)

**Phase 2: Data Configuration** ✅ Complete (2025-10-04)
- [x] Create DataSourceConfig LiveComponent (280 lines)
- [x] Implement Ash resource browsing from Domain
- [x] Add dynamic filter configuration UI
- [x] Wire up preview data loading from real Ash resources
- [x] Implement relationship selection interface
- [x] Add component-to-parent communication pattern

**Phase 3: Visualization & Preview** ✅ Complete (2025-10-04)
- [x] Create VisualizationConfig LiveComponent (450 lines)
- [x] Integrate with Charts.Config module
- [x] Add chart type selection UI (5 types: bar, line, pie, area, scatter)
- [x] Implement comprehensive chart configuration interface
- [x] Add chart preview placeholders
- [x] Wire up visualization updates to config

**Phase 4: Progress Tracking** ✅ Complete (2025-10-04)
- [x] Create ProgressTracker GenServer (280 lines)
- [x] ETS-based state storage
- [x] LiveView polling mechanism for progress updates
- [x] Cancel functionality
- [x] Simulated report generation with progress
- [x] Graceful fallback for tests

**Phase 5: Collaborative Features** ⏭️ Deferred
- [ ] Implement collaborative editing with Phoenix Presence (deferred to future iteration)

**Phase 6: Testing & Polish** ✅ Complete (2025-10-04)
- [x] Enhanced UI with loading states and animations
- [x] Implemented comprehensive form validation
- [x] Added contextual help tooltips to all steps
- [x] Added inline documentation to code
- [ ] Integration testing (deferred - requires ConnCase setup)
- [ ] Performance benchmarking (deferred)

### 4.1.2 Progress Tracking System (Phase 1: UI Foundation)
- [x] Add progress bar UI component (ready for real progress)
- [x] Create generation status tracking in LiveView state
- [ ] Implement WebSocket-based status updates (Phase 4)
- [ ] Create task management for background jobs (Phase 4)
- [ ] Add cancellation support for long-running reports (Phase 4)
- [ ] Implement notification system for completion (Phase 4)

**Phase 1-4 Status**: ✅ Complete (2025-10-04)
- Working LiveView accessible at `/reports/builder`
- Template selection functional
- Data source configuration with live resource browsing
- Filter configuration UI with dynamic filters
- Preview data loading from real Ash resources
- Visualization configuration with 5 chart types
- Chart configuration UI (title, dimensions, theme, legend, grid)
- Chart preview placeholders
- Progress tracking with GenServer and ETS
- Real-time progress updates via LiveView polling
- Cancel functionality for report generation
- All 23 tests passing
- Step navigation working
- Business logic tested and ready for further integration
- Clean architecture with separation of concerns
- **~1,795 lines of new code total**

## 4.2 Advanced UI Components

### 4.2.1 Data Configuration Interface
- [ ] Create data source selection components
- [ ] Implement filter and parameter configuration
- [ ] Add preview data sampling
- [ ] Create relationship mapping tools
- [ ] Implement validation and error display

### 4.2.2 Template Customization ✅ **COMPLETED**
- [x] Add theme selection interface (5 predefined themes)
- [x] Implement style customization tools (brand colors, typography)
- [ ] Create logo and branding upload (deferred to future)
- [x] Add font selection and preview (via theme typography)
- [x] Implement Typst styling generation (CustomizationRenderer)

**Status**: Complete - 79 tests passing
**Branch**: `feature/stage4-section4.2.2-template-customization`
**Summary**: `demo/notes/features/stage4_section4.2.2_feature_summary.md`

## 4.3 Report Gallery and Management

### 4.3.1 Report Library System
- [ ] Create report listing and search
- [ ] Implement tagging and categorization
- [ ] Add sharing and permissions management
- [ ] Create version control for templates
- [ ] Implement report scheduling system

---

# Stage 5: Production Deployment and Scalability

**Duration**: 2-3 weeks
**Status**: 📋 Planned
**Goal**: Production-ready deployment with monitoring and scalability

## 5.1 Containerization and Orchestration

### 5.1.1 Docker Configuration
- [ ] Create multi-stage Dockerfile with Typst and Elixir
- [ ] Implement proper font installation and configuration
- [ ] Add health checks for report generation service
- [ ] Create volume management for templates and cache
- [ ] Implement security hardening

### 5.1.2 Kubernetes Deployment
- [ ] Create Kubernetes manifests for scalable deployment
- [ ] Implement horizontal pod autoscaling
- [ ] Add persistent volume claims for report storage
- [ ] Create service mesh configuration
- [ ] Implement rolling updates and rollback strategies

## 5.2 Monitoring and Observability

### 5.2.1 Telemetry Implementation
- [ ] Add comprehensive Telemetry metrics
- [ ] Implement Prometheus integration
- [ ] Create custom dashboards for report performance
- [ ] Add alerting for service failures
- [ ] Implement distributed tracing

### 5.2.2 Performance Optimization
- [ ] Create performance benchmarking suite
- [ ] Implement connection pooling optimization
- [ ] Add memory usage monitoring and optimization
- [ ] Create cache warming strategies
- [ ] Implement query optimization for large datasets

## 5.3 Security and Compliance

### 5.3.1 Security Hardening
- [ ] Implement template sandboxing
- [ ] Add input validation and sanitization
- [ ] Create audit logging for report generation
- [ ] Implement rate limiting and DDoS protection
- [ ] Add data encryption for sensitive reports

---

# Stage 6: Migration Tools and Backward Compatibility

**Duration**: 1-2 weeks
**Status**: 📋 Planned
**Goal**: Seamless migration from existing AshReports implementation

## 6.1 Migration Utilities

### 6.1.1 Automated Migration Tools
- [ ] Create DSL compatibility analyzer
- [ ] Implement automatic template conversion
- [ ] Add migration validation and testing
- [ ] Create rollback mechanisms
- [ ] Implement gradual migration support

### 6.1.2 Compatibility Layer
- [ ] Maintain API compatibility for existing reports
- [ ] Create adapter pattern for legacy renderers
- [ ] Implement feature parity checking
- [ ] Add deprecation warnings and migration guides
- [ ] Create side-by-side comparison tools

## 6.2 Documentation and Training

### 6.2.1 Comprehensive Documentation
- [ ] Create migration guide from current system
- [ ] Write Typst template development guide
- [ ] Add performance tuning documentation
- [ ] Create troubleshooting guides
- [ ] Implement interactive tutorials

### 6.2.2 Developer Tools
- [ ] Create Typst template debugging tools
- [ ] Add development environment setup scripts
- [ ] Implement template validation CLI tools
- [ ] Create performance profiling utilities
- [ ] Add automated testing helpers

---

# Integration Testing and Validation

## Performance Targets
- **Small reports (1-10 pages)**: 100-500ms total generation
- **Medium reports (10-100 pages)**: 1-10 seconds
- **Large reports (100-1000 pages)**: 10-60 seconds
- **Memory efficiency**: 50-200MB per report
- **Concurrent processing**: 100+ reports on production hardware

## Quality Assurance
- **Feature parity**: All existing AshReports functionality maintained
- **Performance improvement**: 18x faster compilation vs current system
- **Output quality**: Pixel-perfect PDF generation
- **Reliability**: 99.9% uptime with proper monitoring
- **Developer experience**: Hot-reloading, debugging tools, comprehensive docs

## Success Criteria
- [ ] All existing reports render correctly in Typst system
- [ ] Performance targets met or exceeded
- [ ] Production deployment successful with monitoring
- [ ] Developer migration path validated
- [ ] Full backward compatibility maintained during transition period

---

## Architecture Overview

### Current State Analysis
Based on the research document `ash_reports_typst_research.md`, the current AshReports system has:
- Complete DSL framework with Spark extensions
- Four output renderers (HTML, HEEX, PDF, JSON)
- Band-based report structure
- Variable and grouping systems
- Phoenix LiveView integration

### Target State Benefits
The DSL-driven Typst refactor will provide:
- **18x faster compilation** compared to current PDF generation
- **DSL-driven template generation** from AshReports band definitions
- **Enhanced visualizations** with pure Elixir SVG chart generation (Contex/VegaLite)
- **Better developer experience** with declarative report definitions
- **Improved scalability** with streaming and concurrent processing
- **Production-ready deployment** with monitoring and observability

### New Workflow Architecture
```
AshReports DSL Definition
    ↓
reports do
  report :sales_report do
    bands do
      band :title do
        elements do
          label :title_label do
            text "Sales Report"
          end
        end
      end
    end
  end
end
    ↓
DSLGenerator.generate_typst_template(report_definition)
    ↓
Generated Typst Template:
#set page(paper: "a4")
= Sales Report
...
    ↓
BinaryWrapper.compile(template, data)
    ↓
PDF Output (18x faster)
```

### Migration Strategy
1. **Parallel Development**: Build Typst system alongside existing renderers
2. **Gradual Migration**: Implement feature parity before deprecating old system
3. **Compatibility Layer**: Maintain API compatibility during transition
4. **Validation Testing**: Comprehensive testing to ensure output quality
5. **Performance Benchmarking**: Validate performance improvements

### Technical Dependencies
- **Typst 0.1.7** (Elixir package): Rust NIF bindings for Typst compilation ✅ **IMPLEMENTED**
- **AshReports DSL System**: Existing Spark DSL extensions for report definitions ✅ **AVAILABLE**
- **Ash Framework 3.0+**: Resource querying and data transformation ✅ **AVAILABLE**
- **GenStage/Flow**: Stream processing for large datasets (Stage 2) ✅ **IMPLEMENTED**
- **Contex/VegaLite**: Pure Elixir SVG chart generation (Stage 3)
- **Phoenix LiveView**: Enhanced web interface (Stage 4)

### Risk Mitigation
- **Incremental Implementation**: Stage-based approach reduces risk
- **Fallback Mechanisms**: Maintain existing renderers during transition
- **Comprehensive Testing**: Unit, integration, and performance testing
- **Monitoring**: Full observability for production deployment
- **Documentation**: Complete migration guides and troubleshooting

---

**Total Duration**: 11-16 weeks
**Team Requirements**: 2-3 developers with Elixir, TypeScript, and DevOps experience
**Infrastructure Requirements**: Kubernetes cluster, monitoring stack, CI/CD pipeline

**Next Steps**:
1. **✅ Stage 1 COMPLETED**: Infrastructure Foundation and Typst Integration
2. **✅ Stage 2 COMPLETED**: GenStage Streaming Pipeline (95% - core implementation done)
3. **🎯 NEXT PRIORITY**: Stage 3 - Pure Elixir Visualization System
4. Implement Contex/VegaLite chart generation with SVG output
5. Create chart data aggregation pipeline leveraging GenStage streaming
6. Integrate charts into Typst reports via SVG embedding

**Architectural Pivot Complete**: From static template files → Dynamic DSL-driven template generation