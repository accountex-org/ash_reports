# Phase 3.1 Summary: Core Typst Generation

## Overview

This section implements the Typst renderer modules for generating Typst markup from the Intermediate Representation (IR) created in Phase 2. These modules convert IR structs into valid Typst code for grid, table, and stack layouts.

## Files Created

### Source Files

1. **`lib/ash_reports/renderer/typst/grid.ex`**
   - Core Typst grid renderer
   - Renders all grid parameters: columns, rows, gutter, column-gutter, row-gutter, align, inset, fill, stroke
   - Public helper functions: `render_columns/1`, `render_rows/1`, `render_track_size/1`, `render_alignment/1`, `render_fill/1`, `render_stroke/1`, `render_length/1`
   - `build_parameters/1` is public for reuse by Table renderer

2. **`lib/ash_reports/renderer/typst/table.ex`**
   - Table renderer extending grid functionality
   - Adds table-specific features: `table.header()` and `table.footer()` sections
   - Default stroke of "1pt" via `apply_table_defaults/1`
   - Support for `repeat` parameter on headers/footers

3. **`lib/ash_reports/renderer/typst/stack.ex`**
   - Stack renderer for vertical/horizontal stacking
   - Parameters: `dir` (ttb, btt, ltr, rtl) and `spacing`
   - Recursive nested layout rendering for grids, tables, and stacks

### Test Files

1. **`test/ash_reports/renderer/typst/grid_test.exs`** (31 tests)
   - Tests for all grid parameters
   - Tests for track size rendering (fr, pt, cm, auto)
   - Tests for alignment (single and combined)
   - Tests for fill (colors, hex, none)
   - Tests for stroke values

2. **`test/ash_reports/renderer/typst/table_test.exs`** (30 tests)
   - Tests for table defaults (stroke: 1pt)
   - Tests for header/footer rendering with repeat
   - Tests for integration with headers, cells, and footers
   - Tests for apply_table_defaults

3. **`test/ash_reports/renderer/typst/stack_test.exs`** (27 tests)
   - Tests for all directions
   - Tests for spacing (string and numeric)
   - Tests for nested layouts (grid, table, stack)
   - Tests for indentation handling

## Key Implementation Details

### Grid Renderer

The grid renderer converts IR properties to Typst syntax:

```elixir
# IR input
IR.grid(properties: %{
  columns: ["1fr", "2fr"],
  rows: ["auto"],
  gutter: "10pt",
  align: {:left, :top},
  fill: "#ff0000"
})

# Typst output
#grid(
  columns: (1fr, 2fr),
  rows: (auto),
  gutter: 10pt,
  align: left + top,
  fill: rgb("#ff0000"),
)
```

### Table Renderer

Tables extend grids with header/footer support:

```elixir
# Typst output with header
#table(
  columns: (1fr),
  stroke: 1pt,
  table.header(repeat: true,
    [Name]
  )
  [Alice]
  table.footer(
    [Total]
  )
)
```

### Stack Renderer

Stacks support nesting of other layouts:

```elixir
# Nested layouts
#stack(
  dir: ttb,
  spacing: 10pt,
  #grid(
    columns: (1fr, 1fr),
  )
)
```

## Test Results

All 88 tests pass:
- GridTest: 31 tests
- TableTest: 30 tests
- StackTest: 27 tests

## Design Decisions

1. **Public Helper Functions**: Helper functions like `render_track_size/1` and `render_alignment/1` are public with @doc and @spec for reuse and testing.

2. **Grid Reuse**: Table renderer reuses `Grid.build_parameters/1` to avoid code duplication.

3. **Recursive Rendering**: Stack renderer recursively renders nested grids, tables, and stacks with proper indentation.

4. **Hex Color Handling**: Hex colors are wrapped in `rgb("#...")` for Typst compatibility.

5. **Default Stroke for Tables**: Tables automatically get `stroke: 1pt` if not specified.

## Dependencies

- `AshReports.Layout.IR` - Intermediate Representation structs
- Grid renderer is used by both Table and Stack for shared functionality

## Next Steps

- Section 3.2: Cell content rendering with formatting
- Section 3.3: Page setup and document structure
- Integration with overall report generation pipeline
