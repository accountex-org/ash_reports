# Stage 1.1: Test Suite Fixes - Implementation Plan

**Feature**: Fix Broken Test Suite (Section 1.1 from Code Review Implementation Plan)
**Stage**: Stage 1 - Critical Blockers
**Status**: 📋 Planned
**Priority**: CRITICAL - Blocks all other development
**Estimated Duration**: 15-21 hours (2-3 days)

---

## 1. Problem Statement

### Current Situation

The AshReports test suite is severely broken, blocking development and preventing reliable testing:

- **36/36 DSL tests failing** (100% failure rate)
- **135/135 entity tests failing** (91% failure rate)
- **3 test files with compilation errors** preventing test execution
- **Missing dependencies** causing compiler warnings and runtime failures
- **Struct definition mismatches** throughout test files
- **DSL test infrastructure issues** causing deadlocks and race conditions

### Impact on Development

1. **No Reliable Testing**: Cannot validate fixes or new features
2. **Development Blocked**: Cannot merge code without passing tests
3. **Regression Risk**: No safety net for refactoring
4. **CI/CD Broken**: Continuous integration fails on every commit
5. **Code Quality Unknown**: No coverage metrics or test validation

### Root Causes Identified

1. **Compilation Errors**:
   - Function arity mismatches in `pipeline_test.exs`
   - Missing LiveView imports in 2 test files

2. **Struct Mismatches**:
   - Tests expect `Label` with `x:` and `y:` fields
   - Actual struct uses `position: %{x:, y:}` map
   - Same issue affects Field, Box, Line elements

3. **Missing Dependencies**:
   - `:statistics` library already in mix.exs but not properly configured
   - `Timex.week_of_year/1` API change in newer versions

4. **DSL Test Infrastructure**:
   - `Code.eval_string` approach causes deadlocks
   - Temporary module compilation conflicts
   - Race conditions in concurrent tests

---

## 2. Solution Overview

### High-Level Approach

Fix issues in order of blocking severity:

1. **Fix Compilation Errors First** (enables test execution)
2. **Update Struct Definitions** (fixes entity tests)
3. **Verify Dependencies** (fixes library-related errors)
4. **Refactor DSL Testing** (fixes DSL test infrastructure)

### Key Principles

- **Incremental Validation**: Fix and test each category before moving to next
- **Minimal Changes**: Fix only what's broken, don't refactor unnecessarily
- **Clear Checkpoints**: After each fix, verify test count improvements
- **Document Learnings**: Note any patterns for future test writing

---

## 3. Agent Consultations Performed

### Elixir Expert Consultation

**Questions to Research**:
1. What are the best practices for LiveView component testing?
2. How to properly set up Phoenix.LiveViewTest imports?
3. What's the recommended approach for DSL testing without `Code.eval_string`?
4. How to handle function arity mismatches in test helper functions?

**Expected Guidance**:
- LiveView test setup requires proper `ConnCase` or test helpers
- Use `import Phoenix.LiveViewTest` for component testing
- Spark/DSL testing should use Spark.Test utilities directly
- Test helpers should match their call sites or use default parameters

### Research Agent Consultation

**Questions to Research**:
1. Is `:statistics` an Erlang library or Hex package?
2. What's the correct Timex API for week-of-year calculation?
3. Are there alternatives to `:statistics` if unavailable?
4. What version of Timex introduced the API change?

**Expected Findings**:
- `:statistics` is available on Hex (version 0.6.3 already in mix.exs)
- Timex v3.7+ may have changed `week_of_year/1` API
- Alternative: Implement percentile functions locally if needed
- Check Timex documentation for correct function signature

---

## 4. Technical Details

### 4.1 Compilation Error Fixes

#### File: `test/ash_reports/data_loader/pipeline_test.exs`

**Issue**: Function arity mismatches at lines 298, 335
```elixir
# Current (BROKEN):
with_mock_data_stream(mock_data) do  # Called with 1 arg
  # ...
end

# But defined as:
defp with_mock_stream(mock_data) do  # Line 385 - different name!
  mock_data
end

defp with_mock_data_stream(mock_data) do  # Line 391
  mock_data
end
```

