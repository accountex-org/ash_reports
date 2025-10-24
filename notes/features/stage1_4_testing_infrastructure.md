# Stage 1 - Section 1.4: Integration Testing Infrastructure

**Feature**: Section 1.4 of Stage 1 - Typst Integration Testing Infrastructure
**Status**: 📋 Planned
**Priority**: High (Critical for production readiness and regression prevention)
**Dependencies**:
  - Stage 1 Section 1.1 (Typst Runtime) ✅ COMPLETED
  - Stage 1 Section 1.2 (DSL Generator) ✅ COMPLETED
  - Stage 1 Section 1.3 (Data Integration) ✅ COMPLETED
**Target Completion**: 1-2 weeks
**Branch**: `feature/stage1-4-testing-infrastructure`

---

## 📋 Executive Summary

Section 1.4 implements comprehensive testing infrastructure specifically for Typst PDF generation capabilities. This includes rendering test helpers, performance benchmarking, visual regression testing, mock data generators, and memory monitoring to ensure the Typst integration is production-ready, performant, and maintainable.

### Problem Statement

The current Typst integration (Sections 1.1-1.3) has basic unit tests but lacks:

1. **Testing Gaps**:
   - No visual regression testing for PDF output changes
   - Limited performance benchmarking for compilation speed
   - No memory usage monitoring for large reports
   - Insufficient mock data generation for complex scenarios
   - No standardized rendering test helpers

2. **Production Readiness Concerns**:
   - Cannot detect PDF rendering regressions automatically
   - Unknown performance characteristics for large datasets
   - Risk of memory leaks in long-running processes
   - Difficult to reproduce edge cases without proper test data

3. **Maintenance Challenges**:
   - Hard to validate Typst template changes don't break output
   - No baseline metrics for performance degradation detection
   - Manual testing required for visual correctness
   - Limited test coverage for complex report scenarios

### Solution Overview

Implement a comprehensive testing infrastructure with five key components:

1. **Typst Rendering Test Helpers**: Reusable utilities for PDF compilation testing
2. **Performance Benchmarking**: Automated compilation speed measurement with baselines
3. **Visual Regression Testing**: PDF output comparison for detecting rendering changes
4. **Mock Data Generators**: Property-based testing data for complex scenarios
5. **Memory Usage Monitoring**: Heap tracking and leak detection for large reports

### Key Benefits

- **Confidence in Changes**: Automated detection of rendering regressions
- **Performance Baseline**: Measurable compilation speed targets (target: <500ms for simple reports)
- **Production Safety**: Memory leak detection before deployment
- **Rapid Development**: Rich mock data generation for all test scenarios
- **Documentation**: Test helpers serve as usage examples

---

## 🎯 Architecture Design

### System Context

