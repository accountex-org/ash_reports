# Stage 2.5.1: API Implementation - Feature Planning Document

**Status**: 🔄 In Planning
**Section**: 2.5.1 API Implementation (from planning/typst_refactor_plan.md)
**Dependencies**: Sections 2.1-2.4 (Complete ✅)
**Estimated Duration**: 3-5 days

---

## Problem Statement

Section 2.5.1 "API Implementation" from the Typst Refactor Plan has specific requirements that are only partially complete. While the core streaming infrastructure exists and `create_streaming_pipeline/4` has been implemented in `lib/ash_reports/typst/data_loader.ex` (lines 267-305), several critical API features are missing:

### What Exists (Already Complete) ✅

1. **`create_streaming_pipeline/4` function** (lines 267-305)
   - Builds Ash query from report definition
   - Creates transformer function for DataProcessor integration
   - Integrates `build_grouped_aggregations_from_dsl/1` (Section 2.4)
   - Calls `StreamingPipeline.start_pipeline/1` with full configuration
   - Returns stream for consumption

2. **DSL Integration** (Section 2.4 complete)
   - `build_grouped_aggregations_from_dsl/1` parses report groups
   - Cumulative grouping configuration (Level 1: `:territory`, Level 2: `[:territory, :customer_name]`)
   - Variable-to-aggregation mapping (`:sum`, `:count`, `:avg`, `:min`, `:max`)
   - 17 integration tests validating DSL parsing

3. **StreamingPipeline Infrastructure** (Sections 2.1-2.3 complete)
   - Producer (chunk-based Ash query execution)
   - ProducerConsumer (transformation + aggregations)
   - Registry (pipeline tracking)
   - HealthMonitor (telemetry and health checks)
   - Supervisor (process management)

### What's Missing (Gaps) ❌

According to Section 2.5.1 requirements:

1. **Streaming configuration options** - Limited configuration exposed to users
2. **Unified API for batch vs. streaming modes** - No automatic mode selection
3. **API usage patterns and examples documentation** - Minimal documentation
4. **Stream control features** (from Section 2.5.3) - Pause/resume/cancel not exposed at DataLoader level
5. **Automatic mode selection** (from Section 2.5.2) - No dataset size detection or fallback
6. **Error handling improvements** - Stream-specific error handling could be enhanced

### Key Gap Analysis

The **core technical implementation is complete**, but the **user-facing API is incomplete**:

- Developers calling `stream_for_typst/4` have no control over chunk size, max_demand, or aggregation options
- No guidance on when to use batch (`load_for_typst/4`) vs. streaming (`stream_for_typst/4`)
- No way to pause, resume, or cancel streams from the DataLoader API
- No automatic detection: "Should I stream or batch this 500-record dataset?"

---

## Solution Overview

Complete the user-facing API layer for streaming pipelines by:

1. **Enhance Configuration Options** - Expose streaming controls through `stream_for_typst/4` options
2. **Create Unified Batch/Streaming API** - Add automatic mode selection with `load_report_data/4`
3. **Add Stream Control Methods** - Expose pause/resume/cancel at DataLoader level
4. **Improve Documentation** - Add comprehensive examples and usage patterns
5. **Add Helper Functions** - Create utilities for common streaming scenarios

This completes Section 2.5.1 requirements while maintaining backward compatibility.

---

## Technical Details

### 1. Enhanced Streaming Configuration

**Goal**: Allow users to customize streaming behavior through options.

**Current State**: `stream_for_typst/4` accepts options but only passes limited config to pipeline.

**Required Changes**:

