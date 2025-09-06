# PhoenixTest Migration Planning Document

## Problem Statement

The current testing approach for Phoenix web pages and LiveViews in the ash_reports project uses traditional Phoenix testing patterns (Phoenix.LiveViewTest, live_isolated, render_*). While functional, this approach has several limitations:

1. **Fragmented Testing Approach**: Different patterns for static pages vs LiveViews
2. **Implementation-Focused Tests**: Tests are written from the perspective of implementation details rather than user interactions
3. **Maintenance Overhead**: Tests require deep knowledge of Phoenix internals
4. **Limited User Journey Testing**: Difficult to test complex user flows that span multiple pages or components

PhoenixTest provides a unified, user-centric approach to testing Phoenix applications that can improve test maintainability and readability while enabling better end-to-end testing scenarios.

## Solution Overview

Migrate all Phoenix web page and LiveView tests to use PhoenixTest, providing a unified testing approach that:

- Uses intuitive, user-centric test helpers (`visit`, `click_link`, `fill_in`, `assert_has`)
- Seamlessly handles navigation between static pages and LiveViews
- Simplifies complex user interaction testing
- Reduces maintenance burden through more stable test patterns
- Enables better integration testing of complete user workflows

### Current State Analysis

**LiveView Tests Identified**: 9 test files in `/home/ducky/code/ash_reports/test/ash_reports/live_view/`:
- `dashboard_live_test.exs` - Dashboard functionality and coordination
- `chart_live_component_test.exs` - Chart component lifecycle and interactions
- `accessibility_test.exs` - Accessibility compliance
- `browser_integration_test.exs` - Cross-browser compatibility
- `load_test.exs` - Performance under load
- `performance_test.exs` - Performance metrics
- `websocket_streaming_test.exs` - Real-time data streaming

**Additional LiveView Integration Tests**: 1 file in `/home/ducky/code/ash_reports/test/ash_reports/heex_renderer/`:
- `live_view_integration_test.exs` - HeEX renderer LiveView helpers

**Current Test Patterns**:
```elixir
# Current approach using Phoenix.LiveViewTest
use Phoenix.LiveViewTest

{view, html} = live_isolated(DashboardLive, params, session: session)
result = render_click(view, "apply_global_filter", params)
assert html =~ "expected_content"
```

**Dependencies Status**:
- PhoenixTest is already included in mix.exs: `{:phoenix_test, "~> 0.7", only: :test}`
- No blocking compilation errors found
- Some warnings present but not related to phoenix_test

## Agent Consultations Performed

**Phoenix Test Documentation Review**: Comprehensive analysis of PhoenixTest capabilities including:
- Core testing functions (`visit/2`, `click_link/2`, `fill_in/3`, `assert_has/3`)
- LiveView integration patterns
- Form handling and interaction testing
- Navigation between different page types

**Codebase Analysis**: Systematic review of current test patterns to identify:
- All LiveView-related test files
- Current testing approaches and patterns
- Dependency status and compilation issues
- Existing test helper functions and utilities

## Technical Details

### PhoenixTest Core API Functions

```elixir
# Navigation and page interaction
conn |> visit("/dashboard")
conn |> click_link("Users")
conn |> fill_in("Name", with: "Aragorn")
conn |> choose("Ranger")  # Radio buttons
conn |> submit()

# Assertions
conn |> assert_has(".user", text: "Aragorn")
conn |> assert_has("h1", text: "Dashboard")

# Form handling
conn |> fill_form("#user-form", %{name: "John", email: "john@example.com"})
```

### Current Test Patterns to Migrate

1. **LiveView Mounting**:
   ```elixir
   # Current
   {view, html} = live_isolated(DashboardLive, params)
   
   # PhoenixTest equivalent
   conn |> visit("/dashboard?#{URI.encode_query(params)}")
   ```

2. **Event Handling**:
   ```elixir
   # Current
   result = render_click(view, "apply_global_filter", filter_params)
   
   # PhoenixTest equivalent
   conn |> click_button("Apply Filter")
   # or
   conn |> fill_form("#filter-form", filter_params) |> submit()
   ```

