# Unified GenStage Streaming Pipeline Implementation Plan

**Duration**: 5 weeks (160-200 hours)
**Goal**: Unify streaming data loading across all renderers (PDF, HTML, HEEX, JSON)

## Overview

This plan implements a shared GenStage streaming pipeline that all renderers can use,
eliminating code duplication and enabling consistent streaming behavior across the
entire AshReports system.

## Current Status

### ✅ Completed

**Stage 1.1.1: Extract Core from Typst.DataLoader** (Section 1.1)

- Created `lib/ash_reports/streaming/data_loader.ex` (498 lines)
- Refactored `lib/ash_reports/typst/data_loader.ex` (reduced 643 → 320 lines, 50% reduction)
- All Typst tests passing (streaming_mvp_test.exs: 16/16, data_loader_integration_test.exs: 17/17)
- Commit: b2a7719

**Stage 1.1.2: Create Streaming Consumer Protocol** (Section 1.1)

- Created `lib/ash_reports/streaming/consumer.ex` (470 lines)
- Defined `StreamingConsumer` behavior with `consume_chunk/2` and `finalize/1` callbacks
- Implemented buffering helper for batching chunks
- Implemented error handling wrapper with retry support
- Implemented progress tracking helper
- Created comprehensive test suite: 30/30 tests passing
- Branch: `feature/stage1-1-2-streaming-consumer-protocol`
- Commit: 8034add

**Stage 1.1.3: Refactor Typst.DataLoader** (Section 1.1)
- Reduced `lib/ash_reports/typst/data_loader.ex` from 330 → 181 lines (45% reduction)
- Streamlined moduledoc to focus on Typst-specific features
- Updated test assertions to match streamlined documentation
- Maintained backward compatibility with deprecated functions
- All Typst tests passing: 53/53
- Branch: `feature/stage1-1-3-typst-dataloader-refactor`

### 🔄 In Progress

None

### 📋 Pending

See detailed stages below

## Stage 1: Core Infrastructure (Week 1)

**Duration**: 1 week (32-40 hours)
**Goal**: Create shared data loading interface and streaming consumer protocol
**Priority**: FOUNDATION - Required for all renderer integrations

### 1.1 Shared DataLoader Interface

#### ✅ 1.1.1 Extract Core from Typst.DataLoader

**Duration**: 8-12 hours
**Files**: Create `lib/ash_reports/streaming/data_loader.ex` (new)

**Completed Tasks**:

- [x] Create new AshReports.Streaming.DataLoader module
  - [x] Extract streaming logic from `lib/ash_reports/typst/data_loader.ex`
  - [x] Make domain/renderer agnostic
  - [x] Keep Typst.DataLoader as thin wrapper
  - [x] Test: Existing PDF rendering still works

**Success Criteria**:

- ✅ Typst.DataLoader delegates to Streaming.DataLoader
- ✅ All existing Typst tests pass
- ✅ Code reduction in Typst.DataLoader (50% achieved)

#### ✅ 1.1.2 Create Streaming Consumer Protocol

**Duration**: 6-8 hours
**Files**: Create `lib/ash_reports/streaming/consumer.ex` (new)

**Completed Tasks**:

- [x] Define StreamingConsumer behavior
  - [x] `consume_chunk/2` callback - Process a chunk of streamed data
  - [x] `finalize/1` callback - Finalize after all chunks consumed
- [x] Create helper functions for common patterns
  - [x] Buffering helper for batching chunks
  - [x] Error handling wrapper with retry support
  - [x] Progress tracking helper
- [x] Write comprehensive tests (30 tests created, all passing)

**Success Criteria**:

- ✅ StreamingConsumer behavior is well-documented
- ✅ Helper functions cover common use cases
- ✅ Tests demonstrate correct usage patterns

#### ✅ 1.1.3 Refactor Typst.DataLoader to Use Shared Components
**Duration**: 8-12 hours
**Files**: Refactor `lib/ash_reports/typst/data_loader.ex`