```elixir
# lib/ash_reports/typst/data_loader.ex

@doc """
Streams large datasets for memory-efficient Typst compilation.

## Options

- `:chunk_size` - Records per producer chunk (default: 500)
- `:max_demand` - Max demand for backpressure (default: 1000)
- `:buffer_size` - ProducerConsumer buffer size (default: 1000)
- `:enable_telemetry` - Enable telemetry events (default: true)
- `:aggregations` - Global aggregation functions (default: [])
- `:grouped_aggregations` - Grouped aggregation configs (default: auto from DSL)
- `:memory_limit` - Memory limit per stream in bytes (default: 500MB)
- `:preload_strategy` - Relationship preloading (:auto | :eager | :lazy, default: :auto)
- `:timeout` - Pipeline timeout in ms (default: :infinity)

## Examples

    # Basic streaming
    {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :sales_report, params)

    # Custom chunk size for faster throughput
    {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :large_report, params,
      chunk_size: 2000,
      max_demand: 5000
    )

    # Override DSL-inferred aggregations
    {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params,
      aggregations: [:sum, :count, :avg],
      grouped_aggregations: [
        %{group_by: :region, aggregations: [:sum, :count]}
      ]
    )

    # Memory-constrained environment
    {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params,
      memory_limit: 100_000_000,  # 100MB
      chunk_size: 100
    )
"""
@spec stream_for_typst(module(), atom(), map(), load_options()) ::
        {:ok, Enumerable.t()} | {:error, term()}
def stream_for_typst(domain, report_name, params, opts \\ []) do
  # ... existing implementation ...

  # NEW: Build comprehensive pipeline_opts from user options
  pipeline_opts = build_pipeline_opts(domain, report, params, opts, grouped_aggregations)

  case StreamingPipeline.start_pipeline(pipeline_opts) do
    {:ok, _stream_id, stream} ->
      {:ok, stream}

    {:error, reason} ->
      {:error, {:streaming_pipeline_failed, reason}}
  end
end

# NEW: Build comprehensive pipeline options
defp build_pipeline_opts(domain, report, params, opts, grouped_aggregations) do
  transformer = build_typst_transformer(report, opts)

  [
    domain: domain,
    resource: report.resource,
    query: build_query_from_report(domain, report, params) |> elem(1),
    transformer: transformer,
    chunk_size: Keyword.get(opts, :chunk_size, 500),
    max_demand: Keyword.get(opts, :max_demand, 1000),
    buffer_size: Keyword.get(opts, :buffer_size, 1000),
    enable_telemetry: Keyword.get(opts, :enable_telemetry, true),
    report_name: report.name,
    report_config: build_report_config(report, params),
    aggregations: Keyword.get(opts, :aggregations, []),
    grouped_aggregations: Keyword.get(opts, :grouped_aggregations, grouped_aggregations),
    memory_limit: Keyword.get(opts, :memory_limit, 500_000_000),
    timeout: Keyword.get(opts, :timeout, :infinity)
  ]
end
```

**Implementation Tasks**:
- [ ] Add comprehensive @doc with all options explained
- [ ] Create `build_pipeline_opts/5` private function
- [ ] Add option validation (e.g., chunk_size > 0)
- [ ] Support overriding DSL-inferred grouped_aggregations
- [ ] Pass memory_limit to Producer configuration
- [ ] Add examples for common scenarios

---

### 2. Unified Batch/Streaming API with Automatic Mode Selection

**Goal**: Create a single function that automatically chooses batch or streaming based on dataset size.

**Current State**: Users must manually choose between `load_for_typst/4` (batch) and `stream_for_typst/4` (streaming).

**Required Changes**:

