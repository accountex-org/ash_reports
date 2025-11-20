# Phase 6: Advanced Features

## Overview

This phase implements advanced layout features including deeply nested layouts, complex conditional styling, page break handling, and accessibility attributes. These features enhance the power and flexibility of the layout system for complex reporting scenarios.

**Duration Estimate**: 2-3 weeks

**Dependencies**: Phase 1-5 (Complete system with migrated demo app)

## 6.1 Nested Layouts

### 6.1.1 Deep Nesting Support
- [ ] **Task 6.1.1 Complete**

Support arbitrarily deep layout nesting.

- [ ] 6.1.1.1 Validate nested layout depth limits (success: reasonable limits set)
- [ ] 6.1.1.2 Handle recursive IR transformation for deep nesting (success: deep transforms work)
- [ ] 6.1.1.3 Optimize rendering for nested structures (success: performance acceptable)
- [ ] 6.1.1.4 Test grid-in-cell-in-table-in-stack scenarios (success: complex nesting works)

### 6.1.2 Layout Composition Patterns
- [ ] **Task 6.1.2 Complete**

Support common composition patterns.

- [ ] 6.1.2.1 Support stack within grid cell for multi-line content (success: pattern works)
- [ ] 6.1.2.2 Support grid within stack for side-by-side sections (success: pattern works)
- [ ] 6.1.2.3 Support table within table for nested data (success: nested tables)
- [ ] 6.1.2.4 Document recommended composition patterns (success: patterns documented)

### 6.1.3 Property Inheritance in Nested Layouts
- [ ] **Task 6.1.3 Complete**

Handle property inheritance across nesting boundaries.

- [ ] 6.1.3.1 Define inheritance rules for nested layouts (success: rules defined)
- [ ] 6.1.3.2 Handle font styling inheritance (success: fonts inherit)
- [ ] 6.1.3.3 Handle alignment inheritance (success: alignment inherits)
- [ ] 6.1.3.4 Allow explicit overrides at each level (success: overrides work)

### Unit Tests - Section 6.1
- [ ] 6.1.T.1 Test deep nesting scenarios
- [ ] 6.1.T.2 Test all composition patterns
- [ ] 6.1.T.3 Test property inheritance
- [ ] 6.1.T.4 Test performance with complex nesting

## 6.2 Conditional Styling

### 6.2.1 Function-Based Fill
- [ ] **Task 6.2.1 Complete**

Support full Elixir functions for conditional fill.

- [ ] 6.2.1.1 Support anonymous functions in DSL (success: `fn x, y -> ... end` works)
- [ ] 6.2.1.2 Compile functions at DSL parse time (success: compile-time validation)
- [ ] 6.2.1.3 Evaluate functions during render with position context (success: positions available)
- [ ] 6.2.1.4 Support referencing report data in functions (success: data accessible)

### 6.2.2 Conditional Stroke
- [ ] **Task 6.2.2 Complete**

Support conditional stroke styling.

- [ ] 6.2.2.1 Add function support to stroke property (success: conditional strokes)
- [ ] 6.2.2.2 Support conditional border highlighting (success: borders highlight)
- [ ] 6.2.2.3 Support different strokes for different cells (success: per-cell strokes)

### 6.2.3 Conditional Alignment
- [ ] **Task 6.2.3 Complete**

Support conditional alignment.

- [ ] 6.2.3.1 Add function support to align property (success: conditional alignment)
- [ ] 6.2.3.2 Support data-driven alignment (e.g., numeric detection) (success: smart alignment)

### 6.2.4 Style Rules DSL
- [ ] **Task 6.2.4 Complete**

Consider a declarative style rules DSL.

- [ ] 6.2.4.1 Evaluate need for declarative style rules (success: decision made)
- [ ] 6.2.4.2 Design style rule syntax if needed (success: syntax designed)
- [ ] 6.2.4.3 Implement style rules transformer if needed (success: rules transform)

### Unit Tests - Section 6.2
- [ ] 6.2.T.1 Test function-based fill
- [ ] 6.2.T.2 Test conditional stroke
- [ ] 6.2.T.3 Test conditional alignment
- [ ] 6.2.T.4 Test style rules if implemented

## 6.3 Page Break Handling

### 6.3.1 Cell Break Control
- [ ] **Task 6.3.1 Complete**

Control page breaks within cells.

- [ ] 6.3.1.1 Implement breakable property in Typst renderer (success: breakable works)
- [ ] 6.3.1.2 Generate Typst breakable parameter (success: `breakable: false` output)
- [ ] 6.3.1.3 Test page breaks with large cell content (success: breaks controlled)

### 6.3.2 Row Break Control
- [ ] **Task 6.3.2 Complete**

Control page breaks at row boundaries.

- [ ] 6.3.2.1 Add keep_together property to row (success: property added)
- [ ] 6.3.2.2 Generate Typst keep together semantics (success: rows stay together)
- [ ] 6.3.2.3 Handle multi-row groups that should stay together (success: groups work)

