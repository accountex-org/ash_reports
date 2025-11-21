# Phase 2: Intermediate Representation

## Overview

This phase creates the Intermediate Representation (IR) layer that transforms parsed DSL entities into a normalized format suitable for all renderers. The IR handles cell positioning calculations, spanning logic, and provides a consistent data structure for Typst, HTML, and JSON output.

**Duration Estimate**: 1.5-2 weeks

**Dependencies**: Phase 1 (Core DSL Entities)

## 2.1 IR Data Structures

### 2.1.1 Layout IR Types
- [x] **Task 2.1.1 Complete**

Define core IR type structures for layout containers.

- [x] 2.1.1.1 Create `AshReports.Layout.IR` module with type definitions (success: module compiles)
- [x] 2.1.1.2 Define LayoutIR struct with type, properties, children, lines fields (success: struct creation works)
- [x] 2.1.1.3 Define type field as :grid | :table | :stack enum (success: all types representable)
- [x] 2.1.1.4 Define properties map with normalized property values (success: properties accessible)
- [x] 2.1.1.5 Define children as list of CellIR | RowIR | ContentIR (success: heterogeneous children)
- [x] 2.1.1.6 Define lines as list of LineIR for hline/vline (success: lines stored separately)

### 2.1.2 Cell and Row IR Types
- [x] **Task 2.1.2 Complete**

Define IR types for cells and rows.

- [x] 2.1.2.1 Define CellIR struct with position, span, properties, content (success: struct creation works)
- [x] 2.1.2.2 Define position as {x, y} tuple (0-indexed) (success: position tuple works)
- [x] 2.1.2.3 Define span as {colspan, rowspan} tuple (success: span tuple works)
- [x] 2.1.2.4 Define content as list of ContentIR (success: multiple content items per cell)
- [x] 2.1.2.5 Define RowIR struct with properties and cells (success: row contains cells)

### 2.1.3 Content IR Types
- [x] **Task 2.1.3 Complete**

Define IR types for content elements.

- [x] 2.1.3.1 Define LabelIR with text, style fields (success: label IR created)
- [x] 2.1.3.2 Define FieldIR with source, format, decimal_places, style fields (success: field IR created)
- [x] 2.1.3.3 Define NestedLayoutIR for layouts within cells (success: nested layouts representable)
- [x] 2.1.3.4 Create ContentIR union type of all content types (success: content is polymorphic)

### 2.1.4 Supporting IR Types
- [x] **Task 2.1.4 Complete**

Define IR types for supporting elements.

- [x] 2.1.4.1 Define LineIR with orientation, position, start, end, stroke (success: line IR created)
- [x] 2.1.4.2 Define HeaderIR with repeat, level, rows (success: header IR created)
- [x] 2.1.4.3 Define FooterIR with repeat, rows (success: footer IR created)
- [x] 2.1.4.4 Define StyleIR with font_size, font_weight, color, font_family (success: style IR created)

### Unit Tests - Section 2.1
- [x] 2.1.T.1 Test all IR struct creation
- [x] 2.1.T.2 Test nested IR structures
- [ ] 2.1.T.3 Test IR serialization/deserialization (deferred to Phase 3)

## 2.2 DSL to IR Transformers

### 2.2.1 Grid Transformer
- [x] **Task 2.2.1 Complete**

Transform grid DSL entities to GridIR.

- [x] 2.2.1.1 Create `AshReports.Layout.Transformer.Grid` module (success: module compiles)
- [x] 2.2.1.2 Transform columns property to normalized track sizes (success: all track types normalize)
- [x] 2.2.1.3 Transform rows property to normalized track sizes (success: rows normalize)
- [x] 2.2.1.4 Calculate grid dimensions from children (success: dimensions computed correctly)
- [x] 2.2.1.5 Transform gutter/column_gutter/row_gutter to spacing values (success: gutters resolve)
- [x] 2.2.1.6 Transform fill function to IR representation (success: conditional fills preserved)

### 2.2.2 Table Transformer
- [x] **Task 2.2.2 Complete**

Transform table DSL entities to TableIR.

- [x] 2.2.2.1 Create `AshReports.Layout.Transformer.Table` module (success: module compiles)
- [x] 2.2.2.2 Extend grid transformer for table-specific properties (success: table extends grid)
- [x] 2.2.2.3 Transform header sections to HeaderIR (success: headers transform)
- [x] 2.2.2.4 Transform footer sections to FooterIR (success: footers transform)
- [x] 2.2.2.5 Apply table defaults (stroke: "1pt", inset: "5pt") (success: defaults applied)

### 2.2.3 Stack Transformer
- [x] **Task 2.2.3 Complete**

Transform stack DSL entities to StackIR.

- [x] 2.2.3.1 Create `AshReports.Layout.Transformer.Stack` module (success: module compiles)
- [x] 2.2.3.2 Transform dir property to direction enum (success: direction normalizes)
- [x] 2.2.3.3 Transform spacing property to length value (success: spacing normalizes)
- [x] 2.2.3.4 Recursively transform child layouts (success: nested layouts transform)