The testing infrastructure integrates with existing test support:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AshReports Test Suite                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │            Existing Test Support                            │ │
│  │  • test/support/test_helpers.ex                             │ │
│  │  • test/support/test_resources.ex                           │ │
│  │  • test/support/integration/integration_test_helpers.ex     │ │
│  │  • test/support/integration/benchmark_helpers.ex            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │      NEW: Typst Testing Infrastructure                      │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  TypstTestHelpers                                     │  │ │
│  │  │  • compile_and_validate/2                             │  │ │
│  │  │  • assert_pdf_valid/1                                 │  │ │
│  │  │  • extract_pdf_text/1                                 │  │ │
│  │  │  • compare_pdf_structure/2                            │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  TypstBenchmarkHelpers                                │  │ │
│  │  │  • benchmark_compilation/2                            │  │ │
│  │  │  • run_typst_benchmark_suite/0                        │  │ │
│  │  │  • validate_performance_targets/1                     │  │ │
│  │  │  • generate_performance_report/1                      │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  TypstVisualRegression                                │  │ │
│  │  │  • capture_pdf_snapshot/2                             │  │ │
│  │  │  • compare_with_baseline/2                            │  │ │
│  │  │  • generate_visual_diff/2                             │  │ │
│  │  │  • update_baseline/2                                  │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  TypstDataGenerators                                  │  │ │
│  │  │  • generate_complex_report/1                          │  │ │
│  │  │  • generate_nested_groups/2                           │  │ │
│  │  │  • generate_large_dataset/1                           │  │ │
│  │  │  • generate_edge_case_data/0                          │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  TypstMemoryMonitor                                   │  │ │
│  │  │  • measure_memory_usage/1                             │  │ │
│  │  │  • track_compilation_memory/2                         │  │ │
│  │  │  • assert_memory_within_limit/2                       │  │ │
│  │  │  • detect_memory_leaks/1                              │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                  Typst Testing Workflow                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Test Case                                                        │
│       ↓                                                           │
│  TypstDataGenerators.generate_complex_report/1                   │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Test Execution                                          │    │
│  │  ┌────────────────────────────────────────────────────┐ │    │
│  │  │  TypstMemoryMonitor.measure_memory_usage/1         │ │    │
│  │  │       ↓                                             │ │    │
│  │  │  TypstTestHelpers.compile_and_validate/2           │ │    │
│  │  │       ↓                                             │ │    │
│  │  │  BinaryWrapper.compile/2                           │ │    │
│  │  │       ↓                                             │ │    │
│  │  │  [PDF Binary Output]                               │ │    │
│  │  └────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────┘    │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Validation Layer                                        │    │
│  │  • TypstTestHelpers.assert_pdf_valid/1                  │    │
│  │  • TypstVisualRegression.compare_with_baseline/2        │    │
│  │  • TypstBenchmarkHelpers.validate_performance_targets/1 │    │
│  │  • TypstMemoryMonitor.assert_memory_within_limit/2      │    │
│  └─────────────────────────────────────────────────────────┘    │
│       ↓                                                           │
│  Test Results + Metrics                                          │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Agent Consultations Performed

### Research Areas

1. **Elixir Testing Best Practices**
   - ExUnit property-based testing with StreamData
   - Benchee for performance measurement
   - Memory profiling with `:recon` and `:observer`
   - Test organization patterns

2. **Visual Regression Testing**
   - PDF comparison strategies (text extraction vs. image diff)
   - Baseline management patterns
   - Snapshot testing approaches
   - Tools: pdftotext, pdf-diff libraries

3. **Performance Benchmarking**
   - Benchee configuration and reporting
   - Baseline establishment methodology
   - Performance regression detection
   - CI integration patterns

4. **Mock Data Generation**
   - StreamData generators for complex structures
   - Property-based testing patterns
   - Edge case enumeration
   - Deterministic randomness for reproducibility

5. **Memory Monitoring**
   - BEAM memory measurement APIs
   - Leak detection strategies
   - Profiling large dataset scenarios
   - Memory limit assertions

### Key Findings

- **PDF Testing**: Text extraction is more reliable than image diffing for Typst PDFs
- **Benchmarking**: Benchee's built-in memory measurement is sufficient for most cases
- **Visual Regression**: Store PDF metadata hashes and text content for comparison
- **Data Generation**: StreamData works well with Ash resource structures
- **Memory**: `:erlang.memory()` provides sufficient granularity for testing

---

## 🛠 Technical Details

### File Structure

```
test/
├── support/
│   └── typst/
│       ├── typst_test_helpers.ex           # Main rendering test helpers
│       ├── typst_benchmark_helpers.ex      # Performance benchmarking
│       ├── typst_visual_regression.ex      # Visual regression testing
│       ├── typst_data_generators.ex        # Mock data generation
│       └── typst_memory_monitor.ex         # Memory usage monitoring
│
└── ash_reports/
    └── typst/
        ├── integration_test.exs            # End-to-end integration tests
        ├── performance_test.exs            # Performance benchmarks
        ├── visual_regression_test.exs      # Visual regression suite
        ├── memory_test.exs                 # Memory usage tests
        └── stress_test.exs                 # Stress testing (large datasets)

test/fixtures/
└── typst/
    ├── baselines/                          # Visual regression baselines
    │   ├── simple_report.baseline.json
    │   ├── complex_report.baseline.json
    │   └── grouped_report.baseline.json
    └── templates/                          # Test template samples
        ├── minimal.typ
        ├── standard.typ
        └── complex.typ
```

