# Stage 2 - Section 2.6.1: Unit and Integration Tests for GenStage Streaming Pipeline

**Feature**: Section 2.6.1 of Stage 2 - Comprehensive Testing for Streaming Pipeline
**Status**: 📋 Planned
**Priority**: Critical (Required for production readiness)
**Dependencies**:
  - Stage 2 Section 2.1 (GenStage Infrastructure) ✅ COMPLETED
  - Stage 2 Section 2.2 (Producer Enhancements) ✅ COMPLETED
  - Stage 2 Section 2.3 (Consumer Transformer) ✅ COMPLETED
  - Stage 2 Section 2.4 (DSL-driven Aggregations) ✅ COMPLETED
**Target Completion**: 1 week
**Branch**: `feature/streaming-pipeline-tests`

---

## 📋 Executive Summary

Section 2.6.1 implements comprehensive unit and integration tests for the GenStage streaming pipeline infrastructure. This testing suite validates all critical functionality including demand handling, backpressure, aggregations, DSL-driven configuration, error handling, and recovery mechanisms.

### Problem Statement

The current streaming pipeline implementation has basic tests (located at `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline_test.exs`) that cover:
- Registry operations
- HealthMonitor telemetry
- Supervisor initialization
- Producer configuration options

However, the following critical areas lack comprehensive test coverage:
1. **Producer demand handling and backpressure** - No tests for demand-driven query execution
2. **Consumer backpressure behavior** - No tests for ProducerConsumer backpressure handling
3. **Aggregation functions** - No tests for global and grouped aggregations
4. **DSL-driven aggregation configuration** - No tests for DSL-to-aggregation-config generation
5. **Error handling and recovery** - Limited error scenario coverage
6. **Integration testing** - No end-to-end pipeline tests

### Solution Overview

Create a comprehensive test suite that covers:
- **Unit tests** for each pipeline component (Producer, ProducerConsumer, Registry, HealthMonitor)
- **Integration tests** for complete pipeline flows
- **DSL-driven aggregation tests** validating configuration generation and execution
- **Error handling tests** for failure scenarios and recovery mechanisms
- **Backpressure tests** validating demand management across stages
- **Performance validation tests** ensuring memory and throughput targets are met

### Key Benefits

- **Production Confidence**: Comprehensive test coverage ensures production readiness
- **Regression Prevention**: Catch breaking changes early in development cycle
- **Documentation**: Tests serve as executable documentation for pipeline behavior
- **Maintainability**: Well-tested code is easier to refactor and extend

---

## 🎯 Testing Architecture

### Test Organization

```
test/ash_reports/typst/
├── streaming_pipeline_test.exs                    # EXISTS: Basic infrastructure tests
└── streaming_pipeline/
    ├── producer_test.exs                          # NEW: Producer unit tests
    ├── producer_consumer_test.exs                 # NEW: ProducerConsumer unit tests
    ├── registry_test.exs                          # NEW: Extended registry tests
    ├── health_monitor_test.exs                    # NEW: Extended health monitor tests
    ├── aggregation_test.exs                       # NEW: Aggregation function tests
    ├── dsl_aggregation_test.exs                   # NEW: DSL-driven config tests
    ├── backpressure_test.exs                      # NEW: Backpressure behavior tests
    ├── error_recovery_test.exs                    # NEW: Error handling tests
    └── integration_test.exs                       # NEW: End-to-end pipeline tests
```

### Test Categories

#### 1. Unit Tests
Test individual components in isolation with mocked dependencies.

**Modules to Test**:
- Producer (demand handling, query execution, memory monitoring)
- ProducerConsumer (transformation, aggregations, backpressure)
- Registry (pipeline tracking, status updates)
- HealthMonitor (health checks, telemetry, intervention)

#### 2. Integration Tests
Test complete pipeline flows with real Ash resources and data.

**Scenarios to Test**:
- End-to-end streaming with transformations
- Large dataset processing (10K+ records)
- Concurrent pipelines
- DSL-driven aggregation pipelines
- Error propagation and recovery

#### 3. Backpressure Tests
Test demand management and backpressure behavior across stages.

**Scenarios to Test**:
- Producer respects consumer demand
- ProducerConsumer propagates backpressure
- Buffer management under high load
- Memory-based circuit breakers

#### 4. Error Handling Tests
Test failure scenarios and recovery mechanisms.

**Scenarios to Test**:
- Query failures
- Transformation errors
- Process crashes
- Memory limit violations
- Timeout scenarios

---

## 🔧 Detailed Test Specifications