```elixir
# lib/ash_reports/typst/data_loader.ex

@doc """
Loads report data with automatic batch vs. streaming mode selection.

Automatically chooses the most efficient loading strategy:
- Small datasets (< threshold): Batch loading via `load_for_typst/4`
- Large datasets (>= threshold): Streaming via `stream_for_typst/4`

The threshold can be customized or disabled for manual control.

## Options

- `:mode` - Force mode (`:auto | :batch | :streaming`, default: `:auto`)
- `:streaming_threshold` - Record count threshold (default: 10_000)
- `:estimate_count` - Pre-count records for mode selection (default: false)
- All options from `load_for_typst/4` and `stream_for_typst/4`

## Returns

- `{:ok, data}` - Batch mode: All records loaded into memory
- `{:ok, stream}` - Streaming mode: Enumerable stream of records
- `{:error, reason}` - Loading failure

## Examples

    # Automatic mode selection (recommended)
    case DataLoader.load_report_data(MyApp.Domain, :sales_report, params) do
      {:ok, %{records: records}} ->
        # Batch mode was selected (small dataset)
        IO.puts "Loaded #{length(records)} records"

      {:ok, stream} ->
        # Streaming mode was selected (large dataset)
        stream |> Enum.each(&process_record/1)
    end

    # Force batch mode
    {:ok, data} = DataLoader.load_report_data(MyApp.Domain, :report, params,
      mode: :batch
    )

    # Force streaming mode
    {:ok, stream} = DataLoader.load_report_data(MyApp.Domain, :report, params,
      mode: :streaming
    )

    # Custom threshold
    {:ok, result} = DataLoader.load_report_data(MyApp.Domain, :report, params,
      streaming_threshold: 5000
    )

    # Estimate count before loading (adds query overhead)
    {:ok, result} = DataLoader.load_report_data(MyApp.Domain, :report, params,
      estimate_count: true
    )
"""
@spec load_report_data(module(), atom(), map(), load_options()) ::
        {:ok, typst_data() | Enumerable.t()} | {:error, term()}
def load_report_data(domain, report_name, params, opts \\ []) do
  mode = Keyword.get(opts, :mode, :auto)

  case mode do
    :batch ->
      load_for_typst(domain, report_name, params, opts)

    :streaming ->
      stream_for_typst(domain, report_name, params, opts)

    :auto ->
      with {:ok, report} <- get_report_definition(domain, report_name),
           {:ok, selected_mode} <- select_mode(domain, report, params, opts) do
        case selected_mode do
          :batch -> load_for_typst(domain, report_name, params, opts)
          :streaming -> stream_for_typst(domain, report_name, params, opts)
        end
      end
  end
end

# NEW: Intelligent mode selection
defp select_mode(domain, report, params, opts) do
  threshold = Keyword.get(opts, :streaming_threshold, 10_000)
  estimate_count = Keyword.get(opts, :estimate_count, false)

  if estimate_count do
    # Count records before loading (adds overhead)
    case estimate_record_count(domain, report, params) do
      {:ok, count} when count < threshold ->
        Logger.debug("Selecting batch mode: #{count} records < #{threshold} threshold")
        {:ok, :batch}

      {:ok, count} ->
        Logger.debug("Selecting streaming mode: #{count} records >= #{threshold} threshold")
        {:ok, :streaming}

      {:error, _reason} ->
        # Fallback to streaming if count fails
        Logger.warning("Failed to estimate count, defaulting to streaming mode")
        {:ok, :streaming}
    end
  else
    # Heuristic-based selection without pre-counting
    # Default to streaming for safety (memory-efficient)
    Logger.debug("Auto mode without count estimation, defaulting to streaming")
    {:ok, :streaming}
  end
end

# NEW: Estimate record count via Ash.count/2
defp estimate_record_count(domain, report, params) do
  with {:ok, query} <- build_query_from_report(domain, report, params) do
    case Ash.count(query, domain: domain) do
      {:ok, count} -> {:ok, count}
      {:error, reason} -> {:error, {:count_failed, reason}}
    end
  end
end
```

**Implementation Tasks**:
- [ ] Implement `load_report_data/4` with automatic mode selection
- [ ] Add `select_mode/4` private function
- [ ] Implement `estimate_record_count/3` using `Ash.count/2`
- [ ] Add heuristic-based selection (without pre-counting)
- [ ] Update documentation with decision flowchart
- [ ] Add tests for mode selection logic

---

### 3. Stream Control API

**Goal**: Expose pause/resume/cancel functionality at the DataLoader level.

**Current State**: `StreamingPipeline` has `pause_pipeline/1`, `resume_pipeline/1`, `stop_pipeline/1` but they require `stream_id`. Users calling `stream_for_typst/4` don't get the `stream_id` back.

**Required Changes**:

