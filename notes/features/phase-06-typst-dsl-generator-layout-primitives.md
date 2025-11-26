# Phase 6: Typst DSL Generator - Layout Primitives Support

## Problem Statement

The Typst DSL generator (`lib/ash_reports/typst/dsl_generator.ex`) currently only handles the legacy element-based band format. When bands contain the new layout primitives (`grid`, `table`, `stack`), the generator:

1. Doesn't detect them (only checks `band.elements`)
2. Falls through to `generate_default_band_content`
3. Outputs invalid Typst syntax like `= Title` (heading syntax) inside grids

### Error Example
```
[line 28:3] unexpected equals sign
  Source: = Title
         ^
```

This breaks the product_inventory report which was migrated to use layout primitives.

### Impact
- PDF generation fails for any report using layout primitives
- Reports must stay on legacy format until this is fixed

## Solution Overview

Update the DSL generator to:
1. Detect and render `band.grids`, `band.tables`, `band.stacks`
2. Remove all legacy element-based rendering (no backward compatibility needed)
3. Integrate with existing Typst renderers for layout primitives

### Key Design Decisions
- **No backward compatibility**: Remove all legacy code
- **Delegate to existing renderers**: Use `AshReports.Renderer.Typst.Grid`, `Table`, `Stack`
- **Transform DSL entities to IR**: Convert band primitives to IR format for rendering

## Technical Details

### Files Modified
- `lib/ash_reports/typst/dsl_generator.ex` - Main generator

### Files Referenced (existing renderers)
- `lib/ash_reports/renderer/typst/grid.ex` - Grid rendering
- `lib/ash_reports/renderer/typst/table.ex` - Table rendering
- `lib/ash_reports/renderer/typst/stack.ex` - Stack rendering
- `lib/ash_reports/layout/transformer/grid.ex` - Grid transformer (DSL -> IR)
- `lib/ash_reports/layout/transformer/table.ex` - Table transformer (DSL -> IR)
- `lib/ash_reports/layout/transformer/stack.ex` - Stack transformer (DSL -> IR)

### Old Flow (Broken)
```
Band -> generate_band_content -> checks band.elements (empty) -> generate_default_band_content -> "= Title"
```

### New Flow (Implemented)
```
Band -> generate_band_content -> checks band.grids/tables/stacks -> transform to IR -> render with Typst renderers
```

## Implementation Plan

### Step 1: Analyze Current Structure
- [x] Map out all legacy element handling code
- [x] Identify which functions need updating vs removing
- [x] Document the Band struct fields for layout primitives

### Step 2: Update generate_band_content
- [x] Add detection for `band.grids`, `band.tables`, `band.stacks`
- [x] Remove `band.elements` handling for band-level content
- [x] Call appropriate renderer for each layout primitive type

### Step 3: Create Layout Primitive Rendering Functions
- [x] `generate_grid_content/2` - Transform grid DSL entity to IR, render
- [x] `generate_table_content/2` - Transform table DSL entity to IR, render
- [x] `generate_stack_content/2` - Transform stack DSL entity to IR, render

### Step 4: Remove Legacy Code
- [x] Remove `generate_table_based_band/2` (legacy element layout)
- [x] Remove `generate_table_cells/3`
- [x] Remove `generate_table_cell_content/2`
- [x] Remove `generate_default_band_content/2` (fallback to `= Title`)
- [x] Remove `humanize_name/1` (unused after removing default band content)
- [x] Remove ~320 lines of legacy code

### Step 5: Update Data Processing
- [x] Field interpolation works via existing transformer/renderer pipeline
- [x] Variable placeholder handling preserved in existing renderer

### Step 6: Update Tests
- [x] Updated tests to use new layout primitives format
- [x] Tagged legacy element-based tests with `@tag :skip` for future migration
- [x] 43 tests pass, 11 legacy tests skipped

### Step 7: Fix Typst Mode Issues
- [x] Fixed `#` prefix issue (markup mode inside code mode)
- [x] Fixed comma requirement issue (content blocks in function args)
- [x] Solution: Wrap rendered content in content block `[...]`