### 1. Producer Unit Tests (`producer_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/producer_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.ProducerTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline.Producer
  alias AshReports.Typst.StreamingPipeline.Registry

  describe "Producer demand handling" do
    test "produces records based on consumer demand" do
      # Setup: Create producer with test resource
      # Action: Subscribe consumer with demand of 100
      # Assert: Producer emits exactly 100 records
    end

    test "handles demand larger than chunk size" do
      # Setup: Producer with chunk_size of 50
      # Action: Consumer requests 200 records
      # Assert: Producer emits 4 chunks (50 each)
    end

    test "handles demand smaller than chunk size" do
      # Setup: Producer with chunk_size of 100
      # Action: Consumer requests 25 records
      # Assert: Producer emits 25 records (partial chunk)
    end

    test "stops producing when dataset is exhausted" do
      # Setup: Dataset with 150 records, chunk_size of 100
      # Action: Consumer requests 300 records
      # Assert: Producer emits 150 records then stops
    end

    test "accumulates demand across multiple requests" do
      # Setup: Producer ready to serve
      # Action: Consumer makes 3 demand requests (50 each)
      # Assert: Producer serves accumulated demand of 150
    end
  end

  describe "Producer backpressure" do
    test "pauses when pipeline status is :paused" do
      # Setup: Producer with active stream
      # Action: Registry.update_status(stream_id, :paused)
      # Assert: Producer stops emitting events
    end

    test "resumes after being paused" do
      # Setup: Paused producer
      # Action: Registry.update_status(stream_id, :running)
      # Assert: Producer resumes emitting events
    end

    test "implements memory-based circuit breaker" do
      # Setup: Producer with memory_limit of 100MB
      # Action: Memory usage exceeds limit
      # Assert: Producer pauses and emits telemetry warning
    end

    test "exits degraded mode when memory drops" do
      # Setup: Producer in degraded mode
      # Action: Memory usage drops below threshold
      # Assert: Producer returns to normal chunk size
    end
  end

  describe "Producer query execution" do
    test "executes chunked queries with offset/limit" do
      # Setup: Dataset with 500 records, chunk_size of 100
      # Action: Request all records
      # Assert: Verify 5 queries with correct offset/limit
    end

    test "applies relationship loading configuration" do
      # Setup: Producer with load_config
      # Action: Execute query
      # Assert: Verify relationships are loaded per config
    end

    test "retries failed queries with exponential backoff" do
      # Setup: Producer with max_retries of 3
      # Action: Query fails twice then succeeds
      # Assert: Producer retries and eventually succeeds
    end

    test "marks stream as failed after max retries exhausted" do
      # Setup: Producer with max_retries of 3
      # Action: Query fails 4 times
      # Assert: Producer marks stream as :failed
    end
  end

  describe "Producer telemetry" do
    test "emits chunk_fetched event for each chunk" do
      # Setup: Telemetry handler attached
      # Action: Producer fetches 3 chunks
      # Assert: 3 chunk_fetched events emitted
    end

    test "emits completed event when stream finishes" do
      # Setup: Telemetry handler attached
      # Action: Producer completes stream
      # Assert: completed event emitted with metrics
    end

    test "emits error event on query failure" do
      # Setup: Telemetry handler attached
      # Action: Query fails permanently
      # Assert: error event emitted with reason
    end
  end

  describe "Producer cache integration" do
    test "uses cached results when available" do
      # Setup: Producer with enable_cache: true
      # Action: Request same chunk twice
      # Assert: Second request uses cache (no query)
    end

    test "bypasses cache when disabled" do
      # Setup: Producer with enable_cache: false
      # Action: Request same chunk twice
      # Assert: Both requests execute query
    end
  end
