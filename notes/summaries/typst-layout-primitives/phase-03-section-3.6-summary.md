# Phase 3.6 Summary: Text Styling

## Overview

This section implements a dedicated Styling module for applying text styling using Typst's #text() function. The module provides a clean API for wrapping text with font size, weight, style, color, and family properties.

## Files Created

### Source Files

1. **`lib/ash_reports/renderer/typst/styling.ex`**
   - Text styling via Typst #text() function
   - Support for font_size, font_weight, font_style, color, font_family
   - Efficient combination of multiple style properties
   - Public functions: `apply_style/2`, `wrap_with_text/2`, `build_style_parameters/1`, `render_font_weight/1`, `render_color/1`, `has_styling?/1`

### Test Files

1. **`test/ash_reports/renderer/typst/styling_test.exs`** (44 tests)
   - Tests for apply_style with various style properties
   - Tests for wrap_with_text
   - Tests for build_style_parameters
   - Tests for render_font_weight (all weight variants)
   - Tests for render_color (named, hex, atom)
   - Tests for has_styling?
   - Integration scenarios

## Key Implementation Details

### Style Application

The module wraps text with #text() only when styling is needed:

```elixir
# No styling - returns text unchanged
apply_style("Hello", nil) → "Hello"
apply_style("Hello", %Style{}) → "Hello"

# With styling - wraps with #text()
apply_style("Hello", %Style{font_weight: :bold})
→ "#text(weight: \"bold\")[Hello]"
```

### Style Properties

All standard Typst text properties are supported:

| Property | Typst Parameter | Example |
|----------|----------------|---------|
| font_size | size | `size: 14pt` |
| font_weight | weight | `weight: "bold"` |
| font_style | style | `style: "italic"` |
| color | fill | `fill: red` |
| font_family | font | `font: "Arial"` |

### Font Weight Rendering

Supports all standard font weights:

```elixir
render_font_weight(:normal) → "\"regular\""
render_font_weight(:bold) → "\"bold\""
render_font_weight(:light) → "\"light\""
render_font_weight(:medium) → "\"medium\""
render_font_weight(:semibold) → "\"semibold\""
render_font_weight(:thin) → "\"thin\""
render_font_weight(:black) → "\"black\""
render_font_weight(:extrabold) → "\"extrabold\""
render_font_weight(:extralight) → "\"extralight\""
render_font_weight(400) → "400"  # numeric weights
```

### Color Rendering

Handles named colors and hex values:

```elixir
render_color("red") → "red"
render_color(:blue) → "blue"
render_color("#ff0000") → "rgb(\"#ff0000\")"
```

### Combined Styles

Multiple style properties are combined into a single #text() call:

```elixir
style = %Style{
  font_size: "24pt",
  font_weight: :bold,
  color: "#333333"
}

apply_style("Title", style)
→ "#text(size: 24pt, weight: \"bold\", fill: rgb(\"#333333\"))[Title]"
```

## Test Results

All 325 tests pass:
- GridTest: 31 tests
- TableTest: 30 tests
- StackTest: 27 tests
- CellTest: 26 tests
- ContentTest: 42 tests
- PropertyRenderingTest: 48 tests
- LinesTest: 30 tests
- InterpolationTest: 47 tests
- StylingTest: 44 tests

## Design Decisions

1. **Dedicated Module**: Extracted styling into a separate module for better reusability and testing.

2. **Efficient Combination**: Multiple style properties are combined into a single #text() call for cleaner output.

3. **Empty Style Handling**: Text is returned unchanged when no styling is needed, avoiding unnecessary #text() wrappers.

4. **Comprehensive Weight Support**: All standard font weights including numeric values are supported.

5. **Hex Color Conversion**: Hex colors are automatically wrapped in rgb() for Typst compatibility.

## Dependencies

- `AshReports.Layout.IR.Style` - Style IR struct

## Integration

The Styling module can be used by:
- Content renderer for label and field styling
- Cell renderer for cell content styling
- Any component that needs to apply text styling

## Usage Example

```elixir
alias AshReports.Layout.IR.Style
alias AshReports.Renderer.Typst.Styling

# Report title
title_style = %Style{
  font_size: "24pt",
  font_weight: :bold,
  color: "#333333"
}
Styling.apply_style("Monthly Sales Report", title_style)
# → "#text(size: 24pt, weight: \"bold\", fill: rgb(\"#333333\"))[Monthly Sales Report]"

# Column header
header_style = %Style{font_weight: :semibold, color: "gray"}
Styling.apply_style("Product Name", header_style)
# → "#text(weight: \"semibold\", fill: gray)[Product Name]"
```

## Next Steps

- Section 3.7: Renderer integration (main entry point)
- Section 3.8: Internationalization (locale-aware formatting)
