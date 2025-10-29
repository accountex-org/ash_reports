# Feature Planning Document: `render_report_bands` Function

## Document Metadata
- **Feature**: HEEX Band Rendering Function
- **Created**: 2025-10-29
- **Author**: Claude Code
- **Status**: Planning
- **Priority**: High (Blocking - Function is called but doesn't exist)

---

## 1. Problem Statement

### Current State
The HEEX renderer (`/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/heex_renderer.ex`) calls `render_report_bands(@reports)` on lines 646 and 651, but this function does not exist. This causes runtime errors when attempting to render reports using the HEEX renderer.

### Why This Function Is Needed
The `render_report_bands` function is the core template generation function responsible for converting report data structures into HEEX template code. It needs to:

1. **Process Band Hierarchy**: Handle the 11 different band types (title, page_header, column_header, group_header, detail_header, detail, detail_footer, group_footer, column_footer, page_footer, summary)
2. **Render Elements Within Bands**: Generate HEEX for all element types (field, label, expression, aggregate, line, box, image)
3. **Integrate Variables**: Display variable values (sum, count, average, min, max, custom) with proper scoping
4. **Handle Grouping**: Render group headers/footers with group-specific data and aggregates
5. **Support Aggregates**: Calculate and display aggregate functions at appropriate scopes
6. **Maintain Context**: Track current record, band, group, and variable state during rendering

### Impact
Without this function:
- HEEX renderer is non-functional
- Reports cannot be rendered as HEEX templates
- LiveView integration is blocked
- Phoenix component-based rendering is unavailable

---

## 2. Solution Overview

### High-Level Approach
Create a `render_report_bands/1` function that generates HEEX template code by:

1. Accepting the `@reports` assign (which contains `context.records` - the list of data records)
2. Iterating through the report's band structure in the correct order
3. For each band, rendering its elements with appropriate data binding
4. Integrating variable values from the render context
5. Handling group breaks and group-scoped aggregates
6. Generating Phoenix.Component-compatible HEEX markup

### Key Design Decisions

#### **Location**: Where should the function live?
**Decision**: Create a new module `AshReports.HeexRenderer.BandRenderer` 

**Rationale**:
- Separation of concerns - band rendering is a distinct responsibility
- Follows existing pattern (Components, LiveViewIntegration are separate modules)
- Easier to test in isolation
- Allows for future optimization without modifying main renderer
- Can be used by both HeexRenderer and HeexRendererEnhanced

#### **Signature**: Function parameters and return type
```elixir
@spec render_report_bands(RenderContext.t()) :: String.t() | Phoenix.LiveView.Rendered.t()
```

**Note**: The function is called with `@reports` which is assigned from `context.records`, but it actually needs the full `RenderContext` to access:
- Report definition (for band structure)
- Records (data to display)
- Variables (calculated values)
- Groups (grouping state)
- Metadata (additional context)

**Correction Needed**: The HEEX template should pass `@context` or the assigns should include all necessary data.

#### **Processing Strategy**: How to iterate through data
**Decision**: Use stream-based processing where possible, with Phoenix.Component comprehensions for HEEX generation

**Rationale**:
- Memory efficient for large reports
- Matches existing streaming support
- Leverages Phoenix's optimized template engine
- Allows for lazy evaluation

---

## 3. Technical Details

### 3.1 Data Flow

```
RenderContext
    ├─ report (Report.t()) - Contains band definitions
    ├─ records (list) - Data rows to render  
    ├─ variables (map) - Variable values (e.g., %{total: 1000, count: 10})
    ├─ groups (map) - Group metadata (e.g., %{{1 => "West"} => %{record_count: 5}})
    └─ metadata (map) - Additional context

Report Structure:
    ├─ bands (list of Band.t())
    │   ├─ type (:title | :page_header | :group_header | :detail | etc.)
    │   ├─ elements (list of Element.t())
    │   │   ├─ type (:field | :label | :aggregate | etc.)
    │   │   ├─ position (map with x, y, width, height)
    │   │   └─ style (map with formatting properties)
    │   └─ bands (optional nested bands)
    │
    ├─ variables (list of Variable.t())
    │   ├─ name (atom)
    │   ├─ type (:sum | :count | :average | :min | :max)
    │   ├─ expression (Ash.Expr.t())
    │   └─ reset_on (:detail | :group | :page | :report)
    │
    └─ groups (list of Group.t())
        ├─ name (atom)
        ├─ level (integer)
        └─ expression (Ash.Expr.t() or field reference)
```

### 3.2 Band Rendering Order

Bands must be rendered in a specific order to maintain proper report structure:

1. **Title** (once per report)
2. **Page Header** (at page start)
3. **Column Header** (after page header)
4. **For each group level (1, 2, 3...)**:
   - **Group Header** (when group value changes)
   - **Detail Header** (before detail records)
   - **Detail** (for each record in group)
   - **Detail Footer** (after detail records)
   - **Group Footer** (when group value changes)
5. **Column Footer** (before page footer)
6. **Page Footer** (at page end)
7. **Summary** (once at report end)

### 3.3 Element Rendering

Each element type requires specific rendering logic:

#### Field Element
```heex
<div class="field-element" style="position: absolute; left: <%= @element.position.x %>; top: <%= @element.position.y %>;">
  <%= get_in(@record, [@element.source]) %>
</div>
```

#### Label Element
```heex
<div class="label-element" style="<%= element_style(@element) %>">
  <%= @element.text %>
</div>
```

#### Expression Element
```heex
<div class="expression-element" style="<%= element_style(@element) %>">
  <%= evaluate_expression(@element.expression, @record, @variables) %>
</div>
```

#### Aggregate Element
```heex
<div class="aggregate-element" style="<%= element_style(@element) %>">
  <%= format_aggregate(@element, @variables[@element.name]) %>
</div>
```

### 3.4 Variable Integration

Variables are pre-calculated by the DataLoader and stored in `context.variables`:

```elixir
context.variables = %{
  total_amount: 50000,      # Sum variable
  record_count: 125,        # Count variable
  average_price: 400.00,    # Average variable
  max_quantity: 100,        # Max variable
  min_quantity: 1           # Min variable
}
```

To display a variable in HEEX:
```heex
<%= @variables[:total_amount] %>
```

With formatting:
```heex
<%= Number.Currency.number_to_currency(@variables[:total_amount]) %>
```

### 3.5 Group Integration

Groups are tracked in `context.groups` as a map where keys are group value combinations:

```elixir
context.groups = %{
  # Key is map of level => value
  %{1 => "West"} => %{
    record_count: 45,
    first_record: %{region: "West", ...},
    last_record: %{region: "West", ...},
    group_level_values: %{1 => "West"}
  },
  %{1 => "East"} => %{
    record_count: 80,
    ...
  }
}
```

Group headers and footers are rendered when group values change. The records should already be ordered by group, so the renderer can detect changes by comparing consecutive records.

### 3.6 Aggregates vs Variables

**Variables** (from Variable System):
- Pre-calculated during data loading
- Stored in `context.variables`
- Accessed by variable name
- Scoped to reset points (detail, group, page, report)

**Aggregates** (from Aggregate Elements):
- Element type (:aggregate)
- Reference a variable by name
- Include formatting information
- Positioned like other elements

**Relationship**: An aggregate element displays a variable's value at a specific position with specific formatting.

---

## 4. Implementation Plan

### Phase 1: Module Structure (Week 1, Day 1-2)

#### Task 1.1: Create BandRenderer Module
**File**: `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/band_renderer.ex`

**Responsibilities**:
- Main entry point: `render_report_bands/1`
- Band iteration logic
- Element rendering coordination
- HEEX template string assembly

**Module Structure**:
```elixir
defmodule AshReports.HeexRenderer.BandRenderer do
  @moduledoc """
  Generates HEEX template code for report bands and their elements.
  
  This module is responsible for converting report band structures into
  Phoenix.Component-compatible HEEX markup, integrating data records,
  variables, groups, and aggregates.
  """
  
  alias AshReports.{Band, Element, RenderContext}
  
  @doc """
  Renders all report bands with their elements as HEEX template code.
  
  ## Parameters
  - context: RenderContext with report definition and data
  
  ## Returns
  String containing HEEX template code
  """
  @spec render_report_bands(RenderContext.t()) :: String.t()
  def render_report_bands(%RenderContext{} = context)
  
  # Private functions for each rendering concern
  defp render_band(band, context)
  defp render_band_elements(elements, context)
  defp render_element(element, context)
  defp render_field_element(element, record)
  defp render_label_element(element)
  defp render_expression_element(element, record, variables)
  defp render_aggregate_element(element, variables)
  defp element_style(element)
  defp evaluate_expression(expression, record, variables)
  defp format_aggregate(element, value)
end
```

#### Task 1.2: Update HeexRenderer to Use BandRenderer
**File**: `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/heex_renderer.ex`

**Changes**:
1. Add alias for `BandRenderer`
2. Update `build_component_assigns` to pass full context instead of just records
3. Update template generation to use `BandRenderer.render_report_bands(@context)`

**Before**:
```elixir
base_assigns = %{
  locale: context.locale,
  text_direction: context.text_direction,
  reports: context.records,  # Only records
  ...
}
```

**After**:
```elixir
base_assigns = %{
  locale: context.locale,
  text_direction: context.text_direction,
  context: context,  # Full context including report, records, variables, groups
  ...
}
```

**Template Update**:
```elixir
# Before
<%= render_report_bands(@reports) %>

# After  
<%= BandRenderer.render_report_bands(@context) %>
```

#### Task 1.3: Write Module Tests
**File**: `/home/pcharbon/code/ash_reports/test/ash_reports/renderers/heex_renderer/band_renderer_test.exs`

**Test Coverage**:
- Basic band rendering
- Element type rendering (field, label, expression, aggregate)
- Variable integration
- Group handling
- Empty data handling
- Error cases

---

### Phase 2: Core Band Rendering (Week 1, Day 3-4)

#### Task 2.1: Implement Band Type Rendering

**Priority Order** (implement in this sequence):
1. `:detail` - Most common, simplest
2. `:detail_header` - Similar to detail
3. `:detail_footer` - Similar to detail
4. `:title` - Simple, renders once
5. `:summary` - Simple, renders once
6. `:group_header` - Requires group detection
7. `:group_footer` - Requires group detection
8. `:page_header` - Pagination handling
9. `:page_footer` - Pagination handling
10. `:column_header` - Column layout
11. `:column_footer` - Column layout

**Implementation Pattern** (for each band type):
```elixir
defp render_detail_band(%Band{type: :detail, elements: elements} = band, context) do
  """
  <div class="detail-band" data-band="#{band.name}">
    #{render_band_elements(elements, context)}
  </div>
  """
end
```

#### Task 2.2: Implement Detail Band with Record Iteration

**Challenge**: Detail bands render once per record

**Solution**:
```elixir
defp render_detail_bands(detail_band, records, variables) do
  records
  |> Enum.map(fn record ->
    """
    <div class="detail-record">
      #{render_band_elements(detail_band.elements, record, variables)}
    </div>
    """
  end)
  |> Enum.join("\n")
end
```

#### Task 2.3: Write Tests for Band Rendering
- Test each band type individually
- Test band ordering
- Test nested bands
- Test visibility conditions

---

### Phase 3: Element Rendering (Week 1, Day 5 - Week 2, Day 1)

#### Task 3.1: Implement Element Type Renderers

**Field Element**:
```elixir
defp render_field_element(%{type: :field, source: source} = element, record) do
  value = get_field_value(record, source)
  """
  <span class="field-element" data-field="#{source}">
    <%= #{inspect(value)} %>
  </span>
  """
end

defp get_field_value(record, source) when is_atom(source) do
  Map.get(record, source)
end

defp get_field_value(record, source) when is_list(source) do
  get_in(record, source)
end
```

**Label Element**:
```elixir
defp render_label_element(%{type: :label, text: text} = element) do
  """
  <span class="label-element">
    #{text}
  </span>
  """
end
```

**Expression Element**:
```elixir
defp render_expression_element(%{type: :expression, expression: expr} = element, record, variables) do
  # Expression evaluation is complex - needs CalculationEngine
  # For Phase 1, we'll provide a placeholder
  """
  <span class="expression-element">
    <%= evaluate_expression(#{inspect(expr)}, @record, @variables) %>
  </span>
  """
end
```

**Aggregate Element**:
```elixir
defp render_aggregate_element(%{type: :aggregate, name: var_name} = element, variables) do
  value = Map.get(variables, var_name)
  formatted_value = format_value(value, element.format)
  """
  <span class="aggregate-element" data-variable="#{var_name}">
    #{formatted_value}
  </span>
  """
end
```

#### Task 3.2: Implement Style Generation

```elixir
defp element_style(element) do
  base_styles = [
    position_styles(element.position),
    text_styles(element.style),
    color_styles(element.style),
    border_styles(element.style)
  ]
  
  base_styles
  |> Enum.reject(&is_nil/1)
  |> Enum.join("; ")
end

defp position_styles(%{x: x, y: y, width: w, height: h}) do
  "position: absolute; left: #{x}px; top: #{y}px; width: #{w}px; height: #{h}px"
end

defp text_styles(%{font_size: size, font_weight: weight}) do
  "font-size: #{size}px; font-weight: #{weight}"
end
```

#### Task 3.3: Write Element Rendering Tests
- Test each element type
- Test with various data types
- Test null/missing data handling
- Test formatting

---

### Phase 4: Variable Integration (Week 2, Day 2-3)

#### Task 4.1: Variable Access Helpers

```elixir
defp get_variable_value(variables, variable_name) do
  Map.get(variables, variable_name)
end

defp format_variable_value(value, %{format: format}) when not is_nil(format) do
  apply_format(value, format)
end

defp format_variable_value(value, _element) do
  to_string(value)
end

defp apply_format(value, :currency) do
  Number.Currency.number_to_currency(value)
end

defp apply_format(value, :percentage) do
  "#{Float.round(value * 100, 2)}%"
end

defp apply_format(value, :number) do
  Number.Delimit.number_to_delimited(value)
end

defp apply_format(value, _format) do
  to_string(value)
end
```

#### Task 4.2: Variable Scope Display

Variables may need to show different values based on scope:
- Report-scoped variables: Show once in summary
- Page-scoped variables: Show in page footer
- Group-scoped variables: Show in group footer
- Detail-scoped variables: Show in detail footer

**Implementation**:
```elixir
defp render_scoped_variables(variables, scope, band_type) do
  variables
  |> Enum.filter(fn {_name, var_def} -> var_def.reset_on == scope end)
  |> Enum.map(fn {name, _var} ->
    render_variable_display(name, variables[name])
  end)
  |> Enum.join("\n")
end
```

#### Task 4.3: Write Variable Integration Tests
- Test variable value access
- Test formatting
- Test missing variables
- Test variable scoping

---

### Phase 5: Group Handling (Week 2, Day 4-5)

#### Task 5.1: Group Break Detection

```elixir
defp detect_group_breaks(records, groups) do
  records
  |> Enum.chunk_by(fn record ->
    # Build group key from all group levels
    Enum.map(groups, fn group ->
      get_group_value(record, group.expression)
    end)
  end)
end

defp get_group_value(record, expression) when is_atom(expression) do
  Map.get(record, expression)
end

defp get_group_value(record, expression) when is_list(expression) do
  get_in(record, expression)
end
```

#### Task 5.2: Group Header/Footer Rendering

```elixir
defp render_with_groups(records, report, context) do
  grouped_records = detect_group_breaks(records, report.groups)
  
  grouped_records
  |> Enum.map(fn group_chunk ->
    first_record = List.first(group_chunk)
    group_key = build_group_key(first_record, report.groups)
    
    """
    #{render_group_headers(report, group_key, context)}
    #{render_detail_records(group_chunk, report, context)}
    #{render_group_footers(report, group_key, context)}
    """
  end)
  |> Enum.join("\n")
end
```

#### Task 5.3: Group-Scoped Aggregates

Group footers often display aggregates for that group:
```elixir
defp render_group_footer(group_footer_band, group_key, context) do
  group_data = Map.get(context.groups, group_key, %{})
  group_variables = calculate_group_aggregates(group_data)
  
  """
  <div class="group-footer" data-group="#{inspect(group_key)}">
    #{render_band_elements(group_footer_band.elements, group_variables)}
  </div>
  """
end
```

#### Task 5.4: Write Group Handling Tests
- Test single-level grouping
- Test multi-level grouping
- Test group break detection
- Test group aggregates

---

### Phase 6: Integration & Testing (Week 3, Day 1-2)

#### Task 6.1: End-to-End Integration Tests

Create comprehensive tests that:
1. Define a complete report with all band types
2. Load sample data with grouping
3. Calculate variables
4. Render using BandRenderer
5. Verify HEEX output structure

**Test File**: `/home/pcharbon/code/ash_reports/test/ash_reports/renderers/heex_renderer/band_renderer_integration_test.exs`

#### Task 6.2: Update HeexRendererEnhanced

Ensure the enhanced renderer also uses BandRenderer:
```elixir
# In heex_renderer_enhanced.ex
alias AshReports.HeexRenderer.BandRenderer

defp render_base_heex_content(%RenderContext{} = context) do
  heex_content = BandRenderer.render_report_bands(context)
  {:ok, heex_content}
end
```

#### Task 6.3: Performance Testing

Test with large datasets:
- 10 records (baseline)
- 100 records (typical)
- 1,000 records (large)
- 10,000 records (stress test)

Measure:
- Memory usage
- Rendering time
- HEEX template size

---

### Phase 7: Documentation & Polish (Week 3, Day 3)

#### Task 7.1: Update Module Documentation
- Add comprehensive @moduledoc
- Document all public functions
- Add usage examples
- Document limitations

#### Task 7.2: Add Function Documentation
- Add @doc for all public functions
- Add @spec for type safety
- Add examples in documentation

#### Task 7.3: Create Usage Guide

**File**: `/home/pcharbon/code/ash_reports/guides/heex_band_rendering.md`

Content:
- Overview of band rendering
- How bands map to HEEX
- Variable integration examples
- Group handling examples
- Custom styling examples
- Performance considerations

---

## 5. Success Criteria

### Functional Requirements Met
- [ ] `render_report_bands/1` function exists and is callable
- [ ] All 11 band types render correctly
- [ ] All 7 element types render correctly
- [ ] Variables are accessible and formatted
- [ ] Groups are detected and rendered
- [ ] Aggregates display correct values
- [ ] HEEX output is valid Phoenix.Component markup

### Quality Requirements Met
- [ ] Test coverage > 90%
- [ ] No compiler warnings
- [ ] Passes Credo checks
- [ ] Documentation complete
- [ ] Performance acceptable (<100ms for 100 records)

### Integration Requirements Met
- [ ] HeexRenderer works end-to-end
- [ ] HeexRendererEnhanced works with BandRenderer
- [ ] Compatible with existing RenderContext
- [ ] No breaking changes to existing APIs

---

## 6. Dependencies

### Internal Dependencies
- **AshReports.RenderContext**: Provides data and report structure
- **AshReports.Band**: Band type definitions
- **AshReports.Element**: Element type definitions
- **AshReports.Variable**: Variable definitions
- **AshReports.Group**: Group definitions
- **AshReports.CalculationEngine**: For expression evaluation (may need enhancement)

### External Dependencies
- **Phoenix.Component**: For HEEX compatibility
- **Phoenix.LiveView**: For LiveView integration
- **Number**: For number/currency formatting

---

## 7. Risks & Mitigation

### Risk 1: Expression Evaluation Complexity
**Risk**: Ash.Expr expressions may be complex to evaluate in HEEX context

**Mitigation**:
- Phase 1: Support simple field references only
- Phase 2: Add CalculationEngine integration
- Phase 3: Handle complex expressions
- Always provide fallback values

### Risk 2: Performance with Large Datasets
**Risk**: String concatenation for thousands of records could be slow

**Mitigation**:
- Use IO lists instead of string concatenation
- Implement streaming for large reports
- Add pagination support
- Profile and optimize hot paths

### Risk 3: Group Detection Edge Cases
**Risk**: Complex grouping scenarios may not be handled correctly

**Mitigation**:
- Start with single-level groups
- Test multi-level groups thoroughly
- Document known limitations
- Provide clear error messages

### Risk 4: HEEX Template Escaping
**Risk**: Data values may contain characters that break HEEX syntax

**Mitigation**:
- Use Phoenix.HTML.html_escape/1 for all data values
- Test with special characters
- Validate template output

---

## 8. Future Enhancements

### Phase 2 Features (Post-Initial Implementation)
1. **Conditional Band Rendering**: Evaluate band visibility expressions
2. **Custom Element Types**: Support for plugin element types
3. **Advanced Formatting**: More formatting options for variables/aggregates
4. **Interactive Elements**: LiveView event handlers for elements
5. **Real-Time Updates**: Push variable updates to live views
6. **Template Caching**: Cache compiled HEEX templates
7. **Partial Rendering**: Render individual bands on demand

### Performance Optimizations
1. **Template Compilation**: Compile band templates at build time
2. **Lazy Evaluation**: Stream-based rendering for large reports
3. **Memoization**: Cache repeated calculations
4. **Parallel Rendering**: Render independent bands concurrently

---

## 9. Notes & Considerations

### Architectural Decisions

#### Why Not Use Phoenix.Component Directly?
The function returns a HEEX string that will be embedded in a Phoenix template. We're generating the template code, not executing components. This is by design because:
1. Templates are composed at compile time
2. Allows for template optimization
3. Enables static analysis
4. Supports both LiveView and static HEEX

#### Why Pass Full Context Instead of Just Records?
The `@reports` variable only contains records, but rendering needs:
- Report definition (for band structure)
- Variables (for aggregate display)
- Groups (for group headers/footers)
- Metadata (for formatting, locale, etc.)

Therefore, we need to update the assigns to pass the full RenderContext.

#### Streaming Strategy
For large reports, consider:
```elixir
def render_report_bands_stream(%RenderContext{} = context) do
  Stream.resource(
    fn -> initialize_stream(context) end,
    fn state -> generate_next_band(state) end,
    fn state -> cleanup_stream(state) end
  )
end
```

### Edge Cases to Handle

1. **Empty Records**: Report with no data should still render title/summary
2. **Missing Fields**: Field references that don't exist in record
3. **Null Values**: Variables or fields with nil values
4. **Deeply Nested Groups**: Groups with 3+ levels
5. **Variable Name Conflicts**: Variable and field with same name
6. **Complex Expressions**: Expressions that reference other variables
7. **Circular Dependencies**: Variables that reference each other

### Testing Strategy

**Unit Tests** (Fast, Isolated):
- Each band type renderer
- Each element type renderer
- Style generation
- Value formatting

**Integration Tests** (Medium, Coordinated):
- Band + Element combinations
- Variable integration
- Group handling
- Full context rendering

**End-to-End Tests** (Slow, Comprehensive):
- Complete report rendering
- Multiple format outputs
- Performance benchmarks
- Error scenarios

### Code Quality Standards

- **Complexity**: Keep cyclomatic complexity < 10
- **Function Length**: Keep functions < 50 lines
- **Module Length**: Keep modules < 500 lines
- **Documentation**: 100% of public functions
- **Type Specs**: 100% of public functions
- **Test Coverage**: > 90% line coverage

---

## 10. Architectural Decisions (Answered)

1. **Expression Evaluation**: ✅ **HYBRID APPROACH**
   - Phase 1: Support simple expressions (field references, arithmetic, string concatenation)
   - Phase 2: Add complex Ash.Expr evaluation via CalculationEngine
   - Rationale: Enables basic functionality quickly while deferring complex cases

2. **Formatting Strategy**: ✅ **NUMBER LIBRARY (CLDR.NUMBER)**
   - Use Number/Cldr libraries for internationalization-aware formatting
   - Provides currency, number, percentage formatting with locale support
   - Rationale: Better i18n support, consistent with existing codebase patterns

3. **Error Handling**: ✅ **SHOW ERROR PLACEHOLDER**
   - Display `[MISSING: field_name]` or `[ERROR: description]` in output
   - Makes missing data visible without breaking rendering
   - Rationale: Easy debugging while maintaining graceful degradation

4. **Performance Targets**: ✅ **STANDARD: <200ms for 100 records**
   - Allows for clean initial implementation
   - Realistic for most use cases
   - Will profile and optimize if needed
   - Rationale: Balance between performance and implementation speed

5. **LiveView Integration**: ✅ **STATIC HEEX ONLY**
   - Generate static HEEX templates in Phase 1
   - No LiveView event handlers initially
   - Add interactivity in future phases
   - Rationale: Simpler, faster to implement, meets immediate needs

6. **Template Optimization**: ✅ **PROFILE FIRST, THEN DECIDE**
   - Build without caching initially
   - Measure performance during Phase 6 testing
   - Add caching only if profiling shows it's needed
   - Rationale: Avoid premature optimization

7. **Nested Bands**: ✅ **YES - FULL NESTED SUPPORT**
   - Implement recursive band rendering from the start
   - Support arbitrary nesting depth
   - Rationale: Complete feature set, proper architectural foundation

8. **Column Bands**: ✅ **HIGH PRIORITY - IMPLEMENT FULLY**
   - Build complete column layout support in Phase 1
   - Implement column_header and column_footer band types fully
   - Rationale: Essential for reports using column-based layouts

---

## 11. Implementation Checklist

### Pre-Implementation
- [ ] Review this plan with Pascal
- [ ] Get answers to open questions
- [ ] Confirm success criteria
- [ ] Set up development branch

### Phase 1: Module Structure
- [ ] Create BandRenderer module file
- [ ] Create BandRenderer test file
- [ ] Update HeexRenderer to use BandRenderer
- [ ] Update HeexRenderer assigns structure
- [ ] Write initial smoke tests

### Phase 2: Core Band Rendering
- [ ] Implement detail band rendering
- [ ] Implement title/summary bands
- [ ] Implement group header/footer bands
- [ ] Implement page header/footer bands
- [ ] Implement column header/footer bands
- [ ] Write band rendering tests

### Phase 3: Element Rendering
- [ ] Implement field element renderer
- [ ] Implement label element renderer
- [ ] Implement expression element renderer
- [ ] Implement aggregate element renderer
- [ ] Implement style generation
- [ ] Write element rendering tests

### Phase 4: Variable Integration
- [ ] Implement variable access helpers
- [ ] Implement variable formatting
- [ ] Implement scoped variable display
- [ ] Write variable integration tests

### Phase 5: Group Handling
- [ ] Implement group break detection
- [ ] Implement group header rendering
- [ ] Implement group footer rendering
- [ ] Implement group aggregates
- [ ] Write group handling tests

### Phase 6: Integration & Testing
- [ ] Write end-to-end integration tests
- [ ] Update HeexRendererEnhanced
- [ ] Run performance tests
- [ ] Fix any issues found

### Phase 7: Documentation & Polish
- [ ] Update module documentation
- [ ] Add function documentation
- [ ] Create usage guide
- [ ] Update CHANGELOG
- [ ] Final code review

### Post-Implementation
- [ ] Merge to develop branch
- [ ] Update planning documents
- [ ] Demo to Pascal
- [ ] Gather feedback for Phase 2

---

## 12. Timeline Estimate

**Total Estimated Time**: 3 weeks (15 working days)

| Phase | Tasks | Duration | Dependencies |
|-------|-------|----------|--------------|
| 1. Module Structure | Setup, basic scaffolding | 2 days | None |
| 2. Core Band Rendering | Band type renderers | 2 days | Phase 1 |
| 3. Element Rendering | Element type renderers | 2 days | Phase 2 |
| 4. Variable Integration | Variable access & formatting | 2 days | Phase 3 |
| 5. Group Handling | Group detection & rendering | 2 days | Phase 4 |
| 6. Integration & Testing | E2E tests, performance | 2 days | Phase 5 |
| 7. Documentation | Docs, polish, review | 1 day | Phase 6 |
| Buffer | Unexpected issues | 2 days | All |

**Critical Path**: Phases 1 → 2 → 3 → 4 → 5 → 6 → 7

**Parallel Work Opportunities**:
- Documentation can be written alongside implementation
- Tests can be written before implementation (TDD)
- Performance testing can be done incrementally

---

## 13. References

### Relevant Files
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/heex_renderer.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/heex_renderer_enhanced.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/render_context.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/reports/band.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/reports/element.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/reports/variable.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/reports/variable_state.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/data_loader/group_processor.ex`
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/json_renderer/data_serializer.ex`

### Related Documentation
- Phoenix.Component documentation
- Phoenix.LiveView documentation
- HEEX template syntax
- Ash Framework expression evaluation

### Similar Implementations
- JSON Renderer (for reference on data serialization)
- HTML Renderer (for reference on template generation)
- PDF Renderer (for reference on band/element rendering)

---

## Document Status

This planning document is **READY FOR REVIEW**.

Next steps:
1. Pascal reviews and provides feedback
2. Answer open questions (Section 10)
3. Adjust timeline/scope based on feedback
4. Begin implementation when approved
