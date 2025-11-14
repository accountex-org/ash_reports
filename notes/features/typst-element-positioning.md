# Typst Element Positioning and Styling Implementation Plan

## ✅ Implementation Status: COMPLETED

**Completion Date:** 2025-11-14
**Branch:** `feature/typst-element-positioning`
**Tests:** 43/43 passing

### Accomplishments

✅ **Phase 1: Research & Planning** (Completed)
- Researched Typst positioning and styling syntax
- Documented `place()` and `text()` function usage
- Identified color format requirements (rgb() without # prefix)
- Discovered alignment-based positioning options
- Created comprehensive implementation plan

✅ **Phase 2: Core Implementation** (Completed)
- Implemented position attribute extraction (`extract_position/1`)
- Implemented style attribute extraction (`extract_style/1`)
- Created Typst code generators:
  - `generate_position_wrapper/2` for `place()` positioning with dual modes:
    - **Absolute positioning**: `position x: 100, y: 50` → `place(dx: 100pt, dy: 50pt)`
    - **Alignment-based positioning**: `position align: [:top, :center]` → `place(top + center)`
  - `alignment_to_typst/1` for alignment atom conversion
  - `build_alignment_string/1` for combining multiple alignments
  - `generate_style_wrapper/2` for `text()` styling
  - `build_style_params/1` for style parameter formatting
  - `apply_element_wrappers/2` for wrapper application
  - `strip_outer_brackets/1` for bracket management
- Updated all element generation functions (label, field, expression, aggregate)
- Fixed Typst syntax issues:
  - Removed `#` prefix generation (function body is in code mode)
  - Strip `#` from color hex codes for `rgb()` function
- Maintained backward compatibility for elements without position/style

✅ **Phase 3: Testing** (Completed)
- Added 15 comprehensive unit tests for absolute positioning and styling
- Added 9 comprehensive unit tests for alignment-based positioning
- Added 4 integration tests with PDF compilation
- All 43 tests passing
- Tests cover:
  - Absolute positioned elements (dx/dy)
  - Alignment-based positioned elements (center, top, bottom, horizon, left, right)
  - Combined alignments (top + center, bottom + right, etc.)
  - Styled elements
  - Mixed position + style
  - Backward compatibility
  - PDF compilation verification
  - Invalid alignment handling

✅ **Phase 4: Alignment Enhancement** (Completed - 2025-11-14)
- Added support for Typst alignment-based positioning
- Supports all Typst alignment values: center, top, bottom, horizon, left, right, start, end
- Supports combined alignments using `+` operator
- Both single alignment (`align: :center`) and multiple (`align: [:top, :center]`) work
- Filters out invalid alignment values gracefully

### Key Technical Decisions

1. **No `#` Prefix in Function Body**: Inside Typst function bodies, we're in code mode, so function calls don't need `#` prefix
2. **Color Format**: Strip `#` from hex colors before passing to `rgb()` function
3. **Wrapper Order**: Position wrapper (outer) → Style wrapper (inner) → Content
4. **Bracket Handling**: Strip outer brackets from content before applying wrappers
5. **Backward Compatibility**: Elements without position/style render normally
6. **Dual Positioning Modes**: Support both absolute (dx/dy) and alignment-based positioning, but not mixed
7. **Alignment Validation**: Invalid alignment atoms are filtered out, valid ones are preserved

### Files Modified

- `lib/ash_reports/typst/dsl_generator.ex` (762-826 modified, alignment support added)
- `test/ash_reports/typst/dsl_generator_test.exs` (626-750 new alignment tests)

## Usage Examples

### Absolute Positioning (dx/dy mode)

Use absolute positioning when you need precise pixel-perfect placement:

```elixir
# Single element with absolute positioning
label :company_logo do
  text("ACME Corp")
  position x: 50, y: 20
  style font_size: 16, font_weight: "bold"
end
```

**Generates:**
```typst
place(dx: 50pt, dy: 20pt)[text(size: 16pt, weight: "bold")[ACME Corp]]
```

### Alignment-Based Positioning

Use alignment-based positioning for responsive layouts:

#### Center Alignment

```elixir
# Horizontally and vertically centered
label :report_title do
  text("Annual Report 2024")
  position align: :center
  style font_size: 24, font_weight: "bold"
end
```

**Generates:**
```typst
place(center)[text(size: 24pt, weight: "bold")[Annual Report 2024]]
```

#### Top-Center Alignment

```elixir
# Centered horizontally, aligned to top
label :page_header do
  text("Company Confidential")
  position align: [:top, :center]
  style font_size: 12, color: "#999999"
end
```

**Generates:**
```typst
place(top + center)[text(size: 12pt, fill: rgb("999999"))[Company Confidential]]
```

#### Bottom-Right Alignment

```elixir
# Page number in bottom-right corner
label :page_number do
  text("Page 1")
  position align: [:bottom, :right]
  style font_size: 10
end
```

**Generates:**
```typst
place(bottom + right)[text(size: 10pt)[Page 1]]
```

#### Vertical Centering with Horizon

```elixir
# Vertically and horizontally centered using horizon
label :watermark do
  text("DRAFT")
  position align: [:horizon, :center]
  style font_size: 48, color: "#CCCCCC"
end
```

**Generates:**
```typst
place(horizon + center)[text(size: 48pt, fill: rgb("CCCCCC"))[DRAFT]]
```

### Available Alignment Values

**Horizontal:**
- `:left` - Align to left edge
- `:center` - Horizontally centered
- `:right` - Align to right edge
- `:start` - Align to start (left in LTR, right in RTL)
- `:end` - Align to end (right in LTR, left in RTL)

**Vertical:**
- `:top` - Align to top edge
- `:horizon` - Vertically centered (middle)
- `:bottom` - Align to bottom edge

**Combining Alignments:**

Use a list to combine vertical and horizontal alignment:

```elixir
position align: [:top, :left]      # Top-left corner
position align: [:top, :center]    # Top-center
position align: [:top, :right]     # Top-right corner
position align: [:horizon, :left]  # Vertically centered, left-aligned
position align: [:horizon, :center] # Fully centered
position align: [:bottom, :center] # Bottom-center
```

### Styling Without Positioning

You can apply styling without positioning:

```elixir
label :emphasized_text do
  text("Important Notice")
  style font_size: 16, color: "#FF0000", font_weight: "bold"
end
```

**Generates:**
```typst
text(size: 16pt, fill: rgb("FF0000"), weight: "bold")[Important Notice]
```

### Complete Example in a Report

```elixir
report :customer_summary do
  title("Customer Summary Report")
  driving_resource(MyApp.Customer)

  band :title do
    type :title

    # Centered title
    label :report_title do
      text("Customer Summary Report")
      position align: [:top, :center]
      style font_size: 24, color: "#2F5597", font_weight: "bold"
    end

    # Company logo in top-left
    label :company_logo do
      text("ACME Corp")
      position x: 50, y: 20
      style font_size: 14, font_weight: "bold"
    end

    # Date in top-right
    field :report_date do
      source {:parameter, :report_date}
      position align: [:top, :right]
      style font_size: 10, color: "#666666"
    end
  end

  band :customer_detail do
    type :detail

    field :customer_name do
      source {:resource, :name}
      style font_size: 12, font_weight: "bold"
    end

    field :customer_email do
      source {:resource, :email}
      style font_size: 10, color: "#666666"
    end
  end
end
```

## Problem Statement

The AshReports DSL currently defines `position` and `style` attributes in the `base_element_schema` that all report elements inherit (Label, Field, Expression, Aggregate, Line, Box, Image). However, the Typst template generator (`AshReports.Typst.DSLGenerator`) completely ignores these attributes when generating Typst templates.

**Current State:**
- DSL accepts position attributes (x, y, width, height)
- DSL accepts style attributes (font, color, alignment, font_size, font_weight, etc.)
- Generator outputs only element content without any positioning or styling

**Impact:**
- Reports cannot have custom element positioning
- All elements use default Typst styling
- No control over element layout or appearance
- Limits report design flexibility significantly

**Example of the Gap:**
```elixir
# DSL allows this:
label :title_label do
  text("Customer Summary Report")
  position x: 100, y: 50, width: 400, height: 60
  style font_size: 18, color: "#2F5597", font_weight: "bold"
end

# But generator outputs only:
"[Customer Summary Report]"

# Should output:
"#place(dx: 100pt, dy: 50pt)[#text(size: 18pt, fill: rgb(\"#2F5597\"), weight: \"bold\")[Customer Summary Report]]"
```

## Solution Overview

Enhance the Typst DSL generator to extract and apply `position` and `style` attributes from DSL elements, generating appropriate Typst positioning and styling commands.

**High-Level Approach:**
1. Create helper functions to extract position and style attributes from elements
2. Create Typst code generators for positioning (`place()`) and styling (`text()`)
3. Wrap element content with positioning and styling wrappers
4. Maintain backward compatibility for elements without these attributes
5. Support all element types (label, field, expression, aggregate, line, box, image)

**Key Design Decisions:**
- Use Typst's `place()` function for absolute positioning with dx/dy offsets
- Use Typst's `text()` function for text styling
- Apply position wrapping as outermost wrapper, style wrapping as inner wrapper
- Convert DSL color hex codes to Typst `rgb()` format
- Convert DSL units (assumed pixels) to Typst points (pt)
- Only apply wrappers when attributes are present (no-op when empty)

**Architecture Considerations:**
- All changes isolated to `AshReports.Typst.DSLGenerator` module
- No changes to DSL schema (already supports these attributes)
- Generator remains pure functional with no state
- Maintains existing test patterns and structure

## Agent Consultations Performed

- **research-agent**: Consulted Typst documentation for positioning and styling syntax
  - `place()` function for absolute positioning
  - `text()` function for text styling
  - `rgb()` function for color specification
  - Unit conversion (pixels to points)

## Technical Details

### File Locations

**Primary Implementation:**
- `/home/pcharbon/code/ash_reports/lib/ash_reports/typst/dsl_generator.ex`
  - Lines 380-459: Element generation functions (need modification)
  - New helper functions for position/style extraction and Typst code generation

**DSL Schema Reference:**
- `/home/pcharbon/code/ash_reports/lib/ash_reports/dsl.ex:1088-1110`
  - `base_element_schema()` defines position and style attributes

**Test Files:**
- `/home/pcharbon/code/ash_reports/test/ash_reports/typst/dsl_generator_test.exs`
  - Add new test cases for positioned and styled elements
  - Update integration tests to verify PDF compilation

### Dependencies

- **Elixir Standard Library**: Map, Keyword list manipulation
- **Typst Syntax**: `place()`, `text()`, `rgb()` functions
- **Existing Infrastructure**: `BinaryWrapper.compile/2` for integration tests

### Configuration

No configuration changes required. Feature is opt-in through DSL element definitions.

### Typst Syntax Reference

**Positioning:**
```typst
#place(dx: 100pt, dy: 50pt)[Content here]
```

**Styling:**
```typst
#text(size: 18pt, fill: rgb("#2F5597"), weight: "bold", font: "Liberation Serif")[Content here]
```

**Combined:**
```typst
#place(dx: 100pt, dy: 50pt)[#text(size: 18pt, fill: rgb("#2F5597"), weight: "bold")[Content here]]
```

## Success Criteria

### CRITICAL: Feature requires comprehensive test coverage

**All tests must pass including:**
- Unit tests for position/style extraction functions
- Unit tests for Typst code generation functions
- Integration tests for each element type with positioning
- Integration tests for each element type with styling
- Integration tests for combined positioning and styling
- Backward compatibility tests (elements without position/style)
- PDF compilation tests verifying generated templates compile successfully

### Feature Verification

- Elements with position attributes render at specified coordinates
- Elements with style attributes render with specified styling
- Elements without position/style render as before (backward compatible)
- All element types support positioning and styling (label, field, expression, etc.)
- Generated Typst templates compile to valid PDFs
- Manual verification: Generated PDFs display positioned and styled elements correctly

### Performance Requirements

- No significant performance degradation in template generation
- Position/style extraction should be O(1) Map access operations

## Implementation Plan

### Step 1: Research Typst Syntax

- [x] Research Typst `place()` function for positioning
- [x] Research Typst `text()` function for styling
- [x] Research Typst `rgb()` function for colors
- [x] Understand unit conversion requirements

### Step 2: Create Helper Functions for Attribute Extraction

- [ ] Create `extract_position/1` function to extract position keyword list from element
- [ ] Create `extract_style/1` function to extract style keyword list from element
- [ ] Create `has_position?/1` predicate to check if element has position attributes
- [ ] Create `has_style?/1` predicate to check if element has style attributes
- [ ] Add unit tests for extraction functions

### Step 3: Create Typst Code Generators

- [ ] Create `generate_position_wrapper/2` to wrap content with `place()`
  - Convert x/y to dx/dy with pt units
  - Support width/height if needed
  - Return content unwrapped if no position
- [ ] Create `generate_style_wrapper/2` to wrap content with `text()`
  - Convert font_size to size parameter
  - Convert color hex to rgb() format
  - Convert font_weight to weight parameter
  - Support font family parameter
  - Return content unwrapped if no style
- [ ] Add unit tests for wrapper generation

### Step 4: Update Element Generation Functions

- [ ] Update `generate_label_element/2` to apply position/style wrappers
- [ ] Update `generate_field_element/2` to apply position/style wrappers
- [ ] Update `generate_expression_element/2` to apply position/style wrappers (if exists)
- [ ] Update `generate_aggregate_element/2` to apply position/style wrappers (if exists)
- [ ] Ensure wrapper application order: position (outer), style (inner), content
- [ ] Add unit tests for each updated function

### Step 5: Comprehensive Testing

- [ ] Create test report definitions with positioned elements
- [ ] Create test report definitions with styled elements
- [ ] Create test report definitions with both positioning and styling
- [ ] Test backward compatibility (elements without attributes)
- [ ] Run integration tests with PDF compilation
- [ ] Verify generated Typst templates are syntactically correct
- [ ] Manual PDF verification for positioning accuracy

### Step 6: Update Documentation

- [ ] Update phase-01 plan to mark positioning feature as complete
- [ ] Create implementation summary in notes/summaries
- [ ] Document Typst positioning and styling capabilities
- [ ] Provide DSL usage examples for positioned/styled elements

## Notes/Considerations

### Edge Cases

- **Empty position/style maps**: Functions should handle gracefully (no-op)
- **Partial attributes**: If only x specified without y, should default y to 0
- **Invalid color formats**: Should validate color hex format or use default
- **Unit conversion edge cases**: Very large or small coordinates

### Future Improvements

- Support relative positioning (not just absolute)
- Support responsive positioning based on page dimensions
- Support z-index/layering for overlapping elements
- Support rotation and transformation attributes
- Support box element styling (borders, backgrounds)
- Support alignment attributes (left, center, right, justify)

### Related Technical Debt

- Consider extracting Typst code generation into separate module if it grows
- Consider creating a Typst DSL builder for cleaner code generation
- Line and Box elements have some property support but not general position/style

### Risk Assessment

**Low Risk:**
- Changes isolated to generator module
- No DSL schema changes required
- Backward compatible by design
- Comprehensive test coverage planned

**Mitigation:**
- Extensive unit and integration testing
- Manual PDF verification
- Gradual rollout (can be feature-flagged if needed)

## Test Strategy

### Unit Tests

**Position/Style Extraction:**
- Test `extract_position/1` with various position keyword lists
- Test `extract_style/1` with various style keyword lists
- Test predicates with elements that have/don't have attributes

**Typst Code Generation:**
- Test `generate_position_wrapper/2` with various position values
- Test `generate_style_wrapper/2` with various style values
- Test wrapper generation with empty/nil attributes (should be no-op)
- Test color hex conversion to rgb() format
- Test unit conversion (pixels to points)

**Element Generation:**
- Test each updated element generation function with position
- Test each updated element generation function with style
- Test each updated element generation function with both
- Test backward compatibility (no position/style)

### Integration Tests

**Template Compilation:**
- Generate template with positioned label, compile to PDF
- Generate template with styled label, compile to PDF
- Generate template with positioned and styled field, compile to PDF
- Generate template with mix of positioned/styled/default elements, compile to PDF

**All Element Types:**
- Test positioning for: Label, Field, Expression, Aggregate
- Test styling for: Label, Field, Expression, Aggregate
- Verify Line and Box elements maintain existing behavior

### Manual Verification

- Visual inspection of generated PDFs
- Verify elements appear at specified coordinates
- Verify styling (colors, fonts, weights) rendered correctly
- Verify no regression in existing reports

## Estimated Effort

**Medium**: Implementation is straightforward but requires comprehensive testing and verification.

- Helper functions: 2-3 hours
- Typst code generators: 2-3 hours
- Element generation updates: 2-3 hours
- Unit tests: 3-4 hours
- Integration tests: 2-3 hours
- Manual verification and documentation: 2 hours

**Total: ~15-20 hours**

## Ready for Implementation

**Yes** - Requirements are clear, Typst syntax is well-documented, and implementation approach is well-defined.

---

**Created:** 2025-11-13
**Branch:** feature/typst-element-positioning
**Status:** Ready for implementation