**Root Cause**: Helper functions return the data directly but tests expect them to yield a block.

**Solution Options**:
1. **Option A**: Make helpers accept a block (recommended)
   ```elixir
   defp with_mock_data_stream(mock_data, fun) do
     fun.(mock_data)
   end
   ```

2. **Option B**: Remove the `do` block and use directly
   ```elixir
   mock_data = with_mock_data_stream(mock_data)
   assert {:ok, stream} = Pipeline.process_stream(config)
   ```

**Recommended**: Option B (simpler, clearer intent)

#### File: `test/ash_reports/live_view/chart_live_component_test.exs`

**Issue**: Missing imports at line 15
```elixir
use ExUnit.Case, async: true
import Phoenix.LiveViewTest  # Line 15 - missing implementation
```

**Solution**: Add proper LiveView test setup
```elixir
use ExUnit.Case, async: true

# Conditional import only if phoenix_live_view available
if Code.ensure_loaded?(Phoenix.LiveViewTest) do
  import Phoenix.LiveViewTest
else
  # Skip tests if LiveView not available
  @moduletag :skip
end
```

**Alternative**: Create `test/support/live_view_case.ex` for shared setup

#### File: `test/ash_reports/live_view/accessibility_test.exs`

**Issue**: Same as chart_live_component_test.exs
**Solution**: Apply same fix pattern

### 4.2 Struct Definition Mismatches

#### Files Affected

Search results show usage in:
- `test/ash_reports/heex_renderer/helpers_test.exs`
- `test/ash_reports/heex_renderer_test.exs`
- `test/ash_reports/heex_renderer/components_test.exs`
- `test/ash_reports/heex_renderer/live_view_integration_test.exs`
- `test/support/test_helpers.ex` (lines 107, 174)

#### Current Struct Definition (Correct)

From `lib/ash_reports/element/label.ex`:
```elixir
defstruct [
  :name,
  :text,
  :position,  # Map, not individual x/y fields
  :style,     # Map, not individual style fields
  :conditional,
  type: :label
]
```

#### Test Pattern (Incorrect)

```elixir
# BROKEN:
%Label{name: :test_label, x: 10, y: 20}

# CORRECT:
%Label{name: :test_label, position: %{x: 10, y: 20}}

# OR using keyword list (auto-converted):
Label.new(:test_label, position: [x: 10, y: 20])
```

#### Fix Strategy

1. Search for all `%Label{.*x:.*y:` patterns
2. Replace with `position: %{x:, y:}` structure
3. Search for Field, Box, Line with same pattern
4. Update test_helpers.ex build functions (lines 107, 174)

### 4.3 Dependency Verification

#### Statistics Library

**Current Status**: Already in mix.exs (line 85)
```elixir
{:statistics, "~> 0.6.3"},
```

**Files Using It**: `lib/ash_reports/charts/statistics.ex`

**Action Required**:
1. Verify `mix deps.get` downloads it correctly
2. Check if it's in `deps/` directory
3. If missing, check for Hex availability
4. If unavailable, implement local percentile calculations

**Usage Locations** (from statistics.ex):
- Line 134: percentile calculations
- Line 208, 210: variance/std_dev
- Line 253, 255: quartile calculations

#### Timex Library

**Current Status**: Already in mix.exs (line 86)
```elixir
{:timex, "~> 3.7"},
```

**Issue**: `Timex.week_of_year/1` may be undefined

**Action Required**:
1. Check Timex documentation for v3.7
2. Test current API: `Timex.week_of_year/1`
3. If deprecated, replace with: `Timex.iso_week/1` or `Timex.format/2`
4. Alternative: Use Elixir's built-in `Date.iso_week/1`

**Reference**: `lib/ash_reports/charts/time_series.ex:309`

### 4.4 DSL Test Infrastructure

#### Current Implementation (Problematic)