### 6.3.3 Band Break Control
- [ ] **Task 6.3.3 Complete**

Control page breaks between bands.

- [ ] 6.3.3.1 Add page_break property to band (success: property added)
- [ ] 6.3.3.2 Support :before, :after, :avoid values (success: break control)
- [ ] 6.3.3.3 Generate appropriate Typst page break commands (success: breaks render)

### 6.3.4 Orphan/Widow Control
- [ ] **Task 6.3.4 Complete**

Prevent orphaned/widowed rows.

- [ ] 6.3.4.1 Add min_rows_before_break property (success: property added)
- [ ] 6.3.4.2 Add min_rows_after_break property (success: property added)
- [ ] 6.3.4.3 Generate Typst orphan/widow settings (success: settings apply)

### Unit Tests - Section 6.3
- [ ] 6.3.T.1 Test cell break control
- [ ] 6.3.T.2 Test row break control
- [ ] 6.3.T.3 Test band break control
- [ ] 6.3.T.4 Test orphan/widow prevention

## 6.4 Accessibility

### 6.4.1 Table Accessibility
- [ ] **Task 6.4.1 Complete**

Ensure tables are accessible.

- [ ] 6.4.1.1 Generate proper scope attributes for th elements (success: scope set)
- [ ] 6.4.1.2 Add support for caption element (success: captions work)
- [ ] 6.4.1.3 Add support for summary attribute (success: summary works)
- [ ] 6.4.1.4 Ensure proper header associations for complex tables (success: associations correct)

### 6.4.2 ARIA Attributes
- [ ] **Task 6.4.2 Complete**

Support ARIA attributes for HTML output.

- [ ] 6.4.2.1 Add aria-label property to layouts (success: labels work)
- [ ] 6.4.2.2 Add aria-describedby for complex layouts (success: descriptions work)
- [ ] 6.4.2.3 Add role attribute where needed (success: roles set)
- [ ] 6.4.2.4 Ensure screen reader compatibility (success: accessible)

### 6.4.3 PDF Accessibility
- [ ] **Task 6.4.3 Complete**

Ensure PDF output is accessible.

- [ ] 6.4.3.1 Research Typst accessibility features (success: features identified)
- [ ] 6.4.3.2 Generate tagged PDF structure (success: structure tags)
- [ ] 6.4.3.3 Add alt text support for any images (success: alt text works)
- [ ] 6.4.3.4 Test with PDF accessibility checkers (success: passes checks)

### Unit Tests - Section 6.4
- [ ] 6.4.T.1 Test table accessibility attributes
- [ ] 6.4.T.2 Test ARIA attributes in HTML
- [ ] 6.4.T.3 Test PDF accessibility

## 6.5 Additional Typst Primitives

### 6.5.1 Box Primitive
- [ ] **Task 6.5.1 Complete**

Evaluate and potentially add box primitive.

- [ ] 6.5.1.1 Research Typst box() capabilities (success: capabilities documented)
- [ ] 6.5.1.2 Determine if box adds value over existing primitives (success: decision made)
- [ ] 6.5.1.3 Implement box entity if valuable (success: box works or deferred)

### 6.5.2 Block Primitive
- [ ] **Task 6.5.2 Complete**

Evaluate and potentially add block primitive.

- [ ] 6.5.2.1 Research Typst block() capabilities (success: capabilities documented)
- [ ] 6.5.2.2 Determine if block adds value (success: decision made)
- [ ] 6.5.2.3 Implement block entity if valuable (success: block works or deferred)

### 6.5.3 Place Primitive
- [ ] **Task 6.5.3 Complete**

Evaluate absolute positioning with place.

- [ ] 6.5.3.1 Research Typst place() for absolute positioning (success: capabilities documented)
- [ ] 6.5.3.2 Determine use cases for absolute positioning in reports (success: uses identified)
- [ ] 6.5.3.3 Implement place entity if valuable (success: place works or deferred)

### Unit Tests - Section 6.5
- [ ] 6.5.T.1 Test additional primitives if implemented

## 6.6 Performance Optimization

### 6.6.1 IR Optimization
- [ ] **Task 6.6.1 Complete**

Optimize IR generation and processing.

- [ ] 6.6.1.1 Profile IR transformation performance (success: bottlenecks identified)
- [ ] 6.6.1.2 Optimize cell positioning algorithm (success: positioning fast)
- [ ] 6.6.1.3 Cache computed properties where possible (success: caching works)
- [ ] 6.6.1.4 Reduce IR struct allocations (success: memory optimized)

### 6.6.2 Rendering Optimization
- [ ] **Task 6.6.2 Complete**

Optimize rendering performance.

- [ ] 6.6.2.1 Profile Typst rendering performance (success: bottlenecks identified)
- [ ] 6.6.2.2 Profile HTML rendering performance (success: bottlenecks identified)
- [ ] 6.6.2.3 Optimize string concatenation in renderers (success: strings optimized)
- [ ] 6.6.2.4 Consider streaming output for large reports (success: streaming evaluated)