end
```

**Total Test Cases**: 18

---

### 2. ProducerConsumer Unit Tests (`producer_consumer_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/producer_consumer_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.ProducerConsumerTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline.ProducerConsumer

  describe "ProducerConsumer transformation" do
    test "transforms records using DataProcessor" do
      # Setup: ProducerConsumer with transformation_opts
      # Action: Send events with Ash structs
      # Assert: Emits transformed typst-compatible maps
    end

    test "applies custom transformer function" do
      # Setup: ProducerConsumer with transformer: fn
      # Action: Send events
      # Assert: Custom transformer is applied to each record
    end

    test "handles transformation errors gracefully" do
      # Setup: Transformer that fails for specific records
      # Action: Send batch with mix of valid/invalid records
      # Assert: Invalid records are skipped, valid ones processed
    end

    test "increments failed_count for transformation errors" do
      # Setup: Telemetry handler attached
      # Action: Send batch with failing transformations
      # Assert: batch_transformed event shows failed_count
    end
  end

  describe "ProducerConsumer global aggregations" do
    test "computes sum aggregation across all records" do
      # Setup: ProducerConsumer with aggregations: [:sum]
      # Action: Send records with numeric fields
      # Assert: aggregation_state.sum contains correct totals
    end

    test "computes count aggregation" do
      # Setup: ProducerConsumer with aggregations: [:count]
      # Action: Send 150 records in 3 batches
      # Assert: aggregation_state.count equals 150
    end

    test "computes avg aggregation" do
      # Setup: ProducerConsumer with aggregations: [:avg]
      # Action: Send records with numeric values
      # Assert: aggregation_state.avg calculated correctly
    end

    test "computes min/max aggregations" do
      # Setup: ProducerConsumer with aggregations: [:min, :max]
      # Action: Send records with varying values
      # Assert: min/max values tracked correctly
    end

    test "computes running_total aggregation" do
      # Setup: ProducerConsumer with aggregations: [:running_total]
      # Action: Send records incrementally
      # Assert: running_total updates per batch
    end

    test "handles multiple aggregations simultaneously" do
      # Setup: ProducerConsumer with all aggregation types
      # Action: Send records
      # Assert: All aggregations computed correctly
    end
  end

  describe "ProducerConsumer grouped aggregations" do
    test "groups records by single field" do
      # Setup: grouped_aggregations: [%{group_by: :territory, aggregations: [:sum]}]
      # Action: Send records with different territories
      # Assert: Separate aggregations per territory
    end

    test "groups records by multiple fields" do
      # Setup: group_by: [:territory, :product_category]
      # Action: Send records with combinations
      # Assert: Aggregations for each unique combination
    end

    test "enforces max_groups limit per configuration" do
      # Setup: grouped_aggregations with max_groups: 100
      # Action: Send records creating 150 unique groups
      # Assert: Only 100 groups created, 50 records rejected
    end

    test "emits group_limit_reached telemetry event" do
      # Setup: Telemetry handler, max_groups: 10
      # Action: Send records exceeding limit
      # Assert: group_limit_reached event emitted
    end

    test "handles multiple grouped aggregation configs" do
      # Setup: 3 different grouped_aggregation configs
      # Action: Send records
      # Assert: All configs compute independently
    end

    test "tracks rejected_count for group limit violations" do
      # Setup: Grouped aggregation with limit
      # Action: Exceed limit
      # Assert: batch_transformed shows rejected_count
    end
  end

  describe "ProducerConsumer backpressure" do
    test "respects max_demand from subscription" do
      # Setup: ProducerConsumer with max_demand: 50
      # Action: Producer sends 200 records
      # Assert: ProducerConsumer requests in chunks of 50
    end

    test "buffers events when downstream is slow" do
      # Setup: Slow consumer downstream
      # Action: Producer sends events quickly
      # Assert: ProducerConsumer buffers up to buffer_size
    end

    test "emits buffer_full telemetry when near capacity" do
      # Setup: Telemetry handler, buffer_size: 100
      # Action: Fill buffer to 85%
      # Assert: buffer_full event emitted
    end
  end

  describe "ProducerConsumer telemetry" do
    test "emits batch_transformed event with metrics" do
      # Setup: Telemetry handler attached
      # Action: Process batch
      # Assert: Event includes records_in, records_out, duration_ms
    end

    test "emits aggregation_computed event" do
      # Setup: Telemetry handler, aggregations enabled
      # Action: Process batch
      # Assert: Event includes aggregation state
    end

    test "emits throughput metric to HealthMonitor" do
      # Setup: HealthMonitor telemetry handler
      # Action: Process batch
      # Assert: Throughput metric emitted
    end
  end
end
```

**Total Test Cases**: 20

---

### 3. Aggregation Function Tests (`aggregation_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/aggregation_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.AggregationTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.StreamingPipeline.ProducerConsumer

  describe "Global aggregation functions" do
    test "sum aggregation accumulates across batches" do
      # Setup: Records with amount field in 3 batches
      # Action: Process all batches
      # Assert: Sum is cumulative across batches
    end

    test "count aggregation counts all records" do
      # Setup: 3 batches with different sizes
      # Action: Process all batches
      # Assert: Count equals total records
    end

    test "avg aggregation computes correct average" do
      # Setup: Records with known average
      # Action: Process in batches
      # Assert: Average is correct
    end

    test "min aggregation tracks minimum value" do
      # Setup: Records with varying values
      # Action: Process batches
      # Assert: Minimum is correct
    end

    test "max aggregation tracks maximum value" do
      # Setup: Records with varying values
      # Action: Process batches
      # Assert: Maximum is correct
    end

    test "running_total maintains running sum" do
      # Setup: Records in sequence
      # Action: Process batches
      # Assert: Running total updates correctly
    end

    test "handles multiple numeric fields in aggregations" do
      # Setup: Records with amount, quantity, price
      # Action: Process with sum aggregation
      # Assert: Each field aggregated separately
    end

    test "ignores non-numeric fields in aggregations" do
      # Setup: Records with string, date, numeric fields
      # Action: Process with sum aggregation
      # Assert: Only numeric fields aggregated
    end
  end

  describe "Grouped aggregation functions" do
    test "groups by single field with sum" do
      # Setup: Sales by territory
      # Action: Process records
      # Assert: Sum per territory correct
    end

    test "groups by multiple fields" do
      # Setup: Sales by territory + product
      # Action: Process records
      # Assert: Correct grouping by tuple
    end

    test "applies multiple aggregations per group" do
      # Setup: group_by: :territory, aggregations: [:sum, :count, :avg]
      # Action: Process records
      # Assert: All aggregations correct per group
    end

    test "handles sparse groups correctly" do
      # Setup: Some groups with 1 record, others with many
      # Action: Process records
      # Assert: All groups computed correctly
    end

    test "maintains group state across batches" do
      # Setup: Records for same group in different batches
      # Action: Process batches
      # Assert: Groups accumulated across batches
    end

    test "enforces max_groups limit" do
      # Setup: max_groups: 5
      # Action: Send records creating 10 groups
      # Assert: Only 5 groups, rest rejected
    end

    test "uses default max_groups when not specified" do
      # Setup: No max_groups in config
      # Action: Create many groups
      # Assert: Defaults to 10,000
    end
  end

  describe "Aggregation edge cases" do
    test "handles empty batches" do
      # Setup: Aggregation config
      # Action: Process empty batch
      # Assert: Aggregation state unchanged
    end

    test "handles nil values in numeric fields" do
      # Setup: Records with nil amounts
      # Action: Process with sum
      # Assert: Nils ignored, sum correct
    end

    test "handles records with missing fields" do
      # Setup: Aggregation on :amount, some records lack it
      # Action: Process records
      # Assert: Only records with field counted
    end

    test "handles zero values correctly" do
      # Setup: Records with zero amounts
      # Action: Process with sum/avg
      # Assert: Zeros included in calculations
    end
  end