From `test/support/test_helpers.ex` lines 20-45:
```elixir
def parse_dsl(dsl_content, extension \\ AshReports) do
  module_name = :"TestModule#{:rand.uniform(999_999)}"

  try do
    Code.eval_string("""
    defmodule #{module_name} do
      use Ash.Domain, extensions: [#{extension}]

      #{dsl_content}
    end
    """)

    dsl_state = Extension.get_persisted(module_name, :dsl_state)
    {:ok, dsl_state}
  rescue
    error -> {:error, error}
  after
    # Cleanup
  end
end
```

**Problems**:
1. `Code.eval_string` can cause deadlocks in concurrent tests
2. Module name collisions possible despite randomization
3. Cleanup not always effective
4. Doesn't properly isolate test state

#### Recommended Solution

**Option 1**: Use Spark Testing Utilities (if available)
```elixir
def parse_dsl(dsl_content, extension \\ AshReports) do
  # Use Spark.Test if available
  Spark.Test.parse_dsl(extension, dsl_content)
end
```

**Option 2**: Improve Current Approach
```elixir
def parse_dsl(dsl_content, extension \\ AshReports) do
  # Use System.unique_integer for truly unique names
  module_name = :"TestModule_#{System.unique_integer([:positive, :monotonic])}"

  # Use compile-time evaluation instead of Code.eval_string
  quoted = Code.string_to_quoted!("""
    defmodule #{module_name} do
      use Ash.Domain, extensions: [#{extension}]
      #{dsl_content}
    end
  """)

  # Better isolation
  Code.compile_quoted(quoted)

  # Extract state
  dsl_state = Spark.Dsl.Extension.get_persisted(module_name, :dsl)
  {:ok, dsl_state}
rescue
  error -> {:error, error}
after
  # More thorough cleanup
  :code.purge(module_name)
  :code.delete(module_name)
end
```

**Option 3**: Pre-compile Test Modules
```elixir
# In test/support/test_reports.ex
defmodule TestReports.SimpleReport do
  use Ash.Domain, extensions: [AshReports]

  reports do
    report :simple do
      title "Simple Report"
      driving_resource TestResource
    end
  end
end

# Then in tests, use directly
test "simple report works" do
  report = TestReports.SimpleReport.simple()
  assert report.title == "Simple Report"
end
```

**Recommendation**: Start with Option 3 for common test cases, use improved Option 2 for dynamic testing

---

## 5. Success Criteria

### 5.1 Compilation Fixes

- [ ] All 3 test files compile without errors
- [ ] `mix compile --warnings-as-errors` succeeds
- [ ] `mix test --only compilation` passes (if such tag exists)

**Verification Command**:
```bash
mix compile --force --warnings-as-errors
```

### 5.2 Struct Fixes

- [ ] All entity tests pass (currently 135 failing)
- [ ] No `KeyError` exceptions for missing fields
- [ ] Element instantiation follows current struct definition

**Verification Command**:
```bash
mix test test/ash_reports/heex_renderer/ --only element
```

### 5.3 Dependency Verification

- [ ] `:statistics` library functions work
- [ ] No compiler warnings about missing modules
- [ ] Timex functions resolve correctly
- [ ] All chart statistics calculations work

**Verification Commands**:
```bash
mix deps.get
mix deps.compile statistics
iex -S mix
> Statistics.median([1,2,3,4,5], :value)
> Timex.iso_week(Date.utc_today())
```

### 5.4 DSL Test Infrastructure

- [ ] DSL tests pass rate improves from 0% to >80%
- [ ] No deadlocks when running `mix test test/ash_reports/dsl_test.exs`
- [ ] Tests can run with `async: true` without conflicts
- [ ] No orphaned modules after test completion

**Verification Commands**:
```bash
mix test test/ash_reports/dsl_test.exs --trace
mix test test/ash_reports/entities/ --trace
```

### 5.5 Overall Test Health

**Before**:
- Compilation errors: 3 files
- Failing tests: 171+ (DSL + entity tests)
- Test suite executable: No

**After**:
- Compilation errors: 0
- Failing tests: <30 (target >80% pass rate)
- Test suite executable: Yes

**Verification Command**:
```bash
mix test --slowest 10
```

---

## 6. Implementation Plan

