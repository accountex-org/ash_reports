# Phase 3: Typst Renderer

## Overview

This phase implements the Typst renderer that generates `.typ` markup from the Intermediate Representation. The renderer produces Typst code for grids, tables, and stacks that compiles to high-quality PDF output with proper layout, styling, and data interpolation.

**Duration Estimate**: 2-2.5 weeks

**Dependencies**: Phase 1 (Core DSL Entities), Phase 2 (Intermediate Representation)

**Parallelization**: This phase can run concurrently with Phase 4 (HTML Renderer) once Phase 2 is complete. If multiple developers are available, this reduces total elapsed time by 1.5-2 weeks.

## 3.1 Core Typst Generation

### 3.1.1 Grid Markup Generation
- [ ] **Task 3.1.1 Complete**

Generate Typst grid() function calls from GridIR.

- [ ] 3.1.1.1 Create `AshReports.Renderer.Typst.Grid` module (success: module compiles)
- [ ] 3.1.1.2 Generate columns parameter with track sizes (success: `columns: (100pt, 1fr, auto)` output)
- [ ] 3.1.1.3 Generate rows parameter when not auto (success: explicit rows render)
- [ ] 3.1.1.4 Generate gutter parameter (success: `gutter: 10pt` output)
- [ ] 3.1.1.5 Generate column-gutter and row-gutter overrides (success: specific gutters render)
- [ ] 3.1.1.6 Generate align parameter (success: `align: center` output)
- [ ] 3.1.1.7 Generate inset parameter (success: `inset: 5pt` output)
- [ ] 3.1.1.8 Generate fill parameter with static or function value (success: fill renders)
- [ ] 3.1.1.9 Generate stroke parameter (success: `stroke: none` output)

### 3.1.2 Table Markup Generation
- [ ] **Task 3.1.2 Complete**

Generate Typst table() function calls from TableIR.

- [ ] 3.1.2.1 Create `AshReports.Renderer.Typst.Table` module (success: module compiles)
- [ ] 3.1.2.2 Extend grid generation for table-specific defaults (success: table uses grid code)
- [ ] 3.1.2.3 Generate table.header() for header sections (success: header renders)
- [ ] 3.1.2.4 Generate repeat parameter for headers (success: `repeat: true` output)
- [ ] 3.1.2.5 Generate table.footer() for footer sections (success: footer renders)
- [ ] 3.1.2.6 Apply default stroke "1pt" for tables (success: tables have borders)

### 3.1.3 Stack Markup Generation
- [ ] **Task 3.1.3 Complete**

Generate Typst stack() function calls from StackIR.

- [ ] 3.1.3.1 Create `AshReports.Renderer.Typst.Stack` module (success: module compiles)
- [ ] 3.1.3.2 Generate dir parameter with Typst direction values (success: `dir: ttb` output)
- [ ] 3.1.3.3 Generate spacing parameter (success: `spacing: 10pt` output)
- [ ] 3.1.3.4 Recursively render child layouts (success: nested layouts render)
- [ ] 3.1.3.5 Render direct content children (labels, fields) (success: content renders)

### Unit Tests - Section 3.1
- [ ] 3.1.T.1 Test grid markup generation with all parameters
- [ ] 3.1.T.2 Test table markup with header/footer
- [ ] 3.1.T.3 Test stack markup with nested layouts
- [ ] 3.1.T.4 Test generated Typst compiles without errors

## 3.2 Cell and Content Rendering

### 3.2.1 Cell Markup Generation
- [ ] **Task 3.2.1 Complete**

Generate grid.cell() and table.cell() calls from CellIR.

- [ ] 3.2.1.1 Create `AshReports.Renderer.Typst.Cell` module (success: module compiles)
- [ ] 3.2.1.2 Generate colspan parameter when > 1 (success: `colspan: 2` output)
- [ ] 3.2.1.3 Generate rowspan parameter when > 1 (success: `rowspan: 3` output)
- [ ] 3.2.1.4 Generate align override (success: cell-specific align renders)
- [ ] 3.2.1.5 Generate fill override (success: cell-specific fill renders)
- [ ] 3.2.1.6 Generate inset override (success: cell-specific inset renders)
- [ ] 3.2.1.7 Generate breakable parameter when false (success: `breakable: false` output)
- [ ] 3.2.1.8 Use simple bracket syntax when no overrides (success: `[content]` for simple cells)

