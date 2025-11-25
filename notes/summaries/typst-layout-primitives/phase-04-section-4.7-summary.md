# Phase 4.7 JSON Renderer - Implementation Summary

**Date:** 2024-11-24
**Branch:** `feature/phase-04-json-renderer`
**Status:** Complete ✅

## Overview

Implemented a JSON renderer that serializes the Layout Intermediate Representation (IR) to JSON-compatible maps for client-side rendering. This enables JavaScript-based rendering engines to consume report structures via APIs.

## Changes Made

### Source Files Created

1. **`lib/ash_reports/renderer/json.ex`** - Complete JSON renderer
   - `render/2` - Serializes single IR to map
   - `render_all/2` - Serializes multiple layouts with wrapper
   - `render_json/2` - Encodes directly to JSON string
   - Handles all IR types: Grid, Table, Stack
   - Serializes nested structures: Cells, Rows, Content, Lines, Headers, Footers
   - Resolves field values from data context

### Test Files Created

1. **`test/ash_reports/renderer/json_test.exs`** (27 tests)
   - Test layout serialization (grid, table, stack)
   - Test nested structures (cells, rows, content)
   - Test content types (labels, fields, nested layouts)
   - Test property serialization (atoms, tuples, functions)
   - Test data resolution (atom keys, string keys, nested paths)
   - Test JSON encoding

## Architecture

### Serialization Flow

```
IR Struct
    │
    ▼
serialize_layout/2
    │
    ├─── properties → serialize_properties
    ├─── children → serialize_children
    │       ├─── Cell → serialize_cell
    │       └─── Row → serialize_row
    ├─── lines → serialize_lines
    ├─── headers → serialize_headers
    └─── footers → serialize_footers
    │
    ▼
JSON-compatible Map
    │
    ▼ (optional)
Jason.encode!
    │
    ▼
JSON String
```

### Output Format

```elixir
%{
  type: "grid",
  properties: %{columns: ["1fr", "1fr"], gap: "10px"},
  children: [
    %{
      type: "cell",
      position: [0, 0],
      span: [1, 1],
      properties: %{align: "center"},
      content: [
        %{type: "label", text: "Name", style: %{font_weight: "bold"}}
      ]
    }
  ],
  lines: [],
  headers: [],
  footers: []
}
```

## API Reference

### render/2

Serializes a single IR to a JSON-compatible map.

```elixir
ir = IR.grid(properties: %{columns: ["1fr", "1fr"]})
map = AshReports.Renderer.Json.render(ir)
# => %{type: "grid", properties: %{...}, children: [], ...}
```

### render_all/2

Serializes multiple layouts (bands) to a wrapper structure.

```elixir
map = AshReports.Renderer.Json.render_all([header_ir, body_ir, footer_ir])
# => %{layouts: [%{...}, %{...}, %{...}]}
```

### render_json/2

Convenience function that encodes directly to JSON string.

```elixir
json = AshReports.Renderer.Json.render_json(ir)
# => "{\"type\":\"grid\",\"properties\":...}"
```

## Serialization Rules

### Property Values

| Elixir Type | JSON Output |
|-------------|-------------|
| Atom | String (e.g., `:center` → `"center"`) |
| Tuple | Array (e.g., `{1, 2}` → `[1, 2]`) |
| Function | `"__function__"` placeholder |
| Boolean | Boolean |
| Number | Number |
| String | String |
| nil | null |

### Position and Span

Tuples are converted to arrays:
- `position: {1, 2}` → `"position": [1, 2]`
- `span: {2, 1}` → `"span": [2, 1]`

### Content Types

```elixir
# Label
%{type: "label", text: "Total:", style: %{...}}

# Field with resolved value
%{type: "field", source: "amount", value: 99.99, format: "currency", decimal_places: 2}

# Nested layout
%{type: "nested_layout", layout: %{type: "grid", ...}}
```

## Data Resolution

The renderer resolves field values from the provided data context:

```elixir
field = Content.field(:user_name)
cell = Cell.new(content: [field])
ir = IR.grid(children: [cell])

Json.render(ir, data: %{user_name: "Alice"})
# Content includes: %{type: "field", source: "user_name", value: "Alice"}
```

### Nested Path Resolution

Supports nested data paths:

```elixir
field = Content.field([:user, :address, :city])
# Resolves: data.user.address.city
```

### Key Flexibility

The resolver tries both atom and string keys at each level:
- First tries atom key (e.g., `:name`)
- Falls back to string key (e.g., `"name"`)

## Test Results

```
27 tests, 0 failures
Finished in 0.2 seconds
```

## Test Coverage

| Test Category | Count | Description |
|--------------|-------|-------------|
| Layout serialization | 3 | Grid, table, stack types |
| Cell/Row serialization | 3 | Children with properties |
| Content types | 4 | Labels, fields, nested layouts |
| Property serialization | 4 | Atoms, tuples, functions |
| Lines/Headers/Footers | 3 | Table structures |
| render_all/2 | 3 | Multiple layouts, data passing |
| render_json/2 | 3 | JSON encoding |
| Nested structures | 2 | Deep nesting |
| Data resolution | 4 | Key types, nested paths |

## Use Cases

### API Response

```elixir
def render(conn, %{"report_id" => id}) do
  ir = generate_report_ir(id)
  json(conn, AshReports.Renderer.Json.render(ir, data: get_data()))
end
```

### Client-Side Rendering

```javascript
// Fetch report JSON
const response = await fetch('/api/reports/1');
const report = await response.json();

// Render with JavaScript library
renderReport(report);
```

### Preview/Debug

```elixir
ir = build_complex_ir()
IO.puts(AshReports.Renderer.Json.render_json(ir, pretty: true))
```

## Phase 4.7 Completion Status

| Task | Status |
|------|--------|
| 4.7.1.1 Create Json module | ✅ |
| 4.7.1.2 Serialize LayoutIR to map | ✅ |
| 4.7.1.3 Serialize nested structures | ✅ |
| 4.7.1.4 Include resolved data | ✅ |
| 4.7.1.5 Register for :json format | ✅ |
| 4.7.T.1 Test JSON serialization | ✅ |
| 4.7.T.2 Test nested structures | ✅ |
| 4.7.T.3 Test data inclusion | ✅ |

## Phase 4 Complete

With section 4.7 complete, **Phase 4 (HTML Renderer) is now fully complete**. All sections have been implemented:

- ✅ 4.1 Core HTML Generation
- ✅ 4.2 Cell and Content Rendering
- ✅ 4.3 CSS Property Mapping
- ✅ 4.4 Data Interpolation
- ✅ 4.5 Styling
- ✅ 4.6 Renderer Integration
- ✅ 4.7 JSON Renderer

## Next Steps

Phase 5: Demo App Migration
- Migrate existing demo app to use new IR-based renderers
- Test with real-world report scenarios

## Notes

- The JSON renderer produces maps that Jason can encode without additional configuration
- Functions in properties are serialized as "__function__" placeholders since they can't be JSON-encoded
- The resolver gracefully handles missing data by returning nil
- Both atom and string keys are supported for maximum flexibility with data sources
