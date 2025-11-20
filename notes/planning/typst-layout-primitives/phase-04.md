# Phase 4: HTML Renderer

## Overview

This phase implements the HTML renderer that generates CSS Grid and Flexbox-based HTML from the Intermediate Representation. The renderer produces semantic HTML with inline styles for web display, supporting all layout features with proper CSS equivalents.

**Duration Estimate**: 1.5-2 weeks

**Dependencies**: Phase 1 (Core DSL Entities), Phase 2 (Intermediate Representation)

**Parallelization**: This phase can run concurrently with Phase 3 (Typst Renderer) once Phase 2 is complete. If multiple developers are available, this reduces total elapsed time by 1.5-2 weeks.

## 4.1 Core HTML Generation

### 4.1.1 Grid HTML Generation
- [ ] **Task 4.1.1 Complete**

Generate CSS Grid HTML from GridIR.

- [ ] 4.1.1.1 Create `AshReports.Renderer.Html.Grid` module (success: module compiles)
- [ ] 4.1.1.2 Generate div with class="ash-grid" (success: grid container rendered)
- [ ] 4.1.1.3 Generate display: grid CSS property (success: grid display set)
- [ ] 4.1.1.4 Generate grid-template-columns from track sizes (success: columns render)
- [ ] 4.1.1.5 Generate grid-template-rows when explicit (success: rows render)
- [ ] 4.1.1.6 Generate gap CSS property from gutter (success: gap renders)
- [ ] 4.1.1.7 Generate column-gap and row-gap overrides (success: specific gaps render)
- [ ] 4.1.1.8 Generate align-items and justify-items from align (success: alignment renders)
- [ ] 4.1.1.9 Generate padding from inset (not directly mapped, apply to cells) (success: inset handled)

### 4.1.2 Table HTML Generation
- [ ] **Task 4.1.2 Complete**

Generate semantic HTML table from TableIR.

- [ ] 4.1.2.1 Create `AshReports.Renderer.Html.Table` module (success: module compiles)
- [ ] 4.1.2.2 Generate table element with class="ash-table" (success: table rendered)
- [ ] 4.1.2.3 Generate thead for header sections (success: thead rendered)
- [ ] 4.1.2.4 Generate tbody for data rows (success: tbody rendered)
- [ ] 4.1.2.5 Generate tfoot for footer sections (success: tfoot rendered)
- [ ] 4.1.2.6 Apply border-collapse and default styling (success: table styled)
- [ ] 4.1.2.7 Generate tr for rows, th for headers, td for data (success: proper elements)

### 4.1.3 Stack HTML Generation
- [ ] **Task 4.1.3 Complete**

Generate Flexbox HTML from StackIR.

- [ ] 4.1.3.1 Create `AshReports.Renderer.Html.Stack` module (success: module compiles)
- [ ] 4.1.3.2 Generate div with class="ash-stack" (success: stack container rendered)
- [ ] 4.1.3.3 Generate display: flex CSS property (success: flex display set)
- [ ] 4.1.3.4 Map :ttb to flex-direction: column (success: vertical stack renders)
- [ ] 4.1.3.5 Map :btt to flex-direction: column-reverse (success: reverse vertical renders)
- [ ] 4.1.3.6 Map :ltr to flex-direction: row (success: horizontal stack renders)
- [ ] 4.1.3.7 Map :rtl to flex-direction: row-reverse (success: reverse horizontal renders)
- [ ] 4.1.3.8 Generate gap CSS property from spacing (success: spacing renders)

### Unit Tests - Section 4.1
- [ ] 4.1.T.1 Test grid HTML generation
- [ ] 4.1.T.2 Test table HTML with thead/tbody/tfoot
- [ ] 4.1.T.3 Test stack HTML with all directions
- [ ] 4.1.T.4 Test generated HTML is valid

## 4.2 Cell and Content Rendering

### 4.2.1 Grid Cell HTML Generation
- [ ] **Task 4.2.1 Complete**