**Completed Tasks**:
- [x] Update Typst.DataLoader to use Streaming.DataLoader
  - [x] Remove duplicated streaming logic
  - [x] Keep Typst-specific chart preprocessing
  - [x] Maintain backward compatibility
  - [x] Test: All Typst tests still pass

**Success Criteria**: ✅ All Met
- ✅ Typst.DataLoader is 181 lines (< 200 target)
- ✅ All Typst tests pass (53/53)
- ✅ Chart preprocessing still works
- ✅ Backward compatible API (deprecated functions maintained)

### 1.2 StreamingPipeline Interface Cleanup

#### 📋 1.2.1 Document StreamingPipeline Public API

**Duration**: 4-6 hours
**Files**: Update `lib/ash_reports/typst/streaming_pipeline.ex`

**Tasks**:

- [ ] Add comprehensive moduledoc
- [ ] Document all public functions
- [ ] Add usage examples
- [ ] Mark internal functions as @doc false

**Success Criteria**:

- Clear documentation for external consumers
- Examples for common scenarios
- Internal functions clearly marked

## Stage 2: HTML Renderer Integration (Week 2)

**Duration**: 1 week (32-40 hours)
**Goal**: Integrate HTML renderer with streaming pipeline
**Depends On**: Stage 1 complete

### 2.1 HTML Streaming Consumer

#### 📋 2.1.1 Implement HtmlRenderer.StreamingConsumer

**Duration**: 12-16 hours
**Files**: Create `lib/ash_reports/renderers/html_renderer/streaming_consumer.ex`

**Tasks**:

- [ ] Implement StreamingConsumer behavior for HTML
  - [ ] consume_chunk/2: Convert records to HTML fragments
  - [ ] finalize/1: Wrap fragments in complete HTML document
  - [ ] Handle CSS generation during finalization
  - [ ] Test: Generate valid HTML from streamed chunks

**Success Criteria**:

- HTML fragments generated incrementally
- Complete HTML document at finalization
- CSS properly included
- Tests verify streaming behavior

#### 📋 2.1.2 Integrate with HtmlRenderer

**Duration**: 8-12 hours
**Files**: Update `lib/ash_reports/renderers/html_renderer.ex`

**Tasks**:

- [ ] Add streaming support to HtmlRenderer
  - [ ] render_with_context/2 uses Streaming.DataLoader
  - [ ] Support both in-memory and streaming modes
  - [ ] Maintain backward compatibility
  - [ ] Test: Existing HTML tests pass + new streaming tests

**Success Criteria**:

- HTML renderer supports streaming
- In-memory mode still available
- All existing tests pass
- New streaming tests added

### 2.2 HTML Streaming Tests

#### 📋 2.2.1 Create HTML Streaming Test Suite

**Duration**: 8-12 hours
**Files**: Create `test/ash_reports/renderers/html_renderer/streaming_test.exs`

**Tasks**:

- [ ] Test streaming with large datasets
- [ ] Test buffering behavior
- [ ] Test error handling during streaming
- [ ] Test progress tracking
- [ ] Performance: Memory usage stays constant

**Success Criteria**:

- Comprehensive streaming test coverage
- Memory usage verified < 1.5x baseline
- Error scenarios covered
- Performance benchmarks pass

## Stage 3: JSON Renderer Integration (Week 3)

**Duration**: 1 week (32-40 hours)
**Goal**: Integrate JSON renderer with streaming pipeline
**Depends On**: Stage 1 complete

### 3.1 JSON Streaming Consumer

#### 📋 3.1.1 Remove Duplicate JsonRenderer.StreamingEngine

**Duration**: 4-6 hours
**Files**: Delete `lib/ash_reports/renderers/json_renderer/streaming_engine.ex`

**Tasks**:

- [ ] Identify all usages of JsonRenderer.StreamingEngine
- [ ] Plan migration to Streaming.DataLoader
- [ ] Remove StreamingEngine module
- [ ] Update JsonRenderer to use Streaming.DataLoader

**Success Criteria**:

- StreamingEngine module deleted
- JsonRenderer uses shared streaming
- All JSON tests still pass
- Code duplication eliminated

#### 📋 3.1.2 Implement JsonRenderer.StreamingConsumer

