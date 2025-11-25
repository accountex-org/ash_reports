# Phase 5: Demo App Migration

## Overview

This phase migrates all existing reports in the ash_reports_demo application to the new Typst layout primitives DSL. Each report will be completely rewritten using grid, table, stack, row, and cell entities, demonstrating the full capabilities of the new system.

**Duration Estimate**: 1.5-2 weeks

**Dependencies**: Phase 1 (Core DSL Entities), Phase 2 (IR), Phase 3 (Typst Renderer), Phase 4 (HTML Renderer)

## Early Validation Strategy

**IMPORTANT**: Don't wait until Phase 5 to test real reports. Use progressive migration to validate the system throughout development:

1. **After Phase 1**: Migrate `product_inventory` (simplest report) using just the DSL entities
2. **During Phase 2**: Use product_inventory to test IR transformation
3. **During Phase 3**: Use product_inventory to test Typst/PDF output
4. **During Phase 4**: Use product_inventory to test HTML output
5. **Phase 5**: Complete remaining 3 reports with confidence

This ensures the DSL design works for actual use cases and surfaces issues early when they're cheap to fix.

**Checkpoint**: After product_inventory works end-to-end, review before migrating remaining reports.

## 5.1 Customer Summary Report

### 5.1.1 Report Structure Analysis
- [ ] **Task 5.1.1 Complete**

Analyze existing customer_summary report structure.

- [ ] 5.1.1.1 Document current band structure and content (success: structure documented)
- [ ] 5.1.1.2 Identify all variables and their reset scopes (success: variables listed)
- [ ] 5.1.1.3 Identify grouping configuration (success: groups documented)
- [ ] 5.1.1.4 Map current fields to new cell-based layout (success: mapping complete)

### 5.1.2 Title Band Migration
- [ ] **Task 5.1.2 Complete**

Rewrite title band using new layout primitives.

- [ ] 5.1.2.1 Create grid layout for title band (success: grid defined)
- [ ] 5.1.2.2 Add centered title label with styling (success: title renders)
- [ ] 5.1.2.3 Add subtitle/date range label (success: subtitle renders)
- [ ] 5.1.2.4 Apply appropriate spacing and alignment (success: layout correct)

### 5.1.3 Column Header Band Migration
- [ ] **Task 5.1.3 Complete**

Rewrite column headers using table with header section.

- [ ] 5.1.3.1 Create table layout with column definitions (success: columns defined)
- [ ] 5.1.3.2 Add header section with repeat: true (success: header repeats)
- [ ] 5.1.3.3 Add label for each column with bold styling (success: headers styled)
- [ ] 5.1.3.4 Apply background fill for header row (success: header highlighted)

### 5.1.4 Detail Band Migration
- [ ] **Task 5.1.4 Complete**

Rewrite detail band with table layout.

- [ ] 5.1.4.1 Create table layout matching header columns (success: columns match)
- [ ] 5.1.4.2 Add row with cells for each field (success: fields placed)
- [ ] 5.1.4.3 Apply field sources and formats (success: data displays)
- [ ] 5.1.4.4 Apply alignment (right-align numeric columns) (success: alignment correct)
- [ ] 5.1.4.5 Add alternating row fill (success: zebra striping)

### 5.1.5 Group Header/Footer Migration
- [ ] **Task 5.1.5 Complete**

Rewrite group bands with grid layouts.

- [ ] 5.1.5.1 Create grid for group header with group value display (success: header renders)
- [ ] 5.1.5.2 Create grid for group footer with subtotals (success: footer renders)
- [ ] 5.1.5.3 Apply group-level styling (background, font weight) (success: styled)
- [ ] 5.1.5.4 Reference group variables correctly (success: variables interpolate)

### 5.1.6 Summary Band Migration
- [ ] **Task 5.1.6 Complete**

Rewrite summary band with stack and grid.

- [ ] 5.1.6.1 Create stack layout for vertical arrangement (success: stack defined)
- [ ] 5.1.6.2 Add grid for summary statistics (success: stats display)
- [ ] 5.1.6.3 Add grand total with emphasis styling (success: total prominent)
- [ ] 5.1.6.4 Reference report-level variables (success: totals correct)

### Unit Tests - Section 5.1
- [ ] 5.1.T.1 Test customer_summary compiles without errors
- [ ] 5.1.T.2 Test PDF generation produces valid output
- [ ] 5.1.T.3 Test HTML generation produces valid output
- [ ] 5.1.T.4 Test all variables interpolate correctly
- [ ] 5.1.T.5 Test grouping works correctly

## 5.2 Product Inventory Report

### 5.2.1 Report Structure Analysis
- [x] **Task 5.2.1 Complete**

Analyze existing product_inventory report structure.

- [x] 5.2.1.1 Document current band structure (success: structure documented)
- [x] 5.2.1.2 Identify inventory-specific formatting needs (success: formats identified)
- [ ] 5.2.1.3 Plan conditional styling for stock levels (deferred: future enhancement)

### 5.2.2 Title Band Migration
- [x] **Task 5.2.2 Complete**

Rewrite title band for product inventory.