### Phase 1: Fix Compilation Errors (2-3 hours)

**Step 1.1**: Fix `pipeline_test.exs` arity issues
```bash
# 1. Open file
code test/ash_reports/data_loader/pipeline_test.exs

# 2. Find lines 298, 335
# 3. Remove `do` blocks from with_mock_data_stream calls
# 4. Use returned mock_data directly

# Before:
with_mock_data_stream(mock_data) do
  assert {:ok, stream} = Pipeline.process_stream(config)
  results = stream |> Enum.take(2)
  assert length(results) <= 2
end

# After:
_mock_data = with_mock_data_stream(mock_data)
assert {:ok, stream} = Pipeline.process_stream(config)
results = stream |> Enum.take(2)
assert length(results) <= 2
```

**Step 1.2**: Fix LiveView test imports
```bash
# 1. Create test/support/live_view_case.ex if not exists
# 2. Add conditional LiveView imports
# 3. Update both test files to use the case template
```

**Checkpoint**: Run `mix compile --warnings-as-errors`
- Should succeed with no errors
- Proceed to Phase 2

### Phase 2: Fix Struct Definitions (3-4 hours)

**Step 2.1**: Search and identify all struct issues
```bash
# Find all Label instantiations with old pattern
grep -rn "%Label{.*x:.*y:" test/

# Find all Field instantiations
grep -rn "%Field{.*x:.*y:" test/

# Find all Box, Line patterns
grep -rn "%Box{.*x:.*y:" test/
grep -rn "%Line{.*x:.*y:" test/
```

**Step 2.2**: Fix test_helpers.ex first (foundation)
```elixir
# Line 107 - build_simple_report
%AshReports.Element.Label{
  name: :title_label,
  text: title,
  position: %{x: 0, y: 0}  # Changed from position: [x: 0, y: 0]
}

# Line 174 - build_complex_report
%AshReports.Element.Label{
  name: :title_label,
  text: title,
  position: %{x: 0, y: 0}
}
```

**Step 2.3**: Fix test files systematically
```bash
# For each file found in Step 2.1:
# 1. Replace %Label{x: X, y: Y} with %Label{position: %{x: X, y: Y}}
# 2. Same for Field, Box, Line
# 3. Run tests for that file after each fix
```

**Step 2.4**: Use element constructors where possible
```elixir
# Instead of:
%Label{name: :test, text: "Test", position: %{x: 10, y: 20}}

# Prefer:
Label.new(:test, text: "Test", position: [x: 10, y: 20])
# The new/2 function handles keyword-to-map conversion
```

**Checkpoint**: Run entity tests
```bash
mix test test/ash_reports/heex_renderer/helpers_test.exs
mix test test/ash_reports/heex_renderer_test.exs
```
- Entity tests should now pass
- Proceed to Phase 3

### Phase 3: Verify Dependencies (1-2 hours)

**Step 3.1**: Verify Statistics library
```bash
# Clean and reinstall
mix deps.clean statistics
mix deps.get
mix deps.compile statistics

# Test in IEx
iex -S mix
> alias AshReports.Charts.Statistics
> test_data = [%{value: 10}, %{value: 20}, %{value: 30}]
> Statistics.median(test_data, :value)
# Should return: 20.0
```

**Step 3.2**: Check Timex API
```bash
# Check Timex version
mix hex.info timex

# Test current API
iex -S mix
> Timex.week_of_year(Date.utc_today())
# If undefined, try:
> Timex.iso_week(Date.utc_today())
# Or use Elixir built-in:
> Date.iso_week(Date.utc_today())
```

**Step 3.3**: Fix Timex usage if needed
```elixir
# In lib/ash_reports/charts/time_series.ex:309
# Replace:
week = Timex.week_of_year(date)

# With (if needed):
{year, week} = Date.iso_week(date)
# OR
week = Timex.iso_week(date) |> elem(1)
```

**Checkpoint**: Run statistics tests
```bash
mix test test/ash_reports/charts/ --only statistics
```
- Statistics calculations should work
- No compiler warnings about missing functions
- Proceed to Phase 4