**Duration**: 8-12 hours
**Files**: Create `lib/ash_reports/renderers/json_renderer/streaming_consumer.ex`

**Tasks**:

- [ ] Implement StreamingConsumer behavior for JSON
  - [ ] consume_chunk/2: Convert records to JSON fragments
  - [ ] finalize/1: Wrap fragments in complete JSON document
  - [ ] Handle JSON array formatting
  - [ ] Test: Generate valid JSON from streamed chunks

**Success Criteria**:

- JSON fragments generated incrementally
- Valid JSON array at finalization
- Proper comma handling between chunks
- Tests verify streaming behavior

#### 📋 3.1.3 Integrate with JsonRenderer

**Duration**: 8-12 hours
**Files**: Update `lib/ash_reports/renderers/json_renderer.ex`

**Tasks**:

- [ ] Update JsonRenderer to use new streaming
  - [ ] Remove old streaming code
  - [ ] Use Streaming.DataLoader
  - [ ] Maintain backward compatibility
  - [ ] Test: All JSON tests pass

**Success Criteria**:

- JSON renderer uses shared streaming
- Old streaming code removed
- All existing tests pass
- New streaming tests added

## Stage 4: HEEX Renderer Integration (Week 3)

**Duration**: 1 week (32-40 hours)
**Goal**: Integrate HEEX renderer with streaming pipeline
**Depends On**: Stage 1 complete
**Parallel With**: Stage 3 (can be done concurrently)

### 4.1 HEEX Streaming Consumer

#### 📋 4.1.1 Implement HeexRenderer.StreamingConsumer

**Duration**: 12-16 hours
**Files**: Create `lib/ash_reports/renderers/heex_renderer/streaming_consumer.ex`

**Tasks**:

- [ ] Implement StreamingConsumer behavior for HEEX
  - [ ] consume_chunk/2: Generate HEEX fragments
  - [ ] finalize/1: Combine fragments for LiveView
  - [ ] Handle component state updates
  - [ ] Test: Generate valid HEEX from streamed chunks

**Success Criteria**:

- HEEX fragments generated incrementally
- LiveView integration works
- Component state properly managed
- Tests verify streaming behavior

#### 📋 4.1.2 Integrate with HeexRenderer

**Duration**: 8-12 hours
**Files**: Update `lib/ash_reports/renderers/heex_renderer.ex`

**Tasks**:

- [ ] Add streaming support to HeexRenderer
  - [ ] render_with_context/2 uses Streaming.DataLoader
  - [ ] Support LiveView updates during streaming
  - [ ] Maintain backward compatibility
  - [ ] Test: All HEEX tests pass

**Success Criteria**:

- HEEX renderer supports streaming
- LiveView updates work correctly
- All existing tests pass
- New streaming tests added

## Stage 5: Integration & Testing (Week 4)

**Duration**: 1 week (32-40 hours)
**Goal**: Comprehensive integration testing and documentation
**Depends On**: Stages 2, 3, 4 complete

### 5.1 Cross-Renderer Integration Tests

#### 📋 5.1.1 Create Multi-Renderer Streaming Tests

**Duration**: 12-16 hours
**Files**: Create `test/ash_reports/integration/streaming_test.exs`

**Tasks**:

- [ ] Test all renderers with same dataset
- [ ] Verify consistent behavior across renderers
- [ ] Test error handling across renderers
- [ ] Test memory usage across renderers
- [ ] Performance: All renderers meet targets

**Success Criteria**:

- All renderers produce correct output
- Memory usage consistent
- Error handling consistent
- Performance targets met

### 5.2 Documentation

#### 📋 5.2.1 Create Streaming Usage Guide

**Duration**: 8-12 hours
**Files**: Create `guides/streaming.md`

**Tasks**:

- [ ] Document streaming architecture
- [ ] Provide examples for each renderer
- [ ] Document StreamingConsumer behavior
- [ ] Document helper functions
- [ ] Migration guide from old APIs

**Success Criteria**:

- Clear usage examples
- All renderers documented
- Migration path clear
- Best practices included