```elixir
# lib/ash_reports/typst/data_loader.ex

@doc """
Streams large datasets with control handle for pause/resume/cancel.

Returns both the stream and a control handle for managing the pipeline.

## Returns

- `{:ok, stream, control}` - Stream and control handle
- `{:error, reason}` - Streaming setup failure

## Control Handle

The control handle is a map with:
- `:stream_id` - Unique pipeline identifier
- `:pause` - Function to pause the stream
- `:resume` - Function to resume the stream
- `:stop` - Function to stop the stream
- `:info` - Function to get pipeline info

## Examples

    {:ok, stream, control} = DataLoader.stream_for_typst_with_control(
      MyApp.Domain,
      :large_report,
      params
    )

    # Start processing in background
    task = Task.async(fn ->
      stream |> Enum.each(&process_record/1)
    end)

    # Pause processing
    control.pause.()

    # Check status
    {:ok, info} = control.info.()
    IO.inspect(info.status)  # => :paused

    # Resume processing
    control.resume.()

    # Cancel if needed
    control.stop.()
"""
@spec stream_for_typst_with_control(module(), atom(), map(), load_options()) ::
        {:ok, Enumerable.t(), map()} | {:error, term()}
def stream_for_typst_with_control(domain, report_name, params, opts \\ []) do
  Logger.info("Setting up streaming with control for report #{report_name}")

  with {:ok, report} <- get_report_definition(domain, report_name),
       {:ok, stream_id, stream} <- create_streaming_pipeline_with_id(domain, report, params, opts) do

    # Create control handle
    control = %{
      stream_id: stream_id,
      pause: fn -> StreamingPipeline.pause_pipeline(stream_id) end,
      resume: fn -> StreamingPipeline.resume_pipeline(stream_id) end,
      stop: fn -> StreamingPipeline.stop_pipeline(stream_id) end,
      info: fn -> StreamingPipeline.get_pipeline_info(stream_id) end
    }

    {:ok, stream, control}
  end
end

# NEW: Return stream_id alongside stream
defp create_streaming_pipeline_with_id(domain, report, params, opts) do
  # Same as create_streaming_pipeline/4 but returns stream_id
  with {:ok, query} <- build_query_from_report(domain, report, params) do
    transformer = build_typst_transformer(report, opts)
    grouped_aggregations = build_grouped_aggregations_from_dsl(report)

    pipeline_opts = build_pipeline_opts(domain, report, params, opts, grouped_aggregations)

    case StreamingPipeline.start_pipeline(pipeline_opts) do
      {:ok, stream_id, stream} ->
        {:ok, stream_id, stream}

      {:error, reason} ->
        {:error, {:streaming_pipeline_failed, reason}}
    end
  end
end

@doc """
Gets information about an active streaming pipeline.

## Examples

    {:ok, info} = DataLoader.get_stream_info(stream_id)
    IO.inspect(info)
    # => %{
    #   status: :running,
    #   records_processed: 5000,
    #   memory_usage: 123456789,
    #   started_at: ~U[2025-01-15 10:30:00Z]
    # }
"""
@spec get_stream_info(String.t()) :: {:ok, map()} | {:error, :not_found}
def get_stream_info(stream_id) do
  StreamingPipeline.get_pipeline_info(stream_id)
end

@doc """
Lists all active streaming pipelines.

## Examples

    pipelines = DataLoader.list_active_streams()
    # => [
    #   %{stream_id: "abc123", status: :running, report_name: :sales_report},
    #   %{stream_id: "def456", status: :paused, report_name: :inventory_report}
    # ]
"""
@spec list_active_streams(keyword()) :: [map()]
def list_active_streams(opts \\ []) do
  StreamingPipeline.list_pipelines(opts)
end
```

**Implementation Tasks**:
- [ ] Implement `stream_for_typst_with_control/4`
- [ ] Create `create_streaming_pipeline_with_id/4` helper
- [ ] Build control handle map with closures
- [ ] Add `get_stream_info/1` delegation
- [ ] Add `list_active_streams/1` delegation
- [ ] Add examples and documentation
- [ ] Consider deprecating direct `StreamingPipeline` API for users

---

### 4. Configuration Helpers and Utilities

**Goal**: Provide helper functions for common streaming scenarios.

**Required Changes**:

```elixir
# lib/ash_reports/typst/data_loader.ex

@doc """
Creates streaming configuration optimized for memory-constrained environments.

Reduces chunk size and buffer size to minimize memory usage.

## Examples

    opts = DataLoader.streaming_config_low_memory()
    {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params, opts)
"""
@spec streaming_config_low_memory() :: load_options()
def streaming_config_low_memory do
  [
    chunk_size: 100,
    max_demand: 200,
    buffer_size: 100,
    memory_limit: 100_000_000  # 100MB
  ]
end

@doc """
Creates streaming configuration optimized for high throughput.

Increases chunk size and buffer size for faster processing.

## Examples

    opts = DataLoader.streaming_config_high_throughput()
    {:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params, opts)
"""
@spec streaming_config_high_throughput() :: load_options()
def streaming_config_high_throughput do
  [
    chunk_size: 5000,
    max_demand: 10000,
    buffer_size: 5000
  ]
end

@doc """
Creates streaming configuration with custom aggregations.

## Examples

    opts = DataLoader.streaming_config_with_aggregations(
      aggregations: [:sum, :count],
      grouped_aggregations: [
        %{group_by: :region, aggregations: [:sum, :count]}
      ]
    )
"""
@spec streaming_config_with_aggregations(keyword()) :: load_options()
def streaming_config_with_aggregations(overrides \\ []) do
  defaults = [
    aggregations: Keyword.get(overrides, :aggregations, []),
    grouped_aggregations: Keyword.get(overrides, :grouped_aggregations, [])
  ]

  Keyword.merge(defaults, overrides)
end
```

**Implementation Tasks**:
- [ ] Add `streaming_config_low_memory/0`
- [ ] Add `streaming_config_high_throughput/0`
- [ ] Add `streaming_config_with_aggregations/1`
- [ ] Document performance tradeoffs
- [ ] Add benchmarks comparing configs

---

### 5. Enhanced Error Handling

