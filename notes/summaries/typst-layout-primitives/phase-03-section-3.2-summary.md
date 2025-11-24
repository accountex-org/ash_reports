# Phase 3.2 Summary: Cell and Content Rendering

## Overview

This section implements the Cell and Content Typst renderer modules for generating Typst markup from CellIR and ContentIR. These modules handle cell parameters (colspan, rowspan, align, fill, inset, breakable), content rendering (labels, fields), styling, character escaping, and nested layout support.

## Files Created

### Source Files

1. **`lib/ash_reports/renderer/typst/cell.ex`**
   - Cell renderer generating grid.cell() or table.cell() calls
   - Parameters: colspan, rowspan, align, fill, inset, breakable
   - Simple bracket syntax for cells without parameters
   - Context-aware (grid vs table)
   - Public functions: `render/2`, `build_cell_parameters/2`, `needs_cell_syntax?/1`

2. **`lib/ash_reports/renderer/typst/content.ex`**
   - Content renderer for labels, fields, and nested layouts
   - Styling support via #text() function
   - Character escaping for Typst special characters
   - Field value formatting (number, currency, percent, date, datetime)
   - Nested layout rendering (grid, table, stack)
   - Public functions: `render/2`, `escape_typst/1`, `wrap_with_style/2`, `build_style_parameters/1`, `render_font_weight/1`, `render_color/1`, `format_value/3`

### Updated Files

- **`lib/ash_reports/renderer/typst/grid.ex`** - Updated to use Cell renderer
- **`lib/ash_reports/renderer/typst/table.ex`** - Updated to use Cell renderer
- **`lib/ash_reports/renderer/typst/stack.ex`** - Updated to use Cell renderer

### Test Files

1. **`test/ash_reports/renderer/typst/cell_test.exs`** (26 tests)
   - Tests for simple bracket syntax
   - Tests for colspan/rowspan
   - Tests for cell overrides (align, fill, inset, breakable)
   - Tests for grid vs table context
   - Tests for needs_cell_syntax?

2. **`test/ash_reports/renderer/typst/content_test.exs`** (42 tests)
   - Tests for label rendering with and without styling
   - Tests for field rendering with data interpolation
   - Tests for all format types (number, currency, percent, date)
   - Tests for escape_typst covering all special characters
   - Tests for nested layout rendering
   - Tests for wrap_with_style

## Key Implementation Details

### Cell Renderer

The cell renderer produces either simple bracket syntax or full cell() calls:

```elixir
# Simple cell (no parameters)
[Hello World]

# Cell with colspan
grid.cell(colspan: 2)[Wide cell]

# Cell with multiple overrides
table.cell(colspan: 2, align: center, fill: gray)[Complex cell]
```

### Content Renderer

Content rendering handles labels, fields, and nested layouts:

```elixir
# Label with styling
#text(size: 14pt, weight: "bold", fill: red)[Important]

# Field with currency format (escaped $)
\$99.99

# Nested grid in cell
#grid(
  columns: (1fr, 1fr),
)
```

### Character Escaping

All Typst special characters are escaped:
- `#` `$` `@` `*` `_` `[` `]` `{` `}` `<` `>` `\`

### Style Parameters

Styles are rendered as #text() parameters:
- `size:` for font_size
- `weight:` for font_weight
- `style:` for font_style (italic)
- `fill:` for color
- `font:` for font_family

## Test Results

All 156 tests pass:
- GridTest: 31 tests
- TableTest: 30 tests
- StackTest: 27 tests
- CellTest: 26 tests
- ContentTest: 42 tests

## Design Decisions

1. **Simple Bracket Syntax**: Cells without parameters use `[content]` instead of `grid.cell()[content]` for cleaner output.

2. **Context-Aware Prefixes**: Cell renderer uses `grid.cell()` or `table.cell()` based on context parameter.

3. **Eager Escaping**: All text content is escaped immediately when rendered, ensuring safety throughout.

4. **Reusing Grid Helpers**: Cell renderer reuses `Grid.render_alignment/1`, `Grid.render_fill/1`, and `Grid.render_length/1` to avoid duplication.

5. **Format at Render Time**: Field values are formatted during render, allowing data to flow through unmodified until final output.

## Dependencies

- `AshReports.Layout.IR.Cell` - Cell IR struct
- `AshReports.Layout.IR.Content` - Content IR types (Label, Field, NestedLayout)
- `AshReports.Layout.IR.Style` - Style IR struct
- `AshReports.Renderer.Typst.Grid` - For rendering helpers

## Integration

The Cell renderer is now used by:
- Grid renderer for cell children
- Table renderer for cell children, headers, and footers
- Stack renderer for cell children

## Next Steps

- Section 3.3: Property rendering utilities
- Section 3.4: Line rendering (hline/vline)
- Section 3.5: Data interpolation and formatting