### 6.6.3 Memory Optimization
- [ ] **Task 6.6.3 Complete**

Optimize memory usage for large reports.

- [ ] 6.6.3.1 Profile memory usage with large datasets (success: usage profiled)
- [ ] 6.6.3.2 Implement lazy evaluation where beneficial (success: lazy eval works)
- [ ] 6.6.3.3 Consider pagination for very large reports (success: pagination evaluated)

### Unit Tests - Section 6.6
- [ ] 6.6.T.1 Performance benchmarks for IR
- [ ] 6.6.T.2 Performance benchmarks for rendering
- [ ] 6.6.T.3 Memory usage tests

## 6.7 Documentation and Examples

### 6.7.1 API Documentation
- [ ] **Task 6.7.1 Complete**

Complete API documentation for all entities.

- [ ] 6.7.1.1 Document all DSL entities with examples (success: entities documented)
- [ ] 6.7.1.2 Document all properties with types and defaults (success: properties documented)
- [ ] 6.7.1.3 Document track size helpers (success: helpers documented)
- [ ] 6.7.1.4 Generate ExDoc documentation (success: docs generate)

### 6.7.2 Tutorial and Guides
- [ ] **Task 6.7.2 Complete**

Create learning resources.

- [ ] 6.7.2.1 Write getting started guide for layouts (success: guide written)
- [ ] 6.7.2.2 Write guide for common patterns (success: patterns documented)
- [ ] 6.7.2.3 Write migration guide from legacy format (success: migration guide)
- [ ] 6.7.2.4 Write troubleshooting guide (success: troubleshooting documented)

### 6.7.3 Example Reports
- [ ] **Task 6.7.3 Complete**

Create example reports demonstrating features.

- [ ] 6.7.3.1 Create example for each layout primitive (success: examples exist)
- [ ] 6.7.3.2 Create example for nested layouts (success: nesting example)
- [ ] 6.7.3.3 Create example for conditional styling (success: styling example)
- [ ] 6.7.3.4 Create example for accessibility features (success: accessibility example)

### Unit Tests - Section 6.7
- [ ] 6.7.T.1 All examples compile and run
- [ ] 6.7.T.2 Documentation generates without errors

## 6.8 Chart Integration

### 6.8.1 Charts in Layout Containers
- [ ] **Task 6.8.1 Complete**

Ensure existing AshReports charts work within new layout containers.

- [ ] 6.8.1.1 Test chart embedding in grid cells (success: charts render in grid)
- [ ] 6.8.1.2 Test chart embedding in table cells (success: charts render in table)
- [ ] 6.8.1.3 Test chart embedding in stack children (success: charts render in stack)
- [ ] 6.8.1.4 Verify chart sizing respects cell bounds (success: charts size correctly)

### 6.8.2 Chart Sizing and Layout
- [ ] **Task 6.8.2 Complete**

Handle chart sizing within layout constraints.

- [ ] 6.8.2.1 Support explicit width/height for charts in cells (success: explicit sizing works)
- [ ] 6.8.2.2 Support auto-sizing to fill cell (success: charts fill available space)
- [ ] 6.8.2.3 Handle aspect ratio preservation (success: aspect ratios maintained)
- [ ] 6.8.2.4 Test charts in spanning cells (success: spanned cells size charts)

### 6.8.3 Chart Data Flow
- [ ] **Task 6.8.3 Complete**

Ensure data flows correctly to embedded charts.

- [ ] 6.8.3.1 Pass report data context to chart renderer (success: data available)
- [ ] 6.8.3.2 Support chart-specific data subsets (success: filtering works)
- [ ] 6.8.3.3 Support chart parameters from report variables (success: variables work)

### Unit Tests - Section 6.8
- [ ] 6.8.T.1 Test all chart types in grid cells
- [ ] 6.8.T.2 Test chart sizing
- [ ] 6.8.T.3 Test chart data flow

## Success Criteria

1. **Nested Layouts**: Support deep nesting with proper property inheritance
2. **Conditional Styling**: Full function support for conditional fill, stroke, alignment
3. **Page Break Handling**: Control breaks at cell, row, and band level
4. **Accessibility**: Proper table semantics, ARIA attributes, PDF accessibility
5. **Additional Primitives**: Evaluate and implement box/block/place if valuable
6. **Performance**: Optimized IR and rendering for large reports
7. **Documentation**: Complete API docs, tutorials, and examples

## Provides Foundation

This phase completes the layout primitives system with:

- **Full feature parity** with Typst layout capabilities
- **Production-ready** performance and accessibility
- **Comprehensive documentation** for users
- **Rich examples** demonstrating all features

## Key Outputs

- Deep nesting support with composition patterns
- Function-based conditional styling
- Page break control at all levels
- Accessibility features for HTML and PDF
- Performance optimizations
- Complete API documentation
- Tutorial and guides
- Example report collection
