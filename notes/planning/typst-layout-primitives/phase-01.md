# Phase 1: Core DSL Entities

## Overview

This phase establishes the foundational Spark DSL entities for Typst layout primitives. The goal is to create a complete, type-safe DSL that allows report authors to define grid, table, stack, and row layouts within bands.

**Duration Estimate**: 2-3 weeks

**Dependencies**: Existing AshReports DSL infrastructure, Spark.Dsl framework

## Risk Mitigation: Vertical Slice First

**IMPORTANT**: Before completing all entities, build a minimal end-to-end vertical slice to validate the architecture:

1. Implement grid entity with columns, cells, and basic properties (Section 1.1.1)
2. Implement cell entity with content (Section 1.2.2)
3. Implement label entity (Section 1.3.1)
4. Create minimal IR transformation (Phase 2 preview)
5. Generate basic Typst grid output (Phase 3 preview)
6. Verify PDF compilation works

This validates the full pipeline before investing in all entity variations. If issues are discovered, they can be addressed with minimal rework.

**Checkpoint**: After completing the vertical slice, review the architecture before proceeding with remaining entities.

## 1.1 Layout Container Entities

### 1.1.1 Grid Entity Definition
- [x] **Task 1.1.1 Complete** (2024-11-20)

Define the grid entity for 2D presentational layouts without semantic meaning.

- [x] 1.1.1.1 Create `AshReports.Dsl.Layout.Grid` module with Spark entity definition (success: module compiles without errors)
- [x] 1.1.1.2 Define grid schema with columns property accepting track sizes (success: `columns [fr(1), "100pt", auto()]` parses correctly)
- [x] 1.1.1.3 Define rows property with auto/array/integer support (success: `rows auto()` and `rows 3` both parse)
- [x] 1.1.1.4 Add gutter, column_gutter, row_gutter properties for spacing (success: `gutter "10pt"` applies to all gaps)
- [x] 1.1.1.5 Add align property with horizontal/vertical alignment support (success: `align :center` and `align {:left, :top}` both work)
- [x] 1.1.1.6 Add inset property for cell padding (success: `inset "5pt"` sets default padding)
- [x] 1.1.1.7 Add fill property with color/function support (success: conditional fill function compiles)
- [x] 1.1.1.8 Add stroke property with none as default (success: grids have no borders by default)

### 1.1.2 Table Entity Definition
- [x] **Task 1.1.2 Complete** (2024-11-20)

Define the table entity for semantic data presentation with accessibility support.

- [x] 1.1.2.1 Create `AshReports.Dsl.Layout.Table` module extending grid properties (success: module compiles)
- [x] 1.1.2.2 Override stroke default to "1pt" for table borders (success: tables have visible borders by default)
- [x] 1.1.2.3 Override inset default to "5pt" for cell padding (success: tables have default padding)
- [ ] 1.1.2.4 Add header entity support with repeat and level properties (deferred to section 1.2.3)
- [ ] 1.1.2.5 Add footer entity support with repeat property (deferred to section 1.2.3)
- [x] 1.1.2.6 Ensure table semantics are preserved for accessibility (success: table generates proper semantic markup)

### 1.1.3 Stack Entity Definition
- [x] **Task 1.1.3 Complete** (2024-11-20)

Define the stack entity for 1D sequential arrangement.

- [x] 1.1.3.1 Create `AshReports.Dsl.Layout.Stack` module (success: module compiles)
- [x] 1.1.3.2 Define dir property with :ttb, :btt, :ltr, :rtl options (success: all direction values parse)
- [x] 1.1.3.3 Define spacing property for item separation (success: `spacing "10pt"` applies between children)
- [x] 1.1.3.4 Allow nested layout containers as children (success: stack can contain grids and tables)

### Unit Tests - Section 1.1
- [x] 1.1.T.1 Test grid entity parsing with all property combinations
- [x] 1.1.T.2 Test table entity parsing with header/footer sections
- [x] 1.1.T.3 Test stack entity parsing with nested layouts
- [ ] 1.1.T.4 Test error messages for invalid property values

## 1.2 Row and Cell Entities

### 1.2.1 Row Entity Definition
- [ ] **Task 1.2.1 Complete**

Define explicit row containers within grid/table.

