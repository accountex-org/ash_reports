# Stage 3 Section 3.1: Elixir Chart Generation Infrastructure

**Feature Branch**: `feature/stage3-section3.1-chart-infrastructure`
**Implementation Date**: 2025-10-03
**Status**: 🚧 In Progress

## Problem Statement

AshReports needs a chart generation system to create visualizations within PDF reports. The original plan called for a Node.js D3 service, but this adds unnecessary complexity and external dependencies. We need a pure Elixir solution that:

- Generates SVG charts without external services
- Integrates seamlessly with the existing Ash/Typst infrastructure
- Supports common chart types (bar, line, pie, area, scatter)
- Provides caching and performance optimization
- Works with GenStage streaming for large datasets

**Impact**: Charts are essential for data visualization in reports. Without this feature, reports are limited to tables and text.

## Solution Overview

Implement pure Elixir chart generation using **Contex** (mature Elixir SVG charting library) with:

1. **Chart abstraction layer** (`AshReports.Charts`) for unified chart interface
2. **Chart type registry** to register and discover available chart types
3. **SVG renderer** (`AshReports.Charts.Renderer`) for SVG generation using Contex
4. **Configuration schema** using Ecto embedded schemas for type safety
5. **ETS-based caching** for compiled SVG charts
6. **Telemetry integration** for performance monitoring

**Key Design Decisions**:
- Use **Contex** as primary charting library (pure Elixir, mature, well-maintained)
- Defer VegaLite integration to future enhancement (optional advanced features)
- Use Ecto embedded schemas for chart configuration (type safety, validation)
- Implement ETS caching for SVG output (fast, in-memory)
- Add chart builder behavior for extensibility (custom chart types)

## Technical Details

### Dependencies

**Add to mix.exs**:
```elixir
{:contex, "~> 0.5.0"}
```

### File Structure

```
lib/ash_reports/charts/
├── charts.ex                    # Main module, public API
├── registry.ex                  # Chart type registry
├── renderer.ex                  # SVG rendering with Contex
├── config.ex                    # Chart configuration schema
├── cache.ex                     # ETS-based SVG cache
├── types/
│   ├── bar_chart.ex            # BarChart implementation
│   ├── line_chart.ex           # LineChart implementation
│   ├── pie_chart.ex            # PieChart implementation
│   └── behavior.ex             # Chart builder behavior

test/ash_reports/charts/
├── charts_test.exs
├── renderer_test.exs
├── registry_test.exs
├── cache_test.exs
└── types/
    ├── bar_chart_test.exs
    ├── line_chart_test.exs
    └── pie_chart_test.exs
```

### Module Responsibilities

#### 1. `AshReports.Charts` (Main Module)
- Public API for chart generation
- `generate(type, data, config)` - Main entry point
- `list_types()` - List available chart types
- Delegates to Registry and Renderer

#### 2. `AshReports.Charts.Registry`
- Chart type registration system
- `register(type, module)` - Register chart type
- `get(type)` - Retrieve chart module
- `list()` - List all registered types
- Uses ETS table for storage

#### 3. `AshReports.Charts.Renderer`
- SVG generation using Contex
- `render(chart_module, data, config)` - Render to SVG
- SVG optimization and minification
- Error handling and fallback rendering
- Integrates with cache

#### 4. `AshReports.Charts.Config`
- Ecto embedded schema for configuration
- Fields: title, width, height, colors, legend, axes
- Validation and defaults

#### 5. `AshReports.Charts.Cache`
- ETS-based SVG cache
- `get(key)` - Retrieve cached SVG
- `put(key, svg, ttl)` - Cache SVG with TTL
- `clear()` - Clear cache
- Automatic expiration

#### 6. `AshReports.Charts.Types.Behavior`
- Behavior for chart implementations
- Callbacks: `build/2`, `validate/1`
- Ensures consistent interface

## Success Criteria

### Functional Requirements
- ✅ Contex dependency added and working
- ✅ Chart abstraction layer with public API
- ✅ Registry system for chart types
- ✅ At least 3 chart types implemented (bar, line, pie)
- ✅ SVG rendering with Contex
- ✅ ETS caching system functional
- ✅ Configuration schema with validation
- ✅ Error handling and fallback rendering

### Testing Requirements
- ✅ Unit tests for all modules (>80% coverage)
- ✅ Integration tests for chart generation flow
- ✅ Cache performance tests
- ✅ SVG output validation tests
- ✅ Error case handling tests

### Performance Requirements
- Chart generation <100ms for simple charts
- Cache hit latency <5ms
- SVG output <100KB for typical charts

## Implementation Plan

### Phase 1: Foundation (3.1.1 - Chart Library Integration)

#### Step 1: Add Dependencies ✅
- [x] Add Contex to mix.exs (~> 0.5.0)
- [x] Run `mix deps.get`
- [x] Verify Contex compiles correctly

#### Step 2: Create Base Module Structure
- [ ] Create `lib/ash_reports/charts/charts.ex` (main module)
- [ ] Create `lib/ash_reports/charts/registry.ex` (chart type registry)
- [ ] Create `lib/ash_reports/charts/config.ex` (configuration schema)
- [ ] Create `lib/ash_reports/charts/types/behavior.ex` (chart behavior)

#### Step 3: Implement Chart Registry
- [ ] ETS table setup for chart type storage
- [ ] `register/2` function to register chart types
- [ ] `get/1` function to retrieve chart modules
- [ ] `list/0` function to list available types
- [ ] Registry initialization in application startup

#### Step 4: Create Configuration Schema
- [ ] Ecto embedded schema for chart config
- [ ] Fields: title, width, height, colors, legend, axes
- [ ] Validation functions
- [ ] Default values