3. **Assertions**:
   ```elixir
   # Current
   assert html =~ "expected_content"
   
   # PhoenixTest equivalent
   conn |> assert_has(".content", text: "expected_content")
   ```

### Key Migration Considerations

1. **Real-time Testing**: PhoenixTest handles LiveView updates automatically, eliminating need for manual `render()` calls
2. **Component Testing**: May need to create test routes for isolated component testing
3. **Event Simulation**: Some complex JavaScript interactions may need alternative testing approaches
4. **Test Data Setup**: Existing test helpers and data setup functions can remain largely unchanged

## Success Criteria

### Functional Requirements

1. **Complete Migration**: All identified LiveView and web page tests converted to PhoenixTest
2. **Test Coverage Maintained**: All existing test scenarios preserved with equivalent PhoenixTest implementations
3. **Pass Rate**: 100% of migrated tests pass with same or improved reliability
4. **Performance**: Test execution time remains comparable or improves

### Quality Improvements

1. **Readability**: Tests read more like user stories and less like implementation details
2. **Maintainability**: Reduced coupling to Phoenix internals makes tests more stable
3. **Integration Coverage**: Better testing of complete user workflows across components
4. **Documentation**: Clear examples of PhoenixTest patterns for future development

### Technical Validation

1. **No Compilation Errors**: All tests compile successfully
2. **CI/CD Compatibility**: All tests run successfully in automated testing environment
3. **Dependency Stability**: Phoenix_test dependency remains stable and well-supported
4. **Configuration Correctness**: Test environment properly configured for PhoenixTest

## Implementation Plan

### Phase 1: Foundation Setup (Day 1)

1. **Environment Preparation**
   - Verify PhoenixTest configuration in `config/test.exs`
   - Create test helper functions for common PhoenixTest patterns
   - Set up test routes if needed for component isolation

2. **Migration Utilities**
   - Create helper module for converting common test patterns
   - Document mapping between old and new test patterns
   - Set up test data factories compatible with PhoenixTest

### Phase 2: Core LiveView Tests Migration (Days 2-3)

1. **Dashboard Tests Migration**
   - Convert `dashboard_live_test.exs` to PhoenixTest patterns
   - Focus on user interaction flows (filtering, sorting, layout changes)
   - Maintain all existing test scenarios

2. **Chart Component Tests Migration**
   - Convert `chart_live_component_test.exs` interactive tests
   - Handle complex chart interactions through user-centric approaches
   - Preserve performance and error handling tests

### Phase 3: Specialized Tests Migration (Days 4-5)

1. **Real-time and Streaming Tests**
   - Migrate `websocket_streaming_test.exs` with PhoenixTest WebSocket support
   - Convert real-time update verification to user-observable changes

2. **Integration and Accessibility Tests**
   - Convert `browser_integration_test.exs` to PhoenixTest patterns
   - Migrate `accessibility_test.exs` using PhoenixTest assertion helpers
   - Update `live_view_integration_test.exs` for HeEX renderer

### Phase 4: Performance and Load Tests (Day 6)

1. **Performance Test Adaptation**
   - Evaluate PhoenixTest impact on `performance_test.exs`
   - Adapt `load_test.exs` to work with PhoenixTest patterns
   - Ensure performance benchmarks remain valid

### Phase 5: Validation and Documentation (Day 7)

1. **Test Execution and Validation**
   - Run complete test suite to verify all migrations successful
   - Compare test execution times and reliability
   - Fix any remaining issues or edge cases

2. **Documentation and Guidelines**
   - Update project README with PhoenixTest usage guidelines
   - Create developer documentation for new test patterns
   - Document any PhoenixTest-specific testing approaches

### Implementation Steps Detail

#### Step 1: Configuration and Setup
```elixir
# config/test.exs - Verify PhoenixTest configuration
config :phoenix_test, :endpoint, AshReports.Endpoint

# test/support/test_helpers.exs - Add PhoenixTest helpers
defmodule AshReports.TestHelpers do
  import PhoenixTest
  
  def login_user(conn, user) do
    conn
    |> visit("/login")
    |> fill_in("Email", with: user.email)
    |> fill_in("Password", with: "password123")
    |> click_button("Sign In")
  end
  
  def visit_dashboard_with_data(conn, dashboard_data) do
    # Setup test data
    # Visit dashboard page
    conn |> visit("/dashboard")
  end
end
```