### 3.2.2 Content Rendering
- [ ] **Task 3.2.2 Complete**

Render label and field content within cells.

- [ ] 3.2.2.1 Create `AshReports.Renderer.Typst.Content` module (success: module compiles)
- [ ] 3.2.2.2 Render label text as Typst text (success: text renders)
- [ ] 3.2.2.3 Render field value with data interpolation (success: field value renders)
- [ ] 3.2.2.4 Apply content styling (font_size, font_weight, color) (success: styles apply)
- [ ] 3.2.2.5 Escape special Typst characters in text (success: special chars safe)

### 3.2.3 Nested Layout Rendering
- [ ] **Task 3.2.3 Complete**

Render nested layouts within cells.

- [ ] 3.2.3.1 Detect nested LayoutIR in cell content (success: nested layouts detected)
- [ ] 3.2.3.2 Recursively render nested grid/table/stack (success: nested layouts render)
- [ ] 3.2.3.3 Properly nest Typst function calls (success: nesting syntax correct)

### Unit Tests - Section 3.2
- [ ] 3.2.T.1 Test cell markup with spanning
- [ ] 3.2.T.2 Test cell markup with overrides
- [ ] 3.2.T.3 Test simple cell bracket syntax
- [ ] 3.2.T.4 Test label content rendering
- [ ] 3.2.T.5 Test field content with styling
- [ ] 3.2.T.6 Test nested layout rendering

## 3.3 Property Rendering

### 3.3.1 Track Size Rendering
- [ ] **Task 3.3.1 Complete**

Render track sizes to Typst column/row syntax.

- [ ] 3.3.1.1 Render :auto as `auto` (success: auto renders)
- [ ] 3.3.1.2 Render {:fr, n} as `nfr` (success: `1fr`, `2fr` render)
- [ ] 3.3.1.3 Render length strings directly (success: `100pt`, `2cm` render)
- [ ] 3.3.1.4 Render arrays as Typst arrays (success: `(100pt, 1fr, auto)` output)
- [ ] 3.3.1.5 Render integer as repeated auto (success: `3` becomes `(auto, auto, auto)`)

### 3.3.2 Alignment Rendering
- [ ] **Task 3.3.2 Complete**

Render alignment values to Typst alignment syntax.

- [ ] 3.3.2.1 Render :left as `left` (success: horizontal align renders)
- [ ] 3.3.2.2 Render :center as `center` (success: center renders)
- [ ] 3.3.2.3 Render :right as `right` (success: right renders)
- [ ] 3.3.2.4 Render :top as `top` (success: vertical align renders)
- [ ] 3.3.2.5 Render combined alignment {:left, :top} as `left + top` (success: combined renders)

### 3.3.3 Color and Fill Rendering
- [ ] **Task 3.3.3 Complete**

Render colors and fill values to Typst syntax.

- [ ] 3.3.3.1 Render hex colors as Typst rgb() (success: `#ffffff` becomes `rgb("#ffffff")`)
- [ ] 3.3.3.2 Render :none as `none` (success: no fill renders)
- [ ] 3.3.3.3 Render function fills as Typst functions (success: conditional fills render)
- [ ] 3.3.3.4 Generate position-based fill function syntax (success: `(x, y) => ...` output)

### 3.3.4 Stroke Rendering
- [ ] **Task 3.3.4 Complete**

Render stroke values to Typst stroke syntax.

- [ ] 3.3.4.1 Render :none as `none` (success: no stroke renders)
- [ ] 3.3.4.2 Render simple width as length (success: `1pt` renders)
- [ ] 3.3.4.3 Render width + color as stroke spec (success: `1pt + black` renders)
- [ ] 3.3.4.4 Render full stroke spec with dash (success: dashed strokes render)

### Unit Tests - Section 3.3
- [ ] 3.3.T.1 Test all track size formats
- [ ] 3.3.T.2 Test all alignment combinations
- [ ] 3.3.T.3 Test color rendering
- [ ] 3.3.T.4 Test fill function rendering
- [ ] 3.3.T.5 Test stroke rendering

## 3.4 Line Rendering