### Phase 4: Refactor DSL Testing (8-10 hours)

**Step 4.1**: Research Spark testing patterns
```bash
# Check if Spark provides test utilities
grep -rn "Spark.Test" deps/spark/

# Check Spark documentation
mix hex.docs fetch spark
mix hex.docs open spark
# Look for testing section
```

**Step 4.2**: Create pre-compiled test report modules
```elixir
# Create test/support/test_reports.ex
defmodule AshReports.TestReports do
  @moduledoc "Pre-compiled test reports for testing"

  defmodule SimpleDomain do
    use Ash.Domain, extensions: [AshReports]

    reports do
      report :simple do
        title "Simple Report"
        driving_resource AshReports.Test.Customer
      end
    end
  end

  defmodule ComplexDomain do
    use Ash.Domain, extensions: [AshReports]

    reports do
      report :complex do
        title "Complex Report"
        driving_resource AshReports.Test.Order

        parameters do
          parameter :start_date, :date, required: true
        end

        bands do
          band :title, :title do
            element :title_label, :label do
              text "Complex Report"
              position x: 0, y: 0
            end
          end
        end
      end
    end
  end

  # Factory functions for common test scenarios
  def simple_report_config do
    SimpleDomain.__ash_reports_config__()
  end
end
```

**Step 4.3**: Improve parse_dsl for dynamic cases
```elixir
# In test/support/test_helpers.ex
def parse_dsl(dsl_content, extension \\ AshReports) do
  # Use monotonic unique integer for truly unique names
  unique_id = System.unique_integer([:positive, :monotonic])
  module_name = :"TestDslModule_#{unique_id}_#{:erlang.phash2(dsl_content)}"

  # Parse to quoted form first
  code = """
  defmodule #{inspect(module_name)} do
    use Ash.Domain, extensions: [#{inspect(extension)}]

    #{dsl_content}
  end
  """

  try do
    # Compile in isolated environment
    [{^module_name, _binary}] = Code.compile_string(code)

    # Extract DSL state
    dsl_state = Spark.Dsl.Extension.get_persisted(module_name, :dsl)

    {:ok, dsl_state}
  rescue
    error -> {:error, error}
  after
    # Cleanup compiled module
    if Code.ensure_loaded?(module_name) do
      :code.purge(module_name)
      :code.delete(module_name)
    end
  end
end
```

**Step 4.4**: Update DSL tests to use new patterns
```elixir
# For simple, static tests - use pre-compiled modules
test "simple report parsing" do
  report = AshReports.TestReports.SimpleDomain.simple()
  assert report.title == "Simple Report"
end

# For dynamic tests - use improved parse_dsl
test "validates required fields" do
  dsl_content = """
  reports do
    report :test do
      # Missing required driving_resource
      title "Test"
    end
  end
  """

  assert {:error, error} = parse_dsl(dsl_content)
  assert error.message =~ "required"
end
```

**Step 4.5**: Make tests run serially if needed
```elixir
# In test/ash_reports/dsl_test.exs
# Change from:
use ExUnit.Case, async: true

# To (if deadlocks persist):
use ExUnit.Case, async: false

# Or use semaphore for controlled concurrency
```

**Checkpoint**: Run DSL tests
```bash
# Run with tracing to see execution
mix test test/ash_reports/dsl_test.exs --trace

# Run entity tests
mix test test/ash_reports/entities/ --trace

# Check for deadlocks or timeouts
timeout 30 mix test test/ash_reports/dsl_test.exs
```
- Tests should complete without hanging
- Pass rate should be >80%
- No orphaned modules in memory

### Phase 5: Validation and Documentation (1-2 hours)

**Step 5.1**: Run full test suite
```bash
# Run all tests
mix test

# Get coverage
MIX_ENV=test mix coveralls.html

# Check for warnings
mix compile --warnings-as-errors

# Run with multiple seeds to check for flakiness
mix test --seed 0
mix test --seed 42
mix test --seed 12345
```

