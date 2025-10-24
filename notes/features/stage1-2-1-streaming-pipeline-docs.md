# Stage 1.2.1: Document StreamingPipeline Public API - Feature Planning Document

**Status**: Planning
**Created**: 2025-10-09
**Section**: Stage 1.2.1 - StreamingPipeline Public API Documentation
**Dependencies**: Stage 1.1 (Complete - Shared DataLoader Interface)
**Duration**: 4-6 hours

---

## Problem Statement

The `AshReports.Typst.StreamingPipeline` module (670 lines) provides a high-level interface for creating and managing GenStage streaming pipelines. While the module has a comprehensive moduledoc (lines 2-90) and some function documentation, there are several documentation gaps that make it difficult for external consumers to use the API effectively:

### Current State Analysis

**Strengths**:
- ✅ Comprehensive moduledoc covering architecture, usage, configuration, and telemetry (lines 2-90)
- ✅ Public functions have `@doc` with examples and typespec
- ✅ Internal design note warns about internal use by DataLoader (line 13-15)

**Documentation Gaps**:
1. **Missing @doc false for internal functions**: 14 private helper functions (lines 433-669) are implementation details but not explicitly marked as internal
2. **Unclear Public API Surface**: While all public functions have docs, it's not immediately clear which functions are intended for external use vs internal DataLoader consumption
3. **Missing Usage Scenarios**: Documentation lacks examples for common real-world scenarios like:
   - Monitoring pipeline progress during long-running reports
   - Handling errors and retries
   - Best practices for partition_count configuration
   - Integrating with Phoenix LiveView for progress updates
4. **Internal vs External Distinction**: The module is designed for "internal use by DataLoader" (line 13) but exposes many management functions that seem useful for external consumers

### Why This Matters

1. **Stage 1.2 Goal**: As part of the unified streaming implementation, we need clear public API boundaries before integrating HTML, JSON, and HEEX renderers (Stages 2-4)

2. **External Consumer Confusion**: Developers using AshReports may want to:
   - Monitor pipeline progress during report generation
   - Implement custom retry logic for failed pipelines
   - Build dashboards showing active pipeline status
   - Currently unclear which functions are safe to use

3. **Future Maintenance**: Before refactoring HTML/JSON/HEEX renderers to use streaming (Stages 2-4), we need clear documentation of:
   - What functions renderers should call
   - What internal functions should never be called directly
   - Expected usage patterns and error handling

---

## Solution Overview

Enhance the existing StreamingPipeline documentation to provide clear boundaries between public API and internal implementation while adding comprehensive usage examples for common scenarios.

### Approach

**Not a refactor** - This is purely documentation work. No code changes except:
- Adding `@doc false` to internal helper functions
- Enhancing existing @doc strings with more examples
- Adding new usage examples to moduledoc

**Key Principles**:
1. **Preserve existing structure** - The current moduledoc is excellent, just needs enhancement
2. **Mark internal functions** - Make it explicit which functions are implementation details
3. **Add usage scenarios** - Practical examples for common tasks
4. **Clarify internal vs external** - Help developers understand when to use vs when to extend

### Public API Surface (9 Functions)

Based on analysis, these functions form the public API:

**Pipeline Creation**:
- `start_pipeline/1` - Create a new streaming pipeline (line 162)

**Pipeline Management**:
- `get_pipeline_info/1` - Get pipeline status and progress (line 219)
- `list_pipelines/1` - List all active pipelines (line 238)
- `pause_pipeline/1` - Pause a running pipeline (line 252)
- `resume_pipeline/1` - Resume a paused pipeline (line 265)
- `stop_pipeline/1` - Stop a pipeline early (line 280)
- `pipeline_counts/0` - Get count of pipelines by status (line 307)

**Aggregation Results**:
- `get_aggregation_snapshot/1` - Get current state while streaming (line 355)
- `get_aggregation_state/1` - Get final state after completion (line 426)

### Internal Functions (14 Private Helpers)