Generate grid cells as divs with CSS Grid properties.

- [ ] 4.2.1.1 Create `AshReports.Renderer.Html.Cell` module (success: module compiles)
- [ ] 4.2.1.2 Generate div with class="ash-cell" for grid cells (success: cell rendered)
- [ ] 4.2.1.3 Generate grid-column: span N for colspan (success: colspan renders)
- [ ] 4.2.1.4 Generate grid-row: span N for rowspan (success: rowspan renders)
- [ ] 4.2.1.5 Generate explicit grid-column and grid-row for x/y positioning (success: explicit position)
- [ ] 4.2.1.6 Generate text-align from align property (success: alignment renders)
- [ ] 4.2.1.7 Generate background-color from fill (success: fill renders)
- [ ] 4.2.1.8 Generate border from stroke (success: stroke renders)
- [ ] 4.2.1.9 Generate padding from inset (success: inset renders)

### 4.2.2 Table Cell HTML Generation
- [ ] **Task 4.2.2 Complete**

Generate table cells as td/th elements.

- [ ] 4.2.2.1 Generate th for header cells, td for data cells (success: correct elements)
- [ ] 4.2.2.2 Generate colspan attribute for column spanning (success: colspan works)
- [ ] 4.2.2.3 Generate rowspan attribute for row spanning (success: rowspan works)
- [ ] 4.2.2.4 Apply inline styles for alignment, fill, stroke, inset (success: styles apply)

### 4.2.3 Content HTML Generation
- [ ] **Task 4.2.3 Complete**

Generate HTML for label and field content.

- [ ] 4.2.3.1 Create `AshReports.Renderer.Html.Content` module (success: module compiles)
- [ ] 4.2.3.2 Generate span for labels with text content (success: label renders)
- [ ] 4.2.3.3 Generate span for fields with formatted value (success: field renders)
- [ ] 4.2.3.4 Apply inline styles for font_size, font_weight, color (success: styles apply)
- [ ] 4.2.3.5 Escape HTML special characters (success: XSS prevention)

### Unit Tests - Section 4.2
- [ ] 4.2.T.1 Test grid cell with spanning
- [ ] 4.2.T.2 Test table cell elements
- [ ] 4.2.T.3 Test content rendering
- [ ] 4.2.T.4 Test HTML escaping

## 4.3 CSS Property Mapping

### 4.3.1 Track Size to CSS
- [ ] **Task 4.3.1 Complete**

Map track sizes to CSS grid-template-columns/rows.

- [ ] 4.3.1.1 Map :auto to `auto` (success: auto maps)
- [ ] 4.3.1.2 Map {:fr, n} to `nfr` (success: fractional units map)
- [ ] 4.3.1.3 Map length strings directly (success: `100pt`, `20%` pass through)
- [ ] 4.3.1.4 Convert pt to px where needed (success: unit conversion)
- [ ] 4.3.1.5 Join array into space-separated string (success: `100px 1fr auto`)

### 4.3.2 Alignment to CSS
- [ ] **Task 4.3.2 Complete**

Map alignment values to CSS properties.

- [ ] 4.3.2.1 Map :left to text-align: left (success: left aligns)
- [ ] 4.3.2.2 Map :center to text-align: center (success: center aligns)
- [ ] 4.3.2.3 Map :right to text-align: right (success: right aligns)
- [ ] 4.3.2.4 Map :top to vertical-align: top (success: top aligns)
- [ ] 4.3.2.5 Map :middle to vertical-align: middle (success: middle aligns)
- [ ] 4.3.2.6 Map :bottom to vertical-align: bottom (success: bottom aligns)
- [ ] 4.3.2.7 Handle combined alignments (success: both axes set)

### 4.3.3 Color and Fill to CSS
- [ ] **Task 4.3.3 Complete**

Map color and fill values to CSS.

