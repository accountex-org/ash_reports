# Feature Planning: Replace Manual Pagination with Ash.stream! in AshReports

## Executive Summary

**Feature Name**: Ash.stream! Integration for Data Loading
**Priority**: High
**Estimated Effort**: 3-4 weeks (120-160 hours)
**Impact**: Performance optimization, code simplification, improved scalability
**Status**: 🚧 In Progress - Phase 1: Foundation

This feature replaces the current manual offset/limit pagination streaming implementation in AshReports with Ash Framework's native `Ash.stream!` function. This change will eliminate O(n²) performance degradation, reduce codebase complexity, and leverage Ash's optimized keyset pagination strategy for better performance with large datasets.

## Current Status

### ✅ Completed
- Feature branch created: `feature/ash-stream-integration`
- Planning document created and saved
- Research completed on Ash.stream! capabilities

### 🚧 In Progress
- Phase 1: Foundation work starting

### ⏭️ Next Steps
1. Refactor Executor.stream_query to use Ash.stream!
2. Remove manual offset/limit logic
3. Write unit tests

## Problem Statement

### Current Implementation Issues

The current streaming implementation in `lib/ash_reports/data_loader/executor.ex` uses manual offset/limit pagination:

```elixir
# Current approach (lines 444-464)
defp fetch_next_chunk(state, chunk_size, executor, opts) do
  query_with_limit =
    state.query
    |> Ash.Query.limit(chunk_size)
    |> Ash.Query.offset(state.offset)  # O(n²) performance!

  case execute_query(executor, query_with_limit, state.domain, opts) do
    {:ok, %{records: records}} when length(records) < chunk_size ->
      updated_state = %{state | finished?: true}
      {[records], updated_state}
    # ...
  end
end
```

**Key Problems:**

1. **O(n²) Performance**: Each chunk requires the database to skip all previous records (OFFSET 0, OFFSET 1000, OFFSET 2000...), causing exponential slowdown with large datasets
2. **Documentation Mismatch**: Code comments claim to use GenStage but the actual implementation uses `Stream.resource` with manual pagination
3. **Code Duplication**: Pagination logic is replicated across multiple modules
4. **Missed Optimizations**: Ash.stream! provides keyset pagination which maintains O(n) performance regardless of dataset size
5. **Memory Management Complexity**: Custom memory monitoring could be simplified with Ash's native streaming

### Impact on Users

- Reports with 100K+ records experience significant slowdowns (minutes vs seconds)
- Memory usage is higher than necessary due to manual chunking overhead
- Developers maintaining the code face unnecessary complexity

## Solution Overview

### Proposed Architecture

Replace manual pagination with `Ash.stream!` throughout the data loading pipeline:

**Before**:
```
QueryBuilder → Manual offset/limit loop → Stream.resource → Processing
```

**After**:
```
QueryBuilder → Ash.stream! (keyset pagination) → Processing
```

### Key Benefits

1. **Performance**: O(n) keyset pagination vs O(n²) offset pagination
2. **Simplification**: Remove ~200 lines of manual pagination code
3. **Native Integration**: Leverage Ash's built-in optimizations
4. **Memory Efficiency**: Ash.stream! handles batching internally with optimal strategies
5. **Flexibility**: Support keyset, offset, and full_read strategies based on data layer capabilities

### Strategy Selection

Ash.stream! supports three strategies:

- **:keyset** (default, recommended): Uses cursor-based pagination for O(n) performance
- **:offset**: Falls back to offset pagination when keyset is unavailable
- **:full_read**: Loads entire result set (for small datasets or when streaming isn't supported)

The implementation will default to `:keyset` with automatic fallback based on data layer capabilities.

## Technical Design

### Architecture Components

#### 1. Executor Module Refactoring

**File**: `lib/ash_reports/data_loader/executor.ex`

**Changes**:
- Replace `stream_query/4` implementation with `Ash.stream!` wrapper
- Remove manual offset/limit logic (lines 428-469)
- Simplify stream initialization and cleanup
- Add strategy selection logic

**New Implementation**:
```elixir
def stream_query(_executor, query, domain, opts \\ []) do
  batch_size = Keyword.get(opts, :stream_chunk_size, @default_batch_size)
  strategy = Keyword.get(opts, :stream_strategy, :keyset)

  Ash.stream!(
    query,
    batch_size: batch_size,
    stream_with: strategy,
    domain: domain,
    actor: Keyword.get(opts, :actor),
    timeout: Keyword.get(opts, :timeout, @default_timeout)
  )
end
```

#### 2. DataLoader Module Updates

**File**: `lib/ash_reports/data_loader/data_loader.ex`

**Changes**:
- Update `stream_report/3` to use new Executor streaming
- Simplify stream creation logic
- Remove references to offset-based pagination

### Error Handling

**Strategy Fallback Logic**:
1. Attempt with `:keyset` (default)
2. On failure, try `:offset` if allowed
3. On failure, try `:full_read` if allowed
4. Return error if all strategies fail

**Error Types to Handle**:
- `Ash.Error.Invalid.NoPrimaryKey` - Keyset requires primary key
- `Ash.Error.Invalid.NoSuchResource` - Resource not found
- `Ash.Error.Forbidden` - Authorization failure
- Database-specific pagination errors

### Testing Strategy

#### Unit Tests

1. **Executor Tests** (`test/ash_reports/data_loader/executor_test.exs`)
   - Stream creation with different strategies
   - Batch size configuration
   - Error handling and fallbacks
   - Memory usage validation

2. **Integration Tests**
   - End-to-end streaming with large datasets
   - Strategy selection and fallback
   - Performance benchmarking
   - Memory profiling

#### Performance Tests

**Expected Results**:
- Keyset: ~2x faster than manual offset for 100K records
- Memory: Similar or better efficiency
- Throughput: 5000+ records/second

## Implementation Plan

### Phase 1: Foundation (Week 1)

**Tasks**:
1. ✅ Create feature branch: `feature/ash-stream-integration`
2. ✅ Save planning document
3. 🚧 Add Ash.stream! wrapper in Executor module
4. ⏭️ Implement strategy selection logic
5. ⏭️ Write unit tests for new streaming functions

**Deliverables**:
- Working Ash.stream! implementation in Executor
- 20+ unit tests
- Configuration documentation

**Success Criteria**:
- All new tests pass
- Existing tests still pass
- Performance benchmark shows improvement

### Phase 2: Integration (Week 2)

**Tasks**:
1. Update DataLoader to use new Executor streaming
2. Update all call sites across codebase
3. Add deprecation warnings for old API (if keeping parallel impl)
4. Write integration tests

**Deliverables**:
- Updated DataLoader module
- End-to-end integration tests
- Performance benchmarks

**Success Criteria**:
- All test files pass
- Performance improvement demonstrated
- Memory usage optimal

### Phase 3: Documentation and Cleanup (Week 3)

**Tasks**:
1. Update all module documentation
2. Write migration guide
3. Create performance comparison charts
4. Remove old offset/limit code
5. Update CHANGELOG and README

**Deliverables**:
- Complete documentation update
- Performance analysis report
- Clean codebase

**Success Criteria**:
- Documentation covers all use cases
- Performance gains documented

## Success Criteria

### Functional Requirements

- [ ] Ash.stream! successfully replaces manual pagination in Executor
- [ ] All streaming strategies (:keyset, :offset, :full_read) work correctly
- [ ] Automatic strategy fallback functions as designed
- [ ] All existing tests pass
- [ ] Backward compatibility maintained

### Performance Requirements

- [ ] 2x performance improvement for 100K+ record datasets
- [ ] Memory usage ≤ current implementation
- [ ] Throughput ≥ 5000 records/second
- [ ] Keyset pagination shows O(n) scaling
- [ ] No performance regression for small datasets

### Code Quality Requirements

- [ ] Remove at least 100 lines of manual pagination code
- [ ] Test coverage ≥ 90% for new streaming code
- [ ] No Credo warnings introduced
- [ ] Dialyzer passes with no new warnings
- [ ] Documentation complete and accurate

## Risks and Mitigation

### Risk 1: Data Layer Compatibility

**Risk**: Some data layers may not support keyset pagination
**Impact**: Medium
**Mitigation**:
- Implement automatic fallback to :offset or :full_read
- Test with ETS, Postgres, and other common data layers
- Document data layer requirements clearly

### Risk 2: Performance Regression

**Risk**: Ash.stream! may introduce unexpected overhead
**Impact**: High
**Mitigation**:
- Comprehensive benchmarking before rollout
- Performance monitoring in testing
- Rollback plan ready

### Risk 3: Breaking Changes

**Risk**: API changes may break existing code
**Impact**: Medium
**Mitigation**:
- Maintain backward compatibility where possible
- Clear migration documentation
- Test with demo app

## Alternatives Considered

### Alternative 1: Keep Manual Pagination, Optimize Implementation

**Pros**: Less code change risk, Known behavior
**Cons**: Still O(n²) performance, Doesn't leverage Ash optimizations
**Decision**: Rejected - doesn't solve fundamental performance issue

### Alternative 2: Implement Custom Keyset Pagination

**Pros**: Full control over implementation
**Cons**: Significant effort, Duplicate work that Ash provides
**Decision**: Rejected - unnecessary reinvention

## References

### Documentation

- [Ash.stream! Documentation](https://hexdocs.pm/ash/Ash.html#stream!/2)
- [Ash Streaming Guide](https://hexdocs.pm/ash/code-interfaces.html)
- [Elixir Streams](https://hexdocs.pm/elixir/Stream.html)

### Internal Documents

- Current implementation: `lib/ash_reports/data_loader/executor.ex`

---

**Document Version**: 1.0
**Created**: 2025-11-17
**Last Updated**: 2025-11-17
**Status**: 🚧 In Progress - Phase 1