#### Step 2: Test Pattern Conversion Examples
```elixir
# Before: dashboard_live_test.exs
test "mounts dashboard with multiple charts" do
  {view, html} = live_isolated(DashboardLive, params, session: session)
  assert html =~ "Test Dashboard"
  assert html =~ "chart1"
end

# After: dashboard_live_test.exs with PhoenixTest
test "displays dashboard with multiple charts" do
  conn
  |> visit("/dashboard?dashboard_id=test_dashboard")
  |> assert_has("h1", text: "Test Dashboard")
  |> assert_has("[data-chart-id='chart1']")
  |> assert_has("[data-chart-id='chart2']")
end

# Before: Interactive events
test "applies global filters to all charts", %{view: view} do
  result = render_click(view, "apply_global_filter", %{
    "filter" => %{"region" => "North", "start_date" => "2024-01-01"}
  })
  assert result
  html = render(view)
  assert html =~ "North"
end

# After: User interaction focused
test "applies global filters to all charts" do
  conn
  |> visit("/dashboard")
  |> fill_in("Region", with: "North")
  |> fill_in("Start Date", with: "2024-01-01")
  |> click_button("Apply Filter")
  |> assert_has(".filter-indicator", text: "North")
  |> assert_has(".chart-container[data-filtered='true']")
end
```

#### Step 3: Handle Complex Scenarios
```elixir
# Real-time updates testing
test "handles dashboard-wide real-time updates" do
  conn
  |> visit("/dashboard?real_time=true")
  |> assert_has("[data-real-time='true']")
  # Simulate data change that should trigger updates
  |> eventually(fn conn ->
    conn |> assert_has(".chart-data[data-updated='true']")
  end)
end

# Component isolation for detailed testing
test "chart component handles errors gracefully" do
  conn
  |> visit("/test-components/chart?invalid_config=true")
  |> assert_has(".chart-error")
  |> assert_has(".retry-button")
  |> click_button("Retry")
  |> assert_has(".chart-loading")
end
```

### Testing Strategy

1. **Parallel Implementation**: Keep existing tests while implementing PhoenixTest versions
2. **Gradual Migration**: Complete one test file at a time, verifying functionality
3. **Comparative Testing**: Run both old and new tests during transition to ensure equivalency
4. **CI/CD Integration**: Ensure all tests pass in automated environment throughout migration

## Notes/Considerations

### Edge Cases and Risks

1. **JavaScript-Heavy Interactions**: PhoenixTest doesn't support JavaScript, may need alternative approaches for complex chart interactions
2. **WebSocket Testing**: Real-time features may require additional setup or different testing patterns
3. **Component Isolation**: Some component tests may need dedicated test routes or different approaches
4. **Performance Impact**: PhoenixTest may have different performance characteristics compared to current approach

### Future Improvements

1. **Test Route Organization**: Consider dedicated test routes for component isolation
2. **Helper Function Library**: Build comprehensive PhoenixTest helper functions for common patterns
3. **Documentation Updates**: Update developer onboarding documentation with PhoenixTest patterns
4. **Test Data Management**: Potentially improve test data factories to work better with user-journey testing

### Dependencies and Compatibility

1. **Phoenix Version**: Ensure PhoenixTest compatibility with current Phoenix version (1.7.21)
2. **LiveView Version**: Verify compatibility with Phoenix LiveView (0.20.17)
3. **Test Environment**: Confirm test environment setup supports PhoenixTest requirements
4. **CI/CD Pipeline**: Validate automated testing pipeline compatibility

### Rollback Plan

If migration encounters critical issues:
1. Keep original test files as `*_legacy_test.exs` during transition
2. Maintain ability to run both old and new test suites
3. Document specific issues encountered for potential upstream fixes
4. Consider hybrid approach where some tests remain in original format if necessary

### Success Metrics

- **Migration Completion**: 100% of identified tests migrated
- **Test Reliability**: No decrease in test pass rate
- **Developer Experience**: Improved test readability and maintainability
- **Execution Time**: Comparable or improved test execution performance
- **CI/CD Stability**: No regression in automated testing reliability