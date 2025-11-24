# Phase 3.5 Summary: Data Interpolation

## Overview

This section implements variable interpolation for Typst rendered content and verifies field value formatting. The Interpolation module detects `[variable_name]` patterns in text and replaces them with values from the data context. Field value formatting was already implemented in the Content module from section 3.2.

## Files Created

### Source Files

1. **`lib/ash_reports/renderer/typst/interpolation.ex`**
   - Variable interpolation using `[variable_name]` patterns
   - Nested path support (e.g., `[user.name]`, `[order.customer.address.city]`)
   - Graceful handling of missing variables (keeps as placeholder)
   - Automatic value formatting for different types
   - Public functions: `interpolate/2`, `has_variables?/1`, `extract_variables/1`, `get_variable_value/2`

### Test Files

1. **`test/ash_reports/renderer/typst/interpolation_test.exs`** (47 tests)
   - Tests for simple and multiple variable interpolation
   - Tests for nested variable paths
   - Tests for missing variable handling
   - Tests for value formatting (integer, float, Date, DateTime, etc.)
   - Tests for helper functions (has_variables?, extract_variables)
   - Integration scenarios

## Key Implementation Details

### Variable Interpolation

The interpolation module uses regex to detect and replace variables:

```elixir
# Simple variable
"Hello [name]!" with %{name: "World"} → "Hello World!"

# Multiple variables
"[greeting] [name]!" with %{greeting: "Hi", name: "Bob"} → "Hi Bob!"

# Nested path
"Name: [user.name]" with %{user: %{name: "Alice"}} → "Name: Alice"

# Missing variable (kept as placeholder)
"Hello [unknown]!" with %{} → "Hello [unknown]!"
```

### Nested Path Support

Variables can reference nested data structures:

```elixir
# Deep nesting
"City: [order.customer.address.city]"
with %{order: %{customer: %{address: %{city: "NYC"}}}}
→ "City: NYC"
```

### Value Formatting

Interpolated values are automatically formatted:
- Strings: Used as-is
- Integers: Converted to string
- Floats: Formatted with 2 decimal places
- Dates: ISO 8601 format (YYYY-MM-DD)
- DateTimes: Full ISO 8601 string
- Atoms: Converted to string
- Other: Using `inspect/1`

### Field Value Formatting (Already Implemented)

The Content module already supports field value formatting:

```elixir
# Number format
format_value(1234.56, :number, 2) → "1234.56"

# Currency format
format_value(99.99, :currency, 2) → "$99.99"

# Percent format
format_value(0.125, :percent, 1) → "12.5%"

# Date format
format_value(~D[2025-01-15], :date, nil) → "2025-01-15"

# DateTime format
format_value(~N[2025-01-15 10:30:00], :datetime, nil) → "2025-01-15 10:30:00"
```

## Test Results

All 281 tests pass:
- GridTest: 31 tests
- TableTest: 30 tests
- StackTest: 27 tests
- CellTest: 26 tests
- ContentTest: 42 tests
- PropertyRenderingTest: 48 tests
- LinesTest: 30 tests
- InterpolationTest: 47 tests

## Design Decisions

1. **Regex-Based Pattern Matching**: Uses `~r/\[([^\]]+)\]/` for efficient variable detection.

2. **Placeholder Preservation**: Missing variables are kept as `[variable_name]` to make debugging easier and allow for later processing.

3. **Automatic Type Conversion**: Values are automatically formatted to strings based on their type, with sensible defaults.

4. **Path Parsing**: Variable names with dots are parsed into atom paths for nested map access.

5. **Reuse Existing Formatting**: Field value formatting in Content module is already comprehensive; no duplication needed.

## Dependencies

- No external dependencies
- All functions are in `AshReports.Renderer.Typst.Interpolation` module

## Integration

The Interpolation module can be used by:
- Content renderer for interpolating variables in labels
- Any renderer component that needs to process text with variable placeholders
- Report title/header generation

## Usage Example

```elixir
# In a label or text element
template = "Invoice [invoice.number] for [customer.name]"
data = %{
  invoice: %{number: "INV-001"},
  customer: %{name: "Acme Corp"}
}

result = Interpolation.interpolate(template, data)
# → "Invoice INV-001 for Acme Corp"
```

## Next Steps

- Section 3.6: Text styling (font size, weight, color via #text())
- Section 3.7: Renderer integration (main entry point)
- Section 3.8: Internationalization (locale-aware formatting)