## Stage 6: Performance Optimization (Week 5)

**Duration**: 1 week (32-40 hours)
**Goal**: Optimize streaming performance and memory usage
**Depends On**: Stage 5 complete

### 6.1 Memory Optimization

#### 📋 6.1.1 Optimize Buffer Sizes

**Duration**: 8-12 hours
**Files**: Update streaming modules

**Tasks**:

- [ ] Benchmark different buffer sizes
- [ ] Implement adaptive buffering
- [ ] Add memory monitoring
- [ ] Test: Memory stays within limits

**Success Criteria**:

- Memory usage < 1.5x baseline
- Adaptive buffering works
- Monitoring in place

### 6.2 Throughput Optimization

#### 📋 6.2.1 Optimize Record Processing

**Duration**: 8-12 hours
**Files**: Update renderer streaming consumers

**Tasks**:

- [ ] Profile record processing
- [ ] Optimize hot paths
- [ ] Add parallel processing where possible
- [ ] Test: Throughput meets targets

**Success Criteria**:

- Throughput > 1000 records/sec
- Hot paths optimized
- Parallel processing where beneficial

## Stage 7: Documentation (Week 5)

**Duration**: 1 week (16-24 hours)
**Goal**: Complete documentation and examples
**Depends On**: Stage 6 complete
**Parallel With**: Stage 6 (can overlap)

### 7.1 API Documentation

#### 📋 7.1.1 Complete Module Documentation

**Duration**: 8-12 hours
**Files**: All streaming modules

**Tasks**:

- [ ] Complete all @moduledoc
- [ ] Complete all @doc
- [ ] Add @typedoc for all types
- [ ] Add examples to all public functions

**Success Criteria**:

- All public modules documented
- All public functions documented
- Examples for common scenarios

### 7.2 Examples

#### 📋 7.2.1 Create Example Applications

**Duration**: 8-12 hours
**Files**: Create `examples/streaming/`

**Tasks**:

- [ ] Example: Streaming HTML report
- [ ] Example: Streaming JSON API
- [ ] Example: Streaming HEEX LiveView
- [ ] Example: Custom StreamingConsumer

**Success Criteria**:

- Working examples for each renderer
- Examples demonstrate best practices
- README for each example

## Success Metrics

### Performance Targets

- [ ] Memory usage < 1.5x baseline for large datasets
- [ ] Throughput > 1000 records/second
- [ ] Latency < 100ms for first chunk

### Code Quality Targets

- [ ] Test coverage > 90% for new code
- [ ] All renderers use shared streaming
- [ ] No code duplication in streaming logic
- [ ] < 200 lines per renderer streaming consumer

### Documentation Targets

- [ ] All public APIs documented
- [ ] Usage guide complete
- [ ] Migration guide complete
- [ ] Working examples for all renderers

## Risks & Mitigation

### Risk: Breaking Changes to Existing APIs

**Mitigation**: Maintain backward compatibility, deprecate old APIs gradually

### Risk: Performance Regression

**Mitigation**: Continuous benchmarking, performance tests in CI

### Risk: Memory Leaks in Streaming

**Mitigation**: Memory monitoring, leak detection tests, proper cleanup

### Risk: Renderer-Specific Edge Cases

**Mitigation**: Comprehensive testing per renderer, integration tests

## Timeline Summary

| Week | Stage | Focus |
|------|-------|-------|
| 1 | Stage 1 | Core Infrastructure ✅ Section 1.1.1, ✅ Section 1.1.2 |
| 2 | Stage 2 | HTML Renderer Integration |
| 3 | Stage 3 & 4 | JSON & HEEX Renderer Integration (parallel) |
| 4 | Stage 5 | Integration & Testing |
| 5 | Stage 6 & 7 | Performance & Documentation (parallel) |

## Next Steps

**Current**: Stage 1.1 Complete (Shared DataLoader Interface)
**Next**: Stage 1.2.1 - Document StreamingPipeline Public API

**Immediate Actions**:
1. Add comprehensive moduledoc to StreamingPipeline
2. Document all public functions with examples
3. Mark internal functions as @doc false