### Step 8: Test with ash_reports_demo
- [ ] ash_reports_demo has separate compilation issues (unrelated to Phase 6)
- [ ] Manual PDF generation testing pending

## Success Criteria

1. ✅ Product_inventory report definition uses layout primitives (completed in Phase 5)
2. ✅ DSL generator detects and renders layout primitives
3. ✅ Legacy element-based band code removed (~320 lines)
4. ✅ Tests pass for new rendering path (43 pass, 11 legacy skipped)
5. ✅ Typst mode handling fixed (content block wrapping)
6. ⏳ PDF generation verification pending (ash_reports_demo has separate issues)

## Current Status

- **What Works**:
  - DSL generator updated to handle layout primitives
  - Legacy code removed
  - Tests updated and passing (43 pass, 11 skipped)
  - Code compiles without warnings
  - Typst mode handling fixed with content block wrapping
- **What's Pending**:
  - ash_reports_demo has unrelated compilation error (`undefined function column/1`)
  - Manual PDF generation testing pending once demo is fixed
- **How to Run**: `mix test test/ash_reports/typst/dsl_generator_test.exs`

## Code Changes Summary

### New Functions Added (dsl_generator.ex)

The layout primitive rendering functions wrap content in `[...]` to preserve markup mode syntax:

```elixir
defp generate_grid_content(grid, context) do
  alias AshReports.Layout.Transformer.Grid, as: GridTransformer
  alias AshReports.Renderer.Typst.Grid, as: GridRenderer

  case GridTransformer.transform(grid) do
    {:ok, ir} ->
      data = Map.get(context, :data, %{})
      # Wrap in content block to preserve markup mode syntax inside code block
      rendered = GridRenderer.render(ir, data: data)
      "[#{rendered}]"

    {:error, reason} ->
      Logger.warning("Failed to transform grid #{grid.name}: #{inspect(reason)}")
      "// Grid transformation failed: #{grid.name}"
  end
end

# Similar pattern for generate_table_content/2 and generate_stack_content/2
```

### Typst Mode Handling

**Problem**: The DSL generator outputs code inside `#let report_name(data, config) = { ... }` which is Typst **code mode**. The renderers output `#grid(...)` which is **markup mode** syntax.

**Solution Attempts**:
1. ~~Strip `#` prefixes with `markup_to_code_mode/1`~~ - Failed: content blocks like `[Product Name]` need commas between them in code mode
2. **Wrap in content block `[...]`** - Success: `[#grid(...)]` keeps the content in markup mode where commas aren't required

**Why it works**: Inside a code block `{ }`, a content block `[...]` switches back to markup mode. The `#grid(...)` inside the content block is valid markup mode syntax.

### Updated Function (dsl_generator.ex)
```elixir
defp generate_band_content(%Band{} = band, context) do
  grids = band.grids || []
  tables = band.tables || []
  stacks = band.stacks || []

  cond do
    length(grids) > 0 ->
      grids |> Enum.map(&generate_grid_content(&1, context)) |> Enum.join("\n")
    length(tables) > 0 ->
      tables |> Enum.map(&generate_table_content(&1, context)) |> Enum.join("\n")
    length(stacks) > 0 ->
      stacks |> Enum.map(&generate_stack_content(&1, context)) |> Enum.join("\n")
    true ->
      "// Empty band: #{band.name}"
  end
end
```

### Removed Functions (~320 lines)
- `generate_table_based_band/2`
- `build_table_inset/1`
- `extract_band_spacing_after/1`
- `generate_column_spec/1`
- `generate_table_cells/3`
- `generate_table_cell_content/2`
- `apply_table_cell_style/3`
- `apply_style_only/2`
- `apply_padding_only/2`
- `apply_margin_only/2`
- `apply_alignment_only/2`
- `apply_numeric_formatting/2`
- `strip_hash/1`
- `generate_default_band_content/2`
- `humanize_name/1`

## Notes

- The existing `AshReports.Renderer.Typst.*` modules handle IR -> Typst conversion
- The `AshReports.Layout.Transformer.*` modules handle DSL entity -> IR conversion
- The DSL generator now connects these two pipelines for layout primitives
- Legacy tests tagged with `@tag :legacy_format` for future migration reference
