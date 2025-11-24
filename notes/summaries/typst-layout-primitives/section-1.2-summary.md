# Section 1.2 Implementation Summary: Row and Cell Entities

## Date: 2024-11-20

## Branch: `feature/row-cell-entities`

## Overview

Implemented Row, Cell, Header, and Footer entities for the Typst layout primitives DSL. A key architectural decision was made to use **distinct cell types** (GridCell, TableCell) instead of a single generic Cell entity to avoid circular dependencies in Spark DSL entity definitions.

## Implementation Details

### Architectural Decision: Distinct Cell Types

The original plan called for a single `Cell` entity that could contain nested layout containers (grids, tables, stacks). However, this created circular dependencies:

```
grid_entity → cell_entity → grid_entity (infinite loop)
```

**Solution**: Create separate cell types for grids and tables, each containing only leaf elements (no nested containers):

- `GridCell` - for grids, with x/y positioning
- `TableCell` - for tables, with colspan/rowspan

Nested layouts within cells can be added later using a "layout element" approach or lazy evaluation pattern.

### Files Created

1. **`lib/ash_reports/layout/grid_cell.ex`**
   - x, y positioning
   - align, fill, stroke, inset overrides
   - Contains leaf elements only

2. **`lib/ash_reports/layout/table_cell.ex`**
   - colspan, rowspan spanning
   - x, y positioning
   - align, fill, stroke, inset, breakable
   - Contains leaf elements only

### Files Updated

1. **`lib/ash_reports/dsl.ex`**
   - Added `grid_cell_entity()` and `grid_cell_schema()`
   - Added `table_cell_entity()` and `table_cell_schema()`
   - Updated `grid_entity()` to use `grid_cells: [grid_cell_entity()]`
   - Updated `table_entity()` to use `table_cells: [table_cell_entity()]`
   - Updated `row_entity()` to contain `elements` instead of cells
   - Updated `header_entity()` and `footer_entity()` to use `table_cells`

2. **`lib/ash_reports/layout/grid.ex`**
   - Changed `cells` field to `grid_cells`

3. **`lib/ash_reports/layout/table.ex`**
   - Changed `cells` field to `table_cells`

4. **`lib/ash_reports/layout/row.ex`**
   - Changed `cells` field to `elements`

5. **`lib/ash_reports/layout/header.ex`**
   - Changed `cells` field to `table_cells`

6. **`lib/ash_reports/layout/footer.ex`**
   - Changed `cells` field to `table_cells`

### Files Removed

- `lib/ash_reports/layout/cell.ex` - Replaced by GridCell and TableCell

### Test Fixtures Added

- `AshReports.Test.GridCellDomain` - Tests grid cell positioning and properties
- `AshReports.Test.TableCellDomain` - Tests table cell spanning and properties
- `AshReports.Test.TableHeaderFooterDomain` - Tests header/footer with table cells
- `AshReports.Test.RowEntityDomain` - Tests row with elements

### Tests Added

New test sections in `test/ash_reports/layout_container_test.exs`:

- Grid cell entity parsing (3 tests)
- Table cell entity parsing (3 tests)
- Header and footer entity parsing (4 tests)
- Row entity parsing (3 tests)

## Property Summary

### GridCell Properties

| Property | Type | Description |
|----------|------|-------------|
| name | atom | Optional identifier |
| x | non_neg_integer | Column position (0-indexed) |
| y | non_neg_integer | Row position (0-indexed) |
| align | atom/tuple | Cell alignment |
| fill | string | Background color |
| stroke | string | Border stroke |
| inset | string | Padding |

### TableCell Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| name | atom | nil | Optional identifier |
| colspan | pos_integer | 1 | Columns to span |
| rowspan | pos_integer | 1 | Rows to span |
| x | non_neg_integer | nil | Column position |
| y | non_neg_integer | nil | Row position |
| align | atom/tuple | nil | Cell alignment |
| fill | string | nil | Background color |
| stroke | string | nil | Border stroke |
| inset | string | nil | Padding |
| breakable | boolean | true | Allow page breaks |

### Row Properties

| Property | Type | Description |
|----------|------|-------------|
| name | atom | Row identifier |
| height | string | Fixed height (e.g., "30pt") |
| fill | string | Background color |
| stroke | string | Border stroke |
| align | atom/tuple | Default alignment for elements |
| inset | string | Default padding |

### Header Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| name | atom | nil | Optional identifier |
| repeat | boolean | true | Repeat on each page |
| level | pos_integer | 1 | Cascading header level |

### Footer Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| name | atom | nil | Optional identifier |
| repeat | boolean | true | Repeat on each page |

## DSL Usage Examples

### Grid with GridCells

```elixir
grid :metrics_grid do
  columns 3

  grid_cell do
    x 0
    y 0
    align :left
    fill "#f0f0f0"

    label :cell1 do
      text("Revenue")
    end
  end

  grid_cell do
    x 1
    y 0
    align :right

    field :value do
      source :total_revenue
      format :currency
    end
  end
end
```

### Table with TableCells, Header, Footer

```elixir
table :data_table do
  columns 3

  header repeat: true do
    table_cell do
      label :name_header do
        text("Name")
      end
    end

    table_cell do
      label :value_header do
        text("Value")
      end
    end
  end

  table_cell do
    colspan 2
    align :left

    field :name do
      source :customer_name
    end
  end

  footer repeat: true do
    table_cell do
      colspan 2
      label :total_label do
        text("Total")
      end
    end

    table_cell do
      field :total do
        source :grand_total
        format :currency
      end
    end
  end
end
```

### Row with Elements

```elixir
grid :row_grid do
  columns 2

  row :header_row do
    height "30pt"
    fill "#f0f0f0"
    align :center

    label :col1 do
      text("Column 1")
    end

    label :col2 do
      text("Column 2")
    end
  end
end
```

## Deferred Items

1. **Nested layouts within cells** (1.2.2.7) - Requires either:
   - Lazy evaluation pattern for DSL entities
   - "Layout element" approach where nested containers are special elements

2. **Test nested layouts within cells** (1.2.T.5) - Blocked by above

## Next Steps

1. Proceed with Section 1.3 (Content Elements) - Label and Field entity updates
2. Consider implementing the "layout element" approach for nested containers
3. Run the test suite to verify all changes work correctly

## Typst Generation Notes

When generating Typst output:

- `grid_cell` → Direct content in `#grid()` or `grid.cell()` when explicit positioning needed
- `table_cell` → `table.cell(colspan: n, rowspan: m)[...]`
- `header` → `table.header(repeat: bool)[...]`
- `footer` → `table.footer(repeat: bool)[...]`