#### Step 5: Implement Chart Behavior
- [ ] Define `build/2` callback
- [ ] Define `validate/1` callback
- [ ] Documentation for behavior

#### Step 6: Write Tests for Phase 1
- [ ] Registry tests (register, get, list)
- [ ] Config schema tests (validation, defaults)
- [ ] Behavior compliance tests

### Phase 2: SVG Rendering (3.1.2 - SVG Generation Pipeline)

#### Step 7: Create Renderer Module
- [ ] Create `lib/ash_reports/charts/renderer.ex`
- [ ] `render/3` function (chart_module, data, config)
- [ ] Contex integration for SVG generation
- [ ] SVG optimization (remove unnecessary attrs)
- [ ] Error handling with fallback rendering

#### Step 8: Implement Basic Chart Types
- [ ] Create `lib/ash_reports/charts/types/bar_chart.ex`
  - Implement Behavior
  - Use `Contex.BarChart`
  - Handle grouped/stacked variants
- [ ] Create `lib/ash_reports/charts/types/line_chart.ex`
  - Implement Behavior
  - Use `Contex.LinePlot`
  - Support multi-series
- [ ] Create `lib/ash_reports/charts/types/pie_chart.ex`
  - Implement Behavior
  - Use `Contex.PieChart`
  - Percentage labels

#### Step 9: Implement SVG Cache
- [ ] Create `lib/ash_reports/charts/cache.ex`
- [ ] ETS table for cache storage
- [ ] `get/1` function with key lookup
- [ ] `put/3` function with TTL support
- [ ] `clear/0` function
- [ ] Automatic expiration with GenServer timer

#### Step 10: Add Telemetry
- [ ] Define telemetry events:
  - `[:ash_reports, :charts, :render, :start]`
  - `[:ash_reports, :charts, :render, :stop]`
  - `[:ash_reports, :charts, :cache, :hit]`
  - `[:ash_reports, :charts, :cache, :miss]`
- [ ] Emit events in renderer and cache
- [ ] Document telemetry events

#### Step 11: Write Tests for Phase 2
- [ ] Renderer tests (SVG generation, optimization)
- [ ] BarChart tests (data processing, SVG output)
- [ ] LineChart tests (multi-series, formatting)
- [ ] PieChart tests (percentage calculation)
- [ ] Cache tests (hit/miss, expiration, clear)
- [ ] Telemetry tests (event emission)
- [ ] Integration tests (end-to-end chart generation)

#### Step 12: Documentation
- [ ] Module documentation for all public APIs
- [ ] Chart type usage examples
- [ ] Configuration options documentation
- [ ] Caching strategy documentation

## Testing Strategy

### Unit Tests
- Module-level tests for each component
- Mock data for chart rendering
- Validate SVG structure and content
- Test error conditions and fallbacks

### Integration Tests
- End-to-end chart generation flow
- Registry → Renderer → Cache flow
- Multiple chart types in sequence
- Cache hit/miss scenarios

### Performance Tests
- Benchmark chart generation time
- Cache performance measurement
- Memory usage validation
- SVG output size checks

## Current Status

### What Works
- ✅ Planning document created
- ✅ Architecture designed
- ✅ Implementation plan defined
- ✅ Git branch created: `feature/stage3-section3.1-chart-infrastructure`
- ✅ Contex dependency added to mix.exs (v0.5.0)
- ✅ Dependencies fetched and compiled successfully

### What's Next
1. Implement Phase 1 (Foundation):
   - Create base module structure
   - Implement chart registry
   - Create configuration schema
   - Implement chart behavior
2. Implement Phase 2 (SVG Rendering):
   - Create renderer module
   - Implement basic chart types
   - Add SVG caching
   - Add telemetry
3. Write comprehensive tests
4. Update planning document
5. Create commit after permission

### How to Run (After Implementation)
```bash
# Add charts to a report
config = %AshReports.Charts.Config{
  title: "Sales by Month",
  width: 600,
  height: 400
}

data = [
  %{month: "Jan", sales: 1000},
  %{month: "Feb", sales: 1500},
  %{month: "Mar", sales: 1200}
]

{:ok, svg} = AshReports.Charts.generate(:bar, data, config)

# List available chart types
AshReports.Charts.list_types()
# => [:bar, :line, :pie]
```

## Notes and Considerations

### Edge Cases
- Empty datasets - render "No data" message
- Invalid data formats - validation errors
- Cache memory limits - implement LRU eviction
- Very large datasets - warn if >10K datapoints (should use GenStage aggregation)

### Future Enhancements
- VegaLite integration for advanced charts
- Area chart, scatter plot, heatmap implementations
- Custom color schemes and theming
- Interactive chart options (for web)
- Export to PNG/PDF (via external tool)

### Risks and Mitigation
- **Risk**: Contex API changes
  - **Mitigation**: Pin version, test thoroughly
- **Risk**: SVG compatibility with Typst
  - **Mitigation**: Validate SVG output, test embedding early
- **Risk**: Cache memory growth
  - **Mitigation**: Implement TTL and size limits

### Dependencies on Other Work
- **Stage 2 (GenStage)**: Will be used in Stage 3.2 for data aggregation
- **Typst Integration**: Will be used in Stage 3.3 for SVG embedding
- **DSL Extension**: Will be added in Stage 3.3.2 for chart elements

## Related Documentation
- Planning: `planning/typst_refactor_plan.md` (Section 3.1)
- Contex Docs: https://hexdocs.pm/contex
- Typst SVG Support: https://typst.app/docs/reference/visualize/image/
