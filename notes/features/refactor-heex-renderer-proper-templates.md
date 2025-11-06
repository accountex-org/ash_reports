# Refactor HEEX Renderer to Generate Proper Templates

**Status**: 🚧 In Progress
**Branch**: `feature/refactor-heex-renderer-proper-templates`
**Created**: 2025-01-05
**Owner**: Development Team

## Problem Statement

The current HEEX renderer implementation pre-renders all content into static HTML strings at generation time, which prevents it from leveraging Phoenix LiveView's reactive capabilities and efficient rendering patterns.

### Current Limitations

1. **Static String Generation**: Uses `Enum.map` and `Enum.join` to create HTML strings
2. **No LiveView Benefits**: Cannot benefit from differential rendering or live updates
3. **No Phoenix Assigns**: Cannot use `@variable` syntax for dynamic data
4. **Poor Performance**: Generates entire HTML output on every render
5. **No Component Reusability**: Each render creates new HTML from scratch
6. **No Reactivity**: Cannot respond to data changes efficiently

### Example of Current Approach

```elixir
# band_renderer.ex
defp render_bands_without_grouping(bands, context) do
  bands
  |> Enum.map(fn band -> render_band(band, context) end)
  |> Enum.join("\n")
end
```

This generates:
```html
<div>Band 1 content</div>
<div>Band 2 content</div>
<div>Band 3 content</div>
```

## Solution Overview

Refactor the HEEX renderer to generate proper HEEX template strings that use Phoenix's template syntax including for comprehensions, assigns, and components.

### Desired Approach

Generate HEEX template code that Phoenix evaluates at runtime:

```heex
<div :for={band <- @bands} class="band">
  <%= render_band_content(band, @context) %>
</div>
```

### Key Changes

1. **Template Generation**: Create HEEX template strings with proper syntax
2. **Assign-Based Data**: Use `@assigns` for all dynamic data
3. **For Comprehensions**: Use `:for` attribute for iterations
4. **Component Integration**: Use Phoenix components (`<.component>`)
5. **Runtime Evaluation**: Let Phoenix evaluate templates with assigns

## Technical Details

### Files to Modify

1. **`lib/ash_reports/renderers/heex_renderer/heex_renderer.ex`**
   - Main renderer entry point
   - Update `generate_enhanced_heex_template/3`
   - Change return type to HEEX template string

2. **`lib/ash_reports/renderers/heex_renderer/band_renderer.ex`**
   - Core rendering logic
   - Replace `Enum.map` with HEEX `:for` syntax
   - Generate template strings instead of HTML

3. **New: `lib/ash_reports/renderers/heex_renderer/template_builder.ex`**
   - Helper functions for building HEEX syntax
   - Template string construction utilities
   - Escape and sanitization functions

### Data Structures

#### Current Flow
```
RenderContext → render_bands → HTML String
```

#### New Flow
```
RenderContext → generate_template → HEEX Template String
                                  ↓
                            Runtime: Template + Assigns → HTML
```

### Assign Structure

```elixir
%{
  report: report_definition,
  bands: list_of_bands,
  records: data_records,
  variables: variable_values,
  groups: group_info,
  metadata: render_metadata
}
```

## Implementation Plan

### Phase 1: Foundation (Week 1)

**1.1: Create Template Builder Module**
- [ ] Create `template_builder.ex`
- [ ] Add helper functions for HEEX syntax generation
- [ ] Add tests for template building

**1.2: Update Band Renderer Structure**
- [ ] Modify `render_bands/2` to generate templates
- [ ] Update `render_band/2` for template output
- [ ] Keep old implementation as `_legacy`

**1.3: Simple Band Types**
- [ ] Implement title band template generation
- [ ] Implement page header template generation
- [ ] Add tests for simple bands

### Phase 2: Detail Bands & Elements (Week 2)

**2.1: Detail Band Templates**
- [ ] Implement detail band with `:for` comprehension
- [ ] Handle record iteration
- [ ] Add grouping support