- [ ] 1.2.1.1 Create `AshReports.Dsl.Layout.Row` module (success: module compiles)
- [ ] 1.2.1.2 Define height property for fixed row heights (success: `height "30pt"` sets row height)
- [ ] 1.2.1.3 Define fill property for row background (success: `fill "#f0f0f0"` colors entire row)
- [ ] 1.2.1.4 Define stroke property for row borders (success: `stroke "1pt"` adds row border)
- [ ] 1.2.1.5 Define align property for default cell alignment (success: row align propagates to cells)
- [ ] 1.2.1.6 Define inset property for default cell padding (success: row inset propagates to cells)

### 1.2.2 Cell Entity Definition
- [ ] **Task 1.2.2 Complete**

Define individual cells with spanning and positioning.

- [ ] 1.2.2.1 Create `AshReports.Dsl.Layout.Cell` module (success: module compiles)
- [ ] 1.2.2.2 Define colspan and rowspan properties (success: `colspan 2, rowspan 3` spans correctly)
- [ ] 1.2.2.3 Define x and y properties for explicit positioning (success: `x: 0, y: 1` places cell)
- [ ] 1.2.2.4 Define cell-specific align, fill, stroke, inset overrides (success: cell properties override parent)
- [ ] 1.2.2.5 Define breakable property for page break control (success: `breakable false` prevents breaks)
- [ ] 1.2.2.6 Allow nested layouts within cells (success: cell can contain stack/grid/table)

### 1.2.3 Header and Footer Entities
- [ ] **Task 1.2.3 Complete**

Define table-specific header and footer sections.

- [ ] 1.2.3.1 Create `AshReports.Dsl.Layout.Header` module (success: module compiles)
- [ ] 1.2.3.2 Define repeat property for page repetition (success: `repeat: true` repeats on each page)
- [ ] 1.2.3.3 Define level property for cascading headers (success: multiple header levels work)
- [ ] 1.2.3.4 Create `AshReports.Dsl.Layout.Footer` module with repeat property (success: footer repeats)

### Unit Tests - Section 1.2
- [ ] 1.2.T.1 Test row entity with all property combinations
- [ ] 1.2.T.2 Test cell spanning behavior
- [ ] 1.2.T.3 Test explicit cell positioning
- [ ] 1.2.T.4 Test header/footer repeat behavior
- [ ] 1.2.T.5 Test nested layouts within cells

## 1.3 Content Elements

### 1.3.1 Label Entity Updates
- [ ] **Task 1.3.1 Complete**

Update label entity for new cell-based placement.

- [ ] 1.3.1.1 Remove legacy column property from label schema (success: `column: 0` raises error)
- [ ] 1.3.1.2 Add text property as primary content (success: `text "Report Title"` works)
- [ ] 1.3.1.3 Add style block with font_size, font_weight, color, font_family (success: style properties apply)
- [ ] 1.3.1.4 Support short form syntax (success: `label text: "Name", style: [font_size: 12]`)
- [ ] 1.3.1.5 Maintain variable interpolation with [variable_name] syntax (success: `[total]` interpolates)

### 1.3.2 Field Entity Updates
- [ ] **Task 1.3.2 Complete**

Update field entity for new cell-based placement.

- [ ] 1.3.2.1 Remove legacy column property from field schema (success: `column: 0` raises error)
- [ ] 1.3.2.2 Rename attribute to source for clarity (success: `source :name` works)
- [ ] 1.3.2.3 Define format property with :currency, :number, :date, :datetime, :percent (success: all formats work)
- [ ] 1.3.2.4 Define decimal_places property for numeric formatting (success: `decimal_places 2` rounds)
- [ ] 1.3.2.5 Add optional style block (success: field can have custom styling)
- [ ] 1.3.2.6 Support short form syntax (success: `field source: :amount, format: :currency`)

### Unit Tests - Section 1.3
- [ ] 1.3.T.1 Test label entity with all property combinations
- [ ] 1.3.T.2 Test field entity with all format types
- [ ] 1.3.T.3 Test short form syntax for both entities
- [ ] 1.3.T.4 Test variable interpolation in labels
- [ ] 1.3.T.5 Test error handling for removed legacy properties

## 1.4 Line Control Entities

### 1.4.1 Horizontal and Vertical Lines
- [ ] **Task 1.4.1 Complete**

Define line entities for custom grid/table lines.