### 2.2.4 Cell and Row Transformers
- [x] **Task 2.2.4 Complete**

Transform row and cell DSL entities to IR.

- [x] 2.2.4.1 Create `AshReports.Layout.Transformer.Row` module (success: module compiles)
- [x] 2.2.4.2 Create `AshReports.Layout.Transformer.Cell` module (success: module compiles)
- [x] 2.2.4.3 Transform cell content to ContentIR list (success: content transforms)
- [x] 2.2.4.4 Preserve property inheritance chain (row -> cell -> content) (success: inheritance works)

### Unit Tests - Section 2.2
- [x] 2.2.T.1 Test grid transformer with all property combinations
- [x] 2.2.T.2 Test table transformer with header/footer
- [x] 2.2.T.3 Test stack transformer with nested layouts
- [x] 2.2.T.4 Test cell transformer with content
- [x] 2.2.T.5 Test property inheritance

## 2.3 Cell Positioning Engine

### 2.3.1 Automatic Flow Positioning
- [x] **Task 2.3.1 Complete**

Calculate cell positions for row-major automatic flow.

- [x] 2.3.1.1 Create `AshReports.Layout.Positioning` module (success: module compiles)
- [x] 2.3.1.2 Implement row-major cell placement algorithm (success: cells fill left-to-right, top-to-bottom)
- [x] 2.3.1.3 Track occupied cells during placement (success: occupied set maintained)
- [x] 2.3.1.4 Skip occupied positions when placing cells (success: no cell overlap)
- [x] 2.3.1.5 Calculate next available position after spanning cell (success: spans handled correctly)

### 2.3.2 Explicit Positioning
- [x] **Task 2.3.2 Complete**

Handle explicitly positioned cells with x/y coordinates.

- [x] 2.3.2.1 Detect cells with explicit x/y positions (success: explicit cells identified)
- [x] 2.3.2.2 Place explicit cells before flow calculation (success: explicit cells placed first)
- [x] 2.3.2.3 Mark explicit cell positions as occupied (success: occupancy updated)
- [x] 2.3.2.4 Validate no position conflicts (success: overlap raises error)

### 2.3.3 Spanning Calculations
- [x] **Task 2.3.3 Complete**

Calculate occupied positions for spanning cells.

- [x] 2.3.3.1 Calculate all positions occupied by colspan (success: horizontal span works)
- [x] 2.3.3.2 Calculate all positions occupied by rowspan (success: vertical span works)
- [x] 2.3.3.3 Calculate all positions for colspan + rowspan (success: 2D span works)
- [x] 2.3.3.4 Validate spans don't exceed grid bounds (success: overflow raises error)

### 2.3.4 Row-Based Positioning
- [x] **Task 2.3.4 Complete**

Handle positioning for explicit row containers.

- [x] 2.3.4.1 Reset column counter for each row (success: rows start at column 0)
- [x] 2.3.4.2 Track row index for each row container (success: row indices assigned)
- [x] 2.3.4.3 Place cells within row at sequential columns (success: cells fill row)
- [x] 2.3.4.4 Handle row-level spanning that extends to next rows (success: rowspan crosses rows)

### Unit Tests - Section 2.3
- [x] 2.3.T.1 Test automatic flow positioning
- [x] 2.3.T.2 Test explicit positioning
- [x] 2.3.T.3 Test colspan calculations
- [x] 2.3.T.4 Test rowspan calculations
- [x] 2.3.T.5 Test mixed spanning scenarios
- [x] 2.3.T.6 Test row-based positioning
- [x] 2.3.T.7 Test error handling for conflicts

## 2.4 Property Resolution

### 2.4.1 Property Inheritance
- [x] **Task 2.4.1 Complete**

Resolve property inheritance from parent to child.

- [x] 2.4.1.1 Create `AshReports.Layout.PropertyResolver` module (success: module compiles)
- [x] 2.4.1.2 Implement inheritance chain: grid/table -> row -> cell (success: properties inherit)
- [x] 2.4.1.3 Handle property override at each level (success: child overrides parent)
- [x] 2.4.1.4 Resolve align property with default fallback (success: alignment resolves)
- [x] 2.4.1.5 Resolve inset property with default fallback (success: inset resolves)

### 2.4.2 Conditional Property Evaluation
- [x] **Task 2.4.2 Complete**

Evaluate conditional properties like fill functions.

- [x] 2.4.2.1 Detect function-based fill properties (success: functions identified)
- [x] 2.4.2.2 Preserve function in IR for renderer evaluation (success: function preserved)
- [x] 2.4.2.3 Support position-based fill function signature (x, y) (success: function receives position)
- [x] 2.4.2.4 Handle static vs dynamic property distinction (success: static/dynamic separated)

### 2.4.3 Length Normalization
- [x] **Task 2.4.3 Complete**

Normalize length values to consistent format.

- [x] 2.4.3.1 Parse "100pt" string format (success: pt unit parsed)
- [x] 2.4.3.2 Parse "2cm" string format (success: cm unit parsed)
- [x] 2.4.3.3 Parse "20%" percentage format (success: percentage parsed)
- [x] 2.4.3.4 Normalize to internal length representation (success: all lengths normalize)

