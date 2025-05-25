# Report Writer Band Hierarchy

## Overview

The Report Writer should use a hierarchical band structure to organize and control how data appears in reports. The bands appear in a specific order and serve different purposes in the report layout.

## Hierarchical Band Structure (Top to Bottom)

### 1. Title Band
- **Frequency**: Appears once at the beginning of the report
- **Purpose**: Used for report titles and introductory information
- **Characteristics**: Optional band
- **Location**: Very first band in the report

### 2. Page Header Band
- **Frequency**: Appears at the beginning of each page
- **Purpose**: Commonly used for column headers, report names, and page numbers
- **Characteristics**: Prints on every page of the report
- **Common Usage**: Static information that needs to appear on every page

### 3. Column Header Band
- **Frequency**: Appears at the top of each column (when using multi-column reports)
- **Purpose**: Used for column-specific headers
- **Characteristics**: Only relevant in multi-column report layouts

### 4. Group Header Band(s)
- **Frequency**: Appears when a group expression changes during the report
- **Purpose**: Used for group titles and summary information before group details
- **Characteristics**: 
  - Can have up to 74 data groups in VFP 9 (up from 20 in earlier versions)
  - Group bands are nested, with the first data group appearing at the outermost level
  - Can be reprinted on each page if the group spans multiple pages
  - Supports "Start group on new page when less than" option to prevent orphaned headers

### 5. Detail Band(s)
- **Frequency**: Processes once for each record in the scope
- **Purpose**: Displays the actual data records
- **Structure**: Each detail band can include:
  - **Detail Header Band** - Appears before detail records
  - **Detail Band** - The actual data rows
  - **Detail Footer Band** - Appears after detail records
- **Enhancements**:
  - Supports multiple detail bands
  - Detail bands appear consecutively in the page layout
  - Can specify target aliases for processing related child tables
  - Enables master-detail reporting with multiple child relationships

### 6. Group Footer Band(s)
- **Frequency**: Appears after all detail records for a group have been processed
- **Purpose**: Used for group summaries and totals
- **Characteristics**: Nested in reverse order of group headers
- **Common Usage**: Group totals, counts, and summary information

### 7. Column Footer Band
- **Frequency**: Appears at the bottom of each column (when using multi-column reports)
- **Purpose**: Column-specific footer information
- **Characteristics**: Only relevant in multi-column report layouts

### 8. Page Footer Band
- **Frequency**: Appears at the end of each page
- **Purpose**: Used for page numbers, dates, and other page-specific information
- **Characteristics**: Prints on every page of the report
- **Common Usage**: Page numbers, report run date/time, copyright notices

### 9. Summary Band
- **Frequency**: Appears once at the end of the report
- **Purpose**: Used for report totals and conclusions
- **Characteristics**: Optional band
- **Location**: Very last band in the report (before the final page footer)

## Key Concepts

### Band Processing Order
- Report writef moves through the report's driving cursor in a single pass
- Processing is paused by group breaks
- The Report Engine processes the detail band once for each record in the report scope
- Group changes trigger the printing of group footers and headers

### Multiple Detail Bands (Feature)
- The Report Design represents multiple passes through the detail band scope by showing multiple detail bands
- Each detail band can have a target alias expression that can evaluate to:
  - A child table alias (processes all related child records)
  - The driving alias (valid only in the first detail band)
  - Empty (processes once per driving record)
- Enables complex master-detail reporting with multiple related child tables

### Band Configuration Options

#### Detail Band Options
- Start on a new column
- Start on a new page
- Restart page numbering
- Have associated header/footer bands
- Reprint detail header on each page
- Minimum distance from page bottom

#### Group Band Options
- Start group on new column
- Start group on new page
- Restart page numbering
- Reprint group header on subsequent pages
- Start group on new page when less than X inches remain

### Report Variables and Calculations
- Report variables can be reset based on:
  - Detail bands (specific detail band in multi-detail reports)
  - Groups (at group breaks)
  - Pages (at page breaks)
  - Report (at report end)
- Variables can be scoped to specific detail bands and their target aliases

### Band Expressions
- **On Entry Expression**: Evaluated before processing band objects
- **On Exit Expression**: Evaluated after processing band objects
- Used for:
  - Setting up data relationships
  - Calculating values before band processing
  - Performing cleanup after band processing

## Visual Representation

```
┌─────────────────────────────────────┐
│          TITLE BAND                 │ (Once at report start)
├─────────────────────────────────────┤
│        PAGE HEADER BAND             │ (Every page)
├─────────────────────────────────────┤
│      COLUMN HEADER BAND             │ (Top of each column)
├─────────────────────────────────────┤
│    GROUP 1 HEADER BAND              │ ┐
├─────────────────────────────────────┤ │
│      GROUP 2 HEADER BAND            │ │ Nested
├─────────────────────────────────────┤ │ Groups
│        DETAIL HEADER 1              │ │
│        DETAIL BAND 1                │ │
│        DETAIL FOOTER 1              │ │
├─────────────────────────────────────┤ │
│        DETAIL HEADER 2              │ │
│        DETAIL BAND 2                │ │
│        DETAIL FOOTER 2              │ │
├─────────────────────────────────────┤ │
│      GROUP 2 FOOTER BAND            │ │
├─────────────────────────────────────┤ │
│    GROUP 1 FOOTER BAND              │ ┘
├─────────────────────────────────────┤
│      COLUMN FOOTER BAND             │ (Bottom of each column)
├─────────────────────────────────────┤
│        PAGE FOOTER BAND             │ (Every page)
├─────────────────────────────────────┤
│         SUMMARY BAND                │ (Once at report end)
└─────────────────────────────────────┘
```

## Practical Applications

### Master-Detail Reports
- Use multiple detail bands to show different child relationships
- Example: Customer (driving alias) → Orders (Detail 1) → Payments (Detail 2)

### Grouped Reports with Summaries
- Group headers for category titles
- Detail bands for line items
- Group footers for subtotals
- Summary band for grand totals

### Multi-Column Reports
- Column headers/footers for column-specific information
- Group headers can span multiple columns in VFP 9

### Complex Financial Reports
- Title band for report header
- Multiple group levels for departments/categories
- Detail bands for transactions
- Group footers for subtotals
- Summary band for grand totals and report conclusions