**Goal**: Improve error messages and recovery for streaming-specific failures.

**Current State**: Generic error tuples returned.

**Required Changes**:

```elixir
# lib/ash_reports/typst/data_loader.ex

defp create_streaming_pipeline(domain, report, params, opts) do
  with {:ok, query} <- build_query_from_report(domain, report, params) do
    transformer = build_typst_transformer(report, opts)
    grouped_aggregations = build_grouped_aggregations_from_dsl(report)

    pipeline_opts = build_pipeline_opts(domain, report, params, opts, grouped_aggregations)

    case StreamingPipeline.start_pipeline(pipeline_opts) do
      {:ok, _stream_id, stream} ->
        {:ok, stream}

      {:error, {:producer_start_failed, reason}} ->
        Logger.error("Failed to start streaming producer: #{inspect(reason)}")
        {:error, {:streaming_producer_failed, "Could not initialize data producer. Check query and resource configuration.", reason}}

      {:error, {:producer_consumer_start_failed, reason}} ->
        Logger.error("Failed to start streaming transformer: #{inspect(reason)}")
        {:error, {:streaming_transformer_failed, "Could not initialize data transformer. Check transformation configuration.", reason}}

      {:error, {:registration_failed, reason}} ->
        Logger.error("Failed to register streaming pipeline: #{inspect(reason)}")
        {:error, {:streaming_registration_failed, "Could not register pipeline. Registry may be unavailable.", reason}}

      {:error, reason} ->
        Logger.error("Streaming pipeline failed: #{inspect(reason)}")
        {:error, {:streaming_pipeline_failed, reason}}
    end
  end
end
```

**Implementation Tasks**:
- [ ] Add specific error pattern matching
- [ ] Create user-friendly error messages
- [ ] Add recovery suggestions in error tuples
- [ ] Log detailed errors for debugging
- [ ] Consider automatic fallback to batch mode on streaming failure

---

### 6. Documentation and Examples

**Goal**: Comprehensive documentation for all API usage patterns.

**Required Documentation**:

1. **Module Documentation** (Update `@moduledoc` in `data_loader.ex`)
   - Overview of batch vs. streaming
   - Decision flowchart: when to use which mode
   - Performance characteristics
   - Memory usage guidelines

2. **Function Documentation** (Add detailed `@doc` for each function)
   - All configuration options explained
   - Multiple examples per function
   - Common patterns and anti-patterns
   - Performance tips

3. **Usage Guide** (Add to project docs)
   - Getting started with streaming
   - Automatic mode selection guide
   - Stream control examples
   - Aggregation configuration guide
   - Performance tuning guide
   - Troubleshooting common issues

**Example Documentation Section**:

```markdown
## Usage Patterns

### 1. Simple Batch Loading (Small Reports)

For reports with < 10,000 records, use batch loading:

```elixir
{:ok, data} = DataLoader.load_for_typst(MyApp.Domain, :monthly_sales, %{
  month: "2024-01"
})

# Access records directly
data.records |> Enum.each(&IO.inspect/1)
```

### 2. Streaming Large Datasets

For reports with > 10,000 records, use streaming:

```elixir
{:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :annual_sales, %{
  year: 2024
})

# Process records lazily
stream
|> Stream.chunk_every(1000)
|> Stream.each(&generate_pdf_page/1)
|> Stream.run()
```

### 3. Automatic Mode Selection

Let DataLoader choose the best mode:

```elixir
case DataLoader.load_report_data(MyApp.Domain, :sales_report, params) do
  {:ok, %{records: records}} ->
    # Batch mode: all records in memory
    render_template(records)

  {:ok, stream} ->
    # Streaming mode: process lazily
    stream |> Enum.each(&process_record/1)
end
```

### 4. Stream Control

Pause, resume, and cancel long-running streams:

```elixir
{:ok, stream, control} = DataLoader.stream_for_typst_with_control(
  MyApp.Domain,
  :huge_report,
  params
)

# Start processing in background
task = Task.async(fn ->
  stream |> Enum.each(&process_record/1)
end)

# Pause if system under load
if system_under_load?() do
  control.pause.()
  Process.sleep(60_000)
  control.resume.()
end

# Cancel if timeout
receive do
  :timeout -> control.stop.()
after
  300_000 -> nil