### Dependencies

Already in `mix.exs`:
- `{:benchee, "~> 1.3", only: [:dev, :test]}` ✅
- `{:benchee_html, "~> 1.0", only: [:dev, :test]}` ✅
- `{:stream_data, "~> 1.0"}` ✅
- `{:mox, "~> 1.1", only: :test}` ✅

Potential additions:
- `{:briefly, "~> 0.5", only: :test}` - Temporary file management
- `{:recon, "~> 2.5", only: [:dev, :test]}` - BEAM introspection (optional)

### Integration Points

1. **BinaryWrapper** (`lib/ash_reports/typst/binary_wrapper.ex`):
   - Test helpers wrap `compile/2` and `compile_file/2`
   - Monitor timeout handling and error reporting
   - Validate NIF stability under stress

2. **DSLGenerator** (`lib/ash_reports/typst/dsl_generator.ex`):
   - Generate test templates for various report structures
   - Validate template syntax correctness
   - Test complex band hierarchies

3. **DataLoader** (`lib/ash_reports/typst/data_loader.ex`):
   - Mock data integration for testing
   - Validate data transformation correctness
   - Test error handling with invalid data

4. **Existing Test Infrastructure**:
   - Extend `BenchmarkHelpers` pattern for Typst-specific benchmarks
   - Integrate with existing `TestHelpers` for report generation
   - Reuse test resource infrastructure

---

## ✅ Success Criteria

### 1. Typst Rendering Test Helpers

- [x] **Compilation Helpers**:
  - `compile_and_validate/2` successfully compiles templates and returns validated PDFs
  - `assert_pdf_valid/1` correctly identifies valid vs. invalid PDFs
  - `extract_pdf_text/1` reliably extracts text content for assertions

- [x] **Error Handling**:
  - Graceful handling of compilation failures
  - Clear error messages for debugging
  - Timeout handling for long compilations

- [x] **Documentation**:
  - All helper functions documented with examples
  - Usage patterns demonstrated in integration tests

### 2. Performance Benchmarking

- [x] **Baseline Targets**:
  - Simple report (1 page, 10 records): <500ms compilation
  - Medium report (5 pages, 100 records): <2s compilation
  - Large report (20 pages, 1000 records): <10s compilation

- [x] **Benchmark Suite**:
  - Automated benchmarks for common scenarios
  - HTML reports generated in `tmp/` directory
  - Performance regression detection (>20% slowdown fails tests)

- [x] **CI Integration**:
  - Performance tests tagged appropriately (`:benchmark`, `:slow`)
  - Optional execution in CI (not blocking by default)
  - Trend tracking over time

### 3. Visual Regression Testing

- [x] **Baseline Management**:
  - Baseline snapshots stored in `test/fixtures/typst/baselines/`
  - Update mechanism for intentional changes
  - Version control friendly (JSON format)

- [x] **Comparison Logic**:
  - Text content comparison (character-level accuracy)
  - PDF structure comparison (page count, metadata)
  - Configurable tolerance for minor variations

- [x] **Diff Reporting**:
  - Clear reports when regressions detected
  - Visual diff output for debugging
  - Easy baseline update workflow

### 4. Mock Data Generators

- [x] **Generator Coverage**:
  - Simple reports (single band, <10 records)
  - Complex reports (multiple bands, nested groups)
  - Large datasets (1000+ records)
  - Edge cases (empty data, missing fields, unicode)

- [x] **StreamData Integration**:
  - Property-based test generators for reports
  - Deterministic randomness (seeded for reproducibility)
  - Type-safe data generation matching Ash schemas

- [x] **Ease of Use**:
  - Simple API: `TypstDataGenerators.generate_complex_report(seed: 123)`
  - Predefined scenarios for common cases
  - Composable generators for custom scenarios