- [ ] 4.3.3.1 Pass hex colors directly (success: `#ffffff` works)
- [ ] 4.3.3.2 Map :none to transparent or no style (success: none handled)
- [ ] 4.3.3.3 Evaluate fill functions for each cell (success: conditional fills work)
- [ ] 4.3.3.4 Set background-color CSS property (success: backgrounds render)

### 4.3.4 Stroke to CSS
- [ ] **Task 4.3.4 Complete**

Map stroke values to CSS border properties.

- [ ] 4.3.4.1 Map :none to border: none (success: no border)
- [ ] 4.3.4.2 Map simple width to border: width solid currentColor (success: simple border)
- [ ] 4.3.4.3 Map width + color to full border specification (success: colored border)
- [ ] 4.3.4.4 Map dash styles to border-style (success: dashed/dotted borders)

### Unit Tests - Section 4.3
- [ ] 4.3.T.1 Test track size CSS mapping
- [ ] 4.3.T.2 Test alignment CSS mapping
- [ ] 4.3.T.3 Test color CSS mapping
- [ ] 4.3.T.4 Test stroke CSS mapping

## 4.4 Data Interpolation

### 4.4.1 Variable Interpolation
- [ ] **Task 4.4.1 Complete**

Interpolate report variables into HTML content.

- [ ] 4.4.1.1 Create `AshReports.Renderer.Html.Interpolation` module (success: module compiles)
- [ ] 4.4.1.2 Share interpolation logic with Typst renderer (success: code reuse)
- [ ] 4.4.1.3 Escape interpolated values for HTML (success: XSS safe)
- [ ] 4.4.1.4 Handle missing variables gracefully (success: missing handled)

### 4.4.2 Field Value Formatting
- [ ] **Task 4.4.2 Complete**

Format field values for HTML display.

- [ ] 4.4.2.1 Share formatting logic with Typst renderer (success: code reuse)
- [ ] 4.4.2.2 Format currency, number, date, datetime, percent (success: all formats work)
- [ ] 4.4.2.3 Apply decimal_places property (success: rounding works)
- [ ] 4.4.2.4 Escape formatted output for HTML (success: XSS safe)

### Unit Tests - Section 4.4
- [ ] 4.4.T.1 Test variable interpolation with escaping
- [ ] 4.4.T.2 Test field formatting
- [ ] 4.4.T.3 Test XSS prevention

## 4.5 Styling

### 4.5.1 Inline Styles
- [ ] **Task 4.5.1 Complete**

Generate inline CSS styles for elements.

- [ ] 4.5.1.1 Create `AshReports.Renderer.Html.Styling` module (success: module compiles)
- [ ] 4.5.1.2 Build style attribute from style properties (success: style attribute generated)
- [ ] 4.5.1.3 Map font_size to font-size CSS (success: font size applies)
- [ ] 4.5.1.4 Map font_weight to font-weight CSS (success: font weight applies)
- [ ] 4.5.1.5 Map color to color CSS (success: text color applies)
- [ ] 4.5.1.6 Map font_family to font-family CSS (success: font family applies)
- [ ] 4.5.1.7 Combine multiple styles efficiently (success: single style attribute)

### 4.5.2 CSS Classes
- [ ] **Task 4.5.2 Complete**

Apply consistent CSS classes for styling hooks.

- [ ] 4.5.2.1 Apply ash-grid, ash-table, ash-stack classes (success: container classes)
- [ ] 4.5.2.2 Apply ash-cell class to all cells (success: cell class)
- [ ] 4.5.2.3 Apply ash-header, ash-footer classes (success: section classes)
- [ ] 4.5.2.4 Apply ash-label, ash-field classes to content (success: content classes)

### Unit Tests - Section 4.5
- [ ] 4.5.T.1 Test inline style generation
- [ ] 4.5.T.2 Test CSS classes applied
- [ ] 4.5.T.3 Test combined styling

## 4.6 Renderer Integration