These should be marked `@doc false`:
- `get_current_aggregation_state/2` (line 433)
- `calculate_progress_percentage/1` (line 458)
- `get_producer_consumer_pid/1` (line 480, 488)
- `fetch_required/2` (line 490)
- `extract_metadata/1` (line 497)
- `create_stream/2` (line 507)
- `default_chunk_size/0` (line 512)
- `default_max_demand/0` (line 517)
- `start_pipeline_stages/5` (line 522)
- `get_pipeline_supervisor/1` (line 542)
- `start_producer_stage/3` (line 553)
- `start_producer_consumer_stage/7` (line 566)
- `start_single_worker/6` (line 600)
- `start_partitioned_workers/6` (line 632)

---

## Technical Details

### Module Organization

The module is already well-organized:

```elixir
# Lines 2-90: Comprehensive moduledoc
#   - Architecture overview
#   - Usage examples
#   - Configuration
#   - Pipeline management
#   - Error handling
#   - Telemetry

# Lines 92-101: Aliases and requires

# Lines 103-104: Type definitions
@type stream_id :: binary()
@type pipeline_stream :: Enumerable.t()

# Lines 106-430: Public API (9 functions with @doc)

# Lines 432-669: Private implementation (14 helpers, currently no @doc false)
```

### Documentation Enhancements Needed

#### 1. Add Usage Scenario Section to Moduledoc

Insert new section after line 90 (before existing content):

```markdown
## Usage Scenarios

### Scenario 1: Monitoring Long-Running Reports

When generating large reports, you may want to show progress to users:

    # Start the pipeline
    {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(...)

    # Start async consumption in a Task
    task = Task.async(fn -> Enum.to_list(stream) end)

    # Poll for progress (e.g., every 500ms)
    defp poll_progress(stream_id) do
      case StreamingPipeline.get_aggregation_snapshot(stream_id) do
        {:ok, snapshot} ->
          IO.puts "Progress: #{snapshot.progress.percent_complete}%"
          IO.puts "Records: #{snapshot.progress.records_processed}"
          IO.puts "Status: #{snapshot.progress.status}"

          unless snapshot.stable do
            Process.sleep(500)
            poll_progress(stream_id)
          end
        {:error, _} ->
          :timer.sleep(100)
          poll_progress(stream_id)
      end
    end

    # Wait for completion
    spawn(fn -> poll_progress(stream_id) end)
    results = Task.await(task, :infinity)

### Scenario 2: Phoenix LiveView Progress Updates

Integrate pipeline progress with LiveView for real-time updates:

    # In your LiveView mount/3
    def mount(_params, _session, socket) do
      {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(...)

      # Schedule progress updates
      if connected?(socket) do
        :timer.send_interval(500, self(), :update_progress)
      end

      # Start async consumption
      Task.async(fn -> Enum.to_list(stream) end)

      {:ok, assign(socket, stream_id: stream_id, progress: 0)}
    end

    # Handle progress updates
    def handle_info(:update_progress, socket) do
      case StreamingPipeline.get_aggregation_snapshot(socket.assigns.stream_id) do
        {:ok, snapshot} ->
          progress = snapshot.progress.percent_complete || 0
          {:noreply, assign(socket, progress: progress)}
        {:error, _} ->
          {:noreply, socket}
      end
    end

### Scenario 3: Error Handling and Retry

Handle pipeline failures gracefully:

    defp start_pipeline_with_retry(opts, max_retries \\ 3) do
      case StreamingPipeline.start_pipeline(opts) do
        {:ok, stream_id, stream} ->
          # Monitor the pipeline
          case consume_with_monitoring(stream_id, stream) do
            {:ok, results} -> {:ok, results}
            {:error, reason} -> retry_pipeline(opts, reason, max_retries)
          end
        {:error, reason} ->
          retry_pipeline(opts, reason, max_retries)
      end
    end

    defp consume_with_monitoring(stream_id, stream) do
      try do
        results = Enum.to_list(stream)

        # Check final status
        case StreamingPipeline.get_pipeline_info(stream_id) do
          {:ok, %{status: :completed}} -> {:ok, results}
          {:ok, %{status: :failed}} -> {:error, :pipeline_failed}
          _ -> {:ok, results}
        end
      rescue
        e -> {:error, e}
      end
    end

    defp retry_pipeline(_opts, _reason, 0), do: {:error, :max_retries_exceeded}
    defp retry_pipeline(opts, reason, retries_left) do
      Logger.warn("Pipeline failed: #{inspect(reason)}, retrying...")
      :timer.sleep(1000)
      start_pipeline_with_retry(opts, retries_left - 1)
    end

### Scenario 4: Optimal Partition Count Configuration

Configure partition_count based on workload characteristics:

    # For aggregation-heavy reports, use CPU core count
    defp determine_partition_count(report_config) do
      aggregation_count = length(report_config[:grouped_aggregations] || [])

      cond do
        # No aggregations - single worker sufficient
        aggregation_count == 0 -> 1

        # Light aggregations - 2-4 workers
        aggregation_count <= 5 -> min(4, System.schedulers_online())

        # Heavy aggregations - scale to cores
        aggregation_count > 5 -> System.schedulers_online()
      end
    end

    # Example usage
    {:ok, stream_id, stream} = StreamingPipeline.start_pipeline(
      domain: MyApp.Reporting,
      resource: Order,
      query: query,
      partition_count: determine_partition_count(report_config)
    )

### Scenario 5: Pipeline Dashboard

Build a monitoring dashboard for all active pipelines:

    defmodule PipelineMonitor do
      def get_dashboard_stats do
        # Get overall counts
        counts = StreamingPipeline.pipeline_counts()

        # Get details for running pipelines
        running = StreamingPipeline.list_pipelines(status: :running)
        |> Enum.map(fn pipeline ->
          {:ok, snapshot} = StreamingPipeline.get_aggregation_snapshot(pipeline.stream_id)

          %{
            stream_id: pipeline.stream_id,
            report_name: pipeline.metadata.report_name,
            started_at: pipeline.started_at,
            progress: snapshot.progress.percent_complete,
            records_processed: snapshot.progress.records_processed,
            memory_usage: pipeline.memory_usage
          }
        end)

        %{
          counts: counts,
          running_pipelines: running,
          total_memory: Enum.sum(Enum.map(running, & &1.memory_usage))
        }
      end
    end
```

