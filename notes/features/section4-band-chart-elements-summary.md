# Section 4: Type-Specific Chart Elements in Bands - Completion Summary

**Date**: 2025-10-31
**Branch**: `feature/band-chart-elements`
**Section**: Chart DSL Refactoring - Section 4 of 10
**Duration**: ~1 hour (estimated 3-4 hours)

## Overview

Section 4 successfully replaced the generic chart element with 7 type-specific chart reference elements in the band DSL. Charts can now be referenced by name in band elements, pointing to standalone chart definitions at the reports level.

## Completed Tasks

### Task 4.1: Remove old chart_element_entity ✅

- **File**: `lib/ash_reports/dsl.ex`
- Removed `chart_element_entity()` from band entity elements list
- Deleted deprecated `chart_element_entity/0` function (lines 349-357)
- Deleted deprecated `chart_element_schema/0` function (lines 1183-1215)
- Cleaned up unused code that referenced the old generic chart element

### Task 4.2-4.8: Add type-specific chart element entities ✅

- **File**: `lib/ash_reports/dsl.ex`
- **Commit**: d234e48

Added 7 new element entities to band elements list:
1. `bar_chart_element_entity()` - Lines 349-360
2. `line_chart_element_entity()` - Lines 362-373
3. `pie_chart_element_entity()` - Lines 375-386
4. `area_chart_element_entity()` - Lines 388-399
5. `scatter_chart_element_entity()` - Lines 401-412
6. `gantt_chart_element_entity()` - Lines 414-425
7. `sparkline_element_entity()` - Lines 427-438

Each entity follows this pattern:
- `name`: Matches the chart type (`:bar_chart`, `:line_chart`, etc.)
- `describe`: Clear documentation on referencing standalone charts
- `target`: Points to the corresponding element module
- `args`: `[:chart_name]` - the name of the chart to reference
- `schema`: Uses the corresponding element schema function

### Task 4.2-4.8: Add element schema functions ✅

- **File**: `lib/ash_reports/dsl.ex`
- Added 7 schema functions (lines 1183-1260)

Each schema function:
- Extends `base_element_schema()` to include position, style, conditional fields
- Adds `chart_name` field (required, atom type)
- Documents which chart definition type to reference

Schema functions:
- `bar_chart_element_schema/0`
- `line_chart_element_schema/0`
- `pie_chart_element_schema/0`
- `area_chart_element_schema/0`
- `scatter_chart_element_schema/0`
- `gantt_chart_element_schema/0`
- `sparkline_element_schema/0`

### Section 7 (Integrated): Create Element Modules ✅

Created 7 element modules (originally planned for Section 7, but implemented here):

1. **BarChartElement** - `lib/ash_reports/reports/element/bar_chart_element.ex`
2. **LineChartElement** - `lib/ash_reports/reports/element/line_chart_element.ex`
3. **PieChartElement** - `lib/ash_reports/reports/element/pie_chart_element.ex`
4. **AreaChartElement** - `lib/ash_reports/reports/element/area_chart_element.ex`
5. **ScatterChartElement** - `lib/ash_reports/reports/element/scatter_chart_element.ex`
6. **GanttChartElement** - `lib/ash_reports/reports/element/gantt_chart_element.ex`
7. **SparklineElement** - `lib/ash_reports/reports/element/sparkline_element.ex`

Each module includes:
- `defstruct` with fields: name, chart_name, position, style, conditional, type
- `@type` specification
- `new/2` constructor function
- `process_options/1` helper for converting keyword lists to maps
- Comprehensive moduledoc with DSL examples

## Technical Implementation

### Element Module Pattern

Each element module follows this consistent structure:

```elixir
defmodule AshReports.Element.BarChartElement do
  @moduledoc """
  Documentation explaining chart reference behavior
  """

  defstruct [
    :name,
    :chart_name,
    :position,
    :style,
    :conditional,
    type: :bar_chart_element
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: :bar_chart_element,
          chart_name: atom(),
          position: AshReports.Element.position(),
          style: AshReports.Element.style(),
          conditional: Ash.Expr.t() | nil
        }

  @spec new(atom(), Keyword.t()) :: t()
  def new(chart_name, opts \\ []) do
    struct(
      __MODULE__,
      [chart_name: chart_name, name: chart_name, type: :bar_chart_element]
      |> Keyword.merge(opts)
      |> process_options()
    )
  end

  defp process_options(opts) do
    opts
    |> Keyword.update(:position, %{}, &AshReports.Element.keyword_to_map/1)
    |> Keyword.update(:style, %{}, &AshReports.Element.keyword_to_map/1)
  end
end
```

### DSL Usage

Charts can now be referenced in bands:

```elixir
reports do
  # Define charts at reports level
  bar_chart :sales_by_region do
    data_source expr(aggregate_sales_by_region())
    config do
      width 600
      height 400
      title "Sales by Region"
      type :grouped
    end
  end

  line_chart :trends_over_time do
    data_source expr(daily_metrics())
    config do
      smoothed true
      stroke_width "2"
    end
  end

  # Reference charts in bands
  report :monthly_report do
    bands do
      band :summary do
        elements do
          bar_chart :sales_by_region
          line_chart :trends_over_time
        end
      end
    end
  end
end
```