end
```

**Total Test Cases**: 23

---

### 4. DSL-Driven Aggregation Tests (`dsl_aggregation_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/dsl_aggregation_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.DslAggregationTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.DataLoader
  # Module that generates aggregation config from DSL (to be determined)
  # This tests Section 2.4 integration

  describe "DSL to aggregation config generation" do
    test "generates global aggregations from report DSL" do
      # Setup: Report DSL with aggregate expressions
      # Action: Generate aggregation config
      # Assert: Config contains correct global aggregations
    end

    test "generates grouped aggregations from group bands" do
      # Setup: Report with group_by bands
      # Action: Generate aggregation config
      # Assert: Config contains grouped_aggregations
    end

    test "infers aggregation types from expressions" do
      # Setup: Report with SUM(), COUNT(), AVG() expressions
      # Action: Parse DSL
      # Assert: Aggregation types correctly inferred
    end

    test "extracts group_by fields from DSL" do
      # Setup: Report with group headers
      # Action: Parse DSL
      # Assert: group_by fields extracted correctly
    end

    test "sets max_groups based on report configuration" do
      # Setup: Report with max_groups directive
      # Action: Generate config
      # Assert: max_groups respected in config
    end

    test "handles nested grouping levels" do
      # Setup: Report with territory > customer grouping
      # Action: Generate config
      # Assert: Multiple grouped_aggregation configs
    end
  end

  describe "DSL-driven pipeline execution" do
    test "creates pipeline with DSL-generated aggregations" do
      # Setup: Report with aggregations defined in DSL
      # Action: Start streaming pipeline
      # Assert: ProducerConsumer has correct aggregation config
    end

    test "streams and aggregates data according to DSL" do
      # Setup: Sales report with territory grouping
      # Action: Stream 1000 records
      # Assert: Aggregations match DSL expectations
    end

    test "handles complex DSL aggregation expressions" do
      # Setup: Report with SUM(amount * quantity) type expressions
      # Action: Stream and process
      # Assert: Complex expressions evaluated correctly
    end
  end

  describe "DSL validation" do
    test "validates aggregation expressions during config gen" do
      # Setup: Report with invalid aggregation syntax
      # Action: Attempt config generation
      # Assert: Error raised with helpful message
    end

    test "validates group_by field existence" do
      # Setup: Report grouping by non-existent field
      # Action: Attempt config generation
      # Assert: Validation error raised
    end
  end
end
```

**Total Test Cases**: 11

---

### 5. Backpressure Behavior Tests (`backpressure_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/backpressure_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.BackpressureTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline

  describe "Producer-to-ProducerConsumer backpressure" do
    test "producer waits for consumer demand" do
      # Setup: Producer with data, slow consumer
      # Action: Monitor producer behavior
      # Assert: Producer doesn't emit without demand
    end

    test "producer respects max_demand limit" do
      # Setup: Consumer with max_demand: 50
      # Action: Producer has 500 records
      # Assert: Producer emits in chunks of ≤50
    end

    test "producer handles consumer pause" do
      # Setup: Active pipeline
      # Action: Pause via Registry
      # Assert: Producer stops emitting
    end

    test "producer resumes after consumer ready" do
      # Setup: Paused producer
      # Action: Resume via Registry
      # Assert: Producer continues emitting
    end
  end

  describe "ProducerConsumer-to-Consumer backpressure" do
    test "producer consumer waits for downstream demand" do
      # Setup: ProducerConsumer with slow downstream
      # Action: Monitor behavior
      # Assert: ProducerConsumer buffers but doesn't overflow
    end

    test "producer consumer respects buffer_size" do
      # Setup: buffer_size: 100
      # Action: Fast producer, slow consumer
      # Assert: Buffer doesn't exceed 100
    end

    test "emits buffer_full warning when approaching limit" do
      # Setup: Telemetry handler
      # Action: Fill buffer to 85%
      # Assert: Warning emitted
    end
  end

  describe "Memory-based backpressure" do
    test "producer pauses when memory limit reached" do
      # Setup: Producer with memory_limit
      # Action: Memory usage exceeds limit
      # Assert: Producer pauses emission
    end

    test "producer enters degraded mode under memory pressure" do
      # Setup: Producer with memory_limit
      # Action: Memory at 85% of limit
      # Assert: Producer reduces chunk_size
    end

    test "health monitor triggers circuit breaker on memory" do
      # Setup: HealthMonitor monitoring pipeline
      # Action: Memory exceeds threshold
      # Assert: Pipeline paused via Registry
    end
  end

  describe "End-to-end backpressure flow" do
    test "backpressure propagates through entire pipeline" do
      # Setup: Complete pipeline with slow final consumer
      # Action: Monitor all stages
      # Assert: Backpressure visible at all stages
    end

    test "pipeline maintains bounded memory under load" do
      # Setup: Pipeline streaming 100K records
      # Action: Monitor memory usage
      # Assert: Memory stays within 1.5x baseline
    end
  end