#### 2. Enhance Function Documentation

**start_pipeline/1** - Add note about partition_count best practices:

```elixir
@doc """
Starts a new streaming pipeline.

... (existing content) ...

## Partition Count Best Practices

Choose partition_count based on your workload:

- **No aggregations**: Use 1 (default) - no benefit from parallelization
- **Light aggregations (1-5)**: Use 2-4 workers - moderate speedup
- **Heavy aggregations (5+)**: Use System.schedulers_online() - maximize throughput
- **Large datasets (millions)**: Start with 4, scale up if CPU underutilized

Rule of thumb: partition_count = min(aggregation_count, schedulers_online())

## Returns

... (existing content) ...
"""
```

**get_aggregation_snapshot/1** - Add note about polling frequency:

```elixir
@doc """
Gets a snapshot of current aggregation state while streaming is in progress.

... (existing content) ...

## Polling Frequency Recommendations

- **LiveView updates**: Poll every 500-1000ms for smooth progress bars
- **Logs/metrics**: Poll every 5-10 seconds to reduce overhead
- **Dashboards**: Poll every 2-5 seconds for near-real-time updates

Avoid polling faster than 100ms as it may impact pipeline performance.

## Examples

... (existing content) ...
"""
```

**pause_pipeline/1 and resume_pipeline/1** - Add circuit breaker use case:

```elixir
@doc """
Pauses a running pipeline (circuit breaker).

... (existing content) ...

## Circuit Breaker Pattern

Commonly used when:
- Memory usage exceeds threshold (automatic via HealthMonitor)
- Downstream system becomes unavailable
- Manual intervention needed for debugging

Example:

    # Monitor memory and pause if threshold exceeded
    case StreamingPipeline.get_pipeline_info(stream_id) do
      {:ok, %{memory_usage: memory}} when memory > @max_memory ->
        StreamingPipeline.pause_pipeline(stream_id)
        # Trigger garbage collection, wait for memory to clear
        :erlang.garbage_collect()
        :timer.sleep(5000)
        StreamingPipeline.resume_pipeline(stream_id)
      _ ->
        :ok
    end

## Examples

... (existing content) ...
"""
```