### 3.4.1 Horizontal Lines
- [ ] **Task 3.4.1 Complete**

Render hline entities to grid.hline()/table.hline().

- [ ] 3.4.1.1 Create `AshReports.Renderer.Typst.Lines` module (success: module compiles)
- [ ] 3.4.1.2 Generate grid.hline()/table.hline() call (success: hline renders)
- [ ] 3.4.1.3 Generate y parameter for row position (success: `y: 1` output)
- [ ] 3.4.1.4 Generate start and end parameters for partial lines (success: partial lines render)
- [ ] 3.4.1.5 Generate stroke parameter (success: line styling renders)
- [ ] 3.4.1.6 Generate position parameter (success: `:top`/`:bottom` renders)

### 3.4.2 Vertical Lines
- [ ] **Task 3.4.2 Complete**

Render vline entities to grid.vline()/table.vline().

- [ ] 3.4.2.1 Generate grid.vline()/table.vline() call (success: vline renders)
- [ ] 3.4.2.2 Generate x parameter for column position (success: `x: 2` output)
- [ ] 3.4.2.3 Generate start and end parameters for partial lines (success: partial lines render)
- [ ] 3.4.2.4 Generate stroke and position parameters (success: styling renders)

### Unit Tests - Section 3.4
- [ ] 3.4.T.1 Test hline generation
- [ ] 3.4.T.2 Test vline generation
- [ ] 3.4.T.3 Test partial line specifications
- [ ] 3.4.T.4 Test lines compile in Typst

## 3.5 Data Interpolation

### 3.5.1 Variable Interpolation
- [ ] **Task 3.5.1 Complete**

Interpolate report variables into rendered content.

- [ ] 3.5.1.1 Create `AshReports.Renderer.Typst.Interpolation` module (success: module compiles)
- [ ] 3.5.1.2 Detect [variable_name] patterns in text (success: patterns detected)
- [ ] 3.5.1.3 Replace with variable value from data context (success: values interpolated)
- [ ] 3.5.1.4 Handle missing variables gracefully (success: missing stays as placeholder)
- [ ] 3.5.1.5 Format interpolated values appropriately (success: numbers formatted)

### 3.5.2 Field Value Formatting
- [ ] **Task 3.5.2 Complete**

Format field values based on format property.

- [ ] 3.5.2.1 Format :currency with symbol and decimals (success: `$1,234.56` output)
- [ ] 3.5.2.2 Format :number with decimal places (success: `1,234.56` output)
- [ ] 3.5.2.3 Format :date in locale format (success: date formatted)
- [ ] 3.5.2.4 Format :datetime in locale format (success: datetime formatted)
- [ ] 3.5.2.5 Format :percent with symbol (success: `12.5%` output)
- [ ] 3.5.2.6 Apply decimal_places property (success: rounding works)

### Unit Tests - Section 3.5
- [ ] 3.5.T.1 Test variable interpolation
- [ ] 3.5.T.2 Test missing variable handling
- [ ] 3.5.T.3 Test all format types
- [ ] 3.5.T.4 Test decimal places

## 3.6 Text Styling

### 3.6.1 Font Styling
- [ ] **Task 3.6.1 Complete**

Apply font styling to rendered text.