end
```

**Total Test Cases**: 13

---

### 6. Error Handling and Recovery Tests (`error_recovery_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/error_recovery_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.ErrorRecoveryTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline

  describe "Producer error handling" do
    test "retries failed queries with exponential backoff" do
      # Setup: Producer with max_retries: 3
      # Action: Query fails twice, succeeds third time
      # Assert: Producer retries with backoff, succeeds
    end

    test "marks stream as failed after max retries" do
      # Setup: Producer with max_retries: 3
      # Action: Query fails 4 times
      # Assert: Registry shows status: :failed
    end

    test "emits error telemetry on permanent failure" do
      # Setup: Telemetry handler
      # Action: Producer fails permanently
      # Assert: Error event emitted with reason
    end

    test "cleans up resources on failure" do
      # Setup: Producer with cache enabled
      # Action: Producer fails
      # Assert: Resources cleaned up
    end
  end

  describe "ProducerConsumer error handling" do
    test "skips records with transformation errors" do
      # Setup: Transformer that fails for specific records
      # Action: Send mixed batch
      # Assert: Valid records processed, invalid skipped
    end

    test "logs transformation errors" do
      # Setup: Log capture enabled
      # Action: Transformation fails
      # Assert: Error logged with details
    end

    test "continues processing after transformation errors" do
      # Setup: ProducerConsumer processing stream
      # Action: Some transformations fail
      # Assert: Stream continues, doesn't crash
    end

    test "emits telemetry for transformation failures" do
      # Setup: Telemetry handler
      # Action: Transformations fail
      # Assert: batch_transformed shows failed_count
    end
  end

  describe "Process crash recovery" do
    test "registry detects producer crash" do
      # Setup: Pipeline with producer
      # Action: Kill producer process
      # Assert: Registry marks stream as :failed
    end

    test "registry detects producer_consumer crash" do
      # Setup: Pipeline with producer_consumer
      # Action: Kill producer_consumer
      # Assert: Registry updates status
    end

    test "supervisor restarts crashed producer" do
      # Setup: Pipeline under supervision
      # Action: Producer crashes with recoverable error
      # Assert: Supervisor restarts producer
    end

    test "stops restart loop after max_restarts" do
      # Setup: Producer that crashes immediately
      # Action: Trigger restart loop
      # Assert: Supervisor gives up after max_restarts
    end
  end

  describe "Health monitor intervention" do
    test "kills stream exceeding memory limit" do
      # Setup: HealthMonitor with memory threshold
      # Action: Stream exceeds critical memory (95%)
      # Assert: HealthMonitor kills stream
    end

    test "marks stalled streams as failed" do
      # Setup: HealthMonitor with stall_timeout
      # Action: Stream hasn't updated in 30s
      # Assert: Marked as :failed
    end

    test "emits intervention telemetry" do
      # Setup: Telemetry handler
      # Action: HealthMonitor intervenes
      # Assert: Intervention event emitted
    end
  end

  describe "Error recovery scenarios" do
    test "recovers from transient database errors" do
      # Setup: Database fails once then recovers
      # Action: Pipeline streaming
      # Assert: Pipeline retries and continues
    end

    test "handles network timeouts gracefully" do
      # Setup: Producer with timeout config
      # Action: Query times out
      # Assert: Error handled, retry attempted
    end

    test "handles resource exhaustion" do
      # Setup: System running low on memory
      # Action: Pipeline tries to start
      # Assert: Graceful failure with clear error
    end
  end