#### 3. Add @doc false to Internal Functions

Mark all private helpers as internal (lines 433-669):

```elixir
@doc false
defp get_current_aggregation_state(stream_id, pipeline_info) do
  # ... existing implementation
end

@doc false
defp calculate_progress_percentage(pipeline_info) do
  # ... existing implementation
end

# ... repeat for all 14 internal helpers
```

#### 4. Add Public API Summary Section

Insert before "# Public API" comment (line 106):

```elixir
## Public API Summary

This module provides three categories of public functions:

**Pipeline Lifecycle** (for DataLoader and custom consumers):
- `start_pipeline/1` - Create and start a new pipeline
- `stop_pipeline/1` - Stop a pipeline early

**Pipeline Monitoring** (for dashboards and progress tracking):
- `get_pipeline_info/1` - Get status and progress for one pipeline
- `list_pipelines/1` - List all active pipelines (optionally filtered)
- `pipeline_counts/0` - Get counts by status (running, paused, completed, failed)

**Pipeline Control** (for circuit breakers and error recovery):
- `pause_pipeline/1` - Pause a running pipeline
- `resume_pipeline/1` - Resume a paused pipeline

**Aggregation Results** (for accessing streaming aggregations):
- `get_aggregation_snapshot/1` - Get current state while streaming (for progress)
- `get_aggregation_state/1` - Get final state after completion (for results)

**Internal Functions**: All functions starting with `defp` are internal implementation
details and should not be called directly. They are marked with `@doc false`.
```

### Documentation Structure After Changes

```
Lines 2-90: Existing moduledoc (Architecture, Usage, Config, etc.)
Lines 91-X: NEW - Usage Scenarios (5 scenarios added)
Lines X-Y: NEW - Public API Summary
Lines Y-106: Existing aliases and types
Lines 106-430: Public API (9 functions, enhanced docs)
Lines 430-669: Internal functions (14 helpers, now with @doc false)
```

---

## Implementation Plan

### Step 1: Add @doc false to All Internal Functions
**Duration**: 30 minutes
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Identify all 14 private helper functions (defp)
2. Add `@doc false` annotation above each function
3. Verify no public functions are accidentally marked

**Code locations**:
- Line 433: `get_current_aggregation_state/2`
- Line 458: `calculate_progress_percentage/1`
- Line 480, 488: `get_producer_consumer_pid/1` (two clauses)
- Line 490: `fetch_required/2`
- Line 497: `extract_metadata/1`
- Line 507: `create_stream/2`
- Line 512: `default_chunk_size/0`
- Line 517: `default_max_demand/0`
- Line 522: `start_pipeline_stages/5`
- Line 542: `get_pipeline_supervisor/1`
- Line 553: `start_producer_stage/3`
- Line 566: `start_producer_consumer_stage/7`
- Line 600: `start_single_worker/6`
- Line 632: `start_partitioned_workers/6`

**Verification**:
```bash
# Check that all defp now have @doc false
grep -B1 "defp " lib/ash_reports/typst/streaming_pipeline.ex | grep -c "@doc false"
# Should output: 14
```

**Success Criteria**:
- All 14 internal functions marked with `@doc false`
- No compilation warnings
- Module still compiles successfully

---

### Step 2: Add Usage Scenarios Section to Moduledoc
**Duration**: 1.5 hours
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Insert new "Usage Scenarios" section after line 90
2. Add 5 comprehensive scenarios:
   - Scenario 1: Monitoring long-running reports
   - Scenario 2: Phoenix LiveView progress updates
   - Scenario 3: Error handling and retry
   - Scenario 4: Optimal partition count configuration
   - Scenario 5: Pipeline dashboard
3. Ensure all code examples are syntactically correct
4. Verify examples align with actual API behavior

**Code location**: Insert after line 90, before existing moduledoc end

**Testing approach**:
- Copy each example into IEx and verify it compiles
- Check that example patterns match actual function signatures
- Validate that recommended polling frequencies are reasonable

**Success Criteria**:
- 5 complete usage scenarios added
- All code examples are syntactically valid
- Scenarios cover common real-world use cases
- Documentation flows naturally from architecture to scenarios