### 5. Memory Usage Monitoring

- [x] **Memory Tracking**:
  - Accurate measurement of compilation memory usage
  - Baseline memory usage documented
  - Memory growth detection for large reports

- [x] **Leak Detection**:
  - Multiple compilation cycles tested
  - Memory cleanup validation after compilations
  - Alert on memory growth >1.5x baseline

- [x] **Limits and Assertions**:
  - `assert_memory_within_limit/2` enforces memory budgets
  - Configurable limits per report size
  - Clear failure messages with actual vs. expected

### Overall Quality Metrics

- **Test Coverage**: 90%+ coverage for Typst modules
- **Performance**: All benchmarks meet baseline targets
- **Stability**: No flaky tests in visual regression suite
- **Documentation**: Complete test helper documentation
- **CI Time**: Test suite completes in <5 minutes (excluding benchmarks)

---

## 📝 Implementation Plan

### Phase 1: Foundation - Typst Test Helpers (Week 1, Days 1-2)

**Objective**: Create core rendering test utilities that all other tests will use.

**Tasks**:
1. Create `test/support/typst/typst_test_helpers.ex`
2. Implement core helpers:
   ```elixir
   # Compilation and validation
   def compile_and_validate(template, opts \\ [])
   def assert_pdf_valid(pdf_binary)
   def assert_compilation_succeeds(template, opts \\ [])
   def assert_compilation_fails(template, expected_error)

   # Content extraction
   def extract_pdf_text(pdf_binary)
   def extract_pdf_metadata(pdf_binary)
   def count_pdf_pages(pdf_binary)

   # Comparison utilities
   def assert_pdf_contains(pdf_binary, expected_text)
   def assert_pdf_page_count(pdf_binary, expected_count)
   def compare_pdf_structure(pdf1, pdf2)
   ```
3. Add PDF text extraction via shell command (`pdftotext` or similar)
4. Write unit tests for helpers themselves
5. Document usage patterns with examples

**Deliverables**:
- ✅ `typst_test_helpers.ex` with documented API
- ✅ Test coverage for helper functions
- ✅ Integration test demonstrating usage

**Testing Integration**:
- Update existing `test/ash_reports/typst/binary_wrapper_test.exs` to use new helpers
- Refactor `test/ash_reports/typst/dsl_generator_test.exs` to use helpers

---

### Phase 2: Performance Benchmarking (Week 1, Days 3-4)

**Objective**: Establish performance baselines and automated benchmark suite.

**Tasks**:
1. Create `test/support/typst/typst_benchmark_helpers.ex`
2. Implement benchmark scenarios:
   ```elixir
   def run_typst_benchmark_suite(opts \\ [])
   def benchmark_compilation(scenario_name, template, data, opts \\ [])
   def validate_performance_targets(results)
   def generate_performance_report(results)
   ```
3. Define benchmark scenarios:
   - Simple report (1 page, 10 records)
   - Medium report (5 pages, 100 records)
   - Large report (20 pages, 1000 records)
   - Complex template (nested groups, aggregates)
4. Establish performance baselines
5. Create `test/ash_reports/typst/performance_test.exs`
6. Configure Benchee for HTML report generation

**Deliverables**:
- ✅ Benchmark helper module with reusable functions
- ✅ Performance test suite with baseline targets
- ✅ HTML benchmark reports in `tmp/typst_benchmarks/`
- ✅ Documentation of performance targets

**Performance Targets**:
```elixir
@performance_targets %{
  simple_report: %{max_time_ms: 500, max_memory_mb: 10},
  medium_report: %{max_time_ms: 2000, max_memory_mb: 25},
  large_report: %{max_time_ms: 10000, max_memory_mb: 100},
  complex_template: %{max_time_ms: 3000, max_memory_mb: 30}
}
```

---

### Phase 3: Visual Regression Testing (Week 1, Day 5 - Week 2, Day 1)

**Objective**: Detect unintended PDF rendering changes automatically.