end
```

### 5. Custom Aggregations

Override DSL-inferred aggregations:

```elixir
{:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :sales_report, params,
  aggregations: [:sum, :count, :avg],
  grouped_aggregations: [
    %{group_by: :region, aggregations: [:sum, :count]},
    %{group_by: [:region, :salesperson], aggregations: [:sum]}
  ]
)
```

### 6. Memory-Constrained Environments

Optimize for low memory usage:

```elixir
opts = DataLoader.streaming_config_low_memory()
{:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params, opts)
```

### 7. High-Throughput Processing

Optimize for maximum speed:

```elixir
opts = DataLoader.streaming_config_high_throughput()
{:ok, stream} = DataLoader.stream_for_typst(MyApp.Domain, :report, params, opts)
```
```

**Implementation Tasks**:
- [ ] Update `@moduledoc` in `data_loader.ex`
- [ ] Add comprehensive `@doc` for all public functions
- [ ] Create usage guide in project documentation
- [ ] Add decision flowchart (batch vs. streaming)
- [ ] Document performance characteristics
- [ ] Add troubleshooting section

---

## Implementation Plan

### Phase 1: Configuration Enhancement (Day 1-2)

**Tasks**:
1. Add comprehensive options to `stream_for_typst/4`
2. Create `build_pipeline_opts/5` helper
3. Add option validation
4. Support overriding DSL-inferred aggregations
5. Update documentation with all options
6. Add examples for common scenarios

**Completion Criteria**:
- [ ] All streaming options documented and working
- [ ] Users can customize chunk_size, max_demand, buffer_size
- [ ] Users can override DSL-inferred aggregations
- [ ] Validation prevents invalid configurations
- [ ] Examples demonstrate common use cases

---

### Phase 2: Unified API Implementation (Day 2-3)

**Tasks**:
1. Implement `load_report_data/4` with mode selection
2. Create `select_mode/4` decision logic
3. Implement `estimate_record_count/3` using Ash.count
4. Add heuristic-based selection (no pre-count)
5. Add logging for mode selection decisions
6. Update documentation with decision flowchart

**Completion Criteria**:
- [ ] `load_report_data/4` automatically selects batch or streaming
- [ ] Mode selection based on configurable threshold
- [ ] Optional count estimation before loading
- [ ] Heuristic fallback when count unavailable
- [ ] Clear logging explains mode selection
- [ ] Documentation includes decision guide

---

### Phase 3: Stream Control API (Day 3-4)

**Tasks**:
1. Implement `stream_for_typst_with_control/4`
2. Create `create_streaming_pipeline_with_id/4`
3. Build control handle with closures
4. Add `get_stream_info/1` delegation
5. Add `list_active_streams/1` delegation
6. Document control API with examples

**Completion Criteria**:
- [ ] Users can pause/resume/stop streams
- [ ] Control handle provides clean API
- [ ] Stream info accessible via DataLoader
- [ ] Pipeline listing available
- [ ] Examples demonstrate control patterns
- [ ] Error handling for invalid stream_id

---

### Phase 4: Configuration Helpers (Day 4)

**Tasks**:
1. Add `streaming_config_low_memory/0`
2. Add `streaming_config_high_throughput/0`
3. Add `streaming_config_with_aggregations/1`
4. Document performance tradeoffs
5. Add benchmarks comparing configs

**Completion Criteria**:
- [ ] Helper functions for common scenarios
- [ ] Low-memory config tested and documented
- [ ] High-throughput config benchmarked
- [ ] Aggregation config helper works
- [ ] Performance tradeoffs documented

---

### Phase 5: Error Handling Enhancement (Day 4-5)

**Tasks**:
1. Add specific error pattern matching
2. Create user-friendly error messages
3. Add recovery suggestions in errors
4. Improve error logging
5. Consider automatic fallback to batch

**Completion Criteria**:
- [ ] Streaming errors have clear messages
- [ ] Error tuples include recovery suggestions
- [ ] Detailed logging for debugging
- [ ] Users understand failure reasons
- [ ] Graceful degradation where possible

---

### Phase 6: Documentation (Day 5)

**Tasks**:
1. Update `@moduledoc` in data_loader.ex
2. Add comprehensive `@doc` for all functions
3. Create usage guide with examples
4. Add decision flowchart diagram
5. Document performance characteristics
6. Add troubleshooting section

**Completion Criteria**:
- [ ] Module documentation complete
- [ ] All functions have detailed docs
- [ ] Usage guide covers common patterns
- [ ] Decision flowchart helps users choose
- [ ] Performance guide aids optimization
- [ ] Troubleshooting resolves common issues

---

## Success Criteria

### Functional Requirements

1. **Configuration Control** ✅
   - [ ] Users can customize chunk_size, max_demand, buffer_size
   - [ ] Users can override DSL-inferred aggregations
   - [ ] Users can set memory limits
   - [ ] Users can enable/disable telemetry
   - [ ] Users can configure timeout