- [ ] 3.6.1.1 Create `AshReports.Renderer.Typst.Styling` module (success: module compiles)
- [ ] 3.6.1.2 Wrap text with #text() for styling (success: styled text renders)
- [ ] 3.6.1.3 Apply font_size with size parameter (success: `size: 24pt` output)
- [ ] 3.6.1.4 Apply font_weight with weight parameter (success: `weight: "bold"` output)
- [ ] 3.6.1.5 Apply color with fill parameter (success: `fill: rgb("#000")` output)
- [ ] 3.6.1.6 Apply font_family with font parameter (success: `font: "Arial"` output)
- [ ] 3.6.1.7 Combine multiple styles efficiently (success: single #text() call)

### Unit Tests - Section 3.6
- [ ] 3.6.T.1 Test individual style properties
- [ ] 3.6.T.2 Test combined styles
- [ ] 3.6.T.3 Test styled text compiles

## 3.7 Renderer Integration

### 3.7.1 Main Renderer Module
- [ ] **Task 3.7.1 Complete**

Create main Typst renderer entry point.

- [ ] 3.7.1.1 Create `AshReports.Renderer.Typst` main module (success: module compiles)
- [ ] 3.7.1.2 Implement render/2 accepting IR and data (success: render entry point works)
- [ ] 3.7.1.3 Dispatch to appropriate layout renderer (success: grid/table/stack dispatch)
- [ ] 3.7.1.4 Combine all generated markup into document (success: complete .typ output)
- [ ] 3.7.1.5 Handle multiple bands/layouts in sequence (success: full report renders)

### 3.7.2 Report Pipeline Integration
- [ ] **Task 3.7.2 Complete**

Integrate Typst renderer with report pipeline.

- [ ] 3.7.2.1 Register Typst renderer for :pdf format (success: pdf format uses Typst)
- [ ] 3.7.2.2 Accept report IR from transformer pipeline (success: IR flows to renderer)
- [ ] 3.7.2.3 Pass data context for interpolation (success: data available during render)
- [ ] 3.7.2.4 Return complete Typst markup (success: .typ content returned)
- [ ] 3.7.2.5 Integrate with Typst compilation (success: PDF generated from .typ)

### Unit Tests - Section 3.7
- [ ] 3.7.T.1 Test main renderer with complete IR
- [ ] 3.7.T.2 Test multi-band reports
- [ ] 3.7.T.3 Test pipeline integration
- [ ] 3.7.T.4 Test PDF generation end-to-end

## 3.8 Internationalization

### 3.8.1 Locale-Aware Formatting
- [ ] **Task 3.8.1 Complete**

Support locale-specific formatting for values.

- [ ] 3.8.1.1 Create `AshReports.Renderer.I18n` module (success: module compiles)
- [ ] 3.8.1.2 Support configurable locale per report (success: `locale: "de-DE"` option)
- [ ] 3.8.1.3 Format currency with locale symbol and separators (success: €1.234,56 for German)
- [ ] 3.8.1.4 Format numbers with locale decimal/thousand separators (success: 1.234,56 for German)
- [ ] 3.8.1.5 Format dates with locale date format (success: 20.11.2025 for German)
- [ ] 3.8.1.6 Format times with locale time format (success: 14:30 vs 2:30 PM)
- [ ] 3.8.1.7 Default to system/application locale (success: sensible default)

### 3.8.2 Currency Symbol Handling
- [ ] **Task 3.8.2 Complete**

Handle currency symbols for different locales.

- [ ] 3.8.2.1 Support currency code property on field (success: `currency: :EUR`)
- [ ] 3.8.2.2 Place symbol correctly for locale (success: €100 vs 100€)
- [ ] 3.8.2.3 Use correct decimal places for currency (success: JPY has no decimals)

### Unit Tests - Section 3.8
- [ ] 3.8.T.1 Test formatting with different locales
- [ ] 3.8.T.2 Test currency symbol placement
- [ ] 3.8.T.3 Test date/time formatting

## Success Criteria

1. **Grid Rendering**: Generate valid Typst grid() markup with all properties
2. **Table Rendering**: Generate valid Typst table() markup with header/footer sections
3. **Stack Rendering**: Generate valid Typst stack() markup with nested layouts
4. **Cell Rendering**: Generate cell markup with spanning, positioning, and overrides
5. **Content Rendering**: Render labels and fields with proper styling
6. **Property Rendering**: Correctly render all property types (tracks, alignment, colors, strokes)
7. **Line Rendering**: Generate hline/vline markup for custom lines
8. **Data Interpolation**: Interpolate variables and format field values
9. **Text Styling**: Apply font styling using Typst #text() function
10. **Integration**: Complete pipeline from IR to compiled PDF

## Provides Foundation

This phase establishes the infrastructure for:

- **Phase 5**: Demo App Migration requiring PDF output for migrated reports
- **Phase 6**: Advanced Features building on renderer capabilities

## Key Outputs

- Complete Typst renderer generating valid .typ markup from IR
- Track size, alignment, color, and stroke rendering
- Cell and content rendering with styling
- Line rendering for custom grid/table lines
- Variable interpolation and value formatting
- Text styling with fonts and colors
- Integration with report pipeline
- End-to-end PDF generation tests