**2.2: Element Rendering**
- [ ] Refactor field elements
- [ ] Refactor label elements
- [ ] Refactor expression elements
- [ ] Refactor aggregate elements

**2.3: Data Binding**
- [ ] Implement assign generation
- [ ] Test data flow from context to assigns
- [ ] Verify runtime evaluation

### Phase 3: Grouping & Advanced Features (Week 3)

**3.1: Group Header/Footer**
- [ ] Implement group header templates
- [ ] Implement group footer templates
- [ ] Handle group break logic

**3.2: Variables & Aggregates**
- [ ] Implement variable references
- [ ] Implement aggregate calculations
- [ ] Test variable scoping

**3.3: Integration**
- [ ] Update main `heex_renderer.ex`
- [ ] Update `Components` module
- [ ] Test end-to-end flow

### Phase 4: Testing & Optimization (Week 4)

**4.1: Comprehensive Testing**
- [ ] Unit tests for all band types
- [ ] Integration tests with LiveView
- [ ] Performance benchmarks

**4.2: Documentation**
- [ ] Update module documentation
- [ ] Add usage examples
- [ ] Create migration guide

**4.3: Optimization**
- [ ] Template caching
- [ ] Performance profiling
- [ ] Memory optimization

## Success Criteria

### Functional Requirements
- ✅ Generates valid HEEX template strings
- ✅ Uses `:for` comprehensions for iterations
- ✅ Uses `@assigns` for all dynamic data
- ✅ Supports all 11 band types
- ✅ Supports all 7 element types
- ✅ Maintains grouping functionality
- ✅ Works with LiveView

### Performance Requirements
- ✅ Template generation < 50ms for typical report
- ✅ Runtime rendering benefits from LiveView diffing
- ✅ Memory usage reduced by 30%

### Quality Requirements
- ✅ 100% test coverage for new code
- ✅ All existing tests pass (or updated appropriately)
- ✅ Documentation updated
- ✅ No breaking changes for users

## Testing Strategy

### Unit Tests
- Template builder functions
- Individual band type templates
- Element rendering templates
- Assign generation

### Integration Tests
- Full report template generation
- Template evaluation with assigns
- LiveView integration
- Grouping and variables

### Performance Tests
- Template generation speed
- Runtime rendering performance
- Memory usage comparison
- LiveView update efficiency

## Risks & Mitigation

### Risk 1: Breaking Changes
**Mitigation**: Maintain backward compatibility layer, deprecate old approach gradually

### Risk 2: Complex Template Logic
**Mitigation**: Keep template generation simple, move complexity to data preparation

### Risk 3: Performance Regression
**Mitigation**: Benchmark early and often, optimize hot paths

### Risk 4: Testing Complexity
**Mitigation**: Use helper functions for template assertions, snapshot testing

## Migration Path

### Backward Compatibility

1. Keep old implementation with `_legacy` suffix
2. Add config flag to choose renderer mode
3. Provide migration guide for users
4. Deprecate old mode in v2.0

### Configuration

```elixir
config :ash_reports,
  heex_renderer_mode: :template  # or :legacy
```

## Notes & Considerations

### Edge Cases
- Empty record sets
- Nil values in templates
- Missing group data
- Complex expressions
- Nested bands

### Future Enhancements
- Component slots for custom content
- Live update events
- Interactive elements
- Client-side filtering
- Real-time data streaming

### Performance Considerations
- Template caching by report definition
- Lazy evaluation where possible
- Stream processing for large datasets
- Memory pooling for assigns

## Current Status

**✅ Completed:**
- Planning document created
- Feature branch created
- Architecture designed

**🚧 In Progress:**
- Phase 1: Foundation

**📋 Next Steps:**
- Create `template_builder.ex`
- Refactor `band_renderer.ex`
- Add initial tests

## References

- Phoenix.Component documentation
- HEEx template guide
- LiveView rendering pipeline
- Current HEEX renderer implementation (lines 65-81 of heex_renderer.ex)