**Tasks**:
1. Create `test/support/typst/typst_visual_regression.ex`
2. Implement visual regression API:
   ```elixir
   def capture_pdf_snapshot(pdf_binary, snapshot_name)
   def compare_with_baseline(pdf_binary, baseline_name)
   def generate_visual_diff(current, baseline)
   def update_baseline(pdf_binary, baseline_name)
   def list_baselines()
   def cleanup_old_baselines(keep_count)
   ```
3. Design baseline storage format:
   ```json
   {
     "name": "simple_report",
     "version": "1.0.0",
     "created_at": "2025-10-01T12:00:00Z",
     "metadata": {
       "page_count": 1,
       "file_size": 12345,
       "checksum": "sha256:abc123..."
     },
     "text_content": "extracted text...",
     "structure": {
       "pages": [...],
       "fonts": [...],
       "images": []
     }
   }
   ```
4. Create baseline fixtures in `test/fixtures/typst/baselines/`
5. Implement comparison logic (text diff, structure comparison)
6. Create `test/ash_reports/typst/visual_regression_test.exs`
7. Add baseline update mechanism (Mix task or env var)

**Deliverables**:
- ✅ Visual regression helper module
- ✅ Baseline fixture files for key scenarios
- ✅ Visual regression test suite
- ✅ Baseline update workflow documentation

**Test Scenarios**:
- Simple single-page report
- Multi-page report with page headers/footers
- Grouped report with nested groups
- Report with aggregates and expressions
- RTL/LTR layout variations

---

### Phase 4: Mock Data Generators (Week 2, Days 2-3)

**Objective**: Generate comprehensive test data for all scenarios.

**Tasks**:
1. Create `test/support/typst/typst_data_generators.ex`
2. Implement StreamData generators:
   ```elixir
   # Report structure generators
   def report_generator(opts \\ [])
   def band_generator(type, opts \\ [])
   def element_generator(type, opts \\ [])

   # Data generators
   def generate_complex_report(opts \\ [])
   def generate_nested_groups(depth, records_per_group)
   def generate_large_dataset(record_count)
   def generate_edge_case_data()

   # Specific scenario generators
   def simple_sales_report(record_count \\ 10)
   def financial_report_with_aggregates(record_count \\ 50)
   def multi_level_grouped_report(group_levels \\ 3)
   ```
3. Add deterministic seeding for reproducibility
4. Create property-based tests using generators:
   ```elixir
   property "generated reports compile successfully" do
     check all report <- report_generator(), max_runs: 100 do
       assert {:ok, _pdf} = compile_report(report)
     end
   end
   ```
5. Document generator usage patterns
6. Add edge case generators (empty, null, unicode, large numbers)

**Deliverables**:
- ✅ Data generator module with StreamData integration
- ✅ Property-based test examples
- ✅ Edge case coverage
- ✅ Generator documentation with examples

**Generator Coverage**:
- ✅ All band types (title, detail, group_header, group_footer, etc.)
- ✅ All element types (field, label, expression, aggregate, etc.)
- ✅ Various data sizes (10, 100, 1000, 10000 records)
- ✅ Unicode and internationalization scenarios
- ✅ Edge cases (empty, missing, invalid data)

---

### Phase 5: Memory Usage Monitoring (Week 2, Days 4-5)

**Objective**: Track memory usage and detect leaks in Typst compilation.

**Tasks**:
1. Create `test/support/typst/typst_memory_monitor.ex`
2. Implement memory monitoring API:
   ```elixir
   def measure_memory_usage(fun)
   def track_compilation_memory(template, data, opts \\ [])
   def assert_memory_within_limit(memory_used, limit)
   def detect_memory_leaks(compilation_count \\ 100)
   def profile_large_report(record_count)
   def memory_growth_report()
   ```
3. Add BEAM memory measurement:
   ```elixir
   defp capture_memory_snapshot() do
     %{
       total: :erlang.memory(:total),
       processes: :erlang.memory(:processes),
       binary: :erlang.memory(:binary),
       ets: :erlang.memory(:ets),
       atom: :erlang.memory(:atom)
     }
   end
   ```