### 4.6.1 Main HTML Renderer
- [ ] **Task 4.6.1 Complete**

Create main HTML renderer entry point.

- [ ] 4.6.1.1 Create `AshReports.Renderer.Html` main module (success: module compiles)
- [ ] 4.6.1.2 Implement render/2 accepting IR and data (success: render entry point works)
- [ ] 4.6.1.3 Dispatch to appropriate layout renderer (success: grid/table/stack dispatch)
- [ ] 4.6.1.4 Combine all generated HTML (success: complete HTML output)
- [ ] 4.6.1.5 Handle multiple bands/layouts in sequence (success: full report renders)

### 4.6.2 Report Pipeline Integration
- [ ] **Task 4.6.2 Complete**

Integrate HTML renderer with report pipeline.

- [ ] 4.6.2.1 Register HTML renderer for :html format (success: html format uses renderer)
- [ ] 4.6.2.2 Accept report IR from transformer pipeline (success: IR flows to renderer)
- [ ] 4.6.2.3 Pass data context for interpolation (success: data available)
- [ ] 4.6.2.4 Return complete HTML string (success: HTML returned)

### 4.6.3 HEEX Integration
- [ ] **Task 4.6.3 Complete**

Integrate with LiveView HEEX rendering.

- [ ] 4.6.3.1 Register HEEX renderer for :heex format (success: heex format works)
- [ ] 4.6.3.2 Generate Phoenix.HTML safe output (success: safe HTML)
- [ ] 4.6.3.3 Support LiveView event bindings if needed (success: interactive features)

### Unit Tests - Section 4.6
- [ ] 4.6.T.1 Test main HTML renderer
- [ ] 4.6.T.2 Test multi-band reports
- [ ] 4.6.T.3 Test pipeline integration
- [ ] 4.6.T.4 Test HEEX output

## 4.7 JSON Renderer

### 4.7.1 JSON Output
- [ ] **Task 4.7.1 Complete**

Generate JSON representation of IR for client-side rendering.

- [ ] 4.7.1.1 Create `AshReports.Renderer.Json` module (success: module compiles)
- [ ] 4.7.1.2 Serialize LayoutIR to JSON-compatible map (success: IR serializes)
- [ ] 4.7.1.3 Serialize all nested structures (success: full structure)
- [ ] 4.7.1.4 Include resolved data values (success: data included)
- [ ] 4.7.1.5 Register for :json format (success: json format works)

### Unit Tests - Section 4.7
- [ ] 4.7.T.1 Test JSON serialization
- [ ] 4.7.T.2 Test nested structure serialization
- [ ] 4.7.T.3 Test data inclusion

## Success Criteria

1. **Grid Rendering**: Generate valid CSS Grid HTML with all properties mapped
2. **Table Rendering**: Generate semantic HTML tables with thead/tbody/tfoot
3. **Stack Rendering**: Generate Flexbox HTML with proper direction mapping
4. **Cell Rendering**: Generate cells with spanning, positioning, and styling
5. **Content Rendering**: Render labels and fields with proper escaping
6. **CSS Mapping**: Correctly map all IR properties to CSS equivalents
7. **Data Interpolation**: Interpolate variables with HTML escaping
8. **Styling**: Apply inline styles and CSS classes consistently
9. **Integration**: Complete pipeline from IR to HTML output
10. **JSON Output**: Serialize IR to JSON for client-side use

## Provides Foundation

This phase establishes the infrastructure for:

- **Phase 5**: Demo App Migration requiring HTML output for web display
- **Phase 6**: Advanced Features building on renderer capabilities

## Key Outputs

- Complete HTML renderer generating valid HTML/CSS from IR
- CSS Grid implementation for grids
- Semantic HTML table implementation
- Flexbox implementation for stacks
- Track size, alignment, color, and stroke CSS mapping
- Variable interpolation with HTML escaping
- Inline styles and CSS classes
- JSON renderer for client-side rendering
- Integration with report pipeline