**Step 5.2**: Document fixes and learnings
```markdown
# Create notes/test-suite-fixes-summary.md

## Fixes Applied

1. **Compilation Errors**
   - Fixed pipeline_test.exs arity issues by removing do blocks
   - Added LiveView test setup with conditional imports

2. **Struct Definitions**
   - Updated all element instantiations to use position: %{x:, y:}
   - Total files updated: X
   - Pattern: Old pattern -> New pattern

3. **Dependencies**
   - Verified :statistics library working
   - Updated Timex API usage (if needed)

4. **DSL Testing**
   - Created pre-compiled test modules for common cases
   - Improved parse_dsl with better isolation
   - Approach: [document approach taken]

## Test Results

Before:
- Compilation errors: 3
- Failing tests: 171
- Pass rate: ~20%

After:
- Compilation errors: 0
- Failing tests: X
- Pass rate: Y%

## Learnings

1. [Document key learnings]
2. [Patterns to avoid]
3. [Best practices for future tests]
```

**Step 5.3**: Update test writing guidelines
```markdown
# Add to test/support/README.md (create if needed)

## Test Writing Guidelines

### Element Instantiation
Always use position maps, not individual x/y fields:
```elixir
# Good
%Label{position: %{x: 10, y: 20}}
Label.new(:test, position: [x: 10, y: 20])

# Bad
%Label{x: 10, y: 20}
```

### DSL Testing
For static tests, use pre-compiled modules:
```elixir
test "static test" do
  report = TestReports.SimpleDomain.simple()
  assert report.title == "Simple"
end
```

For dynamic validation tests, use parse_dsl:
```elixir
test "validation test" do
  assert {:error, _} = parse_dsl("invalid dsl")
end
```

### LiveView Testing
Requires optional dependency check:
```elixir
if Code.ensure_loaded?(Phoenix.LiveViewTest) do
  import Phoenix.LiveViewTest
end
```
```

**Checkpoint**: Final validation
- All checkpoints from Section 5 (Success Criteria) pass
- Documentation updated
- Ready for Stage 1.2

---

## 7. Notes and Considerations

### Edge Cases

1. **Concurrent Test Execution**
   - DSL tests may need to run serially to avoid conflicts
   - Use `async: false` if deadlocks persist after refactoring
   - Consider ExUnit semaphores for controlled concurrency

2. **Optional Dependencies**
   - LiveView tests should gracefully skip if phoenix_live_view not installed
   - Use `@moduletag :skip` when dependencies unavailable
   - Document which tests require which optional deps

3. **Module Cleanup**
   - Ensure all temporary modules are purged after tests
   - Watch for memory leaks in long test runs
   - May need to force garbage collection in cleanup

### Risks

1. **DSL Test Refactoring Scope**
   - Estimated 8-10 hours might be insufficient if Spark.Test doesn't exist
   - May need to implement custom DSL testing framework
   - Mitigation: Start with pre-compiled modules, expand gradually

2. **Struct Changes Ripple Effects**
   - Fixing position maps might uncover other struct issues
   - May affect more test files than initially identified
   - Mitigation: Search thoroughly before fixing, fix incrementally

3. **Dependency Version Conflicts**
   - Timex API changes might require code updates beyond time_series.ex
   - Statistics library might have breaking changes
   - Mitigation: Check CHANGELOG for each dependency

### Testing Strategy

1. **Incremental Testing**
   - After each phase, run relevant test subset
   - Don't proceed to next phase until current passes
   - Use `--failed` flag to re-run only failed tests

2. **Isolation Testing**
   - Test each fixed file individually before running full suite
   - Verify fixes don't break other tests
   - Check test execution time doesn't increase significantly

3. **Regression Prevention**
   - Add test to catch arity mismatches in future
   - Document struct patterns in CONTRIBUTING.md
   - Add CI check for `Code.eval_string` usage

### Performance Considerations

1. **Test Execution Time**
   - Pre-compiled modules should speed up DSL tests significantly
   - Removing `Code.eval_string` should eliminate deadlock delays
   - Target: Full test suite completes in <30 seconds