4. Create `test/ash_reports/typst/memory_test.exs`
5. Define memory limits for scenarios:
   ```elixir
   @memory_limits %{
     simple_report: 10 * 1024 * 1024,      # 10MB
     medium_report: 25 * 1024 * 1024,      # 25MB
     large_report: 100 * 1024 * 1024,      # 100MB
     stress_test: 500 * 1024 * 1024        # 500MB
   }
   ```
6. Implement leak detection (multiple compilations, check for growth)
7. Create memory profiling reports

**Deliverables**:
- ✅ Memory monitor module
- ✅ Memory test suite
- ✅ Memory limit assertions
- ✅ Leak detection tests
- ✅ Memory profiling documentation

**Memory Test Scenarios**:
- Single compilation memory usage
- Multiple compilations (no leak)
- Large dataset compilation (1000+ records)
- Concurrent compilations
- NIF memory management validation

---

### Phase 6: Integration and Documentation (Week 2, Day 5)

**Objective**: Integrate all testing infrastructure and create comprehensive documentation.

**Tasks**:
1. Create `test/ash_reports/typst/integration_test.exs`:
   - End-to-end tests using all helpers
   - Complex scenarios combining multiple features
   - Stress tests with large datasets
2. Create `test/ash_reports/typst/stress_test.exs`:
   - 10,000+ record compilation
   - Concurrent compilation tests
   - Memory stress testing
3. Update existing tests to use new infrastructure:
   - `binary_wrapper_test.exs` - Use test helpers
   - `dsl_generator_test.exs` - Use data generators
   - `data_loader_test.exs` - Use mock data
4. Configure test tags:
   ```elixir
   @moduletag :typst
   @tag :benchmark  # For performance tests
   @tag :slow       # For stress tests
   @tag :visual     # For visual regression tests
   ```
5. Update `mix.exs` test configuration:
   ```elixir
   # Run quick tests by default
   def aliases do
     [
       test: ["test --exclude benchmark --exclude slow --exclude visual"],
       "test.all": ["test --include benchmark --include slow --include visual"],
       "test.typst": ["test --only typst"],
       "test.bench": ["test --only benchmark"]
     ]
   end
   ```
6. Create documentation in test modules and README updates
7. Add CI configuration examples

**Deliverables**:
- ✅ Comprehensive integration tests
- ✅ Stress test suite
- ✅ Updated existing tests using new infrastructure
- ✅ Test configuration with tags
- ✅ Complete documentation
- ✅ CI integration examples

---

## 📌 Notes and Considerations

### Edge Cases

1. **PDF Text Extraction Reliability**:
   - Some Typst features may not extract cleanly to text
   - Consider visual image diffing for complex layouts
   - Fallback to structure comparison if text extraction fails

2. **Typst Version Compatibility**:
   - Baselines may change between Typst versions
   - Document Typst version in baseline metadata
   - Automated baseline regeneration on version upgrades

3. **Deterministic Rendering**:
   - Ensure timestamp/random data doesn't break visual regression
   - Use fixed seeds for random data in tests
   - Mock datetime for consistent output

4. **Performance Variance**:
   - CI environments may have different performance
   - Use percentage-based thresholds rather than absolute times
   - Warm-up runs before benchmarking

5. **Memory Measurement Accuracy**:
   - BEAM memory includes more than just compilation
   - Garbage collect before measurements
   - Use delta measurements (before/after)

### Performance Targets

Based on analysis of existing `BinaryWrapperTest` and typical Typst compilation:

- **Simple Report** (1 page, <10 records): 200-500ms
- **Medium Report** (5 pages, 100 records): 1-2s
- **Large Report** (20 pages, 1000 records): 5-10s
- **Complex Template** (nested groups, aggregates): 2-3s

Memory targets:
- **Baseline**: ~5-10MB (Typst NIF overhead)
- **Simple Report**: +5-10MB per compilation
- **Large Report**: +50-100MB for 1000+ records
- **Memory Leak Detection**: <10% growth over 100 compilations