---

### Step 3: Add Public API Summary Section
**Duration**: 30 minutes
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Add "Public API Summary" section before line 106
2. Group functions by category:
   - Pipeline Lifecycle (2 functions)
   - Pipeline Monitoring (3 functions)
   - Pipeline Control (2 functions)
   - Aggregation Results (2 functions)
3. Add note about internal functions marked with @doc false
4. Link to specific sections in moduledoc

**Code location**: Insert before "# Public API" comment (line 106)

**Success Criteria**:
- Clear categorization of 9 public functions
- Easy to scan and understand API surface
- Note about internal functions is prominent
- No functions are missing or miscategorized

---

### Step 4: Enhance start_pipeline/1 Documentation
**Duration**: 30 minutes
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Locate `start_pipeline/1` @doc (line 108)
2. Add "Partition Count Best Practices" subsection
3. Include guidance on choosing partition_count:
   - No aggregations → 1
   - Light aggregations (1-5) → 2-4
   - Heavy aggregations (5+) → System.schedulers_online()
4. Add rule of thumb formula

**Code location**: Line 108-161 (within existing @doc)

**Success Criteria**:
- Clear guidance on partition_count selection
- Practical examples for different workload types
- Guidance is accurate based on benchmarks (if available)
- Existing documentation is preserved and enhanced

---

### Step 5: Enhance get_aggregation_snapshot/1 Documentation
**Duration**: 20 minutes
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Locate `get_aggregation_snapshot/1` @doc (line 312)
2. Add "Polling Frequency Recommendations" subsection
3. Provide guidance for different use cases:
   - LiveView: 500-1000ms
   - Logs/metrics: 5-10 seconds
   - Dashboards: 2-5 seconds
4. Warn against polling too frequently (<100ms)

**Code location**: Line 312-352 (within existing @doc)

**Success Criteria**:
- Clear guidance on polling frequencies
- Use-case specific recommendations
- Warning about performance impact of excessive polling
- Existing examples are preserved

---

### Step 6: Enhance pause_pipeline/1 and resume_pipeline/1 Documentation
**Duration**: 30 minutes
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Locate `pause_pipeline/1` @doc (line 242)
2. Add "Circuit Breaker Pattern" subsection
3. Include example of memory-based circuit breaker
4. Explain common use cases:
   - Memory threshold exceeded
   - Downstream system unavailable
   - Manual intervention for debugging
5. Update `resume_pipeline/1` @doc with reference to pause docs

**Code locations**:
- Line 242-251: `pause_pipeline/1`
- Line 257-264: `resume_pipeline/1`

**Success Criteria**:
- Circuit breaker pattern clearly explained
- Practical example code that works
- Common use cases documented
- Cross-reference between pause/resume functions

---

### Step 7: Review and Polish Documentation
**Duration**: 30 minutes
**Files**: `lib/ash_reports/typst/streaming_pipeline.ex`

**Actions**:
1. Read through entire moduledoc for flow and consistency
2. Check that all code examples are syntactically correct
3. Verify terminology is consistent throughout
4. Ensure no typos or grammatical errors
5. Verify all links and references are valid
6. Check formatting (indentation, markdown)

**Checklist**:
- [ ] All code examples compile
- [ ] Terminology consistent (e.g., "pipeline" vs "stream")
- [ ] No typos or grammatical errors
- [ ] Section headers follow consistent style
- [ ] Examples are realistic and helpful
- [ ] Internal/external boundaries are clear

**Success Criteria**:
- Documentation reads smoothly from start to finish
- No compilation warnings or errors
- Code examples are copy-paste ready
- Professional quality documentation

---

### Step 8: Generate and Review Documentation
**Duration**: 30 minutes
**Files**: N/A (command line)

**Actions**:
1. Generate ExDoc documentation: `mix docs`
2. Open generated HTML in browser
3. Review StreamingPipeline module page:
   - Check moduledoc renders correctly
   - Verify code examples have syntax highlighting
   - Ensure section headers create table of contents
   - Check that @doc false functions are hidden
4. Test navigation and links
5. Check mobile responsiveness (if applicable)