2. **Unified API** ✅
   - [ ] Single function for automatic mode selection
   - [ ] Configurable streaming threshold
   - [ ] Optional count estimation
   - [ ] Heuristic-based fallback
   - [ ] Clear mode selection logging

3. **Stream Control** ✅
   - [ ] Pause/resume/stop streams
   - [ ] Get stream info
   - [ ] List active streams
   - [ ] Clean control handle API
   - [ ] Error handling for invalid operations

4. **Configuration Helpers** ✅
   - [ ] Low-memory configuration
   - [ ] High-throughput configuration
   - [ ] Aggregation configuration
   - [ ] Performance tradeoffs documented

5. **Error Handling** ✅
   - [ ] Clear error messages
   - [ ] Recovery suggestions
   - [ ] Detailed logging
   - [ ] Graceful degradation

6. **Documentation** ✅
   - [ ] Module overview complete
   - [ ] All functions documented
   - [ ] Usage guide with examples
   - [ ] Decision flowchart
   - [ ] Performance guide
   - [ ] Troubleshooting section

### Non-Functional Requirements

1. **Backward Compatibility**
   - [ ] Existing `stream_for_typst/4` calls work unchanged
   - [ ] Existing `load_for_typst/4` calls work unchanged
   - [ ] New options are additive only
   - [ ] No breaking API changes

2. **Performance**
   - [ ] No performance regression in streaming
   - [ ] Mode selection adds < 1ms overhead (heuristic)
   - [ ] Count estimation optional (adds query overhead)
   - [ ] Configuration helpers zero-cost

3. **Usability**
   - [ ] Clear API with sensible defaults
   - [ ] Examples cover common scenarios
   - [ ] Error messages guide users
   - [ ] Documentation findable and complete

---

## Testing Strategy

### Unit Tests

**New Tests Required**:

1. **Configuration Tests** (`test/ash_reports/typst/data_loader_test.exs`)
   - [ ] Test all streaming options pass through correctly
   - [ ] Test option validation (invalid chunk_size, etc.)
   - [ ] Test DSL aggregation override
   - [ ] Test memory_limit configuration
   - [ ] Test timeout configuration

2. **Mode Selection Tests**
   - [ ] Test automatic batch selection (< threshold)
   - [ ] Test automatic streaming selection (>= threshold)
   - [ ] Test forced batch mode
   - [ ] Test forced streaming mode
   - [ ] Test count estimation success
   - [ ] Test count estimation failure (fallback)
   - [ ] Test heuristic selection

3. **Stream Control Tests**
   - [ ] Test control handle creation
   - [ ] Test pause/resume/stop functions
   - [ ] Test get_stream_info delegation
   - [ ] Test list_active_streams delegation
   - [ ] Test control handle with invalid stream_id

4. **Configuration Helper Tests**
   - [ ] Test low_memory config values
   - [ ] Test high_throughput config values
   - [ ] Test aggregation config builder
   - [ ] Test config merging

5. **Error Handling Tests**
   - [ ] Test producer failure error message
   - [ ] Test producer_consumer failure error message
   - [ ] Test registration failure error message
   - [ ] Test generic failure error message

**Estimated Test Count**: ~25-30 new tests

---

### Integration Tests

**Scenarios**:

1. **End-to-End Streaming** (using test report from Section 2.4.4)
   - [ ] Stream 10K+ records with custom options
   - [ ] Verify chunk_size affects batching
   - [ ] Verify aggregations computed correctly
   - [ ] Verify stream completes successfully

2. **Automatic Mode Selection**
   - [ ] Test with 100-record dataset (batch mode)
   - [ ] Test with 20K-record dataset (streaming mode)
   - [ ] Test with count estimation enabled
   - [ ] Verify mode selection logged correctly

3. **Stream Control**
   - [ ] Start stream, pause, resume, complete
   - [ ] Start stream, cancel mid-processing
   - [ ] Check stream info during processing
   - [ ] List active streams

4. **Configuration Presets**
   - [ ] Test low_memory config with large dataset
   - [ ] Test high_throughput config performance
   - [ ] Test aggregation config override

**Estimated Test Count**: ~15-20 integration tests

---

### Documentation Tests

**Doctests**:
- [ ] Add doctests to all `@doc` examples
- [ ] Verify code examples compile and run
- [ ] Test edge cases in examples

---

## Dependencies and Blockers

### Dependencies (All Complete ✅)