end
```

**Total Test Cases**: 19

---

### 7. Integration Tests (`integration_test.exs`)

**File**: `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline/integration_test.exs`

#### Test Cases

```elixir
defmodule AshReports.Typst.StreamingPipeline.IntegrationTest do
  use ExUnit.Case, async: false

  alias AshReports.Typst.StreamingPipeline
  alias AshReports.Typst.DataLoader

  # Setup test resources and domains
  setup do
    # Create test domain with sample data
    # Seed database with test records
    :ok
  end

  describe "End-to-end pipeline flow" do
    test "streams complete dataset successfully" do
      # Setup: 1000 test records
      # Action: Start pipeline and consume all
      # Assert: All 1000 records received and transformed
    end

    test "applies transformations correctly" do
      # Setup: Records with various data types
      # Action: Stream through pipeline
      # Assert: Transformations applied per DataProcessor
    end

    test "handles relationships in streamed data" do
      # Setup: Records with belongs_to, has_many relationships
      # Action: Stream with load_config
      # Assert: Relationships loaded correctly
    end

    test "maintains record order during streaming" do
      # Setup: Ordered dataset
      # Action: Stream all records
      # Assert: Order preserved
    end
  end

  describe "Large dataset processing" do
    test "streams 10K records with constant memory" do
      # Setup: 10K test records
      # Action: Stream all, monitor memory
      # Assert: Memory stays within 1.5x baseline
    end

    test "streams 100K records efficiently" do
      # Setup: 100K test records
      # Action: Stream all, measure throughput
      # Assert: Throughput >1000 records/sec
    end

    test "handles million-record datasets" do
      # Setup: 1M test records (if feasible in test env)
      # Action: Stream sample chunks
      # Assert: Pipeline performs correctly
    end
  end

  describe "Concurrent pipeline operations" do
    test "runs multiple pipelines concurrently" do
      # Setup: 5 different reports
      # Action: Start 5 pipelines simultaneously
      # Assert: All complete successfully
    end

    test "maintains isolation between concurrent streams" do
      # Setup: 2 pipelines with different configs
      # Action: Run concurrently
      # Assert: Configs don't interfere
    end

    test "handles concurrent memory pressure" do
      # Setup: Multiple pipelines
      # Action: Run concurrently
      # Assert: Memory management works across all
    end
  end

  describe "DSL-driven aggregation pipelines" do
    test "executes global aggregations from DSL" do
      # Setup: Report with SUM, COUNT expressions
      # Action: Stream 1000 records
      # Assert: Aggregations computed correctly
    end

    test "executes grouped aggregations from DSL" do
      # Setup: Sales report grouped by territory
      # Action: Stream sales data
      # Assert: Per-territory aggregations correct
    end

    test "handles complex multi-level grouping" do
      # Setup: Report with territory > customer grouping
      # Action: Stream sales data
      # Assert: All grouping levels correct
    end

    test "respects max_groups from DSL configuration" do
      # Setup: DSL with max_groups: 100
      # Action: Stream data creating 150 groups
      # Assert: Only 100 groups created
    end
  end

  describe "DataLoader integration" do
    test "DataLoader.stream_for_typst creates pipeline" do
      # Setup: Report configuration
      # Action: Call DataLoader.stream_for_typst
      # Assert: Pipeline created and stream returned
    end

    test "streamed data compatible with Typst templates" do
      # Setup: Streaming pipeline
      # Action: Consume stream
      # Assert: Data format matches Typst expectations
    end

    test "handles cancellation mid-stream" do
      # Setup: Active pipeline
      # Action: Stop pipeline after 500 records
      # Assert: Pipeline stops cleanly, resources cleaned
    end
  end

  describe "Performance validation" do
    test "maintains constant memory for any dataset size" do
      # Setup: Datasets of 1K, 10K, 100K
      # Action: Stream each, measure memory
      # Assert: Memory growth is <1.5x baseline for all
    end

    test "achieves target throughput" do
      # Setup: 10K record dataset
      # Action: Stream and measure time
      # Assert: Throughput >1000 records/sec
    end

    test "startup latency is acceptable" do
      # Setup: Pipeline configuration
      # Action: Measure time to first record
      # Assert: Latency <100ms
    end
  end

  describe "Error propagation in pipeline" do
    test "query errors stop pipeline gracefully" do
      # Setup: Invalid query
      # Action: Start pipeline
      # Assert: Error propagated, resources cleaned
    end

    test "transformation errors skip records" do
      # Setup: Some records cause transformer to fail
      # Action: Stream dataset
      # Assert: Valid records processed, invalid skipped
    end

    test "consumer errors don't crash pipeline" do
      # Setup: Consumer that errors on specific record
      # Action: Stream data
      # Assert: Error handled gracefully
    end
  end
end
```

**Total Test Cases**: 25

---

## 📁 Test Support Modules

### Test Fixtures

Create reusable test fixtures for consistent testing:

```elixir
# test/support/streaming_fixtures.ex

defmodule AshReports.StreamingFixtures do
  @moduledoc """
  Fixtures for streaming pipeline tests.
  """

  def sample_records(count, opts \\ []) do
    # Generate sample records for testing
  end

  def sales_records_by_territory(territories, records_per_territory) do
    # Generate sales data grouped by territory
  end

  def records_with_relationships(count) do
    # Generate records with loaded relationships
  end

  def create_test_report(aggregation_config) do
    # Create report with specified aggregations
  end
end
```

### Test Helpers

```elixir
# test/support/streaming_helpers.ex

defmodule AshReports.StreamingHelpers do
  @moduledoc """
  Helper functions for streaming tests.
  """

  def start_test_pipeline(opts) do
    # Start pipeline with test configuration
  end

  def consume_stream_with_monitoring(stream) do
    # Consume stream while monitoring memory/throughput
  end

  def assert_aggregations(aggregation_state, expected) do
    # Assert aggregation state matches expectations
  end

  def measure_memory_usage(fun) do
    # Measure memory usage of function execution
  end

  def measure_throughput(stream, record_count) do
    # Measure records per second throughput
  end
end
```

### Test Resources

```elixir
# test/support/test_resources.ex

defmodule AshReports.TestResource.Sale do
  use Ash.Resource, domain: AshReports.TestDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :territory, :string
    attribute :customer_name, :string
    attribute :amount, :decimal
    attribute :quantity, :integer
    attribute :sale_date, :date
  end

  relationships do
    belongs_to :customer, AshReports.TestResource.Customer
    belongs_to :product, AshReports.TestResource.Product
  end
end

defmodule AshReports.TestResource.Customer do
  use Ash.Resource, domain: AshReports.TestDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :territory, :string
  end

  relationships do
    has_many :sales, AshReports.TestResource.Sale
  end