### Testing Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Temporary files cleaned up in `on_exit` callbacks
3. **Seeding**: Use deterministic seeds for reproducible tests
4. **Tagging**: Proper test tags for selective execution
5. **Documentation**: Every helper function documented with examples

### Maintenance Considerations

1. **Baseline Updates**:
   - Establish workflow for intentional baseline updates
   - Version control baseline files
   - Document why baselines changed in commits

2. **Performance Degradation**:
   - Track benchmarks over time
   - Alert on >20% performance regressions
   - Investigate and document acceptable degradations

3. **Test Data Evolution**:
   - Keep generators in sync with DSL changes
   - Add new scenarios as features are added
   - Archive old baselines when formats change

4. **CI Resource Management**:
   - Benchmark tests optional or separate job
   - Stress tests only on main branch
   - Visual regression on feature branches

### Future Enhancements

1. **Advanced Visual Diffing**:
   - PDF to PNG conversion for image diffing
   - Highlight visual differences in HTML reports
   - Integration with visual regression services

2. **Performance Trend Analysis**:
   - Store benchmark results over time
   - Generate performance trend graphs
   - Automated performance regression alerts

3. **Property-Based Testing Expansion**:
   - Fuzz testing for template syntax
   - Random report generation and compilation
   - Exhaustive edge case enumeration

4. **Test Data Sharing**:
   - Export test data as fixtures for other tests
   - Shareable test scenarios across modules
   - Test data versioning

5. **Parallel Test Execution**:
   - Optimize test suite for parallelization
   - Isolated temporary directories per test
   - Concurrent compilation testing

---

## 🎓 Learning Resources

### Elixir Testing
- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [StreamData Guide](https://hexdocs.pm/stream_data/StreamData.html)
- [Property-Based Testing in Elixir](https://hexdocs.pm/stream_data/property_testing.html)

### Performance Testing
- [Benchee Documentation](https://hexdocs.pm/benchee/Benchee.html)
- [Benchee Best Practices](https://github.com/bencheeorg/benchee)
- [BEAM Memory Profiling](https://www.erlang.org/doc/man/erlang.html#memory-0)

### Visual Regression
- [PDF Text Extraction Approaches](https://pdfminer-docs.readthedocs.io/)
- [Snapshot Testing Patterns](https://jestjs.io/docs/snapshot-testing)
- [Visual Regression Testing Guide](https://percy.io/blog/visual-regression-testing)

### Memory Analysis
- [Erlang Memory Management](https://www.erlang.org/doc/efficiency_guide/memory.html)
- [BEAM Observability](https://ferd.ca/recon.html)
- [Memory Leak Detection](https://www.erlang.org/doc/efficiency_guide/profiling.html)

---

## ✅ Acceptance Checklist

Before marking this section complete, verify:

- [ ] All five component modules implemented and tested
- [ ] Test coverage >90% for Typst modules
- [ ] All performance targets met in benchmarks
- [ ] Visual regression baselines created and validated
- [ ] Memory tests pass with leak detection
- [ ] Documentation complete with examples
- [ ] CI integration configured
- [ ] Test suite runs in <5 minutes (excluding benchmarks)
- [ ] No flaky tests in regression suite
- [ ] Mix task aliases configured (`test.typst`, `test.bench`, etc.)

---

## 📊 Success Metrics

### Quantitative Metrics
- **Test Coverage**: 90%+ for Typst modules
- **Benchmark Count**: 15+ scenarios across performance ranges
- **Visual Baselines**: 10+ baseline scenarios
- **Generator Coverage**: 20+ edge case scenarios
- **CI Time**: <5 minutes for standard test suite

### Qualitative Metrics
- **Developer Confidence**: Team can make changes without fear of regressions
- **Documentation Quality**: New contributors can understand testing approach
- **Maintainability**: Tests are easy to update when requirements change
- **Production Readiness**: Memory and performance characteristics well-understood

---

**Planning Document Created**: 2025-10-01
**Last Updated**: 2025-10-01
**Status**: Ready for Implementation