1. **Section 2.1**: GenStage Infrastructure - COMPLETE
2. **Section 2.2**: Producer Implementation - COMPLETE
3. **Section 2.3**: ProducerConsumer Implementation - COMPLETE
4. **Section 2.4**: DSL-Driven Grouped Aggregation - COMPLETE

### Blockers

**None** - All dependencies complete.

---

## Risks and Mitigations

### Risk 1: Breaking Changes

**Risk**: New API might break existing users.

**Mitigation**:
- All changes are additive (new functions or new optional parameters)
- Existing `stream_for_typst/4` signature unchanged
- Backward compatibility tests
- Deprecation warnings if needed

### Risk 2: Performance Regression

**Risk**: Mode selection or option processing adds overhead.

**Mitigation**:
- Heuristic selection is O(1) (no query overhead)
- Count estimation is opt-in (disabled by default)
- Benchmark before/after
- Performance tests in CI

### Risk 3: Incomplete Documentation

**Risk**: Users don't know how to use new features.

**Mitigation**:
- Comprehensive @doc for all functions
- Usage guide with decision flowchart
- Multiple examples per feature
- Troubleshooting guide
- Code review for documentation quality

### Risk 4: Configuration Complexity

**Risk**: Too many options confuse users.

**Mitigation**:
- Sensible defaults for all options
- Configuration helpers for common scenarios
- Documentation guides users to right config
- Examples demonstrate 80% use cases

---

## Open Questions

1. **Should we deprecate direct `StreamingPipeline` API access for users?**
   - **Recommendation**: Yes, but with deprecation warnings (not removal)
   - Users should use `DataLoader` API for cleaner interface
   - Keep `StreamingPipeline` public for advanced use cases

2. **Should `load_report_data/4` be the primary API?**
   - **Recommendation**: Yes, promote as primary API in docs
   - Keep `load_for_typst/4` and `stream_for_typst/4` for explicit control
   - Guide users to `load_report_data/4` in "Getting Started"

3. **Should count estimation be enabled by default?**
   - **Recommendation**: No, keep opt-in (adds query overhead)
   - Heuristic selection (default to streaming) is safer
   - Document trade-offs clearly

4. **Should we add automatic fallback to batch on streaming failure?**
   - **Recommendation**: No, fail explicitly
   - Automatic fallback hides issues
   - Users should handle errors explicitly
   - Provide clear error messages to guide recovery

---

## Future Enhancements (Out of Scope for 2.5.1)

These are valuable but deferred to Section 2.5.2, 2.5.3, or future work:

1. **Section 2.5.2: Automatic Mode Selection** (Partially addressed)
   - [ ] More sophisticated heuristics (query complexity analysis)
   - [ ] Adaptive thresholds based on system resources
   - [ ] Machine learning-based mode selection

2. **Section 2.5.3: Stream Control** (Partially addressed)
   - [ ] Timeout handling with auto-stop
   - [ ] Graceful shutdown on application termination
   - [ ] Stream migration (pause on one node, resume on another)

3. **Advanced Features**
   - [ ] Stream progress reporting (X% complete)
   - [ ] Estimated time remaining
   - [ ] Memory usage visualization
   - [ ] Performance profiling API
   - [ ] Stream composition (chain multiple streams)

---

## Acceptance Checklist

**Before marking Section 2.5.1 complete**:

- [ ] All implementation tasks from Phase 1-6 complete
- [ ] All unit tests pass (25-30 tests)
- [ ] All integration tests pass (15-20 tests)
- [ ] All doctests pass
- [ ] Documentation reviewed and complete
- [ ] Code reviewed for quality
- [ ] Performance benchmarks show no regression
- [ ] Backward compatibility verified
- [ ] Examples tested manually
- [ ] Decision flowchart created
- [ ] Usage guide written
- [ ] Troubleshooting section complete
- [ ] Error messages clear and helpful
- [ ] Configuration helpers documented
- [ ] All open questions resolved

---

## Related Documents

- **Planning Doc**: `/home/ducky/code/ash_reports/planning/typst_refactor_plan.md` (Section 2.5.1)
- **Section 2.4 Integration**: `/home/ducky/code/ash_reports/notes/features/stage2_4_4_integration_testing.md`
- **StreamingPipeline API**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline.ex`
- **DataLoader Implementation**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/data_loader.ex`
- **ProducerConsumer Docs**: `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline/producer_consumer.ex`

---

**Document Version**: 1.0
**Created**: 2025-10-01
**Last Updated**: 2025-10-01
**Author**: Planning Document (for Pascal's review)