- [x] 5.2.2.1 Create grid layout with centered title (success: title renders)
- [ ] 5.2.2.2 Add report date/timestamp (deferred: future enhancement)

### 5.2.3 Table Band Migration
- [x] **Task 5.2.3 Complete**

Rewrite main data table with inventory columns.

- [x] 5.2.3.1 Create table with product columns (success: columns defined)
- [x] 5.2.3.2 Add header section with column labels (success: headers render)
- [x] 5.2.3.3 Add detail row with product fields (success: data displays)
- [ ] 5.2.3.4 Apply conditional fill for low stock warning (deferred: future enhancement)
- [x] 5.2.3.5 Format quantity and price columns (success: formats correct - currency and percent)

### 5.2.4 Summary Band Migration
- [x] **Task 5.2.4 Complete**

Rewrite summary with inventory totals.

- [x] 5.2.4.1 Create grid for summary statistics (success: 2x2 grid with labels)
- [x] 5.2.4.2 Display total products, total value (success: totals render)
- [ ] 5.2.4.3 Display low stock count if applicable (deferred: future enhancement)

### Unit Tests - Section 5.2
- [x] 5.2.T.1 Test product_inventory compiles without errors
- [ ] 5.2.T.2 Test PDF generation (requires Typst integration)
- [x] 5.2.T.3 Test HTML generation
- [ ] 5.2.T.4 Test conditional styling for stock levels (deferred: future enhancement)

## 5.3 Invoice Details Report

### 5.3.1 Report Structure Analysis
- [ ] **Task 5.3.1 Complete**

Analyze existing invoice_details report structure.

- [ ] 5.3.1.1 Document multi-level grouping (customer, invoice) (success: groups documented)
- [ ] 5.3.1.2 Document line item detail structure (success: details documented)
- [ ] 5.3.1.3 Plan nested table structures (success: nesting planned)

### 5.3.2 Title Band Migration
- [ ] **Task 5.3.2 Complete**

Rewrite title band for invoice details.

- [ ] 5.3.2.1 Create grid with report title and date range (success: title renders)
- [ ] 5.3.2.2 Apply prominent styling (success: title styled)

### 5.3.3 Customer Group Header Migration
- [ ] **Task 5.3.3 Complete**

Rewrite customer-level group header.

- [ ] 5.3.3.1 Create grid for customer information (success: customer header)
- [ ] 5.3.3.2 Display customer name and details (success: customer shows)
- [ ] 5.3.3.3 Apply group header styling (success: styled)

### 5.3.4 Invoice Group Header Migration
- [ ] **Task 5.3.4 Complete**

Rewrite invoice-level group header.

- [ ] 5.3.4.1 Create grid for invoice header info (success: invoice header)
- [ ] 5.3.4.2 Display invoice number, date, status (success: info displays)
- [ ] 5.3.4.3 Apply indentation for nested group (success: hierarchy clear)

### 5.3.5 Line Item Detail Migration
- [ ] **Task 5.3.5 Complete**

Rewrite line item detail table.

- [ ] 5.3.5.1 Create table with line item columns (success: columns defined)
- [ ] 5.3.5.2 Add header with column labels (success: headers render)
- [ ] 5.3.5.3 Add detail row with item fields (success: items display)
- [ ] 5.3.5.4 Apply currency formatting for prices (success: prices formatted)
- [ ] 5.3.5.5 Calculate and display line totals (success: totals correct)

### 5.3.6 Invoice Footer Migration
- [ ] **Task 5.3.6 Complete**

Rewrite invoice-level footer with subtotals.

- [ ] 5.3.6.1 Create table for invoice totals (success: totals table)
- [ ] 5.3.6.2 Display subtotal, tax, total (success: amounts display)
- [ ] 5.3.6.3 Apply emphasis to total line (success: total prominent)

### 5.3.7 Customer Footer Migration
- [ ] **Task 5.3.7 Complete**

Rewrite customer-level footer.

- [ ] 5.3.7.1 Create grid for customer totals (success: customer totals)
- [ ] 5.3.7.2 Display total invoices, total amount (success: summary shows)

### 5.3.8 Report Summary Migration
- [ ] **Task 5.3.8 Complete**

Rewrite report summary with grand totals.

- [ ] 5.3.8.1 Create stack with summary sections (success: summary layout)
- [ ] 5.3.8.2 Display total customers, invoices, amount (success: totals show)
- [ ] 5.3.8.3 Apply grand total styling (success: prominent display)

### Unit Tests - Section 5.3
- [ ] 5.3.T.1 Test invoice_details compiles without errors
- [ ] 5.3.T.2 Test PDF generation with multiple pages
- [ ] 5.3.T.3 Test HTML generation
- [ ] 5.3.T.4 Test multi-level grouping
- [ ] 5.3.T.5 Test all calculations correct

## 5.4 Financial Summary Report

### 5.4.1 Report Structure Analysis
- [ ] **Task 5.4.1 Complete**

Analyze existing financial_summary report structure.

- [ ] 5.4.1.1 Document aggregation structure (success: structure documented)
- [ ] 5.4.1.2 Identify key financial metrics (success: metrics listed)
- [ ] 5.4.1.3 Plan dashboard-style layout (success: layout planned)

