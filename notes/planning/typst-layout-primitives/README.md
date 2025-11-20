# Typst Layout Primitives Implementation Plan

## Overview

This plan implements Typst layout primitives (grid, table, stack, row) into the AshReports DSL. It is a greenfield implementation with no backward compatibility requirements.

**Total Estimated Duration**: 11-15 weeks (add 20-30% buffer for integration issues and design revisions)

**Design Document**: `../typst-layout-primitives-dsl-design.md`

## Phase Summary

| Phase | Description | Duration | Dependencies |
|-------|-------------|----------|--------------|
| [Phase 1](phase-01.md) | Core DSL Entities | 2-3 weeks | None |
| [Phase 2](phase-02.md) | Intermediate Representation | 1.5-2 weeks | Phase 1 |
| [Phase 3](phase-03.md) | Typst Renderer | 2-2.5 weeks | Phase 2 |
| [Phase 4](phase-04.md) | HTML Renderer | 1.5-2 weeks | Phase 2 |
| [Phase 5](phase-05.md) | Demo App Migration | 1.5-2 weeks | Phases 3, 4 |
| [Phase 6](phase-06.md) | Advanced Features | 2-3 weeks | Phase 5 |

## Critical Path & Risk Mitigation

### Phase 1 is the Critical Path

The DSL entity design cascades through all subsequent phases. Issues discovered late are expensive to fix.

**Mitigation: Vertical Slice Approach**

Before completing all entities in Phase 1, build a minimal end-to-end slice:
1. Implement grid entity with columns and cells
2. Create minimal IR transformation
3. Generate basic Typst output
4. Verify PDF compilation

This validates the architecture early and surfaces integration issues before full implementation.

### Early Validation in Phase 5

Don't wait until Phase 5 to test real reports.

**Mitigation: Progressive Migration**

- Migrate `product_inventory` (simplest report) immediately after Phase 1 entities are defined
- Use it to drive Phase 2-4 development as a real-world test case
- This ensures the DSL design works for actual use cases before completing all infrastructure

## Parallelization Opportunities

### Phase 3 & 4 Can Run Concurrently

The Typst renderer (Phase 3) and HTML renderer (Phase 4) are independent once the IR is defined in Phase 2.

**Opportunity**: If multiple developers are available, these phases can execute in parallel, reducing total elapsed time by 1.5-2 weeks.

```
Phase 1 → Phase 2 → ┬→ Phase 3 (Typst) ─┬→ Phase 5 → Phase 6
                    └→ Phase 4 (HTML)  ─┘
```

## Estimate Padding

The 11-15 week range assumes focused work. Real-world factors to account for:

- **Integration issues between phases**: +10%
- **Design revisions based on testing**: +10%
- **Unexpected Typst/Spark complexity**: +10%
- **Code review and refinement**: +5%

**Recommended total buffer**: 20-30%

**Realistic estimate**: 14-20 weeks

## Cross-Cutting Concerns

These concerns span multiple phases and should be tracked throughout:

### Error Handling & Validation (Phase 2)

Comprehensive error messages for DSL validation failures:
- Invalid property values
- Incorrect entity nesting
- Cell position conflicts
- Span overflow errors

### Internationalization (Phase 3)

Locale-aware formatting for:
- Currency symbols and formatting
- Date/time formats
- Number decimal/thousand separators
- Consider making locale configurable per report

### Chart Integration (Phase 6)

Ensure charts work within new layout containers:
- Chart embedding in grid/table cells
- Chart sizing within cell bounds
- Data flow to embedded charts

## Success Metrics

### Phase Completion Criteria

Each phase is complete when:
1. All tasks marked with `[x]`
2. All unit tests pass
3. Integration tests with previous phases pass
4. Code review approved

### Overall Project Success

The project is successful when:
1. All 4 demo app reports migrated and working
2. PDF output matches or exceeds previous quality
3. HTML output renders correctly in browsers
4. Performance is acceptable for large reports
5. Documentation is complete

## Getting Started

1. Read the design document: `../typst-layout-primitives-dsl-design.md`
2. Start with Phase 1, Section 1.1 (Grid Entity)
3. Build vertical slice before completing all entities
4. Use `product_inventory` report as ongoing validation

## Progress Tracking

Update task checkboxes in phase documents as work progresses:
- `[ ]` - Not started
- `[x]` - Complete

Mark the phase task header when all subtasks complete:
- `[ ] **Task X.X.X Complete**` → `[x] **Task X.X.X Complete**`