**Commands**:
```bash
# Generate docs
mix docs

# Open in browser (Linux)
xdg-open doc/index.html

# Verify @doc false functions are hidden
grep -A3 "Private Functions" doc/AshReports.Typst.StreamingPipeline.html
# Should show no content (functions hidden)
```

**Success Criteria**:
- ExDoc generates without errors
- Documentation renders correctly in browser
- Code examples have proper syntax highlighting
- @doc false functions do not appear in generated docs
- Navigation and links work correctly

---

### Step 9: Update Planning Documents
**Duration**: 20 minutes
**Files**:
- `planning/unified_streaming_implementation.md`
- `notes/features/stage1-2-1-streaming-pipeline-docs.md` (this file)

**Actions**:
1. Mark Section 1.2.1 as complete in unified plan
2. Add "Completed" timestamp to this planning document
3. Document any deviations from original plan
4. Add notes about what worked well
5. Add notes about challenges encountered
6. Update "Next Steps" section

**Success Criteria**:
- Planning documents reflect completion status
- Deviations and learnings documented
- Next steps clearly identified (Section 2.1.1)

---

### Step 10: Final Validation
**Duration**: 30 minutes
**Files**: All modified files

**Actions**:
1. Run full test suite: `mix test`
2. Run formatter: `mix format --check-formatted`
3. Run Credo: `mix credo --strict`
4. Verify no compilation warnings: `mix compile --warnings-as-errors`
5. Check documentation completeness:
   ```bash
   # Check that all public functions have docs
   grep "^  def " lib/ash_reports/typst/streaming_pipeline.ex | wc -l
   # Should be 9 (all public functions)

   grep "@doc \"\"\"" lib/ash_reports/typst/streaming_pipeline.ex | wc -l
   # Should be 10 (9 public + 1 moduledoc)
   ```

**Validation Checklist**:
- [ ] All tests pass (currently 53/53 Typst tests)
- [ ] Code formatted correctly
- [ ] No Credo warnings
- [ ] No compilation warnings
- [ ] All public functions documented
- [ ] All internal functions marked @doc false
- [ ] ExDoc generates successfully

**Success Criteria**:
- All automated checks pass
- Documentation is complete and accurate
- Ready for code review and merge

---

## Success Criteria

### Functional Requirements

**✅ Complete when**:

1. **Internal Functions Marked**: All 14 private helper functions have `@doc false`
   - `get_current_aggregation_state/2`
   - `calculate_progress_percentage/1`
   - `get_producer_consumer_pid/1`
   - `fetch_required/2`
   - `extract_metadata/1`
   - `create_stream/2`
   - `default_chunk_size/0`
   - `default_max_demand/0`
   - `start_pipeline_stages/5`
   - `get_pipeline_supervisor/1`
   - `start_producer_stage/3`
   - `start_producer_consumer_stage/7`
   - `start_single_worker/6`
   - `start_partitioned_workers/6`

2. **Usage Scenarios Added**: 5 comprehensive scenarios in moduledoc:
   - Monitoring long-running reports
   - Phoenix LiveView progress updates
   - Error handling and retry
   - Optimal partition count configuration
   - Pipeline dashboard

3. **Public API Summary Added**: Clear categorization of 9 public functions:
   - Pipeline Lifecycle (2)
   - Pipeline Monitoring (3)
   - Pipeline Control (2)
   - Aggregation Results (2)

4. **Enhanced Function Documentation**: 4 functions have enhanced docs:
   - `start_pipeline/1` - Partition count best practices
   - `get_aggregation_snapshot/1` - Polling frequency recommendations
   - `pause_pipeline/1` - Circuit breaker pattern
   - `resume_pipeline/1` - Cross-reference to pause

### Non-Functional Requirements

**✅ Complete when**:

1. **Documentation Quality**:
   - All code examples are syntactically correct
   - Terminology is consistent throughout
   - No typos or grammatical errors
   - Professional quality writing

2. **Documentation Completeness**:
   - All 9 public functions documented
   - All 14 internal functions marked @doc false
   - ExDoc generates without errors
   - Generated docs render correctly in browser