end

defmodule AshReports.TestDomain do
  use Ash.Domain

  resources do
    resource AshReports.TestResource.Sale
    resource AshReports.TestResource.Customer
    resource AshReports.TestResource.Product
  end
end
```

---

## 📋 Implementation Plan

### Phase 1: Test Infrastructure (Days 1-2)

**Goal**: Set up test support modules and fixtures

#### Tasks:
- [ ] Create `test/support/streaming_fixtures.ex` with sample data generators
- [ ] Create `test/support/streaming_helpers.ex` with test utilities
- [ ] Create `test/support/test_resources.ex` with Ash test resources
- [ ] Set up test database with seed data for integration tests
- [ ] Create shared test setup in `test/test_helper.exs`

**Deliverables**: Reusable test infrastructure ready for use

---

### Phase 2: Producer Unit Tests (Days 2-3)

**Goal**: Comprehensive Producer testing

#### Tasks:
- [ ] Create `test/ash_reports/typst/streaming_pipeline/producer_test.exs`
- [ ] Implement 18 test cases covering:
  - Demand handling (5 tests)
  - Backpressure (4 tests)
  - Query execution (4 tests)
  - Telemetry (3 tests)
  - Cache integration (2 tests)
- [ ] Ensure all tests pass
- [ ] Verify test coverage >90% for Producer module

**Deliverables**: 18 passing Producer unit tests

---

### Phase 3: ProducerConsumer Unit Tests (Days 3-4)

**Goal**: Comprehensive ProducerConsumer testing

#### Tasks:
- [ ] Create `test/ash_reports/typst/streaming_pipeline/producer_consumer_test.exs`
- [ ] Implement 20 test cases covering:
  - Transformation (4 tests)
  - Global aggregations (6 tests)
  - Grouped aggregations (6 tests)
  - Backpressure (3 tests)
  - Telemetry (3 tests)
- [ ] Ensure all tests pass
- [ ] Verify test coverage >90% for ProducerConsumer module

**Deliverables**: 20 passing ProducerConsumer unit tests

---

### Phase 4: Aggregation Function Tests (Day 4)

**Goal**: Validate aggregation logic

#### Tasks:
- [ ] Create `test/ash_reports/typst/streaming_pipeline/aggregation_test.exs`
- [ ] Implement 23 test cases covering:
  - Global aggregations (8 tests)
  - Grouped aggregations (7 tests)
  - Edge cases (8 tests)
- [ ] Test all aggregation types (sum, count, avg, min, max, running_total)
- [ ] Verify accuracy of aggregation calculations

**Deliverables**: 23 passing aggregation tests

---

### Phase 5: DSL-Driven Aggregation Tests (Day 5)

**Goal**: Test Section 2.4 integration

#### Tasks:
- [ ] Create `test/ash_reports/typst/streaming_pipeline/dsl_aggregation_test.exs`
- [ ] Implement 11 test cases covering:
  - DSL config generation (6 tests)
  - Pipeline execution (2 tests)
  - Validation (3 tests)
- [ ] Test integration with expression parser
- [ ] Verify DSL-driven pipelines work end-to-end

**Deliverables**: 11 passing DSL aggregation tests

---

### Phase 6: Backpressure and Error Handling Tests (Day 6)

**Goal**: Test failure scenarios and backpressure

#### Tasks:
- [ ] Create `test/ash_reports/typst/streaming_pipeline/backpressure_test.exs`
- [ ] Implement 13 backpressure test cases
- [ ] Create `test/ash_reports/typst/streaming_pipeline/error_recovery_test.exs`
- [ ] Implement 19 error handling test cases
- [ ] Test all failure scenarios and recovery paths

**Deliverables**: 32 passing backpressure and error tests

---

### Phase 7: Integration Tests (Days 6-7)

**Goal**: End-to-end pipeline testing

#### Tasks:
- [ ] Create `test/ash_reports/typst/streaming_pipeline/integration_test.exs`
- [ ] Implement 25 integration test cases covering:
  - End-to-end flow (4 tests)
  - Large datasets (3 tests)
  - Concurrent operations (3 tests)
  - DSL-driven pipelines (4 tests)
  - DataLoader integration (3 tests)
  - Performance validation (3 tests)
  - Error propagation (3 tests)
- [ ] Test with realistic data volumes
- [ ] Validate performance targets

**Deliverables**: 25 passing integration tests

---

### Phase 8: Documentation and Review (Day 7)

**Goal**: Document tests and finalize

#### Tasks:
- [ ] Add comprehensive test documentation
- [ ] Document test fixtures and helpers usage
- [ ] Create testing guide for future developers
- [ ] Review all test code for clarity
- [ ] Run full test suite and verify all pass
- [ ] Generate test coverage report
- [ ] Update this planning document with results

**Deliverables**: Complete, documented test suite

---

## ✅ Success Criteria

### Test Coverage
- [ ] Overall test coverage >90% for all streaming modules
- [ ] Producer module coverage >90%
- [ ] ProducerConsumer module coverage >90%
- [ ] Registry module coverage >90%
- [ ] HealthMonitor module coverage >90%

### Test Quality
- [ ] All 150+ tests passing consistently
- [ ] No flaky tests (all tests pass 10 runs in a row)
- [ ] Test execution time <30 seconds for full suite
- [ ] Clear, descriptive test names
- [ ] Comprehensive test documentation

### Functional Coverage
- [ ] All demand handling scenarios tested
- [ ] All backpressure behaviors validated
- [ ] All aggregation functions verified
- [ ] DSL-driven configuration tested
- [ ] All error scenarios covered
- [ ] Recovery mechanisms validated

### Performance Validation
- [ ] Memory usage tests confirm <1.5x baseline
- [ ] Throughput tests confirm >1000 records/sec
- [ ] Latency tests confirm <100ms startup
- [ ] Concurrent pipeline tests pass

### Integration
- [ ] DataLoader integration tested
- [ ] DSL parser integration tested
- [ ] DataProcessor integration tested
- [ ] Complete pipeline flows validated

---

## 📊 Test Count Summary

| Test Module | Test Cases | Focus Area |
|------------|-----------|-----------|
| producer_test.exs | 18 | Producer demand, backpressure, queries |
| producer_consumer_test.exs | 20 | Transformation, aggregations |
| aggregation_test.exs | 23 | Aggregation functions accuracy |
| dsl_aggregation_test.exs | 11 | DSL integration |
| backpressure_test.exs | 13 | Backpressure propagation |
| error_recovery_test.exs | 19 | Error handling, recovery |
| integration_test.exs | 25 | End-to-end scenarios |
| **Total New Tests** | **129** | |
| **Existing Tests** | **~20** | Registry, HealthMonitor, Supervisor |
| **Grand Total** | **~150** | |

---

## 🔗 Integration Points

### Upstream Dependencies
- **Section 2.1** (GenStage Infrastructure): Core components to test
- **Section 2.2** (Producer Enhancements): Advanced features to validate
- **Section 2.3** (Consumer Transformer): Transformation logic to test
- **Section 2.4** (DSL Aggregations): Config generation to integrate

### Downstream Consumers
- **Production Deployment**: Tests provide confidence for production use
- **Future Features**: Test suite serves as regression prevention
- **Documentation**: Tests demonstrate usage patterns

---

## 💡 Testing Best Practices

### GenStage Testing Patterns

Based on research and official patterns:

1. **Test Producers**: Create test consumers that send received events to test process via messages
2. **Test Consumers**: Create test producers using GenStage.BroadcastDispatcher
3. **Test ProducerConsumers**: Test both consumer and producer aspects independently
4. **Verify Demand**: Always verify demand handling and max_demand respect
5. **Test Backpressure**: Simulate slow consumers and verify buffering behavior

### Elixir/OTP Best Practices

1. **Use ExUnit async: false**: For GenStage tests due to process dependencies
2. **Capture Telemetry**: Use telemetry handlers to verify events
3. **Monitor Memory**: Use :erlang.memory/1 for memory assertions
4. **Test Process Death**: Use spawn_monitor and assert DOWN messages
5. **Test Timeouts**: Use assert_receive with timeout for async behavior

### Test Organization

1. **One behavior per test**: Each test verifies one specific behavior
2. **Descriptive names**: Test names describe the scenario and expected outcome
3. **Arrange-Act-Assert**: Follow AAA pattern consistently
4. **Shared setup**: Use setup blocks for common test preparation
5. **Test helpers**: Extract common assertions into helper functions

---

## 📚 References

### GenStage Testing Resources
- [GenStage Official Tests](https://github.com/elixir-lang/gen_stage/blob/main/test/gen_stage_test.exs) - Official test examples
- [Testing GenStage Producers](https://elixirforum.com/t/unit-testing-a-genstage-producer/3398) - Community patterns
- [Testing GenStage Consumers](https://stackoverflow.com/questions/50617217/how-to-test-the-elixir-genstage-consumer) - Consumer testing approaches

### Existing Codebase
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline.ex` - Main module to test
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline/producer.ex` - Producer implementation
- `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex` - ProducerConsumer implementation
- `/home/ducky/code/ash_reports/test/ash_reports/typst/streaming_pipeline_test.exs` - Existing basic tests

### Planning Documents
- `/home/ducky/code/ash_reports/notes/features/stage2_section2.1_genstage_infrastructure.md` - Infrastructure plan
- Section 2.4 DSL Aggregation plan (referenced but not yet reviewed in detail)

---

## ✅ Definition of Done

Section 2.6.1 is complete when:

- [ ] All 7 test files created with comprehensive test cases
- [ ] Minimum 129 new tests implemented and passing
- [ ] Test coverage >90% for all streaming modules
- [ ] All tests pass consistently (10 consecutive runs)
- [ ] Test fixtures and helpers documented
- [ ] Testing guide created for future developers
- [ ] Performance validation tests pass
- [ ] Integration tests validate complete flows
- [ ] DSL integration tests verify Section 2.4 compatibility
- [ ] Error handling tests cover all failure scenarios
- [ ] Code review completed and approved
- [ ] This planning document updated with actual results

---

**Document Version**: 1.0
**Created**: 2025-10-02
**Status**: Ready for Review and Implementation

**Next Action**: Review this plan with Pascal, confirm approach, and begin Phase 1 implementation.