## Verification

### Compilation
```bash
$ mix compile --warnings-as-errors
Compiling 4 files (.ex)
Generated ash_reports app
```
✅ Clean compilation with no warnings (exit code 0)

### File Statistics
```
Modified:
  lib/ash_reports/dsl.ex: +170 insertions, -33 deletions

Created:
  lib/ash_reports/reports/element/bar_chart_element.ex: 75 lines
  lib/ash_reports/reports/element/line_chart_element.ex: 73 lines
  lib/ash_reports/reports/element/pie_chart_element.ex: 73 lines
  lib/ash_reports/reports/element/area_chart_element.ex: 75 lines
  lib/ash_reports/reports/element/scatter_chart_element.ex: 75 lines
  lib/ash_reports/reports/element/gantt_chart_element.ex: 75 lines
  lib/ash_reports/reports/element/sparkline_element.ex: 80 lines

Total: +701 lines, -33 deletions
```

### Commit History
```
d234e48 - feat: Add type-specific chart element entities to band DSL (+701)
```

## Code Quality

- ✅ All entities and modules compile without warnings
- ✅ Consistent structure across all 7 chart element types
- ✅ Proper Spark DSL Entity and schema patterns
- ✅ Type-safe field definitions with atom validation
- ✅ Comprehensive documentation with DSL examples
- ✅ Clean removal of deprecated code
- ✅ Follows existing element patterns (Label, Field, etc.)
- ✅ No credo issues introduced

## Integration Points

These changes enable:
- **Section 5**: Chart type implementations will receive chart definitions from lookup (not yet implemented)
- **Section 6**: Renderers will look up chart definitions by name from element references
- **Section 8**: Old generic Chart element module can be deleted

## Breaking Changes

1. **Generic chart element removed**: `chart :name do chart_type :bar ... end` syntax no longer works in bands
2. **Chart must be defined at reports level**: Inline chart definitions in bands are not supported
3. **Chart reference required**: Bands must reference charts by name using type-specific elements

### Migration Example

**Old Syntax (no longer works):**
```elixir
band :detail do
  elements do
    chart :my_chart do
      chart_type :bar
      data_source expr(sales_data)
      config %{width: 600}
    end
  end
end
```

**New Syntax:**
```elixir
# Define at reports level
bar_chart :my_chart do
  data_source expr(sales_data)
  config do
    width 600
  end
end

# Reference in band
band :detail do
  elements do
    bar_chart :my_chart
  end
end
```

## Known Limitations

1. **No Renderer Integration Yet**: Elements parse correctly but renderers don't yet look up and process chart references (Section 6)
2. **No Chart Type Implementation Updates**: Chart type modules still expect old config format (Section 5)
3. **No Tests Yet**: Test creation planned for Section 9
4. **Old Chart Element Module Still Exists**: `AshReports.Element.Chart` will be deleted in Section 8

## Next Steps

Section 5 will:
1. Update chart type implementations (BarChart, LineChart, etc.)
2. Change build/2 signatures to accept type-specific config structs
3. Map config fields to Contex library options
4. Update validation functions

Section 6 will:
1. Add chart lookup functions to renderers
2. Resolve chart definitions by name from reports
3. Handle type-specific chart elements in rendering
4. Remove old generic chart rendering code

## Statistics

- **DSL Changes**: 1 file modified (+170, -33 lines)
- **Element Modules Created**: 7 files (~75 lines each)
- **Total Lines Added**: ~701 lines
- **Lines Removed**: 33 lines (deprecated code)
- **Commits**: 1 atomic commit
- **Duration**: ~1 hour (67% faster than estimated 3-4 hours)
- **Compilation**: ✅ Clean
- **Warnings**: 0

## Element Type Summary

| Element Type | Module | Type Atom | Args |
|-------------|---------|-----------|------|
| BarChart | AshReports.Element.BarChartElement | :bar_chart_element | [:chart_name] |
| LineChart | AshReports.Element.LineChartElement | :line_chart_element | [:chart_name] |
| PieChart | AshReports.Element.PieChartElement | :pie_chart_element | [:chart_name] |
| AreaChart | AshReports.Element.AreaChartElement | :area_chart_element | [:chart_name] |
| ScatterChart | AshReports.Element.ScatterChartElement | :scatter_chart_element | [:chart_name] |
| GanttChart | AshReports.Element.GanttChartElement | :gantt_chart_element | [:chart_name] |
| Sparkline | AshReports.Element.SparklineElement | :sparkline_element | [:chart_name] |

All elements share base fields: `name`, `chart_name`, `position`, `style`, `conditional`, `type`

## Conclusion

Section 4 is complete. All 7 chart types now have type-specific element entities and modules that reference standalone chart definitions by name. The DSL now supports the new pattern where charts are defined once at the reports level and referenced multiple times in different bands.

The implementation was more efficient than estimated (1 hour vs 3-4 hours) due to the consistent pattern across all chart types and integration of Section 7's element module creation.

Section 7 (Chart Element Modules) can now be marked as complete since all element modules were created as part of this section.
