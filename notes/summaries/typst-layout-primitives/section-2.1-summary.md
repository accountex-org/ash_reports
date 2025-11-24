# Section 2.1 Implementation Summary: IR Data Structures

## Overview

This section implements the Intermediate Representation (IR) data structures for the layout system. The IR provides a normalized format that transforms parsed DSL entities into a consistent data structure suitable for all renderers (Typst, HTML, JSON).

## Completed Tasks

### 2.1.1 Layout IR Types ✅
- Created `AshReports.Layout.IR` module with LayoutIR struct
- Implemented type field supporting `:grid | :table | :stack`
- Added properties map, children list, lines list, headers list, footers list
- Convenience constructors: `IR.grid/1`, `IR.table/1`, `IR.stack/1`
- Helper functions: `add_child/2`, `add_line/2`, `add_header/2`, `add_footer/2`
- Property accessors: `put_property/3`, `get_property/3`

### 2.1.2 Cell and Row IR Types ✅
- Created `AshReports.Layout.IR.Cell` with position `{x, y}` tuple (0-indexed)
- Implemented span as `{colspan, rowspan}` tuple
- Added `occupied_positions/1` for calculating all positions covered by spans
- Accessor functions: `x/1`, `y/1`, `colspan/1`, `rowspan/1`
- Created `AshReports.Layout.IR.Row` with index, properties, and cells

### 2.1.3 Content IR Types ✅
- Created `AshReports.Layout.IR.Content` module with nested types:
  - `Label` - Static text with style
  - `Field` - Dynamic field values with source, format, decimal_places
  - `NestedLayout` - Nested layout containers within cells
- Convenience constructors: `Content.label/2`, `Content.field/2`, `Content.nested_layout/1`
- Type detection: `Content.content_type/1`

### 2.1.4 Supporting IR Types ✅
- Created `AshReports.Layout.IR.Line` for horizontal/vertical lines
  - Convenience: `Line.hline/2`, `Line.vline/2`
  - Predicates: `horizontal?/1`, `vertical?/1`
- Created `AshReports.Layout.IR.Header` for table headers
  - Fields: repeat (boolean | :group), level, rows
- Created `AshReports.Layout.IR.Footer` for table footers
  - Fields: repeat (boolean), rows
- Created `AshReports.Layout.IR.Style` for styling properties
  - Font properties: size, weight, style, family
  - Color properties: color, background_color
  - Alignment: text_align, vertical_align
  - Layout: padding, border
  - Helper: `Style.merge/2`, `Style.empty?/1`

### Unit Tests ✅
- 51 tests covering all IR struct creation
- Tests for nested IR structures
- Tests for complex scenarios (table with header/footer, nested layouts)
- All tests passing

## Files Created

```
lib/ash_reports/layout/ir.ex                    # Main LayoutIR module
lib/ash_reports/layout/ir/cell.ex               # CellIR struct
lib/ash_reports/layout/ir/row.ex                # RowIR struct
lib/ash_reports/layout/ir/content.ex            # Content IR types (Label, Field, NestedLayout)
lib/ash_reports/layout/ir/line.ex               # LineIR struct
lib/ash_reports/layout/ir/header.ex             # HeaderIR struct
lib/ash_reports/layout/ir/footer.ex             # FooterIR struct
lib/ash_reports/layout/ir/style.ex              # StyleIR struct
test/ash_reports/layout/ir_test.exs             # Unit tests
```

## Architecture Decisions

### Position Representation
- Used `{x, y}` tuples for cell positions (0-indexed)
- x = column index, y = row index
- Consistent with Typst's grid.cell(x, y) syntax

### Span Representation
- Used `{colspan, rowspan}` tuples
- Allows easy calculation of occupied positions
- Natural representation for 2D spanning

### Content Polymorphism
- Content types are separate structs under the Content module
- Union type `Content.t()` allows heterogeneous content in cells
- `content_type/1` function for type detection during rendering

### Style Merging
- Styles can be merged with override semantics
- nil values in override don't replace base values
- Enables property inheritance chain: grid/table -> row -> cell -> content

## Usage Examples

```elixir
# Create a simple grid IR
alias AshReports.Layout.IR
alias AshReports.Layout.IR.{Cell, Content, Style}

style = Style.new(font_weight: :bold)
label = Content.label("Total:", style: style)
field = Content.field(:amount, format: :currency)

cell1 = Cell.new(position: {0, 0}, content: [label])
cell2 = Cell.new(position: {1, 0}, content: [field])

grid = IR.grid(
  properties: %{columns: ["1fr", "1fr"]},
  children: [cell1, cell2]
)

# Create a table with header
header = Header.new(repeat: true, rows: [header_row])
table = IR.table(
  properties: %{stroke: "1pt"},
  headers: [header],
  children: data_rows
)
```

## Next Steps

Section 2.1 provides the foundation for:
- **Section 2.2**: DSL to IR Transformers - Convert DSL entities to IR
- **Section 2.3**: Cell Positioning Engine - Calculate cell positions and handle spans
- **Section 2.4**: Property Resolution - Resolve property inheritance

## Test Results

```
51 tests, 0 failures
```

All tests pass successfully, validating:
- Struct creation for all IR types
- Property accessors and mutators
- Span calculations and occupied positions
- Style merging
- Nested IR structures
- Complex table with header/footer scenarios