### 5.4.2 Title Band Migration
- [ ] **Task 5.4.2 Complete**

Rewrite title band for financial summary.

- [ ] 5.4.2.1 Create grid with report title (success: title renders)
- [ ] 5.4.2.2 Add period/date range display (success: period shows)

### 5.4.3 Summary Statistics Migration
- [ ] **Task 5.4.3 Complete**

Rewrite summary statistics using grid layout.

- [ ] 5.4.3.1 Create grid for KPI cards layout (success: grid defined)
- [ ] 5.4.3.2 Add cell for each key metric (success: metrics placed)
- [ ] 5.4.3.3 Style each metric with label and value (success: styled)
- [ ] 5.4.3.4 Apply conditional coloring for trends (success: colors indicate)

### 5.4.4 Breakdown Table Migration
- [ ] **Task 5.4.4 Complete**

Rewrite breakdown tables for financial details.

- [ ] 5.4.4.1 Create table for revenue breakdown (success: table defined)
- [ ] 5.4.4.2 Add categories and amounts (success: data displays)
- [ ] 5.4.4.3 Apply currency formatting (success: formatted)
- [ ] 5.4.4.4 Add totals row (success: totals show)

### 5.4.5 Grand Total Migration
- [ ] **Task 5.4.5 Complete**

Rewrite grand total section.

- [ ] 5.4.5.1 Create emphasized total display (success: total prominent)
- [ ] 5.4.5.2 Apply strong styling (success: stands out)

### Unit Tests - Section 5.4
- [ ] 5.4.T.1 Test financial_summary compiles without errors
- [ ] 5.4.T.2 Test PDF generation
- [ ] 5.4.T.3 Test HTML generation
- [ ] 5.4.T.4 Test all calculations correct

## 5.5 Test Suite Updates

### 5.5.1 Unit Test Migration
- [ ] **Task 5.5.1 Complete**

Update all report-related unit tests.

- [ ] 5.5.1.1 Update tests for new DSL syntax (success: tests compile)
- [ ] 5.5.1.2 Add tests for new layout features (success: features tested)
- [ ] 5.5.1.3 Remove tests for legacy column syntax (success: legacy removed)
- [ ] 5.5.1.4 Ensure all tests pass (success: green test suite)

### 5.5.2 Integration Test Updates
- [ ] **Task 5.5.2 Complete**

Update integration tests for complete report flow.

- [ ] 5.5.2.1 Test report compilation end-to-end (success: reports compile)
- [ ] 5.5.2.2 Test PDF generation for all reports (success: PDFs generate)
- [ ] 5.5.2.3 Test HTML generation for all reports (success: HTML generates)
- [ ] 5.5.2.4 Test data interpolation with sample data (success: data works)

### 5.5.3 Visual Regression Tests
- [ ] **Task 5.5.3 Complete**

Add visual tests for report output.

- [ ] 5.5.3.1 Create baseline PDF snapshots (success: baselines created)
- [ ] 5.5.3.2 Create baseline HTML screenshots (success: baselines created)
- [ ] 5.5.3.3 Implement visual diff comparison (success: diffs work)

### Unit Tests - Section 5.5
- [ ] 5.5.T.1 All unit tests pass
- [ ] 5.5.T.2 All integration tests pass
- [ ] 5.5.T.3 Visual regression tests pass

## 5.6 Documentation Updates

### 5.6.1 Code Documentation
- [ ] **Task 5.6.1 Complete**

Update documentation for migrated reports.

- [ ] 5.6.1.1 Add comments explaining layout structure (success: comments added)
- [ ] 5.6.1.2 Document any migration-specific patterns (success: patterns documented)

### 5.6.2 Example Updates
- [ ] **Task 5.6.2 Complete**

Ensure demo app serves as good examples.

- [ ] 5.6.2.1 Verify each report demonstrates different features (success: variety shown)
- [ ] 5.6.2.2 Add inline comments for learning (success: educational value)

## Success Criteria

1. **Customer Summary**: Report fully migrated with all bands using new layout DSL
2. **Product Inventory**: Report fully migrated with conditional styling for stock levels
3. **Invoice Details**: Report fully migrated with multi-level grouping and nested tables
4. **Financial Summary**: Report fully migrated with dashboard-style grid layout
5. **Compilation**: All reports compile without errors
6. **PDF Output**: All reports generate valid PDF output
7. **HTML Output**: All reports generate valid HTML output
8. **Data Interpolation**: All variables and fields display correct values
9. **Calculations**: All totals and aggregations calculate correctly
10. **Tests**: All unit and integration tests pass

## Provides Foundation

This phase establishes:

- **Working examples** of all layout primitive features
- **Reference implementations** for users building new reports
- **Test coverage** ensuring the system works end-to-end
- **Validation** that the DSL design meets real-world needs

## Key Outputs

- Four fully migrated reports using new layout DSL
- Comprehensive test suite for all reports
- Visual regression baselines
- Updated documentation and examples
- Validated end-to-end report generation pipeline