3. **Documentation Usability**:
   - Easy to find answers to common questions
   - Examples are copy-paste ready
   - Clear boundaries between public and internal APIs
   - Suitable for external developers unfamiliar with codebase

### Validation Checklist

Before marking section 1.2.1 as complete, verify:

- [ ] All 14 internal functions marked with @doc false
- [ ] 5 usage scenarios added to moduledoc
- [ ] Public API summary section added
- [ ] Enhanced docs for 4 key functions
- [ ] All code examples compile and are correct
- [ ] ExDoc generates successfully
- [ ] All tests pass (53/53 Typst tests)
- [ ] Code formatted correctly
- [ ] No Credo warnings
- [ ] No compilation warnings
- [ ] Code review completed
- [ ] Planning documents updated
- [ ] Ready for merge to develop branch

---

## Notes

### Dependencies

**Requires**:
- ✅ Stage 1.1.1: Shared DataLoader Interface (Complete)
- ✅ Stage 1.1.2: Streaming Consumer Protocol (Complete)
- ✅ Stage 1.1.3: Typst.DataLoader Refactor (Complete)

**Blocks**:
- Stage 2.1.1: HTML Streaming Consumer Implementation
- Stage 3.1.1: JSON Streaming Consumer Implementation
- Stage 4.1.1: HEEX Streaming Consumer Implementation

### Implementation Considerations

1. **No Code Changes**: This is purely documentation work, no functional changes:
   - Only adding `@doc false` annotations
   - Only enhancing existing documentation
   - No behavior changes

2. **Backward Compatibility**: Not applicable since no API changes

3. **Testing**: No new tests needed since no code changes:
   - Existing 53 Typst tests should still pass
   - Documentation examples should be validated manually

4. **Documentation Format**: Follow existing patterns:
   - Use triple-quoted strings for @moduledoc and @doc
   - Use markdown formatting (headers, code blocks, lists)
   - Include @spec for all public functions
   - Use @doc false for internal functions

5. **Code Examples**: All examples should be:
   - Syntactically correct Elixir code
   - Realistic and useful
   - Copy-paste ready
   - Aligned with actual API behavior

### Future Enhancements

After section 1.2.1 is complete, consider:

1. **Video Walkthrough**: Create screencast demonstrating pipeline monitoring
2. **Cookbook**: Separate document with more complex examples
3. **API Guides**: Per-use-case guides (e.g., "Building a Pipeline Dashboard")
4. **Telemetry Guide**: Detailed guide on telemetry events and metrics
5. **Performance Tuning Guide**: In-depth guide on partition_count and buffer tuning

### Related Documentation

- Planning document: `/home/ducky/code/ash_reports/planning/unified_streaming_implementation.md`
- StreamingPipeline module: `/home/ducky/code/ash_reports/lib/ash_reports/typst/streaming_pipeline.ex`
- Streaming.DataLoader: `/home/ducky/code/ash_reports/lib/ash_reports/streaming/data_loader.ex`
- StreamingConsumer protocol: `/home/ducky/code/ash_reports/lib/ash_reports/streaming/consumer.ex`
- Section 1.1.1 completion: Commit b2a7719
- Section 1.1.2 completion: Commit 8034add

### Documentation Style Guide

Follow these conventions for consistency:

**Headers**:
- Use `##` for top-level sections in moduledoc
- Use `###` for subsections within @doc
- Keep headers concise (< 60 chars)

**Code Examples**:
- Use 4-space indentation for code blocks
- Include comments for clarity
- Show both setup and usage
- Include expected output when helpful

**Lists**:
- Use `-` for unordered lists
- Use numbers for ordered lists/steps
- Keep list items concise (1-2 lines)

**Terminology**:
- "pipeline" for StreamingPipeline instances
- "stream" for Elixir streams returned by start_pipeline/1
- "chunk" for batches of records
- "aggregation" for streaming aggregations
- "partition" for parallel workers

**Cross-References**:
- Link to other functions using backticks: `start_pipeline/1`
- Reference configuration keys: `:partition_count`
- Reference modules with full path: `AshReports.Typst.DataLoader`

---

**Planning Document Complete** - Ready for implementation.
