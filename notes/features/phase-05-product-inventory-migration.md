# Phase 5.2: Product Inventory Report Migration

## Problem Statement

Migrate the existing `product_inventory` report from the legacy band-based DSL to the new layout primitives DSL (grid, table, stack, cell, row, label, field entities).

### Current State
- Report uses simple bands with labels and fields
- No explicit layout structure (relies on default rendering)
- Title band: Single label
- Detail band: 4 fields (name, sku, price, margin)
- Summary band: 2 labels with variable interpolation

### Target State
- Report uses new layout primitives for explicit layout control
- Title band: Grid with centered, styled title
- Detail band: Semantic table with header row and data fields
- Summary band: Grid with styled totals display

## Solution Overview

### Migration Approach
1. **Title Band**: Replace simple label with `grid` containing centered, styled label
2. **Detail Band**: Replace flat fields with `table` including:
   - Header section with column labels
   - Data row with fields for each column
3. **Summary Band**: Replace labels with `grid` containing styled summary metrics

### Key Design Decisions
- Use semantic `table` for detail data (accessibility, proper HTML output)
- Use `grid` for title and summary (flexible styling)
- Apply explicit styling for better visual presentation
- Add conditional fill for low stock highlighting (enhancement)

## Technical Details

### Files to Modify
- **ash_reports_demo**: `lib/ash_reports_demo/domain.ex` - Contains product_inventory report definition (main production migration)
- **ash_reports** (test data): `test/data/domain.ex` - Contains test report definitions (already migrated)

### Current Report Structure
```elixir
report :product_inventory do
  title("Product Inventory Report")
  driving_resource(AshReportsDemo.Product)

  # Parameters and variables unchanged

  band :title do
    type :title
    label :report_title do
      text("Product Inventory Report")
    end
  end

  band :product_detail do
    type :detail
    field :product_name do source :name end
    field :sku do source :sku end
    field :price do source :price end
    field :margin do source :margin_percentage end
  end

  band :inventory_summary do
    type :summary
    label :total_products_summary do
      text("Total Products: [total_products]")
    end
    label :inventory_value_summary do
      text("Total Inventory Value: [total_inventory_value]")
    end
  end
end
```

### Target Report Structure
```elixir
report :product_inventory do
  title("Product Inventory Report")
  driving_resource(AshReportsDemo.Product)

  # Parameters and variables unchanged

  band :title do
    type :title
    grid :title_grid do
      columns 1
      align :center
      inset "10pt"

      label :report_title do
        text("Product Inventory Report")
        style font_size: 18, font_weight: :bold
      end
    end
  end

  band :column_headers do
    type :column_header
    table :header_table do
      columns [fr(2), fr(1), fr(1), fr(1)]
      stroke "1pt"
      fill "#f0f0f0"
      inset "5pt"

      header do
        label :name_header do text("Product Name") end
        label :sku_header do text("SKU") end
        label :price_header do text("Price") end
        label :margin_header do text("Margin %") end
      end
    end
  end

  band :product_detail do
    type :detail
    table :detail_table do
      columns [fr(2), fr(1), fr(1), fr(1)]
      stroke "0.5pt"
      inset "5pt"

      field :product_name do source :name end
      field :sku do source :sku end
      field :price do source :price, format: :currency, decimal_places: 2 end
      field :margin do source :margin_percentage, format: :percent, decimal_places: 1 end
    end
  end

  band :inventory_summary do
    type :summary
    grid :summary_grid do
      columns [fr(1), fr(1)]
      gutter "20pt"
      align :center
      inset "10pt"
      fill "#e8e8e8"

      stack :products_stat do
        dir :ttb
        spacing "5pt"
        label :products_label do
          text("Total Products")
          style font_weight: :bold
        end
        label :products_value do
          text("[total_products]")
          style font_size: 16
        end
      end

      stack :value_stat do
        dir :ttb
        spacing "5pt"
        label :value_label do
          text("Inventory Value")
          style font_weight: :bold
        end
        label :value_amount do
          text("$[total_inventory_value]")
          style font_size: 16
        end
      end
    end
  end
end
```

## Implementation Plan

### Step 1: Migrate Title Band
- [x] Replace simple label with grid layout
- [x] Add centered alignment
- [x] Apply title styling (larger font, bold)

### Step 2: Migrate Detail Band to Table
- [x] Create table with appropriate column widths
- [x] Add column header band with table layout
- [x] Add detail band with table for data rows
- [x] Add fields with proper formatting (currency, percent)
- [x] Apply table styling (borders, padding)

### Step 3: Migrate Summary Band
- [x] Create 2x2 grid for metrics display
- [x] Add labels for metric names and values
- [x] Apply styling (background fill, spacing)

### Step 4: Write Tests
- [x] Test report compilation (15 tests passing)
- [x] Test HTML rendering produces expected output
- [ ] Test PDF rendering (requires Typst integration - deferred)
- [x] Test variable interpolation placeholder text

### Step 5: Update Plan
- [x] Mark tasks complete in phase-05.md
- [x] Document discoveries and issues

## Success Criteria

1. ✅ Report compiles without errors
2. ✅ HTML output shows proper table structure with headers
3. ✅ Title is centered and styled
4. ✅ Summary metrics display in grid layout
5. ✅ All existing functionality preserved (filtering, variables)

## Current Status

- **What Works**:
  - Full migration complete in ash_reports test data (15 tests passing)
  - Full migration complete in ash_reports_demo production domain
  - Removed invalid `column N` attributes from all reports
- **What's Next**: Conditional styling for low stock (future enhancement)
- **How to Run**:
  - ash_reports tests: `mix test test/ash_reports/migration/product_inventory_migration_test.exs`
  - ash_reports_demo: `cd ../ash_reports_demo && mix compile && mix phx.server`

## Discoveries During Implementation

1. **Grid DSL Limitation**: Grids don't support nested stacks directly in the DSL entities. Changed summary band to use a 2x2 grid with labels instead of nested stacks.

2. **Transformer Return Values**: Layout transformers return `{:ok, ir}` tuples, not raw IR structs.

3. **Column Conversion**: Integer column widths like `[2, 1, 1, 1]` are converted to string format `["2pt", "1pt", "1pt", "1pt"]` during transformation.

4. **Invalid `column N` Attribute**: The legacy `column 0`, `column 1`, etc. syntax on labels/fields is NOT valid in the current DSL. Elements are positioned by their order within the band/table, not by explicit column indices. This attribute needed to be removed from all reports (customer_summary, invoice_details, financial_summary) for compilation to succeed.

## Notes

- The existing report structure was simple - good candidate for first migration
- Conditional styling for low stock warning deferred as future enhancement
- Report date/timestamp display deferred as future enhancement
- Consider adding alternating row colors in detail band (future enhancement)