- [ ] 1.4.1.1 Create `AshReports.Dsl.Layout.HLine` module (success: module compiles)
- [ ] 1.4.1.2 Define y property for row position (success: `y: 1` places line after row 1)
- [ ] 1.4.1.3 Define start and end_col properties for partial lines (success: line spans subset of columns)
- [ ] 1.4.1.4 Define stroke property for line styling (success: `stroke "2pt"` creates thick line)
- [ ] 1.4.1.5 Define position property for :top/:bottom placement (success: `position: :bottom` works)
- [ ] 1.4.1.6 Create `AshReports.Dsl.Layout.VLine` module with analogous properties (success: vline works)

### Unit Tests - Section 1.4
- [ ] 1.4.T.1 Test hline and vline entity parsing
- [ ] 1.4.T.2 Test partial line specifications
- [ ] 1.4.T.3 Test line positioning within grid/table

## 1.5 Track Size Helper Functions

### 1.5.1 Track Size Types
- [ ] **Task 1.5.1 Complete**

Implement helper functions and types for track sizing.

- [ ] 1.5.1.1 Create `AshReports.Layout.Track` module with helper functions (success: module compiles)
- [ ] 1.5.1.2 Implement `auto()` function returning :auto (success: `auto()` in columns works)
- [ ] 1.5.1.3 Implement `fr(n)` function returning {:fr, n} (success: `fr(1)` in columns works)
- [ ] 1.5.1.4 Support string lengths: "100pt", "2cm", "20%" (success: all length strings parse)
- [ ] 1.5.1.5 Support integer shorthand for auto columns (success: `columns 3` creates 3 auto columns)
- [ ] 1.5.1.6 Add type specs and documentation (success: dialyzer passes)

### Unit Tests - Section 1.5
- [ ] 1.5.T.1 Test all track size helper functions
- [ ] 1.5.T.2 Test length string parsing
- [ ] 1.5.T.3 Test integer shorthand conversion

## 1.6 DSL Integration

### 1.6.1 Band Layout Integration
- [ ] **Task 1.6.1 Complete**

Integrate layout entities into band definitions.

- [ ] 1.6.1.1 Update band entity to accept grid/table/stack as children (success: band contains layout)
- [ ] 1.6.1.2 Remove legacy columns string property from band (success: `columns "(100pt)"` raises error)
- [ ] 1.6.1.3 Ensure only one layout container per band (success: multiple layouts raises error)
- [ ] 1.6.1.4 Update band verifier to require layout container (success: empty band raises error)

### 1.6.2 Entity Registration
- [ ] **Task 1.6.2 Complete**

Register all new entities with Spark DSL.

- [ ] 1.6.2.1 Add all entities to AshReports.Domain extension (success: domain compiles with new entities)
- [ ] 1.6.2.2 Define proper entity nesting hierarchy (success: cells only in rows/grids/tables)
- [ ] 1.6.2.3 Add import for Track helper functions (success: auto() and fr() available in DSL)
- [ ] 1.6.2.4 Ensure compile-time validation of entity structure (success: invalid nesting raises compile error)

### Unit Tests - Section 1.6
- [ ] 1.6.T.1 Test band with grid layout
- [ ] 1.6.T.2 Test band with table layout
- [ ] 1.6.T.3 Test band with stack layout
- [ ] 1.6.T.4 Test error handling for legacy column syntax
- [ ] 1.6.T.5 Test entity nesting validation

## Success Criteria

1. **Grid Entity**: Successfully parse grid definitions with all properties including columns, rows, gutter, align, inset, fill, stroke
2. **Table Entity**: Successfully parse table definitions with header/footer sections and proper semantic defaults
3. **Stack Entity**: Successfully parse stack definitions with direction and spacing, containing nested layouts
4. **Row/Cell Entities**: Successfully parse row and cell definitions with spanning, positioning, and property overrides
5. **Content Elements**: Successfully parse updated label and field entities without legacy column property
6. **Line Control**: Successfully parse hline and vline entities for custom grid/table lines
7. **Integration**: Successfully compile reports using new layout DSL within bands

## Provides Foundation

This phase establishes the infrastructure for:

- **Phase 2**: Intermediate Representation requiring parsed DSL entities to transform
- **Phase 3**: Typst Renderer requiring entity structures to generate Typst markup
- **Phase 4**: HTML Renderer requiring entity structures to generate CSS Grid/Flexbox
- **Phase 5**: Demo App Migration requiring complete DSL to rewrite reports

## Key Outputs

- Complete set of Spark DSL entity definitions for layout primitives
- Track size helper functions (`auto()`, `fr()`)
- Updated label and field entities without legacy column support
- Integration with band definitions
- Comprehensive unit tests for all entities
- Type specifications and documentation
