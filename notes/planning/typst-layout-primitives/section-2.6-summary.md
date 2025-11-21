# Section 2.6: Error Handling and Validation - Implementation Summary

## Overview

This section implements a comprehensive error handling system for layout transformation, providing structured error types, formatted messages, and validation functions for DSL properties, positioning conflicts, and property values.

## Files Created

### Core Module

1. **`lib/ash_reports/layout/errors.ex`**
   - Error type constructors for all error categories
   - `format/1` - Human-readable error message formatting
   - `format_with_location/3` - Error messages with file/line info
   - `validate_one_of/3` - Validate value against allowed list
   - `validate_track_size/1` - Validate track size formats
   - `validate_color/1` - Validate color formats
   - `validate_alignment/1` - Validate alignment values
   - `validate_length/1` - Validate length units

### Test File

2. **`test/ash_reports/layout/errors_test.exs`**
   - 70 unit tests covering all error types and validation functions

## Key Implementation Details

### Error Categories

#### DSL Validation Errors

| Constructor | Description | Example Message |
|-------------|-------------|-----------------|
| `invalid_property/3` | Invalid property value | "Invalid align: :diagonal. Expected one of: [:left, :center, :right]" |
| `invalid_nesting/2` | Incorrect entity nesting | "cell cannot be nested directly inside cell" |
| `missing_required/2` | Missing required property | "columns is required for grid" |

#### Positioning Errors

| Constructor | Description | Example Message |
|-------------|-------------|-----------------|
| `position_conflict/2` | Cell position conflict | "Cell at (2, 1) conflicts with existing cell" |
| `span_overflow/3` | Span exceeds grid bounds | "colspan 3 at column 2 exceeds grid width of 4" |
| `invalid_position/2` | Position outside bounds | "Position (5, 0) outside grid bounds (4, 3)" |
| `grid_gap/1` | Empty position in grid | "No cell at position (1, 2)" |

#### Property Validation Errors

| Constructor | Description | Example Message |
|-------------|-------------|-----------------|
| `invalid_track_size/1` | Invalid track size | "Invalid track size: 'abc'" |
| `invalid_color/1` | Invalid color format | "Invalid color: 'not-a-color'" |
| `invalid_alignment/1` | Invalid alignment | "Invalid alignment: :diagonal" |
| `invalid_length/1` | Invalid length unit | "Unknown unit in '10px'" |

### Validation Functions

#### Track Size Validation

Accepts:
- `"auto"` / `:auto`
- Numeric values
- Units: `pt`, `cm`, `mm`, `in`, `%`, `fr`, `em`

```elixir
:ok = Errors.validate_track_size("1fr")
:ok = Errors.validate_track_size("100pt")
{:error, _} = Errors.validate_track_size("abc")
```

#### Color Validation

Accepts:
- Atom colors: `:red`, `:blue`
- Named colors: "red", "white", "transparent"
- Hex colors: "#fff", "#ff0000", "#ff0000ff"
- RGB/RGBA: "rgb(255, 0, 0)", "rgba(0, 0, 0, 0.5)"
- Typst functions: "luma(50)", "oklab()", "color.red"

```elixir
:ok = Errors.validate_color("#ff0000")
:ok = Errors.validate_color("rgb(255, 0, 0)")
{:error, _} = Errors.validate_color("not-a-color")
```

#### Alignment Validation

Accepts:
- Horizontal: `:left`, `:center`, `:right`, `:start`, `:end`
- Vertical: `:top`, `:horizon`, `:bottom`
- Combined: "left+top", "center+horizon"

```elixir
:ok = Errors.validate_alignment(:center)
:ok = Errors.validate_alignment("left+top")
{:error, _} = Errors.validate_alignment(:diagonal)
```

#### Length Validation

Accepts:
- `"auto"` / `:auto`
- Numeric values
- Units: `pt`, `cm`, `mm`, `in`, `%`, `fr`, `em`
- Plain number strings

```elixir
:ok = Errors.validate_length("100pt")
:ok = Errors.validate_length("1.5em")
{:error, _} = Errors.validate_length("10px")  # px not supported
{:error, _} = Errors.validate_length("5rem")  # rem not supported
```

### Error Formatting

#### Basic Formatting

```elixir
error = {:position_conflict, {2, 1}, :existing_cell}
message = Errors.format(error)
# => "Cell at (2, 1) conflicts with existing cell"
```

#### With Location

```elixir
error = {:invalid_property, :align, :diagonal, [:left, :center, :right]}
message = Errors.format_with_location(error, "lib/my_report.ex", 42)
# => "lib/my_report.ex:42: Invalid align: :diagonal. Expected one of: [:left, :center, :right]"
```

## Test Coverage

All 70 tests pass, covering:

### Error Constructors (12 tests)
- DSL validation error tuples
- Positioning error tuples
- Property validation error tuples

### Format Function (19 tests)
- All DSL validation error formats
- All positioning error formats
- All property validation error formats
- Format with location

### Validation Functions (39 tests)
- `validate_one_of/3` - Valid and invalid values
- `validate_track_size/1` - All units, invalid formats
- `validate_color/1` - Named, hex, RGB, Typst functions
- `validate_alignment/1` - Atoms, strings, combined
- `validate_length/1` - All units, invalid formats

## Architecture

The Errors module is designed to be:

1. **Composable**: Error constructors create typed tuples
2. **Consistent**: All errors follow `{:error_type, ...}` pattern
3. **Extensible**: Easy to add new error types
4. **Informative**: Clear, actionable error messages

## Integration Points

The Errors module can be integrated with:

- **Transformers** (Section 2.2): Validate during transformation
- **Positioning Engine** (Section 2.3): Report positioning conflicts
- **Property Resolver** (Section 2.4): Validate resolved properties
- **Pipeline** (Section 2.5): Provide detailed error messages

## Phase 2 Completion

With Section 2.6 complete, Phase 2 is fully finished:

- [x] Section 2.1 - IR Data Structures
- [x] Section 2.2 - DSL to IR Transformers
- [x] Section 2.3 - Cell Positioning Engine
- [x] Section 2.4 - Property Resolution
- [x] Section 2.5 - Transformer Pipeline
- [x] Section 2.6 - Error Handling and Validation

## Next Steps

Phase 3 (Typst Renderer) can now begin with confidence:
- Full IR layer complete
- Comprehensive error handling available
- All validation functions ready to use

## Branch

All changes are on branch: `feature/phase-02-error-handling`