### Unit Tests - Section 2.4
- [x] 2.4.T.1 Test property inheritance chain
- [x] 2.4.T.2 Test property override
- [x] 2.4.T.3 Test conditional fill preservation
- [x] 2.4.T.4 Test length normalization

## 2.5 Transformer Pipeline

### 2.5.1 Pipeline Orchestration
- [ ] **Task 2.5.1 Complete**

Create main transformer pipeline.

- [ ] 2.5.1.1 Create `AshReports.Layout.Transformer` main module (success: module compiles)
- [ ] 2.5.1.2 Implement transform/1 entry point (success: DSL entity transforms to IR)
- [ ] 2.5.1.3 Dispatch to appropriate type transformer (success: grid/table/stack dispatch works)
- [ ] 2.5.1.4 Handle recursive transformation for nested layouts (success: nested layouts transform)
- [ ] 2.5.1.5 Integrate positioning engine after entity transformation (success: positions calculated)
- [ ] 2.5.1.6 Integrate property resolver after positioning (success: properties resolved)

### 2.5.2 Band Integration
- [ ] **Task 2.5.2 Complete**

Integrate transformer with band processing.

- [ ] 2.5.2.1 Extract layout from band entity (success: layout extracted)
- [ ] 2.5.2.2 Transform band layout to IR (success: band layout transforms)
- [ ] 2.5.2.3 Attach IR to band for renderer access (success: IR accessible from band)

### Unit Tests - Section 2.5
- [ ] 2.5.T.1 Test full pipeline transformation
- [ ] 2.5.T.2 Test nested layout transformation
- [ ] 2.5.T.3 Test band integration
- [ ] 2.5.T.4 Test error handling throughout pipeline

## 2.6 Error Handling and Validation

### 2.6.1 DSL Validation Errors
- [ ] **Task 2.6.1 Complete**

Provide clear error messages for DSL validation failures.

- [ ] 2.6.1.1 Create `AshReports.Layout.Errors` module (success: module compiles)
- [ ] 2.6.1.2 Error for invalid property values with expected types (success: "Expected length, got :invalid")
- [ ] 2.6.1.3 Error for incorrect entity nesting (success: "cell cannot contain cell directly")
- [ ] 2.6.1.4 Error for missing required properties (success: "columns is required for grid")
- [ ] 2.6.1.5 Include file/line information in errors (success: errors show location)

### 2.6.2 Positioning Errors
- [ ] **Task 2.6.2 Complete**

Provide clear errors for cell positioning problems.

- [ ] 2.6.2.1 Error for cell position conflicts (success: "Cell at (2,1) conflicts with existing cell")
- [ ] 2.6.2.2 Error for span overflow (success: "colspan 3 at column 2 exceeds grid width of 4")
- [ ] 2.6.2.3 Error for invalid explicit positions (success: "Position (5,0) outside grid bounds")
- [ ] 2.6.2.4 Warning for gaps in grid (success: "No cell at position (1,2)")

### 2.6.3 Property Validation
- [ ] **Task 2.6.3 Complete**

Validate property values during transformation.

- [ ] 2.6.3.1 Validate track size formats (success: "Invalid track size: 'abc'")
- [ ] 2.6.3.2 Validate color formats (success: "Invalid color: 'not-a-color'")
- [ ] 2.6.3.3 Validate alignment values (success: "Invalid alignment: :diagonal")
- [ ] 2.6.3.4 Validate length units (success: "Unknown unit in '10px'")

### Unit Tests - Section 2.6
- [ ] 2.6.T.1 Test all validation error messages
- [ ] 2.6.T.2 Test positioning error detection
- [ ] 2.6.T.3 Test property validation
- [ ] 2.6.T.4 Test error message formatting with locations

## Success Criteria

1. **IR Data Structures**: All layout elements representable as typed IR structs
2. **Grid Transformation**: Grid DSL entities transform to normalized GridIR with correct properties
3. **Table Transformation**: Table DSL entities transform with header/footer sections
4. **Stack Transformation**: Stack DSL entities transform with nested children
5. **Cell Positioning**: Automatic flow correctly places cells in row-major order
6. **Explicit Positioning**: Cells with x/y coordinates placed at specified positions
7. **Spanning**: Colspan and rowspan correctly mark occupied positions
8. **Property Inheritance**: Properties correctly inherit and override through hierarchy
9. **Pipeline**: Complete transformation from DSL to IR with all calculations

## Provides Foundation

This phase establishes the infrastructure for:

- **Phase 3**: Typst Renderer consuming IR to generate Typst markup
- **Phase 4**: HTML Renderer consuming IR to generate CSS Grid/Flexbox
- **Phase 5**: Demo App Migration requiring complete transformation pipeline

## Key Outputs

- Complete IR type definitions for all layout elements
- DSL to IR transformers for grid, table, stack, row, cell
- Cell positioning engine with automatic and explicit placement
- Spanning calculation logic
- Property inheritance and resolution
- Main transformer pipeline integrating all components
- Comprehensive unit tests for all transformation logic