2. **Memory Usage**
   - Watch for memory growth with improved module cleanup
   - Profile with `:observer.start()` during test runs
   - Ensure orphaned modules don't accumulate

### Future Improvements

1. **Test Infrastructure**
   - Create comprehensive LiveView test helpers
   - Build DSL testing framework as separate library
   - Add property-based testing for DSL validation

2. **Documentation**
   - Document all test helpers in ExDoc
   - Create testing guide for contributors
   - Add examples for each test pattern

3. **CI/CD**
   - Set up test result tracking over time
   - Add coverage requirements per module
   - Implement parallel test execution

---

## 8. Implementation Checklist

### Pre-Implementation
- [ ] Review this plan with Pascal
- [ ] Confirm approach for DSL testing (pre-compiled vs dynamic)
- [ ] Check if Spark.Test utilities exist
- [ ] Verify `:statistics` and `timex` versions in deps

### Phase 1: Compilation
- [ ] Fix pipeline_test.exs arity issues
- [ ] Create LiveView test case template
- [ ] Update chart_live_component_test.exs
- [ ] Update accessibility_test.exs
- [ ] Verify: `mix compile --warnings-as-errors` succeeds

### Phase 2: Structs
- [ ] Search for all struct instantiation patterns
- [ ] Fix test_helpers.ex (lines 107, 174)
- [ ] Fix heex_renderer test files (4 files)
- [ ] Update any other files found in search
- [ ] Verify: Entity tests pass

### Phase 3: Dependencies
- [ ] Verify :statistics library installation
- [ ] Test Statistics module functions
- [ ] Check Timex API version
- [ ] Fix Timex usage if needed
- [ ] Verify: No compiler warnings

### Phase 4: DSL Testing
- [ ] Research Spark testing utilities
- [ ] Create test/support/test_reports.ex
- [ ] Improve parse_dsl implementation
- [ ] Update dsl_test.exs to use new patterns
- [ ] Update entity tests to use new patterns
- [ ] Verify: DSL tests pass >80%

### Phase 5: Validation
- [ ] Run full test suite
- [ ] Check coverage metrics
- [ ] Test with multiple seeds
- [ ] Document fixes and learnings
- [ ] Update test writing guidelines
- [ ] Final verification of all success criteria

---

## 9. Success Metrics

### Quantitative Metrics

| Metric | Before | Target | Actual |
|--------|--------|--------|--------|
| Compilation errors | 3 | 0 | ___ |
| DSL tests passing | 0/36 | 29/36 (80%) | ___ |
| Entity tests passing | 0/135 | 108/135 (80%) | ___ |
| Total test pass rate | ~20% | >80% | ___ |
| Test suite execution time | N/A (blocked) | <30s | ___ |
| Compiler warnings | Multiple | 0 | ___ |

### Qualitative Metrics

- [ ] Test suite runs reliably without deadlocks
- [ ] Tests can run with async: true (where appropriate)
- [ ] No orphaned modules after test completion
- [ ] Clear error messages for test failures
- [ ] Test code follows documented patterns

---

## 10. Post-Implementation

### Verification Steps

1. Run full test suite 5 times to check for flakiness
2. Run tests on different machines/environments
3. Verify CI/CD pipeline passes
4. Check test coverage for critical modules

### Documentation Updates

1. Update CONTRIBUTING.md with test patterns
2. Document DSL testing approach in README
3. Add examples to test/support/README.md
4. Update implementation plan with actual results

### Next Steps

After completing Section 1.1, proceed to:
- **Section 1.2**: Security Vulnerability Patches
- **Section 1.3**: Implementation Status Documentation

### Handoff Notes

For the implementer:
1. Start with Phase 1 (compilation errors) - it's the fastest and enables everything else
2. Don't skip the checkpoints - they prevent wasted work
3. If you encounter issues with DSL testing, start with pre-compiled modules
4. Document any deviations from this plan and the reasons
5. Ask for help if stuck on any phase for >2 hours

---

**Plan Created**: 2025-10-04
**Plan Author**: Claude (feature-planner agent)
**Approved By**: _Pending Pascal's review_
**Implementation Start**: _TBD after approval_
